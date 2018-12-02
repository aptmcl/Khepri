using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Net.Sockets;
using UnityEngine;

namespace KhepriUnity {
    public class Channel : KhepriBase.Channel {
        public List<GameObject> shapes;
        public List<Material> materials;
        // Storage for operations made available. The starting one is the operation that makes other operations available 

        public Channel(NetworkStream stream) : base(stream) {
            this.shapes = new List<GameObject>();
            this.materials = new List<Material>();
        }

        /*
         * We use, as convention, that the name of the reader is 'r' + type
         * and the name of the writer is 'w' + type
         * For handling errors, we also include the error signaller, which
         * is 'e' + type.
         * WARNING: This is used by the code generation part
         */


        public GameObject rGameObject() => shapes[r.ReadInt32()];
        public void wGameObject(GameObject obj) {
            shapes.Add(obj);
            if (FastMode) {
                //do nothing, the client knows the id in advance
            } else {
                wInt32(shapes.Count - 1);
            }
        }
        public void eGameObject(Exception e) { wInt32(-1); dumpException(e); }

        public GameObject[] rGameObjectArray() {
            int length = rInt32();
            GameObject[] objs = new GameObject[length];
            for (int i = 0; i < length; i++) {
                objs[i] = rGameObject();
            }
            return objs;
        }
        public void wGameObjectArray(GameObject[] ids) {
            wInt32(ids.Length);
            foreach (var id in ids) {
                wGameObject(id);
            }
        }
        public void eGameObjectArray(Exception e) { wInt32(-1); dumpException(e); }

        public Material rMaterial() => materials[r.ReadInt32()];
        public void wMaterial(Material mat) {
            materials.Add(mat);
            wInt32(materials.Count - 1);
        }
        public void eMaterial(Exception e) { wInt32(-1); dumpException(e); }

        public Vector3 rVector3() => new Vector3(rSingle(), rSingle(), rSingle());
        public void wVector3(Vector3 p) { w.Write(p.x); w.Write(p.y); w.Write(p.z); }
        public void eVector3(Exception e) { eDouble(e); }

        public Vector3[] rVector3Array() {
            int length = rInt32();
            Vector3[] pts = new Vector3[length];
            for (int i = 0; i < length; i++) {
                pts[i] = rVector3();
            }
            return pts;
        }
        public void wVector3Array(Vector3[] pts) {
            wInt32(pts.Length);
            foreach (var pt in pts) {
                wVector3(pt);
            }
        }
        public void eVector3Array(Exception e) => wInt32(-1);

        public Vector3[][] rVector3ArrayArray() {
            int length = rInt32();
            Vector3[][] ptss = new Vector3[length][];
            for (int i = 0; i < length; i++) {
                ptss[i] = rVector3Array();
            }
            return ptss;
        }
        public void wVector3ArrayArray(Vector3[][] ptss) {
            wInt32(ptss.Length);
            foreach (var pt in ptss) {
                wVector3Array(pt);
            }
        }
        public void eVector3ArrayArray(Exception e) => wInt32(-1);

        public Color rColor() => new Color(rSingle(), rSingle(), rSingle());
        public void wColor(Color c) { w.Write(c.r); w.Write(c.g); w.Write(c.b); }
        public void eColor(Exception e) { eDouble(e); }

        public Quaternion rQuaternion() {
            float m11 = rSingle();
            float m12 = rSingle();
            float m13 = rSingle();
            float m21 = rSingle();
            float m22 = rSingle();
            float m23 = rSingle();
            float m31 = rSingle();
            float m32 = rSingle();
            float m33 = rSingle();
            return quaternionFromRotationMatrix(m11, m12, m13, m21, m22, m23, m31, m32, m33);
        }

        Quaternion quaternionFromRotationMatrix(
            float m11, float m12, float m13, 
            float m21, float m22, float m23,
            float m31, float m32, float m33) {
            float X, Y, Z, W;
            float trace = m11 + m22 + m33;

            if (trace > 0.0f) {
                float s = (float)Math.Sqrt(trace + 1.0f);
                W = s * 0.5f;
                s = 0.5f / s;
                X = (m23 - m32) * s;
                Y = (m31 - m13) * s;
                Z = (m12 - m21) * s;
            } else {
                if (m11 >= m22 && m11 >= m33) {
                    float s = (float)Math.Sqrt(1.0f + m11 - m22 - m33);
                    float invS = 0.5f / s;
                    X = 0.5f * s;
                    Y = (m12 + m21) * invS;
                    Z = (m13 + m31) * invS;
                    W = (m23 - m32) * invS;
                } else if (m22 > m33) {
                    float s = (float)Math.Sqrt(1.0f + m22 - m11 - m33);
                    float invS = 0.5f / s;
                    X = (m21 + m12) * invS;
                    Y = 0.5f * s;
                    Z = (m32 + m23) * invS;
                    W = (m31 - m13) * invS;
                } else {
                    float s = (float)Math.Sqrt(1.0f + m33 - m11 - m22);
                    float invS = 0.5f / s;
                    X = (m31 + m13) * invS;
                    Y = (m32 + m23) * invS;
                    Z = 0.5f * s;
                    W = (m12 - m21) * invS;
                }
            }
            return new Quaternion(X, Y, Z, W);
        }
        public void eTransform(Exception e) { eVector3(e); }


        override public void Terminate() {
//            shapes.Clear();
        }
    }
}