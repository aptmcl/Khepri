using System;
using System.Collections.Generic;
using System.Net.Sockets;
//using System.Windows;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;
using System.IO;

namespace KhepriAutoCAD {
    public class Channel : KhepriBase.Channel {
        public List<ObjectId> shapes;
        public List<Material> materials;
        // Storage for operations made available. The starting one is the operation that makes other operations available 

        public Channel(NetworkStream stream) : base(stream) {
            this.shapes = new List<ObjectId>();
            this.materials = new List<Material>();
        }

        /*
         * We use, as convention, that the name of the reader is 'r' + type
         * and the name of the writer is 'w' + type
         * For handling errors, we also include the error signaller, which
         * is 'e' + type.
         * WARNING: This is used by the code generation part
         */

        public Point2d rPoint2d() => new Point2d(rDouble(), rDouble());
        public void wPoint2d(Point2d p) { w.Write(p.X); w.Write(p.Y); }
        public void ePoint2d(Exception e) { eDouble(e); }

        public Point3d rPoint3d() => new Point3d(rDouble(), rDouble(), rDouble());
        public void wPoint3d(Point3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }
        public void ePoint3d(Exception e) { eDouble(e); }

        public Vector3d rVector3d() => new Vector3d(rDouble(), rDouble(), rDouble());
        public void wVector3d(Vector3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }
        public void eVector3d(Exception e) { eDouble(e); }

        public Frame3d rFrame3d() => new Frame3d(rPoint3d(), rVector3d(), rVector3d(), rVector3d());
        public void wFrame3d(Frame3d f) {
            wPoint3d(f.origin);
            wVector3d(f.xaxis);
            wVector3d(f.yaxis);
            wVector3d(f.zaxis);
        }
        public void eFrame3d(Exception e) { ePoint3d(e); }

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
        public void eObjectId(Exception e) { wInt32(-1); dumpException(e); }

        public Entity rEntity() => getShape(rObjectId());
        public void wEntity(Entity e) { using (e) { wObjectId(addShape(e)); } }
        public void eEntity(Exception e) => eObjectId(e);

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
        public void ePoint2dArray(Exception e) => wInt32(-1);
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
        public void ePoint3dArray(Exception e) => wInt32(-1);

        public ObjectId[] rObjectIdArray() {
            int length = rInt32();
            ObjectId[] objs = new ObjectId[length];
            for (int i = 0; i < length; i++)
            {
                objs[i] = rObjectId();
            }
            return objs;
        }
        public void wObjectIdArray(ObjectId[] ids) {
            wInt32(ids.Length);
            foreach (var id in ids)
            {
                wObjectId(id);
            }
        }
        public void eObjectIdArray(Exception e) { wInt32(-1); dumpException(e); }

        public Material rMaterial() => materials[r.ReadInt32()];
        public void wMaterial(Material m) { materials.Add(m); wInt32(materials.Count - 1); }
        public void eMaterial(Exception e) { wInt32(-1); dumpException(e); }

        public Document getDoc() => Application.DocumentManager.MdiActiveDocument;
        public Transaction getTrans(Document doc) => doc.Database.TransactionManager.StartTransaction();
        public ObjectId addShape(Entity shape) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartTransaction()) {
                BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                ObjectId id;
                using (shape) {
                    id = btr.AppendEntity(shape);
                    tr.AddNewlyCreatedDBObject(shape, true);
                }
                tr.Commit();
                //doc.Editor.UpdateScreen();
                return id;
            }
        }
 
        public Entity getShape(ObjectId id) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartOpenCloseTransaction()) {
                //This doesn't seem very safe, but it is working
                return (Entity)tr.GetObject(id, OpenMode.ForRead);
            }
        }

        public void shapeGetter(ObjectId id, Action<Entity> f) {
            Document doc = Application.DocumentManager.MdiActiveDocument;
            using (doc.LockDocument())
            using (Transaction tr = doc.Database.TransactionManager.StartOpenCloseTransaction()) {
                f((Entity)tr.GetObject(id, OpenMode.ForRead));
            }
        }

        override public void Terminate() {
            shapes.Clear();
        }
    }
}