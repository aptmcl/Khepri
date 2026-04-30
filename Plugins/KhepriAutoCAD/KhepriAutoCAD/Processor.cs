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

        const uint WM_KEYDOWN = 0x0100;
        const uint WM_KEYUP = 0x0101;
        const int VK_ESCAPE = 0x1B;

        public Processor(System.Windows.Forms.Control sync, Channel c, Primitives p) : base(c, p) {
            this.sync = sync;
            c.processor = this;
            p.processor = this;
        }

        // Cancel any active interactive command (ORBIT, PAN, ZOOM, etc.) by posting
        // ESC keystrokes to AutoCAD's main window. Called from the client thread
        // BEFORE sync.Invoke so the main thread stays free to process the ESC.
        void CancelActiveCommand(int timeoutMs = 2000) {
            Document currentDoc;
            try {
                currentDoc = Application.DocumentManager.MdiActiveDocument;
            } catch {
                return;
            }
            if (currentDoc == null || currentDoc.Editor.IsQuiescent) return;
            IntPtr hwnd = Application.MainWindow.Handle;
            // Two ESC pairs to cancel nested command states
            for (int i = 0; i < 2; i++) {
                NativeMethods.PostMessage(hwnd, WM_KEYDOWN, (IntPtr)VK_ESCAPE, IntPtr.Zero);
                NativeMethods.PostMessage(hwnd, WM_KEYUP, (IntPtr)VK_ESCAPE, IntPtr.Zero);
            }
            // Poll on the client thread while the main thread processes the ESC
            int elapsed = 0;
            while (elapsed < timeoutMs) {
                Thread.Sleep(10);
                elapsed += 10;
                try {
                    if (currentDoc.Editor.IsQuiescent) return;
                } catch {
                    return;
                }
            }
        }

        public override void Execute(int op) {
            CancelActiveCommand();
            sync.Invoke(operations[op], new object[] { channel, primitives });
            channel.EndFrame();
        }

        public override bool ExecuteReadAndRepeat(int op) {
            CancelActiveCommand();
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
                                operations[op](channel, primitives);
                                channel.EndFrame();
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
