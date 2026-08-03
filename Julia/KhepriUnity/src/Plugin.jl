export setup_unity

const khepri_unity_version = let toml = joinpath(dirname(@__DIR__), "Project.toml")
  VersionNumber(match(r"version\s*=\s*\"([^\"]+)\"", read(toml, String)).captures[1])
end

const julia_khepri = dirname(@__DIR__)
const unity_project_source = joinpath(dirname(dirname(julia_khepri)), "Plugins", "KhepriUnity")
const unity_plugin_repo = "https://github.com/aptmcl/KhepriUnity.git"
const unity_copy_excludes = Set([
  "Library", "Logs", "Temp", "obj", ".vs", ".idea",
  "UserSettings", "UIElementsSchema", "SteamVR_SteamVR_khepri", ".git"])

plugin_version(path) = VersionNumber(strip(read(path, String)))

ensure_unity_source() =
  isdir(unity_project_source) ||
    error("Unity plugin not found at $unity_project_source.\n" *
          "Clone it with:\n  git clone $unity_plugin_repo \"$unity_project_source\"")

copy_unity_project(src, dest) =
  let skip_extensions = Set([".csproj", ".sln", ".vrmanifest"]),
      skip_prefixes = ["binding_", "bindings_"]
    mkpath(dest)
    for item in readdir(src)
      item in unity_copy_excludes && continue
      any(ext -> endswith(item, ext), skip_extensions) && continue
      any(pfx -> startswith(item, pfx), skip_prefixes) && continue
      endswith(item, ".json") && startswith(item, "actions") && continue
      let src_item = joinpath(src, item),
          dst_item = joinpath(dest, item)
        rm(dst_item, force=true, recursive=true)
        cp(src_item, dst_item)
      end
    end
  end

#=
Create a new Unity project with Khepri pre-installed.
Copies the full Plugins/KhepriUnity/ project, excluding build artifacts.

  setup_unity()
=#
setup_unity() =
  let _ = ensure_unity_source(),
      src = unity_project_source
    print("Destination path [$(joinpath(homedir(), "KhepriUnity"))]: ")
    let input = strip(readline()),
        dest = isempty(input) ? joinpath(homedir(), "KhepriUnity") : expanduser(input),
        dest_version = joinpath(dest, "Assets", "Khepri", "version.txt")
      if isfile(dest_version) && plugin_version(dest_version) >= khepri_unity_version
        @info "KhepriUnity project is already up to date (v$(plugin_version(dest_version))) at $dest"
      else
        @info "Creating KhepriUnity project at $dest..."
        copy_unity_project(src, dest)
        let khepri_dir = joinpath(dest, "Assets", "Khepri")
          mkpath(khepri_dir)
          write(joinpath(khepri_dir, "version.txt"), string(khepri_unity_version))
        end
        @info """
        KhepriUnity project created at $dest (v$khepri_unity_version).
        Next steps:
          1. Open Unity Hub and add the project at: $dest
          2. Open the scene: Assets/Scenes/KhepriScene.unity
          3. Click 'Start Khepri' in the Inspector to begin
        """
      end
    end
  end

#=
Deploy the Khepri plugin into an existing Unity project.
Copies Assets/Khepri/, Assets/Resources/ (Default, materials, prefabs),
and Assets/Scenes/ from Plugins/KhepriUnity/ into the project.

  setup_unity("/path/to/your/unity/project")
=#
setup_unity(project_path::AbstractString) =
  let _ = ensure_unity_source(),
      assets_src = joinpath(unity_project_source, "Assets"),
      assets = joinpath(project_path, "Assets"),
      dest_khepri = joinpath(assets, "Khepri"),
      dest_resources = joinpath(assets, "Resources"),
      dest_version = joinpath(dest_khepri, "version.txt")
    isdir(assets) || error("Not a Unity project (no Assets/ folder): $project_path")
    let need_install = !isfile(dest_version) || plugin_version(dest_version) < khepri_unity_version
      if need_install
        @info "Installing Khepri Unity plugin v$khepri_unity_version into $project_path..."
        # Copy Khepri/
        rm(dest_khepri, force=true, recursive=true)
        cp(joinpath(assets_src, "Khepri"), dest_khepri)
        write(joinpath(dest_khepri, "version.txt"), string(khepri_unity_version))
        # Copy Resources/ subdirectories (Default, materials, prefabs)
        mkpath(dest_resources)
        let resources_src = joinpath(assets_src, "Resources")
          for dir in readdir(resources_src)
            let src = joinpath(resources_src, dir),
                dst = joinpath(dest_resources, dir)
              rm(dst, force=true, recursive=true)
              cp(src, dst)
            end
          end
        end
        # Copy Scenes/
        let scenes_src = joinpath(assets_src, "Scenes"),
            scenes_dst = joinpath(assets, "Scenes")
          if isdir(scenes_src)
            rm(scenes_dst, force=true, recursive=true)
            cp(scenes_src, scenes_dst)
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
