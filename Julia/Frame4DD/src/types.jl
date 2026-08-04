"""
    Node(x, y, z, r=0.0)

A node in the structural model.

- `x`, `y`, `z`: coordinates in global space
- `r`: rigid end zone radius (default 0). When nonzero, the effective element
  length is reduced by `r` at each end.
"""
struct Node
  x::Float64
  y::Float64
  z::Float64
  r::Float64  # rigid radius (finite node size)
end

Node(x, y, z) = Node(x, y, z, 0.0)

"""
    Material(E, G, density)

Material properties.

- `E`: Young's modulus (force/area)
- `G`: shear modulus (force/area)
- `density`: mass density (mass/volume)
"""
struct Material
  E::Float64
  G::Float64
  density::Float64
end

"""
    Section(Ax, Asy, Asz, Jx, Iy, Iz)

Cross-section properties.

- `Ax`: axial area
- `Asy`: effective shear area in local y (used when `shear=true`)
- `Asz`: effective shear area in local z
- `Jx`: torsional moment of inertia (St. Venant)
- `Iy`: bending moment of inertia about local y axis
- `Iz`: bending moment of inertia about local z axis
"""
struct Section
  Ax::Float64   # axial area
  Asy::Float64  # shear area in local y
  Asz::Float64  # shear area in local z
  Jx::Float64   # torsional moment of inertia
  Iy::Float64   # bending moment of inertia about y
  Iz::Float64   # bending moment of inertia about z
end

"""
    FrameElement

A frame element connecting two nodes. Created via [`add_element!`](@ref).

Fields: `node1`, `node2` (node indices), `section`, `material`, `roll`
(roll angle in degrees about the element axis).
"""
struct FrameElement
  node1::Int
  node2::Int
  section::Section
  material::Material
  roll::Float64  # roll angle in degrees
end

"""
    DOFMask

A `NTuple{6,Bool}` indicating which DOFs are restrained at a node:
`(dx, dy, dz, rx, ry, rz)`. `true` means fixed.
"""
const DOFMask = NTuple{6,Bool}  # (dx,dy,dz,rx,ry,rz), true=fixed

"""
    GravityLoad(gx, gy, gz)

Gravitational acceleration in global coordinates (acceleration units).
Applied as a body force to all elements via their mass density.
"""
struct GravityLoad
  gx::Float64
  gy::Float64
  gz::Float64
end

GravityLoad() = GravityLoad(0.0, 0.0, 0.0)

"""
    ConcentratedLoad

A concentrated force and moment applied at a node in global coordinates.
Created via [`add_nodal_load!`](@ref).
"""
struct ConcentratedLoad
  node::Int
  fx::Float64
  fy::Float64
  fz::Float64
  mx::Float64
  my::Float64
  mz::Float64
end

"""
    UniformLoad

A uniformly distributed load on an element in local coordinates (force/length).
Created via [`add_uniform_load!`](@ref).
"""
struct UniformLoad
  element::Int
  ux::Float64  # local x (axial) force/length
  uy::Float64  # local y force/length
  uz::Float64  # local z force/length
end

"""
    TrapezoidalLoad

A linearly varying (trapezoidal) distributed load on an element in local
coordinates. For each local axis (x, y, z), the load is defined by a start
position, end position, start intensity, and end intensity (force/length).
Created via [`add_trapezoidal_load!`](@ref).
"""
struct TrapezoidalLoad
  element::Int
  # x-axis (axial): start pos, end pos, start intensity, end intensity
  xx1::Float64; xx2::Float64; wx1::Float64; wx2::Float64
  # y-axis (transverse): start pos, end pos, start intensity, end intensity
  yx1::Float64; yx2::Float64; wy1::Float64; wy2::Float64
  # z-axis (transverse): start pos, end pos, start intensity, end intensity
  zx1::Float64; zx2::Float64; wz1::Float64; wz2::Float64
end

"""
    InternalPointLoad

A concentrated load applied at an interior point of an element in local
coordinates. `a` is the distance from node1 along the element axis.
Created via [`add_point_load!`](@ref).
"""
struct InternalPointLoad
  element::Int
  px::Float64  # local x force
  py::Float64  # local y force
  pz::Float64  # local z force
  a::Float64   # distance from node1
end

