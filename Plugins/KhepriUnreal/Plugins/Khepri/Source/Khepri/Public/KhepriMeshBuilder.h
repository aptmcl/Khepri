// KhepriMeshBuilder.h — Mesh generation utilities
// Pure geometry functions returning (Vertices, Triangles, Normals, UVs)
// for UProceduralMeshComponent. All functions generate double-sided geometry.

#pragma once

#include "CoreMinimal.h"
#include "ProceduralMeshComponent.h"

namespace KhepriMeshBuilder
{
  struct FMeshData
  {
    TArray<FVector> Vertices;
    TArray<int32> Triangles;
    TArray<FVector> Normals;
    TArray<FVector2D> UVs;
  };

  // Tier 3 — Solid primitives
  FMeshData BuildBox(const FVector& Size);
  FMeshData BuildBoxFromCorners(
    const FVector& B0, const FVector& B1, const FVector& B2, const FVector& B3,
    const FVector& T0, const FVector& T1, const FVector& T2, const FVector& T3);
  FMeshData BuildSphere(float Radius, int32 LatSegments = 32, int32 LonSegments = 32);
  FMeshData BuildCylinder(float Radius, float Height, int32 Segments = 32);
  FMeshData BuildConeFrustum(float BottomRadius, float TopRadius, float Height, int32 Segments = 32);
  FMeshData BuildTorus(float MajorRadius, float MinorRadius, int32 MajorSegments = 32, int32 MinorSegments = 16);

  // Arbitrary mesh from vertices and face index lists
  FMeshData BuildFromVertsFaces(const TArray<FVector>& Verts, const TArray<TArray<int32>>& Faces);

  // Tier 1 — Surface primitives
  FMeshData BuildTriangle(const FVector& P1, const FVector& P2, const FVector& P3);
  FMeshData BuildQuad(const FVector& P1, const FVector& P2, const FVector& P3, const FVector& P4);
  FMeshData BuildNGon(const TArray<FVector>& Points, const FVector& Pivot);
  FMeshData BuildQuadStrip(const TArray<FVector>& Bottom, const TArray<FVector>& Top, bool Smooth);
  FMeshData BuildSurfacePolygon(const TArray<FVector>& Points);
  FMeshData BuildSurfaceGrid(const TArray<TArray<FVector>>& Points, bool ClosedU, bool ClosedV, bool Smooth);

  // Pyramid shapes
  FMeshData BuildPyramid(const TArray<FVector>& Base, const FVector& Apex);
  FMeshData BuildPyramidFrustum(const TArray<FVector>& Base, const TArray<FVector>& Top);

  // Multi-section variants returning separate FMeshData per part (for per-section materials)
  // Cylinder: {bottom, top, side}
  TArray<FMeshData> BuildCylinderParts(float Radius, float Height, int32 Segments = 32);
  // ConeFrustum: {bottom, top, side} — top is empty if cone (TopRadius~0)
  TArray<FMeshData> BuildConeFrustumParts(float BottomRadius, float TopRadius, float Height, int32 Segments = 32);
  // Pyramid: {base, sides}
  TArray<FMeshData> BuildPyramidParts(const TArray<FVector>& Base, const FVector& Apex);
  // PyramidFrustum: {bottom, top, sides}
  TArray<FMeshData> BuildPyramidFrustumParts(const TArray<FVector>& Base, const TArray<FVector>& Top);

  // Lines as tube meshes
  FMeshData BuildTube(const TArray<FVector>& Points, float Radius, int32 Segments = 8);
  FMeshData BuildPointMarker(const FVector& Position, float Size = 5.0f);

  // Slab with holes
  FMeshData BuildSlab(const TArray<FVector>& Contour, const TArray<TArray<FVector>>& Holes, float Height);

  // Panel (extruded polygon along normal)
  FMeshData BuildPanel(const TArray<FVector>& Points, const FVector& Normal);

  // Beam sections
  FMeshData BuildBeamRectSection(float DX, float DY, float DZ);
  FMeshData BuildBeamCircSection(float Radius, float Height, int32 Segments = 16);

  // Utility
  FVector ComputeNormal(const FVector& P1, const FVector& P2, const FVector& P3);
  void MakeDoubleSided(FMeshData& Data);
  void ReverseWinding(FMeshData& Data);
  void NegateNormals(FMeshData& Data);

  // Fan triangulation for N-gons: creates triangles from Pivot to consecutive point pairs
  void TriangulateFan(const FVector& Pivot, const TArray<FVector>& Points,
                      TArray<FVector>& OutVerts, TArray<int32>& OutTris, TArray<FVector>& OutNormals, TArray<FVector2D>& OutUVs);

  // Simple ear-clipping triangulation for convex/simple polygons
  TArray<int32> TriangulatePolygon(const TArray<FVector>& Points);
}
