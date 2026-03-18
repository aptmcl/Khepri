using System;
using System.Collections.Generic;
using System.Net.Sockets;
//using System.Windows;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Colors;
using System.IO;

namespace KhepriAutoCAD {
    public class Channel : KhepriBase.Channel {
        public Processor processor;
        public List<ObjectId> shapes;
        public List<Material> materials;

        public Channel(NetworkStream stream) : base(stream) {
            this.shapes = new List<ObjectId>();
            this.materials = new List<Material>();
        }

        public void ConvertFromIdToId(ObjectId fromId, ObjectId toId) {
            int idx = 0;
            while ((idx = shapes.IndexOf(fromId, idx)) > -1) {
                shapes[idx] = toId;
            }
        }
        /*
         * We use, as convention, that the name of the reader is 'r' + type
         * and the name of the writer is 'w' + type
         * WARNING: This is used by the code generation part
         */
        public Point2d rPoint2d() => new Point2d(rDouble(), rDouble());
        public void wPoint2d(Point2d p) { w.Write(p.X); w.Write(p.Y); }

        public Point3d rPoint3d() => new Point3d(rDouble(), rDouble(), rDouble());
        public void wPoint3d(Point3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }

        public Vector3d rVector3d() => new Vector3d(rDouble(), rDouble(), rDouble());
        public void wVector3d(Vector3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }

        public Frame3d rFrame3d() => new Frame3d(rPoint3d(), rVector3d(), rVector3d(), rVector3d());
        public void wFrame3d(Frame3d f) {
            wPoint3d(f.origin);
            wVector3d(f.xaxis);
            wVector3d(f.yaxis);
            wVector3d(f.zaxis);
        }

        public Handle rHandle() => new Handle(r.ReadInt64());
        public void wHandle(Handle h) => wInt64(h.Value);

        /*
        public ObjectId rObjectId() => shapes[r.ReadInt32()];
        public void wObjectId(ObjectId id) {
            shapes.Add(id);
            if (FastMode) {
                //do nothing, the client knows the id in advance
            }
            else {
                wInt32(shapes.Count - 1);
            }
        }
        */
        public ObjectId rObjectId() {
            long value = rInt64();
            return value < 0 ?
                ObjectId.Null :
                getDoc().Database.GetObjectId(false, new Handle(value), 0);
        }
        public void wObjectId(ObjectId id) => wHandle(id.Handle);

        public Entity rEntity() => getShape(rObjectId());
        // This needs an open transaction public Entity rEntity() => rObjectId().GetObject(OpenMode.ForRead) as Entity;
        public void wEntity(Entity e) { using (e) { wObjectId(addShape(e)); }}

        public Point2d[] rPoint2dArray() {
            int length = rInt32();
            Point2d[] pts = new Point2d[length];
            for (int i = 0; i < length; i++) {
                pts[i] = rPoint2d();
            }
            return pts;
        }
        public void wPoint2dArray(Point2d[] pts) {
            wInt32(pts.Length);
            foreach (var pt in pts) {
                wPoint2d(pt);
            }
        }
        public Point3d[] rPoint3dArray() {
            int length = rInt32();
            Point3d[] pts = new Point3d[length];
            for (int i = 0; i < length; i++) {
                pts[i] = rPoint3d();
            }
            return pts;
        }
        public void wPoint3dArray(Point3d[] pts) {
            wInt32(pts.Length);
            foreach (var pt in pts) {
                wPoint3d(pt);
            }
        }
        public Vector3d[] rVector3dArray() {
            int length = rInt32();
            Vector3d[] pts = new Vector3d[length];
            for (int i = 0; i < length; i++) {
                pts[i] = rVector3d();
            }
            return pts;
        }
        public void wVector3dArray(Vector3d[] pts) {
            wInt32(pts.Length);
            foreach (var pt in pts) {
                wVector3d(pt);
            }
        }
        public Point3d[][] rPoint3dArrayArray() {
            int length = rInt32();
            Point3d[][] ptss = new Point3d[length][];
            for (int i = 0; i < length; i++) {
                ptss[i] = rPoint3dArray();
            }
            return ptss;
        }
        public void wPoint3dArrayArray(Point3d[][] ptss) {
            wInt32(ptss.Length);
            foreach (var pt in ptss) {
                wPoint3dArray(pt);
            }
        }

        public ObjectId[] rObjectIdArray() {
            int length = rInt32();
            ObjectId[] objs = new ObjectId[length];
            for (int i = 0; i < length; i++) {
                objs[i] = rObjectId();
            }
            return objs;
        }
        public void wObjectIdArray(ObjectId[] ids) {
            wInt32(ids.Length);
            foreach (var id in ids) {
                wObjectId(id);
            }
        }
        /*
        public Material rMaterial() {
            int idx = r.ReadInt32();
            return idx < 0 ? null : materials[idx];
        }
        public void wMaterial(Material m) { materials.Add(m); wInt32(materials.Count - 1); }
        */
        public Material rMaterial() {
            int idx = r.ReadInt32();
            return idx < 0 ? null : materials[idx];
        }
        public void wMaterial(Material m) {
            materials.Add(m); wInt32(materials.Count - 1);
        }

        public override object rObject(byte code) {
            switch (code) {
                case 7:
                case 8:
                    //This a ARGB color
                    rByte(); //Discard alpha
                    return rColor();
                default: return base.rObject(code);
            }
        }

        public new Color rColor() => Color.FromRgb(rByte(), rByte(), rByte());
        public void wColor(Color c) { wByte(c.Red); wByte(c.Green); wByte(c.Blue); }

        public Transaction tr {
            get => processor.tr;
        }
        public Document doc {
            get => processor.doc;
        }
        public Document getDoc() => Application.DocumentManager.MdiActiveDocument;
        public Transaction getTrans(Document doc) => doc.Database.TransactionManager.StartTransaction();
        public ObjectId addShape(Entity shape) {
            BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
            BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
            ObjectId id;
            using (shape) {
                id = btr.AppendEntity(shape);
                tr.AddNewlyCreatedDBObject(shape, true);
            }
            return id;
        }

        public Entity getShape(ObjectId id) {
            return (Entity)tr.GetObject(id, OpenMode.ForRead);
        }

        public void shapeGetter(ObjectId id, Action<Entity> f) {
            f((Entity)tr.GetObject(id, OpenMode.ForRead));
        }

        override public void Terminate() {
            shapes.Clear();
        }
    }
}