"""
    TemperatureLoad

A temperature load on an element. Produces axial force from the mean temperature
and bending moments from differential temperatures across the section depth.
Created via [`add_temperature_load!`](@ref).

- `alpha`: coefficient of thermal expansion
- `hy`, `hz`: section depths in local y and z
- `ty_pos`, `ty_neg`: temperature changes at +y and -y fibers
- `tz_pos`, `tz_neg`: temperature changes at +z and -z fibers
"""
struct TemperatureLoad
  element::Int
  alpha::Float64  # coefficient of thermal expansion
  hy::Float64     # section depth in local y
  hz::Float64     # section depth in local z
  ty_pos::Float64 # temp change at +y fiber
  ty_neg::Float64 # temp change at -y fiber
  tz_pos::Float64 # temp change at +z fiber
  tz_neg::Float64 # temp change at -z fiber
end

"""
    PrescribedDisplacement

A prescribed (imposed) displacement at a restrained node in global coordinates.
The node must first be fixed with [`fix_node!`](@ref).
Created via [`add_prescribed_displacement!`](@ref).
"""
struct PrescribedDisplacement
  node::Int
  dx::Float64
  dy::Float64
  dz::Float64
  rx::Float64
  ry::Float64
  rz::Float64
end

"""
    LoadCase

A collection of loads to be applied simultaneously. Created via
[`add_load_case!`](@ref). Loads are added with [`set_gravity!`](@ref),
[`add_nodal_load!`](@ref), [`add_uniform_load!`](@ref), etc.
"""
mutable struct LoadCase
  gravity::GravityLoad
  nodal_loads::Vector{ConcentratedLoad}
  uniform_loads::Vector{UniformLoad}
  trapezoidal_loads::Vector{TrapezoidalLoad}
  point_loads::Vector{InternalPointLoad}
  temperature_loads::Vector{TemperatureLoad}
  prescribed_displacements::Vector{PrescribedDisplacement}
end

function LoadCase()
  LoadCase(
    GravityLoad(),
    ConcentratedLoad[],
    UniformLoad[],
    TrapezoidalLoad[],
    InternalPointLoad[],
    TemperatureLoad[],
    PrescribedDisplacement[]
  )
end

"""
    NodeMass

Extra lumped mass and rotational inertia at a node.
Created via [`add_node_mass!`](@ref).
"""
struct NodeMass
  node::Int
  mass::Float64
  Ixx::Float64
  Iyy::Float64
  Izz::Float64
end

"""
    ElementExtraMass

Extra non-structural mass distributed along an element (total mass, not per-length).
Created via [`add_element_extra_mass!`](@ref).
"""
struct ElementExtraMass
  element::Int
  mass::Float64
end

"""
    VerticalAxis

The vertical axis convention: `ZVertical` (default) or `YVertical`.
Controls the coordinate transformation for elements.
"""
@enum VerticalAxis ZVertical YVertical

"""
    ZVertical

Z-axis is the vertical direction (default). Controls the coordinate
transformation for elements — the local y-axis is formed using the global
Z-axis as reference.
"""
ZVertical

"""
    YVertical

Y-axis is the vertical direction. Controls the coordinate transformation
for elements — the local y-axis is formed using the global Y-axis as reference.
"""
YVertical

"""
    EigenMethod

Eigensolver method for modal analysis: `SubspaceJacobi` (default) or `Stodola`.
"""
@enum EigenMethod SubspaceJacobi = 1 Stodola = 2

"""
    SubspaceJacobi

Subspace iteration with Jacobi rotation for the reduced eigenproblem.
Computes all requested modes simultaneously. Good for problems where many
modes are needed. This is the default eigensolver.
"""
SubspaceJacobi

"""
    Stodola

Inverse iteration with deflation (Stodola method). Computes one mode at a
time. Can be more robust for problems with closely spaced eigenvalues.
"""
Stodola

"""
    ModalOptions(num_modes; method=SubspaceJacobi, lumped=true, tol=1e-9, shift=0.0)

Options for modal (eigenvalue) analysis.

- `num_modes`: number of natural frequencies and mode shapes to compute
- `method`: eigensolver — [`SubspaceJacobi`](@ref EigenMethod) or [`Stodola`](@ref EigenMethod)
- `lumped`: `true` for lumped mass matrix, `false` for consistent
- `tol`: convergence tolerance for the eigensolver
- `shift`: eigenvalue shift (for problems with near-zero frequencies)
"""
struct ModalOptions
  num_modes::Int
  method::EigenMethod
  lumped::Bool
  tol::Float64
  shift::Float64
