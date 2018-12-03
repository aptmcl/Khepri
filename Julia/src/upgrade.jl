#=

Here is the process for updating Khepri

=#

# The Khepri Julia project itself is stored at

julia_khepri = joinpath(dirname(dirname(abspath(@__FILE__))), "Khepri")

upgrade_autocad(; phase="Debug") =
    let # 1. The dlls are updated in VisualStudio after compilation of the plugin, and they are stored in the folder.
        dlls = ["KhepriBase.dll", "KhepriAutoCAD.dll"]
        # 2. Depending on whether we are in Debug mode or Release mode,
        development_phase = phase # "Release"
        # 3. the dlls are located in a folder
        dlls_folder = joinpath("bin", "x64", development_phase)
        # 4. contained inside the Plugins folder, which has a specific location regarding this file itself
        plugin_folder = joinpath(dirname(dirname(dirname(abspath(@__FILE__)))), "Plugins", "KhepriAutoCAD", "KhepriAutoCAD")
        # 5. Besides the dlls, we also need the bundle folder
        bundle_name = "Khepri.bundle"
        bundle_dll_folder = joinpath(bundle_name, "Contents")
        bundle_xml = joinpath(bundle_name, "PackageContents.xml")
        # 6. which is contained in the Plugins folder
        bundle_path = joinpath(plugin_folder, bundle_name)
        # 7. The bundle needs to be copied to the current folder
        local_bundle_path = joinpath(julia_khepri, "Plugins", "AutoCAD", bundle_name)
        # 8. but, before, we remove any previously existing bundle
        mkpath(dirname(local_bundle_path))
        if isdir(local_bundle_path)
            rm(local_bundle_path, force=true, recursive=true)
        end
        # 9. Now we do the copy
        cp(bundle_path, local_bundle_path)
        # 10. and we copy the dlls to the local bundle Contents folder
        local_bundle_contents_path = joinpath(local_bundle_path, "Contents")
        for dll in dlls
            src = joinpath(plugin_folder, dlls_folder, dll)
            dst = joinpath(local_bundle_contents_path, dll)
            rm(dst, force=true)
            cp(src, dst)
        end
    end

export upgrade_autocad

#=
After updating something in the plugin, just call this function:

upgrade_autocad()

=#

#=
Pkg3 is not yet ready. We need to manually generate REQUIRE
=#

import Pkg
const PT = Pkg.Types

generate_require(dir=julia_khepri) =
    begin
        Pkg.activate(dir)             # current directory as the project
        ctx = PT.Context()
        pkg = ctx.env.pkg
        if pkg ≡ nothing
            @error "Not in a package, I won't generate REQUIRE."
        else
            @info "found package" pkg = pkg
        end
        deps = PT.get_deps(ctx)
        non_std_deps = sort(collect(setdiff(keys(deps), values(ctx.stdlibs))))
        open(joinpath(julia_khepri, "REQUIRE"), "w") do io
            for d in non_std_deps
                println(io, d)
                @info "listing $d"
            end
        end
    end

#=
generate_require()
=#

export generate_require
