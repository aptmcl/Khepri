using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;
using System.IO;

namespace KhepriBase {
    public class Processor<C,P> where C : Channel where P : Primitives {
        protected C channel;
        protected P primitives;
        protected List<Action<C, P>> operations;

        public Processor(C c, P p) {
            this.channel = c;
            this.primitives = p;
            this.operations = new List<Action<C, P>> {
                new Action<C,P>(ProvideOperation)
            };
        }

        public void ProvideOperation(C c, P p) {
            var action = RMIfy.RMIFor(c, p, c.rString());
            if (action == null) {
                CleanChannel(c);
                c.wInt32(-1);
            } else {
                operations.Add(action);
                c.wInt32(operations.Count - 1);
            }
        }

        public void CleanChannel(C c) {
            //Clean the channel
            c.SetReadTimeout(5);
            try {
                for (;;) { c.rByte(); }
            } catch (IOException) {
                // Done cleaning
            } finally {
                c.SetReadTimeout(-1);
            }
        }

        public int ReadOperation() {
            try {
                return channel.rInt32();
            } catch (EndOfStreamException) {
                return -1;
            }
        }

        public virtual void Execute(int op) {
            operations[op](channel, primitives);
            channel.Flush();
        }

        public bool ReadAndExecute() {
            int op = ReadOperation();
            if (op == -1) return false;
            Execute(op);
            return true; //FIXME
        }

        public int TryReadOperation() {
            channel.SetReadTimeout(20);
            try {
                return ReadOperation();
            } catch (IOException) {
                return -2; //timeout
            } finally {
                channel.SetReadTimeout(-1);
            }
        }

        public virtual bool ExecuteReadAndRepeat(int op) {
            while (true) {
                if (op == -1) {
                    return false;
                }
                Execute(op);
                channel.SetReadTimeout(20);
                try {
                    op = ReadOperation();
                } catch (IOException) {
                    break;
                } finally {
                    channel.SetReadTimeout(-1);
                }
            }
            return true;
        }
    }
}
