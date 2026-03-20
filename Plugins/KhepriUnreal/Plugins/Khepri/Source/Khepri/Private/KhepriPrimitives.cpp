// KhepriPrimitives.cpp — All Khepri operations for Unreal Engine
// Each function reads parameters from FKhepriChannel, executes, writes result.

#include "KhepriPrimitives.h"
#include "KhepriModule.h"
#include "KhepriServer.h"
#include "KhepriMeshBuilder.h"

#include "Engine/World.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/Actor.h"
#include "Components/StaticMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/SpotLightComponent.h"
#include "ProceduralMeshComponent.h"
#include "Materials/Material.h"
#include "Materials/MaterialInterface.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialExpressionVectorParameter.h"
#include "Materials/MaterialExpressionScalarParameter.h"
#include "Materials/MaterialExpressionMultiply.h"
#include "UObject/ConstructorHelpers.h"
#include "UObject/Package.h"
#include "Editor.h"
#include "LevelEditorViewport.h"
#include "EditorViewportClient.h"
#include "UnrealEdGlobals.h"
#include "Editor/UnrealEdEngine.h"
#include "HighResScreenshot.h"
#include "Kismet/KismetRenderingLibrary.h"
#include "Engine/Selection.h"
#include "EngineUtils.h"
#include "Framework/Application/SlateApplication.h"
#include "Widgets/SWindow.h"

// =============================================================================
// Static base material for dynamic material instances
// =============================================================================

static UMaterial* GKhepriBaseMaterial = nullptr;

static UMaterial* GetOrCreateBaseMaterial()
{
  if (GKhepriBaseMaterial && GKhepriBaseMaterial->IsValidLowLevel())
  {
    return GKhepriBaseMaterial;
  }

  UMaterial* Mat = NewObject<UMaterial>(GetTransientPackage(), TEXT("M_KhepriBase"));

  // BaseColor vector parameter (RGBA)
  auto* BaseColorParam = NewObject<UMaterialExpressionVectorParameter>(Mat);
  BaseColorParam->ParameterName = TEXT("BaseColor");
  BaseColorParam->DefaultValue = FLinearColor(0.8f, 0.8f, 0.8f, 1.0f);

  // Metallic scalar parameter
  auto* MetallicParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  MetallicParam->ParameterName = TEXT("Metallic");
  MetallicParam->DefaultValue = 0.0f;

  // Specular scalar parameter
  auto* SpecularParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  SpecularParam->ParameterName = TEXT("Specular");
  SpecularParam->DefaultValue = 0.5f;

  // Roughness scalar parameter
  auto* RoughnessParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  RoughnessParam->ParameterName = TEXT("Roughness");
  RoughnessParam->DefaultValue = 0.5f;

  // Opacity scalar parameter
  auto* OpacityParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  OpacityParam->ParameterName = TEXT("Opacity");
  OpacityParam->DefaultValue = 1.0f;

  // EmissiveColor vector parameter (RGB)
  auto* EmissiveColorParam = NewObject<UMaterialExpressionVectorParameter>(Mat);
  EmissiveColorParam->ParameterName = TEXT("EmissiveColor");
  EmissiveColorParam->DefaultValue = FLinearColor(0.0f, 0.0f, 0.0f, 1.0f);

  // EmissionStrength scalar parameter (multiplied with EmissiveColor)
  auto* EmissionStrengthParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  EmissionStrengthParam->ParameterName = TEXT("EmissionStrength");
  EmissionStrengthParam->DefaultValue = 0.0f;

  // Multiply emissive color by strength for the emissive input
  auto* EmissiveMultiply = NewObject<UMaterialExpressionMultiply>(Mat);

  // Register expressions with the material
  Mat->GetExpressionCollection().Expressions.Add(BaseColorParam);
  Mat->GetExpressionCollection().Expressions.Add(MetallicParam);
  Mat->GetExpressionCollection().Expressions.Add(SpecularParam);
  Mat->GetExpressionCollection().Expressions.Add(RoughnessParam);
  Mat->GetExpressionCollection().Expressions.Add(OpacityParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissiveColorParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissionStrengthParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissiveMultiply);

  // Wire expressions to material input pins
#if WITH_EDITORONLY_DATA
  UMaterialEditorOnlyData* EditorData = Mat->GetEditorOnlyData();
  EditorData->BaseColor.Expression = BaseColorParam;
  EditorData->Metallic.Expression = MetallicParam;
  EditorData->Specular.Expression = SpecularParam;
  EditorData->Roughness.Expression = RoughnessParam;
  EditorData->Opacity.Expression = OpacityParam;
  // EmissiveColor = EmissiveColorParam * EmissionStrengthParam
  EmissiveMultiply->A.Expression = EmissiveColorParam;
  EmissiveMultiply->B.Expression = EmissionStrengthParam;
  EditorData->EmissiveColor.Expression = EmissiveMultiply;
#endif

  Mat->TwoSided = true;

  // Trigger material compilation
  Mat->PreEditChange(nullptr);
  Mat->PostEditChange();

  Mat->AddToRoot();
  GKhepriBaseMaterial = Mat;

  UE_LOG(LogKhepri, Log, TEXT("Created KhepriBaseMaterial with BaseColor, Metallic, Specular, Roughness, Opacity, EmissiveColor, EmissionStrength parameters"));
  return GKhepriBaseMaterial;
}

// =============================================================================
// Actor naming counter
// =============================================================================

static int32 GKhepriActorCounter = 0;

// =============================================================================
// Registration
// =============================================================================

