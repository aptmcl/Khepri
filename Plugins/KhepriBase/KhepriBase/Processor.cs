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
        public void ProvideOperation(C c, P p) {
            var name = c.rString();
            var expectedCanonical = c.rString();
            var action = RMIfy.RMIFor(c, p, name, expectedCanonical);
            if (action != null) {
                operations.Add(action);
                c.wByte(0);
                c.wInt32(operations.Count - 1);
            }
            // Error already written by RMIFor (with NOTOK prefix) when action is null
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
        public int TryReadOperation() {
            if (!channel.PollRead(minWaitTime * 1000))
                return -2;
            if (!channel.DataAvailable)
                return -2;
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
                if (count > MaxRepeated) {
                    return false;
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
