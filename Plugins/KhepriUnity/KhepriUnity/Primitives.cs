using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using Parabox.CSG;


namespace KhepriUnity {
    public class Primitives : KhepriBase.Primitives {

        GameObject mainObj;
        Camera mainCamera;
        Material currentMaterial;

        public Primitives(GameObject mainObject) {
            this.mainObj = mainObject;
            this.mainCamera = Camera.main;
            this.currentMaterial = new Material(Shader.Find("Diffuse"));
        }
        public void DeleteMany(GameObject[] objs) {
            foreach(GameObject obj in objs) {
                GameObject.Destroy(obj);
            }
        }
        public void DeleteAll() {
            foreach (Transform child in mainObj.transform) {
                GameObject.Destroy(child.gameObject);
            }
        }

        public Material LoadMaterial(String name) => Resources.Load<Material>(name);
        public void SetCurrentMaterial(Material material) => this.currentMaterial = material;
        public Material CurrentMaterial() => this.currentMaterial;

        Vector2 BestSize(float sizeA, float sizeB, float sizeC) =>
            (sizeA >= sizeB) ?
              ((sizeB >= sizeC) ?
                new Vector2(sizeA, sizeB) :
                BestSize(sizeA, sizeC, sizeB)) :
            BestSize(sizeB, sizeA, sizeC);

        public GameObject ApplyMaterial(GameObject obj, Material material) {
            float scaleFactor = 2;
            Renderer renderer = obj.GetComponent<Renderer>();
            renderer.material = material;
            Vector3 size = renderer.bounds.size;
            renderer.material.mainTextureScale = BestSize(size.x, size.y, size.z)/scaleFactor;
            return obj;
        }

        public GameObject ApplyCurrentMaterial(GameObject obj) =>
            ApplyMaterial(obj, currentMaterial);

        public GameObject LoadResource(String name) => Resources.Load<GameObject>(name);

        public GameObject PointLight(Vector3 position, Color color, float range, float intensity) {
            GameObject pLight = new GameObject("PointLight");
            Light light = pLight.AddComponent<Light>();
            pLight.transform.parent = mainObj.transform;
            light.type = LightType.Point;
            light.color = color;
            light.range = range;         // How far the light is emitted from the center of the object
            light.intensity = intensity; // Brightness of the light
            pLight.transform.localPosition = position;
            return pLight;
        }

