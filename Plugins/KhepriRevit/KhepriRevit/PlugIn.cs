using Autodesk.Revit.DB.Events;
using Autodesk.Revit.UI;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading;
using Application = Autodesk.Revit.ApplicationServices.Application;

namespace KhepriRevit {

    using RevitProcessor = Processor<Channel, Primitives>;

    class NativeMethods {
        [DllImport("user32.dll")]
        internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        internal static extern bool SetForegroundWindow(IntPtr hWnd);
    }

    /* ExternalEvent handler that runs queued RPC batches on Revit's API thread.
     *
     * The control flow between this handler and `WaitForConnections`/`HandleClient`
     * is intentionally simple: the listener thread reads an opcode, raises the
     * ExternalEvent, then blocks on `resumeEvt` until Revit's API thread finishes
     * processing the batch and signals completion. The two threads are coupled
     * exclusively through `resumeEvt`. If `Execute` ever returns without setting
     * the event — including after an exception — the listener parks on
     * `resumeEvt.WaitOne()` forever and the connection appears hung from Julia's
     * side, even though the underlying socket is still alive.
     *
     * That's exactly what happened when an RPC carrying an `object[]` parameter
     * tripped an `AmbiguousMatchException` inside RMIfy codegen: the exception
     * propagated out of `ExecuteReadAndRepeat`, the catch block logged it, and
     * the listener was left waiting on an event no one would ever set.
     *
     * The fix is to put the signal in `finally` so it runs on every exit path.
     * `result` is left at its previous value (true) on exception, which lets the
     * listener loop continue serving the next request — RMIfy already wrote a
     * NOTOK frame for caught errors; for codegen errors that escape RMIfy, the
     * Julia side will surface the failure on its next read.
     *
     * See also: `KhepriBase.RMIfy.GetMethod` for the codegen-time lookup that was
     * the original throw site.
     */
    public class ClientHandler : IExternalEventHandler {
        public int op;
        public bool result = true;
        public ManualResetEvent resumeEvt = new ManualResetEvent(false);
        public RevitProcessor processor;

        public void Execute(UIApplication uiapp) {
            try {
                result = processor.ExecuteReadAndRepeat(op);
            } catch (Exception e) {
                PlugIn.WriteMessage(e.Message + e.StackTrace);
            } finally {
                resumeEvt.Set();
            }
        }
        public string GetName() {
            return "Khepri Handler";
        }
    }

    public class PlugIn : IExternalApplication {
        private static UIApplication thisUIapp = null;

        void WaitForConnections(ClientHandler c, ExternalEvent evt)
        {
            try
            {
                Int32 port = 11001;
                IPAddress localAddr = IPAddress.Parse("127.0.0.1");
                TcpListener server = new TcpListener(localAddr, port);
                server.Start();
                WriteMessage($"WaitForConnections: listening on 127.0.0.1:{port}");
                while (true)
                {
                    var client = server.AcceptTcpClient();
                    client.NoDelay = true;
                    WriteMessage($"WaitForConnections: client accepted from {client.Client.RemoteEndPoint}");
                    RevitProcessor processor =
                        new RevitProcessor(
                            thisUIapp,
                            new Channel(thisUIapp, client.GetStream(), client.Client),
                            new Primitives(thisUIapp))
                        ;
                    HandleClient(c, evt, processor);
                }
            } catch (Exception e) {
                WriteMessage($"WaitForConnections: terminated with exception: {e.GetType().Name}: {e.Message}\n{e.StackTrace}");
            }
        }

        void HandleClient(ClientHandler c, ExternalEvent evt, RevitProcessor processor) {
            c.processor = processor;
            try {
                while (true) {
                    c.op = processor.ReadOperation();
                    c.resumeEvt.Reset();
                    evt.Raise();
                    c.resumeEvt.WaitOne();
                    if (!c.result) break;
                }
                WriteMessage("HandleClient: client disconnected normally");
            } catch (IOException e) {
                WriteMessage($"HandleClient: IO exception (client likely disconnected): {e.Message}");
            } catch (Exception e) {
                WriteMessage($"HandleClient: unexpected exception: {e.GetType().Name}: {e.Message}\n{e.StackTrace}");
            }
        }

