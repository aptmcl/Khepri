// KhepriMeshBuilder.cpp — Mesh generation utilities for UProceduralMeshComponent

#include "KhepriMeshBuilder.h"

namespace KhepriMeshBuilder
{

// =============================================================================
// Utility
// =============================================================================

FVector ComputeNormal(const FVector& P1, const FVector& P2, const FVector& P3)
{
  FVector Edge1 = P2 - P1;
  FVector Edge2 = P3 - P1;
  FVector Normal = FVector::CrossProduct(Edge1, Edge2);
  return Normal.GetSafeNormal();
}

void MakeDoubleSided(FMeshData& Data)
{
  // No-op: double-sided rendering is handled by the TwoSided material.
  // Duplicating geometry causes Z-fighting between front/back faces.
}

void ReverseWinding(FMeshData& Data)
{
  for (int32 i = 0; i < Data.Triangles.Num(); i += 3)
  {
    Swap(Data.Triangles[i + 1], Data.Triangles[i + 2]);
  }
}

void NegateNormals(FMeshData& Data)
{
  for (FVector& N : Data.Normals)
  {
    N = -N;
  }
}

// =============================================================================
// Triangulation helpers
// =============================================================================

void TriangulateFan(const FVector& Pivot, const TArray<FVector>& Points,
                    TArray<FVector>& OutVerts, TArray<int32>& OutTris,
                    TArray<FVector>& OutNormals, TArray<FVector2D>& OutUVs)
{
  int32 NumPoints = Points.Num();
  if (NumPoints < 2)
  {
    return;
  }

  for (int32 i = 0; i < NumPoints - 1; ++i)
  {
    FVector Normal = ComputeNormal(Pivot, Points[i], Points[i + 1]);

    int32 Base = OutVerts.Num();
    OutVerts.Add(Pivot);
    OutVerts.Add(Points[i]);
    OutVerts.Add(Points[i + 1]);

    OutTris.Add(Base);
    OutTris.Add(Base + 1);
    OutTris.Add(Base + 2);

    OutNormals.Add(Normal);
    OutNormals.Add(Normal);
    OutNormals.Add(Normal);

    float U = static_cast<float>(i) / static_cast<float>(NumPoints - 1);
    float U1 = static_cast<float>(i + 1) / static_cast<float>(NumPoints - 1);
    OutUVs.Add(FVector2D(0.5f, 0.5f));
    OutUVs.Add(FVector2D(U, 0.0f));
    OutUVs.Add(FVector2D(U1, 0.0f));
  }
}

TArray<int32> TriangulatePolygon(const TArray<FVector>& Points)
{
  TArray<int32> Indices;
  int32 N = Points.Num();
  if (N < 3)
  {
    return Indices;
  }

  // Determine best-fit 2D projection plane by computing polygon normal
  FVector PolyNormal = FVector::ZeroVector;
  for (int32 i = 0; i < N; ++i)
  {
    const FVector& Curr = Points[i];
    const FVector& Next = Points[(i + 1) % N];
    // Newell's method
    PolyNormal.X += (Curr.Y - Next.Y) * (Curr.Z + Next.Z);
    PolyNormal.Y += (Curr.Z - Next.Z) * (Curr.X + Next.X);
    PolyNormal.Z += (Curr.X - Next.X) * (Curr.Y + Next.Y);
  }
  PolyNormal = PolyNormal.GetSafeNormal();

  // Choose the two axes that give the largest projection area
  float AbsX = FMath::Abs(PolyNormal.X);
  float AbsY = FMath::Abs(PolyNormal.Y);
  float AbsZ = FMath::Abs(PolyNormal.Z);

  // Project to 2D by dropping the dominant axis
  auto Project2D = [&](const FVector& P) -> FVector2D
  {
    if (AbsZ >= AbsX && AbsZ >= AbsY)
    {
      return FVector2D(P.X, P.Y);
    }
    else if (AbsY >= AbsX)
    {
      return FVector2D(P.X, P.Z);
    }
    else
    {
      return FVector2D(P.Y, P.Z);
    }
  };

  // Build index list for ear clipping
  TArray<int32> Remaining;
  Remaining.SetNum(N);
  for (int32 i = 0; i < N; ++i)
  {
    Remaining[i] = i;
  }

  // Project all points
  TArray<FVector2D> Projected;
  Projected.SetNum(N);
  for (int32 i = 0; i < N; ++i)
  {
    Projected[i] = Project2D(Points[i]);
  }

  // Compute signed area to determine winding
  float SignedArea = 0.0f;
  for (int32 i = 0; i < N; ++i)
  {
    const FVector2D& A = Projected[i];
    const FVector2D& B = Projected[(i + 1) % N];
    SignedArea += A.X * B.Y - B.X * A.Y;
  }
  bool bCCW = (SignedArea > 0.0f);

  // Helper: is point P inside triangle ABC?
  auto PointInTriangle2D = [](const FVector2D& P, const FVector2D& A,
                               const FVector2D& B, const FVector2D& C) -> bool
  {
    auto Cross2D = [](const FVector2D& U, const FVector2D& V) -> float
    {
      return U.X * V.Y - U.Y * V.X;
    };
    float D1 = Cross2D(B - A, P - A);
    float D2 = Cross2D(C - B, P - B);
    float D3 = Cross2D(A - C, P - C);
    bool bHasNeg = (D1 < 0.0f) || (D2 < 0.0f) || (D3 < 0.0f);
    bool bHasPos = (D1 > 0.0f) || (D2 > 0.0f) || (D3 > 0.0f);
    return !(bHasNeg && bHasPos);
  };

  // Ear clipping
  int32 MaxIterations = N * N; // safety limit
  int32 Iterations = 0;
  while (Remaining.Num() > 2 && Iterations < MaxIterations)
  {
    ++Iterations;
    bool bFoundEar = false;

    int32 RN = Remaining.Num();
    for (int32 i = 0; i < RN; ++i)
    {
      int32 Prev = (i + RN - 1) % RN;
      int32 Next = (i + 1) % RN;

      int32 Ai = Remaining[Prev];
      int32 Bi = Remaining[i];
      int32 Ci = Remaining[Next];

      const FVector2D& A = Projected[Ai];
      const FVector2D& B = Projected[Bi];
      const FVector2D& C = Projected[Ci];

      // Check if this is a convex vertex
      float Cross = (B.X - A.X) * (C.Y - A.Y) - (B.Y - A.Y) * (C.X - A.X);
      bool bConvex = bCCW ? (Cross > 0.0f) : (Cross < 0.0f);

      if (!bConvex)
      {
        continue;
      }

      // Check that no other vertex lies inside this triangle
      bool bIsEar = true;
      for (int32 j = 0; j < RN; ++j)
      {
        if (j == Prev || j == i || j == Next)
        {
          continue;
        }
        if (PointInTriangle2D(Projected[Remaining[j]], A, B, C))
        {
          bIsEar = false;
          break;
        }
      }

      if (bIsEar)
      {
        Indices.Add(Ai);
        Indices.Add(Bi);
        Indices.Add(Ci);
        Remaining.RemoveAt(i);
        bFoundEar = true;
        break;
      }
    }

    if (!bFoundEar)
    {
      // Degenerate polygon; fan from first vertex as fallback
      for (int32 i = 1; i < Remaining.Num() - 1; ++i)
      {
        Indices.Add(Remaining[0]);
        Indices.Add(Remaining[i]);
        Indices.Add(Remaining[i + 1]);
      }
      break;
    }
  }

  return Indices;
}

// =============================================================================
// Helper: append mesh data with an offset
// =============================================================================

static void AppendMesh(FMeshData& Dest, const TArray<FVector>& Verts,
                       const TArray<int32>& Tris, const TArray<FVector>& Normals,
                       const TArray<FVector2D>& UVs)
{
  int32 BaseVert = Dest.Vertices.Num();
  Dest.Vertices.Append(Verts);
  Dest.Normals.Append(Normals);
  Dest.UVs.Append(UVs);
  for (int32 Idx : Tris)
  {
    Dest.Triangles.Add(Idx + BaseVert);
  }
}

// =============================================================================
// Tier 1 — Surface primitives
// =============================================================================

FMeshData BuildTriangle(const FVector& P1, const FVector& P2, const FVector& P3)
{
  FMeshData Data;
  FVector Normal = ComputeNormal(P1, P2, P3);

  Data.Vertices.Add(P1);
  Data.Vertices.Add(P2);
  Data.Vertices.Add(P3);

  Data.Triangles.Add(0);
  Data.Triangles.Add(1);
  Data.Triangles.Add(2);

  Data.Normals.Add(Normal);
  Data.Normals.Add(Normal);
  Data.Normals.Add(Normal);

  Data.UVs.Add(FVector2D(0.0f, 0.0f));
  Data.UVs.Add(FVector2D(1.0f, 0.0f));
  Data.UVs.Add(FVector2D(0.5f, 1.0f));

  ReverseWinding(Data);
  return Data;
}

FMeshData BuildQuad(const FVector& P1, const FVector& P2, const FVector& P3, const FVector& P4)
{
  FMeshData Data;
  FVector Normal = ComputeNormal(P1, P2, P3);

  Data.Vertices.Add(P1);
  Data.Vertices.Add(P2);
  Data.Vertices.Add(P3);
  Data.Vertices.Add(P4);

  // Triangle 1: 0,1,2
  Data.Triangles.Add(0);
  Data.Triangles.Add(1);
  Data.Triangles.Add(2);
  // Triangle 2: 0,2,3
  Data.Triangles.Add(0);
  Data.Triangles.Add(2);
  Data.Triangles.Add(3);

  Data.Normals.Add(Normal);
  Data.Normals.Add(Normal);
  Data.Normals.Add(Normal);
  Data.Normals.Add(Normal);

  Data.UVs.Add(FVector2D(0.0f, 0.0f));
  Data.UVs.Add(FVector2D(1.0f, 0.0f));
  Data.UVs.Add(FVector2D(1.0f, 1.0f));
  Data.UVs.Add(FVector2D(0.0f, 1.0f));

  ReverseWinding(Data);
  return Data;
}

FMeshData BuildNGon(const TArray<FVector>& Points, const FVector& Pivot)
{
  FMeshData Data;

  TriangulateFan(Pivot, Points, Data.Vertices, Data.Triangles, Data.Normals, Data.UVs);

  ReverseWinding(Data);
  return Data;
}

FMeshData BuildQuadStrip(const TArray<FVector>& Bottom, const TArray<FVector>& Top, bool Smooth)
{
  FMeshData Data;
  int32 N = FMath::Min(Bottom.Num(), Top.Num());
  if (N < 2)
  {
    return Data;
  }

  if (!Smooth)
  {
    // Flat shading: each quad gets its own vertices with per-face normals
    for (int32 i = 0; i < N - 1; ++i)
    {
      const FVector& B0 = Bottom[i];
      const FVector& B1 = Bottom[i + 1];
      const FVector& T1 = Top[i + 1];
      const FVector& T0 = Top[i];

      FVector Normal = ComputeNormal(B0, B1, T1);
      int32 Base = Data.Vertices.Num();

      Data.Vertices.Add(B0);
      Data.Vertices.Add(B1);
      Data.Vertices.Add(T1);
      Data.Vertices.Add(T0);

      Data.Normals.Add(Normal);
      Data.Normals.Add(Normal);
      Data.Normals.Add(Normal);
      Data.Normals.Add(Normal);

      float U0 = static_cast<float>(i) / static_cast<float>(N - 1);
      float U1 = static_cast<float>(i + 1) / static_cast<float>(N - 1);
      Data.UVs.Add(FVector2D(U0, 0.0f));
      Data.UVs.Add(FVector2D(U1, 0.0f));
      Data.UVs.Add(FVector2D(U1, 1.0f));
      Data.UVs.Add(FVector2D(U0, 1.0f));

      // Two triangles per quad
      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 1);
      Data.Triangles.Add(Base + 2);

      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 2);
      Data.Triangles.Add(Base + 3);
    }
  }
  else
  {
    // Smooth shading: shared vertices with averaged normals
    // First pass: add all vertices
    for (int32 i = 0; i < N; ++i)
    {
      float U = static_cast<float>(i) / static_cast<float>(N - 1);

      Data.Vertices.Add(Bottom[i]);
      Data.UVs.Add(FVector2D(U, 0.0f));
      Data.Normals.Add(FVector::ZeroVector); // placeholder

      Data.Vertices.Add(Top[i]);
      Data.UVs.Add(FVector2D(U, 1.0f));
      Data.Normals.Add(FVector::ZeroVector); // placeholder
    }

    // Second pass: add triangles and accumulate normals
    for (int32 i = 0; i < N - 1; ++i)
    {
      int32 BL = i * 2;       // Bottom left
      int32 TL = i * 2 + 1;   // Top left
      int32 BR = (i + 1) * 2; // Bottom right
      int32 TR = (i + 1) * 2 + 1; // Top right

      FVector FaceNormal = ComputeNormal(Bottom[i], Bottom[i + 1], Top[i + 1]);

      Data.Normals[BL] += FaceNormal;
      Data.Normals[BR] += FaceNormal;
      Data.Normals[TR] += FaceNormal;
      Data.Normals[TL] += FaceNormal;

      Data.Triangles.Add(BL);
      Data.Triangles.Add(BR);
      Data.Triangles.Add(TR);

      Data.Triangles.Add(BL);
      Data.Triangles.Add(TR);
      Data.Triangles.Add(TL);
    }

    // Normalize all accumulated normals
    for (int32 i = 0; i < Data.Normals.Num(); ++i)
    {
      Data.Normals[i] = Data.Normals[i].GetSafeNormal();
    }
  }

  ReverseWinding(Data);
  return Data;
}

