using System.Text;
using System.Threading.Tasks;
using System.IO;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.EditorInput;
using System.Threading;
using System;

namespace KhepriAutoCAD {
    public class Processor : KhepriBase.Processor<Channel,Primitives> {

        System.Windows.Forms.Control sync;
        public Transaction tr;
        public Document doc;

        public Processor(System.Windows.Forms.Control sync, Channel c, Primitives p) : base(c, p) {
            this.sync = sync;
            c.processor = this;
            p.processor = this;
        }

        public override void Execute(int op) {
            sync.Invoke(operations[op], new object[] { channel, primitives });
            channel.Flush();
        }

        public override bool ExecuteReadAndRepeat(int op) {
            Action<Processor, int> action = (proc, oper) => { proc.ExecuteReadAndRepeatInMainThread(oper); };
            sync.Invoke(action, new object[] { this, op });
            return true;
        }

        public bool ExecuteReadAndRepeatInMainThread(int op) {
            if (op == -1) {
                return false;
            } else {
                doc = Application.DocumentManager.MdiActiveDocument;
                using (doc.LockDocument()) {
                    // Don't use using (no pun intended) because it might be changed during the loop
                    tr = doc.Database.TransactionManager.StartOpenCloseTransaction();
                    int count = 0;
                    try {
                        while (true) {
                            if (op == -1) {
                                return false;
                            } else {
                                while (!doc.Editor.IsQuiescent) { Thread.Sleep(10); }
                                operations[op](channel, primitives);
                                channel.Flush();
                                count++;
                                if (count > MaxRepeated) {
                                    break;
                                }
                                channel.SetReadTimeout(maxWaitTime);
                                try {
                                    op = ReadOperation();
                                } catch (IOException) {
                                    break;
                                } finally {
                                    channel.SetReadTimeout(-1);
                                }
                            }
                        }
                        return true;
                    } finally {
                        CommitAndStop();
                    }
                }
            }
        }

        public void CommitAndStop() {
            tr.Commit();
            tr.Dispose();
            doc.Editor.Regen();
        }
        public void CommitAndStartTransaction() {
            CommitAndStop();
            tr = doc.Database.TransactionManager.StartTransaction();
        }

        public void CommitAndStartOpenCloseTransaction() {
            CommitAndStop();
            tr = doc.Database.TransactionManager.StartOpenCloseTransaction();
        }
    }
}
