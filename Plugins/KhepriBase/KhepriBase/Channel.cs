using System;
using System.Collections.Generic;
using System.Net.Sockets;
using System.IO;
using System.Drawing;
using System.Text;

namespace KhepriBase {
    /// <summary>
    /// Binary framing and serialization layer over TCP. Handles length-prefixed frames
    /// (Int32 length + payload) and typed value serialization, but knows nothing about
    /// RPC semantics — the OK/NOTOK status byte and operation dispatch belong to the
    /// application layer (RMIFy/Processor).
    /// </summary>
    public class Channel : IDisposable {
        NetworkStream stream;
        System.Net.Sockets.Socket socket;
        public BinaryReader r;
        public BinaryWriter w;
        public List<BIMLevel> levels;
        public List<BIMFamily> families;
        // Storage for operations made available. The starting one is the operation that makes other operations available
        public int DebugMode;
        public bool FastMode;
        BinaryReader savedReader;
        BinaryWriter savedWriter;
        MemoryStream writeFrameStream;

        public Channel(NetworkStream stream) : this(stream, null) { }

        public Channel(NetworkStream stream, System.Net.Sockets.Socket socket) {
            this.stream = stream;
            this.socket = socket;
            this.r = new BinaryReader(stream, Encoding.UTF8);
            this.w = new BinaryWriter(stream, Encoding.UTF8);
            this.levels = new List<BIMLevel>();
            this.families = new List<BIMFamily>();
            this.DebugMode = 0;
            this.FastMode = false;
        }

        bool disposed = false;
        public void Dispose() {
            Dispose(true);
            GC.SuppressFinalize(this);
        }
        protected virtual void Dispose(bool disposing) {
            if (disposed) return;
            if (disposing) {
                r.Dispose();
                w.Dispose();
                writeFrameStream?.Dispose();
                levels.Clear();
                families.Clear();
            }
            // Free any unmanaged objects here.
            disposed = true;
        }


        public void Flush() => w.Flush();
        public void SetReadTimeout(int t) => stream.ReadTimeout = t;
        public bool DataAvailable => stream.DataAvailable;
        // Poll for readable data without touching the stream state.
        // microSeconds: max wait time; returns true if data (or EOF) is ready to read.
        public bool PollRead(int microSeconds) =>
            socket != null
                ? socket.Poll(microSeconds, System.Net.Sockets.SelectMode.SelectRead)
                : stream.DataAvailable;

        // Reads a length-prefixed frame from the network into memory, then redirects
        // r/w to in-memory streams so the operation handler reads from the buffered
        // request and writes to a buffered response. The original network reader/writer
        // are saved for EndFrame to restore.
        // Largest length-prefixed frame we will allocate for. A corrupt or
        // desynchronized stream can yield a garbage Int32 length; without this cap a
        // negative value throws ArgumentOutOfRange and a huge value OOMs, either way
        // killing the dispatch loop. 64 MiB is far above any real Khepri RPC frame.
        const int MaxFrameLength = 64 * 1024 * 1024;
        public bool BeginFrame() {
            int frameLen;
            try {
                frameLen = r.ReadInt32();
            } catch (EndOfStreamException) {
                return false;
            }
            // Corrupt/desynced length -> treat as a closed connection rather than
            // crashing the loop on ReadBytes (negative -> exception, huge -> OOM).
            if (frameLen < 0 || frameLen > MaxFrameLength)
                return false;
            byte[] frameData = r.ReadBytes(frameLen);
            // ReadBytes can legally return fewer bytes at EOF; a short read means the
            // peer closed the connection mid-frame.
            if (frameData.Length != frameLen)
                return false;
            savedReader = r;
            savedWriter = w;
            r = new BinaryReader(new MemoryStream(frameData), Encoding.UTF8);
            if (writeFrameStream == null)
                writeFrameStream = new MemoryStream();
            else
                writeFrameStream.SetLength(0);
            w = new BinaryWriter(writeFrameStream, Encoding.UTF8);
            return true;
        }

        // Restores network reader/writer, then writes the buffered response as a
        // length-prefixed frame (Int32 length + payload) back to the network stream.
        public void EndFrame() {
            w.Flush();
            byte[] responseData = writeFrameStream.ToArray();
            r = savedReader;
            w = savedWriter;
            w.Write(responseData.Length);
            w.Write(responseData);
            w.Flush();
        }

        /*
         * Discards everything buffered so far for the current response frame.
         *
         * Between BeginFrame and EndFrame the response lives entirely in
         * writeFrameStream; nothing has touched the network yet, and BeginFrame
         * writes no header bytes into the buffer (the Int32 length prefix is
         * computed and written by EndFrame itself), so truncating the buffer is a
         * complete rewind — there is nothing to re-write afterwards.
         *
         * Error paths need this because a handler can throw after partially
         * serializing a result (e.g. the 0x00 OK status byte plus half an array:
         * writers are not pure — wEntity-style writers mutate the host document and
         * can fail). Without the rewind, appending the 0x01 NOTOK record would
         * leave the partial OK bytes in front of it and the Julia side would decode
         * garbage as a success. SetLength(0) also resets Position (MemoryStream
         * clamps Position to the new length), exactly as BeginFrame relies on when
         * it reuses the stream.
         *
         * Only meaningful while a frame is in progress (after BeginFrame, before
         * EndFrame); outside a frame there is no buffered response to reset.
         *
         * See also: RMIfy.SerializeErrors and Processor.ProvideOperation, the two
         * error paths that rely on this.
         */
        public void ResetResponse() => writeFrameStream.SetLength(0);

