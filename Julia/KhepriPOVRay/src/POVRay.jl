#=
A backend for POVRay
=#

export POVRay,
       povray,
       povray_material

# We will use MIME types to encode for POVRay
const MIMEPOVRay = MIME"text/povray"

# First, basic types
show(io::IO, ::MIMEPOVRay, s::String) =
  show(io, s)
show(io::IO, ::MIMEPOVRay, s::Symbol) =
  print(io, s)
show(io::IO, ::MIMEPOVRay, r::Real) =
  show(io, r)
show(io::IO, mime::MIMEPOVRay, v::Vector) =
  begin
    write(io, "<")
    for (i, e) in enumerate(v)
      if i > 1
        write(io, ", ")
      end
      show(io, mime, e)
    end
    write(io, ">")
    nothing
  end
show(io::IO, ::MIMEPOVRay, p::Union{Loc,Vec}) =
  # swap y with z to make it consistent with POVRay coordinate system
  let p = in_world(p)
    print(io, "<$(p.x), $(p.z), $(p.y)>")
  end
show(io::IO, ::MIMEPOVRay, c::RGB) =
  print(io, "color rgb <$(Float64(red(c))), $(Float64(green(c))), $(Float64(blue(c)))>")
show(io::IO, ::MIMEPOVRay, c::RGBA) =
  print(io, "color rgbt <$(Float64(red(c))), $(Float64(green(c))), $(Float64(blue(c))), $(Float64(1-alpha(c)))>")

write_povray_object(f::Function, io::IO, type, material, args...) =
  let mime = MIMEPOVRay()
    write(io, "$(type) {")
    for (i, arg) in enumerate(args)
      if i == 1
        write(io, "\n  ")
      elseif i > 1
        write(io, ", ")
      end
      show(io, mime, arg)
    end
    write(io, '\n')
    if ! isnothing(material)
      write_povray_material(io, material)
    end
    let res = f()
      write(io, "}\n")
      res
    end
  end

write_povray_object(io::IO, type, material, args...) =
  write_povray_object(io, type, material, args...) do
    -1 # Default id
  end

write_povray_value(io::IO, value::Any) =
  show(io, MIMEPOVRay(), value)

write_povray_values(io::IO, values) =
  let first = true
    for value in values
      if !first
        print(io, ", ")
      else
        first = false
      end
      write_povray_value(io, value)
    end
  end

write_povray_param(io::IO, name::String, value::Any) =
  begin
    write(io, "  ", name, " ")
    write_povray_value(io, value)
    write(io, '\n')
  end

write_povray_call(io::IO, name::String, values...) =
  begin
    write(io, "  ", name, "(")
    write_povray_values(io, values)
    write(io, ")\n")
  end


write_povray_material(io::IO, material) =
  begin
    write(io, "  ")
    write_povray_value(io, material)
    write(io, '\n')
  end

write_povray_matrix(io::IO, p::Loc) =
  let t = (translated_cs(p.cs, p.x, p.y, p.z).transform)
    write_povray_param(io, "matrix",
      [t[1,1], t[3,1], t[2,1],
       t[1,2], t[3,2], t[2,2],
       t[1,3], t[3,3], t[2,3],
       t[1,4], t[3,4], t[2,4]])
  end

write_povray_camera(io::IO, camera, target, lens) =
  write_povray_object(io, "camera", nothing) do
    write_povray_param(io, "location", camera)
    write_povray_param(io, "look_at", target)
    write_povray_param(io, "right", Symbol("x*image_width/image_height"))
    write_povray_param(io, "angle", view_angles(lens)[1])
  end

write_povray_pointlight(io::IO, location, color) =
  write_povray_object(io, "light_source", nothing, location, color)

write_povray_polygon(io::IO, mat, vs) =
  write_povray_object(io, "polygon", mat, length(vs)+1, vs..., vs[1])

write_povray_polygons(io::IO, mat, vss) =
  write_povray_object(io, "polygon", mat,
    mapreduce(length, +, vss) + length(vss),
    mapreduce(vs->[vs..., vs[1]], vcat, vss)...)