void KhepriPrimitives::RegisterAllOperations(FKhepriServer& Server)
{
  // Shape Management
  Server.RegisterOperation(TEXT("Primitive::DeleteAll"), &KhepriPrimitives::DeleteAll);
  Server.RegisterOperation(TEXT("Primitive::DeleteAllShapes"), &KhepriPrimitives::DeleteAllShapes);
  Server.RegisterOperation(TEXT("Primitive::DeleteMany"), &KhepriPrimitives::DeleteMany);
  Server.RegisterOperation(TEXT("Primitive::DeleteRef"), &KhepriPrimitives::DeleteRef);

  // Tier 0: Curves
  Server.RegisterOperation(TEXT("Primitive::Point"), &KhepriPrimitives::Point);
  Server.RegisterOperation(TEXT("Primitive::Line"), &KhepriPrimitives::Line);
  Server.RegisterOperation(TEXT("Primitive::ClosedLine"), &KhepriPrimitives::ClosedLine);

  // Tier 1: Surfaces
  Server.RegisterOperation(TEXT("Primitive::Triangle"), &KhepriPrimitives::Triangle);
  Server.RegisterOperation(TEXT("Primitive::Quad"), &KhepriPrimitives::Quad);
  Server.RegisterOperation(TEXT("Primitive::NGon"), &KhepriPrimitives::NGon);
  Server.RegisterOperation(TEXT("Primitive::QuadStrip"), &KhepriPrimitives::QuadStrip);
  Server.RegisterOperation(TEXT("Primitive::SurfacePolygon"), &KhepriPrimitives::SurfacePolygon);

  // Tier 2: Advanced Surfaces
  Server.RegisterOperation(TEXT("Primitive::SurfaceGrid"), &KhepriPrimitives::SurfaceGrid);
  Server.RegisterOperation(TEXT("Primitive::SurfaceMesh"), &KhepriPrimitives::SurfaceMesh);

  // Tier 3: Solids
  Server.RegisterOperation(TEXT("Primitive::Sphere"), &KhepriPrimitives::Sphere);
  Server.RegisterOperation(TEXT("Primitive::Box"), &KhepriPrimitives::Box);
  Server.RegisterOperation(TEXT("Primitive::RightCuboid"), &KhepriPrimitives::RightCuboid);
  Server.RegisterOperation(TEXT("Primitive::Cylinder"), &KhepriPrimitives::Cylinder);
  Server.RegisterOperation(TEXT("Primitive::ConeFrustum"), &KhepriPrimitives::ConeFrustum);
  Server.RegisterOperation(TEXT("Primitive::Torus"), &KhepriPrimitives::Torus);
  Server.RegisterOperation(TEXT("Primitive::Pyramid"), &KhepriPrimitives::Pyramid);
  Server.RegisterOperation(TEXT("Primitive::PyramidFrustum"), &KhepriPrimitives::PyramidFrustum);
  Server.RegisterOperation(TEXT("Primitive::PyramidFrustumWithMaterial"), &KhepriPrimitives::PyramidFrustumWithMaterial);

  // BIM Elements
  Server.RegisterOperation(TEXT("Primitive::Slab"), &KhepriPrimitives::Slab);
  Server.RegisterOperation(TEXT("Primitive::Panel"), &KhepriPrimitives::Panel);
  Server.RegisterOperation(TEXT("Primitive::BeamRectSection"), &KhepriPrimitives::BeamRectSection);
  Server.RegisterOperation(TEXT("Primitive::BeamCircSection"), &KhepriPrimitives::BeamCircSection);
  Server.RegisterOperation(TEXT("Primitive::InstantiateBIMElement"), &KhepriPrimitives::InstantiateBIMElement);
  Server.RegisterOperation(TEXT("Primitive::CreateBlockInstance"), &KhepriPrimitives::CreateBlockInstance);

  // Materials & Layers
  Server.RegisterOperation(TEXT("Primitive::LoadMaterial"), &KhepriPrimitives::LoadMaterial);
  Server.RegisterOperation(TEXT("Primitive::CreateMaterial"), &KhepriPrimitives::CreateMaterial);
  Server.RegisterOperation(TEXT("Primitive::CurrentMaterial"), &KhepriPrimitives::CurrentMaterial);
  Server.RegisterOperation(TEXT("Primitive::SetCurrentMaterial"), &KhepriPrimitives::SetCurrentMaterial);
  Server.RegisterOperation(TEXT("Primitive::CurrentParent"), &KhepriPrimitives::CurrentParent);
  Server.RegisterOperation(TEXT("Primitive::SetCurrentParent"), &KhepriPrimitives::SetCurrentParent);
  Server.RegisterOperation(TEXT("Primitive::CreateParent"), &KhepriPrimitives::CreateParent);
  Server.RegisterOperation(TEXT("Primitive::LoadResource"), &KhepriPrimitives::LoadResource);

  // Lighting
  Server.RegisterOperation(TEXT("Primitive::PointLight"), &KhepriPrimitives::PointLight);
  Server.RegisterOperation(TEXT("Primitive::Spotlight"), &KhepriPrimitives::Spotlight);

  // Boolean Operations
  Server.RegisterOperation(TEXT("Primitive::Unite"), &KhepriPrimitives::Unite);
  Server.RegisterOperation(TEXT("Primitive::Subtract"), &KhepriPrimitives::Subtract);
  Server.RegisterOperation(TEXT("Primitive::Intersect"), &KhepriPrimitives::Intersect);

  // View & Rendering
  Server.RegisterOperation(TEXT("Primitive::SetView"), &KhepriPrimitives::SetView);
  Server.RegisterOperation(TEXT("Primitive::ViewCamera"), &KhepriPrimitives::ViewCamera);
  Server.RegisterOperation(TEXT("Primitive::ViewTarget"), &KhepriPrimitives::ViewTarget);
  Server.RegisterOperation(TEXT("Primitive::ViewLens"), &KhepriPrimitives::ViewLens);
  Server.RegisterOperation(TEXT("Primitive::RenderView"), &KhepriPrimitives::RenderView);
  Server.RegisterOperation(TEXT("Primitive::ZoomExtents"), &KhepriPrimitives::ZoomExtents);
  Server.RegisterOperation(TEXT("Primitive::ViewSize"), &KhepriPrimitives::ViewSize);

  // Bounding Box
  Server.RegisterOperation(TEXT("Primitive::BoundingBoxMin"), &KhepriPrimitives::BoundingBoxMin);
  Server.RegisterOperation(TEXT("Primitive::BoundingBoxMax"), &KhepriPrimitives::BoundingBoxMax);

  // Batch
  Server.RegisterOperation(TEXT("Primitive::DisableUpdate"), &KhepriPrimitives::DisableUpdate);
  Server.RegisterOperation(TEXT("Primitive::EnableUpdate"), &KhepriPrimitives::EnableUpdate);

  // Selection
  Server.RegisterOperation(TEXT("Primitive::HighlightRefs"), &KhepriPrimitives::HighlightRefs);
  Server.RegisterOperation(TEXT("Primitive::UnhighlightRefs"), &KhepriPrimitives::UnhighlightRefs);
  Server.RegisterOperation(TEXT("Primitive::UnhighlightAllRefs"), &KhepriPrimitives::UnhighlightAllRefs);
}

// =============================================================================
// Helper: get the editor world
// =============================================================================

static UWorld* GetEditorWorld()
{
  if (GEditor)
  {
    return GEditor->GetEditorWorldContext().World();
  }
  return nullptr;
}

// =============================================================================
// Helper: get the active editor viewport client
// =============================================================================

static FEditorViewportClient* GetActiveViewportClient()
{
  if (!GEditor)
  {
    return nullptr;
  }
  // Use GetLevelViewportClients which returns properly-typed pointers.
  // GEditor->GetActiveViewport()->GetClient() returns a FCommonViewportClient
  // which is NOT necessarily an FEditorViewportClient — static_cast is unsafe.
  for (FLevelEditorViewportClient* LevelVC : GEditor->GetLevelViewportClients())
  {
    if (LevelVC && LevelVC->IsPerspective())
    {
      return LevelVC;
    }
  }
  // Fallback: any level viewport
  for (FLevelEditorViewportClient* LevelVC : GEditor->GetLevelViewportClients())
  {
    if (LevelVC)
    {
      return LevelVC;
    }
  }
  return nullptr;
}

