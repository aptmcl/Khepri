using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;

using Rhino;
using Rhino.Commands;
using Rhino.Geometry;
using Rhino.Input;
using Rhino.Input.Custom;
using Rhino.PlugIns;
using KhepriBase;

namespace KhepriRhinoceros {
    [System.Runtime.InteropServices.Guid("2714b22e-b1fe-4065-b58e-91599142bbf9")]
    public class KhepriRhinocerosCommand : Command {

        static System.Windows.Forms.Control syncCtrl;
        TcpListener server;
        RhinoDoc doc;
        Processor<Channel, Primitives> processor;

        public KhepriRhinocerosCommand() {
            // Rhino only creates one instance of each command class defined in a
            // plug-in, so it is safe to store a reference in a static property.
            Instance = this;
            // The control created to help with marshaling
            // needs to be created on the main thread
            syncCtrl = new System.Windows.Forms.Control();
            syncCtrl.CreateControl();
        }

        ///<summary>The only instance of this command.</summary>
        public static KhepriRhinocerosCommand Instance {
            get; private set;
        }

        ///<returns>The command name as it appears on the Rhino command line.</returns>
        public override string EnglishName {
            get { return "Khepri"; }
        }

        /*
                void WaitForConnections(RhinoDoc doc) {
                    try {
                        Int32 port = 12000;
                        IPAddress localAddr = IPAddress.Parse("127.0.0.1");
                        TcpListener server = new TcpListener(localAddr, port);
                        server.Start();
                        WriteMessage("Waiting for connections\n");
                        while (true) {
                            processor = new Processor<Channel, Primitives>(new Channel(server.AcceptTcpClient().GetStream()), new Primitives(doc));
                            WriteMessage("Connection established\n");
                            Thread thread = new Thread(() => HandleClient(doc, c));
                            thread.Start();
                        }
                    } catch (System.Exception e) {
                        WriteMessage(e.ToString() + "\n");
                    }

                }
                void HandleClient(RhinoDoc doc, Channel c) {
                    try {
                        while (true) {
                            if (!c.ReadAndExecute()) break;
                            doc.Views.Redraw();
                        }
                        WriteMessage("Client disconnected\n");
                    } catch (IOException) {
                        WriteMessage("Disconneting from client\n");
                    } catch (System.Exception e) {
                        WriteMessage(e.ToString() + "\n");
                        WriteMessage("Terminating client\n");
                    }
                    c.Terminate();
                }

                public void WriteMessage(String msg) {
                    syncCtrl.Invoke(new Action(() => RhinoApp.WriteLine(msg)));
                }
        */
        protected override Result RunCommand(RhinoDoc doc, RunMode mode) {
            if (server == null) {
                Int32 port = 12000;
                IPAddress localAddr = IPAddress.Parse("127.0.0.1");
                server = new TcpListener(localAddr, port);
            } else {
                server.Stop();
                RhinoApp.Idle -= OnIdleAcceptClient;
                RhinoApp.Idle -= OnIdleHandleClient;
            }
            server.Start();
            RhinoApp.WriteLine("Waiting for connection");
            this.doc = doc;
            RhinoApp.Idle += OnIdleAcceptClient;
            return Result.Success;
        }

        public void OnIdleAcceptClient(object sender, EventArgs e) {
            if (server.Pending()) {
                RhinoApp.Idle -= OnIdleAcceptClient;
                processor = new Processor<Channel, Primitives>(new Channel(server.AcceptTcpClient().GetStream(), doc), new Primitives(doc));
                RhinoApp.WriteLine("Connection established");
                RhinoApp.Idle += OnIdleHandleClient;
            }
        }

        public void OnIdleHandleClient(object sender, EventArgs e) {
            int op = processor.TryReadOperation();
            if (op == -1) {
                RhinoApp.WriteLine("Connection terminated");
                RhinoApp.WriteLine("Waiting for connection");
                RhinoApp.Idle -= OnIdleHandleClient;
                RhinoApp.Idle += OnIdleAcceptClient;
            } else if (op == -2) {
                //timeout
            } else {                
                processor.ExecuteReadAndRepeat(op);
                doc.Views.Redraw();
            }
        }
    }
}
