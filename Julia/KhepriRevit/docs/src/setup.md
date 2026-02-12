# [Setup](@id setup)

## Plugin Installation

KhepriRevit communicates with Revit through a C# plugin that must be installed
as a Revit add-in. The plugin is distributed as an **ApplicationPlugin bundle**
(`KhepriRevit.bundle`) containing:

```
KhepriRevit.bundle/
├── PackageContents.xml    # Version and metadata
└── Contents/
    ├── KhepriBase.dll     # Shared Khepri communication library
    ├── KhepriRevit.dll    # Revit-specific plugin
    └── KhepriRevit.addin  # Revit add-in manifest
```

### Automatic Plugin Management

On first connection, KhepriRevit automatically checks and updates the plugin:

1. **`check_plugin()`** runs before connecting — called automatically by
   `before_connecting`
2. **`update_plugin()`** compares the version in the local `Plugin/` folder
   (shipped with the Julia package) against the installed version
3. If the installed version is older (or missing), the plugin files are copied
   automatically

The plugin is installed to the **user ApplicationPlugins** folder:
```
%APPDATA%\Autodesk\ApplicationPlugins\KhepriRevit.bundle\
```

### Plugin Installation Paths

Revit searches for add-ins in several locations:

| Location | Path | Scope |
|----------|------|-------|
| User Addins | `%APPDATA%\Autodesk\Revit\Addins\<version>\` | Current user |
| User ApplicationPlugins | `%APPDATA%\Autodesk\ApplicationPlugins\` | Current user |
| Machine Addins | `C:\ProgramData\Autodesk\Revit\Addins\<version>\` | All users |
| Machine ApplicationPlugins | `C:\ProgramData\Autodesk\ApplicationPlugins\` | All users |
| Autodesk servers | `C:\Program Files\Autodesk\Revit <version>\AddIns\` | Built-in |

KhepriRevit uses the **User ApplicationPlugins** path by default.

### Upgrading the Plugin (Developers)

When the C# plugin source is modified and recompiled in Visual Studio, run:

```julia
upgrade_plugin()
```

This:
1. Bumps the minor version in `PackageContents.xml`
2. Copies the compiled DLLs from the Visual Studio output directory to the
   Julia package's `Plugin/` folder
3. The next `check_plugin()` call will propagate the update to Revit's plugin
   folder

The build configuration is controlled by `development_phase` (default:
`"Debug"`). Change to `"Release"` for production builds.

## Connection

### Starting Revit

KhepriRevit provides a convenience function to launch Revit with a template:

```julia
# The default template path
revit_template()  # Returns path to KhepriTemplate.rte

# Launch Revit with the template
start_revit()
```

The template file (`KhepriTemplate.rte`) is located in the `Plugin/` directory
of the KhepriRevit package.

### Connecting

The standard Khepri backend activation handles connection:

```julia
using KhepriRevit
using KhepriBase

backend(revit)  # Connects to Revit on port 11001
```

The connection sequence:
1. `before_connecting` → calls `check_plugin()` to ensure the plugin is current
2. TCP connection established on port 11001 (Julia as server, plugin as client)
3. `after_connecting` → registers all [default family mappings](@ref default-families)

### Port Configuration

The default port is `11001` (defined as `revit_port` in KhepriBase). If you
need a different port, create a new backend instance:

```julia
my_revit = RVT("Revit", 12345, revit_api)
backend(my_revit)
```

## Troubleshooting

### "The Revit plugin is outdated! Please, close Revit."

This error appears when `update_plugin()` cannot overwrite the installed DLLs
because Revit has them locked. The solution:

1. Close Revit completely
2. Wait for the retry mechanism (it retries up to 10 times with 5-second delays)
3. Or restart Julia and try `backend(revit)` again

### Plugin Not Loading in Revit

- Verify the bundle exists at `%APPDATA%\Autodesk\ApplicationPlugins\KhepriRevit.bundle\`
- Check that `PackageContents.xml` and the `Contents/` folder with DLLs are present
- Look in Revit's add-in manager for error messages
- Ensure the Revit version matches the plugin's target framework

### Connection Timeout

- Ensure Revit is running and the Khepri plugin is loaded (check Revit's
  External Tools or add-in manager)
- Check that no firewall is blocking TCP port 11001
- Verify no other application is using port 11001

### Debug vs Release Builds

The `development_phase` variable (default `"Debug"`) controls which build
output directory is used when running `upgrade_plugin()`. If you're building
the plugin in Release mode in Visual Studio, set:

```julia
development_phase = "Release"
```

before calling `upgrade_plugin()`.