# mesh2 cannot write materials as mesh did.
write_povray_mesh(io::IO, mat, pts, closed_u, closed_v, smooth_u, smooth_v) =
  let (si, sj) = size(pts),
      vcs = add_z.(pts, 1) .- pts,
      idxs = quad_grid_indexes(si, sj, closed_u, closed_v)
    write_povray_object(io, "mesh2", nothing) do
      write_povray_object(io, "vertex_vectors", nothing, si*sj, reshape(permutedims(pts), :)...)
      # Must understand how to handle smoothness along one direction
      if smooth_u && smooth_v
        write_povray_object(io, "normal_vectors", nothing, si*sj, reshape(permutedims(vcs), :)...)
      end
      write_povray_object(io, "face_indices", nothing, length(idxs), idxs...)
      # Must understand how to handle smoothness along one direction
      #write_povray_object(buf, "normal_indices", nothing, length(idxs), idxs...)
      write_povray_material(io, mat)
    end
  end

write_povray_isosurface(io::IO, mat, func, contained_by, max_gradient) =
  write_povray_object(io, "isosurface", mat) do
    write_povray_object(io, "function", nothing, func)
    write_povray_object(io, "contained_by", nothing, contained_by)
    write_povray_param(io, "max_gradient", max_gradient)
  end

#=
struct POVRayPigment
  color::RGB
end

show(io::IO, mime::MIMEPOVRay, p::POVRayPigment) =
  write_povray_object(io, mime, "pigment") do
    show(io, mime, p.color)
  end

#=
NORMAL:
  normal { [NORMAL_IDENTIFIER] [NORMAL_TYPE] [NORMAL_MODIFIER...] }
NORMAL_TYPE:
  PATTERN_TYPE Amount |
  bump_map { BITMAP_TYPE "bitmap.ext" [BUMP_MAP_MODS...]}
NORMAL_MODIFIER:
  PATTERN_MODIFIER | NORMAL_LIST | normal_map { NORMAL_MAP_BODY } |
  slope_map{ SLOPE_MAP_BODY } | bump_size Amount |
  no_bump_scale Bool | accuracy Float
=#

struct POVRayNormal
  type::String
  amount::Real
end

povray_normal(; bumps) =
  POVRayNormal("bumps", bumps)

show(io::IO, mime::MIMEPOVRay, n::POVRayNormal) =
  write_povray_object(io, mime, "normal") do
    write_povray_param(io, mime, n.type, n.amount)
  end

#=
FINISH:
  finish { [FINISH_IDENTIFIER] [FINISH_ITEMS...] }
FINISH_ITEMS:
  ambient COLOR | diffuse [albedo] Amount [, Amount] | emission COLOR |
  brilliance Amount | phong [albedo] Amount | phong_size Amount | specular [albedo] Amount |
  roughness Amount | metallic [Amount] | reflection COLOR |
  crand Amount | conserve_energy BOOL_ON_OFF |
  reflection { Color_Reflecting_Min [REFLECTION_ITEMS...] } |
  subsurface { translucency COLOR } |
  irid { Irid_Amount [IRID_ITEMS...] }
REFLECTION_ITEMS:
  COLOR_REFLECTION_MAX | fresnel BOOL_ON_OFF |
  falloff FLOAT_FALLOFF | exponent FLOAT_EXPONENT |
  metallic FLOAT_METALLIC
IRID_ITEMS:
  thickness Amount | turbulence Amount
=#

struct POVRayFinish
  ambient::Union{RGB,Nothing}
  diffuse::Union{Real,Nothing}
  emission::Union{RGB,Nothing}
  brilliance::Union{Real,Nothing}
  phong::Union{Real,Nothing}
  phong_size::Union{Real,Nothing}
  specular::Union{Real,Nothing}
  roughness::Union{Real,Nothing}
  metallic::Union{Real,Nothing}
  reflection::Union{RGB,Nothing}
  crand::Union{Real,Nothing}
  conserve_energy::Union{Bool,Nothing}
  subsurface::Any
  irid::Any
