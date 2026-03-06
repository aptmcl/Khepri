using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityMeshSimplifier;
using Boolean = Parabox.CSG.Boolean;
using Parabox.CSG;

namespace KhepriUnity {
    public class Primitives : KhepriBase.Primitives {
#if UNITY_STANDALONE_WIN || UNITY_EDITOR_WIN
        [DllImport("user32.dll", SetLastError = true)]
        static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
        [DllImport("user32.dll")]
        static extern IntPtr GetActiveWindow();
        const uint SWP_NOMOVE = 0x0002;
        const uint SWP_NOZORDER = 0x0004;
#endif

        public static Primitives Instance { get; private set; }

        GameObject currentParent;
        List<GameObject> parents;
        GameObject sun;
        public List<GameObject> SelectedGameObjects { get; set; }
        public bool InSelectionProcess { get; set; }
        public bool SelectingManyGameObjects { get; set; }
        Dictionary<GameObject, Outline> highlightedCache;
        Outline.Mode highlightMode;
        Color highlightColor;
        float highlightWidth;

        Transform playerTransform;
        Camera mainCamera;
        Material currentMaterial;
        public Material DefaultMaterial { get; }

        bool applyMaterials;
        bool applyColliders;
        bool enableLights;
        bool enablePointlightShadows;
        private Dictionary<GameObject, Light> lightsCache;
        bool enableMergeParent;
        bool bakedLights;
        bool applyLOD;
        LODLevel[] lodLevels;
        SimplificationOptions lodSimplificationOptions;
        bool makeUVs;
        bool makeStatic;

        Processor<Channel, Primitives> processor;

        public Primitives(GameObject mainObject) {
            this.currentParent = mainObject;
            this.parents = new List<GameObject> { mainObject };
            this.SelectedGameObjects = new List<GameObject>();
            this.InSelectionProcess = false;
            this.highlightedCache = new Dictionary<GameObject, Outline>();
            this.highlightMode = Outline.Mode.OutlineAll;
            this.highlightColor = new Color(1, 0.45f, 0);
            this.highlightWidth = KhepriConstants.DEFAULT_HIGHLIGHT_WIDTH;
            this.mainCamera = Camera.main;
            var player = GameObject.FindWithTag("Player");
            this.playerTransform = player != null ? player.transform : null;
            if (playerTransform == null) {
                Debug.LogWarning("Primitives: Player not found. View operations may be unavailable.");
            }
            this.DefaultMaterial = new Material(Shader.Find("Standard")) {
                enableInstancing = true
            };
            this.currentMaterial = DefaultMaterial;
            this.applyMaterials = true;
            this.applyColliders = true;
            this.enableLights = true;
            this.enablePointlightShadows = true;
            this.bakedLights = false;
            this.applyLOD = true;
            this.makeUVs = false;
            this.makeStatic = true;
            this.enableMergeParent = false;
            this.lightsCache = new Dictionary<GameObject, Light>();
            this.lodLevels = new LODLevel[] {
                new LODLevel(0.5f, 1f) {
                    CombineMeshes = false,
                    CombineSubMeshes = false,
                    SkinQuality = SkinQuality.Auto,
                    ShadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On,
                    ReceiveShadows = true,
                    SkinnedMotionVectors = true,
                    LightProbeUsage = UnityEngine.Rendering.LightProbeUsage.BlendProbes,
                    ReflectionProbeUsage = UnityEngine.Rendering.ReflectionProbeUsage.BlendProbes,
                },
                new LODLevel(0.17f, 0.65f) {
                    CombineMeshes = true,
                    CombineSubMeshes = false,
                    SkinQuality = SkinQuality.Auto,
                    ShadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On,
                    ReceiveShadows = true,
                    SkinnedMotionVectors = true,
                    LightProbeUsage = UnityEngine.Rendering.LightProbeUsage.BlendProbes,
                    ReflectionProbeUsage = UnityEngine.Rendering.ReflectionProbeUsage.Simple
                },
                new LODLevel(0.02f, 0.4225f) {
                    CombineMeshes = true,
                    CombineSubMeshes = true,
                    SkinQuality = SkinQuality.Bone2,
                    ShadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off,
                    ReceiveShadows = false,
                    SkinnedMotionVectors = false,
                    LightProbeUsage = UnityEngine.Rendering.LightProbeUsage.Off,
                    ReflectionProbeUsage = UnityEngine.Rendering.ReflectionProbeUsage.Off
                }
            };
            Instance = this;
        }

        /// <summary>
        /// Clears the singleton instance. Call during cleanup or before creating a new instance.
        /// </summary>
        public static void ClearInstance() {
            Instance = null;
        }

        #region Setters
        public void SetProcessor(Processor<Channel, Primitives> processor) => this.processor = processor;

        public GameObject CurrentParent() => currentParent;
        public GameObject SetCurrentParent(GameObject newParent) {
            GameObject prevParent = currentParent;
            currentParent = newParent;
            return prevParent;
        }

        public void SetApplyMaterials(bool apply) => applyMaterials = apply;
        public void SetApplyColliders(bool apply) => applyColliders = apply;
        public void SetApplyLOD(bool apply) => applyLOD = apply;
        public void SetLODLevels(LODLevel[] lodLevels) => this.lodLevels = lodLevels;
        public void SetLODSimplificationOptions(SimplificationOptions options) =>
            this.lodSimplificationOptions = options;
        public void SetEnableMergeParent(bool enable) => enableMergeParent = enable;
        public void SetCalculateUV(bool apply) => makeUVs = apply;

        public void SetEnableLights(bool apply) {
            if (apply != enableLights) {
                enableLights = apply;
                // Update all current lights retroatively to enableLights value
                UpdateEnableLights();
            }
        }

        public void SetEnablePointLightsShadow(bool apply) {
            if (apply != enablePointlightShadows) {
                enablePointlightShadows = apply;
                // Update all current lights retroatively to enableLights value
                UpdateEnablePointLightsShadow();
            }
        }

        public void SetBakedLights(bool apply) {
            if (apply != bakedLights) {
                bakedLights = apply;
                // Update all current lights retroatively to enableLights value
                UpdateBakedLights();
            }
        }

        private void FindPointLights() {
            if (lightsCache.Count == 0) {
                foreach (Transform child in currentParent.transform) {
                    if (child.name == "PointLight") {
                        Light lightComponent = child.GetComponent<Light>();
                        if (lightComponent != null) {
                            lightsCache[child.gameObject] = lightComponent;
                        }
                    }
                }
            }
        }

        private void UpdateEnableLights() {
            FindPointLights();
            foreach (var light in lightsCache.Values) {
                light.enabled = enableLights;
            }
        }

        private void UpdateBakedLights() {
            FindPointLights();
            // Lightmap bake type setting disabled for build compatibility
        }

        private void UpdateEnablePointLightsShadow() {
            FindPointLights();
            // Shadow settings disabled for build compatibility
        }

        public void MakeStaticGameObjects(bool val) {
            makeStatic = val;
        }

        public void SetHighlightMode(Outline.Mode mode) {
            highlightMode = mode;
            UpdateHighlights();
        }
        public void SetHighlightColor(Color color) {
            highlightColor = color;
            UpdateHighlights();
        }
        public void SetHighlightWidth(float width) {
            highlightWidth = width;
            UpdateHighlights();
        }
        private void UpdateHighlights() {
            foreach (var outline in highlightedCache.Values) {
                if (outline != null) {
                    outline.OutlineMode = highlightMode;
                    outline.OutlineColor = highlightColor;
                    outline.OutlineWidth = highlightWidth;
                }
            }
        }

