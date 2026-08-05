// Khepri.Build.cs — Module build rules for Khepri UE plugin
// No boost, no BSPUtils, no MovieScene dependencies.

using UnrealBuildTool;

public class Khepri : ModuleRules
{
  public Khepri(ReadOnlyTargetRules Target) : base(Target)
  {
    PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;
    IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
    // The dispatch loop (KhepriServer.cpp) converts handler exceptions into
    // NOTOK error frames. UBT compiles with exceptions OFF by default, which
    // would make those catch blocks dead code and turn any throw into an
    // editor-terminating std::terminate — enable them so errors reach Julia
    // as BackendError instead.
    bEnableExceptions = true;

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