end

povray_finish(; ambient::Union{RGB,Nothing}=nothing,
                diffuse::Union{Real,Nothing}=nothing,
                emission::Union{RGB,Nothing}=nothing,
                brilliance::Union{Real,Nothing}=nothing,
                phong::Union{Real,Nothing}=nothing,
                phong_size::Union{Real,Nothing}=nothing,
                specular::Union{Real,Nothing}=nothing,
                roughness::Union{Real,Nothing}=nothing,
                metallic::Union{Real,Nothing}=nothing,
                reflection::Union{RGB,Nothing}=nothing,
                crand::Union{Real,Nothing}=nothing,
                conserve_energy::Union{Bool,Nothing}=nothing,
                subsurface::Any=nothing,
                irid::Any=nothing) =
  POVRayFinish(ambient,
               diffuse,
               emission,
               brilliance,
               phong,
               phong_size,
               specular,
               roughness,
               metallic,
               reflection,
               crand,
               conserve_energy,
               subsurface,
               irid)

show(io::IO, mime::MIMEPOVRay, f::POVRayFinish) =
  write_povray_object(io, mime, "finish") do
    for name in fieldnames(typeof(f))
      let v = getfield(f, name)
        if ! isnothing(v)
          write_povray_param(io, mime, string(name), v)
        end
      end
    end
  end

struct POVRayTexture
  pygment::Union{POVRayPigment,Nothing}
  normal::Union{POVRayNormal,Nothing}
  finish::Union{POVRayFinish,Nothing}
end

struct POVRayLibraryTexture
  name::String
end

show(io::IO, mime::MIMEPOVRay, m::POVRayLibraryTexture) =
  write_povray_object(io, mime, "texture") do
    show(io, mime, m.name)
    #show(io, mime, m.interior)
  end

show(io::IO, mime::MIMEPOVRay, t::POVRayTexture) =
  write_povray_object(io, mime, "texture") do
    show(io, mime, t.pygment)
    show(io, mime, t.normal)
    show(io, mime, t.finish)
  end

struct POVRayInterior
  pygment::Union{POVRayPigment,Nothing}
  normal::Union{POVRayNormal,Nothing}
  finish::Union{POVRayFinish,Nothing}
end

struct POVRayMaterial
  name::String
  texture::POVRayTexture
  interior::Union{POVRayInterior,Nothing}
end
=#

abstract type POVRayMaterial end

struct POVRayDefinition <: POVRayMaterial
  name::String
  kind::String
  description::String
end

convert_to_povray_identifier(name) = replace(name, " " => "_")

write_povray_definition(io::IO, d::POVRayDefinition) =
  write(io, "#declare $(convert_to_povray_identifier(d.name)) =\n  $(d.kind) $(d.description)\n")

show(io::IO, ::MIMEPOVRay, d::POVRayDefinition) =
  write(io, "$(d.kind) { $(convert_to_povray_identifier(d.name)) }")

struct POVRayInclude <: POVRayMaterial
  filename::AbstractString
  kind::String
  name::String
end

write_povray_definition(io::IO, m::POVRayInclude) =
  write(io, "#include \"$(m.filename)\"\n")

show(io::IO, ::MIMEPOVRay, m::POVRayInclude) =
  write(io, "$(m.kind) { $(m.name) }")

export povray_definition, povray_include, povray_material
const povray_definition = POVRayDefinition
const povray_include = POVRayInclude

const povray_concrete =
  povray_definition("Concrete", "texture", """{
   pigment {
     granite turbulence 1.5 color_map {
       [0  .25 color White color Gray75] [.25  .5 color White color Gray75]
       [.5 .75 color White color Gray75] [.75 1.1 color White color Gray75]}}
  finish {
    ambient 0.2 diffuse 0.3 crand 0.03 reflection 0 }
  normal {
    dents .5 scale .5 }}""")

const povray_neutral =
  povray_definition("Material", "texture",
    "{ pigment { color rgb 0.3 } finish { reflection 0 ambient 0 }}")

