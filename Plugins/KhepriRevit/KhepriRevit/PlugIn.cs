using Autodesk.Revit.DB.Events;
using Autodesk.Revit.UI;
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using Application = Autodesk.Revit.ApplicationServices.Application;

namespace KhepriRevit {

    using RevitProcessor = Processor<Channel, Primitives>;

    class NativeMethods {
        [DllImport("user32.dll")]
        internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        internal static extern bool SetForegroundWindow(IntPtr hWnd);
    }

    public class ClientHandler : IExternalEventHandler {
        public int op;
        public bool result = true;
        public ManualResetEvent resumeEvt = new ManualResetEvent(false);
        public RevitProcessor processor;

        public void Execute(UIApplication uiapp) {
            try {
                result = processor.ExecuteReadAndRepeat(op);
                resumeEvt.Set();
            } catch (Exception e) {
                PlugIn.WriteMessage(e.Message + e.StackTrace);
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
                //WriteMessage("Waiting for connections\n");
                while (true)
                {
                    var client = server.AcceptTcpClient();
                    client.NoDelay = true;
                    RevitProcessor processor =
                        new RevitProcessor(
                            thisUIapp,
                            new Channel(thisUIapp, client.GetStream(), client.Client),
                            new Primitives(thisUIapp))
                        ;
                    HandleClient(c, evt, processor);
                }
            } catch (Exception e) {
                WriteMessage(e.ToString() + "\n");
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
                //WriteMessage("Client disconnected\n");
            } catch (IOException e) {
                WriteMessage(e.ToString() + "\n");
                //WriteMessage("Disconneting from client\n");
            } catch (Exception e) {
                WriteMessage(e.ToString() + "\n");
                //WriteMessage("Terminating client\n");
            }
        }

        public static void WriteMessage(String msg) {
            MessageBox.Show(msg);
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
            application.ControlledApplication.DocumentCreated += OnDocumentCreated;
            application.ControlledApplication.DocumentOpened += OnDocumentOpened;
            return Result.Succeeded;
        }

        void OnDocumentOpenedOrCreated(object sender) {
            if (thisUIapp == null) {
                Application app = sender as Application;
                thisUIapp = new UIApplication(app);
                ClientHandler cli = new ClientHandler();
                ExternalEvent evt = ExternalEvent.Create(cli);
                Thread thread = new Thread(() => WaitForConnections(cli, evt));
                thread.Start();
            }
        }

        void OnDocumentCreated(object sender, DocumentCreatedEventArgs e) => OnDocumentOpenedOrCreated(sender);
        void OnDocumentOpened(object sender, DocumentOpenedEventArgs e) => OnDocumentOpenedOrCreated(sender);

        public Result OnShutdown(UIControlledApplication application) {
            return Result.Succeeded;
        }
    }
}