FMeshData BuildSurfacePolygon(const TArray<FVector>& Points)
{
  FMeshData Data;
  if (Points.Num() < 3)
  {
    return Data;
  }

  TArray<int32> TriIndices = TriangulatePolygon(Points);

  // Compute overall polygon normal using Newell's method
  FVector PolyNormal = FVector::ZeroVector;
  int32 N = Points.Num();
  for (int32 i = 0; i < N; ++i)
  {
    const FVector& Curr = Points[i];
    const FVector& Next = Points[(i + 1) % N];
    PolyNormal.X += (Curr.Y - Next.Y) * (Curr.Z + Next.Z);
    PolyNormal.Y += (Curr.Z - Next.Z) * (Curr.X + Next.X);
    PolyNormal.Z += (Curr.X - Next.X) * (Curr.Y + Next.Y);
  }
  PolyNormal = PolyNormal.GetSafeNormal();

  // Compute bounding box for UV mapping
  FVector MinPt = Points[0];
  FVector MaxPt = Points[0];
  for (int32 i = 1; i < N; ++i)
  {
    MinPt = MinPt.ComponentMin(Points[i]);
    MaxPt = MaxPt.ComponentMax(Points[i]);
  }
  FVector Extent = MaxPt - MinPt;
  // Avoid division by zero
  if (Extent.X < KINDA_SMALL_NUMBER) Extent.X = 1.0f;
  if (Extent.Y < KINDA_SMALL_NUMBER) Extent.Y = 1.0f;
  if (Extent.Z < KINDA_SMALL_NUMBER) Extent.Z = 1.0f;

  // Determine UV projection axes
  float AbsX = FMath::Abs(PolyNormal.X);
  float AbsY = FMath::Abs(PolyNormal.Y);
  float AbsZ = FMath::Abs(PolyNormal.Z);

  for (int32 i = 0; i < N; ++i)
  {
    Data.Vertices.Add(Points[i]);
    Data.Normals.Add(PolyNormal);

    FVector2D UV;
    FVector Rel = Points[i] - MinPt;
    if (AbsZ >= AbsX && AbsZ >= AbsY)
    {
      UV = FVector2D(Rel.X / Extent.X, Rel.Y / Extent.Y);
    }
    else if (AbsY >= AbsX)
    {
      UV = FVector2D(Rel.X / Extent.X, Rel.Z / Extent.Z);
    }
    else
    {
      UV = FVector2D(Rel.Y / Extent.Y, Rel.Z / Extent.Z);
    }
    Data.UVs.Add(UV);
  }

  Data.Triangles = MoveTemp(TriIndices);

  ReverseWinding(Data);
  return Data;
}

FMeshData BuildSurfaceGrid(const TArray<TArray<FVector>>& Points, bool ClosedU, bool ClosedV, bool Smooth)
{
  FMeshData Data;
  int32 NumU = Points.Num();
  if (NumU < 2)
  {
    return Data;
  }
  int32 NumV = Points[0].Num();
  if (NumV < 2)
  {
    return Data;
  }

  // Add all vertices
  for (int32 u = 0; u < NumU; ++u)
  {
    for (int32 v = 0; v < NumV; ++v)
    {
      Data.Vertices.Add(Points[u][v]);
      Data.Normals.Add(FVector::ZeroVector); // will be computed

      float UCoord = static_cast<float>(u) / static_cast<float>(ClosedU ? NumU : NumU - 1);
      float VCoord = static_cast<float>(v) / static_cast<float>(ClosedV ? NumV : NumV - 1);
      Data.UVs.Add(FVector2D(UCoord, VCoord));
    }
  }

  auto VertIndex = [&](int32 u, int32 v) -> int32
  {
    if (ClosedU) u = u % NumU;
    if (ClosedV) v = v % NumV;
    return u * NumV + v;
  };

  int32 ULimit = ClosedU ? NumU : NumU - 1;
  int32 VLimit = ClosedV ? NumV : NumV - 1;

  if (Smooth)
  {
    // Shared vertices with accumulated normals
    for (int32 u = 0; u < ULimit; ++u)
    {
      for (int32 v = 0; v < VLimit; ++v)
      {
        int32 I00 = VertIndex(u, v);
        int32 I10 = VertIndex(u + 1, v);
        int32 I11 = VertIndex(u + 1, v + 1);
        int32 I01 = VertIndex(u, v + 1);

        FVector FaceNormal = ComputeNormal(
          Data.Vertices[I00], Data.Vertices[I10], Data.Vertices[I11]);

        Data.Normals[I00] += FaceNormal;
        Data.Normals[I10] += FaceNormal;
        Data.Normals[I11] += FaceNormal;
        Data.Normals[I01] += FaceNormal;

        Data.Triangles.Add(I00);
        Data.Triangles.Add(I10);
        Data.Triangles.Add(I11);

        Data.Triangles.Add(I00);
        Data.Triangles.Add(I11);
        Data.Triangles.Add(I01);
      }
    }

    for (int32 i = 0; i < Data.Normals.Num(); ++i)
    {
      Data.Normals[i] = Data.Normals[i].GetSafeNormal();
    }
  }
  else
  {
    // Flat shading: duplicate vertices per quad
    Data.Vertices.Empty();
    Data.Normals.Empty();
    Data.UVs.Empty();

    for (int32 u = 0; u < ULimit; ++u)
    {
      for (int32 v = 0; v < VLimit; ++v)
      {
        int32 u1 = ClosedU ? (u + 1) % NumU : u + 1;
        int32 v1 = ClosedV ? (v + 1) % NumV : v + 1;

        const FVector& P00 = Points[u][v];
        const FVector& P10 = Points[u1][v];
        const FVector& P11 = Points[u1][v1];
        const FVector& P01 = Points[u][v1];

        FVector Normal = ComputeNormal(P00, P10, P11);

        int32 Base = Data.Vertices.Num();
        Data.Vertices.Add(P00);
        Data.Vertices.Add(P10);
        Data.Vertices.Add(P11);
        Data.Vertices.Add(P01);

        Data.Normals.Add(Normal);
        Data.Normals.Add(Normal);
        Data.Normals.Add(Normal);
        Data.Normals.Add(Normal);

        float U0 = static_cast<float>(u) / static_cast<float>(ClosedU ? NumU : NumU - 1);
        float U1 = static_cast<float>(u + 1) / static_cast<float>(ClosedU ? NumU : NumU - 1);
        float V0 = static_cast<float>(v) / static_cast<float>(ClosedV ? NumV : NumV - 1);
        float V1 = static_cast<float>(v + 1) / static_cast<float>(ClosedV ? NumV : NumV - 1);

        Data.UVs.Add(FVector2D(U0, V0));
        Data.UVs.Add(FVector2D(U1, V0));
        Data.UVs.Add(FVector2D(U1, V1));
        Data.UVs.Add(FVector2D(U0, V1));

        Data.Triangles.Add(Base);
        Data.Triangles.Add(Base + 1);
        Data.Triangles.Add(Base + 2);

        Data.Triangles.Add(Base);
        Data.Triangles.Add(Base + 2);
        Data.Triangles.Add(Base + 3);
      }
    }
  }

  ReverseWinding(Data);
  return Data;
}

