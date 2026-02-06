import Frame4DD as F4DD

export frame4dd,
       frame4dd_circular_tube_truss_bar_family

@kwdef struct Frame4DDBackend{K,T} <: LazyBackend{K,T}
  realized::Parameter{Bool}=Parameter(false)
  truss_nodes::Vector{<:TrussNode}=TrussNode[]
  truss_bars::Vector{<:TrussBar}=TrussBar[]
  shapes::Vector{<:Shape}=Shape[]
  truss_node_data::Vector{TrussNodeData}=TrussNodeData[]
  truss_bar_data::Vector{TrussBarData}=TrussBarData[]
  view::View=default_view()
  refs::References{K,T}=References{K,T}()
end

abstract type FR4DDKey end
const FR4DDId = Any
const FR4DDNativeRef = NativeRef{FR4DDKey, FR4DDId}
const FR4DD = Frame4DDBackend{FR4DDKey, FR4DDId}

void_ref(b::FR4DD) = FR4DDNativeRef(-1)

const frame4dd = FR4DD()

KhepriBase.backend_name(b::FR4DD) = "Frame4DD"

# Frame4DD needs to merge nodes and bars
save_shape!(b::FR4DD, s::TrussNode) = maybe_merged_node(b, s)
save_shape!(b::FR4DD, s::TrussBar) = maybe_merged_bar(b, s)

# Frame4DD does not need layers
use_material_as_layer(b::FR4DD) = false
KhepriBase.b_current_layer_ref(b::FR4DD) = nothing
KhepriBase.b_current_layer_ref(b::FR4DD, layer) = nothing

# Frame4DD Families
abstract type Frame4DDFamily <: Family end

Base.@kwdef struct Frame4DDTrussBarGeometry
  Ax  # cross section area
  Asy # shear area y-direction
  Asz # shear area z-direction
  Jxx # torsional moment of inertia - x axis
  Iyy # bending moment of inertia - y axis
  Izz # bending moment of inertia - z axis
end

Base.@kwdef struct Frame4DDTrussBarFamily <: Frame4DDFamily
  geometry=Ref{Any}(nothing) # properties that only depend on radius and thickness
  E   # elastic modulus
  G   # shear modulus
  p   # roll angle
  d   # mass density
end

export frame4dd_truss_bar_family
frame4dd_truss_bar_family = Frame4DDTrussBarFamily

truss_bar_family_cross_section_area(f::Frame4DDTrussBarFamily) =
  f.geometry[].Ax

#=
Circular Tube (outer radius= Ro, inner radius = Ri):

Ax = π ( Ro² - Ri² )
Asy = Asz = Ax / ( 0.54414 + 2.97294(Ri/Ro) - 1.51899(Ri/Ro)² ) ± 0.05%
Jxx = (1/2) π ( Ro⁴ - Ri⁴ )
Ixx = Iyy = (1/4) π ( Ro⁴ - Ri⁴ )
=#

export frame4dd_circular_tube_truss_bar_geometry
frame4dd_circular_tube_truss_bar_geometry(rₒ, e) =
  let rᵢ = rₒ - e,
      Ax = annulus_area(rₒ, rᵢ),
      Asyz = Ax/(0.54414 + 2.97294*(rᵢ/rₒ) - 1.51899*(rᵢ/rₒ)^2),
      Jxx = π/2*(rₒ^4 - rᵢ^4),
      Ixxyy = Jxx/2
    Frame4DDTrussBarGeometry(
      Ax =Ax,
      Asy=Asyz,
      Asz=Asyz,
      Jxx=Jxx,
      Iyy=Ixxyy,
      Izz=Ixxyy)
  end

backend_get_family_ref(b::FR4DD, f::TrussBarFamily, tbf::Frame4DDTrussBarFamily) =
  begin
    tbf.geometry[] = frame4dd_circular_tube_truss_bar_geometry(f.radius, f.radius-f.inner_radius)
    tbf
  end

KhepriBase.b_delete_all_shape_refs(b::FR4DD) =
  begin
    empty!(b.truss_nodes)
    empty!(b.truss_bars)
    b.realized(false)
    b
  end

realize(b::FR4DD, s::TrussNode) =
  error("BUM")

realize(b::FR4DD, s::TrussBar) =
  error("BUM")

realize(b::FR4DD, s::Panel) =
  error("BUM")

# Core analysis function — builds a Frame4DD.Model and solves it directly
KhepriBase.b_truss_analysis(b::FR4DD, load::Vec, self_weight::Bool, point_loads::Dict) =
  let nodes = process_nodes(b.truss_nodes, load, point_loads),
      bars = process_bars(b.truss_bars, nodes),
      supported_nodes = filter(truss_node_is_supported, nodes),
      loaded_nodes = filter(!truss_node_is_supported, nodes),
      model = F4DD.Model()
    empty!(b.truss_node_data)
    append!(b.truss_node_data, nodes)
    empty!(b.truss_bar_data)
    append!(b.truss_bar_data, bars)
    length(nodes) > 0 || error("The truss has no nodes.")
    length(bars) > 0 || error("The truss has no bars.")
    length(supported_nodes) > 0 || error("The truss has no supports.")
    # Add nodes
    for n in nodes
      F4DD.add_node!(model, n.loc.x, n.loc.y, n.loc.z)
    end
    # Fix supported nodes
    for n in supported_nodes
      let s = n.family.support
        F4DD.fix_node!(model, n.id;
          dx=s.ux, dy=s.uy, dz=s.uz,
          rx=s.rx, ry=s.ry, rz=s.rz)
      end
    end
    # Add elements
    for bar in bars
      let f = family_ref(b, bar.family),
          g = f.geometry[],
          section = F4DD.Section(g.Ax, g.Asy, g.Asz, g.Jxx, g.Iyy, g.Izz),
          material = F4DD.Material(f.E, f.G, f.d)
        F4DD.add_element!(model, bar.node1.id, bar.node2.id, section, material;
          roll=bar.rotation)
      end
    end
    # Create single load case
    let lc = F4DD.add_load_case!(model)
      # Gravity for self-weight
      if self_weight
        F4DD.set_gravity!(lc, 0.0, 0.0, -9.81)
      end
      # Nodal loads
      for n in loaded_nodes
        F4DD.add_nodal_load!(lc, n.id;
          fx=n.load.x, fy=n.load.y, fz=n.load.z)
      end
    end
    # Solve
    F4DD.solve(model)
  end

# Displacement extraction — returns a closure that maps TrussNodeData → displacement Vec
KhepriBase.b_node_displacement_function(b::FR4DD, results) =
  let D = results.load_cases[1].displacements
    n -> let base = 6*(n.id - 1)
      vxyz(D[base+1], D[base+2], D[base+3], world_cs)
    end
  end