        public void SetSun(float altitude, float azimuth) {
            if (sun == null) {
                sun = GameObject.FindWithTag("Sun");
            }
            sun.transform.rotation = Quaternion.Euler(altitude, azimuth, 0);
        }

        #endregion

        #region Getters

        // Analysis
        /*
        public string GetRenderResolution() => UnityStats.screenRes;
        public float GetCurrentFPS() {
            return 1 / UnityStats.frameTime;
        }

        public int GetViewTriangleCount() {
            return UnityStats.triangles;
        }

        public int GetViewVertexCount() {
            return UnityStats.vertices;
        }
        */
        public Vector3 GetSunRotation() {
            return sun.transform.rotation.eulerAngles;
        }
        #endregion

        #region Auxiliary
        public void SetActive(GameObject obj, bool state) => obj.SetActive(state);

        GameObject ApplyCollider(GameObject obj, Mesh mesh) {
            if (applyColliders) {
                MeshCollider meshCollider = obj.GetComponent<MeshCollider>();
                if (meshCollider == null)
                    meshCollider = obj.AddComponent<MeshCollider>();

                meshCollider.sharedMesh = mesh;
            }
            return obj;
        }

        GameObject ApplyCollider(GameObject obj) {
            if (applyColliders) {
                Collider collider = obj.GetComponent<Collider>();
                if (collider == null) {
                    MeshCollider meshCollider = obj.AddComponent<MeshCollider>();
                    meshCollider.sharedMesh = obj.GetComponent<MeshFilter>().sharedMesh;
                }
            } else {
                Collider collider = obj.GetComponent<Collider>();
                if (collider != null) {
                    Component.DestroyImmediate(collider);
                }
            }
            return obj;
        }

        public GameObject ApplyLOD(GameObject g) {
            if (!applyLOD)
                return g;
            Mesh mesh = g.GetComponent<MeshFilter>()?.sharedMesh;
            if (mesh == null || mesh.vertexCount < KhepriConstants.MIN_MESH_VERTICES_FOR_LOD)
                return g;

            LODGenerator.GenerateLODGroup(g, lodLevels, true, lodSimplificationOptions);
            return g;
        }

        public GameObject ApplyCurrentMaterial(GameObject obj) =>
            ApplyMaterial(obj, currentMaterial);

        public GameObject ApplyMaterial(GameObject obj, Material material) {
            Renderer renderer = obj.GetComponent<Renderer>();
            if (applyMaterials) {
                renderer.sharedMaterial = material;
            } else {
                renderer.sharedMaterial = DefaultMaterial;
            }
            return obj;
        }

        // This helps improve performance 
        public GameObject MakeStatic(GameObject s) {
            if (makeStatic) {
                s.isStatic = true;
                foreach (Transform trans in s.transform) {
                    MakeStatic(trans.gameObject);
                }
            }
            return s;
        }

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
            if (Vector3.Dot(normalPts, normal) > 0) {
                return pts;
            }
            // Create reversed copy without LINQ allocation
            Vector3[] reversed = new Vector3[pts.Length];
            for (int i = 0; i < pts.Length; i++) {
                reversed[i] = pts[pts.Length - 1 - i];
            }
            return reversed;
        }

        Mesh CreatePolygonMesh(Vector3[] ps) {
            Poly2Mesh.Polygon polygon = new Poly2Mesh.Polygon();
            polygon.outside = new List<Vector3>(ps);
            return Poly2Mesh.CreateMesh(polygon);
        }

        Mesh CreatePolygonMeshWithHoles(Vector3[] ps, Vector3[][] holes) {
            Poly2Mesh.Polygon polygon = new Poly2Mesh.Polygon();
            polygon.outside = new List<Vector3>(ps);
            polygon.holes =
                new List<List<Vector3>>(
                    new List<Vector3[]>(holes).Select(e => new List<Vector3>(e)));
            return Poly2Mesh.CreateMesh(polygon);
        }

        Mesh MeshFromVerticesTriangles(Vector3[] vertices, int[] triangles) {
            Mesh mesh = new Mesh {
                vertices = vertices,
                triangles = triangles
            };
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            return mesh;
        }

        Mesh CreateTrigMeshSharedVertices(Vector3[] ps, Vector3 q) {
            Vector3[] vertices = new Vector3[ps.Length + 1];
            Array.Copy(ps, vertices, ps.Length);
            vertices[ps.Length] = q;
            int[] triangles = new int[ps.Length * 3];
            int k = 0;
            for (int i = 0; i < ps.Length - 1; i++) {
                triangles[k++] = ps.Length;
                triangles[k++] = i + 1;
                triangles[k++] = i;
            }
            triangles[k++] = ps.Length;
            triangles[k++] = 0;
            triangles[k++] = ps.Length - 1;
            return MeshFromVerticesTriangles(vertices, triangles);
        }

        Mesh CreateQuadMeshSharedVertices(Vector3[] ps, Vector3[] qs, bool closed) {
            Vector3[] vertices = new Vector3[ps.Length * 2];
            Array.Copy(ps, vertices, ps.Length);
            Array.Copy(qs, 0, vertices, ps.Length, qs.Length);
            int[] triangles = new int[(ps.Length + (closed ? 1 : 0)) * 2 * 3];
            int k = 0;
            for (int i = 0, j = ps.Length; i < ps.Length - 1; i++, j++) {
                triangles[k++] = j + 1;
                triangles[k++] = i + 1;
                triangles[k++] = i;
                triangles[k++] = j;
                triangles[k++] = j + 1;
                triangles[k++] = i;
            }
            if (closed) {
                triangles[k++] = ps.Length;
                triangles[k++] = 0;
                triangles[k++] = ps.Length - 1;
                triangles[k++] = 2 * ps.Length - 1;
                triangles[k++] = ps.Length;
                triangles[k++] = ps.Length - 1;
            }
            return MeshFromVerticesTriangles(vertices, triangles);
        }

        Mesh CreateTrigMesh(Vector3[] ps, Vector3 q) {
            Vector3[] vertices = new Vector3[ps.Length * 3];
            int[] triangles = new int[ps.Length * 3];
            for (int i = 0; i < triangles.Length; i++) {
                triangles[i] = triangles.Length - 1 - i;
            }
            int v = 0;
            for (int i = 0; i < ps.Length - 1; i++) {
                vertices[v++] = ps[i];
                vertices[v++] = ps[i + 1];
                vertices[v++] = q;
            }
            vertices[v++] = ps[ps.Length - 1];
            vertices[v++] = ps[0];
            vertices[v++] = q;
            return MeshFromVerticesTriangles(vertices, triangles);
        }

        Mesh CreateQuadMesh(Vector3[] ps, Vector3[] qs, bool closed) {
            Vector3[] vertices = new Vector3[(ps.Length + (closed ? 1 : 0)) * 2 * 3];
            int[] triangles = new int[vertices.Length];
            for (int i = 0; i < triangles.Length; i++) {
                triangles[i] = triangles.Length - 1 - i;
            }
            int v = 0;
            for (int i = 0; i < ps.Length - 1; i++) {
                vertices[v++] = ps[i];
                vertices[v++] = ps[i + 1];
                vertices[v++] = qs[i + 1];
                vertices[v++] = ps[i];
                vertices[v++] = qs[i + 1];
                vertices[v++] = qs[i];
            }
            if (closed) {
                vertices[v++] = ps[ps.Length - 1];
                vertices[v++] = ps[0];
                vertices[v++] = qs[0];
                vertices[v++] = ps[ps.Length - 1];
                vertices[v++] = qs[0];
                vertices[v++] = qs[qs.Length - 1];
            }
            return MeshFromVerticesTriangles(vertices, triangles);
        }

