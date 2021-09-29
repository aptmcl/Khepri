### PLugin
#=
Whenever the plugin is updated, run this function and commit the plugin files.
upgrade_plugin()
=#

const khepri_grasshopper_dlls = ["KhepriGrasshopper.gha", "FastColoredTextBox.dll"]
const julia_khepri = dirname(dirname(abspath(@__FILE__)))

upgrade_plugin() =
  let # 1. The dlls are updated in VisualStudio after compilation of the plugin, and they are stored in the folder
      #    contained inside the Plugins folder, which has a specific location regarding this file itself
      plugin_folder = joinpath(dirname(dirname(julia_khepri)), "Plugins", "KhepriGrasshopper", "KhepriGrasshopper", "bin")
      # 2. The bundle needs to be copied to the current folder
      local_folder = joinpath(julia_khepri, "Plugin")
      # 3. Now we copy the dlls to the local folder
      for dll in khepri_grasshopper_dlls
          src = joinpath(plugin_folder, dll)
          dst = joinpath(local_folder, dll)
          rm(dst, force=true)
          cp(src, dst)
      end
  end

#

update_plugin() =
  let grasshopper_user_plugins = joinpath(ENV["APPDATA"], "Grasshopper", "Libraries"),
      local_khepri_plugin = joinpath(julia_khepri, "Plugin")
    for dll in khepri_grasshopper_dlls
      let local_path = joinpath(local_khepri_plugin, dll),
          grasshopper_path = joinpath(grasshopper_user_plugins, dll)
          cp(local_path, grasshopper_path, force=true)
      end
    end
  end

#=
We want to support these two syntaxes

a < Number
a < Number("Number")
a < Number("Number", "N")
a < Number("Number", "N", "Parameter N")
a < Number("Number", "N", "Parameter N", 0.0)

a < Number(0.0)
a < Number("Number", 0.0)
a < Number("Number", "N", 0.0)
a < Number("Number", "N", "Parameter N", 0.0)

a < String()
a < String("String")
a < String("String")
a < Number(0.0, "a")

=#

in_gh(sym) = Symbol("GH$(sym)")
kgh_io_function_names = Symbol[]
is_kgh_io_function_name(sym) =
  sym in kgh_io_function_names

macro ghdef(name, init)
  let str = string(name),
      ghname = esc(in_gh(name))
    quote
      push!(kgh_io_function_names, $(QuoteNode(name)))
      $(ghname)(description::Base.String, short_description=description[1:1], message=description*" parameter", value=$init) =
        [$(str), description, short_description, message, value]
      $(ghname)(value::Base.Any, description=$(str), short_description=description[1:1], message=description*" parameter") =
        [$(str), description, short_description, message, value]
    end
  end
end

#Strings require conversion to avoid SubStrings!!!!!!!
@ghdef(String, "")
@ghdef(Path, "")
@ghdef(Boolean, false)
@ghdef(Number, 0.0)
@ghdef(Integer, 0)
@ghdef(Point, u0())
@ghdef(Vector, vx(1))
@ghdef(Any, nothing)
@ghdef(Eval, nothing)
@ghdef(JL, nothing)
@ghdef(Strings, [])
@ghdef(Paths, [])
@ghdef(Booleans, [])
@ghdef(Numbers, [])
@ghdef(Integers, [])
@ghdef(Points, [])
@ghdef(Vectors, [])
@ghdef(Many, [])
@ghdef(Evals, [])
@ghdef(JLs, [])
@ghdef(Stringss, [])
@ghdef(Pathss, [])
@ghdef(Booleanss, [])
@ghdef(Numberss, [])
@ghdef(Integerss, [])
@ghdef(Pointss, [])
@ghdef(Vectorss, [])
@ghdef(Manies, [])
@ghdef(Evalss, [])
@ghdef(JLss, [])

export define_kgh_function

kgh_forms(text, idx=1) =
  let (expr, idx) = Meta.parse(text, idx, greedy=true, depwarn=false)
    isnothing(expr) ?
      [] :
      [expr, kgh_forms(text, idx)...]
  end

is_kgh_io_function_call(e) =
  e isa Expr && e.head === :call && is_kgh_io_function_name(e.args[1])

