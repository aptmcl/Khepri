using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public static class Intersections
{
    static Vector2? SegmentsIntersection(Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3)
    {
        float denom = (p3.y - p2.y) * (p1.x - p0.x) - (p3.x - p2.x) * (p1.y - p0.y);
        if (denom == 0)
        {
            return null;
        }

        float u = ((p3.x - p2.x) * (p0.y - p2.y) - (p3.y - p2.y) * (p0.x - p2.x)) / denom;
        float v = ((p1.x - p0.x) * (p0.y - p2.y) - (p1.y - p0.y) * (p0.x - p2.x)) / denom;

        if (u >= 0 && u <= 1 && v >= 0 && v <= 1)
        {
            return new Vector2(p0.x + u * (p1.x - p0.x), p0.y + u * (p1.y - p0.y));
        }

        return null;
    }

    public static int HowMany(Func<Vector2, Vector2, bool> f, Vector2[] lst1, Vector2[] lst2)
    {
        if (!lst1.Any() || !lst2.Any())
        {
            return 0;
        }
        else if (f(lst1[0], lst2[0]))
        {
            return 1 + HowMany(f, lst1.Skip(1).ToArray(), lst2.Skip(1).ToArray());
        }
        else
        {
            return HowMany(f, lst1.Skip(1).ToArray(), lst2.Skip(1).ToArray());
        }
    }

    public static bool PointOnPolygon(Vector2 p, Vector2[] vertices)
    {
        Vector2 q = new Vector2(vertices.Max(v => v.x) + 1, p.y);

        int l = HowMany(
            (vi, vj) => SegmentsIntersection(p, q, vi, vj) != null,
            vertices,
            vertices.Skip(1).Concat(new Vector2[] { vertices[0] }).ToArray()
        );

        return l % 2 == 1;
    }

    public static (Vector2, float, float) BoundingBox(Vector2[] vertices)
    {
        float minX = vertices.Min(v => v.x);
        float maxX = vertices.Max(v => v.x);
        float minY = vertices.Min(v => v.y);
        float maxY = vertices.Max(v => v.y);

        return (new Vector2(minX, minY), maxX - minX, maxY - minY);
    }
}