povray_material(name::String;
                gray::Real=0.3,
                red::Real=gray, green::Real=gray, blue::Real=gray,
                specularity=0, roughness=0,
                transmissivity=nothing, transmitted_specular=nothing) =
  povray_definition(name, "texture", """{
  pigment { rgb <$(Float64(red)),$(Float64(green)),$(Float64(blue))> }
  finish { specular $(specularity) roughness $(roughness) }
}""")

const povray_grass =
  povray_definition("Grass", "texture",
   "{ pigment{ color <0.2,0.5,0.1>*0.5} normal { bumps 0.5 scale 0.005 }}")

const povray_gray_ground =
  povray_definition("Ground", "texture", "{ pigment { color rgb 0.8 } finish { reflection 0 ambient 0 }}")

#=
IMAGE_MAP:
  pigment {
    image_map {
      [BITMAP_TYPE] "bitmap[.ext]" [gamma GAMMA] [premultiplied BOOL]
      [IMAGE_MAP_MODS...]
      }
  [PIGMENT_MODFIERS...]
  }
 IMAGE_MAP:
  pigment {
   image_map {
     FUNCTION_IMAGE
     }
  [PIGMENT_MODFIERS...]
  }
 BITMAP_TYPE:
   exr | gif | hdr | iff | jpeg | pgm | png | ppm | sys | tga | tiff
 IMAGE_MAP_MODS:
   map_type Type | once | interpolate Type |
   filter Palette, Amount | filter all Amount |
   transmit Palette, Amount | transmit all Amount
 FUNCTION_IMAGE:
   function I_WIDTH, I_HEIGHT { FUNCTION_IMAGE_BODY }
 FUNCTION_IMAGE_BODY:
   PIGMENT | FN_FLOAT | pattern { PATTERN [PATTERN_MODIFIERS] }
=#
povray_image_map_material(name::String; image_map, map_type=0) =
  povray_definition(name, "texture", """{
  pigment { image_map $(image_map) map_type $(map_type) }
  }""")

####################################################
# Sky models

povray_realistic_sky_string(turbidity, inner) = """
#version 3.7;
#include "colors.inc"
#include "CIE.inc"
#include "lightsys.inc"
#include "lightsys_constants.inc"
#include "sunpos.inc"
#declare Current_Turbidity = $(turbidity);
//To solve a bug in CIE_Skylight.in
#local fiLuminous=finish{ambient 0 emission 1 diffuse 0 specular 0 phong 0 reflection 0 crand 0 irid{0}}
#include "CIE_Skylight.inc"
global_settings {
  assumed_gamma 1.0
  radiosity {
  }
}
#default {finish {ambient 0 diffuse 1}}
light_source{
  $(inner)
  Light_Color(SunColor,3)
  translate SolarPosition
}
"""
# This one seems to work better. Still 3.5 though.

#=
povray_realistic_sky_string(turbidity, inner) = """
#version 3.5;
#include "colors.inc"
#include "CIE.inc"
#include "lightsys.inc"
#include "lightsys_constants.inc"
#include "sunpos.inc"
global_settings {
  assumed_gamma 1.0
  radiosity {
  }
}
#default {finish {ambient 0 diffuse 1}}
CIE_ColorSystemWhitepoint(Beta_ColSys, Daylight2Whitepoint(Kt_Daylight_Film))
CIE_GamutMapping(off)
#declare Lightsys_Brightness = 1.0;
#declare Lightsys_Filter = <1,1,1>;
#declare Al=38;    // sun altitude
#declare Az=100;   // sun rotation
#declare North=-z;
#declare DomeSize=1e5;
#declare Current_Turbidity = 5.0;
#declare Intensity_Mult = 0.7;
#include "CIE_Skylight.inc"
light_source{ 0
  Light_Color(SunColor,5)
  translate SolarPosition
}
"""
=#

povray_realistic_sky_string(altitude, azimuth, turbidity, withsun) =
  povray_realistic_sky_string(
    turbidity,
    "vrotate(<0,0,1000000000>,<-$(altitude),$(azimuth+180),0>)")

