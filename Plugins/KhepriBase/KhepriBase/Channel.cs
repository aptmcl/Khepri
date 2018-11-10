﻿using System;
using System.Collections.Generic;

using System.Net.Sockets;
using System.IO;

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
            this.r = new BinaryReader(stream);
            this.w = new BinaryWriter(stream);
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

        public int rInt16() => r.ReadInt16();

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

        public double[] rDoubleArray() {
            int length = rInt32();
            double[] ds = new double[length];
            for (int i = 0; i < length; i++) {
                ds[i] = rDouble();
            }
            return ds;
        }
        public void wDoubleArray(double[] ds) {
            wInt32(ds.Length);
            foreach (var d in ds) {
                wDouble(d);
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

        // BIM
        public BIMLevel rBIMLevel() => levels[r.ReadInt32()];
        public void wBIMLevel(BIMLevel l) { levels.Add(l); wInt32(levels.Count - 1); }
        public void eBIMLevel(Exception e) { wInt32(-1); dumpException(e); }

        public BIMFamily rBIMFamily() => families[r.ReadInt32()];
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