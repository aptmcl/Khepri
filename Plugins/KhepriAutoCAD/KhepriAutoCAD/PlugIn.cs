using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;

namespace KhepriAutoCAD {

    public class PlugIn : IExtensionApplication {
        //public delegate void Action();
        public delegate Entity ShapeCreator(Channel c);
        public delegate List<Entity> ShapesCreator(Channel c);
        public delegate void ShapeGetter(Entity ent, Channel c);

        static System.Windows.Forms.Control syncCtrl;
        TcpListener server;

        public void Initialize() {
            // The control created to help with marshaling
            // needs to be created on the main thread
            syncCtrl = new System.Windows.Forms.Control();
            syncCtrl.CreateControl();
        }

        public void Terminate() {
        }

        void WaitForConnections() {
            try {
                if (server == null) {
                    Int32 port = 11000;
                    IPAddress localAddr = IPAddress.Parse("127.0.0.1");
                    server = new TcpListener(localAddr, port);
                } else {
                    server.Stop();
                }
                server.Start();
                WriteMessage("Waiting for connections\n");
                while (true) {
                    Processor processor =
                        new Processor(
                            syncCtrl,
                            new Channel(server.AcceptTcpClient().GetStream()),
                            new Primitives());
                    WriteMessage("Connection established\n");
                    Thread thread = new Thread(() => HandleClient(processor));
                    thread.Start();
                }
            }
            catch (System.Exception e) {
                WriteMessage(e.ToString() + "\n");
            }

        }
        void HandleClient(Processor processor) {
            try {
                while (true) {
                    if (! processor.ReadAndExecuteAndRepeat()) break;
                }
                WriteMessage("Client disconnected\n");
            }
            catch (IOException) {
                WriteMessage("Disconneting from client\n");
            }
            catch (System.Exception e) {
                WriteMessage(e.ToString() + "\n");
                WriteMessage("Terminating client\n");
            }
        }

        public void WriteMessage(String msg) {
            Editor ed = Application.DocumentManager.MdiActiveDocument.Editor;
            syncCtrl.Invoke(new Action(() => ed.WriteMessage(msg)));
        }

        [CommandMethod("KHEPRI")]
        public void KHEPRI() {
            Thread thread = new Thread(() => WaitForConnections());
            thread.Start();
        }
    }
}
