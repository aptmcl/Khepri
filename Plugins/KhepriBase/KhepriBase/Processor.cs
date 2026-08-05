using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;
using System.IO;

namespace KhepriBase {
    /// <summary>
    /// Main RPC dispatch loop. Maintains a list of operation handlers (compiled delegates
    /// from RMIFy). Operation 0 is always ProvideOperation — the bootstrap mechanism that
    /// registers new operations. Each frame from Julia contains an Int32 opcode followed by
    /// serialized arguments; the Processor reads the opcode, dispatches to the corresponding
    /// handler, and the handler writes the response into the frame.
    /// </summary>
    public class Processor<C,P> where C : Channel where P : Primitives {
        public C channel { get; set; }
        public P primitives { get; set; }
        protected List<Action<C, P>> operations;
        protected int minWaitTime;
        protected int maxWaitTime;
        public int MaxRepeated { get; set; }

        public Processor(C c, P p) : this(c, p, 20, 20, Int32.MaxValue) { }

        public Processor(C c, P p, int minWaitTime, int maxWaitTime, int maxRepeated) {
            this.channel = c;
            this.primitives = p;
            this.minWaitTime = minWaitTime;
            this.maxWaitTime = maxWaitTime;
            this.MaxRepeated = maxRepeated;
            this.operations = new List<Action<C, P>> {
                new Action<C,P>(ProvideOperation)
            };
        }

        // Lazy registration protocol: Julia calls opcode 0 with the method name and
        // expected canonical signature. RMIFor finds, validates, and compiles the method.
        // On success, the new handler is appended and its index (new opcode) is returned.
        // On failure, RMIFor writes the NOTOK error directly.
        //
        // The try-catch is the last line of defense for this handler: RMIFor
        // pre-validates the failure modes it knows about (missing method, canonical
        // mismatch, missing reader/writer) and answers NOTOK itself, but any exception
        // escaping here would leave the begun frame unfinished — the caller (Execute)
        // would never reach EndFrame, no response would ship, and the Julia client,
        // whose receive() has no timeout, would block forever. The frame is begun by
        // ReadOperation and ended by Execute, so the catch only writes the NOTOK
        // record into the buffered response (after resetting any partial bytes) and
        // lets Execute ship exactly one complete frame, as always.
        public void ProvideOperation(C c, P p) {
            var name = "<unknown>";
            try {
                name = c.rString();
                var expectedCanonical = c.rString();
                var action = RMIfy.RMIFor(c, p, name, expectedCanonical);
                if (action != null) {
                    operations.Add(action);
                    c.wByte(0);
                    c.wInt32(operations.Count - 1);
                }
                // Error already written by RMIFor (with NOTOK prefix) when action is null
            } catch (Exception e) {
                c.ResetResponse();
                c.wByte(1);
                c.wString($"Cannot register '{name}': {e.Message}\n{e.StackTrace}");
                c.Flush();
            }
        }

        public int ReadOperation() {
            try {
                if (!channel.BeginFrame()) return -1;
                return channel.rInt32();
            } catch (EndOfStreamException) {
                return -1;
            }
        }

        public virtual void Execute(int op) {
            // A stale/desynced opcode (e.g. after a reconnect without re-registration)
            // would index operations[] out of range and throw BEFORE the RMI delegate's
            // error handler runs, so no NOTOK frame is written and the Julia caller
            // blocks on receive(). Guard it and write a clean NOTOK response (the frame
            // is already begun by ReadOperation), matching RMIFy's error format.
            if (op < 0 || op >= operations.Count) {
                channel.wByte(1);
                channel.wString($"Unknown opcode {op}");
                channel.EndFrame();
                return;
            }
            operations[op](channel, primitives);
            channel.EndFrame();
        }

        public bool ReadAndExecute() {
            int op = ReadOperation();
            if (op == -1) return false;
            Execute(op);
            return true; //FIXME
        }

