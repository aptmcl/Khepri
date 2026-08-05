using System;
using System.IO;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;

namespace KhepriAutoCAD {
    /*
    Single-thread execution model. The plugin is driven from
    Application.Idle (see PlugIn.cs) so both socket reads and document
    mutations happen on the AutoCAD UI thread. That removes two sources
    of fragility that the previous Control.Invoke-based design had:

      1. No worker thread → no uncaught-exception-kills-the-process path.
      2. No cross-thread document access → LockDocument is taken as a
         hygiene measure (in case AutoCAD itself starts a command between
         ticks) but is no longer load-bearing for correctness.

    What we still need:
      - A document lock + transaction scope per batch, so a sequence of
        ops from Julia (b_box; b_sphere; b_subtraction) reads/writes
        through one consistent transaction and is committed atomically.
      - The ability to preempt a quiescence-blocking interactive command
        (ORBIT, PAN, ZOOM, …) that the user started before Julia issued
        an op. CancelActiveCommand just posts ESC and returns; the caller
        must yield (return from the Idle handler) so the message pump can
        deliver the ESC, and re-check quiescence on the next tick. This
        is why PlugIn.HandleClient checks IsQuiescent BEFORE reading an
        op rather than after: if we read first we would either have to
        execute under a held command (undefined behaviour) or buffer the
        op and reorder it relative to the wire stream.

    See also: PlugIn.cs HandleClient for the call site.
    */
    public class Processor : KhepriBase.Processor<Channel,Primitives> {

        public Transaction tr;
        public Document doc;
        DocumentLock docLock;

        const uint WM_KEYDOWN = 0x0100;
        const uint WM_KEYUP = 0x0101;
        const int VK_ESCAPE = 0x1B;

        // The `sync` parameter is kept for source compatibility with the
        // previous threaded design; nothing inside Processor uses it now
        // because we already run on the UI thread.
        public Processor(System.Windows.Forms.Control sync, Channel c, Primitives p) : base(c, p) {
            c.processor = this;
            p.processor = this;
        }

        // Post ESC to AutoCAD's main window to break any interactive
        // command the user has started. Because we run on the UI thread
        // we cannot wait for the message to be processed in this tick;
        // the caller must return from the Idle handler so the pump can
        // deliver the ESC. The next Idle tick will see a quiescent editor.
        public void CancelActiveCommand() {
            Document currentDoc;
            try {
                currentDoc = Application.DocumentManager.MdiActiveDocument;
            } catch {
                return;
            }
            if (currentDoc == null || currentDoc.Editor.IsQuiescent) return;
            IntPtr hwnd = Application.MainWindow.Handle;
            // Two ESC pairs to cancel nested command states.
            for (int i = 0; i < 2; i++) {
                NativeMethods.PostMessage(hwnd, WM_KEYDOWN, (IntPtr)VK_ESCAPE, IntPtr.Zero);
                NativeMethods.PostMessage(hwnd, WM_KEYUP, (IntPtr)VK_ESCAPE, IntPtr.Zero);
            }
        }

        /*
         * The batch loop itself is the base class's — this used to be a wholesale
         * copy (kept only to wrap the batch in a document lock + transaction), and
         * the copy had already drifted from the base (`count > MaxRepeated` vs the
         * base's exact `count >= MaxRepeated`; the 2026-07 poll-batching fix had to
         * be applied to both copies separately). Now AutoCAD only scopes the batch
         * via the hooks; polling, batching, FIN disambiguation, and the opcode
         * guard all come from the base. The interactive contract is unchanged:
         * waiting happens in the base's Socket.Poll between frames, never inside
         * a frame.
         */
        protected override bool BeginBatch() {
            doc = Application.DocumentManager.MdiActiveDocument;
            // No open document: report as "cannot run a batch" (historical behavior
            // treated this as a disconnect and dropped the client).
            if (doc == null) return false;
            docLock = doc.LockDocument();
            try {
                tr = doc.Database.TransactionManager.StartOpenCloseTransaction();
            } catch {
                docLock.Dispose();
                docLock = null;
                throw;
            }
            return true;
        }

        protected override void EndBatch() {
            try {
                CommitAndStop();
            } finally {
                docLock?.Dispose();
                docLock = null;
            }
        }

        public void CommitAndStop() {
            var t = tr;
            tr = null;   // clear first so a disposed transaction can never be reused
            if (t != null) {
                try {
                    t.Commit();
                } catch (System.Exception e) {
                    // A failed commit must NOT be silent — the client already received per-op OK
                    // frames, so its geometry would vanish with no signal — and must NOT skip the
                    // Dispose below, which would leak the transaction and keep the document lock.
                    // Report it to the command line and still dispose.
                    doc?.Editor.WriteMessage("\nKhepri: transaction commit failed: " + e.Message + "\n");
                } finally {
                    t.Dispose();
                }
            }
            try { doc?.Editor.Regen(); } catch { /* Regen is a cosmetic redraw; never let it break the batch */ }
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