// =============================================================================
// CreateMeshActor — core helper for spawning procedural mesh actors
// =============================================================================

int32 KhepriPrimitives::CreateMeshActor(
  FKhepriChannel& Channel,
  const KhepriMeshBuilder::FMeshData& MeshData,
  int32 MaterialIndex,
  const FVector& Location,
  const FRotator& Rotation,
  bool bCreateCollision,
  const TCHAR* ShapeLabel)
{
  UWorld* World = GetEditorWorld();
  if (!World)
  {
    UE_LOG(LogKhepri, Error, TEXT("Khepri: No editor world available"));
    return -1;
  }

  // Generate a unique name for this actor
  int32 ActorNum = GKhepriActorCounter++;
  FString ActorName = FString::Printf(TEXT("Khepri_%s_%d"), ShapeLabel, ActorNum);

  // Spawn a new actor
  FActorSpawnParameters SpawnParams;
  SpawnParams.Name = FName(*ActorName);
  SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
  AActor* NewActor = World->SpawnActor<AActor>(SpawnParams);
  if (!NewActor)
  {
    UE_LOG(LogKhepri, Error, TEXT("Khepri: Failed to spawn actor"));
    return -1;
  }

#if WITH_EDITOR
  NewActor->SetActorLabel(*ActorName);
#endif

  // Create the UProceduralMeshComponent as root
  UProceduralMeshComponent* ProcMesh = NewObject<UProceduralMeshComponent>(NewActor, TEXT("ProceduralMesh"));
  NewActor->SetRootComponent(ProcMesh);
  ProcMesh->RegisterComponent();

  // Set mesh data on section 0 using LinearColor variant
  TArray<FProcMeshTangent> EmptyTangents;
  TArray<FLinearColor> EmptyColors;
  ProcMesh->CreateMeshSection_LinearColor(
    0,
    MeshData.Vertices,
    MeshData.Triangles,
    MeshData.Normals,
    MeshData.UVs,
    EmptyColors,
    EmptyTangents,
    bCreateCollision
  );

  // Apply material
  UMaterialInterface* Material = nullptr;
  if (MaterialIndex >= 0)
  {
    Material = Channel.GetMaterial(MaterialIndex);
  }
  else if (Channel.CurrentMaterialIndex >= 0)
  {
    Material = Channel.GetMaterial(Channel.CurrentMaterialIndex);
  }

  if (Material)
  {
    ProcMesh->SetMaterial(0, Material);
  }

  // Attach to parent if one is set
  if (Channel.CurrentParentIndex >= 0)
  {
    AActor* ParentActor = Channel.GetActor(Channel.CurrentParentIndex);
    if (ParentActor)
    {
      NewActor->AttachToActor(ParentActor, FAttachmentTransformRules::KeepWorldTransform);
    }
  }

  // Set actor transform
  NewActor->SetActorLocation(Location);
  NewActor->SetActorRotation(Rotation);

  // Register and return index
  int32 Index = Channel.RegisterActor(NewActor);
  return Index;
}

// =============================================================================
// Shape Management
// =============================================================================

void KhepriPrimitives::DeleteAll(FKhepriChannel& Channel)
{
  const TArray<AActor*>& Actors = Channel.GetActorRegistry();
  for (AActor* Actor : Actors)
  {
    if (Actor && IsValid(Actor))
    {
      Actor->Destroy();
    }
  }
  Channel.ClearRegistries();
  GKhepriActorCounter = 0;
  Channel.WriteInt32(0);
}

void KhepriPrimitives::DeleteAllShapes(FKhepriChannel& Channel)
{
  Channel.ClearShapeActors();
  Channel.WriteInt32(0);
}

void KhepriPrimitives::DeleteMany(FKhepriChannel& Channel)
{
  TArray<int32> Indices = Channel.ReadInt32Array();
  for (int32 Idx : Indices)
  {
    AActor* Actor = Channel.GetActor(Idx);
    if (Actor && IsValid(Actor))
    {
      Actor->Destroy();
    }
  }
  Channel.WriteInt32(0);
}

void KhepriPrimitives::DeleteRef(FKhepriChannel& Channel)
{
  int32 Idx = Channel.ReadInt32();
  AActor* Actor = Channel.GetActor(Idx);
  if (Actor && IsValid(Actor))
  {
    Actor->Destroy();
  }
  Channel.WriteInt32(0);
}

// =============================================================================
// Tier 0: Curves
// =============================================================================

