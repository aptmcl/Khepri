using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;
using KhepriUnity;
using UnityEngine;
using static KhepriUnity.KhepriConstants;

using UnityProcessor = KhepriUnity.Processor<KhepriUnity.Channel, KhepriUnity.Primitives>;

public enum State { StartingServer, WaitingConnections, Connecting, WaitingCommands, Selecting, Simulating, Visualizing }

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

    // Async connection state
    private Task connectTask;
    private float lastConnectAttempt = -999f;
    private const float CONNECT_RETRY_DELAY = 3f; // seconds between attempts

    public SceneLoad() {
        mainObject = GameObject.Find("MainObject");
        if (mainObject == null) {
            mainObject = new GameObject("MainObject");
            mainObject.isStatic = true;
        }
        primitives = new Primitives(mainObject);
    }

    public bool StartKhepri() {
        Disconnect();
        if (I_am_the_server) {
            try {
                if (server == null) {
                    IPAddress localAddr = IPAddress.Parse(DEFAULT_SERVER_ADDRESS);
                    server = new TcpListener(localAddr, DEFAULT_SERVER_PORT);
                } else {
                    server.Stop();
                }
                server.Start();
            } catch (Exception e) {
                WriteMessage(e.ToString() + "\n");
                WriteMessage("Couldn't start server\n");
                return false;
            }
        }
        lastConnectAttempt = -999f;
        currentState = State.WaitingConnections;
        return true;
    }

    public void Disconnect() {
        try { channel?.Dispose(); }
        catch (Exception e) { WriteMessage("Error disposing channel: " + e.Message + "\n"); }
        channel = null;
        processor = null;
        connectTask = null;
        // Shutdown the socket before closing to send FIN immediately,
        // unblocking any pending read on the Julia side.
        try { client?.Client?.Shutdown(SocketShutdown.Both); }
        catch (Exception) { }
        try { client?.Close(); }
        catch (Exception e) { WriteMessage("Error closing client: " + e.Message + "\n"); }
        client = null;
    }

    public void StopKhepri() {
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
        if (I_am_the_server) {
            // Server mode: non-blocking accept
            if (!server.Pending())
                return;
            try {
                client = server.AcceptTcpClient();
                channel = new Channel(client.GetStream());
                processor = new UnityProcessor(channel, primitives);
                primitives.SetProcessor(processor);
                WriteMessage("Connection established\n");
                currentState = State.WaitingCommands;
            } catch (Exception e) {
                WriteMessage(e.ToString() + "\n");
                processor = null;
            }
        } else {
            // Client mode: start async connect with retry delay
            float now = Time.realtimeSinceStartup;
            if (now - lastConnectAttempt < CONNECT_RETRY_DELAY)
                return;
            lastConnectAttempt = now;
            try {
                client = new TcpClient();
                IPAddress remoteAddr = IPAddress.Parse(DEFAULT_SERVER_ADDRESS);
                connectTask = client.ConnectAsync(remoteAddr, DEFAULT_CLIENT_PORT);
                currentState = State.Connecting;
                WriteMessage("Connecting to Julia...\n");
            } catch (Exception e) {
                WriteMessage("Connect error: " + e.Message + "\n");
                try { client?.Close(); } catch { }
                client = null;
            }
        }
    }

    private void PollConnect() {
        if (connectTask == null) {
            currentState = State.WaitingConnections;
            return;
        }
        if (!connectTask.IsCompleted)
            return;
        if (connectTask.IsFaulted || !client.Connected) {
            WriteMessage("Connection failed, retrying in " + CONNECT_RETRY_DELAY + "s...\n");
            connectTask = null;
            try { client?.Close(); } catch { }
            client = null;
            currentState = State.WaitingConnections;
            return;
        }
        // Connected successfully
        try {
            connectTask = null;
            channel = new Channel(client.GetStream());
            processor = new UnityProcessor(channel, primitives);
            primitives.SetProcessor(processor);
            channel.wString("Unity");
            WriteMessage("Connection established\n");
            currentState = State.WaitingCommands;
        } catch (Exception e) {
            WriteMessage("Post-connect error: " + e.Message + "\n");
            Disconnect();
            currentState = State.WaitingConnections;
        }
    }

    public void WriteMessage(String msg) {
        Debug.Log(msg);
    }

    public bool Serve() {
        switch (currentState) {
            case State.StartingServer:
                StartKhepri();
                return true;
            case State.WaitingConnections:
                WaitForConnections();
                return true;
            case State.Connecting:
                PollConnect();
                return true;
            case State.WaitingCommands:
                if (processor == null) {
                    currentState = State.WaitingConnections;
                    return false;
                }
                try {
                    int op = processor.TryReadOperation();
                    switch (op) {
                        case -2: //Timeout
                            return true;
                        case -1: //EOF
                            Disconnect();
                            currentState = State.WaitingConnections;
                            WriteMessage("Disconnected from Julia\n");
                            return false;
                        default:
                            processor.ExecuteReadAndRepeat(op);
                            if (primitives.selectionPending) {
                                currentState = State.Selecting;
                            } else if (primitives.simulationPending) {
                                currentState = State.Simulating;
                            }
                            return true;
                    }
                } catch (Exception) {
                    Disconnect();
                    currentState = State.WaitingConnections;
                    WriteMessage("Connection to Julia lost, reconnecting...\n");
                    return false;
                }
            case State.Selecting:
                if (!primitives.InSelectionProcess) {
                    int[] ids = primitives.SelectedGameObjectsIds(true);
                    channel.wInt32(ids.Length);
                    foreach (int id in ids)
                        channel.wInt32(id);
                    channel.Flush();
                    primitives.selectionPending = false;
                    currentState = State.WaitingCommands;
                }
                return true;
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
        StopKhepri();
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
