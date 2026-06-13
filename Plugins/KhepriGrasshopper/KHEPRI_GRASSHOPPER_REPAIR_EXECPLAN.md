# Restore KhepriGrasshopper Project Identity

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds. This plan follows the repository-level instructions in `PLANS.md` at the workspace root.

## Purpose / Big Picture

KhepriGrasshopper is the Grasshopper plugin that lets users place a Grasshopper component containing Julia and Khepri code. Visual Studio cannot currently load the plugin because the latest project rename left the solution pointing to a missing project file. After this change, `Plugins/KhepriGrasshopper/KhepriGrasshopper.sln` should load its C# project again, and the project should compile the real Khepri component source instead of a missing file.

This repair intentionally does not implement the separate `GrasshopperToKhepri` converter. That converter should be a distinct future project whose role is to turn an existing graph of Grasshopper components into one KhepriGrasshopper component.

## Progress

- [x] (2026-05-15) Confirmed the plugin repository is clean before edits.
- [x] (2026-05-15) Confirmed the solution references `KhepriGrasshopper\KhepriGrasshopper.csproj`, while only `GrasshopperToKhepri.csproj` exists.
- [x] (2026-05-15) Restored the project filename and component source filename to KhepriGrasshopper names.
- [x] (2026-05-15) Updated C# type references and project compile entries to match restored filenames.
- [x] (2026-05-15) Ran static validation and available Julia tests. Linux `msbuild`/`dotnet` were not installed, so VS2022 MSBuild was run through Windows interop.
- [x] (2026-05-15) Ran VS2022 MSBuild through Windows interop and confirmed the repaired solution builds.
- [x] (2026-05-15) Moved ignored Visual Studio cache aside and renamed the ignored `.csproj.user` file to match `KhepriGrasshopper.csproj`.
- [x] (2026-05-15) Reran VS2022 `devenv.com` after clearing `.vs`; it now rebuilds `KhepriGrasshopper` with one project succeeded.

## Surprises & Discoveries

- Observation: the current code does not contain an implemented converter that takes selected Grasshopper components and synthesizes one KhepriGrasshopper component.
  Evidence: searches for conversion behavior found only the Julia-backed component implementation and old commented traceability code.
- Observation: the March 2026 commit renamed the project and component source but did not update the solution or project compile item consistently.
  Evidence: `KhepriGrasshopper.sln` points to `KhepriGrasshopper.csproj`; `GrasshopperToKhepri.csproj` compiles missing `KhepriComponent.cs`.
- Observation: after the tracked project repair, VS2022 MSBuild can load and build the solution, but local ignored Visual Studio state still refers to the old project history.
  Evidence: `MSBuild.exe KhepriGrasshopper.sln /p:Configuration=Release` produced `bin\KhepriGrasshopper.dll`; ignored state included `.vs/KhepriGrasshopper/v17/.suo` and `KhepriGrasshopper/GrasshopperToKhepri.csproj.user`.
- Observation: the Visual Studio IDE command-line build was blocked by the stale `.vs` cache, not by the repaired project file.
  Evidence: before moving `.vs`, `devenv.com KhepriGrasshopper.sln /Rebuild "Release|Any CPU"` reported `0 succeeded, 0 failed, 0 skipped`; after moving `.vs`, the same command rebuilt `KhepriGrasshopper` with `1 succeeded`.

## Decision Log

- Decision: restore `KhepriGrasshopper` as the loadable project and component identity.
  Rationale: KhepriGrasshopper is the shipped integration and has existing Julia package deployment code expecting `KhepriGrasshopper.gha`; changing that identity breaks Visual Studio loading and user workflows.
  Date/Author: 2026-05-15 / Codex
- Decision: do not add a `GrasshopperToKhepri` project in this repair.
  Rationale: a converter should have a separate specification and GUIDs; the current code is not that converter and should not be renamed as if it were.
  Date/Author: 2026-05-15 / Codex
- Decision: preserve local Visual Studio state instead of deleting it.
  Rationale: `.vs` and `.csproj.user` are ignored local files, but they can affect Visual Studio UI behavior. Moving `.vs` aside and renaming the `.csproj.user` file keeps the old state recoverable while letting Visual Studio regenerate fresh state for the repaired solution.
  Date/Author: 2026-05-15 / Codex

## Outcomes & Retrospective

The solution and project file paths are internally consistent again, while the newer Julia/KhepriBase implementation changes from the March 2026 commit are preserved. `KhepriGrasshopper.sln` points to an existing `KhepriGrasshopper.csproj`; that project compiles an existing `KhepriComponent.cs`; and the active source no longer references the accidental `GrasshopperToKhepriComponent` type. Julia-side package tests passed with 33 tests. VS2022 MSBuild through Windows interop successfully loaded and built the solution. After moving stale `.vs` state aside, VS2022 `devenv.com` also rebuilt the solution with one project succeeded. Ignored local Visual Studio state was preserved outside this subrepo at `Plugins/KhepriGrasshopper.vs.before-khepri-grasshopper-repair-20260515`, and `GrasshopperToKhepri.csproj.user` was renamed to `KhepriGrasshopper.csproj.user`.

## Context and Orientation

The affected repository is `Plugins/KhepriGrasshopper`. It is a C# Grasshopper plugin. A `.sln` file tells Visual Studio which `.csproj` file to load. A `.csproj` file tells MSBuild which C# source files to compile. A Grasshopper component has stable GUIDs so existing Grasshopper documents can reopen the same component type.