match_expr(e1, e2) =
  e2 === :_ ||
  e1 == e2 ||
  e1 isa Expr && e2 isa Expr &&
  match_expr(e1.head, e2.head) &&
  length(e1.args) == length(e2.args) &&
  all([match_expr(e1, e2) for (e1, e2) in zip(e1.args, e2.args)])

is_kgh_input(form) =
  match_expr(form, :(_ < _)) &&
  is_kgh_io_function_call(form.args[3])
is_kgh_output(form) =
  (match_expr(form, :(_ > _)) &&
   is_kgh_io_function_call(form.args[3])) ||
  is_kgh_io_function_call(form)

kgh_io_param(form) =
  form.args[2] == :_ ? :__result : form.args[2]
kgh_io_call(form) =
  let param = form.args[2],
      form = form.args[3],
      func = Expr(:., :KhepriGrasshopper, QuoteNode(in_gh(form.args[1])))
    match_expr(form, :(_())) ||
    (match_expr(form, :(_(_))) && !(form.args[2] isa String)) ?
        :($(func)($(form.args[2:end]...), $(string(param)))) :
        :($(func)($(form.args[2:end]...)))
  end

kgh_inputs(forms) = filter(is_kgh_input, forms)
kgh_outputs(forms) = filter(is_kgh_output, forms)

create_kgh_function(name::String, body::String) =
  let forms = kgh_forms(body),
      inputs = filter(is_kgh_input, forms),
      outputs = filter(is_kgh_output, forms),
      forms = filter(f -> !(f in inputs || f in outputs), forms),
      inp_params = map(kgh_io_param, inputs),
      out_params = map(kgh_io_param, outputs),
      inp_forms = map(kgh_io_call, inputs),
      out_forms = map(kgh_io_call, outputs),
      inps = Symbol("__inps_$name"),
      inp_inits = [:($(inp) = $(inps)[$(i)]) for (i, inp) in enumerate(inp_params)],
      outs = Symbol("__outs_$name"),
      out_inits = [:($(outs)[$(i)] = $(out)) for (i, out) in enumerate(out_params)],
      inp_docs = Symbol("__doc_inps_$name"),
      out_docs = Symbol("__doc_outs_$name"),
      shapes = Symbol("__shapes_$name"),
      prev_collected_shapes = gensym("prev_collected_shapes")
    if isempty(inp_forms) && isempty(out_forms)
      quote
        $(inp_docs) = Any[$(inp_forms...)]
        $(out_docs) = Any[$(out_forms...)]
        $(inps) = Array{Any,1}(undef, $(length(inp_inits)))
        $(outs) = Array{Any,1}(undef, $(length(out_inits)))
        $(shapes) = Shape[]
        function $(Symbol("__func_$name"))()
          nothing
        end
      end
    else
      quote
        $(inp_docs) = Any[$(inp_forms...)]
        $(out_docs) = Any[$(out_forms...)]
        $(inps) = Array{Any,1}(undef, $(length(inp_inits)))
        $(outs) = Array{Any,1}(undef, $(length(out_inits)))
        $(shapes) = Shape[]
        function $(Symbol("__func_$name"))()
          $(inp_inits...)
          $prev_collected_shapes = collected_shapes()
          collected_shapes($(shapes))
          __result = try
            $(forms...)
          finally
            collected_shapes($prev_collected_shapes)
          end
          $(out_inits...)
          nothing
        end
      end
    end
  end

define_kgh_function(name::String, body::String) =
  Base.eval(Main, create_kgh_function(name, body))

#=
fn = """
  a < Number("Number", "N", "Parameter N", 0.0)
  b < Any()
  c < Number(5)
  d < String("Foo")

  f(a + b)

  c = a + 1

  c > Any()
  d > Strings("Bar")
"""

create_kgh_function("foo", fn)
=#

#=
fn = """
a < Number("Number", "N", "Parameter N", 0.0)
b < Any()
c < Number(5)
d < String("Foo")

f(a + b)

c = a + 1

c > Any()
d > String("Bar")
"""

create_kgh_function("foo", fn)

=#

#=
fn = """
a < Number("Number", "N", "Parameter N", 0.0)
b < Any()
c < Number(5)
d < String("Foo")
e > String("Bar")
_ > Number()

e = f(a + b)
g(b*c)
"""

