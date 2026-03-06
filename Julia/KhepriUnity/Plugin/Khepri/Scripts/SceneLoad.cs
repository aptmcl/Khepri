using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using KhepriUnity;
using UnityEngine;
using static KhepriUnity.KhepriConstants;

using UnityProcessor = KhepriUnity.Processor<KhepriUnity.Channel, KhepriUnity.Primitives>;

public enum State { StartingServer, WaitingConnections, WaitingCommands, Simulating, Visualizing }

public class SceneLoad {

    TcpListener server;
    TcpClient client;
    Channel channel;
    UnityProcessor processor;
    private GameObject mainObject;
    public Primitives primitives;
    private static volatile bool _visualizing = false;
    public static bool visualizing {
        get { return _visualizing; }
        set { _visualizing = value; }
    }
    private static bool I_am_the_server = false;
    public State currentState = I_am_the_server ? State.StartingServer : State.WaitingConnections;

    public SceneLoad() {
        mainObject = GameObject.Find("MainObject");
        if (mainObject == null) {
            mainObject = new GameObject("MainObject");
            mainObject.isStatic = true;
        }
        primitives = new Primitives(mainObject);
    }

    public TcpClient StartClient() {
        IPAddress remoteAddr = IPAddress.Parse(DEFAULT_SERVER_ADDRESS);
        IPEndPoint serverEndPoint = new IPEndPoint(remoteAddr, DEFAULT_CLIENT_PORT);
        client = new TcpClient();
        client.Connect(serverEndPoint);
        return client;
    }

    public bool StartServer() {
        try {
            if (server == null) {
                IPAddress localAddr = IPAddress.Parse(DEFAULT_SERVER_ADDRESS);
                server = new TcpListener(localAddr, DEFAULT_SERVER_PORT);
            } else {
                server.Stop();
            }
            server.Start();
            currentState = State.WaitingConnections;
            return true;

        } catch (Exception e) {
            WriteMessage(e.ToString() + "\n");
            WriteMessage("Couldn't start server\n");
            return false;
        }
    }

    public void Disconnect() {
        try { channel?.Dispose(); }
        catch (Exception e) { WriteMessage("Error disposing channel: " + e.Message + "\n"); }
        channel = null;
        processor = null;
        try { client?.Close(); }
        catch (Exception e) { WriteMessage("Error closing client: " + e.Message + "\n"); }
        client = null;
    }

    public void StopServer() {
        Disconnect();
        if (server != null) {
            try { server.Stop(); }
            catch (Exception e) { WriteMessage("Error stopping server: " + e.Message + "\n"); }
            WriteMessage("Server stopped\n");
            server = null;
        }
        currentState = I_am_the_server ? State.StartingServer : State.WaitingConnections;
    }

    public void WaitForConnections() {
        if (channel != null) {
            currentState = State.WaitingCommands;
            return;
        }
        try {
            WriteMessage("Waiting for connections\n");
            channel = new Channel((I_am_the_server ? server.AcceptTcpClient() : StartClient()).GetStream());
            processor = new UnityProcessor(channel, primitives);
            primitives.SetProcessor(processor);
            if (!I_am_the_server) {
                channel.wString("Unity");
            }
            WriteMessage("Connection established\n");
            currentState = State.WaitingCommands;
        } catch (IOException) {
            currentState = State.WaitingConnections;
            processor = null;
            WriteMessage("Disconnecting\n");
        } catch (Exception e) {
            currentState = State.WaitingConnections;
            processor = null;
            WriteMessage(e.ToString() + "\n");
            WriteMessage("Terminating connection\n");
        }
    }

    public void WriteMessage(String msg) {
        Debug.Log(msg);
    }

    public bool Serve() {
        switch (currentState) {
            case State.StartingServer:
                StartServer();
                return true;
            case State.WaitingConnections:
                WaitForConnections();
                return true;
            case State.WaitingCommands:
                int op = processor.TryReadOperation();
                switch (op) {
                    case -2: //Timeout
                        return true;
                    case -1: //EOF
                        currentState = State.WaitingConnections;
                        processor = null;
                        WriteMessage("Disconnecting from client\n");
                        return false;
                    default:
                        processor.ExecuteReadAndRepeat(op);
                        if (primitives.simulationPending) {
                            currentState = State.Simulating;
                        }
                        return true;
                }
            case State.Simulating:
                if (SystemManager.isFinished) {
                    channel.wSingle(SimMetrics.GetEvacuationTime());
                    channel.wBoolean(!SystemManager.timeOut);
                    channel.Flush();
                    primitives.simulationPending = false;
                    currentState = State.WaitingCommands;
                }
                return true;
            default:
                return true;
        }
    }

    public void Update() {
        if (visualizing) {
            return;
        } else {
            Serve();
        }
    }

    void Awake() {
        //DontDestroyOnLoad(this.gameObject);
        //GameObject.Find("MainObject").transform.Rotate(-90, 0, 0);
        visualizing = ! Application.isEditor;
    }

    public void OnDestroy() {
        StopServer();
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