void KhepriPrimitives::Point(FKhepriChannel& Channel)
{
  FVector Position = Channel.ReadFVector();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildPointMarker(FVector::ZeroVector, 5.0f);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, Position, FRotator::ZeroRotator, false, TEXT("Point"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Line(FKhepriChannel& Channel)
{
  TArray<FVector> Pts = Channel.ReadFVectorArray();

  // Build tube mesh along the points
  // Translate points to local space relative to first point
  FVector Origin = Pts.Num() > 0 ? Pts[0] : FVector::ZeroVector;
  TArray<FVector> LocalPts;
  LocalPts.Reserve(Pts.Num());
  for (const FVector& P : Pts)
  {
    LocalPts.Add(P - Origin);
  }

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildTube(LocalPts, 2.0f);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, Origin, FRotator::ZeroRotator, false, TEXT("Line"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::ClosedLine(FKhepriChannel& Channel)
{
  TArray<FVector> Pts = Channel.ReadFVectorArray();

  // Close the polyline by appending the first point
  if (Pts.Num() > 0)
  {
    FVector First = Pts[0];
    Pts.Add(First);
  }

  FVector Origin = Pts.Num() > 0 ? Pts[0] : FVector::ZeroVector;
  TArray<FVector> LocalPts;
  LocalPts.Reserve(Pts.Num());
  for (const FVector& P : Pts)
  {
    LocalPts.Add(P - Origin);
  }

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildTube(LocalPts, 2.0f);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, Origin, FRotator::ZeroRotator, false, TEXT("ClosedLine"));
  Channel.WriteInt32(Index);
}

// =============================================================================
// Tier 1: Surfaces
// =============================================================================

void KhepriPrimitives::Triangle(FKhepriChannel& Channel)
{
  FVector P1 = Channel.ReadFVector();
  FVector P2 = Channel.ReadFVector();
  FVector P3 = Channel.ReadFVector();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildTriangle(P1, P2, P3);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, false, TEXT("Triangle"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Quad(FKhepriChannel& Channel)
{
  FVector P1 = Channel.ReadFVector();
  FVector P2 = Channel.ReadFVector();
  FVector P3 = Channel.ReadFVector();
  FVector P4 = Channel.ReadFVector();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildQuad(P1, P2, P3, P4);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, false, TEXT("Quad"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::NGon(FKhepriChannel& Channel)
{
  TArray<FVector> Pts = Channel.ReadFVectorArray();
  FVector Pivot = Channel.ReadFVector();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildNGon(Pts, Pivot);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, false, TEXT("NGon"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::QuadStrip(FKhepriChannel& Channel)
{
  TArray<FVector> Bottom = Channel.ReadFVectorArray();
  TArray<FVector> Top = Channel.ReadFVectorArray();
  int32 SmoothInt = Channel.ReadInt32();
  bool bSmooth = (SmoothInt != 0);

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildQuadStrip(Bottom, Top, bSmooth);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, false, TEXT("QuadStrip"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::SurfacePolygon(FKhepriChannel& Channel)
{
  TArray<FVector> Pts = Channel.ReadFVectorArray();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildSurfacePolygon(Pts);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, false, TEXT("SurfacePolygon"));
  Channel.WriteInt32(Index);
}

// =============================================================================
// Tier 2: Advanced Surfaces
// =============================================================================

void KhepriPrimitives::SurfaceGrid(FKhepriChannel& Channel)
{
  TArray<TArray<FVector>> Pts = Channel.ReadFVectorArrayArray();
  int32 ClosedUInt = Channel.ReadInt32();
  int32 ClosedVInt = Channel.ReadInt32();
  int32 SmoothInt = Channel.ReadInt32();
  bool bClosedU = (ClosedUInt != 0);
  bool bClosedV = (ClosedVInt != 0);
  bool bSmooth = (SmoothInt != 0);

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildSurfaceGrid(Pts, bClosedU, bClosedV, bSmooth);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, false, TEXT("SurfaceGrid"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::SurfaceMesh(FKhepriChannel& Channel)
{
  TArray<FVector> Vertices = Channel.ReadFVectorArray();
  TArray<TArray<int32>> Faces = Channel.ReadInt32ArrayArray();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildFromVertsFaces(Vertices, Faces);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, false, TEXT("SurfaceMesh"));
  Channel.WriteInt32(Index);
}

// =============================================================================
// Tier 3: Solids
// =============================================================================

void KhepriPrimitives::Sphere(FKhepriChannel& Channel)
{
  FVector Center = Channel.ReadFVector();
  float Radius = Channel.ReadFloat();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildSphere(Radius);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, Center, FRotator::ZeroRotator, true, TEXT("Sphere"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Box(FKhepriChannel& Channel)
{
  FVector Pos = Channel.ReadFVector();
  FVector Vx = Channel.ReadFVector();
  FVector Vy = Channel.ReadFVector();
  FVector Size = Channel.ReadFVector();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildBox(Size);

  // Compute rotation from Vx/Vy
  FVector Vz = FVector::CrossProduct(Vx, Vy).GetSafeNormal();
  Vx.Normalize();
  Vy.Normalize();
  FMatrix RotMatrix = FMatrix(Vx, Vy, Vz, FVector::ZeroVector);
  FRotator Rotation = RotMatrix.Rotator();

  int32 Index = CreateMeshActor(Channel, MeshData, -1, Pos, Rotation, true, TEXT("Box"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::RightCuboid(FKhepriChannel& Channel)
{
  FVector Pos = Channel.ReadFVector();
  FVector Vx = Channel.ReadFVector();
  FVector Vy = Channel.ReadFVector();
  float SX = Channel.ReadFloat();
  float SY = Channel.ReadFloat();
  float SZ = Channel.ReadFloat();
  float Angle = Channel.ReadFloat();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildBox(FVector(SX, SY, SZ));

  // Compute rotation from Vx/Vy, then apply additional angle rotation
  FVector Vz = FVector::CrossProduct(Vx, Vy).GetSafeNormal();
  Vx.Normalize();
  Vy.Normalize();
  FMatrix RotMatrix = FMatrix(Vx, Vy, Vz, FVector::ZeroVector);
  FRotator Rotation = RotMatrix.Rotator();
  // Apply angle around local Z axis
  FRotator AngleRotation(0.0f, 0.0f, FMath::RadiansToDegrees(Angle));
  Rotation = (FQuat(Rotation) * FQuat(AngleRotation)).Rotator();

  int32 Index = CreateMeshActor(Channel, MeshData, -1, Pos, Rotation, true, TEXT("RightCuboid"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Cylinder(FKhepriChannel& Channel)
{
  FVector Bottom = Channel.ReadFVector();
  float Radius = Channel.ReadFloat();
  FVector Top = Channel.ReadFVector();

  FVector Dir = Top - Bottom;
  float Height = Dir.Size();
  if (Height < KINDA_SMALL_NUMBER)
  {
    Height = KINDA_SMALL_NUMBER;
  }

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildCylinder(Radius, Height);

  // BuildCylinder generates mesh centered at origin (-Height/2 to +Height/2),
  // so place actor at midpoint between Bottom and Top
  FVector Midpoint = (Bottom + Top) * 0.5f;
  FVector DirNorm = Dir.GetSafeNormal();
  FRotator Rotation = FRotationMatrix::MakeFromZ(DirNorm).Rotator();

  int32 Index = CreateMeshActor(Channel, MeshData, -1, Midpoint, Rotation, true, TEXT("Cylinder"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::ConeFrustum(FKhepriChannel& Channel)
{
  FVector Base = Channel.ReadFVector();
  float BaseRadius = Channel.ReadFloat();
  FVector Top = Channel.ReadFVector();
  float TopRadius = Channel.ReadFloat();

  FVector Dir = Top - Base;
  float Height = Dir.Size();
  if (Height < KINDA_SMALL_NUMBER)
  {
    Height = KINDA_SMALL_NUMBER;
  }

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildConeFrustum(BaseRadius, TopRadius, Height);

  // BuildConeFrustum generates mesh centered at origin (-Height/2 to +Height/2),
  // so place actor at midpoint between Base and Top
  FVector Midpoint = (Base + Top) * 0.5f;
  FVector DirNorm = Dir.GetSafeNormal();
  FRotator Rotation = FRotationMatrix::MakeFromZ(DirNorm).Rotator();

  int32 Index = CreateMeshActor(Channel, MeshData, -1, Midpoint, Rotation, true, TEXT("ConeFrustum"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Torus(FKhepriChannel& Channel)
{
  FVector Center = Channel.ReadFVector();
  float MajorR = Channel.ReadFloat();
  float MinorR = Channel.ReadFloat();
  FVector Normal = Channel.ReadFVector();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildTorus(MajorR, MinorR);

  // Compute rotation from Normal - the torus lies in the plane perpendicular to Normal
  FRotator Rotation = FRotationMatrix::MakeFromZ(Normal.GetSafeNormal()).Rotator();

  int32 Index = CreateMeshActor(Channel, MeshData, -1, Center, Rotation, true, TEXT("Torus"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Pyramid(FKhepriChannel& Channel)
{
  TArray<FVector> Base = Channel.ReadFVectorArray();
  FVector Apex = Channel.ReadFVector();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildPyramid(Base, Apex);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, true, TEXT("Pyramid"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::PyramidFrustum(FKhepriChannel& Channel)
{
  TArray<FVector> Base = Channel.ReadFVectorArray();
  TArray<FVector> Top = Channel.ReadFVectorArray();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildPyramidFrustum(Base, Top);
  int32 Index = CreateMeshActor(Channel, MeshData, -1, FVector::ZeroVector, FRotator::ZeroRotator, true, TEXT("PyramidFrustum"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::PyramidFrustumWithMaterial(FKhepriChannel& Channel)
{
  TArray<FVector> Base = Channel.ReadFVectorArray();
  TArray<FVector> Top = Channel.ReadFVectorArray();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildPyramidFrustum(Base, Top);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, true, TEXT("PyramidFrustum"));
  Channel.WriteInt32(Index);
}

// =============================================================================
// BIM Elements
// =============================================================================

void KhepriPrimitives::Slab(FKhepriChannel& Channel)
{
  TArray<FVector> Contour = Channel.ReadFVectorArray();
  TArray<TArray<FVector>> Holes = Channel.ReadFVectorArrayArray();
  float Height = Channel.ReadFloat();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildSlab(Contour, Holes, Height);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, true, TEXT("Slab"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Panel(FKhepriChannel& Channel)
{
  TArray<FVector> Pts = Channel.ReadFVectorArray();
  FVector Normal = Channel.ReadFVector();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildPanel(Pts, Normal);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, true, TEXT("Panel"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::BeamRectSection(FKhepriChannel& Channel)
{
  FVector Pos = Channel.ReadFVector();
  FVector Vx = Channel.ReadFVector();
  FVector Vy = Channel.ReadFVector();
  float DX = Channel.ReadFloat();
  float DY = Channel.ReadFloat();
  float DZ = Channel.ReadFloat();
  float Angle = Channel.ReadFloat();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildBox(FVector(DX, DY, DZ));

  // Compute rotation from Vx/Vy, then apply angle
  FVector Vz = FVector::CrossProduct(Vx, Vy).GetSafeNormal();
  Vx.Normalize();
  Vy.Normalize();
  FMatrix RotMatrix = FMatrix(Vx, Vy, Vz, FVector::ZeroVector);
  FRotator Rotation = RotMatrix.Rotator();
  FRotator AngleRotation(0.0f, 0.0f, FMath::RadiansToDegrees(Angle));
  Rotation = (FQuat(Rotation) * FQuat(AngleRotation)).Rotator();

  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, Pos, Rotation, true, TEXT("BeamRect"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::BeamCircSection(FKhepriChannel& Channel)
{
  FVector Bot = Channel.ReadFVector();
  float Radius = Channel.ReadFloat();
  FVector Top = Channel.ReadFVector();
  int32 MatIndex = Channel.ReadInt32();

  FVector Dir = Top - Bot;
  float Height = Dir.Size();
  if (Height < KINDA_SMALL_NUMBER)
  {
    Height = KINDA_SMALL_NUMBER;
  }

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildCylinder(Radius, Height);

  // BuildCylinder generates mesh centered at origin, place at midpoint
  FVector Midpoint = (Bot + Top) * 0.5f;
  FVector DirNorm = Dir.GetSafeNormal();
  FRotator Rotation = FRotationMatrix::MakeFromZ(DirNorm).Rotator();

  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, Midpoint, Rotation, true, TEXT("BeamCirc"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::InstantiateBIMElement(FKhepriChannel& Channel)
{
  int32 MeshIndex = Channel.ReadInt32();
  FVector Position = Channel.ReadFVector();
  float Angle = Channel.ReadFloat();

  UWorld* World = GetEditorWorld();
  if (!World)
  {
    Channel.WriteInt32(-1);
    return;
  }

  UStaticMesh* Mesh = Channel.GetMesh(MeshIndex);
  if (!Mesh)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: InstantiateBIMElement - invalid mesh index %d"), MeshIndex);
    Channel.WriteInt32(-1);
    return;
  }

  FString ActorName = FString::Printf(TEXT("Khepri_BIMElement_%d"), GKhepriActorCounter++);
  FActorSpawnParameters SpawnParams;
  SpawnParams.Name = FName(*ActorName);
  SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
  AActor* NewActor = World->SpawnActor<AActor>(SpawnParams);
  if (!NewActor)
  {
    Channel.WriteInt32(-1);
    return;
  }

#if WITH_EDITOR
  NewActor->SetActorLabel(*ActorName);
#endif

  UStaticMeshComponent* MeshComp = NewObject<UStaticMeshComponent>(NewActor, TEXT("StaticMesh"));
  NewActor->SetRootComponent(MeshComp);
  MeshComp->RegisterComponent();
  MeshComp->SetStaticMesh(Mesh);

  // Apply rotation (angle around Z in radians)
  FRotator Rotation(0.0f, FMath::RadiansToDegrees(Angle), 0.0f);
  NewActor->SetActorLocationAndRotation(Position, Rotation);

  // Attach to parent if set
  if (Channel.CurrentParentIndex >= 0)
  {
    AActor* ParentActor = Channel.GetActor(Channel.CurrentParentIndex);
    if (ParentActor)
    {
      NewActor->AttachToActor(ParentActor, FAttachmentTransformRules::KeepWorldTransform);
    }
  }

  // Apply current material if set
  if (Channel.CurrentMaterialIndex >= 0)
  {
    UMaterialInterface* Material = Channel.GetMaterial(Channel.CurrentMaterialIndex);
    if (Material)
    {
      MeshComp->SetMaterial(0, Material);
    }
  }

  int32 Index = Channel.RegisterActor(NewActor);
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::CreateBlockInstance(FKhepriChannel& Channel)
{
  int32 MeshIndex = Channel.ReadInt32();
  FVector Position = Channel.ReadFVector();
  FVector Vx = Channel.ReadFVector();
  FVector Vy = Channel.ReadFVector();
  float Scale = Channel.ReadFloat();

  UWorld* World = GetEditorWorld();
  if (!World)
  {
    Channel.WriteInt32(-1);
    return;
  }

  UStaticMesh* Mesh = Channel.GetMesh(MeshIndex);
  if (!Mesh)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: CreateBlockInstance - invalid mesh index %d"), MeshIndex);
    Channel.WriteInt32(-1);
    return;
  }

  FString ActorName = FString::Printf(TEXT("Khepri_BlockInstance_%d"), GKhepriActorCounter++);
  FActorSpawnParameters SpawnParams;
  SpawnParams.Name = FName(*ActorName);
  SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
  AActor* NewActor = World->SpawnActor<AActor>(SpawnParams);
  if (!NewActor)
  {
    Channel.WriteInt32(-1);
    return;
  }

#if WITH_EDITOR
  NewActor->SetActorLabel(*ActorName);
#endif

  UStaticMeshComponent* MeshComp = NewObject<UStaticMeshComponent>(NewActor, TEXT("StaticMesh"));
  NewActor->SetRootComponent(MeshComp);
  MeshComp->RegisterComponent();
  MeshComp->SetStaticMesh(Mesh);

  // Compute rotation from Vx/Vy orientation
  Vx.Normalize();
  Vy.Normalize();
  FVector Vz = FVector::CrossProduct(Vx, Vy).GetSafeNormal();
  FMatrix RotMatrix = FMatrix(Vx, Vy, Vz, FVector::ZeroVector);
  FRotator Rotation = RotMatrix.Rotator();

  NewActor->SetActorLocationAndRotation(Position, Rotation);
  NewActor->SetActorScale3D(FVector(Scale));

  // Attach to parent if set
  if (Channel.CurrentParentIndex >= 0)
  {
    AActor* ParentActor = Channel.GetActor(Channel.CurrentParentIndex);
    if (ParentActor)
    {
      NewActor->AttachToActor(ParentActor, FAttachmentTransformRules::KeepWorldTransform);
    }
  }

  // Apply current material if set
  if (Channel.CurrentMaterialIndex >= 0)
  {
    UMaterialInterface* Material = Channel.GetMaterial(Channel.CurrentMaterialIndex);
    if (Material)
    {
      MeshComp->SetMaterial(0, Material);
    }
  }

  int32 Index = Channel.RegisterActor(NewActor);
  Channel.WriteInt32(Index);
}

// =============================================================================
// Materials & Layers
// =============================================================================

void KhepriPrimitives::LoadMaterial(FKhepriChannel& Channel)
{
  FString Path = Channel.ReadString();

  UMaterialInterface* Material = LoadObject<UMaterialInterface>(nullptr, *Path);
  if (!Material)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: LoadMaterial - failed to load '%s'"), *Path);
    Channel.WriteInt32(-1);
    return;
  }

  int32 Index = Channel.RegisterMaterial(Material);
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::CreateMaterial(FKhepriChannel& Channel)
{
  float R = Channel.ReadFloat();
  float G = Channel.ReadFloat();
  float B = Channel.ReadFloat();
  float A = Channel.ReadFloat();
  float Metallic = Channel.ReadFloat();
  float Specular = Channel.ReadFloat();
  float Roughness = Channel.ReadFloat();
  float EmissiveR = Channel.ReadFloat();
  float EmissiveG = Channel.ReadFloat();
  float EmissiveB = Channel.ReadFloat();
  float EmissionStrength = Channel.ReadFloat();

  UMaterial* BaseMaterial = GetOrCreateBaseMaterial();
  if (!BaseMaterial)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: CreateMaterial - failed to create base material"));
    Channel.WriteInt32(-1);
    return;
  }

  UWorld* World = GetEditorWorld();
  UMaterialInstanceDynamic* DynMat = UMaterialInstanceDynamic::Create(BaseMaterial, World);
  if (!DynMat)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: CreateMaterial - failed to create dynamic material instance"));
    Channel.WriteInt32(-1);
    return;
  }

  DynMat->SetVectorParameterValue(TEXT("BaseColor"), FLinearColor(R, G, B, A));
  DynMat->SetScalarParameterValue(TEXT("Metallic"), Metallic);
  DynMat->SetScalarParameterValue(TEXT("Specular"), Specular);
  DynMat->SetScalarParameterValue(TEXT("Roughness"), Roughness);
  DynMat->SetScalarParameterValue(TEXT("Opacity"), A);
  DynMat->SetVectorParameterValue(TEXT("EmissiveColor"), FLinearColor(EmissiveR, EmissiveG, EmissiveB, 1.0f));
  DynMat->SetScalarParameterValue(TEXT("EmissionStrength"), EmissionStrength);

  // Prevent garbage collection
  DynMat->AddToRoot();

  int32 Index = Channel.RegisterMaterial(DynMat);
  UE_LOG(LogKhepri, Verbose, TEXT("Khepri: CreateMaterial - RGBA(%.2f,%.2f,%.2f,%.2f) Metallic=%.2f Specular=%.2f Roughness=%.2f Emissive=(%.2f,%.2f,%.2f)*%.2f -> index %d"),
    R, G, B, A, Metallic, Specular, Roughness, EmissiveR, EmissiveG, EmissiveB, EmissionStrength, Index);
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::CurrentMaterial(FKhepriChannel& Channel)
{
  Channel.WriteInt32(Channel.CurrentMaterialIndex);
}

void KhepriPrimitives::SetCurrentMaterial(FKhepriChannel& Channel)
{
  int32 MatIndex = Channel.ReadInt32();
  Channel.CurrentMaterialIndex = MatIndex;
  Channel.WriteInt32(0);
}

void KhepriPrimitives::CurrentParent(FKhepriChannel& Channel)
{
  Channel.WriteInt32(Channel.CurrentParentIndex);
}

void KhepriPrimitives::SetCurrentParent(FKhepriChannel& Channel)
{
  int32 ParentIndex = Channel.ReadInt32();
  Channel.CurrentParentIndex = ParentIndex;
  Channel.WriteInt32(0);
}

void KhepriPrimitives::CreateParent(FKhepriChannel& Channel)
{
  FString Name = Channel.ReadString();

  UWorld* World = GetEditorWorld();
  if (!World)
  {
    Channel.WriteInt32(-1);
    return;
  }

  FActorSpawnParameters SpawnParams;
  SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
  AActor* ParentActor = World->SpawnActor<AActor>(SpawnParams);
  if (ParentActor)
  {
    ParentActor->SetActorLabel(*Name);
  }

  int32 Index = Channel.RegisterActor(ParentActor);
  Channel.ParentIndices.Add(Index);
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::LoadResource(FKhepriChannel& Channel)
{
  FString Name = Channel.ReadString();

  UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, *Name);
  if (!Mesh)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: LoadResource - failed to load '%s'"), *Name);
    Channel.WriteInt32(-1);
    return;
  }

  int32 Index = Channel.RegisterMesh(Mesh);
  Channel.WriteInt32(Index);
}

// =============================================================================
// Lighting
// =============================================================================

void KhepriPrimitives::PointLight(FKhepriChannel& Channel)
{
  FVector Position = Channel.ReadFVector();
  FLinearColor Color = Channel.ReadFLinearColor();
  float Range = Channel.ReadFloat();
  float Intensity = Channel.ReadFloat();

  UWorld* World = GetEditorWorld();
  if (!World)
  {
    Channel.WriteInt32(-1);
    return;
  }

  FString ActorName = FString::Printf(TEXT("Khepri_PointLight_%d"), GKhepriActorCounter++);
  FActorSpawnParameters SpawnParams;
  SpawnParams.Name = FName(*ActorName);
  SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
  AActor* LightActor = World->SpawnActor<AActor>(SpawnParams);
  if (!LightActor)
  {
    Channel.WriteInt32(-1);
    return;
  }

#if WITH_EDITOR
  LightActor->SetActorLabel(*ActorName);
#endif

  UPointLightComponent* LightComp = NewObject<UPointLightComponent>(LightActor, TEXT("PointLight"));
  LightActor->SetRootComponent(LightComp);
  LightComp->RegisterComponent();

  LightComp->SetLightColor(Color);
  LightComp->SetAttenuationRadius(Range);
  LightComp->SetIntensity(Intensity);

  LightActor->SetActorLocation(Position);

  // Attach to parent if set
  if (Channel.CurrentParentIndex >= 0)
  {
    AActor* ParentActor = Channel.GetActor(Channel.CurrentParentIndex);
    if (ParentActor)
    {
      LightActor->AttachToActor(ParentActor, FAttachmentTransformRules::KeepWorldTransform);
    }
  }

  int32 Index = Channel.RegisterActor(LightActor);
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Spotlight(FKhepriChannel& Channel)
{
  FVector Position = Channel.ReadFVector();
  FVector Dir = Channel.ReadFVector();
  FLinearColor Color = Channel.ReadFLinearColor();
  float Range = Channel.ReadFloat();
  float Intensity = Channel.ReadFloat();
  float Hotspot = Channel.ReadFloat();
  float Falloff = Channel.ReadFloat();

  UWorld* World = GetEditorWorld();
  if (!World)
  {
    Channel.WriteInt32(-1);
    return;
  }

  FString SpotActorName = FString::Printf(TEXT("Khepri_Spotlight_%d"), GKhepriActorCounter++);
  FActorSpawnParameters SpawnParams;
  SpawnParams.Name = FName(*SpotActorName);
  SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
  AActor* LightActor = World->SpawnActor<AActor>(SpawnParams);
  if (!LightActor)
  {
    Channel.WriteInt32(-1);
    return;
  }

#if WITH_EDITOR
  LightActor->SetActorLabel(*SpotActorName);
#endif

  USpotLightComponent* SpotComp = NewObject<USpotLightComponent>(LightActor, TEXT("SpotLight"));
  LightActor->SetRootComponent(SpotComp);
  SpotComp->RegisterComponent();

  SpotComp->SetLightColor(Color);
  SpotComp->SetAttenuationRadius(Range);
  SpotComp->SetIntensity(Intensity);
  SpotComp->SetInnerConeAngle(FMath::RadiansToDegrees(Hotspot));
  SpotComp->SetOuterConeAngle(FMath::RadiansToDegrees(Falloff));

  // Set location and direction
  FRotator Rotation = Dir.GetSafeNormal().Rotation();
  LightActor->SetActorLocationAndRotation(Position, Rotation);

  // Attach to parent if set
  if (Channel.CurrentParentIndex >= 0)
  {
    AActor* ParentActor = Channel.GetActor(Channel.CurrentParentIndex);
    if (ParentActor)
    {
      LightActor->AttachToActor(ParentActor, FAttachmentTransformRules::KeepWorldTransform);
    }
  }

  int32 Index = Channel.RegisterActor(LightActor);
  Channel.WriteInt32(Index);
}

// =============================================================================
// Boolean Operations (CSG stubs - not fully supported in UE5 procedural context)
// =============================================================================

void KhepriPrimitives::Unite(FKhepriChannel& Channel)
{
  int32 Idx1 = Channel.ReadInt32();
  int32 Idx2 = Channel.ReadInt32();

  UE_LOG(LogKhepri, Warning, TEXT("Khepri: Unite - CSG boolean operations are not fully supported; returning first operand"));
  Channel.WriteInt32(Idx1);
}

void KhepriPrimitives::Subtract(FKhepriChannel& Channel)
{
  int32 Idx1 = Channel.ReadInt32();
  int32 Idx2 = Channel.ReadInt32();

  UE_LOG(LogKhepri, Warning, TEXT("Khepri: Subtract - CSG boolean operations are not fully supported; returning first operand"));
  Channel.WriteInt32(Idx1);
}

void KhepriPrimitives::Intersect(FKhepriChannel& Channel)
{
  int32 Idx1 = Channel.ReadInt32();
  int32 Idx2 = Channel.ReadInt32();

  UE_LOG(LogKhepri, Warning, TEXT("Khepri: Intersect - CSG boolean operations are not fully supported; returning first operand"));
  Channel.WriteInt32(Idx1);
}

// =============================================================================
// View & Rendering
// =============================================================================

void KhepriPrimitives::SetView(FKhepriChannel& Channel)
{
  FVector Position = Channel.ReadFVector();
  FVector Target = Channel.ReadFVector();
  float Lens = Channel.ReadFloat();
  float Aperture = Channel.ReadFloat();

  FEditorViewportClient* ViewportClient = GetActiveViewportClient();
  if (ViewportClient)
  {
    ViewportClient->SetViewLocation(Position);

    FVector Direction = (Target - Position).GetSafeNormal();
    FRotator LookAtRotation = Direction.Rotation();
    ViewportClient->SetViewRotation(LookAtRotation);

    if (Lens > 0.0f)
    {
      float FOV = FMath::RadiansToDegrees(2.0f * FMath::Atan(36.0f / (2.0f * Lens)));
      ViewportClient->ViewFOV = FOV;
    }
  }
  else
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: SetView - no viewport client"));
  }

  Channel.WriteInt32(0);
}

void KhepriPrimitives::ViewCamera(FKhepriChannel& Channel)
{
  FVector CameraLocation = FVector::ZeroVector;

  FEditorViewportClient* ViewportClient = GetActiveViewportClient();
  if (ViewportClient)
  {
    CameraLocation = ViewportClient->GetViewLocation();
  }

  Channel.WriteFVector(CameraLocation);
}

void KhepriPrimitives::ViewTarget(FKhepriChannel& Channel)
{
  FVector TargetLocation = FVector::ForwardVector;

  FEditorViewportClient* ViewportClient = GetActiveViewportClient();
  if (ViewportClient)
  {
    // Target = position + forward direction
    FVector Location = ViewportClient->GetViewLocation();
    FRotator Rotation = ViewportClient->GetViewRotation();
    FVector Forward = Rotation.Vector();
    // Project target along forward direction at a reasonable distance
    TargetLocation = Location + Forward * 1000.0f;
  }

  Channel.WriteFVector(TargetLocation);
}

void KhepriPrimitives::ViewLens(FKhepriChannel& Channel)
{
  float Lens = 50.0f; // default 50mm

  FEditorViewportClient* ViewportClient = GetActiveViewportClient();
  if (ViewportClient)
  {
    // Convert FOV back to focal length: focal_length = sensor_width / (2 * tan(fov/2))
    float FOV = ViewportClient->ViewFOV;
    if (FOV > 0.0f)
    {
      Lens = 36.0f / (2.0f * FMath::Tan(FMath::DegreesToRadians(FOV / 2.0f)));
    }
  }

  Channel.WriteFloat(Lens);
}

void KhepriPrimitives::RenderView(FKhepriChannel& Channel)
{
  int32 Width = Channel.ReadInt32();
  int32 Height = Channel.ReadInt32();
  FString Name = Channel.ReadString();
  FString Path = Channel.ReadString();
  int32 Frame = Channel.ReadInt32();

  // Construct full file path
  FString FullPath = FPaths::Combine(Path, Name);
  if (!FullPath.EndsWith(TEXT(".png")))
  {
    FullPath += TEXT(".png");
  }

  // Ensure output directory exists
  FString Directory = FPaths::GetPath(FullPath);
  if (!Directory.IsEmpty())
  {
    IPlatformFile& PlatformFile = FPlatformFileManager::Get().GetPlatformFile();
    PlatformFile.CreateDirectoryTree(*Directory);
  }

  bool bSuccess = false;
  if (GEditor)
  {
    FEditorViewportClient* ViewportClient = GetActiveViewportClient();
    FViewport* Viewport = ViewportClient ? ViewportClient->Viewport : nullptr;
    if (Viewport)
    {
      // Configure and request high-res screenshot
      FHighResScreenshotConfig& ScreenshotConfig = GetHighResScreenshotConfig();
      ScreenshotConfig.SetResolution(Width, Height, 1.0f);
      ScreenshotConfig.FilenameOverride = FullPath;
      ScreenshotConfig.bMaskEnabled = false;
      GScreenshotResolutionX = Width;
      GScreenshotResolutionY = Height;

      Viewport->TakeHighResScreenShot();
      bSuccess = true;
      UE_LOG(LogKhepri, Log, TEXT("Khepri: RenderView - screenshot requested to %s (%dx%d)"), *FullPath, Width, Height);
    }
    else
    {
      UE_LOG(LogKhepri, Warning, TEXT("Khepri: RenderView - no active viewport"));
    }
  }
  else
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: RenderView - no editor"));
  }

  Channel.WriteInt32(bSuccess ? 0 : -1);
}

void KhepriPrimitives::ZoomExtents(FKhepriChannel& Channel)
{
  FEditorViewportClient* ViewportClient = GetActiveViewportClient();
  if (ViewportClient)
  {
    {
      GEditor->Exec(ViewportClient->GetWorld(), TEXT("CAMERA ALIGN"));
      UE_LOG(LogKhepri, Log, TEXT("Khepri: ZoomExtents - focused viewport on scene"));
    }
  }
  else
  {
    {
      UE_LOG(LogKhepri, Warning, TEXT("Khepri: ZoomExtents - no active viewport"));
    }
  }

  Channel.WriteInt32(0);
}

void KhepriPrimitives::ViewSize(FKhepriChannel& Channel)
{
  int32 Width = Channel.ReadInt32();
  int32 Height = Channel.ReadInt32();

  TSharedPtr<SWindow> MainWindow = FSlateApplication::Get().GetActiveTopLevelWindow();
  if (MainWindow.IsValid())
  {
    MainWindow->Resize(FVector2D(Width, Height));
    UE_LOG(LogKhepri, Log, TEXT("Khepri: ViewSize - resized to %dx%d"), Width, Height);
  }
  else
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: ViewSize - no active top-level window"));
  }

  Channel.WriteInt32(0);
}

// =============================================================================
// Bounding Box
// =============================================================================

void KhepriPrimitives::BoundingBoxMin(FKhepriChannel& Channel)
{
  int32 Idx = Channel.ReadInt32();
  FVector Min = FVector::ZeroVector;

  AActor* Actor = Channel.GetActor(Idx);
  if (Actor && IsValid(Actor))
  {
    FBox BoundingBox = Actor->GetComponentsBoundingBox(true);
    Min = BoundingBox.Min;
  }

  Channel.WriteFVector(Min);
}

void KhepriPrimitives::BoundingBoxMax(FKhepriChannel& Channel)
{
  int32 Idx = Channel.ReadInt32();
  FVector Max = FVector::ZeroVector;

  AActor* Actor = Channel.GetActor(Idx);
  if (Actor && IsValid(Actor))
  {
    FBox BoundingBox = Actor->GetComponentsBoundingBox(true);
    Max = BoundingBox.Max;
  }

  Channel.WriteFVector(Max);
}

// =============================================================================
// Batch Processing
// =============================================================================

void KhepriPrimitives::DisableUpdate(FKhepriChannel& Channel)
{
  // Batch processing hint - no-op for now
  Channel.WriteInt32(0);
}

void KhepriPrimitives::EnableUpdate(FKhepriChannel& Channel)
{
  // Batch processing hint - no-op for now
  Channel.WriteInt32(0);
}

// =============================================================================
// Selection (Editor Highlighting)
// =============================================================================

void KhepriPrimitives::HighlightRefs(FKhepriChannel& Channel)
{
  TArray<int32> Indices = Channel.ReadInt32Array();

  if (GEditor)
  {
    USelection* Selection = GEditor->GetSelectedActors();
    if (Selection)
    {
      for (int32 Idx : Indices)
      {
        AActor* Actor = Channel.GetActor(Idx);
        if (Actor && IsValid(Actor))
        {
          GEditor->SelectActor(Actor, true, true, true);
        }
      }
    }
  }

  Channel.WriteInt32(0);
}

void KhepriPrimitives::UnhighlightRefs(FKhepriChannel& Channel)
{
  TArray<int32> Indices = Channel.ReadInt32Array();

  if (GEditor)
  {
    for (int32 Idx : Indices)
    {
      AActor* Actor = Channel.GetActor(Idx);
      if (Actor && IsValid(Actor))
      {
        GEditor->SelectActor(Actor, false, true, true);
      }
    }
  }

  Channel.WriteInt32(0);
}

void KhepriPrimitives::UnhighlightAllRefs(FKhepriChannel& Channel)
{
  if (GEditor)
  {
    GEditor->SelectNone(true, true, false);
  }

  Channel.WriteInt32(0);
}
