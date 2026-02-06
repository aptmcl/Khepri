using System;
using System.Collections.Generic;
using System.Net.Sockets;
using System.IO;
using System.Drawing;
using System.Text;

namespace KhepriBase {
    public class Channel : IDisposable {
        NetworkStream stream;
        public BinaryReader r;
        public BinaryWriter w;
        public List<BIMLevel> levels;
        public List<BIMFamily> families;
        // Storage for operations made available. The starting one is the operation that makes other operations available 
        public int DebugMode;
        public bool FastMode;

        public Channel(NetworkStream stream) {
            this.stream = stream;
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
                levels.Clear();
                families.Clear();
            }
            // Free any unmanaged objects here.
            disposed = true;
        }


        public void Flush() => w.Flush();
        public void SetReadTimeout(int t) => stream.ReadTimeout = t;

        /*
         * We use, as convention, that the name of the reader is 'r' + type
         * and the name of the writer is 'w' + type
         * For handling errors, we also include the error signaller, which
         * is 'e' + type.
         * WARNING: This is used by the code generation part
         */

        protected void dumpException(Exception e) { wString(e.Message + "\n" + e.StackTrace); }
        public void wVoid() => w.Write((byte)0);
        public void eVoid(Exception e) { w.Write((byte)127); dumpException(e); }

        public byte rByte() => r.ReadByte();
        public void wByte(byte b) => w.Write(b);
        public void eByte(Exception e) { w.Write(-123); dumpException(e); }

        public bool rBoolean() => r.ReadByte() == 1;
        public void wBoolean(bool b) => w.Write(b ? (byte)1 : (byte)2);
        public void eBoolean(Exception e) { w.Write((byte)127); dumpException(e); }

        public short rInt16() => r.ReadInt16();
        public void wInt16(Int16 i) => w.Write(i);
        public void eInt16(Exception e) { w.Write(-12345); dumpException(e); }

        public int rInt32() => r.ReadInt32();
        public void wInt32(Int32 i) => w.Write(i);
        public void eInt32(Exception e) { w.Write(-12345); dumpException(e); }

        public long rInt64() => r.ReadInt64();
        public void wInt64(Int64 i) => w.Write(i);
        public void eInt64(Exception e) { w.Write(-123456789); dumpException(e); }

        public string rString() => r.ReadString();
        public void wString(string s) => w.Write(s);
        public void eString(Exception e) { w.Write("This an error!"); dumpException(e); }

        public float rSingle() => r.ReadSingle();
        public void wSingle(float d) => w.Write(d);
        public void eSingle(Exception e) { w.Write(Single.NaN); dumpException(e); }

        public double rDouble() => r.ReadDouble();
        public void wDouble(double d) => w.Write(d);
        public void eDouble(Exception e) { w.Write(Double.NaN); dumpException(e); }

        //A Guid (used, e.g., in Rhinoceros 3D) is a A 16-element byte array
        public Guid rGuid() => new Guid(r.ReadBytes(16));
        public void wGuid(Guid g) => w.Write(g.ToByteArray());
        public void eGuid(Exception e) { w.Write(new byte[16]); dumpException(e); }

        public void eArray(Exception e) { wInt32(-1); dumpException(e); }

        public object rObject() => rObject(rByte());