// =============================================================================
// Tier 3 — Solid primitives
// =============================================================================

FMeshData BuildBox(const FVector& Size)
{
  FMeshData Data;
  float HX = Size.X * 0.5f;
  float HY = Size.Y * 0.5f;
  float HZ = Size.Z * 0.5f;

  // 8 corner positions
  FVector Corners[8] = {
    FVector(-HX, -HY, -HZ), // 0: left  bottom back
    FVector( HX, -HY, -HZ), // 1: right bottom back
    FVector( HX,  HY, -HZ), // 2: right top    back
    FVector(-HX,  HY, -HZ), // 3: left  top    back
    FVector(-HX, -HY,  HZ), // 4: left  bottom front
    FVector( HX, -HY,  HZ), // 5: right bottom front
    FVector( HX,  HY,  HZ), // 6: right top    front
    FVector(-HX,  HY,  HZ), // 7: left  top    front
  };

  // 6 faces: each has 4 vertices, a normal, and 2 triangles
  struct FaceDesc
  {
    int32 V[4];
    FVector Normal;
  };

  FaceDesc Faces[6] = {
    // Front (+Z)
    { {4, 5, 6, 7}, FVector(0.0f, 0.0f, 1.0f) },
    // Back (-Z)
    { {1, 0, 3, 2}, FVector(0.0f, 0.0f, -1.0f) },
    // Right (+X)
    { {5, 1, 2, 6}, FVector(1.0f, 0.0f, 0.0f) },
    // Left (-X)
    { {0, 4, 7, 3}, FVector(-1.0f, 0.0f, 0.0f) },
    // Top (+Y)
    { {3, 7, 6, 2}, FVector(0.0f, 1.0f, 0.0f) },
    // Bottom (-Y)
    { {0, 1, 5, 4}, FVector(0.0f, -1.0f, 0.0f) },
  };

  FVector2D FaceUVs[4] = {
    FVector2D(0.0f, 0.0f),
    FVector2D(1.0f, 0.0f),
    FVector2D(1.0f, 1.0f),
    FVector2D(0.0f, 1.0f),
  };

  for (int32 f = 0; f < 6; ++f)
  {
    int32 Base = Data.Vertices.Num();
    for (int32 v = 0; v < 4; ++v)
    {
      Data.Vertices.Add(Corners[Faces[f].V[v]]);
      Data.Normals.Add(Faces[f].Normal);
      Data.UVs.Add(FaceUVs[v]);
    }

    Data.Triangles.Add(Base);
    Data.Triangles.Add(Base + 1);
    Data.Triangles.Add(Base + 2);

    Data.Triangles.Add(Base);
    Data.Triangles.Add(Base + 2);
    Data.Triangles.Add(Base + 3);
  }

  ReverseWinding(Data);
  return Data;
}

FMeshData BuildBoxFromCorners(
  const FVector& B0, const FVector& B1, const FVector& B2, const FVector& B3,
  const FVector& T0, const FVector& T1, const FVector& T2, const FVector& T3)
{
  // B0-B3: bottom face, T0-T3: top face (T_i is above B_i)
  FMeshData Data;

  struct FaceDesc { FVector V[4]; };
  FaceDesc Faces[6] = {
    { {T0, T1, T2, T3} },  // Top
    { {B3, B2, B1, B0} },  // Bottom
    { {B0, B1, T1, T0} },  // Front
    { {B2, B3, T3, T2} },  // Back
    { {B1, B2, T2, T1} },  // Right
    { {B3, B0, T0, T3} },  // Left
  };

  for (const FaceDesc& Face : Faces)
  {
    int32 Base = Data.Vertices.Num();
    FVector Normal = ComputeNormal(Face.V[0], Face.V[1], Face.V[2]);
    for (int32 i = 0; i < 4; ++i)
    {
      Data.Vertices.Add(Face.V[i]);
      Data.Normals.Add(Normal);
    }
    Data.UVs.Add(FVector2D(0, 0));
    Data.UVs.Add(FVector2D(1, 0));
    Data.UVs.Add(FVector2D(1, 1));
    Data.UVs.Add(FVector2D(0, 1));
    Data.Triangles.Append({Base, Base+1, Base+2, Base, Base+2, Base+3});
  }

  // The handedness of (B0→B1, B0→B3, B0→T0) depends on the input vectors.
  // Check the determinant to apply the correct fix:
  //   det < 0: face orientation correct, normals inward → negate normals
  //   det > 0: normals correct (outward), face orientation wrong → reverse winding
  // The handedness of (B0→B1, B0→B3, B0→T0) depends on the input coordinate system.
  // det < 0: face orientation correct for UE, normals inward → negate normals
  // det > 0: normals correct (outward), face orientation wrong → reverse winding
  float Det = FVector::DotProduct(FVector::CrossProduct(B1 - B0, B3 - B0), T0 - B0);
  if (Det < 0)
    NegateNormals(Data);
  else
    ReverseWinding(Data);
  return Data;
}

FMeshData BuildSphere(float Radius, int32 LatSegments, int32 LonSegments)
{
  // Pre-allocate: 2 poles + (LatSegments-1) rings of (LonSegments+1) vertices
  int32 NumVerts = 2 + (LatSegments - 1) * (LonSegments + 1);
  int32 NumTris = (2 * LonSegments + (LatSegments - 2) * LonSegments * 2) * 3;
  FMeshData Data;
  Data.Vertices.Reserve(NumVerts);
  Data.Normals.Reserve(NumVerts);
  Data.UVs.Reserve(NumVerts);
  Data.Triangles.Reserve(NumTris);

  // Generate vertices for UV sphere
  // Top pole
  Data.Vertices.Add(FVector(0.0f, 0.0f, Radius));
  Data.Normals.Add(FVector(0.0f, 0.0f, 1.0f));
  Data.UVs.Add(FVector2D(0.5f, 0.0f));

  for (int32 lat = 1; lat < LatSegments; ++lat)
  {
    float Theta = PI * static_cast<float>(lat) / static_cast<float>(LatSegments);
    float SinTheta = FMath::Sin(Theta);
    float CosTheta = FMath::Cos(Theta);

    for (int32 lon = 0; lon <= LonSegments; ++lon)
    {
      float Phi = 2.0f * PI * static_cast<float>(lon) / static_cast<float>(LonSegments);
      float SinPhi = FMath::Sin(Phi);
      float CosPhi = FMath::Cos(Phi);

      FVector Normal(SinTheta * CosPhi, SinTheta * SinPhi, CosTheta);
      Data.Vertices.Add(Normal * Radius);
      Data.Normals.Add(Normal);

      float U = static_cast<float>(lon) / static_cast<float>(LonSegments);
      float V = static_cast<float>(lat) / static_cast<float>(LatSegments);
      Data.UVs.Add(FVector2D(U, V));
    }
  }

  // Bottom pole
  int32 BottomPoleIndex = Data.Vertices.Num();
  Data.Vertices.Add(FVector(0.0f, 0.0f, -Radius));
  Data.Normals.Add(FVector(0.0f, 0.0f, -1.0f));
  Data.UVs.Add(FVector2D(0.5f, 1.0f));

  // Top cap triangles (pole to first latitude ring)
  for (int32 lon = 0; lon < LonSegments; ++lon)
  {
    Data.Triangles.Add(0);
    Data.Triangles.Add(1 + lon + 1);
    Data.Triangles.Add(1 + lon);
  }

  // Middle quads
  int32 RingSize = LonSegments + 1;
  for (int32 lat = 0; lat < LatSegments - 2; ++lat)
  {
    for (int32 lon = 0; lon < LonSegments; ++lon)
    {
      int32 Current = 1 + lat * RingSize + lon;
      int32 Next = Current + RingSize;

      Data.Triangles.Add(Current);
      Data.Triangles.Add(Current + 1);
      Data.Triangles.Add(Next + 1);

      Data.Triangles.Add(Current);
      Data.Triangles.Add(Next + 1);
      Data.Triangles.Add(Next);
    }
  }

  // Bottom cap triangles (last latitude ring to bottom pole)
  int32 LastRingStart = 1 + (LatSegments - 2) * RingSize;
  for (int32 lon = 0; lon < LonSegments; ++lon)
  {
    Data.Triangles.Add(BottomPoleIndex);
    Data.Triangles.Add(LastRingStart + lon);
    Data.Triangles.Add(LastRingStart + lon + 1);
  }

  // BuildSphere already produces correct CW winding for UE — no reversal needed.
  return Data;
}

