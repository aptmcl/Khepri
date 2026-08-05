using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Autodesk.Revit.DB;
using Autodesk.Revit.UI;
using System.IO;

namespace KhepriRevit {
    public class Processor<C,P> : KhepriBase.Processor<C,P> where C : Channel where P : Primitives {

        public UIApplication uiApp;

        public Processor(UIApplication uiApp, C c, P p) : base(c, p) {
            this.uiApp = uiApp;
        }

        /*
         * The batch loop itself is the base class's — this used to be a `new`-hidden
         * copy, which meant every base-loop fix since 2026-03 (poll batching, FIN
         * disambiguation, the retirement of mid-frame ReadTimeout) was dead code for
         * Revit, and its own SetReadTimeout(20) around ReadOperation could time out
         * INSIDE a frame, desyncing the wire protocol. Now Revit only scopes the
         * batch in a Transaction via the hooks. They run on the thread that runs the
         * loop — the ExternalEvent API thread (see PlugIn.cs ClientHandler.Execute) —
         * which is where Revit transactions must live. The interactive contract is
         * unchanged: waiting happens in the base's Socket.Poll between frames, never
         * inside one.
         */
        protected override bool BeginBatch() {
            primitives.EnsureTransaction(uiApp);
            return true;
        }

        // Per-op re-check detects a document switch (user opened/created a new
        // project mid-batch); EnsureTransaction is idempotent on the same document.
        protected override void BeforeOperation() {
            primitives.EnsureTransaction(uiApp);
        }

        protected override void EndBatch() {
            primitives.CommitAndDisposeTransaction();
        }
    }
}
