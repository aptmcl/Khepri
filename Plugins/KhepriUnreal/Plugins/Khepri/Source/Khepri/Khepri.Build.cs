// Khepri.Build.cs — Module build rules for Khepri UE plugin
// No boost, no BSPUtils, no MovieScene dependencies.

using UnrealBuildTool;

public class Khepri : ModuleRules
{
  public Khepri(ReadOnlyTargetRules Target) : base(Target)
  {
    PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;
    IncludeOrderVersion = EngineIncludeOrderVersion.Latest;

    PublicDependencyModuleNames.AddRange(
      new string[]
      {
        "Core",
        "CoreUObject",
        "Engine",
        "ProceduralMeshComponent",
        "Networking",
        "Sockets",
      });

    PrivateDependencyModuleNames.AddRange(
      new string[]
      {
        "UnrealEd",
        "LevelEditor",
        "Slate",
        "SlateCore",
        "InputCore",
        "ImageWriteQueue",
        "MeshDescription",
        "StaticMeshDescription",
      });
  }
}