        // Logging sink for plugin-side errors and debug messages.
        // Previously this opened a modal MessageBox, which (a) blocked the Revit UI
        // thread on every transient socket / family-load error, and (b) hid the actual
        // error text from the Julia caller (the exception still propagated through the
        // Channel error frame, but the modal made the failure look like a freeze).
        // Now we write to Trace and append to a per-session log file under %TEMP%; the
        // exception still propagates back to Julia via the catch in
        // ClientHandler.Execute / Processor.ExecuteReadAndRepeat.
        public static void WriteMessage(String msg) {
            Trace.WriteLine(msg);
            try {
                File.AppendAllText(
                    Path.Combine(Path.GetTempPath(), "KhepriRevit.log"),
                    $"[{DateTime.Now:O}] {msg}\n");
            } catch {
                // logging is best-effort; never let a logging failure mask the original error
            }
        }

        public struct MyLevel {
            public string name;
            public double height;

            public MyLevel(string n, double h) {
                name = n;
                height = h;
            }
        }

        public Result OnStartup(UIControlledApplication application) {
            try {
                WriteMessage($"OnStartup: KhepriRevit plugin loading. Revit={application.ControlledApplication.VersionNumber}, AssemblyLocation={typeof(PlugIn).Assembly.Location}");
                application.ControlledApplication.DocumentCreated += OnDocumentCreated;
                application.ControlledApplication.DocumentOpened += OnDocumentOpened;
                // App-level warning swallower: covers EVERY transaction, including the mid-operation
                // CurrentTransaction.Commit()/Start() restarts (wall-then-door, etc.) that the
                // per-transaction WarningSwallower doesn't re-attach to. Benign warnings (overlapping
                // walls, etc.) are auto-dismissed dialog-free; errors are left to surface to Julia.
                application.ControlledApplication.FailuresProcessing += OnFailuresProcessing;
                application.ControlledApplication.DocumentChanged += OnDocumentChanged;
                // Auto-dismiss startup/task dialogs (version-upgrade prompts, missing links/worksets,
                // etc.) so a script-launched Revit reaches a usable state without manual clicks.
                // Registered on the UI app at startup so it fires for document-open dialogs too.
                application.DialogBoxShowing += OnDialogBoxShowing;
                WriteMessage("OnStartup: event handlers registered, returning Result.Succeeded");
                return Result.Succeeded;
            } catch (Exception e) {
                WriteMessage($"OnStartup: exception: {e.GetType().Name}: {e.Message}\n{e.StackTrace}");
                throw;
            }
        }

        void OnDocumentOpenedOrCreated(object sender) {
            try {
                WriteMessage($"OnDocumentOpenedOrCreated: thisUIapp == null? {thisUIapp == null}");
                if (thisUIapp == null) {
                    Application app = sender as Application;
                    thisUIapp = new UIApplication(app);
                    WriteMessage("OnDocumentOpenedOrCreated: UIApplication wrapped, creating ClientHandler + ExternalEvent");
                    ClientHandler cli = new ClientHandler();
                    ExternalEvent evt = ExternalEvent.Create(cli);
                    WriteMessage("OnDocumentOpenedOrCreated: starting WaitForConnections thread");
                    Thread thread = new Thread(() => WaitForConnections(cli, evt));
                    thread.IsBackground = true;
                    thread.Start();
                    WriteMessage("OnDocumentOpenedOrCreated: thread started");
                } else {
                    WriteMessage("OnDocumentOpenedOrCreated: already initialized, skipping");
                }
            } catch (Exception e) {
                WriteMessage($"OnDocumentOpenedOrCreated: exception: {e.GetType().Name}: {e.Message}\n{e.StackTrace}");
                throw;
            }
        }

        void OnDocumentCreated(object sender, DocumentCreatedEventArgs e) {
            WriteMessage($"OnDocumentCreated: doc='{e.Document?.Title}'");
            OnDocumentOpenedOrCreated(sender);
        }
        void OnDocumentOpened(object sender, DocumentOpenedEventArgs e) {
            WriteMessage($"OnDocumentOpened: doc='{e.Document?.Title}'");
            OnDocumentOpenedOrCreated(sender);
        }