        public GameObject Window(Vector3 position, Quaternion rotation, float dx, float dy, float dz) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cube);
            s.name = "Window";
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            s.transform.localRotation = rotation;
            s.transform.localPosition = position + rotation * new Vector3(dx / 2, dy / 2, dz / 2);
            s.GetComponent<Renderer>().material = Resources.Load<Material>("Materials/Glass");
            return s;
        }

        /*
                static Vector3 vpol(float rho, float phi) => new Vector3(rho * Mathf.Cos(phi), rho * Mathf.Sin(phi), 0);

                public List<GameObject> RowOfGameObjects(Vector3 c, float angle, int n, float spacing, GameObject family) {
                    Quaternion rot = Quaternion.Euler(0, 0, Mathf.Rad2Deg*angle + 90);
                    return Enumerable.Range(0, n).Select(i => TransformedGameObject(family, c + vpol(spacing * i, angle), rot)).ToList();
                }

                public List<GameObject> CenteredRowOfGameObjects(Vector3 c, float angle, int n, float spacing, GameObject family) =>
                    RowOfGameObjects(c + vpol(-spacing * (n - 1) / 2, angle), angle, n, spacing, family);

                // BIM Table
                public List<GameObject> BaseRectangularTable(float length, float width, float height, float top_thickness, float leg_thickness) {
                    List<GameObject> objs = new List<GameObject>();
                    GameObject table = new Solid3d();
                    table.CreateBox(length, width, top_thickness);
                    table.TransformBy(Quaternion.Displacement(new Vector3d(0, 0, height - top_thickness / 2)));
                    objs.Add(table);
                    float dx = length / 2;
                    float dy = width / 2;
                    float leg_x = dx - leg_thickness / 2;
                    float leg_y = dy - leg_thickness / 2;
                    Vector3[] pts = new Vector3[] {
                            new Vector3(+leg_x, -leg_y, 0),
                            new Vector3(+leg_x, +leg_y, 0),
                            new Vector3(-leg_x, +leg_y, 0),
                            new Vector3(-leg_x, -leg_y, 0)
                        };
                    foreach (Vector3 p in pts) {
                        Solid3d leg = new Solid3d();
                        leg.CreateBox(leg_thickness, leg_thickness, height - top_thickness);
                        leg.TransformBy(Quaternion.Displacement(p - Vector3.Origin + new Vector3d(0, 0, (height - top_thickness) / 2)));
                        objs.Add(leg);
                    }
                    return objs;
                }
                public GameObject CreateRectangularTableFamily(float length, float width, float height, float top_thickness, float leg_thickness) =>
                    CreateBlockFromFunc("Khepri Table", () => BaseRectangularTable(length, width, height, top_thickness, leg_thickness));


                public GameObject Table(Vector3 c, float angle, GameObject family) =>
                    CreateBlockInstanceAtRotated(family, c, angle);

                // BIM Chair block
                public List<GameObject> BaseChair(float length, float width, float height, float seat_height, float thickness) {
                    List<GameObject> objs = BaseRectangularTable(length, width, seat_height, thickness, thickness);
                    float vx = length / 2;
                    float vy = width / 2;
                    float vz = height;
                    Solid3d back = new Solid3d();
                    back.CreateBox(thickness, width, height - seat_height);
                    back.TransformBy(Quaternion.Displacement(new Vector3d((thickness - length) / 2, 0, (seat_height + height) / 2)));
                    objs.Add(back);
                    return objs;
                }
                public GameObject CreateChairFamily(float length, float width, float height, float seat_height, float thickness) =>
                    CreateBlockFromFunc("Khepri Chair", () => BaseChair(length, width, height, seat_height, thickness));

                public GameObject Chair(Vector3 c, float angle, GameObject family) =>
                    CreateBlockInstance(family, new Frame3d(c, vpol(1, angle), vpol(1, angle + Math.PI / 2)));

                // BIM Table and chairs block
                public List<GameObject> BaseRectangularTableAndChairs(GameObject tableFamily, GameObject chairFamily, float tableLength, float tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, float spacing) {
                    List<GameObject> objs = new List<GameObject>();
                    float dx = tableLength / 2;
                    float dy = tableWidth / 2;
                    objs.Add(new GameObject(new Vector3(0, 0, 0), tableFamily));
                    objs.AddRange(CenteredRowOfGameObjects(new Vector3(-dx, 0, 0), -Math.PI / 2, chairsOnBottom, spacing, chairFamily));
                    objs.AddRange(CenteredRowOfGameObjects(new Vector3(+dx, 0, 0), +Math.PI / 2, chairsOnTop, spacing, chairFamily));
                    objs.AddRange(CenteredRowOfGameObjects(new Vector3(0, +dy, 0), -Math.PI, chairsOnRight, spacing, chairFamily));
                    objs.AddRange(CenteredRowOfGameObjects(new Vector3(0, -dy, 0), 0, chairsOnLeft, spacing, chairFamily));
                    return objs;
                }

                public GameObject CreateRectangularTableAndChairsFamily(GameObject tableFamily, GameObject chairFamily, float tableLength, float tableWidth, int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, float spacing) =>
                    CreateBlockFromFunc("Khepri Table&Chair", () => BaseRectangularTableAndChairs(
                        tableFamily, chairFamily, tableLength, tableWidth,
                        chairsOnTop, chairsOnBottom, chairsOnRight, chairsOnLeft,
                        spacing));

                public GameObject TableAndChairs(Vector3 c, float angle, GameObject family) =>
                    CreateBlockInstanceAtRotated(family, c, angle);

            */

        public GameObject Box(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz) {
            Quaternion rotation = Quaternion.LookRotation(vx, vy);
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cube);
            s.name = "Box";
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            s.transform.localRotation = rotation;
            s.transform.localPosition = position + rotation * new Vector3(dx / 2, dy / 2, dz / 2);
            ApplyCurrentMaterial(s);
            return s;
        }

        public GameObject Box2(Vector3 position, Quaternion rotation, float dx, float dy, float dz) {
            GameObject box = new GameObject("Box");
            box.transform.parent = GameObject.Find("MainObject").transform;

            MeshRenderer meshRenderer = box.AddComponent<MeshRenderer>();
            MeshFilter meshFilter = box.AddComponent<MeshFilter>();
            Mesh mesh = new Mesh();
            meshFilter.mesh = mesh;
            mesh.vertices = new Vector3[] {
                // face 1 (xy plane)
                new Vector3(position.x,      position.y,      position.z),
                new Vector3(position.x + dx, position.y,      position.z),
                new Vector3(position.x + dx, position.y + dy, position.z),
                new Vector3(position.x,      position.y + dy, position.z), 
                // face 2 (zy plane)
                new Vector3(position.x + dx, position.y,      position.z),
                new Vector3(position.x + dx, position.y,      position.z + dz),
                new Vector3(position.x + dx, position.y + dy, position.z + dz),
                new Vector3(position.x + dx, position.y + dy, position.z), 
                // face 3 (xy plane)
                new Vector3(position.x + dx, position.y,      position.z + dz),
                new Vector3(position.x,      position.y,      position.z + dz),
                new Vector3(position.x,      position.y + dy, position.z + dz),
                new Vector3(position.x + dx, position.y + dy, position.z + dz), 
                // face 4 (zy plane)
                new Vector3(position.x,      position.y,      position.z + dz),
                new Vector3(position.x,      position.y,      position.z),
                new Vector3(position.x,      position.y + dy, position.z),
                new Vector3(position.x,      position.y + dy, position.z + dz), 
                // face 5  (zx plane)
                new Vector3(position.x,      position.y + dy, position.z),
                new Vector3(position.x + dx, position.y + dy, position.z),
                new Vector3(position.x + dx, position.y + dy, position.z + dz),
                new Vector3(position.x,      position.y + dy, position.z + dz), 
                // face 6 (zx plane)
                new Vector3(position.x,      position.y,      position.z),
                new Vector3(position.x,      position.y,      position.z + dz),
                new Vector3(position.x + dx, position.y,      position.z + dz),
                new Vector3(position.x + dx, position.y,      position.z),
            };

            int faces = 6;
            mesh.subMeshCount = faces; // Specify how many submeshes to apply different materials
            List<int> triangles = new List<int>();
            List<Vector2> uvs = new List<Vector2>();

            for (int i = 0; i < faces; i++) {
                int triangleOffset = i * 4;
                triangles.Add(0 + triangleOffset);
                triangles.Add(2 + triangleOffset);
                triangles.Add(1 + triangleOffset);

                triangles.Add(0 + triangleOffset);
                triangles.Add(3 + triangleOffset);
                triangles.Add(2 + triangleOffset);

                // Same uvs for all faces
                uvs.Add(new Vector2(0, 0));
                uvs.Add(new Vector2(1, 0));
                uvs.Add(new Vector2(1, 1));
                uvs.Add(new Vector2(0, 1));
                mesh.SetTriangles(triangles.ToArray(), i);
                triangles.Clear();
            }
            mesh.uv = uvs.ToArray();

            //Material material = new Material(Shader.Find("Diffuse")); REMOVE ME

            // Codigo a alterar no set material, fazer um ciclo por cada material

//            foreach (Material material in renderer.materials)
//                material.mainTextureScale = new Vector2(scaleX, scaleY);


            Material material = currentMaterial;
            Material[] mats = { material, material, material, material, material, material }; // This list has the size of #faces or #submeshes, in this case 6
            meshRenderer.materials = mats;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();

            box.AddComponent<BoxCollider>();
            box.transform.localRotation = rotation;
            return box;
        }

        public GameObject CenteredBox2(Vector3 position, Quaternion rotation, float dx, float dy, float dz, float angle) {
            GameObject box = new GameObject("CenteredBox");
            box.transform.parent = GameObject.Find("MainObject").transform;

            MeshRenderer meshRenderer = box.AddComponent<MeshRenderer>();
            MeshFilter meshFilter = box.AddComponent<MeshFilter>();
            Mesh mesh = new Mesh();
            meshFilter.mesh = mesh;
            mesh.vertices = new Vector3[] {
                // face 1 (xy plane)
                new Vector3(position.x - dx / 2, position.y,      position.z - dz / 2),
                new Vector3(position.x + dx / 2, position.y,      position.z - dz / 2),
                new Vector3(position.x + dx / 2, position.y + dy, position.z - dz / 2),
                new Vector3(position.x - dx / 2, position.y + dy, position.z - dz / 2), 
                // face 2 (zy plane)
                new Vector3(position.x + dx / 2, position.y,      position.z - dz / 2),
                new Vector3(position.x + dx / 2, position.y,      position.z + dz / 2),
                new Vector3(position.x + dx / 2, position.y + dy, position.z + dz / 2),
                new Vector3(position.x + dx / 2, position.y + dy, position.z - dz / 2), 
                // face 3 (xy plane)
                new Vector3(position.x + dx / 2, position.y,      position.z + dz / 2),
                new Vector3(position.x - dx / 2, position.y,      position.z + dz / 2),
                new Vector3(position.x - dx / 2, position.y + dy, position.z + dz / 2),
                new Vector3(position.x + dx / 2, position.y + dy, position.z + dz / 2), 
                // face 4 (zy plane)
                new Vector3(position.x - dx / 2, position.y,      position.z + dz / 2),
                new Vector3(position.x - dx / 2, position.y,      position.z - dz / 2),
                new Vector3(position.x - dx / 2, position.y + dy, position.z - dz / 2),
                new Vector3(position.x - dx / 2, position.y + dy, position.z + dz / 2), 
                // face 5  (zx plane)
                new Vector3(position.x - dx / 2, position.y + dy, position.z - dz / 2),
                new Vector3(position.x + dx / 2, position.y + dy, position.z - dz / 2),
                new Vector3(position.x + dx / 2, position.y + dy, position.z + dz / 2),
                new Vector3(position.x - dx / 2, position.y + dy, position.z + dz / 2), 
                // face 6 (zx plane)
                new Vector3(position.x - dx / 2, position.y,      position.z - dz / 2),
                new Vector3(position.x - dx / 2, position.y,      position.z + dz / 2),
                new Vector3(position.x + dx / 2, position.y,      position.z + dz / 2),
                new Vector3(position.x + dx / 2, position.y,      position.z - dz / 2),
            };

        int faces = 6;
        mesh.subMeshCount = faces; // Specify how many submeshes to apply different materials
        List<int> triangles = new List<int>();
        List<Vector2> uvs = new List<Vector2>();

        for (int i = 0; i < faces; i++) {
            int triangleOffset = i * 4;
            triangles.Add(0 + triangleOffset);
            triangles.Add(2 + triangleOffset);
            triangles.Add(1 + triangleOffset);

            triangles.Add(0 + triangleOffset);
            triangles.Add(3 + triangleOffset);
            triangles.Add(2 + triangleOffset);

            // Same uvs for all faces
            uvs.Add(new Vector2(0, 0));
            uvs.Add(new Vector2(1, 0));
            uvs.Add(new Vector2(1, 1));
            uvs.Add(new Vector2(0, 1));
            mesh.SetTriangles(triangles.ToArray(), i); // Setup submeshes triangles
            triangles.Clear();
        }
        mesh.uv = uvs.ToArray();

        //Material material = new Material(Shader.Find("Diffuse")); REMOVE ME
        Material material = Resources.Load<Material>("Materials/Concrete"); // FIX ME, HARDCODED MATERIAL
        Material[] mats = { material, material, material, material, material, material }; // This list has the size of #faces or #submeshes, in this case 6
        meshRenderer.materials = mats;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        box.AddComponent<BoxCollider>();
        box.transform.localRotation = Quaternion.Euler(0, Mathf.Rad2Deg * angle, 0) * rotation;
        return box;
    }

        public GameObject RightCuboidNamed(String name, Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle) {
            Quaternion rotation = Quaternion.LookRotation(vx, vy);
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cube);
            rotation = rotation * Quaternion.Euler(0, 0, Mathf.Rad2Deg * angle);
            s.name = name;
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            s.transform.localRotation = rotation;
            s.transform.localPosition = position + rotation * new Vector3(0, 0, dz / 2);
            return s;
        }

        public GameObject RightCuboid(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle) =>
            ApplyCurrentMaterial(RightCuboidNamed("RightCuboid", position, vx, vy, dx, dy, dz, angle));

        public GameObject Sphere(Vector3 center, float radius) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(2 * radius, 2 * radius, 2 * radius);
            s.transform.localPosition = center;
            return s;
        }

        public GameObject CylinderNamed(String name, Vector3 bottom, float radius, Vector3 top) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            s.name = name;
            float d = Vector3.Distance(bottom, top);
            s.transform.parent = mainObj.transform;
            s.transform.localScale = new Vector3(2 * radius, d / 2, 2 * radius);
            s.transform.localRotation = Quaternion.FromToRotation(Vector3.up, top - bottom);
            s.transform.localPosition = bottom + (top - bottom) / 2;
            return s;
        }

        public GameObject Cylinder(Vector3 bottom, float radius, Vector3 top) =>
            ApplyCurrentMaterial(CylinderNamed("Cylinder", bottom, radius, top));

        Vector3 PlaneNormal(Vector3[] pts) {
            Vector3 pt = pts[0];
            Vector3 sum = Vector3.zero;
            for (int i = 1; i < pts.Length - 1; i++) {
                if (pts[i] == pt || pts[i + 1] == pt) continue;
                sum += Vector3.Cross(pts[i] - pt, pts[i + 1] - pt);
            }
            sum.Normalize();
            return sum;
        }

        Vector3[] ReverseIfNeeded(Vector3[] pts, Vector3 normal) {
            Vector3 normalPts = PlaneNormal(pts);
            return (Vector3.Dot(normalPts, normal) > 0) ? pts : pts.Reverse().ToArray();
        }

        GameObject AddPolygonMesh(GameObject parent, Vector3[] ps, Material material) {
            GameObject s = new GameObject("SurfacePolygon");
            s.transform.parent = parent.transform;
            s.AddComponent<MeshRenderer>();
            MeshFilter filter = s.AddComponent<MeshFilter>();
            Poly2Mesh.Polygon polygon = new Poly2Mesh.Polygon();
            polygon.outside = new List<Vector3>(ps);
            filter.mesh = Poly2Mesh.CreateMesh(polygon);
            ApplyMaterial(s, material);
            return s;
        }

        GameObject AddPolygonMeshWithHoles(GameObject parent, Vector3[] ps, Vector3[][] holes, Material material) {
            GameObject s = new GameObject("SurfacePolygon");
            s.transform.parent = parent.transform;
            s.AddComponent<MeshRenderer>();
            MeshFilter filter = s.AddComponent<MeshFilter>();
            Poly2Mesh.Polygon polygon = new Poly2Mesh.Polygon();
            polygon.outside = new List<Vector3>(ps);
            polygon.holes =
                new List<List<Vector3>>(
                    new List<Vector3[]>(holes).Select(e => new List<Vector3>(e)));
            filter.mesh = Poly2Mesh.CreateMesh(polygon);
            ApplyMaterial(s, material);
            return s;
        }

        GameObject AddTrigMesh(GameObject parent, Vector3[] ps, Vector3 q, Material material) {
            GameObject s = new GameObject("TrigMesh");
            s.transform.parent = parent.transform;
            s.AddComponent<MeshRenderer>();
            MeshFilter filter = s.AddComponent<MeshFilter>();
            Vector3[] vertices = new Vector3[ps.Length + 1];
            Array.Copy(ps, vertices, ps.Length);
            vertices[ps.Length] = q;
            int[] triangles = new int[ps.Length * 3];
            int k = 0;
            for (int i = 0, j = ps.Length; i < ps.Length - 1; i++, j++) {
                triangles[k++] = i;
                triangles[k++] = i + 1;
                triangles[k++] = ps.Length;
            }
            triangles[k++] = ps.Length - 1;
            triangles[k++] = 0;
            triangles[k++] = ps.Length;
            Mesh mesh = new Mesh();
            mesh.vertices = vertices;
            mesh.triangles = triangles;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            filter.mesh = mesh;
            ApplyMaterial(s, material);
            ApplyCollider(s, mesh);
            return s;
        }

        GameObject AddQuadMesh(GameObject parent, Vector3[] ps, Vector3[] qs, Material material) {
            GameObject s = new GameObject("QuadMesh");
            s.transform.parent = parent.transform;
            s.AddComponent<MeshRenderer>();
            MeshFilter filter = s.AddComponent<MeshFilter>();
            Vector3[] vertices = new Vector3[ps.Length * 2];
            Array.Copy(ps, vertices, ps.Length);
            Array.Copy(qs, 0, vertices, ps.Length, qs.Length);
            int[] triangles = new int[ps.Length * 2 * 3];
            int k = 0;
            for (int i = 0, j = ps.Length; i < ps.Length - 1; i++, j++) {
                triangles[k++] = i;
                triangles[k++] = i + 1;
                triangles[k++] = j + 1;
                triangles[k++] = i;
                triangles[k++] = j + 1;
                triangles[k++] = j;
            }
            triangles[k++] = ps.Length - 1;
            triangles[k++] = 0;
            triangles[k++] = ps.Length;
            triangles[k++] = ps.Length - 1;
            triangles[k++] = ps.Length;
            triangles[k++] = 2 * ps.Length - 1;
            Mesh mesh = new Mesh();
            mesh.vertices = vertices;
            mesh.triangles = triangles;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            filter.mesh = mesh;
            ApplyMaterial(s, material);
            ApplyCollider(s, mesh);
            return s;
        }

        GameObject ApplyCollider(GameObject obj, Mesh mesh) {
            MeshCollider meshCollider = obj.AddComponent<MeshCollider>();
            meshCollider.sharedMesh = mesh;
            return obj;
        }

        public GameObject SurfacePolygon(Vector3[] ps) =>
            AddPolygonMesh(mainObj, ReverseIfNeeded(ps, Vector3.up), currentMaterial);

        public GameObject Pyramid(Vector3[] ps, Vector3 q) {
            ps = ReverseIfNeeded(ps, Vector3.down);
            GameObject s = new GameObject("Pyramid");
            s.transform.parent = mainObj.transform;
            AddPolygonMesh(s, ps, currentMaterial);
            Array.Reverse(ps);
            AddTrigMesh(s, ps, q, currentMaterial);
            return s;
        }

        public GameObject PyramidFrustum(Vector3[] ps, Vector3[] qs) {
            ps = ReverseIfNeeded(ps, Vector3.down);
            qs = ReverseIfNeeded(qs, Vector3.up);
            GameObject s = new GameObject("PyramidFrustum");
            s.transform.parent = mainObj.transform;
            AddPolygonMesh(s, ps, currentMaterial);
            //Array.Reverse(qs);
            AddPolygonMesh(s, qs, currentMaterial);
            Array.Reverse(ps);
            AddQuadMesh(s, ps, qs, currentMaterial);
            return s;
        }

        public GameObject ExtrudeContour(Vector3[] contour, Vector3[][] holes, Vector3 v, Material material) {
            contour = ReverseIfNeeded(contour, Vector3.down);
            GameObject s = new GameObject("Slab");
            s.transform.parent = mainObj.transform;
            GameObject bot = AddPolygonMeshWithHoles(s, contour.ToArray(), holes, material);
            MeshFilter botMeshFilter = bot.GetComponent<MeshFilter>();
            Mesh botMesh = botMeshFilter.mesh;
            ApplyCollider(bot, botMesh);
            GameObject top = new GameObject("SurfacePolygon");
            top.transform.parent = s.transform;
            top.AddComponent<MeshRenderer>();
            MeshFilter topMeshFilter = top.AddComponent<MeshFilter>();
            Mesh topMesh = new Mesh();
            topMesh.vertices = botMesh.vertices.Select(e => e + v).ToArray();
            topMesh.triangles = botMesh.triangles.Reverse().ToArray();
            topMesh.RecalculateNormals();
            topMesh.RecalculateBounds();
            topMeshFilter.mesh = topMesh;
            ApplyMaterial(top, material);
            ApplyCollider(top, topMesh);
            Vector3[] topContour = contour.Select(e => e + v).ToArray();
            AddQuadMesh(s, topContour, contour, material);
            foreach (Vector3[] hole in holes) {
                Vector3[] topHole = hole.Select(e => e + v).ToArray();
                AddQuadMesh(s, hole.ToArray(), topHole, material);
            }
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
            s.transform.RotateAround(pw, nw, -a * Mathf.Rad2Deg);
        }

        //Boolean operations

        public GameObject Unite(GameObject s0, GameObject s1) {
            Mesh m = CSG.Union(s0, s1);
            GameObject composite = new GameObject();
            composite.transform.parent = mainObj.transform;
            composite.AddComponent<MeshFilter>().sharedMesh = m;
            composite.AddComponent<MeshRenderer>().sharedMaterial = s0.GetComponent<MeshRenderer>().sharedMaterial;
            return composite;
        }

        public GameObject Subtract(GameObject s0, GameObject s1) {
            Mesh m = CSG.Subtract(s0, s1);
            GameObject composite = new GameObject();
            composite.transform.parent = mainObj.transform;
            composite.AddComponent<MeshFilter>().sharedMesh = m;
            composite.AddComponent<MeshRenderer>().sharedMaterial = s0.GetComponent<MeshRenderer>().sharedMaterial;
            return composite;
        }

        public GameObject Intersect(GameObject s0, GameObject s1) {
            Mesh m = CSG.Intersect(s0, s1);
            GameObject composite = new GameObject();
            composite.transform.parent = mainObj.transform;
            composite.AddComponent<MeshFilter>().sharedMesh = m;
            composite.AddComponent<MeshRenderer>().sharedMaterial = s0.GetComponent<MeshRenderer>().sharedMaterial;
            return composite;
        }

        public void SubtractFrom(GameObject s0, GameObject s1) {
            Mesh m = CSG.Subtract(s0, s1);
            s0.GetComponent<MeshFilter>().sharedMesh = m;
            GameObject.Destroy(s1);
        }

        //Blocks
        //We could use Prefabs for this but they can only be used with the Unity Editor and I'm not convinced we want to depend on it.

        //Creating instances
        public GameObject CreateBlockInstance(GameObject block, Vector3 position, Vector3 vx, Vector3 vy, float scale) {
            GameObject obj = InstantiateFamily(block, position, vx, vy, scale);
            obj.SetActive(true);
            return obj;
        }

        //Creating blocks
        public GameObject CreateBlockFromFunc(String name, Func<List<GameObject>> f) =>
            CreateBlockFromShapes(name, f().ToArray());

        public GameObject CreateBlockFromShapes(String name, GameObject[] objs) {
            GameObject block = new GameObject(name);
            block.SetActive(false);
            foreach (GameObject child in objs) {
                child.transform.parent = block.transform;
            }
            return block;
        }


        //BIM

        public GameObject InstantiateFamily(GameObject family, Vector3 pos, Vector3 vx, Vector3 vy, float scale) {
            Quaternion rotation = Quaternion.LookRotation(vx, vy);
            GameObject s = GameObject.Instantiate(family);
            s.transform.parent = mainObj.transform;
            s.transform.localRotation = rotation * s.transform.localRotation;
            s.transform.localPosition = pos;
            return s;
        }

        public GameObject InstantiateBIMElement(GameObject family, Vector3 pos, float angle) {
            GameObject s = GameObject.Instantiate(family);
            s.transform.parent = mainObj.transform;
            s.transform.localRotation = Quaternion.Euler(0, Mathf.Rad2Deg * angle, 0) * s.transform.localRotation;
            s.transform.localPosition += pos;
            return s;
        }


        public GameObject Slab(Vector3[] contour, Vector3[][] holes, float h, Material material) =>
            ExtrudeContour(contour, holes, new Vector3(0, h, 0), material);

        public GameObject BeamRectSection(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle, Material material) =>
            ApplyMaterial(RightCuboidNamed("Beam", position, vx, vy, dx, dy, dz, angle), material);

        public GameObject BeamCircSection(Vector3 bot, float radius, Vector3 top, Material material) =>
            ApplyMaterial(CylinderNamed("Beam", bot, radius, top), material);

        public void SetView(Vector3 position, Vector3 target, float lens) {
            mainCamera.transform.position = position;
            mainCamera.transform.rotation = Quaternion.FromToRotation(mainCamera.transform.forward, target - position);
            mainCamera.focalLength = lens;
        }

        public void SetResolution(int width, int height) {
            Screen.SetResolution(width, height, false);
        }

        public void ScreenShot(String path) {
            ScreenCapture.CaptureScreenshot(path);
        }
    }
}