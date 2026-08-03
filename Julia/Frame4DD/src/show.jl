import Base: show

function show(io::IO, n::Node)
  print(io, "Node($(n.x), $(n.y), $(n.z)")
  n.r != 0.0 && print(io, ", r=$(n.r)")
  print(io, ")")
end

function show(io::IO, m::Material)
  print(io, "Material(E=$(m.E), G=$(m.G), density=$(m.density))")
end

function show(io::IO, s::Section)
  print(io, "Section(Ax=$(s.Ax), Asy=$(s.Asy), Asz=$(s.Asz), Jx=$(s.Jx), Iy=$(s.Iy), Iz=$(s.Iz))")
end

function show(io::IO, e::FrameElement)
  print(io, "FrameElement($(e.node1) -> $(e.node2)")
  e.roll != 0.0 && print(io, ", roll=$(e.roll)")
  print(io, ")")
end

function show(io::IO, lc::LoadCase)
  parts = String[]
  lc.gravity.gx != 0 || lc.gravity.gy != 0 || lc.gravity.gz != 0 && push!(parts, "gravity")
  isempty(lc.nodal_loads) || push!(parts, "$(length(lc.nodal_loads)) nodal")
  isempty(lc.uniform_loads) || push!(parts, "$(length(lc.uniform_loads)) uniform")
  isempty(lc.trapezoidal_loads) || push!(parts, "$(length(lc.trapezoidal_loads)) trapezoidal")
  isempty(lc.point_loads) || push!(parts, "$(length(lc.point_loads)) point")
  isempty(lc.temperature_loads) || push!(parts, "$(length(lc.temperature_loads)) temperature")
  isempty(lc.prescribed_displacements) || push!(parts, "$(length(lc.prescribed_displacements)) prescribed")
  desc = isempty(parts) ? "empty" : join(parts, ", ")
  print(io, "LoadCase($desc)")
end

function show(io::IO, opts::AnalysisOptions)
  parts = String[]
  opts.shear && push!(parts, "shear")
  opts.geometric && push!(parts, "geometric")
  opts.vertical == YVertical && push!(parts, "YVertical")
  opts.modal !== nothing && push!(parts, "modal=$(opts.modal.num_modes) modes")
  opts.sparse_threshold != 200 && push!(parts, "sparse_threshold=$(opts.sparse_threshold)")
  desc = isempty(parts) ? "default" : join(parts, ", ")
  print(io, "AnalysisOptions($desc)")
end

function show(io::IO, mo::ModalOptions)
  print(io, "ModalOptions($(mo.num_modes) modes, $(mo.method)")
  mo.lumped && print(io, ", lumped")
  !mo.lumped && print(io, ", consistent")
  mo.shift != 0.0 && print(io, ", shift=$(mo.shift)")
  print(io, ")")
end

function show(io::IO, r::LoadCaseResults)
  ndof = length(r.displacements)
  nnodes = div(ndof, 6)
  nelem = size(r.element_forces, 1)
  print(io, "LoadCaseResults($nnodes nodes, $nelem elements, rms=$(round(r.rms_residual, sigdigits=3)))")
end

function show(io::IO, r::ModalResults)
  nm = length(r.frequencies)
  f_range = nm > 0 ? "$(round(r.frequencies[1], digits=2))-$(round(r.frequencies[end], digits=2)) Hz" : "none"
  print(io, "ModalResults($nm modes, $f_range, mass=$(round(r.total_mass, sigdigits=4)))")
end

function show(io::IO, r::AnalysisResults)
  nlc = length(r.load_cases)
  print(io, "AnalysisResults($nlc load case$(nlc == 1 ? "" : "s")")
  r.modal !== nothing && print(io, ", $(length(r.modal.frequencies)) modes")
  print(io, ")")
end

function show(io::IO, m::Model)
  nn = length(m.nodes)
  ne = length(m.elements)
  nlc = length(m.load_cases)
  nr = length(m.restraints)
  print(io, "Model($nn nodes, $ne elements, $nlc load case$(nlc == 1 ? "" : "s"), $nr restrained)")
end