povray_realistic_sky_string(date, latitude, longitude, meridian, turbidity, withsun) =
  povray_realistic_sky_string(
    turbidity,
    """
#local xpto = SunPos($(year(date)), $(month(date)), $(day(date)), $(hour(date)), $(minute(date)), $(meridian), $(latitude), $(longitude));
vrotate(<0,0,1000000000>,<-Al,Az,0>)
""")

####################################################
# Clay models
povray_clay_settings_string() =
"""
#version 3.7;
global_settings {
  assumed_gamma 1.0
  radiosity {
      pretrace_start 64/image_width  //0.04
      pretrace_end 1/image_width     //0.002
      count 1000
      nearest_count 10
      error_bound 0.1
      recursion_limit 1
      low_error_factor 0.2 //0.7
      gray_threshold 0
      minimum_reuse 0.001  //0.01
      brightness 1.2
      adc_bailout 0.01/2
  }
}
sky_sphere {
    pigment {
      color rgb 1
    }
  }
"""

####################################################
abstract type POVRayKey end
const POVRayId = Any
const POVRayRef = NativeRef{POVRayKey, POVRayId}

const POVRay = IOBufferBackend{POVRayKey, POVRayId, Nothing}

KhepriBase.backend_name(::POVRay) = "POVRay"

# Traits
# Although we have boolean operation in POVRay at the level of shapes, we do
# not have boolean operations at the level of references
KhepriBase.has_boolean_ops(::Type{POVRay}) = HasBooleanOps{false}()

KhepriBase.void_ref(b::POVRay) = POVRayRef(-1)

const povray = POVRay()

KhepriBase.b_new_material(b::POVRay, name,
						              base_color,
						              metallic, specular, roughness,
	                        clearcoat, clearcoat_roughness,
						              ior,
						              transmission, transmission_roughness,
	                        emission_color,
						              emission_strength) =
  povray_material()
KhepriBase.b_plastic_material(b::POVRay, name, color, roughness) =
  povray_material()
KhepriBase.b_metal_material(b::POVRay, name, color, roughness, ior) =
  povray_material()
KhepriBase.b_glass_material(b::POVRay, name, color, roughness, ior) =
  povray_material()
KhepriBase.b_mirror_material(b::POVRay, name, color) =
  povray_material()

#
KhepriBase.b_trig(b::POVRay, p1, p2, p3, mat) =
  write_povray_object(connection(b), "triangle", mat, p1, p2, p3)

KhepriBase.b_surface_polygon(b::POVRay, ps, mat) =
  write_povray_object(connection(b), "polygon", mat, length(ps) + 1, ps..., ps[1])

KhepriBase.b_surface_polygon_with_holes(b::POVRay, ps, qss, mat) =
  let vss = [ps, qss...]
    write_povray_object(connection(b), "polygon", mat,
      mapreduce(length, +, vss) + length(vss),
      mapreduce(vs->[vs..., vs[1]], vcat, vss)...)
  end

KhepriBase.b_surface_circle(b::POVRay, c, r, mat) =
  	write_povray_object(connection(b), "disc", mat, c, uvz(c.cs), r)

KhepriBase.b_surface_grid(b::POVRay, ptss, closed_u, closed_v, smooth_u, smooth_v, interpolator, mat) =
  let io = connection(b),
      pts = smooth_u || smooth_v ?
              [location_at(interpolator, u, v)
               for u in division(0, 1, 4*size(ptss, 1)), v in division(0, 1, 4*size(ptss, 2))] :
              ptss,
      (si, sj) = size(pts),
      idxs = quad_grid_indexes(si, sj, closed_u, closed_v)
    write_povray_object(io, "mesh2", nothing) do
      write_povray_object(io, "vertex_vectors", nothing, si*sj, reshape(permutedims(pts), :)...)
      # Must understand how to handle smoothness along one direction
      if smooth_u || smooth_v
        write_povray_object(io, "normal_vectors", nothing, si*sj, reshape(permutedims(add_z.(pts, 1) .- pts), :)...)
      end
      write_povray_object(io, "face_indices", nothing, length(idxs), idxs...)
      #write_povray_object(buf, "normal_indices", nothing, length(idxs), idxs...)
      write_povray_material(io, mat)
    end
  end