end

ModalOptions(num_modes; method=SubspaceJacobi, lumped=true, tol=1e-9, shift=0.0) =
  ModalOptions(num_modes, method, lumped, tol, shift)

"""
    AnalysisOptions(; shear=false, geometric=false, vertical=ZVertical, tol=1e-9, modal=nothing, sparse_threshold=200)

Global analysis options.

- `shear`: include shear deformation (Timoshenko beam theory)
- `geometric`: include geometric nonlinearity (P-delta, solved via Newton-Raphson)
- `vertical`: vertical axis convention — `ZVertical` (default) or `YVertical`
- `tol`: Newton-Raphson convergence tolerance (relative equilibrium error)
- `modal`: `nothing` to skip modal analysis, or a [`ModalOptions`](@ref) instance
- `sparse_threshold`: use sparse solver when DOF count exceeds this value.
  Below the threshold, dense LAPACK routines are used. Above it, sparse CHOLMOD
  is used. Default 200.
"""
struct AnalysisOptions
  shear::Bool
  geometric::Bool
  vertical::VerticalAxis
  tol::Float64
  modal::Union{Nothing,ModalOptions}
  sparse_threshold::Int  # use sparse solver when DoF > this value
end

AnalysisOptions(; shear=false, geometric=false, vertical=ZVertical, tol=1e-9, modal=nothing, sparse_threshold=200) =
  AnalysisOptions(shear, geometric, vertical, tol, modal, sparse_threshold)

"""
    LoadCaseResults

Results for a single load case.

- `displacements`: displacement vector (length = 6 × number of nodes). Access
  DOF `k` of node `n` at index `6(n-1) + k` where k: 1=dx, 2=dy, 3=dz, 4=rx, 5=ry, 6=rz.
- `reactions`: reaction force vector (same layout as displacements; nonzero only
  at restrained DOFs)
- `element_forces`: `nE × 12` matrix of local element end forces. See the
  [Tutorial](@ref) for the column layout.
- `rms_residual`: relative RMS equilibrium error (should be near machine epsilon
  for linear analysis)
"""
struct LoadCaseResults
  displacements::Vector{Float64}   # length DoF
  reactions::Vector{Float64}       # length DoF
  element_forces::Matrix{Float64}  # nE × 12, local element end forces
  rms_residual::Float64
end

"""
    ModalResults

Results from modal (eigenvalue) analysis.

- `frequencies`: natural frequencies in Hz (sorted ascending)
- `mode_shapes`: `DoF × nModes` matrix, each column is one mode shape
- `total_mass`: total mass (structural + extra nodal/element masses)
- `structural_mass`: mass from element density × area × length only
"""
struct ModalResults
  frequencies::Vector{Float64}     # Hz
  mode_shapes::Matrix{Float64}    # DoF × nModes
  total_mass::Float64
  structural_mass::Float64
end

"""
    AnalysisResults

Top-level results returned by [`solve`](@ref).

- `load_cases`: a vector of [`LoadCaseResults`](@ref), one per load case
- `modal`: a [`ModalResults`](@ref) instance, or `nothing` if modal analysis was
  not requested
"""
struct AnalysisResults
  load_cases::Vector{LoadCaseResults}
  modal::Union{Nothing,ModalResults}
end

"""
    Model(; options=AnalysisOptions())

The structural model container. Build it up using [`add_node!`](@ref),
[`add_element!`](@ref), [`fix_node!`](@ref), [`add_load_case!`](@ref), etc.,
then call [`solve`](@ref) to run the analysis.
"""
mutable struct Model
  nodes::Vector{Node}
  elements::Vector{FrameElement}
  restraints::Dict{Int,DOFMask}
  load_cases::Vector{LoadCase}
  node_masses::Vector{NodeMass}
  element_extra_masses::Vector{ElementExtraMass}
  options::AnalysisOptions
end

function Model(; options=AnalysisOptions())
  Model(
    Node[],
    FrameElement[],
    Dict{Int,DOFMask}(),
    LoadCase[],
    NodeMass[],
    ElementExtraMass[],
    options
  )
end