The current solution file is `Plugins/KhepriGrasshopper/KhepriGrasshopper.sln`. It already references `KhepriGrasshopper\KhepriGrasshopper.csproj`, but that project file is missing because it was renamed to `KhepriGrasshopper\GrasshopperToKhepri.csproj`. The renamed project file still includes `KhepriComponent.cs`, which is also missing because it was renamed to `GrasshopperToKhepriComponent.cs`.

The Julia package in `Julia/KhepriGrasshopper` deploys `KhepriGrasshopper.gha` from the plugin build output and should continue to do so.

## Plan of Work

First, rename `KhepriGrasshopper/GrasshopperToKhepri.csproj` back to `KhepriGrasshopper/KhepriGrasshopper.csproj`. The solution already points to that name, so no solution edit should be needed unless validation proves otherwise.

Second, rename `KhepriGrasshopper/GrasshopperToKhepriComponent.cs` back to `KhepriGrasshopper/KhepriComponent.cs`. In that source file, rename the public component class and constructor back to `KhepriComponent`, and update internal references that should point at the core Khepri component. Keep the existing Grasshopper component GUID, assembly GUID, assembly name, and output assembly name unchanged.

Third, update `JuliaEditor.Designer.cs` so its editor field and method accept `KhepriComponent`. Update the project file compile item so it includes `KhepriComponent.cs`, which will exist after the rename.

Fourth, validate that no stale `GrasshopperToKhepri` project or component type references remain in the active KhepriGrasshopper project. Then run the available static checks and build/test commands.

## Concrete Steps

Run commands from the workspace root unless a command states otherwise.

1. Rename the project file with `git -C Plugins/KhepriGrasshopper mv KhepriGrasshopper/GrasshopperToKhepri.csproj KhepriGrasshopper/KhepriGrasshopper.csproj`.
2. Rename the component source with `git -C Plugins/KhepriGrasshopper mv KhepriGrasshopper/GrasshopperToKhepriComponent.cs KhepriGrasshopper/KhepriComponent.cs`.
3. Patch `KhepriComponent.cs` and `JuliaEditor.Designer.cs` to restore the `KhepriComponent` type name.
4. Run `rg -n "GrasshopperToKhepri|KhepriComponent.cs|KhepriGrasshopper.csproj" Plugins/KhepriGrasshopper` and confirm remaining matches are either expected history text in this ExecPlan or valid project references.
5. If MSBuild is available, run `msbuild KhepriGrasshopper.sln /p:Configuration=Release` from `Plugins/KhepriGrasshopper`.
6. Run `julia --project -e "using Pkg; Pkg.test()"` from `Julia/KhepriGrasshopper` if the local Julia package environment is available.

Completed validation on 2026-05-15:

    git -C Plugins/KhepriGrasshopper diff --check
    # passed; Git reported CRLF-to-LF working-copy warnings for two edited C# files.

    rg -n "GrasshopperToKhepriComponent|GrasshopperToKhepri.csproj" Plugins/KhepriGrasshopper/KhepriGrasshopper.sln Plugins/KhepriGrasshopper/KhepriGrasshopper/KhepriGrasshopper.csproj Plugins/KhepriGrasshopper/KhepriGrasshopper/*.cs
    # no matches in active solution, project, or C# source files.

    command -v msbuild
    command -v dotnet
    # both unavailable in this environment.

    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe" KhepriGrasshopper.sln /nologo /v:minimal /p:Configuration=Release
    # passed through Windows interop; produced KhepriGrasshopper\bin\KhepriGrasshopper.dll and copied KhepriGrasshopper.gha.

    cd Julia/KhepriGrasshopper
    julia --project -e "using Pkg; Pkg.test()"
    # passed: KhepriGrasshopper.jl, 33 tests.

    mv .vs ../KhepriGrasshopper.vs.before-khepri-grasshopper-repair-20260515
    mv KhepriGrasshopper/GrasshopperToKhepri.csproj.user KhepriGrasshopper/KhepriGrasshopper.csproj.user
    # preserves ignored Visual Studio state while removing stale references from the active VS cache/user filename.

    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.com" KhepriGrasshopper.sln /Rebuild "Release|Any CPU"
    # after moving .vs aside, passed: Rebuild All: 1 succeeded, 0 failed, 0 skipped.

## Validation and Acceptance

Acceptance is that `Plugins/KhepriGrasshopper/KhepriGrasshopper.sln` references an existing `.csproj`, that the `.csproj` references existing C# source files, and that no active code refers to the accidental `GrasshopperToKhepriComponent` type. If a C# build can be run, it should progress past project loading; any remaining build error must be reported with its cause. If Julia tests can be run, they should pass or any unrelated environment failure must be recorded.

## Idempotence and Recovery

The rename steps are safe when run once in a clean repository. If they are interrupted after one rename, inspect `git -C Plugins/KhepriGrasshopper status --short` and continue from the remaining rename or patch step. Do not reset or discard user changes.

## Artifacts and Notes

Important evidence before the repair:

    KhepriGrasshopper.sln references KhepriGrasshopper\KhepriGrasshopper.csproj.
    The repository only contains KhepriGrasshopper\GrasshopperToKhepri.csproj.
    GrasshopperToKhepri.csproj contains <Compile Include="KhepriComponent.cs" />.
    The repository only contains GrasshopperToKhepriComponent.cs.