KhepriBase.b_cylinder(b::POVRay, cb, r, h, bmat, tmat, smat) =
  let buf = connection(b)
    write_povray_object(buf, "cylinder", smat, [0,0,0], [0,0,h], r) do
      write_povray_matrix(buf, cb)
    end
    -1
  end

KhepriBase.b_sphere(b::POVRay, c, r, mat) =
  write_povray_object(connection(b), "sphere", mat, c, r)

KhepriBase.b_torus(b::POVRay, c, ra, rb, mat) =
  let buf = connection(b)
    write_povray_object(buf, "torus", mat, ra, rb) do
      write_povray_param(buf, "rotate", [90,0,0])
      write_povray_matrix(buf, c)
    end
    -1
  end

KhepriBase.b_box(b::POVRay, c, dx, dy, dz, mat) =
  let buf = connection(b)
    write_povray_object(buf, "box", mat, [0,0,0], [dx, dy, dz]) do
      write_povray_matrix(buf, c)
    end
    -1
  end

KhepriBase.b_cone(b::POVRay, cb, r, h, bmat, smat) =
  write_povray_object(connection(b), "cone", smat, cb, r, add_z(cb, h), 0)

KhepriBase.b_cone_frustum(b::POVRay, cb, rb, h, rt, bmat, tmat, smat) =
  write_povray_object(connection(b), "cone", smat, cb, rb, add_z(cb, h), rt)

# This works (including the smooth bit) BUT
# 1. It does not seem to run faster on POVRay than multiple polygons
# 2. It does not support multiple materials
# 3. The vector must be strictly perpendicular to the profile
# So..., I'm disabling it for now.
# KhepriBase.b_generic_prism(b::POVRay, bs, smooth, v, bmat, tmat, smat) =
#   let buf = connection(b),
#       cs = cs_from_o_vz(bs[1], -v),
#       ps = [[p.x, p.y] for p in in_cs(bs, cs)]
#     write_povray_object(buf, "prism", smat) do
#       if smooth
#         write(buf, "linear_sweep cubic_spline ")
#         write_povray_values(buf, [0, norm(v), length(ps) + 3, ps[end], ps..., ps[1], ps[2]])
#       else
#         write(buf, "linear_sweep linear_spline ")
#         write_povray_values(buf, [0, norm(v), length(ps) + 1, ps..., ps[1]])
#       end
#       write_povray_matrix(buf, u0(rotated_x_cs(cs, -pi/2)))
#       -1
#     end
#   end
#

b_isosurface(b::POVRay, frep, bounding_box, mat) =
  write_povray_isosurface(connection(b), mat, func, bounding_box, max_gradient)

#=
###################################

KhepriBase.b_realistic_sky(b::POVRay, date, latitude, longitude, elevation, meridian, altitude, azimuth, turbidity, with_sun) =
  b.sky = povray_realistic_sky_string(date, latitude, longitude, meridian, turbidity, withsun)

# backend_realistic_sky(b::POVRay, altitude, azimuth, turbidity, withsun) =
#   b.sky = povray_realistic_sky_string(altitude, azimuth, turbidity, withsun)
=#

#=
#=

realize(b::POVRay, s::SweepPath) =
  let vertices = in_world.(path_vertices(s.profile)),
      frames = map_division(identity, s.path, 20),
      buf = connection(b),
      mat = get_material(b, s)
    write_povray_mesh(
      buf,
      mat,
      [xyz(cx(p), cy(p), cz(p), frame.cs) for p in vertices, frame in frames],
      is_closed_path(s.profile),
      is_closed_path(s.path),
      is_smooth_path(s.profile),
      is_smooth_path(s.path))
    void_ref(b)
  end

# HACK: JUST FOR TESTING
realize(b::POVRay, s::Thicken) =
  realize(b, s.shape)