        Mesh CombineMesh(Mesh[] meshes) {
            Mesh mainMesh = new Mesh();
            List<CombineInstance> combineInstances = new List<CombineInstance>();

            for (int i = 0; i < meshes.Length; i++) {
                CombineInstance combineInstance = new CombineInstance();
                combineInstance.subMeshIndex = 0;
                combineInstance.mesh = meshes[i];
                combineInstance.transform = Matrix4x4.identity;
                combineInstances.Add(combineInstance);
            }
            mainMesh.CombineMeshes(combineInstances.ToArray());
            mainMesh.Optimize();
            //CalculateUVs(mainMesh);
            return mainMesh;
        }

        #endregion

        #region Khepri Operations
        // ||||||||||||||||||||||||||| Layer |||||||||||||||||||||||||||
        public GameObject CreateParent(String name, bool active) {
            GameObject newParent = parents.Find(p => p.name == name);
            if (newParent == null) {
                newParent = MakeStatic(new GameObject(name));
                parents.Add(newParent);
            }
            SetActive(newParent, active);
            return newParent;
        }

        public void SwitchToParent(GameObject newParent) {
            SetActive(currentParent, false);
            SetActive(newParent, true);
            currentParent = newParent;
        }

        public void OptimizeParent() {
            if (enableMergeParent)
                MergeParent();
            StaticBatchingUtility.Combine(currentParent.gameObject);
        }

        public void MergeParent() {
            if (currentParent.GetComponent<MeshFilter>() != null || currentParent.transform.childCount == 0) return; // Return if the current parent has already merged its mesh
            Renderer[] renderers = LODGenerator.GetChildRenderersForLOD(currentParent);
            var meshRenderers = (from renderer in renderers
                                 where renderer.enabled && renderer as MeshRenderer != null
                                 select renderer as MeshRenderer).ToArray();

            Material[] materials;
            Mesh mesh = MeshCombiner.CombineMeshes(currentParent.transform, meshRenderers, out materials);
            mesh.Optimize();
            MeshRenderer meshRenderer = currentParent.AddComponent<MeshRenderer>();
            meshRenderer.materials = materials;
            MeshFilter meshFilter = currentParent.AddComponent<MeshFilter>();
            meshFilter.sharedMesh = mesh;

            foreach (var renderer in renderers) {
                renderer.enabled = false;
            }
        }

        // Sets a color on the layer
        public GameObject SetLayerColor(GameObject layer, Color color) {
            Material mat = new Material(Shader.Find("Diffuse"));
            mat.color = color;
            mat.name = "__layer_color__";

            var renderers = layer.GetComponentsInChildren<Renderer>();
            foreach (var renderer in renderers) {
                List<Material> materials = new List<Material>(renderer.sharedMaterials);
                materials.Add(mat);
                renderer.sharedMaterials = materials.ToArray();
            }

            return layer;
        }

        public GameObject ResetLayerColor(GameObject layer) {
            var renderers = layer.GetComponentsInChildren<Renderer>();
            foreach (var renderer in renderers) {
                List<Material> newMaterials = new List<Material>();
                foreach (var material in renderer.sharedMaterials) {
                    if (!material.name.Equals("__layer_color__"))
                        newMaterials.Add(material);
                }
                renderer.sharedMaterials = newMaterials.ToArray();
            }

            return layer;
        }

        // ||||||||||||||||||||||||||| Delete |||||||||||||||||||||||||||
        public void DeleteMany(GameObject[] objs) {
            int count = objs.Length;
            for (int i = 0; i < count; i++) {
                lightsCache.Remove(objs[i]);
                highlightedCache.Remove(objs[i]);
                GameObject.DestroyImmediate(objs[i]);
            }
        }

        public void DeleteAllInParent(GameObject parent) {
            int count = parent.transform.childCount;
            for (int i = 0; i < count; i++) {
                GameObject child = parent.transform.GetChild(0).gameObject;
                lightsCache.Remove(child);
                highlightedCache.Remove(child);
                GameObject.DestroyImmediate(child);
            }
        }

        public void DeleteAll() {
            foreach (GameObject parent in parents) {
                DeleteAllInParent(parent);
            }
        }

        // ||||||||||||||||||||||||||| Geometric transformations |||||||||||||||||||||||||||
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

        // ||||||||||||||||||||||||||| Boolean operations |||||||||||||||||||||||||||
        // ||||||||||||||||||||||||||| Boolean operations |||||||||||||||||||||||||||
        public GameObject Unite(GameObject s0, GameObject s1) {
            CSG_Model result = Boolean.Union(s0, s1);
            GameObject composite = new GameObject();
            composite.transform.parent = currentParent.transform;
            composite.AddComponent<MeshFilter>().sharedMesh = result.mesh;
            composite.AddComponent<MeshRenderer>().sharedMaterials = result.materials.ToArray();
            composite.name = "Union";
            ApplyCollider(composite, result.mesh);
            //ApplyLOD(composite);
            GameObject.DestroyImmediate(s0);
            GameObject.DestroyImmediate(s1);
            return MakeStatic(composite);
        }

        public GameObject Subtract(GameObject s0, GameObject s1) {
            CSG_Model result = Boolean.Subtract(s0, s1);
            GameObject composite = new GameObject();
            composite.transform.parent = currentParent.transform;
            composite.AddComponent<MeshFilter>().sharedMesh = result.mesh;
            composite.AddComponent<MeshRenderer>().sharedMaterials = result.materials.ToArray();
            composite.name = "Subtraction";
            ApplyCollider(composite, result.mesh);
            //ApplyLOD(composite);
            GameObject.DestroyImmediate(s0);
            GameObject.DestroyImmediate(s1);
            return MakeStatic(composite);
        }

        public GameObject Intersect(GameObject s0, GameObject s1) {
            CSG_Model result = Boolean.Intersect(s0, s1);
            GameObject composite = new GameObject();
            composite.transform.parent = currentParent.transform;
            composite.AddComponent<MeshFilter>().sharedMesh = result.mesh;
            composite.AddComponent<MeshRenderer>().sharedMaterials = result.materials.ToArray();
            composite.name = "Intersection";
            ApplyCollider(composite, result.mesh);
            //ApplyLOD(composite);
            GameObject.DestroyImmediate(s0);
            GameObject.DestroyImmediate(s1);
            return MakeStatic(composite);
        }

        public void SubtractFrom(GameObject s0, GameObject s1) {
            CSG_Model result = Boolean.Subtract(s0, s1);
            s0.GetComponent<MeshFilter>().sharedMesh = result.mesh;
            ApplyCollider(s0, result.mesh);
            GameObject.DestroyImmediate(s1);
            s0.name += " Subtraction";
        }

        T EnsureNonNull<T>(T arg) {
            if (arg == null) throw new NullReferenceException();
            return arg;
        }
        public int SetMaxNonInteractiveRequests(int n) {
            int prev = processor.MaxRepeated;
            processor.MaxRepeated = n;
            return prev;
        }
        // ||||||||||||||||||||||||||| Interactiveness |||||||||||||||||||||||||||
        public void SetNonInteractiveRequests() => SetMaxNonInteractiveRequests(Int32.MaxValue);

        public void SetInteractiveRequests() => SetMaxNonInteractiveRequests(0);

        // ||||||||||||||||||||||||||| Resources |||||||||||||||||||||||||||
        public Material LoadMaterial(String name) => EnsureNonNull(Resources.Load<Material>(name));
        public void SetCurrentMaterial(Material material) => currentMaterial = material;
        public Material CurrentMaterial() => currentMaterial;
        public GameObject LoadResource(String name) => Resources.Load<GameObject>(name);