FMeshData BuildCylinder(float Radius, float Height, int32 Segments)
{
  FMeshData Data;
  // Side: 4*Segments verts, 6*Segments tris; each cap: ~3*(Segments+1) verts, 3*Segments tris
  int32 EstVerts = 4 * Segments + 2 * 3 * (Segments + 1);
  int32 EstTris = 6 * Segments + 2 * 3 * Segments;
  Data.Vertices.Reserve(EstVerts);
  Data.Normals.Reserve(EstVerts);
  Data.UVs.Reserve(EstVerts);
  Data.Triangles.Reserve(EstTris);
  float HalfH = Height * 0.5f;

  // Bottom center and top center for caps
  FVector BottomCenter(0.0f, 0.0f, -HalfH);
  FVector TopCenter(0.0f, 0.0f, HalfH);

  // Generate ring vertices for bottom and top
  TArray<FVector> BottomRing;
  TArray<FVector> TopRing;
  BottomRing.SetNum(Segments);
  TopRing.SetNum(Segments);

  for (int32 i = 0; i < Segments; ++i)
  {
    float Angle = 2.0f * PI * static_cast<float>(i) / static_cast<float>(Segments);
    float X = Radius * FMath::Cos(Angle);
    float Y = Radius * FMath::Sin(Angle);
    BottomRing[i] = FVector(X, Y, -HalfH);
    TopRing[i] = FVector(X, Y, HalfH);
  }

  // Side surface: quad strip with smooth normals
  for (int32 i = 0; i < Segments; ++i)
  {
    int32 i1 = (i + 1) % Segments;

    float Angle0 = 2.0f * PI * static_cast<float>(i) / static_cast<float>(Segments);
    float Angle1 = 2.0f * PI * static_cast<float>(i1) / static_cast<float>(Segments);

    FVector N0(FMath::Cos(Angle0), FMath::Sin(Angle0), 0.0f);
    FVector N1(FMath::Cos(Angle1), FMath::Sin(Angle1), 0.0f);

    int32 Base = Data.Vertices.Num();

    float U0 = static_cast<float>(i) / static_cast<float>(Segments);
    float U1 = static_cast<float>(i + 1) / static_cast<float>(Segments);

    Data.Vertices.Add(BottomRing[i]);
    Data.Normals.Add(N0);
    Data.UVs.Add(FVector2D(U0, 0.0f));

    Data.Vertices.Add(BottomRing[i1]);
    Data.Normals.Add(N1);
    Data.UVs.Add(FVector2D(U1, 0.0f));

    Data.Vertices.Add(TopRing[i1]);
    Data.Normals.Add(N1);
    Data.UVs.Add(FVector2D(U1, 1.0f));

    Data.Vertices.Add(TopRing[i]);
    Data.Normals.Add(N0);
    Data.UVs.Add(FVector2D(U0, 1.0f));

    // CW winding for UE (swapped from right-handed CCW)
    Data.Triangles.Add(Base);
    Data.Triangles.Add(Base + 2);
    Data.Triangles.Add(Base + 1);

    Data.Triangles.Add(Base);
    Data.Triangles.Add(Base + 3);
    Data.Triangles.Add(Base + 2);
  }

  // Bottom cap (reversed fan for correct downward normals, then swap winding for UE)
  {
    TArray<FVector> BottomFan;
    for (int32 i = Segments - 1; i >= 0; --i)
    {
      BottomFan.Add(BottomRing[i]);
    }
    BottomFan.Add(BottomRing[Segments - 1]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(BottomCenter, BottomFan, FanVerts, FanTris, FanNormals, FanUVs);
    for (int32 i = 0; i < FanTris.Num(); i += 3) { Swap(FanTris[i + 1], FanTris[i + 2]); }
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  // Top cap (normal fan for correct upward normals, then swap winding for UE)
  {
    TArray<FVector> TopFan;
    for (int32 i = 0; i < Segments; ++i)
    {
      TopFan.Add(TopRing[i]);
    }
    TopFan.Add(TopRing[0]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(TopCenter, TopFan, FanVerts, FanTris, FanNormals, FanUVs);
    for (int32 i = 0; i < FanTris.Num(); i += 3) { Swap(FanTris[i + 1], FanTris[i + 2]); }
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  return Data;
}

FMeshData BuildConeFrustum(float BottomRadius, float TopRadius, float Height, int32 Segments)
{
  FMeshData Data;
  // Side: 3-4 verts per segment; caps: ~3*(Segments+1) each
  int32 EstVerts = 4 * Segments + 2 * 3 * (Segments + 1);
  int32 EstTris = 6 * Segments + 2 * 3 * Segments;
  Data.Vertices.Reserve(EstVerts);
  Data.Normals.Reserve(EstVerts);
  Data.UVs.Reserve(EstVerts);
  Data.Triangles.Reserve(EstTris);
  float HalfH = Height * 0.5f;
  bool bIsCone = (TopRadius < KINDA_SMALL_NUMBER);

  FVector BottomCenter(0.0f, 0.0f, -HalfH);
  FVector TopCenter(0.0f, 0.0f, HalfH);

  TArray<FVector> BottomRing;
  TArray<FVector> TopRing;
  BottomRing.SetNum(Segments);
  if (!bIsCone)
  {
    TopRing.SetNum(Segments);
  }

  for (int32 i = 0; i < Segments; ++i)
  {
    float Angle = 2.0f * PI * static_cast<float>(i) / static_cast<float>(Segments);
    float CosA = FMath::Cos(Angle);
    float SinA = FMath::Sin(Angle);
    BottomRing[i] = FVector(BottomRadius * CosA, BottomRadius * SinA, -HalfH);
    if (!bIsCone)
    {
      TopRing[i] = FVector(TopRadius * CosA, TopRadius * SinA, HalfH);
    }
  }

  // Side slope for normals
  float SideAngle = FMath::Atan2(BottomRadius - TopRadius, Height);
  float CosSlope = FMath::Cos(SideAngle);
  float SinSlope = FMath::Sin(SideAngle);

  // Side surface
  for (int32 i = 0; i < Segments; ++i)
  {
    int32 i1 = (i + 1) % Segments;

    float Angle0 = 2.0f * PI * static_cast<float>(i) / static_cast<float>(Segments);
    float Angle1 = 2.0f * PI * static_cast<float>(i1) / static_cast<float>(Segments);

    FVector N0(CosSlope * FMath::Cos(Angle0), CosSlope * FMath::Sin(Angle0), SinSlope);
    FVector N1(CosSlope * FMath::Cos(Angle1), CosSlope * FMath::Sin(Angle1), SinSlope);

    float U0 = static_cast<float>(i) / static_cast<float>(Segments);
    float U1 = static_cast<float>(i + 1) / static_cast<float>(Segments);

    if (bIsCone)
    {
      // Triangle to apex
      int32 Base = Data.Vertices.Num();

      Data.Vertices.Add(BottomRing[i]);
      Data.Normals.Add(N0);
      Data.UVs.Add(FVector2D(U0, 0.0f));

      Data.Vertices.Add(BottomRing[i1]);
      Data.Normals.Add(N1);
      Data.UVs.Add(FVector2D(U1, 0.0f));

      FVector ApexNormal = ((N0 + N1) * 0.5f).GetSafeNormal();
      Data.Vertices.Add(TopCenter);
      Data.Normals.Add(ApexNormal);
      Data.UVs.Add(FVector2D((U0 + U1) * 0.5f, 1.0f));

      // CW winding for UE
      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 2);
      Data.Triangles.Add(Base + 1);
    }
    else
    {
      // Quad
      int32 Base = Data.Vertices.Num();

      Data.Vertices.Add(BottomRing[i]);
      Data.Normals.Add(N0);
      Data.UVs.Add(FVector2D(U0, 0.0f));

      Data.Vertices.Add(BottomRing[i1]);
      Data.Normals.Add(N1);
      Data.UVs.Add(FVector2D(U1, 0.0f));

      Data.Vertices.Add(TopRing[i1]);
      Data.Normals.Add(N1);
      Data.UVs.Add(FVector2D(U1, 1.0f));

      Data.Vertices.Add(TopRing[i]);
      Data.Normals.Add(N0);
      Data.UVs.Add(FVector2D(U0, 1.0f));

      // CW winding for UE
      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 2);
      Data.Triangles.Add(Base + 1);

      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 3);
      Data.Triangles.Add(Base + 2);
    }
  }

  // Bottom cap (reversed fan for correct downward normals, swap winding for UE)
  {
    TArray<FVector> BottomFan;
    for (int32 i = Segments - 1; i >= 0; --i)
    {
      BottomFan.Add(BottomRing[i]);
    }
    BottomFan.Add(BottomRing[Segments - 1]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(BottomCenter, BottomFan, FanVerts, FanTris, FanNormals, FanUVs);
    for (int32 i = 0; i < FanTris.Num(); i += 3) { Swap(FanTris[i + 1], FanTris[i + 2]); }
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  // Top cap (only if not a cone)
  if (!bIsCone)
  {
    TArray<FVector> TopFan;
    for (int32 i = 0; i < Segments; ++i)
    {
      TopFan.Add(TopRing[i]);
    }
    TopFan.Add(TopRing[0]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(TopCenter, TopFan, FanVerts, FanTris, FanNormals, FanUVs);
    for (int32 i = 0; i < FanTris.Num(); i += 3) { Swap(FanTris[i + 1], FanTris[i + 2]); }
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  return Data;
}

FMeshData BuildTorus(float MajorRadius, float MinorRadius, int32 MajorSegments, int32 MinorSegments)
{
  FMeshData Data;

  // Standard parametric torus:
  // x = (R + r*cos(v)) * cos(u)
  // y = (R + r*cos(v)) * sin(u)
  // z = r * sin(v)

  int32 TotalVerts = (MajorSegments + 1) * (MinorSegments + 1);
  int32 TotalTris = MajorSegments * MinorSegments * 6;
  Data.Vertices.Reserve(TotalVerts);
  Data.Normals.Reserve(TotalVerts);
  Data.UVs.Reserve(TotalVerts);
  Data.Triangles.Reserve(TotalTris);

  for (int32 u = 0; u <= MajorSegments; ++u)
  {
    float Phi = 2.0f * PI * static_cast<float>(u) / static_cast<float>(MajorSegments);
    float CosPhi = FMath::Cos(Phi);
    float SinPhi = FMath::Sin(Phi);

    for (int32 v = 0; v <= MinorSegments; ++v)
    {
      float Theta = 2.0f * PI * static_cast<float>(v) / static_cast<float>(MinorSegments);
      float CosTheta = FMath::Cos(Theta);
      float SinTheta = FMath::Sin(Theta);

      FVector Position(
        (MajorRadius + MinorRadius * CosTheta) * CosPhi,
        (MajorRadius + MinorRadius * CosTheta) * SinPhi,
        MinorRadius * SinTheta
      );

      // Normal points from the center of the tube cross-section to the surface point
      FVector TubeCenter(MajorRadius * CosPhi, MajorRadius * SinPhi, 0.0f);
      FVector Normal = (Position - TubeCenter).GetSafeNormal();

      Data.Vertices.Add(Position);
      Data.Normals.Add(Normal);
      Data.UVs.Add(FVector2D(
        static_cast<float>(u) / static_cast<float>(MajorSegments),
        static_cast<float>(v) / static_cast<float>(MinorSegments)
      ));
    }
  }

  // Create triangles
  int32 RingSize = MinorSegments + 1;
  for (int32 u = 0; u < MajorSegments; ++u)
  {
    for (int32 v = 0; v < MinorSegments; ++v)
    {
      int32 I00 = u * RingSize + v;
      int32 I10 = (u + 1) * RingSize + v;
      int32 I11 = (u + 1) * RingSize + v + 1;
      int32 I01 = u * RingSize + v + 1;

      // CW winding for UE
      Data.Triangles.Add(I00);
      Data.Triangles.Add(I11);
      Data.Triangles.Add(I10);

      Data.Triangles.Add(I00);
      Data.Triangles.Add(I01);
      Data.Triangles.Add(I11);
    }
  }

  return Data;
}

// =============================================================================
// Arbitrary mesh
// =============================================================================

FMeshData BuildFromVertsFaces(const TArray<FVector>& Verts, const TArray<TArray<int32>>& Faces)
{
  FMeshData Data;

  for (const TArray<int32>& Face : Faces)
  {
    if (Face.Num() < 3)
    {
      continue;
    }

    // Compute face normal from first three vertices of the face
    FVector Normal = ComputeNormal(Verts[Face[0]], Verts[Face[1]], Verts[Face[2]]);

    int32 Base = Data.Vertices.Num();

    // Add all vertices for this face
    for (int32 i = 0; i < Face.Num(); ++i)
    {
      Data.Vertices.Add(Verts[Face[i]]);
      Data.Normals.Add(Normal);
      Data.UVs.Add(FVector2D(
        static_cast<float>(i) / FMath::Max(1.0f, static_cast<float>(Face.Num() - 1)),
        0.0f
      ));
    }

    // Fan triangulation from first vertex of the face
    for (int32 i = 1; i < Face.Num() - 1; ++i)
    {
      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + i);
      Data.Triangles.Add(Base + i + 1);
    }
  }

  ReverseWinding(Data);
  return Data;
}

// =============================================================================
// Pyramid shapes
// =============================================================================

FMeshData BuildPyramid(const TArray<FVector>& Base, const FVector& Apex)
{
  FMeshData Data;
  int32 N = Base.Num();
  if (N < 3)
  {
    return Data;
  }

  // Compute base centroid for base cap
  FVector Centroid = FVector::ZeroVector;
  for (const FVector& P : Base)
  {
    Centroid += P;
  }
  Centroid /= static_cast<float>(N);

  // Base cap (reversed winding so normal faces outward/downward)
  {
    TArray<FVector> BaseFan;
    for (int32 i = N - 1; i >= 0; --i)
    {
      BaseFan.Add(Base[i]);
    }
    BaseFan.Add(Base[N - 1]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(Centroid, BaseFan, FanVerts, FanTris, FanNormals, FanUVs);
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  // Side faces: triangle from each base edge to apex
  for (int32 i = 0; i < N; ++i)
  {
    int32 i1 = (i + 1) % N;
    const FVector& P0 = Base[i];
    const FVector& P1 = Base[i1];

    FVector Normal = ComputeNormal(P0, P1, Apex);

    int32 BaseIdx = Data.Vertices.Num();
    Data.Vertices.Add(P0);
    Data.Vertices.Add(P1);
    Data.Vertices.Add(Apex);

    Data.Normals.Add(Normal);
    Data.Normals.Add(Normal);
    Data.Normals.Add(Normal);

    float U0 = static_cast<float>(i) / static_cast<float>(N);
    float U1 = static_cast<float>(i + 1) / static_cast<float>(N);
    Data.UVs.Add(FVector2D(U0, 0.0f));
    Data.UVs.Add(FVector2D(U1, 0.0f));
    Data.UVs.Add(FVector2D((U0 + U1) * 0.5f, 1.0f));

    Data.Triangles.Add(BaseIdx);
    Data.Triangles.Add(BaseIdx + 1);
    Data.Triangles.Add(BaseIdx + 2);
  }

  // Handedness depends on coordinate system orientation.
  NegateNormals(Data);
  return Data;
}

FMeshData BuildPyramidFrustum(const TArray<FVector>& Base, const TArray<FVector>& Top)
{
  FMeshData Data;
  int32 N = FMath::Min(Base.Num(), Top.Num());
  if (N < 3)
  {
    return Data;
  }

  // Base cap (reversed winding so normal faces outward/downward)
  {
    FVector Centroid = FVector::ZeroVector;
    for (int32 i = 0; i < N; ++i)
    {
      Centroid += Base[i];
    }
    Centroid /= static_cast<float>(N);

    TArray<FVector> BaseFan;
    for (int32 i = N - 1; i >= 0; --i)
    {
      BaseFan.Add(Base[i]);
    }
    BaseFan.Add(Base[N - 1]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(Centroid, BaseFan, FanVerts, FanTris, FanNormals, FanUVs);
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  // Top cap
  {
    FVector Centroid = FVector::ZeroVector;
    for (int32 i = 0; i < N; ++i)
    {
      Centroid += Top[i];
    }
    Centroid /= static_cast<float>(N);

    TArray<FVector> TopFan;
    for (int32 i = 0; i < N; ++i)
    {
      TopFan.Add(Top[i]);
    }
    TopFan.Add(Top[0]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(Centroid, TopFan, FanVerts, FanTris, FanNormals, FanUVs);
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  // Side faces: quads connecting corresponding base/top edges
  for (int32 i = 0; i < N; ++i)
  {
    int32 i1 = (i + 1) % N;
    const FVector& B0 = Base[i];
    const FVector& B1 = Base[i1];
    const FVector& T1 = Top[i1];
    const FVector& T0 = Top[i];

    FVector Normal = ComputeNormal(B0, B1, T1);

    int32 BaseIdx = Data.Vertices.Num();
    Data.Vertices.Add(B0);
    Data.Vertices.Add(B1);
    Data.Vertices.Add(T1);
    Data.Vertices.Add(T0);

    Data.Normals.Add(Normal);
    Data.Normals.Add(Normal);
    Data.Normals.Add(Normal);
    Data.Normals.Add(Normal);

    float U0 = static_cast<float>(i) / static_cast<float>(N);
    float U1 = static_cast<float>(i + 1) / static_cast<float>(N);
    Data.UVs.Add(FVector2D(U0, 0.0f));
    Data.UVs.Add(FVector2D(U1, 0.0f));
    Data.UVs.Add(FVector2D(U1, 1.0f));
    Data.UVs.Add(FVector2D(U0, 1.0f));

    Data.Triangles.Add(BaseIdx);
    Data.Triangles.Add(BaseIdx + 1);
    Data.Triangles.Add(BaseIdx + 2);

    Data.Triangles.Add(BaseIdx);
    Data.Triangles.Add(BaseIdx + 2);
    Data.Triangles.Add(BaseIdx + 3);
  }

  // Handedness of input vertices depends on coordinate system orientation.
  NegateNormals(Data);
  return Data;
}

// =============================================================================
// Multi-section variants (for per-section materials)
// =============================================================================

TArray<FMeshData> BuildCylinderParts(float Radius, float Height, int32 Segments)
{
  TArray<FMeshData> Parts;
  Parts.SetNum(3); // 0=bottom, 1=top, 2=side
  float HalfH = Height * 0.5f;

  FVector BottomCenter(0.0f, 0.0f, -HalfH);
  FVector TopCenter(0.0f, 0.0f, HalfH);

  TArray<FVector> BottomRing, TopRing;
  BottomRing.SetNum(Segments);
  TopRing.SetNum(Segments);
  for (int32 i = 0; i < Segments; ++i)
  {
    float Angle = 2.0f * PI * static_cast<float>(i) / static_cast<float>(Segments);
    float X = Radius * FMath::Cos(Angle);
    float Y = Radius * FMath::Sin(Angle);
    BottomRing[i] = FVector(X, Y, -HalfH);
    TopRing[i] = FVector(X, Y, HalfH);
  }

  // Side (Part 2)
  {
    FMeshData& Side = Parts[2];
    for (int32 i = 0; i < Segments; ++i)
    {
      int32 i1 = (i + 1) % Segments;
      float Angle0 = 2.0f * PI * static_cast<float>(i) / static_cast<float>(Segments);
      float Angle1 = 2.0f * PI * static_cast<float>(i1) / static_cast<float>(Segments);
      FVector N0(FMath::Cos(Angle0), FMath::Sin(Angle0), 0.0f);
      FVector N1(FMath::Cos(Angle1), FMath::Sin(Angle1), 0.0f);
      int32 Base = Side.Vertices.Num();
      float U0 = static_cast<float>(i) / static_cast<float>(Segments);
      float U1 = static_cast<float>(i + 1) / static_cast<float>(Segments);

      Side.Vertices.Add(BottomRing[i]);  Side.Normals.Add(N0); Side.UVs.Add(FVector2D(U0, 0.0f));
      Side.Vertices.Add(BottomRing[i1]); Side.Normals.Add(N1); Side.UVs.Add(FVector2D(U1, 0.0f));
      Side.Vertices.Add(TopRing[i1]);    Side.Normals.Add(N1); Side.UVs.Add(FVector2D(U1, 1.0f));
      Side.Vertices.Add(TopRing[i]);     Side.Normals.Add(N0); Side.UVs.Add(FVector2D(U0, 1.0f));

      Side.Triangles.Add(Base);     Side.Triangles.Add(Base + 2); Side.Triangles.Add(Base + 1);
      Side.Triangles.Add(Base);     Side.Triangles.Add(Base + 3); Side.Triangles.Add(Base + 2);
    }
  }

  // Bottom cap (Part 0)
  {
    TArray<FVector> BottomFan;
    for (int32 i = Segments - 1; i >= 0; --i) BottomFan.Add(BottomRing[i]);
    BottomFan.Add(BottomRing[Segments - 1]);
    TArray<FVector> FanVerts; TArray<int32> FanTris; TArray<FVector> FanNormals; TArray<FVector2D> FanUVs;
    TriangulateFan(BottomCenter, BottomFan, FanVerts, FanTris, FanNormals, FanUVs);
    for (int32 i = 0; i < FanTris.Num(); i += 3) { Swap(FanTris[i + 1], FanTris[i + 2]); }
    AppendMesh(Parts[0], FanVerts, FanTris, FanNormals, FanUVs);
  }

  // Top cap (Part 1)
  {
    TArray<FVector> TopFan;
    for (int32 i = 0; i < Segments; ++i) TopFan.Add(TopRing[i]);
    TopFan.Add(TopRing[0]);
    TArray<FVector> FanVerts; TArray<int32> FanTris; TArray<FVector> FanNormals; TArray<FVector2D> FanUVs;
    TriangulateFan(TopCenter, TopFan, FanVerts, FanTris, FanNormals, FanUVs);
    for (int32 i = 0; i < FanTris.Num(); i += 3) { Swap(FanTris[i + 1], FanTris[i + 2]); }
    AppendMesh(Parts[1], FanVerts, FanTris, FanNormals, FanUVs);
  }

  return Parts;
}

TArray<FMeshData> BuildConeFrustumParts(float BottomRadius, float TopRadius, float Height, int32 Segments)
{
  TArray<FMeshData> Parts;
  Parts.SetNum(3); // 0=bottom, 1=top, 2=side
  float HalfH = Height * 0.5f;
  bool bIsCone = (TopRadius < KINDA_SMALL_NUMBER);

  FVector BottomCenter(0.0f, 0.0f, -HalfH);
  FVector TopCenter(0.0f, 0.0f, HalfH);

  TArray<FVector> BottomRing, TopRing;
  BottomRing.SetNum(Segments);
  if (!bIsCone) TopRing.SetNum(Segments);

  for (int32 i = 0; i < Segments; ++i)
  {
    float Angle = 2.0f * PI * static_cast<float>(i) / static_cast<float>(Segments);
    float CosA = FMath::Cos(Angle);
    float SinA = FMath::Sin(Angle);
    BottomRing[i] = FVector(BottomRadius * CosA, BottomRadius * SinA, -HalfH);
    if (!bIsCone) TopRing[i] = FVector(TopRadius * CosA, TopRadius * SinA, HalfH);
  }

  float SideAngle = FMath::Atan2(BottomRadius - TopRadius, Height);
  float CosSlope = FMath::Cos(SideAngle);
  float SinSlope = FMath::Sin(SideAngle);

  // Side (Part 2)
  {
    FMeshData& Side = Parts[2];
    for (int32 i = 0; i < Segments; ++i)
    {
      int32 i1 = (i + 1) % Segments;
      float Angle0 = 2.0f * PI * static_cast<float>(i) / static_cast<float>(Segments);
      float Angle1 = 2.0f * PI * static_cast<float>(i1) / static_cast<float>(Segments);
      FVector N0(CosSlope * FMath::Cos(Angle0), CosSlope * FMath::Sin(Angle0), SinSlope);
      FVector N1(CosSlope * FMath::Cos(Angle1), CosSlope * FMath::Sin(Angle1), SinSlope);
      float U0 = static_cast<float>(i) / static_cast<float>(Segments);
      float U1 = static_cast<float>(i + 1) / static_cast<float>(Segments);

      if (bIsCone)
      {
        int32 Base = Side.Vertices.Num();
        Side.Vertices.Add(BottomRing[i]);  Side.Normals.Add(N0); Side.UVs.Add(FVector2D(U0, 0.0f));
        Side.Vertices.Add(BottomRing[i1]); Side.Normals.Add(N1); Side.UVs.Add(FVector2D(U1, 0.0f));
        FVector ApexNormal = ((N0 + N1) * 0.5f).GetSafeNormal();
        Side.Vertices.Add(TopCenter);      Side.Normals.Add(ApexNormal); Side.UVs.Add(FVector2D((U0 + U1) * 0.5f, 1.0f));
        Side.Triangles.Add(Base); Side.Triangles.Add(Base + 2); Side.Triangles.Add(Base + 1);
      }
      else
      {
        int32 Base = Side.Vertices.Num();
        Side.Vertices.Add(BottomRing[i]);  Side.Normals.Add(N0); Side.UVs.Add(FVector2D(U0, 0.0f));
        Side.Vertices.Add(BottomRing[i1]); Side.Normals.Add(N1); Side.UVs.Add(FVector2D(U1, 0.0f));
        Side.Vertices.Add(TopRing[i1]);    Side.Normals.Add(N1); Side.UVs.Add(FVector2D(U1, 1.0f));
        Side.Vertices.Add(TopRing[i]);     Side.Normals.Add(N0); Side.UVs.Add(FVector2D(U0, 1.0f));
        Side.Triangles.Add(Base); Side.Triangles.Add(Base + 2); Side.Triangles.Add(Base + 1);
        Side.Triangles.Add(Base); Side.Triangles.Add(Base + 3); Side.Triangles.Add(Base + 2);
      }
    }
  }

  // Bottom cap (Part 0)
  {
    TArray<FVector> BottomFan;
    for (int32 i = Segments - 1; i >= 0; --i) BottomFan.Add(BottomRing[i]);
    BottomFan.Add(BottomRing[Segments - 1]);
    TArray<FVector> FanVerts; TArray<int32> FanTris; TArray<FVector> FanNormals; TArray<FVector2D> FanUVs;
    TriangulateFan(BottomCenter, BottomFan, FanVerts, FanTris, FanNormals, FanUVs);
    for (int32 i = 0; i < FanTris.Num(); i += 3) { Swap(FanTris[i + 1], FanTris[i + 2]); }
    AppendMesh(Parts[0], FanVerts, FanTris, FanNormals, FanUVs);
  }

  // Top cap (Part 1) — empty if cone
  if (!bIsCone)
  {
    TArray<FVector> TopFan;
    for (int32 i = 0; i < Segments; ++i) TopFan.Add(TopRing[i]);
    TopFan.Add(TopRing[0]);
    TArray<FVector> FanVerts; TArray<int32> FanTris; TArray<FVector> FanNormals; TArray<FVector2D> FanUVs;
    TriangulateFan(TopCenter, TopFan, FanVerts, FanTris, FanNormals, FanUVs);
    for (int32 i = 0; i < FanTris.Num(); i += 3) { Swap(FanTris[i + 1], FanTris[i + 2]); }
    AppendMesh(Parts[1], FanVerts, FanTris, FanNormals, FanUVs);
  }

  return Parts;
}

TArray<FMeshData> BuildPyramidParts(const TArray<FVector>& Base, const FVector& Apex)
{
  TArray<FMeshData> Parts;
  Parts.SetNum(2); // 0=base, 1=sides
  int32 N = Base.Num();
  if (N < 3) return Parts;

  FVector Centroid = FVector::ZeroVector;
  for (const FVector& P : Base) Centroid += P;
  Centroid /= static_cast<float>(N);

  // Base cap (Part 0)
  {
    TArray<FVector> BaseFan;
    for (int32 i = N - 1; i >= 0; --i) BaseFan.Add(Base[i]);
    BaseFan.Add(Base[N - 1]);
    TArray<FVector> FanVerts; TArray<int32> FanTris; TArray<FVector> FanNormals; TArray<FVector2D> FanUVs;
    TriangulateFan(Centroid, BaseFan, FanVerts, FanTris, FanNormals, FanUVs);
    AppendMesh(Parts[0], FanVerts, FanTris, FanNormals, FanUVs);
    NegateNormals(Parts[0]);
  }

  // Side faces (Part 1)
  {
    FMeshData& Sides = Parts[1];
    for (int32 i = 0; i < N; ++i)
    {
      int32 i1 = (i + 1) % N;
      FVector Normal = ComputeNormal(Base[i], Base[i1], Apex);
      int32 BaseIdx = Sides.Vertices.Num();
      Sides.Vertices.Add(Base[i]);  Sides.Normals.Add(Normal);
      Sides.Vertices.Add(Base[i1]); Sides.Normals.Add(Normal);
      Sides.Vertices.Add(Apex);     Sides.Normals.Add(Normal);
      float U0 = static_cast<float>(i) / static_cast<float>(N);
      float U1 = static_cast<float>(i + 1) / static_cast<float>(N);
      Sides.UVs.Add(FVector2D(U0, 0.0f));
      Sides.UVs.Add(FVector2D(U1, 0.0f));
      Sides.UVs.Add(FVector2D((U0 + U1) * 0.5f, 1.0f));
      Sides.Triangles.Add(BaseIdx); Sides.Triangles.Add(BaseIdx + 1); Sides.Triangles.Add(BaseIdx + 2);
    }
    NegateNormals(Sides);
  }

  return Parts;
}

TArray<FMeshData> BuildPyramidFrustumParts(const TArray<FVector>& Base, const TArray<FVector>& Top)
{
  TArray<FMeshData> Parts;
  Parts.SetNum(3); // 0=bottom, 1=top, 2=sides
  int32 N = FMath::Min(Base.Num(), Top.Num());
  if (N < 3) return Parts;

  // Bottom cap (Part 0)
  {
    FVector Centroid = FVector::ZeroVector;
    for (int32 i = 0; i < N; ++i) Centroid += Base[i];
    Centroid /= static_cast<float>(N);
    TArray<FVector> BaseFan;
    for (int32 i = N - 1; i >= 0; --i) BaseFan.Add(Base[i]);
    BaseFan.Add(Base[N - 1]);
    TArray<FVector> FanVerts; TArray<int32> FanTris; TArray<FVector> FanNormals; TArray<FVector2D> FanUVs;
    TriangulateFan(Centroid, BaseFan, FanVerts, FanTris, FanNormals, FanUVs);
    AppendMesh(Parts[0], FanVerts, FanTris, FanNormals, FanUVs);
    NegateNormals(Parts[0]);
  }

  // Top cap (Part 1)
  {
    FVector Centroid = FVector::ZeroVector;
    for (int32 i = 0; i < N; ++i) Centroid += Top[i];
    Centroid /= static_cast<float>(N);
    TArray<FVector> TopFan;
    for (int32 i = 0; i < N; ++i) TopFan.Add(Top[i]);
    TopFan.Add(Top[0]);
    TArray<FVector> FanVerts; TArray<int32> FanTris; TArray<FVector> FanNormals; TArray<FVector2D> FanUVs;
    TriangulateFan(Centroid, TopFan, FanVerts, FanTris, FanNormals, FanUVs);
    AppendMesh(Parts[1], FanVerts, FanTris, FanNormals, FanUVs);
    NegateNormals(Parts[1]);
  }

  // Side faces (Part 2)
  {
    FMeshData& Sides = Parts[2];
    for (int32 i = 0; i < N; ++i)
    {
      int32 i1 = (i + 1) % N;
      FVector Normal = ComputeNormal(Base[i], Base[i1], Top[i1]);
      int32 BaseIdx = Sides.Vertices.Num();
      Sides.Vertices.Add(Base[i]);  Sides.Normals.Add(Normal);
      Sides.Vertices.Add(Base[i1]); Sides.Normals.Add(Normal);
      Sides.Vertices.Add(Top[i1]);  Sides.Normals.Add(Normal);
      Sides.Vertices.Add(Top[i]);   Sides.Normals.Add(Normal);
      float U0 = static_cast<float>(i) / static_cast<float>(N);
      float U1 = static_cast<float>(i + 1) / static_cast<float>(N);
      Sides.UVs.Add(FVector2D(U0, 0.0f));
      Sides.UVs.Add(FVector2D(U1, 0.0f));
      Sides.UVs.Add(FVector2D(U1, 1.0f));
      Sides.UVs.Add(FVector2D(U0, 1.0f));
      Sides.Triangles.Add(BaseIdx);     Sides.Triangles.Add(BaseIdx + 1); Sides.Triangles.Add(BaseIdx + 2);
      Sides.Triangles.Add(BaseIdx);     Sides.Triangles.Add(BaseIdx + 2); Sides.Triangles.Add(BaseIdx + 3);
    }
    NegateNormals(Sides);
  }

  return Parts;
}

// =============================================================================
// Tube mesh
// =============================================================================

FMeshData BuildTube(const TArray<FVector>& Points, float Radius, int32 Segments)
{
  FMeshData Data;
  int32 NumPoints = Points.Num();
  if (NumPoints < 2)
  {
    return Data;
  }

  // Generate cross-section rings at each point along the path
  TArray<TArray<FVector>> Rings;
  Rings.SetNum(NumPoints);

  for (int32 p = 0; p < NumPoints; ++p)
  {
    // Compute the tangent direction at this point
    FVector Tangent;
    if (p == 0)
    {
      Tangent = (Points[1] - Points[0]).GetSafeNormal();
    }
    else if (p == NumPoints - 1)
    {
      Tangent = (Points[p] - Points[p - 1]).GetSafeNormal();
    }
    else
    {
      Tangent = (Points[p + 1] - Points[p - 1]).GetSafeNormal();
    }

    // Build a coordinate frame perpendicular to the tangent
    FVector Up = FMath::Abs(FVector::DotProduct(Tangent, FVector::UpVector)) > 0.99f
      ? FVector::ForwardVector
      : FVector::UpVector;
    FVector Right = FVector::CrossProduct(Tangent, Up).GetSafeNormal();
    FVector Actual_Up = FVector::CrossProduct(Right, Tangent).GetSafeNormal();

    Rings[p].SetNum(Segments);
    for (int32 s = 0; s < Segments; ++s)
    {
      float Angle = 2.0f * PI * static_cast<float>(s) / static_cast<float>(Segments);
      FVector Offset = Right * (Radius * FMath::Cos(Angle)) + Actual_Up * (Radius * FMath::Sin(Angle));
      Rings[p][s] = Points[p] + Offset;
    }
  }

  // Connect consecutive rings with quad strips (smooth normals)
  for (int32 p = 0; p < NumPoints - 1; ++p)
  {
    for (int32 s = 0; s < Segments; ++s)
    {
      int32 s1 = (s + 1) % Segments;

      const FVector& B0 = Rings[p][s];
      const FVector& B1 = Rings[p][s1];
      const FVector& T0 = Rings[p + 1][s];
      const FVector& T1 = Rings[p + 1][s1];

      // Smooth normals: from center of path to surface point
      FVector N_B0 = (B0 - Points[p]).GetSafeNormal();
      FVector N_B1 = (B1 - Points[p]).GetSafeNormal();
      FVector N_T0 = (T0 - Points[p + 1]).GetSafeNormal();
      FVector N_T1 = (T1 - Points[p + 1]).GetSafeNormal();

      int32 Base = Data.Vertices.Num();

      float U0 = static_cast<float>(s) / static_cast<float>(Segments);
      float U1 = static_cast<float>(s + 1) / static_cast<float>(Segments);
      float V0 = static_cast<float>(p) / static_cast<float>(NumPoints - 1);
      float V1 = static_cast<float>(p + 1) / static_cast<float>(NumPoints - 1);

      Data.Vertices.Add(B0);
      Data.Normals.Add(N_B0);
      Data.UVs.Add(FVector2D(U0, V0));

      Data.Vertices.Add(B1);
      Data.Normals.Add(N_B1);
      Data.UVs.Add(FVector2D(U1, V0));

      Data.Vertices.Add(T1);
      Data.Normals.Add(N_T1);
      Data.UVs.Add(FVector2D(U1, V1));

      Data.Vertices.Add(T0);
      Data.Normals.Add(N_T0);
      Data.UVs.Add(FVector2D(U0, V1));

      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 1);
      Data.Triangles.Add(Base + 2);

      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 2);
      Data.Triangles.Add(Base + 3);
    }
  }

  // Cap the start end
  {
    FVector Tangent = (Points[1] - Points[0]).GetSafeNormal();
    FVector Center = Points[0];

    TArray<FVector> CapPoints;
    // Reversed winding for start cap (faces away from path direction)
    for (int32 s = Segments - 1; s >= 0; --s)
    {
      CapPoints.Add(Rings[0][s]);
    }
    CapPoints.Add(Rings[0][Segments - 1]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(Center, CapPoints, FanVerts, FanTris, FanNormals, FanUVs);
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  // Cap the end
  {
    FVector Center = Points[NumPoints - 1];

    TArray<FVector> CapPoints;
    for (int32 s = 0; s < Segments; ++s)
    {
      CapPoints.Add(Rings[NumPoints - 1][s]);
    }
    CapPoints.Add(Rings[NumPoints - 1][0]);

    TArray<FVector> FanVerts;
    TArray<int32> FanTris;
    TArray<FVector> FanNormals;
    TArray<FVector2D> FanUVs;
    TriangulateFan(Center, CapPoints, FanVerts, FanTris, FanNormals, FanUVs);
    AppendMesh(Data, FanVerts, FanTris, FanNormals, FanUVs);
  }

  ReverseWinding(Data);
  return Data;
}

FMeshData BuildPointMarker(const FVector& Position, float Size)
{
  // Small sphere at the given position
  FMeshData Data = BuildSphere(Size * 0.5f, 8, 8);

  // Offset all vertices by Position
  for (FVector& V : Data.Vertices)
  {
    V += Position;
  }

  return Data; // Already double-sided from BuildSphere
}

// =============================================================================
// BIM elements
// =============================================================================

FMeshData BuildSlab(const TArray<FVector>& Contour, const TArray<TArray<FVector>>& Holes, float Height)
{
  FMeshData Data;
  if (Contour.Num() < 3)
  {
    return Data;
  }

  FVector ExtrudeDir(0.0f, 0.0f, Height);

  // Top face: contour polygon
  {
    TArray<FVector> TopContour;
    TopContour.SetNum(Contour.Num());
    for (int32 i = 0; i < Contour.Num(); ++i)
    {
      TopContour[i] = Contour[i] + ExtrudeDir;
    }

    TArray<int32> TriIndices = TriangulatePolygon(TopContour);
    FVector Normal = ComputeNormal(TopContour[0], TopContour[1], TopContour[2]);

    int32 Base = Data.Vertices.Num();
    for (int32 i = 0; i < TopContour.Num(); ++i)
    {
      Data.Vertices.Add(TopContour[i]);
      Data.Normals.Add(Normal);
      Data.UVs.Add(FVector2D(TopContour[i].X * 0.01f, TopContour[i].Y * 0.01f));
    }
    for (int32 Idx : TriIndices)
    {
      Data.Triangles.Add(Idx + Base);
    }
  }

  // Bottom face: contour polygon (reversed winding)
  {
    TArray<FVector> BottomContour;
    BottomContour.SetNum(Contour.Num());
    for (int32 i = 0; i < Contour.Num(); ++i)
    {
      BottomContour[i] = Contour[Contour.Num() - 1 - i];
    }

    TArray<int32> TriIndices = TriangulatePolygon(BottomContour);
    FVector Normal = ComputeNormal(BottomContour[0], BottomContour[1], BottomContour[2]);

    int32 Base = Data.Vertices.Num();
    for (int32 i = 0; i < BottomContour.Num(); ++i)
    {
      Data.Vertices.Add(BottomContour[i]);
      Data.Normals.Add(Normal);
      Data.UVs.Add(FVector2D(BottomContour[i].X * 0.01f, BottomContour[i].Y * 0.01f));
    }
    for (int32 Idx : TriIndices)
    {
      Data.Triangles.Add(Idx + Base);
    }
  }

  // Side faces for the contour: quads connecting bottom and top edges
  for (int32 i = 0; i < Contour.Num(); ++i)
  {
    int32 i1 = (i + 1) % Contour.Num();
    const FVector& B0 = Contour[i];
    const FVector& B1 = Contour[i1];
    FVector T0 = B0 + ExtrudeDir;
    FVector T1 = B1 + ExtrudeDir;

    FVector Normal = ComputeNormal(B0, B1, T1);

    int32 Base = Data.Vertices.Num();
    Data.Vertices.Add(B0);
    Data.Vertices.Add(B1);
    Data.Vertices.Add(T1);
    Data.Vertices.Add(T0);

    Data.Normals.Add(Normal);
    Data.Normals.Add(Normal);
    Data.Normals.Add(Normal);
    Data.Normals.Add(Normal);

    float U0 = static_cast<float>(i) / static_cast<float>(Contour.Num());
    float U1 = static_cast<float>(i + 1) / static_cast<float>(Contour.Num());
    Data.UVs.Add(FVector2D(U0, 0.0f));
    Data.UVs.Add(FVector2D(U1, 0.0f));
    Data.UVs.Add(FVector2D(U1, 1.0f));
    Data.UVs.Add(FVector2D(U0, 1.0f));

    Data.Triangles.Add(Base);
    Data.Triangles.Add(Base + 1);
    Data.Triangles.Add(Base + 2);

    Data.Triangles.Add(Base);
    Data.Triangles.Add(Base + 2);
    Data.Triangles.Add(Base + 3);
  }

  // Side faces for holes (winding reversed compared to contour sides so normals face inward)
  for (const TArray<FVector>& Hole : Holes)
  {
    for (int32 i = 0; i < Hole.Num(); ++i)
    {
      int32 i1 = (i + 1) % Hole.Num();
      const FVector& B0 = Hole[i1]; // Reversed winding
      const FVector& B1 = Hole[i];
      FVector T0 = B0 + ExtrudeDir;
      FVector T1 = B1 + ExtrudeDir;

      FVector Normal = ComputeNormal(B0, B1, T1);

      int32 Base = Data.Vertices.Num();
      Data.Vertices.Add(B0);
      Data.Vertices.Add(B1);
      Data.Vertices.Add(T1);
      Data.Vertices.Add(T0);

      Data.Normals.Add(Normal);
      Data.Normals.Add(Normal);
      Data.Normals.Add(Normal);
      Data.Normals.Add(Normal);

      float U0 = static_cast<float>(i) / static_cast<float>(Hole.Num());
      float U1 = static_cast<float>(i + 1) / static_cast<float>(Hole.Num());
      Data.UVs.Add(FVector2D(U0, 0.0f));
      Data.UVs.Add(FVector2D(U1, 0.0f));
      Data.UVs.Add(FVector2D(U1, 1.0f));
      Data.UVs.Add(FVector2D(U0, 1.0f));

      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 1);
      Data.Triangles.Add(Base + 2);

      Data.Triangles.Add(Base);
      Data.Triangles.Add(Base + 2);
      Data.Triangles.Add(Base + 3);
    }
  }

  ReverseWinding(Data);
  return Data;
}

FMeshData BuildPanel(const TArray<FVector>& Points, const FVector& Normal)
{
  FMeshData Data;
  if (Points.Num() < 3)
  {
    return Data;
  }

  FVector ExtrudeDir = Normal;

  // Front face (original polygon)
  {
    TArray<int32> TriIndices = TriangulatePolygon(Points);
    FVector FaceNormal = ComputeNormal(Points[0], Points[1], Points[2]);

    int32 Base = Data.Vertices.Num();
    for (int32 i = 0; i < Points.Num(); ++i)
    {
      Data.Vertices.Add(Points[i]);
      Data.Normals.Add(FaceNormal);
      Data.UVs.Add(FVector2D(
        static_cast<float>(i) / FMath::Max(1.0f, static_cast<float>(Points.Num() - 1)),
        0.0f
      ));
    }
    for (int32 Idx : TriIndices)
    {
      Data.Triangles.Add(Idx + Base);
    }
  }

  // Back face (extruded polygon, reversed winding)
  {
    TArray<FVector> BackPoints;
    BackPoints.SetNum(Points.Num());
    for (int32 i = 0; i < Points.Num(); ++i)
    {
      BackPoints[i] = Points[Points.Num() - 1 - i] + ExtrudeDir;
    }

    TArray<int32> TriIndices = TriangulatePolygon(BackPoints);
    FVector FaceNormal = ComputeNormal(BackPoints[0], BackPoints[1], BackPoints[2]);

    int32 Base = Data.Vertices.Num();
    for (int32 i = 0; i < BackPoints.Num(); ++i)
    {
      Data.Vertices.Add(BackPoints[i]);
      Data.Normals.Add(FaceNormal);
      Data.UVs.Add(FVector2D(
        static_cast<float>(i) / FMath::Max(1.0f, static_cast<float>(BackPoints.Num() - 1)),
        1.0f
      ));
    }
    for (int32 Idx : TriIndices)
    {
      Data.Triangles.Add(Idx + Base);
    }
  }

  // Side faces
  int32 N = Points.Num();
  for (int32 i = 0; i < N; ++i)
  {
    int32 i1 = (i + 1) % N;
    const FVector& B0 = Points[i];
    const FVector& B1 = Points[i1];
    FVector T0 = B0 + ExtrudeDir;
    FVector T1 = B1 + ExtrudeDir;

    FVector SideNormal = ComputeNormal(B0, B1, T1);

    int32 Base = Data.Vertices.Num();
    Data.Vertices.Add(B0);
    Data.Vertices.Add(B1);
    Data.Vertices.Add(T1);
    Data.Vertices.Add(T0);

    Data.Normals.Add(SideNormal);
    Data.Normals.Add(SideNormal);
    Data.Normals.Add(SideNormal);
    Data.Normals.Add(SideNormal);

    float U0 = static_cast<float>(i) / static_cast<float>(N);
    float U1 = static_cast<float>(i + 1) / static_cast<float>(N);
    Data.UVs.Add(FVector2D(U0, 0.0f));
    Data.UVs.Add(FVector2D(U1, 0.0f));
    Data.UVs.Add(FVector2D(U1, 1.0f));
    Data.UVs.Add(FVector2D(U0, 1.0f));

    Data.Triangles.Add(Base);
    Data.Triangles.Add(Base + 1);
    Data.Triangles.Add(Base + 2);

    Data.Triangles.Add(Base);
    Data.Triangles.Add(Base + 2);
    Data.Triangles.Add(Base + 3);
  }

  ReverseWinding(Data);
  return Data;
}

// =============================================================================
// Beam sections
// =============================================================================

FMeshData BuildBeamRectSection(float DX, float DY, float DZ)
{
  return BuildBox(FVector(DX, DY, DZ));
}

FMeshData BuildBeamCircSection(float Radius, float Height, int32 Segments)
{
  return BuildCylinder(Radius, Height, Segments);
}

} // namespace KhepriMeshBuilder
