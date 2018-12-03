using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net.Sockets;
using System.IO;
using Rhino;
using Rhino.Geometry;
using Rhino.DocObjects;

namespace KhepriRhinoceros {
    class Channel : KhepriBase.Channel {

        RhinoDoc doc;

        public Channel(NetworkStream stream, RhinoDoc doc) : base(stream) {
            this.doc = doc;
        }

        public Point3d rPoint3d() => new Point3d(rDouble(), rDouble(), rDouble());
        public void wPoint3d(Point3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }
        public void ePoint3d(Exception e) { eDouble(e); }

        public Vector3d rVector3d() => new Vector3d(rDouble(), rDouble(), rDouble());
        public void wVector3d(Vector3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }
        public void eVector3d(Exception e) { eDouble(e); }

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
        public void ePoint3dArray(Exception e) => eArray(e);

        public Plane rPlane() => new Plane(rPoint3d(), rVector3d(), rVector3d());
        public void wPlane(Plane pl) { wPoint3d(pl.Origin); wVector3d(pl.XAxis); wVector3d(pl.YAxis); }
        public void ePlane(Exception e) { ePoint3d(e); }

        public RhinoObject rRhinoObject() => doc.Objects.Find(rGuid());
        public void wRhinoObject(RhinoObject obj) => wGuid(obj.Id);
        public void eRhinoObject(Exception e) { eGuid(e); }

        public RhinoObject[] rRhinoObjectArray() => rGuidArray().Select(doc.Objects.Find).ToArray();
        public void wRhinoObjectArray(RhinoObject[] objs) => wGuidArray(objs.Select(obj => obj.Id).ToArray());
        public void eRhinoObjectArray(Exception e) { eGuid(e); }

        //        public RhinoObject rRhinoObject() => doc.Objects.Find(rGuid());
        public void wBrep(Brep brep) => wGuid(doc.Objects.AddBrep(brep));
        public void eBrep(Exception e) { eGuid(e); }

        public void wBrepArray(Brep[] breps) => wGuidArray(breps.Select(doc.Objects.AddBrep).ToArray());
        public void eBrepArray(Exception e) => eArray(e);
    }
}
