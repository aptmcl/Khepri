using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using AcadApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace KhepriAutoCAD {

    /*
    Connection lifecycle. Previously this plugin ran the socket listener on
    a background thread and spawned per-client worker threads that read ops
    blockingly and marshalled execution to the UI thread via Control.Invoke.
    Killing the Julia process took AutoCAD down with it: when a worker
    thread hit an uncaught exception during disconnect (e.g. WriteMessage
    dereferencing a vanished MdiActiveDocument inside a catch block), the
    .NET runtime terminates the entire process for unhandled exceptions on
    non-UI threads — there is no analogue of the main-thread message pump
    to swallow them.

    KhepriRhinoceros never had this problem because it drives the server
    from RhinoApp.Idle on the main thread, using non-blocking socket polls
    and a small currentAction state machine. We adopt the same model here
    via Autodesk.AutoCAD.ApplicationServices.Application.Idle: the Idle
    handler dispatches to AcceptClient (waits for a TcpListener.Pending)
    or HandleClient (TryReadOperation → ExecuteReadAndRepeat). On socket
    EOF or IOException, HandleClient transitions back to AcceptClient
    instead of escaping the handler. Because everything runs on the UI
    thread, the only way AutoCAD can die is the user closing AutoCAD.

    Why not just harden the threaded version? The worker thread design
    forced us to use Control.Invoke for every operation, which converts
    every exception into a TargetInvocationException whose Inner can leak
    on the worker thread side — fragile to keep correct. Single-threaded
    Idle-driven I/O eliminates the marshaling entirely.

    See also: KhepriRhinocerosCommand.cs for the reference implementation.
    */
    public class PlugIn : IExtensionApplication {

        // syncCtrl is retained as a static convenience for any legacy code
        // that may still want a WinForms control for thread marshalling
        // (none in the current plugin), and to keep the Processor signature
        // stable. Created on the main thread during Initialize.
        public static System.Windows.Forms.Control syncCtrl;

        TcpListener server;
        Processor processor;
        Action currentAction;
        bool idleSubscribed = false;

        public void Initialize() {
            syncCtrl = new System.Windows.Forms.Control();
            syncCtrl.CreateControl();
        }

        public void Terminate() {
            UnsubscribeIdle();
            try { server?.Stop(); } catch { }
            server = null;
        }

        [CommandMethod("KHEPRI")]
        public void KHEPRI() {
            StartServer();
        }

        void StartServer() {
            try {
                if (server == null) {
                    server = new TcpListener(IPAddress.Parse("127.0.0.1"), 11000);
                    server.Start();
                }
                WriteMessage("Waiting for connection\n");
                processor = null;
                currentAction = AcceptClient;
                SubscribeIdle();
            } catch (System.Exception e) {
                WriteMessage("Failed to start server: " + e + "\n");
            }
        }

        void SubscribeIdle() {
            if (!idleSubscribed) {
                AcadApp.Idle += OnIdle;
                idleSubscribed = true;
            }
        }

        void UnsubscribeIdle() {
            if (idleSubscribed) {
                AcadApp.Idle -= OnIdle;
                idleSubscribed = false;
            }
        }

        // The Idle event fires on the main UI thread whenever AutoCAD's
        // message pump has no input to process. Any exception escaping
        // here is caught and recovered into the Accept state so a single
        // bad operation cannot strand the listener.
        void OnIdle(object sender, EventArgs e) {
            try {
                currentAction?.Invoke();
            } catch (System.Exception ex) {
                WriteMessage("Idle handler error: " + ex + "\n");
                processor = null;
                currentAction = AcceptClient;
            }
        }

        void AcceptClient() {
            if (server == null) return;
            if (server.Pending()) {
                var client = server.AcceptTcpClient();
                client.NoDelay = true;
                var channel = new Channel(client.GetStream(), client.Client);
                processor = new Processor(syncCtrl, channel, new Primitives());
                WriteMessage("Connection established\n");
                currentAction = HandleClient;
            }
        }

        void HandleClient() {
            if (processor == null) {
                currentAction = AcceptClient;
                return;
            }
            // Do not consume an op while the user is mid-command. Posting
            // ESC here cancels ORBIT/PAN/ZOOM/etc.; the message is pumped
            // after we return from this Idle tick and the next tick sees
            // a quiescent editor. Reading before quiescence would either
            // execute under a held doc lock (deadlocking the UI thread on
            // itself) or buffer ops out of order with the wire stream.
            var doc = AcadApp.DocumentManager.MdiActiveDocument;
            if (doc == null) return;
            if (!doc.Editor.IsQuiescent) {
                processor.CancelActiveCommand();
                return;
            }
            try {
                int op = processor.TryReadOperation();
                if (op == -1) {
                    WriteMessage("Connection terminated\n");
                    WriteMessage("Waiting for connection\n");
                    processor = null;
                    currentAction = AcceptClient;
                } else if (op == -2) {
                    // No data within poll window; wait for the next Idle tick.
                } else {
                    processor.ExecuteReadAndRepeat(op);
                }
            } catch (IOException) {
                WriteMessage("Client disconnected\n");
                WriteMessage("Waiting for connection\n");
                processor = null;
                currentAction = AcceptClient;
            } catch (System.Exception ex) {
                WriteMessage("Handler error: " + ex + "\n");
                processor = null;
                currentAction = AcceptClient;
            }
        }

        // Best-effort write to the AutoCAD command line. Never throws so it
        // is safe to call from catch blocks during disconnect/shutdown when
        // the active document may be transitioning.
        public void WriteMessage(string msg) {
            try {
                var doc = AcadApp.DocumentManager.MdiActiveDocument;
                if (doc != null) {
                    doc.Editor.WriteMessage(msg);
                }
            } catch { /* document closing or unavailable */ }
        }
    }
}