        public Material CreateMaterial(String name, Color baseColor, float alpha,
                                       float metallic, float roughness,
                                       float transmission,
                                       Color emissionColor, float emissionStrength) {
            Material mat = new Material(Shader.Find("Standard"));
            mat.name = name;
            mat.enableInstancing = true;
            Color color = new Color(baseColor.r, baseColor.g, baseColor.b, alpha);
            mat.SetColor("_Color", color);
            mat.SetFloat("_Metallic", metallic);
            mat.SetFloat("_Glossiness", 1.0f - roughness);
            if (transmission > 0 || alpha < 1.0f) {
                float effectiveAlpha = transmission > 0 ? 1.0f - transmission : alpha;
                mat.SetColor("_Color", new Color(baseColor.r, baseColor.g, baseColor.b, effectiveAlpha));
                mat.SetFloat("_Mode", 3);
                mat.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                mat.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                mat.SetInt("_ZWrite", 0);
                mat.DisableKeyword("_ALPHATEST_ON");
                mat.DisableKeyword("_ALPHABLEND_ON");
                mat.EnableKeyword("_ALPHAPREMULTIPLY_ON");
                mat.renderQueue = 3000;
            }
            if (emissionStrength > 0 && (emissionColor.r > 0 || emissionColor.g > 0 || emissionColor.b > 0)) {
                mat.EnableKeyword("_EMISSION");
                mat.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
                mat.SetColor("_EmissionColor", emissionColor * emissionStrength);
            }
            return mat;
        }

        // Points and lines
        public GameObject Line(Vector3[] ps, Material material) {
            GameObject s = new GameObject("Line");
            s.transform.parent = currentParent.transform;
            LineRenderer lineRenderer = s.AddComponent<LineRenderer>();
            lineRenderer.positionCount = ps.Length;
            lineRenderer.SetPositions(ps);
            ApplyMaterial(s, material);
            return s;
        }

        // 2D Geometry primitives
        public GameObject Trig(Vector3 p0, Vector3 p1, Vector3 p2, Material material) {
            GameObject s = new GameObject("Trig");
            s.transform.parent = currentParent.transform;
            s.AddComponent<MeshFilter>().sharedMesh = //Unity uses clockwise order
                MeshFromVerticesTriangles(new Vector3[] { p0, p1, p2 }, new int[] { 2, 1, 0 });
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            return s;
        }
        public GameObject Quad(Vector3 p0, Vector3 p1, Vector3 p2, Vector3 p3, Material material) {
            GameObject s = new GameObject("Quad");
            s.transform.parent = currentParent.transform;
            s.AddComponent<MeshFilter>().sharedMesh =
                MeshFromVerticesTriangles(new Vector3[] { p0, p1, p2, p3 }, new int[] { 2, 1, 0, 3, 2, 0 });
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            return s;
        }
        public GameObject NGon(Vector3[] ps, Vector3 q, bool smooth, Material material) {
            GameObject s = new GameObject("NGon");
            s.transform.parent = currentParent.transform;
            s.AddComponent<MeshFilter>().sharedMesh =
                smooth ? CreateTrigMeshSharedVertices(ps, q) : CreateTrigMesh(ps, q);
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            return s;
        }
        public GameObject QuadStrip(Vector3[] ps, Vector3[] qs, bool smooth, bool closed, Material material) {
            GameObject s = new GameObject("NGon");
            s.transform.parent = currentParent.transform;
            s.AddComponent<MeshFilter>().sharedMesh =
                smooth ? CreateQuadMeshSharedVertices(ps, qs, closed) : CreateQuadMesh(ps, qs, closed);
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            return s;
        }
        public GameObject SurfacePolygonNamed(String name, Vector3[] ps, Material material) {
            GameObject s = new GameObject(name);
            s.transform.parent = currentParent.transform;
            Mesh botMesh = CreatePolygonMesh(ps);
            Array.Reverse(ps);
            Mesh topMesh = CreatePolygonMesh(ps);
            MeshFilter meshFilter = s.AddComponent<MeshFilter>();
            Mesh[] allMeshes = { botMesh, topMesh };
            meshFilter.sharedMesh = CombineMesh(allMeshes);
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            ApplyCollider(s);
            ApplyLOD(s);
            return MakeStatic(s);
        }
        public GameObject SurfacePolygonWithMaterial(Vector3[] ps, Material material) =>
            SurfacePolygonNamed("SurfacePolygon", ps, material);
        public GameObject SurfacePolygon(Vector3[] ps) =>
            SurfacePolygonWithMaterial(ps, currentMaterial);

        public GameObject SurfacePolygonWithHolesNamed(string name, Vector3[] contour, Vector3[][] holes, Material material) {
            GameObject s = new GameObject(name);
            s.transform.parent = currentParent.transform;
            Mesh botMesh = CreatePolygonMeshWithHoles(contour, holes);
            int[] reversedTriangles = (int[])botMesh.triangles.Clone();
            Array.Reverse(reversedTriangles);
            Mesh topMesh = MeshFromVerticesTriangles(botMesh.vertices, reversedTriangles);
            s.AddComponent<MeshFilter>().sharedMesh = CombineMesh(new Mesh[] { topMesh, botMesh });
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            ApplyCollider(s);
            ApplyLOD(s);
            return MakeStatic(s);
        }
        public GameObject SurfacePolygonWithHolesWithMaterial(Vector3[] contour, Vector3[][] holes, Material material) =>
            SurfacePolygonWithHolesNamed("SurfacePolygon", contour, holes, material);
        public GameObject SurfacePolygonWithHoles(Vector3[] contour, Vector3[][] holes) =>
            SurfacePolygonWithHolesWithMaterial(contour, holes, currentMaterial);


        public GameObject SurfaceMeshNamed(String name, Vector3[] vertices, int[] triangles, Material material) {
            GameObject s = new GameObject(name);
            s.transform.parent = currentParent.transform;
            Mesh botMesh = MeshFromVerticesTriangles(vertices, triangles);
            Array.Reverse(triangles);
            Mesh topMesh = MeshFromVerticesTriangles(vertices, triangles);
            MeshFilter meshFilter = s.AddComponent<MeshFilter>();
            meshFilter.sharedMesh = CombineMesh(new Mesh[] { botMesh, topMesh });
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            ApplyCollider(s);
            ApplyLOD(s);
            return MakeStatic(s);
        }
        public GameObject SurfaceMeshWithMaterial(Vector3[] vertices, int[] triangles, Material material) =>
            SurfaceMeshNamed("SurfaceMesh", vertices, triangles, material);
        public GameObject SurfaceMesh(Vector3[] vertices, int[] triangles) =>
            SurfaceMeshWithMaterial(vertices, triangles, currentMaterial);


        public GameObject SurfaceFromGridNamed(string name, int m, int n, Vector3[] pts, bool closedM, bool closedN, int level, Material material) {
            Vector3[] vertices = pts;
            int[] triangles = new int[pts.Length * 2 * 3];
            int k = 0;
            int rm = closedM ? m : m - 1;
            int rn = closedN ? n : n - 1;
            for (int i = 0; i < rm; i++) {
                for (int j = 0; j < rn; j++) {
                    int i11 = i * n + j;
                    int i12 = i * n + (j + 1) % n;
                    int i22 = ((i + 1) % m) * n + (j + 1) % n;
                    int i21 = ((i + 1) % m) * n + j;
                    triangles[k++] = i11;
                    triangles[k++] = i22;
                    triangles[k++] = i12;
                    triangles[k++] = i11;
                    triangles[k++] = i21;
                    triangles[k++] = i22;
                }
            }
            return SurfaceMeshNamed(name, vertices, triangles, material);
        }
        public GameObject SurfaceFromGridWithMaterial(int m, int n, Vector3[] pts, bool closedM, bool closedN, int level, Material material) =>
            SurfaceFromGridNamed("SurfaceGrid", m, n, pts, closedM, closedN, level, material);
        public GameObject SurfaceFromGrid(int m, int n, Vector3[] pts, bool closedM, bool closedN, int level) =>
            SurfaceFromGridWithMaterial(m, n, pts, closedM, closedN, level, currentMaterial);