create_kgh_function("foo", fn)

fn2 = """
e = f(a + b)
g(b*c)
"""

create_kgh_function("foo", fn2)
using InteractiveUtils
InteractiveUtils.@code_lowered KhepriBase.foo()
=#
#=
fn = """
a < Number("Number", "N", "Parameter N", 0.0)
b < Any()
c < Number(5)
d < String("Foo")

f(a + b)

c = a + 1

c > Any()
d > String("Bar")
"""

eval(create_kgh_function("foo", fn))
=#

#=
create_kgh_function("foo", raw"""
path < String()
autos < Numbers()
costs < Numbers()

open(path, "w") do f
  for (a, c) in zip(autos, costs)
    println(f, "$a $c")
  end
end
""")

dump(:("foo $bar"))

=#

#=
str1 = """# v < Type("Input", "I", "Parameter I", default)
a < Number(2)
b < Number(3)
_ > Number()

sqrt(a^2 + b^2)"""

create_kgh_function("zzz", str1)
=#

#=
a < Number()
b < Number()
sphere(x(a), b)

create_kgh_function("zzz", str1)
=#
#=
example = raw"""
generate_outline_vertices(p, area, prop) =
  let l = sqrt(area/prop)
      w = area/l
      [add_xy(p, 0, 0), add_xy(p, w, 0), add_xy(p, w, l), add_xy(p, 0, l)]
  end

areas = 50:50:200
wwrs = 0.2:0.2:0.4
rots = 0:pi/4:pi/2
props = 1:2:5
epocas = [1, 3, 4, 5, 6, 7, 8, 9]
kinds = [1, 2]
stors = 2:3:11
ddy = sqrt(maximum(areas))


Wmaterials = [[[0, "Reboco - 2cm", "Pedra", "Estuque_Claro_1.5"], [15.7, "Reboco - 2cm", "OSB - 2cm", "AirGap", "Isolamento XPS - 4cm", "Pedra", "Estuque_Claro_1.5" ]],
              [[0, "Reboco - 2cm", "Pedra", "Estuque_Claro_1.5"], [15.7, "Reboco - 2cm", "OSB - 2cm", "AirGap", "Isolamento XPS - 4cm", "Pedra", "Estuque_Claro_1.5" ]],
              [[0, "Reboco - 2cm", "Pedra", "AirGap", "Tijolo Furado_11", "Estuque_Claro_1.5"], [7, "Reboco - 2cm", "Pedra", "AirGap", "Isolamento XPS - 4cm", "Tijolo Furado_11", "Estuque_Claro_1.5"]],
              [[0, "Reboco - 2cm", "Tijolo Furado_15", "AirGap", "Tijolo Furado_11", "Estuque_Claro_1.5"], [7, "Reboco - 2cm", "Tijolo Furado_15", "AirGap", "Isolamento XPS - 4cm", "Tijolo Furado_11", "Estuque_Claro_1.5"]],
              [[0, "Reboco - 2cm", "Tijolo Furado_11", "AirGap", "Tijolo Furado_11", "Estuque_Claro_1.5"], [7, "Reboco - 2cm", "Tijolo Furado_11", "AirGap", "Isolamento XPS - 4cm", "Tijolo Furado_11", "Estuque_Claro_1.5"]],
              [[0, "Reboco - 2cm", "Tijolo Furado_15", "AirGap", "Isolamento XPS - 4cm", "Tijolo Furado_11", "Estuque_Claro_1.5"], [7, "Reboco - 2cm", "Tijolo Furado_15", "AirGap", "Isolamento XPS - 4cm", "Isolamento XPS - 4cm", "Tijolo Furado_11", "Estuque_Claro_1.5"]],
              [[0, "Reboco - 2cm", "OSB - 2cm", "AirGap", "Isolamento XPS - 4cm", "Tijolo Furado_22", "Estuque_Claro_1.5"], [7, "Reboco - 2cm", "OSB - 2cm", "AirGap", "Isolamento XPS - 4cm", "Isolamento XPS - 4cm", "Tijolo Furado_22", "Estuque_Claro_1.5"]],
              [[0, "Reboco - 2cm", "Isolamento EPS - 6cm", "Tijolo Furado_22", "Estuque_Claro_1.5"], [7, "Reboco - 2cm", "OSB - 2cm", "Isolamento XPS - 4cm", "Isolamento EPS - 6cm", "Tijolo Furado_22", "Estuque_Claro_1.5"]],
              [[0, "Chapa Metalica", "Isolamento EPS - 4cm", "Isolamento EPS - 6cm", "Isolamento EPS - 6cm", "Estuque_Claro_1.5"], [7, "Chapa Metalica", "Isolamento XPS - 4cm", "Isolamento EPS - 4cm", "Isolamento EPS - 6cm", "Isolamento EPS - 6cm", "Estuque_Claro_1.5"]],
              [[0, "Chapa Metalica", "Isolamento EPS - 4cm", "Isolamento EPS - 6cm", "Isolamento EPS - 6cm", "Estuque_Claro_1.5"], [7, "Chapa Metalica", "Isolamento XPS - 4cm", "Isolamento EPS - 4cm", "Isolamento EPS - 6cm", "Isolamento EPS - 6cm", "Estuque_Claro_1.5"]]]

Fmaterials = [[[0, "Paineis de Madeira_12", "Estuque_Claro_1.5"]],
              [[0, "Paineis de Madeira_12", "Estuque_Claro_1.5"]],
              [[0, "Paineis de Madeira_12", "Estuque_Claro_1.5"]],
              [[0, "Ceramica vidrada - 1cm", "Betonilha de Acentamento_8", "Laje Betao_15", "Estuque_Claro_1.5"]],
              [[0, "Ceramica vidrada - 1cm", "Betonilha de Acentamento_8", "Laje Betao_15", "Estuque_Claro_1.5"]],
              [[0, "Ceramica vidrada - 1cm", "Betonilha de Acentamento_8", "Laje Betao_15", "Estuque_Claro_1.5"]],
              [[0, "Ceramica vidrada - 1cm", "Betonilha de Acentamento_8", "Laje Betao_15", "Estuque_Claro_1.5"]],
              [[0, "Ceramica vidrada - 1cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Ceramica vidrada - 1cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Ceramica vidrada - 1cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]]]

Rmaterials = [[[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]],
              [[0, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"], [7.5, "Betonilha de Acentamento_8", "Tela impermeabilizacao - 2mm", "Isolamento XPS - 4cm", "Betonilha de Acentamento_8", "Laje Aligeirada_0.25", "Estuque_Claro_1.5"]]]


Windowmaterials = [[[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]],
                   [[[0, "2.69, 0.75, 0.8"], [50, "1.70, 0.38, 0.7"]]]]
vertss = []
grsn = []
grse = []
grss = []
grsw = []
Wmats = []
Rmats = []
Fmats = []
Windowmats = []
Storeys = []
dy = 0



for epoca in epocas
  dx = 0
  for wall in kinds, roof in kinds, window in kinds
    for wwr in wwrs
      for area in areas
        for rot in rots
          for prop in props, stor in stors
            for wn in [0, wwr], we in [0, wwr], ws in [0, wwr], ww in [0, wwr]
              push!(vertss, generate_outline_vertices(loc_from_o_phi(xy(dx, dy), rot), area, prop))
              push!(grsn, wn)
              push!(grse, we)
              push!(grss, ws)
              push!(grsw, ww)
              push!(Wmats, Wmaterials[epoca][wall])
              push!(Rmats, Rmaterials[epoca][roof])
              push!(Windowmats, Windowmaterials[epoca][window])
              push!(Fmats, Fmaterials[epoca][1])
              push!(Storeys, stor)
              dx += sqrt(area) + 10
            end
          end
        end
      end
    end
  end
  dy += ddy + 10
end

vertss > JLs("Verticess JL")
grsn > Numbers("WWR'North")
grse > Numbers("WWR'East")
grss > Numbers("WWR'South")
grsw > Numbers("WWR'West")
Storeys > Integers("Number of floors")
Wmats > JLs("Wall materials JL")
Rmats > JLs("Roof materials JL")
Fmats > JLs("Floor materials JL")
Windowmats > JLs("Window materials JL")
"""

print(create_kgh_function("zzz", example))
=#
