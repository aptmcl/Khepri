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
#include "Engine/Light.h"
#include "Engine/Brush.h"
#include "GameFramework/WorldSettings.h"
#include "Framework/Application/SlateApplication.h"
#include "Widgets/SWindow.h"

// Deferred selection state
bool KhepriPrimitives::bSelectionPending = false;
bool KhepriPrimitives::bSelectMany = false;

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
// Static translucent base material (for transmission/alpha < 1)
// =============================================================================

static UMaterial* GKhepriTranslucentMaterial = nullptr;

static UMaterial* GetOrCreateTranslucentBaseMaterial()
{
  if (GKhepriTranslucentMaterial && GKhepriTranslucentMaterial->IsValidLowLevel())
  {
    return GKhepriTranslucentMaterial;
  }

  UMaterial* Mat = NewObject<UMaterial>(GetTransientPackage(), TEXT("M_KhepriTranslucent"));

  auto* BaseColorParam = NewObject<UMaterialExpressionVectorParameter>(Mat);
  BaseColorParam->ParameterName = TEXT("BaseColor");
  BaseColorParam->DefaultValue = FLinearColor(0.8f, 0.8f, 0.8f, 1.0f);

  auto* MetallicParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  MetallicParam->ParameterName = TEXT("Metallic");
  MetallicParam->DefaultValue = 0.0f;

  auto* SpecularParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  SpecularParam->ParameterName = TEXT("Specular");
  SpecularParam->DefaultValue = 0.5f;

  auto* RoughnessParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  RoughnessParam->ParameterName = TEXT("Roughness");
  RoughnessParam->DefaultValue = 0.5f;

  auto* OpacityParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  OpacityParam->ParameterName = TEXT("Opacity");
  OpacityParam->DefaultValue = 0.5f;

  auto* EmissiveColorParam = NewObject<UMaterialExpressionVectorParameter>(Mat);
  EmissiveColorParam->ParameterName = TEXT("EmissiveColor");
  EmissiveColorParam->DefaultValue = FLinearColor(0.0f, 0.0f, 0.0f, 1.0f);

  auto* EmissionStrengthParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  EmissionStrengthParam->ParameterName = TEXT("EmissionStrength");
  EmissionStrengthParam->DefaultValue = 0.0f;

  auto* RefractionParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  RefractionParam->ParameterName = TEXT("Refraction");
  RefractionParam->DefaultValue = 1.5f;

  auto* EmissiveMultiply = NewObject<UMaterialExpressionMultiply>(Mat);

  Mat->GetExpressionCollection().Expressions.Add(BaseColorParam);
  Mat->GetExpressionCollection().Expressions.Add(MetallicParam);
  Mat->GetExpressionCollection().Expressions.Add(SpecularParam);
  Mat->GetExpressionCollection().Expressions.Add(RoughnessParam);
  Mat->GetExpressionCollection().Expressions.Add(OpacityParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissiveColorParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissionStrengthParam);
  Mat->GetExpressionCollection().Expressions.Add(RefractionParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissiveMultiply);

#if WITH_EDITORONLY_DATA
  UMaterialEditorOnlyData* EditorData = Mat->GetEditorOnlyData();
  EditorData->BaseColor.Expression = BaseColorParam;
  EditorData->Metallic.Expression = MetallicParam;
  EditorData->Specular.Expression = SpecularParam;
  EditorData->Roughness.Expression = RoughnessParam;
  EditorData->Opacity.Expression = OpacityParam;
  EmissiveMultiply->A.Expression = EmissiveColorParam;
  EmissiveMultiply->B.Expression = EmissionStrengthParam;
  EditorData->EmissiveColor.Expression = EmissiveMultiply;
  EditorData->Refraction.Expression = RefractionParam;
#endif

  Mat->BlendMode = BLEND_Translucent;
  Mat->TwoSided = true;

  Mat->PreEditChange(nullptr);
  Mat->PostEditChange();
  Mat->AddToRoot();
  GKhepriTranslucentMaterial = Mat;

  UE_LOG(LogKhepri, Log, TEXT("Created KhepriTranslucentMaterial"));
  return GKhepriTranslucentMaterial;
}

// =============================================================================
// Static clear coat base material
// =============================================================================

static UMaterial* GKhepriClearCoatMaterial = nullptr;