        // ||||||||||||||||||||||||||| Simple Geometry |||||||||||||||||||||||||||
        public GameObject PointLight(Vector3 position, Color color, float range, float intensity) {
            GameObject pLight = new GameObject("PointLight");
            Light light = pLight.AddComponent<Light>();
            light.enabled = enableLights;
            pLight.transform.parent = currentParent.transform;
            light.type = LightType.Point;
            light.color = color;
            light.range = range;         // How far the light is emitted from the center of the object
            light.intensity = intensity; // Brightness of the light
            light.shadows = enablePointlightShadows ? LightShadows.Hard : LightShadows.None;
            pLight.transform.localPosition = position;
            lightsCache[pLight] = light;
            return MakeStatic(pLight);
        }

        public GameObject Window(Vector3 position, Quaternion rotation, float dx, float dy, float dz) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cube);
            s.name = "Window";
            s.transform.parent = currentParent.transform;
            s.transform.localScale = new Vector3(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            s.transform.localRotation = rotation;
            s.transform.localPosition = position + rotation * new Vector3(dx / 2, dy / 2, dz / 2);
            ApplyMaterial(s, Resources.Load<Material>("Default/Materials/Glass"));
            ApplyCollider(s);
            return MakeStatic(s);
        }

        public GameObject BoxNamed(String name, Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, Material material) {
            Quaternion rotation = Quaternion.LookRotation(vx, vy);
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cube);
            s.name = name;
            s.transform.parent = currentParent.transform;
            s.transform.localScale = new Vector3(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            s.transform.localRotation = rotation;
            s.transform.localPosition = position + rotation * new Vector3(dx / 2, dy / 2, dz / 2);
            ApplyMaterial(s, material);
            ApplyCollider(s);
            return MakeStatic(s);
        }
        public GameObject BoxWithMaterial(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, Material material) =>
            BoxNamed("Box", position, vx, vy, dx, dy, dz, material);
        public GameObject Box(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz) =>
            BoxWithMaterial(position, vx, vy, dx, dy, dz, currentMaterial);

        public GameObject RightCuboidNamed(String name, Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle, Material material) {
            Quaternion rotation = Quaternion.LookRotation(vx, vy);
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cube);
            rotation = rotation * Quaternion.Euler(0, 0, Mathf.Rad2Deg * angle);
            s.name = name;
            s.transform.parent = currentParent.transform;
            s.transform.localScale = new Vector3(Math.Abs(dx), Math.Abs(dy), Math.Abs(dz));
            s.transform.localRotation = rotation;
            s.transform.localPosition = position + rotation * new Vector3(0, 0, dz / 2);
            ApplyCollider(s);
            ApplyMaterial(s, material);
            return MakeStatic(s);
        }
        public GameObject RightCuboidWithMaterial(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle, Material material) =>
            RightCuboidNamed("RightCuboid", position, vx, vy, dx, dy, dz, angle, material);
        public GameObject RightCuboid(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle) =>
            RightCuboidWithMaterial(position, vx, vy, dx, dy, dz, angle, currentMaterial);

        public GameObject SphereNamed(String name, Vector3 center, float radius, Material material) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            s.name = name;
            s.transform.parent = currentParent.transform;
            s.transform.localScale = new Vector3(2 * radius, 2 * radius, 2 * radius);
            s.transform.localPosition = center;
            ApplyCollider(s);
            ApplyMaterial(s, material);
            ApplyLOD(s);
            return MakeStatic(s);
        }
        public GameObject SphereWithMaterial(Vector3 center, float radius, Material material) =>
            SphereNamed("Sphere", center, radius, material);
        public GameObject Sphere(Vector3 center, float radius) =>
            SphereWithMaterial(center, radius, currentMaterial);
        public Vector3 SphereCenter(GameObject s) => s.transform.localPosition;
        public float SphereRadius(GameObject s) => s.transform.localScale.x / 2;

        public GameObject CylinderNamed(String name, Vector3 bottom, float radius, Vector3 top, Material material) {
            GameObject s = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            s.name = name;
            float d = Vector3.Distance(bottom, top);
            s.transform.parent = currentParent.transform;
            s.transform.localScale = new Vector3(2 * radius, d / 2, 2 * radius);
            s.transform.localRotation = Quaternion.FromToRotation(Vector3.up, top - bottom);
            s.transform.localPosition = bottom + (top - bottom) / 2;
            ApplyCollider(s);
            ApplyMaterial(s, material);
            ApplyLOD(s);
            return MakeStatic(s);
        }
        public GameObject CylinderWithMaterial(Vector3 bottom, float radius, Vector3 top, Material material) =>
            CylinderNamed("Cylinder", bottom, radius, top, material);
        public GameObject Cylinder(Vector3 bottom, float radius, Vector3 top) =>
            CylinderWithMaterial(bottom, radius, top, currentMaterial);


        public string ShapeType(GameObject s) => s.name;

        // ||||||||||||||||||||||||||| Complex Geometry |||||||||||||||||||||||||||
        public GameObject PyramidNamed(String name, Vector3[] ps, Vector3 q, Material material) {
            ps = ReverseIfNeeded(ps, ps[0] - q);
            GameObject s = new GameObject(name);
            s.transform.parent = currentParent.transform;

            Mesh botMesh = CreatePolygonMesh(ps);
            Mesh exteriorMesh = CreateTrigMesh(ps, q);
            MeshFilter meshFilter = s.AddComponent<MeshFilter>();
            Mesh[] allMeshes = { botMesh, exteriorMesh };
            meshFilter.sharedMesh = CombineMesh(allMeshes);
            s.AddComponent<MeshRenderer>();

            ApplyMaterial(s, material);
            ApplyCollider(s);
            ApplyLOD(s);
            return MakeStatic(s);
        }

        public GameObject PyramidWithMaterial(Vector3[] ps, Vector3 q, Material material) =>
            PyramidNamed("Pyramid", ps, q, material);
        public GameObject Pyramid(Vector3[] ps, Vector3 q) =>
            PyramidWithMaterial(ps, q, currentMaterial);

        public GameObject PyramidFrustumNamed(String name, Vector3[] ps, Vector3[] qs, Material material) {
            ps = ReverseIfNeeded(ps, ps[0] - qs[0]);
            qs = ReverseIfNeeded(qs, qs[0] - ps[0]);
            GameObject s = new GameObject(name);
            s.transform.parent = currentParent.transform;
            Mesh botMesh = CreatePolygonMesh(ps);
            Mesh topMesh = CreatePolygonMesh(qs);
            Array.Reverse(qs);
            Mesh exteriorMesh = CreateQuadMesh(ps, qs, true);
            MeshFilter meshFilter = s.AddComponent<MeshFilter>();
            Mesh[] allMeshes = { botMesh, topMesh, exteriorMesh };
            meshFilter.sharedMesh = CombineMesh(allMeshes);
            s.AddComponent<MeshRenderer>();

            ApplyMaterial(s, material);
            ApplyCollider(s);
            ApplyLOD(s);
            return MakeStatic(s);
        }
        public GameObject PyramidFrustumWithMaterial(Vector3[] ps, Vector3[] qs, Material material) =>
            PyramidFrustumNamed("PyramidFrustum", ps, qs, material);
        public GameObject PyramidFrustum(Vector3[] ps, Vector3[] qs) =>
            PyramidFrustumWithMaterial(ps, qs, currentMaterial);
        public GameObject ExtrudedContourNamed(string name, Vector3[] contour, bool smoothContour, Vector3[][] holes, bool[] smoothHoles, Vector3 v, Material material) {
            contour = ReverseIfNeeded(contour, -v);
            GameObject s = new GameObject(name);
            s.transform.parent = currentParent.transform;
            Mesh botMesh = CreatePolygonMeshWithHoles(contour, holes);
            // Create top vertices with offset
            Vector3[] topVertices = new Vector3[botMesh.vertices.Length];
            for (int i = 0; i < botMesh.vertices.Length; i++) {
                topVertices[i] = botMesh.vertices[i] + v;
            }
            // Reverse triangles in place
            int[] reversedTriangles = (int[])botMesh.triangles.Clone();
            Array.Reverse(reversedTriangles);
            Mesh topMesh = MeshFromVerticesTriangles(topVertices, reversedTriangles);
            // Reverse contour for bottom
            Vector3[] botContour = new Vector3[contour.Length];
            for (int i = 0; i < contour.Length; i++) {
                botContour[i] = contour[contour.Length - 1 - i];
            }
            // Create top contour with offset
            Vector3[] topContour = new Vector3[botContour.Length];
            for (int i = 0; i < botContour.Length; i++) {
                topContour[i] = botContour[i] + v;
            }
            Mesh exteriorMesh = smoothContour ? CreateQuadMeshSharedVertices(topContour, botContour, true) : CreateQuadMesh(topContour, botContour, true);
            List<Mesh> meshes = new List<Mesh>() { topMesh, botMesh, exteriorMesh };
            for (int i = 0; i < holes.Length; i++) {
                Vector3[] hole = ReverseIfNeeded(holes[i], -v);
                Vector3[] topHole = new Vector3[hole.Length];
                for (int j = 0; j < hole.Length; j++) {
                    topHole[j] = hole[j] + v;
                }
                meshes.Add(smoothHoles[i] ? CreateQuadMeshSharedVertices(topHole, hole, true) : CreateQuadMesh(topHole, hole, true));
            }
            s.AddComponent<MeshFilter>().sharedMesh = CombineMesh(meshes.ToArray());
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            ApplyCollider(s);
            ApplyLOD(s);
            return MakeStatic(s);
        }
        public GameObject ExtrudedContour(Vector3[] contour, bool smoothContour, Vector3[][] holes, bool[] smoothHoles, Vector3 v, Material material) =>
            ExtrudedContourNamed("Extrusion", contour, smoothContour, holes, smoothHoles, v, material);

        public GameObject CreateTerrain(Texture2D texture, float size) {
            TerrainData terrainData = new TerrainData();
            terrainData.size = new Vector3(2000, 1, 2000);
            TerrainLayer terrainLayer = new TerrainLayer();
            terrainLayer.diffuseTexture = texture;
            terrainLayer.tileOffset = Vector2.zero;
            terrainLayer.tileSize = Vector2.one * size;
            terrainData.terrainLayers = new TerrainLayer[] { terrainLayer };
            GameObject terrain = Terrain.CreateTerrainGameObject(terrainData);
            return terrain;
            /*GameObject terrain = new GameObject("Terrain");
            terrain.transform.parent = currentParent.transform;
            TerrainData terrainData = new TerrainData();
            terrainData.size = new Vector3(10, 600, 10);
            terrainData.heightmapResolution = 512;
            terrainData.baseMapResolution = 1024;
            terrainData.SetDetailResolution(1024, 16);

            TerrainCollider collider = terrain.AddComponent<TerrainCollider>();
            Terrain terrain_aux = terrain.AddComponent<Terrain>();
            collider.terrainData = terrainData;
            terrain_aux.terrainData = terrainData;
            return terrain;*/
        }

        // Text
        public GameObject Text(string txt, Vector3 pos, Vector3 vx, Vector3 vy, string fontName, int fontSize) {
            GameObject s = new GameObject("Text");
            TextMesh textMesh = s.AddComponent<TextMesh>();
            textMesh.anchor = TextAnchor.LowerLeft;
            //            textMesh.font = (Font)Resources.GetBuiltinResource(typeof(Font), fontName);
            textMesh.font = Resources.Load<Font>(fontName);
            textMesh.fontSize = 100 * fontSize;
            textMesh.text = txt;
            s.transform.parent = currentParent.transform;
            s.transform.localScale = new Vector3(0.01f, 0.01f, 0.01f);
            s.transform.localRotation = Quaternion.LookRotation(vx, vy);
            s.transform.localPosition = pos;
            return s;
        }

        // Mesh Combination
        public GameObject Canonicalize(GameObject s) {
            MeshFilter[] meshFilters = s.GetComponentsInChildren<MeshFilter>();
            if (meshFilters.Length == 0) {
                return s;
            }
            Dictionary<Material, List<MeshFilter>> materialMeshFilters = new Dictionary<Material, List<MeshFilter>>();
            foreach (MeshFilter meshFilter in meshFilters) {
                Material[] materials = meshFilter.GetComponent<MeshRenderer>().sharedMaterials;
                if (materials != null) {
                    if (materials.Length > 1 || materials[0] == null) {
                        return s;
                    } else if (materialMeshFilters.ContainsKey(materials[0])) {
                        materialMeshFilters[materials[0]].Add(meshFilter);
                    } else {
                        materialMeshFilters.Add(materials[0], new List<MeshFilter>() { meshFilter });
                    }
                }
            }
            if (materialMeshFilters.Count == 0) {
                return s;
            } else {
                List<GameObject> combinedObjects = new List<GameObject>();
                foreach (KeyValuePair<Material, List<MeshFilter>> entry in materialMeshFilters) {
                    Material material = entry.Key;
                    List<MeshFilter> meshes = entry.Value;
                    string materialName = material.name; // ToString().Split(' ')[0];
                    CombineInstance[] combine = new CombineInstance[meshes.Count];
                    for (int i = 0; i < meshes.Count; i++) {
                        combine[i].mesh = meshes[i].sharedMesh;
                        combine[i].transform = meshes[i].transform.localToWorldMatrix;
                    }
                    Mesh combinedMesh = new Mesh();
                    combinedMesh.CombineMeshes(combine);
                    combinedMesh.Optimize();
                    //Unwrapping.GenerateSecondaryUVSet(combinedMesh); 
                    GameObject combinedObject = new GameObject(materialName);
                    MeshFilter filter = combinedObject.AddComponent<MeshFilter>();
                    filter.sharedMesh = combinedMesh;
                    MeshRenderer renderer = combinedObject.AddComponent<MeshRenderer>();
                    renderer.sharedMaterial = material;
                    combinedObjects.Add(combinedObject);
                }
                //remove old children
                DeleteAllInParent(s);
                //Add new ones
                foreach (GameObject combinedObject in combinedObjects) {
                    combinedObject.transform.parent = s.transform;
                }
                return s;
            }
        }

        // ||||||||||||||||||||||||||| Blocks |||||||||||||||||||||||||||
        //We could use Prefabs for this but they can only be used with the Unity Editor and I'm not convinced we want to depend on it.

        //Creating instances
        public GameObject CreateBlockInstance(GameObject block, Vector3 position, Vector3 vx, Vector3 vy, float scale) {
            GameObject obj = InstantiateFamily(block, position, vx, vy, scale);
            obj.SetActive(true);
            return MakeStatic(obj);
            //return obj;
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

        // ||||||||||||||||||||||||||| BIM |||||||||||||||||||||||||||
        public GameObject InstantiateFamily(GameObject family, Vector3 pos, Vector3 vx, Vector3 vy, float scale) {
            Quaternion rotation = Quaternion.LookRotation(vx, vy);
            GameObject s = GameObject.Instantiate(family);
            s.transform.parent = currentParent.transform;
            s.transform.localRotation = rotation * s.transform.localRotation;
            s.transform.localPosition = pos;
            s.transform.localScale *= scale;
            return MakeStatic(s);
        }

        public GameObject InstantiateBIMElement(GameObject family, Vector3 pos, float angle) {
            GameObject s = GameObject.Instantiate(family);
            s.transform.parent = currentParent.transform;
            s.transform.localRotation = Quaternion.Euler(0, Mathf.Rad2Deg * angle, 0) * s.transform.localRotation;
            s.transform.localPosition += pos;
            return MakeStatic(s);
        }

        public GameObject Slab(Vector3[] contour, bool smoothContour, Vector3[][] holes, bool[] smoothHoles, float h, Material material) =>
            ExtrudedContourNamed("Slab", contour, smoothContour, holes, smoothHoles, new Vector3(0, h, 0), material);

        public GameObject BeamRectSection(Vector3 position, Vector3 vx, Vector3 vy, float dx, float dy, float dz, float angle, Material material) =>
            RightCuboidNamed("Beam", position, vx, vy, dx, dy, dz, angle, material);

        public GameObject BeamCircSection(Vector3 bot, float radius, Vector3 top, Material material) =>
            CylinderNamed("Beam", bot, radius, top, material);

        public GameObject Panel(Vector3[] pts, Vector3 n, Material material) {
            Vector3[] bps = ReverseIfNeeded(pts, -n);
            // Create top points with offset and reversed
            Vector3[] tps = new Vector3[bps.Length];
            for (int i = 0; i < bps.Length; i++) {
                tps[i] = bps[bps.Length - 1 - i] + n;
            }
            GameObject s = new GameObject("Panel");
            s.transform.parent = currentParent.transform;
            Mesh botMesh = CreatePolygonMesh(bps);
            Mesh topMesh = CreatePolygonMesh(tps);
            Array.Reverse(bps);
            Mesh sideMesh = CreateQuadMesh(bps, tps, true);
            MeshFilter meshFilter = s.AddComponent<MeshFilter>();
            meshFilter.sharedMesh = CombineMesh(new Mesh[] { botMesh, topMesh, sideMesh });
            s.AddComponent<MeshRenderer>();
            ApplyMaterial(s, material);
            ApplyCollider(s);
            ApplyLOD(s);
            return MakeStatic(s);
        }

        // ||||||||||||||||||||||||||| View operations |||||||||||||||||||||||||||
        public void SetView(Vector3 position, Vector3 target, float lens) {
            if (playerTransform == null || mainCamera == null) {
                Debug.LogWarning("Primitives: Cannot SetView - player or camera not available.");
                return;
            }
            playerTransform.position = position - mainCamera.gameObject.transform.localPosition;
            mainCamera.transform.LookAt(target);
            mainCamera.focalLength = lens;
            Canvas.ForceUpdateCanvases();
        }

        public Vector3 ViewCamera() {
            if (mainCamera == null) return Vector3.zero;
            return mainCamera.transform.position;
        }

        public Vector3 ViewTarget() {
            if (mainCamera == null) return Vector3.forward;
            return mainCamera.transform.position + mainCamera.transform.forward;
        }

        public float ViewLens() {
            if (mainCamera == null) return 0f;
            return mainCamera.focalLength;
        }

        public void SetResolution(int width, int height) {
            Screen.SetResolution(width, height, false);
        }

        public void ViewSize(int width, int height) {
#if UNITY_STANDALONE_WIN || UNITY_EDITOR_WIN
            SetWindowPos(GetActiveWindow(), IntPtr.Zero, 0, 0, width, height, SWP_NOMOVE | SWP_NOZORDER);
#else
            Screen.SetResolution(width, height, false);
#endif
        }

        public void ScreenShot(String path) {
            ScreenCapture.CaptureScreenshot(path);
            /*Texture2D texture = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, false);
            texture.ReadPixels(new Rect(0, 0, Screen.width, Screen.height), 0, 0);
            texture.Apply();
            byte[] bytes = texture.EncodeToPNG();
            File.WriteAllBytes(path, bytes);*/
        }

        // ||||||||||||||||||||||||||| Object selection |||||||||||||||||||||||||||
        public void SelectGameObjects(GameObject[] objs) {
            // Deselect all currently highlighted objects
            foreach (var outline in highlightedCache.Values) {
                if (outline != null)
                    outline.enabled = false;
            }
            highlightedCache.Clear();

            // Select new objects
            foreach (GameObject obj in objs) {
                Outline outline = obj.GetComponent<Outline>();
                if (outline == null) {
                    outline = obj.AddComponent<Outline>();
                }

                highlightedCache[obj] = outline;
                outline.OutlineMode = highlightMode;
                outline.OutlineColor = highlightColor;
                outline.OutlineWidth = highlightWidth;
                outline.enabled = true;
            }
        }

        public void StartSelectingGameObject() {
            SelectedGameObjects.Clear();
            InSelectionProcess = true;
            SelectingManyGameObjects = false;
        }
        public void StartSelectingGameObjects() {
            StartSelectingGameObject();
            SelectingManyGameObjects = true;
        }
        public bool EndedSelectingGameObjects() => InSelectionProcess == false;

        public void ToggleSelectedGameObject(GameObject obj) {
            if (!SelectedGameObjects.Remove(obj)) {
                SelectedGameObjects.Add(obj);
            }
        }

        public int IndexedSelfOrParent(GameObject obj, List<GameObject> objs) {
            int idx = objs.IndexOf(obj);
            if (idx >= 0) {
                return idx;
            } else {
                if (obj.transform == null) {
                    return -1;
                } else {
                    return IndexedSelfOrParent(obj.transform.parent.gameObject, objs);
                }
            }
        }

        public int SelectedGameObjectId(bool existing) {
            if (SelectedGameObjects.Count > 0) {
                List<GameObject> shapes = processor.channel.shapes;
                GameObject obj = SelectedGameObjects[0];
                if (existing) {
                    int idx = IndexedSelfOrParent(obj, shapes);
                    if (idx >= 0) {
                        return idx;
                    } else {
                        return -2;
                    }
                } else {
                    shapes.Add(obj);
                    return shapes.Count - 1;
                }
            } else {
                return -2;
            }
        }
        public int[] SelectedGameObjectsIds(bool existing) {
            List<int> idxs = new List<int>();
            List<GameObject> shapes = processor.channel.shapes;
            foreach (GameObject obj in SelectedGameObjects) {
                if (existing) {
                    int idx = IndexedSelfOrParent(obj, shapes);
                    if (idx >= 0) {
                        idxs.Add(idx);
                    }
                } else {
                    shapes.Add(obj);
                    idxs.Add(shapes.Count - 1);
                }
            }
            return idxs.ToArray();
        }

        #endregion

        #region Agent Simulation

        // Lazy initialization of the simulation subsystem.
        // Creates SystemManager (with NavMeshSurface) and agent/goal
        // templates if they don't exist in the scene.
        private void EnsureSimulationManager() {
            if (SystemManager.instance != null) return;
            // NavMeshSurface must be added before SystemManager so that
            // SystemManager.Awake() finds it via GetComponent.
            var go = new GameObject("SimulationManager");
            go.AddComponent<Unity.AI.Navigation.NavMeshSurface>();
            go.AddComponent<SystemManager>();

            // Agent template (inactive so OnEnable doesn't fire on the template)
            var agentTemplate = new GameObject("AgentTemplate");
            agentTemplate.SetActive(false);
            agentTemplate.tag = "Agent";
            var cc = agentTemplate.AddComponent<CharacterController>();
            cc.slopeLimit = 80;
            cc.stepOffset = 0.3f;
            cc.skinWidth = 0.08f;
            cc.minMoveDistance = 0.001f;
            cc.center = new Vector3(0, 0, 0);
            cc.radius = 0.2279f;
            cc.height = 1.7f;
            var trigger = agentTemplate.AddComponent<SphereCollider>();
            trigger.isTrigger = true;
            trigger.center = new Vector3(0, 0, 0);
            trigger.radius = 2.0f;
            var agentComp = agentTemplate.AddComponent<Agent_>();
            agentComp.characterController = cc;
            // Capsule child provides a MeshRenderer for Agent_.SetColor
            var visual = GameObject.CreatePrimitive(PrimitiveType.Capsule);
            visual.transform.SetParent(agentTemplate.transform);
            agentComp.capsule = visual;
            visual.transform.localPosition = new Vector3(0, 0, 0);
            visual.transform.localScale = new Vector3(0.45f, 0.85f, 0.45f);
            UnityEngine.Object.Destroy(visual.GetComponent<Collider>());
            var visualCollider = visual.AddComponent<CapsuleCollider>();
            visualCollider.isTrigger = true;
            visualCollider.radius = 3.0f;
            visualCollider.height = 1.7f;
            SystemManager.instance.agent = agentTemplate;

            // Goal template (inactive)
            var goalTemplate = new GameObject("GoalTemplate");
            goalTemplate.SetActive(false);
            var goalCollider = goalTemplate.AddComponent<BoxCollider>();
            goalCollider.isTrigger = true;
            goalTemplate.AddComponent<Goal_>();
            SystemManager.instance.goal = goalTemplate;
        }

        // Agent size configuration — updates the agent template and NavMesh baking settings.
        // Must be called before spawning agents (but after EnsureSimulationManager).
        public void SetSimAgentSize(float radius, float height) {
            EnsureSimulationManager();
            var template = SystemManager.instance.agent;
            var cc = template.GetComponent<CharacterController>();
            cc.radius = radius;
            cc.height = height;
            cc.center = new Vector3(0, 0, 0);

            // Scale trigger collider proportionally (default ratio: 2.0 / 0.2279 ≈ 8.8)
            var trigger = template.GetComponent<SphereCollider>();
            trigger.radius = radius * (2.0f / 0.2279f);

            // Update visual capsule
            var agent_ = template.GetComponent<Agent_>();
            agent_.capsule.transform.localScale = new Vector3(radius * 2, height / 2, radius * 2);

            // Update Agent_ cached values so runtime congestion logic uses new size
            agent_.baseRadius = radius;
            agent_.colliderRadius = trigger.radius;

            // Update NavMeshSurface so baked mesh accounts for agent size
            var navSurface = SystemManager.instance.GetComponent<Unity.AI.Navigation.NavMeshSurface>();
            if (navSurface != null) {
                navSurface.agentTypeID = 0; // Default agent type
                // NavMeshSurface uses NavMesh.GetSettingsByID; we update the build settings at bake time
                // by setting overrideVoxelSize / overrideTileSize if needed.
            }

            // Update minimum spawn spacing (proportional to body radius)
            SystemLib.SetAgentSpawnRadius(radius * (1.2f / 0.2279f));
        }

        // Movement model configuration
        public void SetSimHSF(float relaxationTime, float maxSpeedCoef, float V, float sigma, float U, float R, float c, float phi)
            => SystemLib.SetSimHSF(relaxationTime, maxSpeedCoef, V, sigma, U, R, c, phi);
        public void SetSimNone() => SystemLib.SetSimNone();

        // Velocity distribution
        public void SetVelGaussHSF(float mean, float stdDev, float min, float max)
            => SystemLib.SetVelGaussHSF(mean, stdDev, min, max);
        public void SetVelUniformHSF(float min, float max) => SystemLib.SetVelUniformHSF(min, max);
        public void SetVelHSF(float vel) => SystemLib.SetVelHSF(vel);

        // Goals
        public int CreateSimGoal(Vector3 pos, Vector3 scale, float rot) {
            EnsureSimulationManager();
            return SystemManager.instance.AddGoal(pos, scale, rot);
        }

        // Agent creation
        public void CreateSimAgent(Vector3 pos, float rot, int rgb, List<Goal_> goals) {
            EnsureSimulationManager();
            SystemLib.CreateAgent(pos.x, pos.y, pos.z, rot, rgb, goals);
        }
        public void SpawnAgentsRect(int count, Vector3 center, float dx, float dz, float rot, int rgb, int[] goalIDs) {
            EnsureSimulationManager();
            SystemLib.SpawnAgentsRect(count, center.x, center.y, center.z, dx, dz, rot, rgb, goalIDs);
        }
        public void SpawnAgentsEllipse(int count, Vector3 center, float dx, float dz, float rot, int rgb, int[] goalIDs) {
            EnsureSimulationManager();
            SystemLib.SpawnAgentsEllipse(count, center.x, center.y, center.z, dx, dz, rot, rgb, goalIDs);
        }
        public void SpawnAgentsPolygon(int count, float h, int rgb, int[] goalIDs, Vector3[] vertices) {
            EnsureSimulationManager();
            SystemLib.SpawnAgentsPolygon(count, h, rgb, goalIDs,
                System.Array.ConvertAll(vertices, v => new Vector2(v.x, v.z)));
        }

        // Simulation control
        public void StartSimulation(float maxTime) {
            EnsureSimulationManager();
            SystemLib.StartUnitySimulation(maxTime);
        }
        public void SetSimulationSpeed(float speed) {
            EnsureSimulationManager();
            SystemLib.SetSimulationSpeed(speed);
        }
        public bool IsSimulationFinished() => SystemLib.IsSimulationFinished() == 1;
        public bool WasSimulationSuccessful() => SystemLib.WasSimulationSuccessful() == 1;
        public float GetEvacuationTime() => SystemLib.GetEvacuationTime();
        public void ResetSimulation() {
            EnsureSimulationManager();
            SystemLib.ResetScene();
        }
        public void UpdateNavMesh() {
            EnsureSimulationManager();
            SystemLib.UpdateNavMesh();
        }
        public void SetSimRandSeed(int seed) => UnityEngine.Random.InitState(seed);

        // Blocking simulation: starts the sim; the result is sent later
        // by SceneLoad when the simulation finishes (deferred response).
        public bool simulationPending = false;
        public void RunSimulation(float maxTime) {
            EnsureSimulationManager();
            SystemLib.StartUnitySimulation(maxTime);
            simulationPending = true;
        }

        // NavMesh tagging for standard Khepri geometry
        public void SetNavMeshArea(GameObject obj, int area) {
            var modifier = obj.GetComponent<Unity.AI.Navigation.NavMeshModifier>();
            if (modifier == null) modifier = obj.AddComponent<Unity.AI.Navigation.NavMeshModifier>();
            modifier.overrideArea = true;
            modifier.area = area;
            if (obj.GetComponent<Collider>() == null) {
                var mf = obj.GetComponent<MeshFilter>();
                if (mf != null) {
                    var mc = obj.AddComponent<MeshCollider>();
                    mc.sharedMesh = mf.sharedMesh;
                }
            }
            // NotWalkable geometry should repel agents via social forces.
            if (area == 1) {
                obj.tag = "Obstacle";
            }
        }

        public void SetTag(GameObject obj, string tag) {
            obj.tag = tag;
        }

        #endregion

        #region Deprecated Code
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
        #endregion
    }
}