        // Poll briefly for a next frame, then read it whole. The two-step check is the
        // load-bearing part of the interactive design: the ONLY thing that ever waits
        // with a finite timeout is Socket.Poll, which consumes no bytes, so a timeout
        // can only happen BETWEEN frames; once a frame has begun it is read to
        // completion with blocking reads. (NetworkStream.ReadTimeout must never be
        // used for this — a mid-frame timeout discards partially-read bytes and
        // desyncs the wire protocol, and it corrupts stream state on Mono.)
        //
        // Returns -2 when the poll window elapsed with nothing (yield to the host),
        // -1 when the peer closed the connection (Poll fired but zero bytes are
        // buffered = FIN, or the frame read hit EOF/an I/O error), else the opcode.
        //
        // The FIN disambiguation is load-bearing: Socket.Poll(SelectRead) fires both
        // for readable bytes AND for a peer close. Reporting a close as -2 ("timeout")
        // is the bug that wedged idle-driven listeners like KhepriAutoCAD's PlugIn.cs
        // after a quick connect/close probe: the handler saw -2 on every tick, never
        // transitioned back to AcceptClient, and a real connection queued in the
        // kernel listen backlog was never picked up — the first operation after a
        // reconnect blocked forever on the Julia side.
        protected int PollThenReadOperation(int waitMilliseconds) {
            if (!channel.PollRead(waitMilliseconds * 1000))
                return -2;
            if (!channel.DataAvailable)
                return -1;
            try {
                return ReadOperation();
            } catch (IOException) {
                // A socket error while reading the frame: the connection is unusable;
                // report it as a disconnect rather than crashing the host's idle loop.
                return -1;
            }
        }

        // See PollThenReadOperation for the -2/-1/opcode semantics and the
        // reason a wedged AutoCAD-style listener needs the FIN disambiguation.
        public int TryReadOperation() =>
            PollThenReadOperation(minWaitTime);

        /*
         * Template-method hooks around the batch loop. Host plugins that must scope a
         * batch in application state (a document lock + transaction in AutoCAD, a
         * Transaction in Revit) override THESE instead of copying the loop — the two
         * historical copies each missed later loop fixes (Revit's `new`-hidden copy
         * kept a mid-frame ReadTimeout the base had retired; AutoCAD's drifted on the
         * batch-cap comparison).
         *
         * The hooks run on whichever thread runs the loop — the Idle-driven UI thread
         * in AutoCAD/Rhino, the ExternalEvent API thread in Revit — which is exactly
         * where host transaction scopes must live. BeginBatch returning false means
         * "the host cannot run a batch right now" (e.g. no open document) and is
         * reported as a disconnect, matching the historical AutoCAD behavior.
         * EndBatch runs in a finally, so host state is unwound even when an operation
         * or the transport throws mid-batch.
         */
        protected virtual bool BeginBatch() { return true; }
        protected virtual void BeforeOperation() { }
        protected virtual void EndBatch() { }

        // Batching: after executing one operation, keep executing subsequent ones
        // without returning control to the host application's message loop, so a burst
        // of RPC calls does not pay the host's per-idle-tick latency once per operation.
        //
        // The subtlety is how we decide there is a "next" operation. Execute has just
        // flushed this op's result; a synchronous client (Julia) must now read that
        // result and write its next request — a sub-millisecond localhost round-trip
        // during which NO bytes are buffered yet. A bare `DataAvailable` check loses
        // that race on essentially every operation, so the batch collapses to a single
        // op and control returns to the host loop, which then costs the host's idle
        // cadence (~66 ms/tick in Rhino, whose RhinoApp.Idle is slow) for the NEXT op.
        // Instead we WAIT up to maxWaitTime ms for the next op (PollRead); on localhost
        // the client turns the request around well within that window, so the loop keeps
        // spinning and the entire burst drains inside one idle tick. Only when the client
        // genuinely goes quiet (poll times out) do we leave the batch.
        public virtual bool ExecuteReadAndRepeat(int op) {
            if (op == -1) return false;
            if (!BeginBatch()) return false;
            int count = 0;
            try {
                while (true) {
                    if (op == -1) {
                        return false;
                    }
                    BeforeOperation();
                    Execute(op);
                    count++;
                    // Exact cap (>=, not >) and break (not return false): hitting the batch
                    // cap means "yield to the host idle loop, keep the connection", which the
                    // caller must not confuse with a real disconnect (op == -1).
                    if (count >= MaxRepeated) {
                        break;
                    }
                    // -2: the burst is over (poll window elapsed) — yield to the host
                    // loop, keep the connection. -1: peer closed or the socket died.
                    op = PollThenReadOperation(maxWaitTime);
                    if (op == -2) {
                        break;
                    }
                }
                return true;
            } finally {
                EndBatch();
            }
        }

        public virtual bool ReadAndExecuteAndRepeat() {
            // Between frames we wait via Socket.Poll; the frame reads themselves are
            // meant to block, so make sure no finite stream timeout is left armed.
            channel.EnsureBlockingReads();
            return ExecuteReadAndRepeat(ReadOperation());
        }
    }
}
