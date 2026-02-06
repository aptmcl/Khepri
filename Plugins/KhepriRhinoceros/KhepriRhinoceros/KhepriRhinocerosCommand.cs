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
        public Action currentAction;

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

        protected override Result RunCommand(RhinoDoc doc, RunMode mode) {
            this.doc = doc;
            StartServer();
            RhinoApp.Idle += OnIdleDoCurrentAction;
            return Result.Success;
        }

        public void StartServer() {
            if (server == null) {
                Int32 port = 12000;
                IPAddress localAddr = IPAddress.Parse("127.0.0.1");
                server = new TcpListener(localAddr, port);
            } else {
                server.Stop();
            }
            server.Start();
            RhinoApp.WriteLine("Waiting for connection");
            currentAction = AcceptClient;
        }

        protected void OnIdleDoCurrentAction(object sender, EventArgs e) {
            currentAction();
        }

        public void AcceptClient() {
            if (server.Pending()) {
                processor = new Processor<Channel, Primitives>(new Channel(server.AcceptTcpClient().GetStream(), doc), new Primitives(doc));
                RhinoApp.WriteLine("Connection established");
                currentAction = HandleClient;
            }
        }

        public void HandleClient() {
            int op = processor.TryReadOperation();
            if (op == -1) {
                RhinoApp.WriteLine("Connection terminated");
                RhinoApp.WriteLine("Waiting for connection");
                currentAction = AcceptClient;
            } else if (op == -2) {
                //timeout
            } else {                
                processor.ExecuteReadAndRepeat(op);
                doc.Views.Redraw();
            }
        }
    }
}
