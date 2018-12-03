using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using KhepriUnity;
using UnityEngine;

using UnityProcessor = KhepriUnity.Processor<KhepriUnity.Channel, KhepriUnity.Primitives>;

enum State { StartingServer, WaitingConnections, WaitingClient }

public class SceneLoad : MonoBehaviour {

    TcpListener server;
    UnityProcessor processor;
    State currentState = State.StartingServer;

    void StartServer() {
        try {
            if (server == null) {
                Int32 port = 11002;
                IPAddress localAddr = IPAddress.Parse("127.0.0.1");
                server = new TcpListener(localAddr, port);
            } else {
                server.Stop();
            }
            server.Start();
            currentState = State.WaitingConnections;
        } catch (Exception e) {
            WriteMessage(e.ToString() + "\n");
            WriteMessage("Couldn't start server\n");
        }
    }

    void WaitForConnections() {
        try {
            WriteMessage("Waiting for connections\n");
            processor =
                    new UnityProcessor(
                        new Channel(server.AcceptTcpClient().GetStream()),
                        new Primitives(GameObject.Find("MainObject")));
            WriteMessage("Connection established\n");
            currentState = State.WaitingClient;
        } catch (IOException) {
            currentState = State.WaitingConnections;
            processor = null;
            WriteMessage("Disconneting from client\n");
        } catch (Exception e) {
            currentState = State.WaitingConnections;
            processor = null;
            WriteMessage(e.ToString() + "\n");
            WriteMessage("Terminating client\n");
        }
    }

    public void WriteMessage(String msg) {
        Debug.Log(msg);
    }

    public void Update() {
        switch (currentState) {
            case State.StartingServer:
                //We don't do nothing. Supposedly, the server was started before
                break;
            case State.WaitingConnections:
                WaitForConnections();
                break;
            case State.WaitingClient:
                int op = processor.TryReadOperation();
                switch (op) {
                    case -2: //Timeout
                        break;
                    case -1: //EOF
                        currentState = State.WaitingConnections;
                        processor = null;
                        WriteMessage("Disconneting from client\n");
                        break;
                    default:
                        processor.ExecuteReadAndRepeat(op);
                        break;
                }
                break;
        }
    }


    void Awake() {
        //DontDestroyOnLoad(this.gameObject);
        //GameObject.Find("MainObject").transform.Rotate(-90, 0, 0);
        StartServer();
    }

    void OnDestroy() {
        server.Stop();
    }




    /*    [RuntimeInitializeOnLoadMethod]
        static void OnRuntimeMethodLoad() {
            new Thread(() => {
                new SceneLoadScript().WaitForConnections();
            }).Start();
        }
    */
    /*	private static void tick() {
            //Primitives.MakeCube(new Vector3(0, 0, 0), 1);
            Primitives.MakeCylinder(new Vector3(0, 0, 0), 1, new Vector3(2, 2, 2));
            Primitives.MakeCube(new Vector3(2, 2, 2), 1);
        }
        */
}
