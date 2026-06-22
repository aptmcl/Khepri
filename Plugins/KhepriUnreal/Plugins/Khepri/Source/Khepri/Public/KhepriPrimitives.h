// KhepriPrimitives.h — All Khepri operations
// Free functions registered via REGISTER_OP macro.
// Each function reads parameters from FKhepriChannel, executes, writes result.

#pragma once

#include "CoreMinimal.h"
#include "KhepriChannel.h"
#include "KhepriMeshBuilder.h"

class FKhepriServer;

namespace KhepriPrimitives
{
  // Register all operations with the server
  void RegisterAllOperations(FKhepriServer& Server);

  // --- Shape Management ---
  void DeleteAll(FKhepriChannel& Channel);
  void DeleteAllShapes(FKhepriChannel& Channel);
  void DeleteMany(FKhepriChannel& Channel);
  void DeleteRef(FKhepriChannel& Channel);

  // --- Tier 0: Curves ---
  void Point(FKhepriChannel& Channel);
  void Line(FKhepriChannel& Channel);
  void ClosedLine(FKhepriChannel& Channel);

  // --- Tier 1: Surfaces ---
  void Triangle(FKhepriChannel& Channel);
  void Quad(FKhepriChannel& Channel);
  void NGon(FKhepriChannel& Channel);
  void QuadStrip(FKhepriChannel& Channel);
  void SurfacePolygon(FKhepriChannel& Channel);

  // --- Tier 2: Advanced Surfaces ---
  void SurfaceGrid(FKhepriChannel& Channel);
  void SurfaceMesh(FKhepriChannel& Channel);

  // --- Tier 3: Solids ---
  void Sphere(FKhepriChannel& Channel);
  void Box(FKhepriChannel& Channel);
  void RightCuboid(FKhepriChannel& Channel);
  void Cylinder(FKhepriChannel& Channel);
  void ConeFrustum(FKhepriChannel& Channel);
  void Torus(FKhepriChannel& Channel);
  void Pyramid(FKhepriChannel& Channel);
  void PyramidFrustum(FKhepriChannel& Channel);
  void PyramidFrustumWithMaterial(FKhepriChannel& Channel);

  // --- BIM Elements ---
  void Slab(FKhepriChannel& Channel);
  void Panel(FKhepriChannel& Channel);
  void BeamRectSection(FKhepriChannel& Channel);
  void BeamCircSection(FKhepriChannel& Channel);
  void InstantiateBIMElement(FKhepriChannel& Channel);
  void CreateBlockInstance(FKhepriChannel& Channel);

  // --- Materials & Layers ---
  void LoadMaterial(FKhepriChannel& Channel);
  void CreatePBRMaterial(FKhepriChannel& Channel);
  void CurrentMaterial(FKhepriChannel& Channel);
  void SetCurrentMaterial(FKhepriChannel& Channel);
  void CurrentParent(FKhepriChannel& Channel);
  void SetCurrentParent(FKhepriChannel& Channel);
  void CreateParent(FKhepriChannel& Channel);
  void SetParentVisible(FKhepriChannel& Channel);
  void SetParentOpacity(FKhepriChannel& Channel);
  void DeleteAllInParent(FKhepriChannel& Channel);
  void LoadResource(FKhepriChannel& Channel);

  // --- Lighting ---
  void PointLight(FKhepriChannel& Channel);
  void Spotlight(FKhepriChannel& Channel);

  // --- Boolean Operations ---
  void Unite(FKhepriChannel& Channel);
  void Subtract(FKhepriChannel& Channel);
  void Intersect(FKhepriChannel& Channel);

  // --- Transformations ---
  void Move(FKhepriChannel& Channel);
  void Scale(FKhepriChannel& Channel);
  void Rotate(FKhepriChannel& Channel);

  // --- View & Rendering ---
  void SetView(FKhepriChannel& Channel);
  void ViewCamera(FKhepriChannel& Channel);
  void ViewTarget(FKhepriChannel& Channel);
  void ViewLens(FKhepriChannel& Channel);
  void RenderView(FKhepriChannel& Channel);
  void ZoomExtents(FKhepriChannel& Channel);
  void ViewSize(FKhepriChannel& Channel);

  // --- Bounding Box ---
  void BoundingBoxMin(FKhepriChannel& Channel);
  void BoundingBoxMax(FKhepriChannel& Channel);

  // --- Batch ---
  void DisableUpdate(FKhepriChannel& Channel);
  void EnableUpdate(FKhepriChannel& Channel);

  // --- Selection ---
  void HighlightRefs(FKhepriChannel& Channel);
  void UnhighlightRefs(FKhepriChannel& Channel);
  void UnhighlightAllRefs(FKhepriChannel& Channel);

  // --- Shape query ---
  void ShapeType(FKhepriChannel& Channel);

  // --- Deferred selection (result sent by server polling loop) ---
  void GetShape(FKhepriChannel& Channel);
  void GetShapes(FKhepriChannel& Channel);
  extern bool bSelectionPending;
  extern bool bSelectMany;

  // --- Internal helpers ---
  // Spawn actor with ProceduralMeshComponent, apply material, attach to parent, register
  int32 CreateMeshActor(FKhepriChannel& Channel, const KhepriMeshBuilder::FMeshData& MeshData,
                        int32 MaterialIndex = -1, const FVector& Location = FVector::ZeroVector,
                        const FRotator& Rotation = FRotator::ZeroRotator,
                        bool bCreateCollision = true,
                        const TCHAR* ShapeLabel = TEXT("Shape"));

  // Multi-section variant: one ProceduralMeshComponent section per FMeshData, each with its own material
  int32 CreateMeshActor(FKhepriChannel& Channel,
                        const TArray<KhepriMeshBuilder::FMeshData>& Sections,
                        const TArray<int32>& MaterialIndices,
                        const FVector& Location = FVector::ZeroVector,
                        const FRotator& Rotation = FRotator::ZeroRotator,
                        bool bCreateCollision = true,
                        const TCHAR* ShapeLabel = TEXT("Shape"));
}
