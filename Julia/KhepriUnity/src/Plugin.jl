export setup_unity, upgrade_plugin

const khepri_unity_version = let toml = joinpath(dirname(@__DIR__), "Project.toml")
  VersionNumber(match(r"version\s*=\s*\"([^\"]+)\"", read(toml, String)).captures[1])
end

const julia_khepri = dirname(@__DIR__)
const local_plugin = joinpath(julia_khepri, "Plugin")
const local_version_file = joinpath(local_plugin, "version.txt")

plugin_version(path) = VersionNumber(strip(read(path, String)))

# Subdirectories to copy from Assets/Resources/ into Plugin/Resources/
# Excludes materials/ (1.3GB) and prefabs/ (242MB) to keep Plugin/ manageable.
const plugin_resource_dirs = ["Default"]

#=
Developer-only: copy plugin files from Plugins/KhepriUnity/Assets/ into Plugin/.
Run this after recompiling the C# plugin and commit the updated Plugin/ directory.

  upgrade_plugin()
=#
upgrade_plugin() =
  let plugin_src = joinpath(dirname(dirname(julia_khepri)), "Plugins", "KhepriUnity", "Assets"),
      khepri_src = joinpath(plugin_src, "Khepri"),
      resources_src = joinpath(plugin_src, "Resources")
    isdir(khepri_src) || error("Plugin source not found: $khepri_src")
    mkpath(local_plugin)
    # Copy Khepri/
    let dest = joinpath(local_plugin, "Khepri")
      rm(dest, force=true, recursive=true)
      cp(khepri_src, dest)
    end
    # Copy selected Resources/ subdirectories
    let dest_resources = joinpath(local_plugin, "Resources")
      mkpath(dest_resources)
      for dir in plugin_resource_dirs
        let src = joinpath(resources_src, dir),
            dst = joinpath(dest_resources, dir)
          isdir(src) || (@warn "Resource directory not found, skipping: $src"; continue)
          rm(dst, force=true, recursive=true)
          cp(src, dst)
        end
      end
    end
    # Write version
    write(local_version_file, string(khepri_unity_version))
    @info "Plugin updated to $khepri_unity_version"
  end

#=
Deploy the Khepri plugin into a Unity project.
Copies Khepri/ and Resources/Default/ from Plugin/ into the project's Assets/.

  setup_unity("/path/to/your/unity/project")

Resources/materials/ and Resources/prefabs/ are NOT included in Plugin/ due to size.
To use those, copy them manually from Plugins/KhepriUnity/Assets/Resources/.
=#
setup_unity(project_path::AbstractString) =
  let assets = joinpath(project_path, "Assets"),
      dest_khepri = joinpath(assets, "Khepri"),
      dest_resources = joinpath(assets, "Resources"),
      dest_version = joinpath(dest_khepri, "version.txt")
    isdir(assets) || error("Not a Unity project (no Assets/ folder): $project_path")
    isdir(local_plugin) || error("Plugin folder not found at $local_plugin. Run upgrade_plugin() first.")
    isfile(local_version_file) || error("Plugin version file not found. Run upgrade_plugin() first.")
    let need_install = !isfile(dest_version) || plugin_version(dest_version) < plugin_version(local_version_file)
      if need_install
        @info "Installing Khepri Unity plugin v$(plugin_version(local_version_file)) into $project_path..."
        # Copy Khepri/ (full overwrite)
        rm(dest_khepri, force=true, recursive=true)
        cp(joinpath(local_plugin, "Khepri"), dest_khepri)
        cp(local_version_file, joinpath(dest_khepri, "version.txt"))
        # Merge Resources/ (don't delete user's other resources)
        mkpath(dest_resources)
        let src_resources = joinpath(local_plugin, "Resources")
          for item in readdir(src_resources)
            let src = joinpath(src_resources, item),
                dst = joinpath(dest_resources, item)
              rm(dst, force=true, recursive=true)
              cp(src, dst)
            end
          end
        end
        # Ensure com.unity.ai.navigation dependency
        ensure_unity_navigation_package(project_path)
        @info "Done. Open the Unity project in Unity and click 'Start Khepri' in the Inspector."
      else
        @info "Khepri Unity plugin is already up to date (v$(plugin_version(dest_version))) in $project_path"
      end
    end
  end

ensure_unity_navigation_package(project_path) =
  let manifest_path = joinpath(project_path, "Packages", "manifest.json")
    if isfile(manifest_path)
      let manifest = read(manifest_path, String)
        if !occursin("com.unity.ai.navigation", manifest)
          let new_manifest = replace(manifest,
                r"\"dependencies\"\s*:\s*\{" =>
                "\"dependencies\": {\n    \"com.unity.ai.navigation\": \"2.0.10\",")
            write(manifest_path, new_manifest)
            @info "Added com.unity.ai.navigation package dependency"
          end
        end
      end
    end
  end