        public virtual object rObject(byte code) {
            switch (code) {
                case 0: return rBoolean();
                case 1: return rByte();
                case 2: return rInt32();
                case 3: return rInt64();
                case 4: return rSingle();
                case 5: return rDouble();
                case 6: return rString();
                case 7: return rColor();
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

        public Boolean[] rBooleanArray() {
            int length = rInt32();
            var elems = new Boolean[length];
            for (int i = 0; i < length; i++) {
                elems[i] = rBoolean();
            }
            return elems;
        }
        public void wBooleanArray(Boolean[] elems) {
            wInt32(elems.Length);
            foreach (var elem in elems) {
                wBoolean(elem);
            }
        }
        public void eBooleanArray(Exception e) => eArray(e);
        public short[] rInt16Array() {
            int length = rInt32();
            var elems = new short[length];
            for (int i = 0; i < length; i++) {
                elems[i] = rInt16();
            }
            return elems;
        }
        public void wInt16Array(short[] elems) {
            wInt32(elems.Length);
            foreach (var elem in elems) {
                wInt16(elem);
            }
        }
        public void eInt16Array(Exception e) => eArray(e);
        public int[] rInt32Array() {
            int length = rInt32();
            var elems = new int[length];
            for (int i = 0; i < length; i++) {
                elems[i] = rInt32();
            }
            return elems;
        }
        public void wInt32Array(int[] elems) {
            wInt32(elems.Length);
            foreach (var elem in elems) {
                wInt32(elem);
            }
        }
        public void eInt32Array(Exception e) => eArray(e);
        public long[] rInt64Array() {
            int length = rInt32();
            var elems = new long[length];
            for (int i = 0; i < length; i++) {
                elems[i] = rInt64();
            }
            return elems;
        }
        public void wInt64Array(long[] elems) {
            wInt32(elems.Length);
            foreach (var elem in elems) {
                wInt64(elem);
            }
        }
        public void eInt64Array(Exception e) => eArray(e);

        public float[] rSingleArray() {
            int length = rInt32();
            var elems = new float[length];
            for (int i = 0; i < length; i++) {
                elems[i] = rSingle();
            }
            return elems;
        }
        public void wSingleArray(float[] elems) {
            wInt32(elems.Length);
            foreach (var elem in elems) {
                wSingle(elem);
            }
        }
        public void eSingleArray(Exception e) => eArray(e);
        public double[] rDoubleArray() {
            int length = rInt32();
            var elems = new double[length];
            for (int i = 0; i < length; i++) {
                elems[i] = rDouble();
            }
            return elems;
        }
        public void wDoubleArray(double[] elems) {
            wInt32(elems.Length);
            foreach (var elem in elems) {
                wDouble(elem);
            }
        }
        public void eDoubleArray(Exception e) => eArray(e);

        public string[] rStringArray() {
            int length = rInt32();
            string[] strs = new string[length];
            for (int i = 0; i < length; i++) {
                strs[i] = rString();
            }
            return strs;
        }
        public void wStringArray(string[] strs) {
            wInt32(strs.Length);
            foreach (var str in strs) {
                wString(str);
            }
        }
        public void eStringArray(Exception e) => eArray(e);

        public object[] rObjectArray() {
            int length = rInt32();
            object[] os = new object[length];
            for (int i = 0; i < length; i++) {
                os[i] = rObject();
            }
            return os;
        }

        public Guid[] rGuidArray() {
            int length = rInt32();
            Guid[] gs = new Guid[length];
            for (int i = 0; i < length; i++) {
                gs[i] = rGuid();
            }
            return gs;
        }
        public void wGuidArray(Guid[] gs) {
            wInt32(gs.Length);
            foreach (var g in gs) {
                wGuid(g);
            }
        }
        public void eGuidArray(Exception e) => eArray(e);

        public short[][] rInt16ArrayArray() {
            int length = rInt32();
            short[][] ptss = new short[length][];
            for (int i = 0; i < length; i++) {
                ptss[i] = rInt16Array();
            }
            return ptss;
        }
        public void wInt16ArrayArray(short[][] ptss) {
            wInt32(ptss.Length);
            foreach (var pt in ptss) {
                wInt16Array(pt);
            }
        }
        public void eInt16ArrayArray(Exception e) => wInt32(-1);
        public int[][] rInt32ArrayArray() {
            int length = rInt32();
            int[][] ptss = new int[length][];
            for (int i = 0; i < length; i++) {
                ptss[i] = rInt32Array();
            }
            return ptss;
        }
        public void wInt32ArrayArray(int[][] ptss) {
            wInt32(ptss.Length);
            foreach (var pt in ptss) {
                wInt32Array(pt);
            }
        }
        public void eInt32ArrayArray(Exception e) => wInt32(-1);

        public Color rColor() => Color.FromArgb(rByte(), rByte(), rByte(), rByte());
        public void wColor(Color c) {
            wByte(c.A); wByte(c.R); wByte(c.G); wByte(c.B);
        }
        public void eColor(Exception e) => eByte(e);

        public DateTime rDateTime() => new DateTime(rInt64(), DateTimeKind.Local);
        public void wDateTime(DateTime dt) => wInt64(dt.Ticks);
        public void eDateTime(DateTime dt) => wInt64(-1L);

        // BIM
        public BIMLevel rBIMLevel() => levels[rInt32()];
        public void wBIMLevel(BIMLevel l) { levels.Add(l); wInt32(levels.Count - 1); }
        public void eBIMLevel(Exception e) { wInt32(-1); dumpException(e); }

        public BIMFamily rBIMFamily() => families[rInt32()];
        //SHOULD WE AVOID DUPLICATING ENTRIES?
        public void wBIMFamily(BIMFamily f) { families.Add(f); wInt32(families.Count - 1); }
        public void eBIMFamily(Exception e) { wInt32(-1); dumpException(e); }

        public FloorFamily rFloorFamily() => (FloorFamily)rBIMFamily();
        public void wFloorFamily(FloorFamily f) => wBIMFamily(f);
        public void eFloorFamily(Exception e) => eBIMFamily(e);

        public SlabFamily rSlabFamily() => (SlabFamily)rBIMFamily();
        public void wSlabFamily(SlabFamily f) => wBIMFamily(f);
        public void eSlabFamily(Exception e) => eBIMFamily(e);

        public WallFamily rWallFamily() => (WallFamily)rBIMFamily();
        public void wWallFamily(WallFamily f) => wBIMFamily(f);
        public void eWallFamily(Exception e) => eBIMFamily(e);

        public RoofFamily rRoofFamily() => (RoofFamily)rBIMFamily();
        public void wRoofFamily(RoofFamily f) => wBIMFamily(f);
        public void eRoofFamily(Exception e) => eBIMFamily(e);

        public TableFamily rTableFamily() => (TableFamily)rBIMFamily();
        public void wTableFamily(TableFamily f) => wBIMFamily(f);
        public void eTableFamily(Exception e) => eBIMFamily(e);

        public ChairFamily rChairFamily() => (ChairFamily)rBIMFamily();
        public void wChairFamily(ChairFamily f) => wBIMFamily(f);
        public void eChairFamily(Exception e) => eBIMFamily(e);

        public TableChairFamily rTableChairFamily() => (TableChairFamily)rBIMFamily();
        public void wTableChairFamily(TableChairFamily f) => wBIMFamily(f);
        public void eTableChairFamily(Exception e) => eBIMFamily(e);

        public void SetDebugMode(int mode) => DebugMode = mode;
        public void SetFastMode(bool mode) => FastMode = mode;


        public virtual void Terminate() {
        }
    }
}