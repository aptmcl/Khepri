module Frame4DD

using LinearAlgebra
using SparseArrays
using PrecompileTools

include("types.jl")
include("coord_trans.jl")
include("stiffness.jl")
include("mass.jl")
include("loads.jl")
include("assembly.jl")
include("modal.jl")
include("model.jl")
include("solver.jl")
include("show.jl")

export Model, Node, Material, Section, FrameElement, LoadCase,
       AnalysisOptions, ModalOptions,
       GravityLoad, ConcentratedLoad, UniformLoad, TrapezoidalLoad,
       InternalPointLoad, TemperatureLoad, PrescribedDisplacement,
       NodeMass, ElementExtraMass,
       DOFMask, VerticalAxis, ZVertical, YVertical,
       EigenMethod, SubspaceJacobi, Stodola,
       LoadCaseResults, ModalResults, AnalysisResults,
       add_node!, add_element!, fix_node!, add_load_case!,
       set_gravity!, add_nodal_load!, add_uniform_load!,
       add_trapezoidal_load!, add_point_load!,
       add_temperature_load!, add_prescribed_displacement!,
       add_node_mass!, add_element_extra_mass!,
       solve

@compile_workload begin
  # Small truss that exercises all main code paths
  model = Model()

  # Add nodes
  add_node!(model, 0.0, 0.0, 0.0)
  add_node!(model, 1.0, 0.0, 0.0)
  add_node!(model, 0.5, 0.0, 1.0)

  # Fix supports
  fix_node!(model, 1; dx=true, dy=true, dz=true, rx=true, ry=true, rz=true)
  fix_node!(model, 2; dx=true, dy=true, dz=true)

  # Add elements
  mat = Material(210e9, 81e9, 7800.0)
  sec = Section(1e-3, 5e-4, 5e-4, 1e-7, 5e-8, 5e-8)
  add_element!(model, 1, 2, sec, mat)
  add_element!(model, 1, 3, sec, mat)
  add_element!(model, 2, 3, sec, mat)

  # Add load case with gravity and nodal load
  lc = add_load_case!(model)
  set_gravity!(lc, 0.0, 0.0, -9.81)
  add_nodal_load!(lc, 3; fz=-1000.0)

  # Solve
  solve(model)
end

end # module