        /*
         * We use, as convention, that the name of the reader is 'r' + type
         * and the name of the writer is 'w' + type
         * WARNING: This is used by the code generation part
         */

        public void wVoid() => w.Write((byte)0);

        public byte rByte() => r.ReadByte();
        public void wByte(byte b) => w.Write(b);

        public bool rBoolean() => r.ReadByte() == 1;
        public void wBoolean(bool b) => w.Write(b ? (byte)1 : (byte)2);

        public short rInt16() => r.ReadInt16();
        public void wInt16(Int16 i) => w.Write(i);

        public int rInt32() => r.ReadInt32();
        public void wInt32(Int32 i) => w.Write(i);

        public long rInt64() => r.ReadInt64();
        public void wInt64(Int64 i) => w.Write(i);

        public string rString() => r.ReadString();
        public void wString(string s) => w.Write(s);

        public float rSingle() => r.ReadSingle();
        public void wSingle(float d) => w.Write(d);

        public double rDouble() => r.ReadDouble();
        public void wDouble(double d) => w.Write(d);

        //A Guid (used, e.g., in Rhinoceros 3D) is a A 16-element byte array
        public Guid rGuid() => new Guid(r.ReadBytes(16));
        public void wGuid(Guid g) => w.Write(g.ToByteArray());

        // The type-code byte enables self-describing serialization for heterogeneous
        // collections (Options dictionaries, mixed arrays).
        public object rObject() => rObject(rByte());

        protected static byte UnitFloatToByte(float v) {
            if (float.IsNaN(v) || v < 0.0f || v > 1.0f)
                throw new ArgumentOutOfRangeException(nameof(v), v, "Color component must be in [0, 1].");
            return (byte)Math.Round(v * 255.0f);
        }

        protected Color rRGBObject() =>
            Color.FromArgb(255,
                UnitFloatToByte(rSingle()),
                UnitFloatToByte(rSingle()),
                UnitFloatToByte(rSingle()));

        protected Color rRGBAObject() {
            float red = rSingle();
            float green = rSingle();
            float blue = rSingle();
            float alpha = rSingle();
            return Color.FromArgb(
                UnitFloatToByte(alpha),
                UnitFloatToByte(red),
                UnitFloatToByte(green),
                UnitFloatToByte(blue));
        }

        public virtual object rObject(byte code) {
            switch (code) {
                case 0: return rBoolean();
                case 1: return rByte();
                case 2: return rInt32();
                case 3: return rInt64();
                case 4: return rSingle();
                case 5: return rDouble();
                case 6: return rString();
                case 7: return rRGBObject();
                case 8: return rRGBAObject();
                case 9: return rOptions();
                default: throw new Exception("Unexpected type code:" + code);
            }
        }

        public Options rOptions() {
            int length = rInt32();
            Options dict = new Options();
            for (int i = 0; i < length; i++) {
                string key = rString();
                dict[key] = rObject();
            }
            return dict;
        }



        public Color rColor() => Color.FromArgb(rByte(), rByte(), rByte(), rByte());
        public void wColor(Color c) {
            wByte(c.A); wByte(c.R); wByte(c.G); wByte(c.B);
        }

        public DateTime rDateTime() => new DateTime(rInt64(), DateTimeKind.Local);
        public void wDateTime(DateTime dt) => wInt64(dt.Ticks);

        // BIM families and levels are registered by index during a session — each side
        // maintains a list and exchanges indices rather than full objects on every call.
        public BIMLevel rBIMLevel() => levels[rInt32()];
        public void wBIMLevel(BIMLevel l) { levels.Add(l); wInt32(levels.Count - 1); }

        public BIMFamily rBIMFamily() => families[rInt32()];
        //SHOULD WE AVOID DUPLICATING ENTRIES?
        public void wBIMFamily(BIMFamily f) { families.Add(f); wInt32(families.Count - 1); }

        public FloorFamily rFloorFamily() => (FloorFamily)rBIMFamily();
        public void wFloorFamily(FloorFamily f) => wBIMFamily(f);

        public SlabFamily rSlabFamily() => (SlabFamily)rBIMFamily();
        public void wSlabFamily(SlabFamily f) => wBIMFamily(f);

        public WallFamily rWallFamily() => (WallFamily)rBIMFamily();
        public void wWallFamily(WallFamily f) => wBIMFamily(f);

        public RoofFamily rRoofFamily() => (RoofFamily)rBIMFamily();
        public void wRoofFamily(RoofFamily f) => wBIMFamily(f);

        public TableFamily rTableFamily() => (TableFamily)rBIMFamily();
        public void wTableFamily(TableFamily f) => wBIMFamily(f);

        public ChairFamily rChairFamily() => (ChairFamily)rBIMFamily();
        public void wChairFamily(ChairFamily f) => wBIMFamily(f);

        public TableChairFamily rTableChairFamily() => (TableChairFamily)rBIMFamily();
        public void wTableChairFamily(TableChairFamily f) => wBIMFamily(f);

        public void SetDebugMode(int mode) => DebugMode = mode;
        public void SetFastMode(bool mode) => FastMode = mode;


        public virtual void Terminate() {
        }
    }
}
