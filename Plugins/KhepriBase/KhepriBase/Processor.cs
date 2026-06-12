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

        // Uses Socket.Poll + DataAvailable instead of NetworkStream.ReadTimeout,
        // which is broken on Mono/Linux (corrupts stream state on timeout).
        //
        // Disambiguating Poll=true: Socket.Poll(SelectRead) returns true in two
        // distinct cases — bytes are available OR the peer closed the connection
        // (FIN). The DataAvailable check below tells them apart. If Poll fires
        // but no bytes are buffered, the connection has been closed gracefully
        // and we must return -1 (disconnected). Returning -2 ("timeout") here
        // is the bug that wedges idle-driven listeners like KhepriAutoCAD's
        // current PlugIn.cs after a quick connect/close probe: the handler
        // sees -2 on every subsequent tick, never transitions to AcceptClient,
        // and any real connection queued behind the closed one in the kernel
        // listen backlog is never picked up. Symptom on the Julia side: the
        // first operation after reconnect blocks forever.
        public int TryReadOperation() {
            if (!channel.PollRead(minWaitTime * 1000))
                return -2;
            if (!channel.DataAvailable)
                return -1;
            return ReadOperation();
        }

        // Batching optimization: after executing one operation, checks if more data
        // is immediately available and keeps executing without returning control to
        // the host application's message loop. This reduces per-call overhead for
        // burst sequences of RPC calls.
        public virtual bool ExecuteReadAndRepeat(int op) {
            int count = 0;
            while (true) {
                if (op == -1) {
                    return false;
                }
                Execute(op);
                count++;
                // Exact cap (>=, not >) and break (not return false): hitting the batch
                // cap means "yield to the host idle loop, keep the connection", which the
                // caller must not confuse with a real disconnect (op == -1).
                if (count >= MaxRepeated) {
                    break;
                }
                if (!channel.DataAvailable) {
                    break;
                }
                op = ReadOperation();
            }
            return true;
        }

        public virtual bool ReadAndExecuteAndRepeat() {
            //We can safely wait forever
            channel.SetReadTimeout(-1);
            return ExecuteReadAndRepeat(ReadOperation());
        }
    }
}