        // Deletion forensics: element ids silently disappearing (failure resolutions, rollbacks,
        // join cascades) are otherwise undiagnosable. Logs at most 30 ids per change event.
        void OnDocumentChanged(object sender, Autodesk.Revit.DB.Events.DocumentChangedEventArgs e) {
            try {
                var del = e.GetDeletedElementIds();
                if (del.Count > 0)
                    WriteMessage("OnDocumentChanged: txn='" + string.Join(",", e.GetTransactionNames()) +
                        "' deleted " + del.Count + ": " +
                        string.Join(",", del.Take(30).Select(id => id.Value)));
            } catch { }
        }

        // Delete every Warning-severity failure so script-driven rebuilds are dialog-free, and
        // RESOLVE error-severity failures with their default resolution. Leaving errors alone
        // (Continue) does NOT surface them to the caller: the RPC replies were already sent when
        // the batched 'Execute' transaction commits, so Revit rolls the whole transaction back
        // SILENTLY, evaporating every element created in the batch (observed: a group whose
        // member walls overlap collinearly lost all its members with no deletion events).
        // Resolving instead applies a targeted fix (typically deleting one offending element).
        void OnFailuresProcessing(object sender, Autodesk.Revit.DB.Events.FailuresProcessingEventArgs e) {
            Autodesk.Revit.DB.FailuresAccessor fa = e.GetFailuresAccessor();
            bool deleted = false, hasError = false, resolved = true;
            foreach (Autodesk.Revit.DB.FailureMessageAccessor f in fa.GetFailureMessages()) {
                if (f.GetSeverity() == Autodesk.Revit.DB.FailureSeverity.Warning) {
                    fa.DeleteWarning(f);
                    deleted = true;
                } else {
                    hasError = true;
                    var failingIds = new List<Autodesk.Revit.DB.ElementId>();
                    try { failingIds.AddRange(f.GetFailingElementIds()); } catch { }
                    try {
                        WriteMessage("OnFailuresProcessing: error '" + f.GetDescriptionText() +
                            "' resolutions=" + f.HasResolutions() +
                            " ids=" + string.Join(",", failingIds));
                    } catch { }
                    if (f.HasResolutions())
                        fa.ResolveFailure(f);
                    else if (failingIds.Count > 0)
                        // Unresolvable error: sacrifice the offending element(s) so the
                        // batched transaction commits; letting it roll back evaporates
                        // every element in the batch silently. The ids logged above name
                        // the culprit for the conformance ledger to flag.
                        try { fa.DeleteElements(failingIds); } catch { resolved = false; }
                    else
                        resolved = false;
                }
            }
            e.SetProcessingResult(
                hasError
                    ? (resolved ? Autodesk.Revit.DB.FailureProcessingResult.ProceedWithCommit
                                : Autodesk.Revit.DB.FailureProcessingResult.Continue)
                    : (deleted ? Autodesk.Revit.DB.FailureProcessingResult.ProceedWithCommit
                               : Autodesk.Revit.DB.FailureProcessingResult.Continue));
        }

        // Dismiss any dialog Revit tries to show (upgrade prompts, missing links, worksets, audit
        // notices, etc.) by overriding its result with a "proceed/close" value, so an automated,
        // script-launched Revit never blocks on a modal. The DialogId is logged for diagnosis.
        void OnDialogBoxShowing(object sender, Autodesk.Revit.UI.Events.DialogBoxShowingEventArgs e) {
            try {
                WriteMessage($"OnDialogBoxShowing: auto-dismissing dialog id='{e.DialogId}'");
                if (e is Autodesk.Revit.UI.Events.TaskDialogShowingEventArgs td) {
                    td.OverrideResult((int)TaskDialogResult.Ok);
                } else {
                    e.OverrideResult(1); // IDOK
                }
            } catch (Exception ex) {
                WriteMessage($"OnDialogBoxShowing: failed for '{e.DialogId}': {ex.Message}");
            }
        }

        public Result OnShutdown(UIControlledApplication application) {
            WriteMessage("OnShutdown: KhepriRevit plugin unloading");
            return Result.Succeeded;
        }
    }
}
