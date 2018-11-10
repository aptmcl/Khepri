using System;
using System.Collections.Generic;
using UnityEngine;


namespace KhepriUnity {
    public class Primitives : KhepriBase.Primitives {

        GameObject mainObj;

        public Primitives(GameObject mainObject) {
            this.mainObj = mainObject;
        }

        public void DeleteAll() {
            foreach (Transform child in mainObj.transform) {
                GameObject.Destroy(child.gameObject);
            }
        }

        public GameObject Box(Vector3 position, Quaternion rotation, float dx, float dy, float dz) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cube);
            s.name = "Box";
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            s.transform.localRotation = rotation;
            s.transform.localPosition = position + new Vector3(dx / 2, dy / 2, dz / 2);
            return s;
        }

        public GameObject CenteredBox(Vector3 position, Quaternion rotation, float dx, float dy, float dz, float angle) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cube);
            Quaternion rot = Quaternion.Euler(0, Mathf.Rad2Deg * angle, 0) * rotation;
            s.name = "CenteredBox";
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            s.transform.localRotation = rot;
            s.transform.localPosition = position + rot*new Vector3(0, 0, dz / 2);
            return s;
        }

        public GameObject Sphere(Vector3 center, float radius) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(2 * radius, 2 * radius, 2 * radius);
            s.transform.localPosition = center;
            return s;
        }

        public GameObject Cylinder(Vector3 bottom, float radius, Vector3 top) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            float d = Vector3.Distance(bottom, top);
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(2 * radius, d / 2, 2 * radius);
            s.transform.localRotation = Quaternion.FromToRotation(Vector3.up, top - bottom);
            s.transform.localPosition = bottom + (top - bottom) / 2;
            return s;
        }

        public void Move(GameObject s, Vector3 v) {
            s.transform.localPosition += v;
        }

        public void Scale(GameObject s, Vector3 p, float scale) {
            Vector3 sp = s.transform.localPosition;
            s.transform.localScale *= scale;
            s.transform.localPosition = p + (sp - p) * scale;
        }

        public void Rotate(GameObject s, Vector3 p, Vector3 n, float a) {
            Vector3 pw = s.transform.parent.TransformPoint(p);
            Vector3 nw = s.transform.parent.TransformVector(n);
            s.transform.RotateAround(pw, nw, -a*Mathf.Rad2Deg);
        }
    }
}