static UMaterial* GetOrCreateClearCoatBaseMaterial()
{
  if (GKhepriClearCoatMaterial && GKhepriClearCoatMaterial->IsValidLowLevel())
  {
    return GKhepriClearCoatMaterial;
  }

  UMaterial* Mat = NewObject<UMaterial>(GetTransientPackage(), TEXT("M_KhepriClearCoat"));

  auto* BaseColorParam = NewObject<UMaterialExpressionVectorParameter>(Mat);
  BaseColorParam->ParameterName = TEXT("BaseColor");
  BaseColorParam->DefaultValue = FLinearColor(0.8f, 0.8f, 0.8f, 1.0f);

  auto* MetallicParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  MetallicParam->ParameterName = TEXT("Metallic");
  MetallicParam->DefaultValue = 0.0f;

  auto* SpecularParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  SpecularParam->ParameterName = TEXT("Specular");
  SpecularParam->DefaultValue = 0.5f;

  auto* RoughnessParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  RoughnessParam->ParameterName = TEXT("Roughness");
  RoughnessParam->DefaultValue = 0.5f;

  auto* OpacityParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  OpacityParam->ParameterName = TEXT("Opacity");
  OpacityParam->DefaultValue = 1.0f;

  auto* EmissiveColorParam = NewObject<UMaterialExpressionVectorParameter>(Mat);
  EmissiveColorParam->ParameterName = TEXT("EmissiveColor");
  EmissiveColorParam->DefaultValue = FLinearColor(0.0f, 0.0f, 0.0f, 1.0f);

  auto* EmissionStrengthParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  EmissionStrengthParam->ParameterName = TEXT("EmissionStrength");
  EmissionStrengthParam->DefaultValue = 0.0f;

  auto* ClearCoatParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  ClearCoatParam->ParameterName = TEXT("ClearCoat");
  ClearCoatParam->DefaultValue = 1.0f;

  auto* ClearCoatRoughnessParam = NewObject<UMaterialExpressionScalarParameter>(Mat);
  ClearCoatRoughnessParam->ParameterName = TEXT("ClearCoatRoughness");
  ClearCoatRoughnessParam->DefaultValue = 0.1f;

  auto* EmissiveMultiply = NewObject<UMaterialExpressionMultiply>(Mat);

  Mat->GetExpressionCollection().Expressions.Add(BaseColorParam);
  Mat->GetExpressionCollection().Expressions.Add(MetallicParam);
  Mat->GetExpressionCollection().Expressions.Add(SpecularParam);
  Mat->GetExpressionCollection().Expressions.Add(RoughnessParam);
  Mat->GetExpressionCollection().Expressions.Add(OpacityParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissiveColorParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissionStrengthParam);
  Mat->GetExpressionCollection().Expressions.Add(ClearCoatParam);
  Mat->GetExpressionCollection().Expressions.Add(ClearCoatRoughnessParam);
  Mat->GetExpressionCollection().Expressions.Add(EmissiveMultiply);

#if WITH_EDITORONLY_DATA
  UMaterialEditorOnlyData* EditorData = Mat->GetEditorOnlyData();
  EditorData->BaseColor.Expression = BaseColorParam;
  EditorData->Metallic.Expression = MetallicParam;
  EditorData->Specular.Expression = SpecularParam;
  EditorData->Roughness.Expression = RoughnessParam;
  EditorData->Opacity.Expression = OpacityParam;
  EmissiveMultiply->A.Expression = EmissiveColorParam;
  EmissiveMultiply->B.Expression = EmissionStrengthParam;
  EditorData->EmissiveColor.Expression = EmissiveMultiply;
  EditorData->ClearCoat.Expression = ClearCoatParam;
  EditorData->ClearCoatRoughness.Expression = ClearCoatRoughnessParam;
#endif

  Mat->SetShadingModel(MSM_ClearCoat);
  Mat->TwoSided = true;

  Mat->PreEditChange(nullptr);
  Mat->PostEditChange();
  Mat->AddToRoot();
  GKhepriClearCoatMaterial = Mat;

  UE_LOG(LogKhepri, Log, TEXT("Created KhepriClearCoatMaterial"));
  return GKhepriClearCoatMaterial;
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
  Server.RegisterOperation(TEXT("Primitive::CreatePBRMaterial"), &KhepriPrimitives::CreatePBRMaterial);
  Server.RegisterOperation(TEXT("Primitive::CurrentMaterial"), &KhepriPrimitives::CurrentMaterial);
  Server.RegisterOperation(TEXT("Primitive::SetCurrentMaterial"), &KhepriPrimitives::SetCurrentMaterial);
  Server.RegisterOperation(TEXT("Primitive::CurrentParent"), &KhepriPrimitives::CurrentParent);
  Server.RegisterOperation(TEXT("Primitive::SetCurrentParent"), &KhepriPrimitives::SetCurrentParent);
  Server.RegisterOperation(TEXT("Primitive::CreateParent"), &KhepriPrimitives::CreateParent);
  Server.RegisterOperation(TEXT("Primitive::SetParentVisible"), &KhepriPrimitives::SetParentVisible);
  Server.RegisterOperation(TEXT("Primitive::SetParentOpacity"), &KhepriPrimitives::SetParentOpacity);
  Server.RegisterOperation(TEXT("Primitive::DeleteAllInParent"), &KhepriPrimitives::DeleteAllInParent);
  Server.RegisterOperation(TEXT("Primitive::LoadResource"), &KhepriPrimitives::LoadResource);

  // Lighting
  Server.RegisterOperation(TEXT("Primitive::PointLight"), &KhepriPrimitives::PointLight);
  Server.RegisterOperation(TEXT("Primitive::Spotlight"), &KhepriPrimitives::Spotlight);

  // Boolean Operations
  Server.RegisterOperation(TEXT("Primitive::Unite"), &KhepriPrimitives::Unite);
  Server.RegisterOperation(TEXT("Primitive::Subtract"), &KhepriPrimitives::Subtract);
  Server.RegisterOperation(TEXT("Primitive::Intersect"), &KhepriPrimitives::Intersect);

  // Transformations
  Server.RegisterOperation(TEXT("Primitive::Move"), &KhepriPrimitives::Move);
  Server.RegisterOperation(TEXT("Primitive::Scale"), &KhepriPrimitives::Scale);
  Server.RegisterOperation(TEXT("Primitive::Rotate"), &KhepriPrimitives::Rotate);

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

  // Shape query
  Server.RegisterOperation(TEXT("Primitive::ShapeType"), &KhepriPrimitives::ShapeType);

  // Deferred selection
  Server.RegisterOperation(TEXT("Primitive::GetShape"), &KhepriPrimitives::GetShape);
  Server.RegisterOperation(TEXT("Primitive::GetShapes"), &KhepriPrimitives::GetShapes);
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

  // Set mesh data on section 0 using LinearColor variant.
  // Normals are outward-facing. Individual shape functions are responsible
  // for producing correct winding (CW from outside for UE's left-handed system).
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
// CreateMeshActor — multi-section variant (one section per FMeshData, each with its own material)
// =============================================================================

int32 KhepriPrimitives::CreateMeshActor(
  FKhepriChannel& Channel,
  const TArray<KhepriMeshBuilder::FMeshData>& Sections,
  const TArray<int32>& MaterialIndices,
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

  int32 ActorNum = GKhepriActorCounter++;
  FString ActorName = FString::Printf(TEXT("Khepri_%s_%d"), ShapeLabel, ActorNum);

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

  UProceduralMeshComponent* ProcMesh = NewObject<UProceduralMeshComponent>(NewActor, TEXT("ProceduralMesh"));
  NewActor->SetRootComponent(ProcMesh);
  ProcMesh->RegisterComponent();

  TArray<FProcMeshTangent> EmptyTangents;
  TArray<FLinearColor> EmptyColors;

  for (int32 i = 0; i < Sections.Num(); ++i)
  {
    const auto& MeshData = Sections[i];
    if (MeshData.Vertices.Num() == 0) continue;

    ProcMesh->CreateMeshSection_LinearColor(
      i, MeshData.Vertices, MeshData.Triangles, MeshData.Normals,
      MeshData.UVs, EmptyColors, EmptyTangents, bCreateCollision);

    int32 MatIndex = (i < MaterialIndices.Num()) ? MaterialIndices[i] : -1;
    UMaterialInterface* Material = nullptr;
    if (MatIndex >= 0)
    {
      Material = Channel.GetMaterial(MatIndex);
    }
    else if (Channel.CurrentMaterialIndex >= 0)
    {
      Material = Channel.GetMaterial(Channel.CurrentMaterialIndex);
    }
    if (Material)
    {
      ProcMesh->SetMaterial(i, Material);
    }
  }

  if (Channel.CurrentParentIndex >= 0)
  {
    AActor* ParentActor = Channel.GetActor(Channel.CurrentParentIndex);
    if (ParentActor)
    {
      NewActor->AttachToActor(ParentActor, FAttachmentTransformRules::KeepWorldTransform);
    }
  }

  NewActor->SetActorLocation(Location);
  NewActor->SetActorRotation(Rotation);

  int32 Index = Channel.RegisterActor(NewActor);
  return Index;
}

// =============================================================================
// Shape Management
// =============================================================================

void KhepriPrimitives::DeleteAll(FKhepriChannel& Channel)
{
  // Delete all Khepri-registered actors
  const TArray<AActor*>& Actors = Channel.GetActorRegistry();
  for (AActor* Actor : Actors)
  {
    if (Actor && !Actor->IsUnreachable() && IsValid(Actor))
    {
      Actor->Destroy();
    }
  }
  Channel.ClearRegistries();
  // Don't reset GKhepriActorCounter — UE's name registry retains
  // destroyed actor names until GC, so reusing names causes a fatal error.

  // Also destroy pre-existing level geometry (StaticMeshActors, etc.)
  // so the scene is clean for rendering. Preserve infrastructure actors
  // (lights, sky, landscape, cameras, volumes, brushes, world settings).
  UWorld* World = GetEditorWorld();
  if (World)
  {
    TArray<AActor*> ToDestroy;
    for (TActorIterator<AActor> It(World); It; ++It)
    {
      AActor* Actor = *It;
      if (!Actor || !IsValid(Actor)) continue;

      // Only destroy StaticMeshActors — preserve everything else
      // (lights, sky, atmosphere, landscape, volumes, fog, cameras, etc.)
      if (!Actor->GetClass()->GetName().Contains(TEXT("StaticMeshActor")))
      {
        continue;
      }

      ToDestroy.Add(Actor);
    }
    for (AActor* Actor : ToDestroy)
    {
      Actor->Destroy();
    }
    UE_LOG(LogKhepri, Log, TEXT("Khepri: DeleteAll - destroyed %d Khepri + %d level actors"),
      Actors.Num(), ToDestroy.Num());
  }

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
    if (Actor && !Actor->IsUnreachable() && IsValid(Actor))
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
  if (Actor && !Actor->IsUnreachable() && IsValid(Actor))
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
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildPointMarker(FVector::ZeroVector, 5.0f);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, Position, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Point"));
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

  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildTube(LocalPts, 2.0f);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, Origin, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Line"));
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

  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildTube(LocalPts, 2.0f);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, Origin, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("ClosedLine"));
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
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildTriangle(P1, P2, P3);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Triangle"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Quad(FKhepriChannel& Channel)
{
  FVector P1 = Channel.ReadFVector();
  FVector P2 = Channel.ReadFVector();
  FVector P3 = Channel.ReadFVector();
  FVector P4 = Channel.ReadFVector();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildQuad(P1, P2, P3, P4);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Quad"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::NGon(FKhepriChannel& Channel)
{
  TArray<FVector> Pts = Channel.ReadFVectorArray();
  FVector Pivot = Channel.ReadFVector();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildNGon(Pts, Pivot);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("NGon"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::QuadStrip(FKhepriChannel& Channel)
{
  TArray<FVector> Bottom = Channel.ReadFVectorArray();
  TArray<FVector> Top = Channel.ReadFVectorArray();
  int32 SmoothInt = Channel.ReadInt32();
  bool bSmooth = (SmoothInt != 0);

  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildQuadStrip(Bottom, Top, bSmooth);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("QuadStrip"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::SurfacePolygon(FKhepriChannel& Channel)
{
  TArray<FVector> Pts = Channel.ReadFVectorArray();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildSurfacePolygon(Pts);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("SurfacePolygon"));
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

  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildSurfaceGrid(Pts, bClosedU, bClosedV, bSmooth);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("SurfaceGrid"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::SurfaceMesh(FKhepriChannel& Channel)
{
  TArray<FVector> Vertices = Channel.ReadFVectorArray();
  TArray<TArray<int32>> Faces = Channel.ReadInt32ArrayArray();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildFromVertsFaces(Vertices, Faces);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("SurfaceMesh"));
  Channel.WriteInt32(Index);
}

// =============================================================================
// Tier 3: Solids
// =============================================================================

void KhepriPrimitives::Sphere(FKhepriChannel& Channel)
{
  FVector Center = Channel.ReadFVector();
  float Radius = Channel.ReadFloat();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildSphere(Radius);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, Center, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Sphere"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Box(FKhepriChannel& Channel)
{
  FVector Corner = Channel.ReadFVector();
  FVector Vx = Channel.ReadFVector();
  FVector Vy = Channel.ReadFVector();
  float Dx = Channel.ReadFloat();
  float Dy = Channel.ReadFloat();
  float Dz = Channel.ReadFloat();

  Vx.Normalize();
  Vy.Normalize();
  FVector Vz = FVector::CrossProduct(Vy, Vx).GetSafeNormal();

  FVector EdgeX = Vx * Dx;
  FVector EdgeY = Vy * Dy;
  FVector EdgeZ = Vz * Dz;

  TArray<FVector> Corners;
  Corners.SetNum(8);
  Corners[0] = Corner;
  Corners[1] = Corner + EdgeX;
  Corners[2] = Corner + EdgeX + EdgeY;
  Corners[3] = Corner + EdgeY;
  Corners[4] = Corner + EdgeZ;
  Corners[5] = Corner + EdgeX + EdgeZ;
  Corners[6] = Corner + EdgeX + EdgeY + EdgeZ;
  Corners[7] = Corner + EdgeY + EdgeZ;

  int32 MatIndex = Channel.ReadInt32();

  // Build mesh from 8 corners (6 quad faces)
  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildBoxFromCorners(
    Corners[0], Corners[1], Corners[2], Corners[3],
    Corners[4], Corners[5], Corners[6], Corners[7]);

  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Box"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::RightCuboid(FKhepriChannel& Channel)
{
  FVector BaseCenter = Channel.ReadFVector();
  FVector Vx = Channel.ReadFVector();   // length axis direction
  FVector Vy = Channel.ReadFVector();   // cross-section direction
  float Width = Channel.ReadFloat();    // cross-section width (along Vy)
  float Height = Channel.ReadFloat();   // cross-section height (along Vz)
  float Length = Channel.ReadFloat();   // length along Vx axis
  float Angle = Channel.ReadFloat();

  Vx.Normalize();
  Vy.Normalize();
  FVector Vz = FVector::CrossProduct(Vx, Vy).GetSafeNormal();

  // Build box vertices directly in world space.
  // BaseCenter is at the center of the base cross-section.
  // The cuboid extends along Vx by Length, centered on Vy by Width, centered on Vz by Height.
  FVector HalfW = Vy * (Width * 0.5f);
  FVector HalfH = Vz * (Height * 0.5f);
  FVector LenVec = Vx * Length;

  FVector Base0 = BaseCenter - HalfW - HalfH;
  FVector Base1 = BaseCenter + HalfW - HalfH;
  FVector Base2 = BaseCenter + HalfW + HalfH;
  FVector Base3 = BaseCenter - HalfW + HalfH;

  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildBoxFromCorners(
    Base0, Base1, Base2, Base3,
    Base0 + LenVec, Base1 + LenVec, Base2 + LenVec, Base3 + LenVec);

  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("RightCuboid"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Cylinder(FKhepriChannel& Channel)
{
  FVector Bottom = Channel.ReadFVector();
  float Radius = Channel.ReadFloat();
  FVector Top = Channel.ReadFVector();
  int32 BotMat = Channel.ReadInt32();
  int32 TopMat = Channel.ReadInt32();
  int32 SideMat = Channel.ReadInt32();

  FVector Dir = Top - Bottom;
  float Height = Dir.Size();
  if (Height < KINDA_SMALL_NUMBER)
  {
    Height = KINDA_SMALL_NUMBER;
  }

  TArray<KhepriMeshBuilder::FMeshData> Sections = KhepriMeshBuilder::BuildCylinderParts(Radius, Height);
  TArray<int32> Mats = {BotMat, TopMat, SideMat};

  FVector Midpoint = (Bottom + Top) * 0.5f;
  FVector DirNorm = Dir.GetSafeNormal();
  FRotator Rotation = FRotationMatrix::MakeFromZ(DirNorm).Rotator();

  int32 Index = CreateMeshActor(Channel, Sections, Mats, Midpoint, Rotation, Channel.bCreateCollision, TEXT("Cylinder"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::ConeFrustum(FKhepriChannel& Channel)
{
  FVector Base = Channel.ReadFVector();
  float BaseRadius = Channel.ReadFloat();
  FVector Top = Channel.ReadFVector();
  float TopRadius = Channel.ReadFloat();
  int32 BotMat = Channel.ReadInt32();
  int32 TopMat = Channel.ReadInt32();
  int32 SideMat = Channel.ReadInt32();

  FVector Dir = Top - Base;
  float Height = Dir.Size();
  if (Height < KINDA_SMALL_NUMBER)
  {
    Height = KINDA_SMALL_NUMBER;
  }

  TArray<KhepriMeshBuilder::FMeshData> Sections = KhepriMeshBuilder::BuildConeFrustumParts(BaseRadius, TopRadius, Height);
  TArray<int32> Mats = {BotMat, TopMat, SideMat};

  FVector Midpoint = (Base + Top) * 0.5f;
  FVector DirNorm = Dir.GetSafeNormal();
  FRotator Rotation = FRotationMatrix::MakeFromZ(DirNorm).Rotator();

  int32 Index = CreateMeshActor(Channel, Sections, Mats, Midpoint, Rotation, Channel.bCreateCollision, TEXT("ConeFrustum"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Torus(FKhepriChannel& Channel)
{
  FVector Center = Channel.ReadFVector();
  float MajorR = Channel.ReadFloat();
  float MinorR = Channel.ReadFloat();
  FVector Normal = Channel.ReadFVector();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildTorus(MajorR, MinorR);

  // Compute rotation from Normal - the torus lies in the plane perpendicular to Normal
  FRotator Rotation = FRotationMatrix::MakeFromZ(Normal.GetSafeNormal()).Rotator();

  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, Center, Rotation, Channel.bCreateCollision, TEXT("Torus"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Pyramid(FKhepriChannel& Channel)
{
  TArray<FVector> Base = Channel.ReadFVectorArray();
  FVector Apex = Channel.ReadFVector();
  int32 BaseMat = Channel.ReadInt32();
  int32 SideMat = Channel.ReadInt32();

  TArray<KhepriMeshBuilder::FMeshData> Sections = KhepriMeshBuilder::BuildPyramidParts(Base, Apex);
  TArray<int32> Mats = {BaseMat, SideMat};

  int32 Index = CreateMeshActor(Channel, Sections, Mats, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Pyramid"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::PyramidFrustum(FKhepriChannel& Channel)
{
  TArray<FVector> Base = Channel.ReadFVectorArray();
  TArray<FVector> Top = Channel.ReadFVectorArray();
  int32 BotMat = Channel.ReadInt32();
  int32 TopMat = Channel.ReadInt32();
  int32 SideMat = Channel.ReadInt32();

  TArray<KhepriMeshBuilder::FMeshData> Sections = KhepriMeshBuilder::BuildPyramidFrustumParts(Base, Top);
  TArray<int32> Mats = {BotMat, TopMat, SideMat};

  int32 Index = CreateMeshActor(Channel, Sections, Mats, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("PyramidFrustum"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::PyramidFrustumWithMaterial(FKhepriChannel& Channel)
{
  TArray<FVector> Base = Channel.ReadFVectorArray();
  TArray<FVector> Top = Channel.ReadFVectorArray();
  int32 MatIndex = Channel.ReadInt32();
  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildPyramidFrustum(Base, Top);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("PyramidFrustum"));
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
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Slab"));
  Channel.WriteInt32(Index);
}

void KhepriPrimitives::Panel(FKhepriChannel& Channel)
{
  TArray<FVector> Pts = Channel.ReadFVectorArray();
  FVector Normal = Channel.ReadFVector();
  int32 MatIndex = Channel.ReadInt32();

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildPanel(Pts, Normal);
  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("Panel"));
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

  // DX=width (along Vy), DY=height (along Vz), DZ=length (along Vx)
  Vx.Normalize();
  Vy.Normalize();
  FVector Vz = FVector::CrossProduct(Vx, Vy).GetSafeNormal();

  FVector HalfW = Vy * (DX * 0.5f);
  FVector HalfH = Vz * (DY * 0.5f);
  FVector LenVec = Vx * DZ;

  FVector Base0 = Pos - HalfW - HalfH;
  FVector Base1 = Pos + HalfW - HalfH;
  FVector Base2 = Pos + HalfW + HalfH;
  FVector Base3 = Pos - HalfW + HalfH;

  KhepriMeshBuilder::FMeshData MeshData = KhepriMeshBuilder::BuildBoxFromCorners(
    Base0, Base1, Base2, Base3,
    Base0 + LenVec, Base1 + LenVec, Base2 + LenVec, Base3 + LenVec);

  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, FVector::ZeroVector, FRotator::ZeroRotator, Channel.bCreateCollision, TEXT("BeamRect"));
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

  int32 Index = CreateMeshActor(Channel, MeshData, MatIndex, Midpoint, Rotation, Channel.bCreateCollision, TEXT("BeamCirc"));
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


void KhepriPrimitives::CreatePBRMaterial(FKhepriChannel& Channel)
{
  float R = Channel.ReadFloat();
  float G = Channel.ReadFloat();
  float B = Channel.ReadFloat();
  float A = Channel.ReadFloat();
  float Metallic = Channel.ReadFloat();
  float Roughness = Channel.ReadFloat();
  float Specular = Channel.ReadFloat();
  float EmissiveR = Channel.ReadFloat();
  float EmissiveG = Channel.ReadFloat();
  float EmissiveB = Channel.ReadFloat();
  float EmissionStrength = Channel.ReadFloat();
  float IOR = Channel.ReadFloat();
  float Transmission = Channel.ReadFloat();
  float TransmissionRoughness = Channel.ReadFloat();
  float ClearCoat = Channel.ReadFloat();
  float ClearCoatRoughness = Channel.ReadFloat();

  // Select base material variant based on PBR parameters
  UMaterial* BaseMaterial = nullptr;
  if (Transmission > 0.0f || A < 1.0f)
  {
    BaseMaterial = GetOrCreateTranslucentBaseMaterial();
  }
  else if (ClearCoat > 0.0f)
  {
    BaseMaterial = GetOrCreateClearCoatBaseMaterial();
  }
  else
  {
    BaseMaterial = GetOrCreateBaseMaterial();
  }

  if (!BaseMaterial)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: CreatePBRMaterial - failed to create base material"));
    Channel.WriteInt32(-1);
    return;
  }

  UWorld* World = GetEditorWorld();
  UMaterialInstanceDynamic* DynMat = UMaterialInstanceDynamic::Create(BaseMaterial, World);
  if (!DynMat)
  {
    UE_LOG(LogKhepri, Warning, TEXT("Khepri: CreatePBRMaterial - failed to create dynamic material instance"));
    Channel.WriteInt32(-1);
    return;
  }

  // Common parameters (present on all three base material variants)
  DynMat->SetVectorParameterValue(TEXT("BaseColor"), FLinearColor(R, G, B, A));
  DynMat->SetScalarParameterValue(TEXT("Metallic"), Metallic);
  DynMat->SetScalarParameterValue(TEXT("Specular"), Specular);
  DynMat->SetScalarParameterValue(TEXT("Roughness"), Roughness);
  DynMat->SetScalarParameterValue(TEXT("Opacity"), A);
  DynMat->SetVectorParameterValue(TEXT("EmissiveColor"), FLinearColor(EmissiveR, EmissiveG, EmissiveB, 1.0f));
  DynMat->SetScalarParameterValue(TEXT("EmissionStrength"), EmissionStrength);

  // Variant-specific parameters
  if (Transmission > 0.0f || A < 1.0f)
  {
    // For translucent: use IOR as refraction, blend opacity with transmission
    DynMat->SetScalarParameterValue(TEXT("Refraction"), IOR);
    // Reduce opacity when transmission is high
    float EffectiveOpacity = A * (1.0f - Transmission);
    DynMat->SetScalarParameterValue(TEXT("Opacity"), FMath::Max(EffectiveOpacity, 0.01f));
  }
  else if (ClearCoat > 0.0f)
  {
    DynMat->SetScalarParameterValue(TEXT("ClearCoat"), ClearCoat);
    DynMat->SetScalarParameterValue(TEXT("ClearCoatRoughness"), ClearCoatRoughness);
  }

  DynMat->AddToRoot();

  int32 Index = Channel.RegisterMaterial(DynMat);
  UE_LOG(LogKhepri, Verbose, TEXT("Khepri: CreatePBRMaterial - RGBA(%.2f,%.2f,%.2f,%.2f) Metal=%.2f Rough=%.2f IOR=%.1f Trans=%.2f CC=%.2f -> index %d"),
    R, G, B, A, Metallic, Roughness, IOR, Transmission, ClearCoat, Index);
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

void KhepriPrimitives::SetParentVisible(FKhepriChannel& Channel)
{
  int32 ParentIndex = Channel.ReadInt32();
  int32 Visible = Channel.ReadInt32();
  bool bHidden = (Visible == 0);

  AActor* ParentActor = Channel.GetActor(ParentIndex);
  if (ParentActor)
  {
    ParentActor->SetActorHiddenInGame(bHidden);
    TArray<AActor*> AttachedActors;
    ParentActor->GetAttachedActors(AttachedActors, /*bResetArray=*/true, /*bRecursivelyIncludeAttachedActors=*/true);
    for (AActor* Child : AttachedActors)
    {
      if (Child)
      {
        Child->SetActorHiddenInGame(bHidden);
      }
    }
  }
  Channel.WriteInt32(0);
}

void KhepriPrimitives::SetParentOpacity(FKhepriChannel& Channel)
{
  int32 ParentIndex = Channel.ReadInt32();
  float Opacity = Channel.ReadFloat();

  AActor* ParentActor = Channel.GetActor(ParentIndex);
  if (ParentActor)
  {
    // Apply to the parent and all (recursively) attached actors, mirroring
    // SetParentVisible's traversal. Best-effort: sets the "Opacity" scalar on a
    // dynamic instance of each material slot (KhepriBaseMaterial exposes that
    // parameter). Visible only where the material's blend mode is translucent;
    // opaque materials are left unchanged. Promoting opaque->translucent is left
    // to a future native pass.
    TArray<AActor*> Actors;
    Actors.Add(ParentActor);
    ParentActor->GetAttachedActors(Actors, /*bResetArray=*/false, /*bRecursivelyIncludeAttachedActors=*/true);
    for (AActor* Actor : Actors)
    {
      if (!Actor) continue;
      TArray<UPrimitiveComponent*> Components;
      Actor->GetComponents<UPrimitiveComponent>(Components);
      for (UPrimitiveComponent* Component : Components)
      {
        if (!Component) continue;
        int32 NumMaterials = Component->GetNumMaterials();
        for (int32 i = 0; i < NumMaterials; i++)
        {
          UMaterialInstanceDynamic* DynMat = Component->CreateAndSetMaterialInstanceDynamic(i);
          if (DynMat)
          {
            DynMat->SetScalarParameterValue(TEXT("Opacity"), Opacity);
          }
        }
      }
    }
  }
  Channel.WriteInt32(0);
}

void KhepriPrimitives::DeleteAllInParent(FKhepriChannel& Channel)
{
  int32 ParentIndex = Channel.ReadInt32();

  AActor* ParentActor = Channel.GetActor(ParentIndex);
  if (ParentActor)
  {
    TArray<AActor*> AttachedActors;
    ParentActor->GetAttachedActors(AttachedActors, /*bResetArray=*/true, /*bRecursivelyIncludeAttachedActors=*/true);
    for (AActor* Child : AttachedActors)
    {
      if (Child && !Child->IsUnreachable() && IsValid(Child))
      {
        Child->Destroy();
      }
    }
  }
  Channel.WriteInt32(0);
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
  Channel.ReadInt32(); // operand 1 (unused: CSG not supported)
  Channel.ReadInt32(); // operand 2
  // The Unreal backend has no CSG yet. Return NOTOK rather than silently producing
  // wrong geometry (the previous stub returned the first operand and orphaned the
  // second). The dispatcher already wrote the OK byte, so reset it first.
  Channel.ResetResponse();
  Channel.WriteByte(1);
  Channel.WriteString(TEXT("The Unreal backend does not support the CSG boolean 'unite'."));
}

void KhepriPrimitives::Subtract(FKhepriChannel& Channel)
{
  Channel.ReadInt32(); // operand 1 (unused: CSG not supported)
  Channel.ReadInt32(); // operand 2
  // The Unreal backend has no CSG yet. Return NOTOK rather than silently producing
  // wrong geometry (the previous stub returned the first operand and orphaned the
  // second). The dispatcher already wrote the OK byte, so reset it first.
  Channel.ResetResponse();
  Channel.WriteByte(1);
  Channel.WriteString(TEXT("The Unreal backend does not support the CSG boolean 'subtract'."));
}

void KhepriPrimitives::Intersect(FKhepriChannel& Channel)
{
  Channel.ReadInt32(); // operand 1 (unused: CSG not supported)
  Channel.ReadInt32(); // operand 2
  // The Unreal backend has no CSG yet. Return NOTOK rather than silently producing
  // wrong geometry (the previous stub returned the first operand and orphaned the
  // second). The dispatcher already wrote the OK byte, so reset it first.
  Channel.ResetResponse();
  Channel.WriteByte(1);
  Channel.WriteString(TEXT("The Unreal backend does not support the CSG boolean 'intersect'."));
}

// =============================================================================
// Transformations
// =============================================================================
// Coordinate conversion (Khepri RH metres -> UE LH centimetres: X<->Y swap, x100)
// happens in the Julia FVector encoder, so the points/vectors below already arrive
// in UE world space. That swap is orientation-reversing, so a Khepri rotation by
// +angle becomes -angle about the (already-swapped) axis in UE — mirroring
// KhepriUnity.Rotate, which negates the angle for the same reason.

void KhepriPrimitives::Move(FKhepriChannel& Channel)
{
  int32 Index = Channel.ReadInt32();
  FVector V = Channel.ReadFVector();
  AActor* Actor = Channel.GetActor(Index);
  if (Actor)
  {
    Actor->AddActorWorldOffset(V);
  }
  Channel.WriteInt32(0);
}

void KhepriPrimitives::Scale(FKhepriChannel& Channel)
{
  int32 Index = Channel.ReadInt32();
  FVector P = Channel.ReadFVector();
  float S = Channel.ReadFloat();
  AActor* Actor = Channel.GetActor(Index);
  if (Actor)
  {
    // Uniform scale about world point P.
    FVector Loc = Actor->GetActorLocation();
    Actor->SetActorLocation(P + (Loc - P) * S);
    Actor->SetActorScale3D(Actor->GetActorScale3D() * S);
  }
  Channel.WriteInt32(0);
}

void KhepriPrimitives::Rotate(FKhepriChannel& Channel)
{
  int32 Index = Channel.ReadInt32();
  FVector P = Channel.ReadFVector();      // world point on the axis
  FVector Axis = Channel.ReadFVector();   // axis direction (already swapped; normalize)
  float Angle = Channel.ReadFloat();      // Khepri angle, radians
  AActor* Actor = Channel.GetActor(Index);
  if (Actor)
  {
    // Negate the angle: the Khepri->UE X<->Y swap is orientation-reversing.
    FQuat Q(Axis.GetSafeNormal(), -Angle);
    FVector Loc = Actor->GetActorLocation();
    Actor->AddActorWorldRotation(Q);
    Actor->SetActorLocation(P + Q.RotateVector(Loc - P));
  }
  Channel.WriteInt32(0);
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
      // Configure high-res screenshot on the correct level editor viewport
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

void KhepriPrimitives::ShapeType(FKhepriChannel& Channel)
{
  int32 Index = Channel.ReadInt32();
  AActor* Actor = Channel.GetActor(Index);
  FString Label = Actor ? Actor->GetActorLabel() : TEXT("Unknown");
  // Label format: "Khepri_<Type>_<Num>" — extract the type part
  FString Type = TEXT("Unknown");
  if (Label.StartsWith(TEXT("Khepri_")))
  {
    FString Rest = Label.Mid(7); // after "Khepri_"
    int32 UnderscorePos;
    if (Rest.FindLastChar('_', UnderscorePos))
    {
      Type = Rest.Left(UnderscorePos);
    }
  }
  Channel.WriteString(Type);
}

void KhepriPrimitives::GetShape(FKhepriChannel& Channel)
{
  FString Prompt = Channel.ReadString();
  UE_LOG(LogTemp, Log, TEXT("Khepri: %s"), *Prompt);
  // Start selection — deferred response sent by tick loop
  if (GEditor)
  {
    GEditor->SelectNone(true, true, false);
  }
  bSelectionPending = true;
  bSelectMany = false;
  // No response — result written by the tick/serve loop when selection completes
}

void KhepriPrimitives::GetShapes(FKhepriChannel& Channel)
{
  FString Prompt = Channel.ReadString();
  UE_LOG(LogTemp, Log, TEXT("Khepri: %s"), *Prompt);
  if (GEditor)
  {
    GEditor->SelectNone(true, true, false);
  }
  bSelectionPending = true;
  bSelectMany = true;
}