=#
#=
realize(b::POVRay, s::Move) =
  let buf = connection(b)
    write_povray_object(buf, "object", nothing) do
      ref(b, s.shape)
      backend_delete_shape(b, s.shape)
      write_povray_param(buf, "translate", s.v)
    end
  end

realize(b::POVRay, s::Scale) =
  let buf = connection(b),
      trans = s.p-u0()
    write_povray_object(buf, "object", nothing) do
      ref(b, s.shape)
      backend_delete_shape(b, s.shape)
      write_povray_param(buf, "translate", -trans)
      write_povray_param(buf, "scale", s.s)
      write_povray_param(buf, "translate", trans)
    end
  end

realize(b::POVRay, s::Rotate) =
  let buf = connection(b),
      trans = s.p-u0()
    write_povray_object(buf, "object", nothing) do
      ref(b, s.shape)
      backend_delete_shape(b, s.shape)
      write_povray_param(buf, "translate", -trans)
      write_povray_call(buf, "Axis_Rotate_Trans", s.v, -rad2deg(s.angle))
      write_povray_param(buf, "translate", trans)
    end
  end

realize(b::POVRay, s::UnionShape) =
  let shapes = filter(! is_empty_shape, s.shapes)
    length(shapes) == 1 ?
      (ref(b, shapes[1]); backend_delete_shape(b, shapes[1])) :
      write_povray_object(connection(b), "union", nothing) do #get_material(b, s)) do
        for ss in shapes
          ref(b, ss)
          backend_delete_shape(b, ss)
        end
      end
    void_ref(b)
  end


realize(b::POVRay, s::IntersectionShape) =
  write_povray_object(connection(b), "intersection", get_material(b, s)) do
    for ss in s.shapes
      ref(b, ss)
      backend_delete_shape(b, ss)
    end
    void_ref(b)
  end

realize(b::POVRay, s::SubtractionShape3D) =
  write_povray_object(connection(b), "difference", get_material(b, s)) do
    ref(b, s.shape)
    backend_delete_shape(b, s.shape)
    for ss in s.shapes
      ref(b, ss)
      backend_delete_shape(b, ss)
    end
    void_ref(b)
  end

=#
=#
KhepriBase.b_pointlight(b::POVRay, loc::Loc, color::RGB, intensity::Real, range::Real) =
  write_povray_pointlight(connection(b), loc, rgb(red(color)*intensity, green(color)*intensity, blue(color)*intensity))

export povray_family_materials

povray_family_materials(m1, m2=m1, m3=m2, m4=m3) = (materials=(m1, m2, m3, m4), )

export povray_stone, povray_metal, povray_wood, povray_glass

povray_stone = povray_include("stones2.inc", "texture", "T_Stone35")
povray_metal = povray_include("textures.inc", "texture", "Chrome_Metal")
#povray_wood = povray_include("textures.inc", "texture", "DMFWood1")
povray_wood = povray_include("woods.inc", "texture", "T_Wood10")
povray_glass = povray_include("textures.inc", "material", "M_Glass")

#=

use_family_in_layer(b::POVRay) = true

