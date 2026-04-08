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

        public Channel(NetworkStream stream, System.Net.Sockets.Socket socket, RhinoDoc doc) : base(stream, socket) {
            this.doc = doc;
        }

        public Point3d rPoint3d() => new Point3d(rDouble(), rDouble(), rDouble());
        public void wPoint3d(Point3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }

        public Vector3d rVector3d() => new Vector3d(rDouble(), rDouble(), rDouble());
        public void wVector3d(Vector3d p) { w.Write(p.X); w.Write(p.Y); w.Write(p.Z); }


        public Plane rPlane() => new Plane(rPoint3d(), rVector3d(), rVector3d());
        public void wPlane(Plane pl) { wPoint3d(pl.Origin); wVector3d(pl.XAxis); wVector3d(pl.YAxis); }

        public RhinoObject rRhinoObject() => doc.Objects.Find(rGuid());
        public void wRhinoObject(RhinoObject obj) => wGuid(obj.Id);

        public void wBrep(Brep brep) => wGuid(doc.Objects.AddBrep(brep));
    }
}
