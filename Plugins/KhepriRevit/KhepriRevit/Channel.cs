using Autodesk.Revit.DB;
using Autodesk.Revit.UI;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

namespace KhepriRevit {
    public class Channel : KhepriBase.Channel {
        public UIApplication uiApp;

        public Channel(UIApplication uiApp, NetworkStream stream, System.Net.Sockets.Socket socket) : base(stream, socket) {
            this.uiApp = uiApp;
        }

        const double to_feet = 3.28084;
        double readLength() => rDouble() * to_feet;
        void writeLength(double value) => wDouble(value / to_feet);
        public Length rLength() => new Length(readLength());
        public void wLength(Length l) => writeLength(l.Value);

        public XYZ rXYZ() => new XYZ(readLength(), readLength(), readLength());
        public void wXYZ(XYZ p) { writeLength(p.X); writeLength(p.Y); writeLength(p.Z); }
        /*
                public Vector3d rVector3d() => new Vector3d(rDouble(), rDouble(), rDouble());
                public void wVector3d(Vector3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }
                public void eVector3d(Exception e) { eDouble(e); }

                public void wFrame3d(Frame3d f)
                {
                    wPoint3d(f.origin);
                    wVector3d(f.xaxis);
                    wVector3d(f.yaxis);
                    wVector3d(f.zaxis);
                }
                public void eFrame3d(Exception e) { ePoint3d(e); }
                        public Frame3d rFrame3d() => new Frame3d(rPoint3d(), rVector3d(), rVector3d(), rVector3d());

                        public void wDoubleArray(double[] ds)
                        {
                            wInt32(ds.Length);
                            foreach (var d in ds)
                            {
                                wDouble(d);
                            }
                        }
                        public void eDoubleArray(Exception e) { wInt32(-1); dumpException(e); }
        */

        public ElementId rElementId() {
            long id = r.ReadInt64();
            //Check this number. Should we use -1?
            return (id == 0L) ? null :
                (id == -1L) ? ElementId.InvalidElementId :
                new ElementId(id);
        }
        public void wElementId(ElementId id) => wInt64((int)id.Value);

        public Element rElement() => uiApp.ActiveUIDocument.Document.GetElement(rElementId());
        public void wElement(Element e) { using (e) { wElementId(e.Id); } }

        public Level rLevel() => rElement() as Level;
        public void wLevel(Level e) => wElement(e);

        public Material rMaterial() => rElement() as Material;
        public void wMaterial(Material m) => wElement(m);


        // Keep a reverse lookup so RPCs receiving a Family can resolve the long id
        // back to the Family object that LoadFamily produced.
        static private Dictionary<long, Family> loadedFamilies = new Dictionary<long, Family>() { { 0L, null } };
        public Family rFamily() {
            long key = rInt64();
            // Fall back to looking the family up directly in the document if it isn't
            // in the cache — the cache is populated by wFamily on serializer-side, but
            // RMIFy's expression-tree codegen doesn't always route Family return values
            // through wFamily, leaving the cache empty for valid family ids.
            if (loadedFamilies.TryGetValue(key, out var cached)) return cached;
            var elem = uiApp.ActiveUIDocument.Document.GetElement(new ElementId(key));
            if (elem is Family fam) {
                loadedFamilies[key] = fam;
                return fam;
            }
            throw new InvalidOperationException(
                $"Family id {key} could not be resolved (LoadFamily was not called or the element is not a Family).");
        }
        public void wFamily(Family f) {
            long i = f.Id.Value;
            loadedFamilies[i] = f;
            wInt64(i);
        }


        /*
                public Document getDoc() => Application.DocumentManager.MdiActiveDocument;
                public Transaction getTrans(Document doc) => doc.Database.TransactionManager.StartTransaction();
                public ObjectId addShape(Entity shape)
                {
                    Document doc = Application.DocumentManager.MdiActiveDocument;
                    using (doc.LockDocument())
                    using (Transaction tr = doc.Database.TransactionManager.StartTransaction())
                    {
                        BlockTable bt = (BlockTable)tr.GetObject(doc.Database.BlockTableId, OpenMode.ForRead);
                        BlockTableRecord btr = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);
                        ObjectId id;
                        using (shape)
                        {
                            id = btr.AppendEntity(shape);
                            tr.AddNewlyCreatedDBObject(shape, true);
                        }
                        tr.Commit();
                        //doc.Editor.UpdateScreen();
                        return id;
                    }
                }
                public void SetDebugMode(int mode)
                {
                    DebugMode = mode;
                }
                public void SetFastMode(bool mode)
                {
                    FastMode = mode;
                }
                public Entity getShape(ObjectId id)
                {
                    Document doc = Application.DocumentManager.MdiActiveDocument;
                    using (doc.LockDocument())
                    using (Transaction tr = doc.Database.TransactionManager.StartOpenCloseTransaction())
                    {
                        //This doesn't seem very safe, but it is working
                        return (Entity)tr.GetObject(id, OpenMode.ForRead);
                    }
                }

                public void shapeGetter(ObjectId id, Action<Entity> f)
                {
                    Document doc = Application.DocumentManager.MdiActiveDocument;
                    using (doc.LockDocument())
                    using (Transaction tr = doc.Database.TransactionManager.StartOpenCloseTransaction())
                    {
                        f((Entity)tr.GetObject(id, OpenMode.ForRead));
                    }
                }
                */
    }
}