#=
create_ground_plane(shapes, material=default_povray_ground_material()) =
  if shapes == []
    error("No shapes selected for analysis. Use add-povray-shape!.")
  else
    let (p0, p1) = bounding_box(union(shapes)),
        (center, ratio) = (quad_center(p0, p1, p2, p3),
                  distance(p0, p4)/distance(p0, p2));
     ratio == 0 ?
      error("Couldn"t compute height. Use add-povray-shape!.") :
      let pts = map(p -> intermediate_loc(center, p, ratio*10), [p0, p1, p2, p3]);
         create_surface_layer(pts, 0, ground_layer(), material)
        end
       end
  end
        w = max(floor_extra_factor()*distance(p0, p1), floor_extra_width())
        with(current_layer,floor_layer()) do
          box(xyz(min(p0.x, p1.x)-w, min(p0.y, p1.y)-w, p0.z-1-floor_distance()),
              xyz(max(p0.x, p1.x)+w, max(p0.y, p1.y)+w, p0.z-0-floor_distance()))
        end
      end
    end

=#

realize(b::POVRay, s::Union{Door, Window}) =
  void_ref(b)
=#

povray_environment_string(b::POVRay, env::RealisticSkyEnvironment) =
  povray_realistic_sky_string(
    b.date,
    b.place.latitude,
    b.place.longitude,
    b.place.meridian,
    b.render_env.turbidity,
    b.render_env.sun)

povray_environment_string(b::POVRay, env::ClayEnvironment) =
  povray_clay_settings_string()

####################################################

export_to_povray(b::POVRay, path::String) =
  let buf = connection(b)
    realize_shapes(b)
    open(path, "w") do out
      # write the sky
      write(out, povray_environment_string(b, b.render_env))
      # write useful include
      write(out, """#include "transforms.inc"\n""")
      # write materials (removing duplicate includes)
      for m in unique(m->m isa POVRayInclude ? m.filename : m,
                      material_refs(b, used_materials(b)))
        write_povray_definition(out, m)
      end
      # write the ground
      if !isnothing(b.ground_material)
        write_povray_object(out, "plane", material_ref(b, b.ground_material), :y, b.ground_level)
      end
      # write the objects
      let str = String(take!(buf))
        #save again
        println(buf, str)
        write(out, str)
      end
      # write the view
      write_povray_camera(out, b.view.camera, b.view.target, b.view.lens)
    end
  end

povray_cmd() =
  @static Sys.iswindows() ?
    "C:/Program Files/POV-Ray/v3.7/bin/pvengine64" :
    (@static Sys.isunix() ?
      realpath(normpath(@__DIR__, "..", "bin", "povray")) :
      error("Unsupported operating system!"))

const povray_lib = Parameter(realpath(normpath(@__DIR__, "..", "lib", "include")))
const LightsysIV_lib = Parameter(realpath(normpath(@__DIR__, "..", "lib", "LightsysIV")))

##########################################
export rendered_image_area
rendered_image_area = Parameter{Union{Missing,Tuple{Int,Int,Int,Int}}}(missing)

KhepriBase.b_render_view(b::POVRay, path::String) =
  let povpath = path_replace_suffix(path, ".pov"),
      inipath = path_replace_suffix(path, ".ini"),
      options = @static(Sys.iswindows() ? (film_active() ? ["-D", "/EXIT", "/RENDER"] : ["/RENDER"]) : []),
      cmd = `$(povray_cmd()) $options "$inipath"`
    @info cmd
    export_to_povray(b, povpath)
    open(inipath, "w") do out
      #println(out, "Debug_Console=off")
      println(out, "Library_Path='$(povray_lib())'")
      println(out, "Library_Path='$(LightsysIV_lib())'")
      println(out, "Width=$(render_width())")
      println(out, "Height=$(render_height())")
      println(out, "Antialias=on")
      println(out, "Quality=10")
      println(out, "High_Reproducibility=on")
      println(out, "Input_File_Name='$(povpath)'")
      if ! ismissing(rendered_image_area())
        let (start_col, start_row, end_col, end_row) = rendered_image_area()
          println(out, "Start_Row=", start_row)
          println(out, "Start_Column=", start_col)
          println(out, "End_Row=", end_row)
          println(out, "End_Column=", end_col)
        end
      end
    end
    run(cmd, wait=@static(Sys.iswindows() ? film_active() : true))
  end

export clay_model, realistic_model
clay_model(level::Real=0, b::POVRay=povray) =
  begin
    b.sky = povray_clay_settings_string()
    b.ground_level = level
    b.ground_material = povray_definition("Ground", "texture", "{ pigment { color rgb 3 } finish { reflection 0 ambient 0 }}")
  end

realistic_model(level::Real=0, b::POVRay=povray) =
  begin
    b.sky = povray_realistic_sky_string(DateTime(2020, 9, 21, 10, 0, 0), 39, 9, 0, 5, true)
    b.ground_level = level
    b.ground_material = povray_gray_ground
  end
