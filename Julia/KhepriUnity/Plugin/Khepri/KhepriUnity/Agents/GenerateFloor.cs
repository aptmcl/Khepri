using System.Collections;
using System.Collections.Generic;
//using Unity.VisualScripting;
using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class GenerateFloor : MonoBehaviour
{
    public void Setup(Vector2[] points, float height)
    {
        Vector3[] points3D = new Vector3[points.Length];
        for (int i = 0; i < points.Length; ++i)
        {
            points3D[i] = new Vector3(points[i].x, height, points[i].y);
        }

        if (points.Length < 3)
        {
            Debug.LogError("At least 3 points are required to create a surface.");
            return;
        }

        Mesh mesh = new Mesh { name = "Procedural Mesh" };

        mesh.vertices = points3D;

        int[] triangles = InvertNormals(Triangulate(points3D));
        mesh.triangles = triangles;

        GetComponent<MeshFilter>().mesh = mesh;
    }

    private int[] InvertNormals(int[] vertices)
    {
        for (int i = 0; i < vertices.Length / 3; ++i)
        {
            int c = vertices[i * 3];
            vertices[i * 3] = vertices[(i * 3) + 2];
            vertices[(i * 3) + 2] = c;
        }

        return vertices;
    }

    private int[] Triangulate(Vector3[] vertices)
    {
        List<int> indices = new List<int>();
        List<int> polygon = new List<int>();

        // Populate the polygon index list
        for (int i = 0; i < vertices.Length; i++)
        {
            polygon.Add(i);
        }

        // While the polygon has more than 3 vertices, clip ears
        while (polygon.Count > 3)
        {
            bool earFound = false;

            for (int i = 0; i < polygon.Count; i++)
            {
                int prev = polygon[(i - 1 + polygon.Count) % polygon.Count];
                int current = polygon[i];
                int next = polygon[(i + 1) % polygon.Count];

                // Check if this is an ear
                if (IsEar(prev, current, next, polygon, vertices))
                {
                    // Add the triangle to the indices
                    indices.Add(prev);
                    indices.Add(current);
                    indices.Add(next);

                    // Remove the ear from the polygon
                    polygon.RemoveAt(i);
                    earFound = true;
                    break;
                }
            }

            if (!earFound)
            {
                Debug.LogError("Failed to find an ear. Check if the points are in counter-clockwise order and valid.");
                break;
            }
        }

        // Add the final triangle
        if (polygon.Count == 3)
        {
            indices.Add(polygon[0]);
            indices.Add(polygon[1]);
            indices.Add(polygon[2]);
        }

        return indices.ToArray();
    }

    // Determine if a triangle (v1, v2, v3) is an ear
    private bool IsEar(int v1, int v2, int v3, List<int> polygon, Vector3[] vertices)
    {
        // Check if the triangle is convex
        if (!IsConvex(vertices[v1], vertices[v2], vertices[v3]))
        {
            return false;
        }

        // Check if the triangle contains any other points from the polygon
        for (int i = 0; i < polygon.Count; i++)
        {
            int vi = polygon[i];

            // Skip the vertices of the triangle
            if (vi == v1 || vi == v2 || vi == v3)
            {
                continue;
            }

            if (PointInTriangle(vertices[vi], vertices[v1], vertices[v2], vertices[v3]))
            {
                return false;
            }
        }

        return true;
    }

    // Check if a triangle is convex
    private bool IsConvex(Vector3 v1, Vector3 v2, Vector3 v3)
    {
        Vector3 cross = Vector3.Cross(v2 - v1, v3 - v2);
        return cross.y <= 0; // Assuming counter-clockwise order
    }

    // Check if a point p lies inside the triangle (a, b, c)
    private bool PointInTriangle(Vector3 p, Vector3 a, Vector3 b, Vector3 c)
    {
        float areaOrig = Mathf.Abs(TriangleArea(a, b, c));
        float area1 = Mathf.Abs(TriangleArea(p, b, c));
        float area2 = Mathf.Abs(TriangleArea(a, p, c));
        float area3 = Mathf.Abs(TriangleArea(a, b, p));

        return Mathf.Approximately(areaOrig, area1 + area2 + area3);
    }

    // Compute the signed area of a triangle
    private float TriangleArea(Vector3 a, Vector3 b, Vector3 c)
    {
        return 0.5f * ((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z));
    }

}
