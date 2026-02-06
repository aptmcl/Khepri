"""
    add_node!(model, x, y, z; r=0.0)

Add a node to the model. Returns the node index.
"""
function add_node!(model::Model, x, y, z; r=0.0)
  r_val = Float64(r)
  r_val < 0 && throw(ArgumentError("Node radius r must be non-negative, got $r_val"))
  push!(model.nodes, Node(Float64(x), Float64(y), Float64(z), r_val))
  return length(model.nodes)
end

"""
    add_element!(model, n1, n2, section, material; roll=0.0)

Add a frame element connecting nodes n1 and n2. Returns the element index.
`roll` is the roll angle in degrees.
"""
function add_element!(model::Model, n1::Int, n2::Int, section::Section, material::Material; roll=0.0)
  nN = length(model.nodes)
  (1 <= n1 <= nN) || throw(ArgumentError("Node $n1 out of range 1:$nN"))
  (1 <= n2 <= nN) || throw(ArgumentError("Node $n2 out of range 1:$nN"))
  n1 != n2 || throw(ArgumentError("Element cannot connect a node to itself (n1 == n2 == $n1)"))
  L = element_length(model.nodes[n1], model.nodes[n2])
  L > 0 || throw(ArgumentError("Element has zero length (nodes $n1 and $n2 are coincident)"))
  push!(model.elements, FrameElement(n1, n2, section, material, Float64(roll)))
  return length(model.elements)
end

"""
    fix_node!(model, node; dx=false, dy=false, dz=false, rx=false, ry=false, rz=false)

Fix (restrain) DOFs at a node. `true` means fixed.
"""
function fix_node!(model::Model, node::Int; dx=false, dy=false, dz=false, rx=false, ry=false, rz=false)
  nN = length(model.nodes)
  (1 <= node <= nN) || throw(ArgumentError("Node $node out of range 1:$nN"))
  mask = (Bool(dx), Bool(dy), Bool(dz), Bool(rx), Bool(ry), Bool(rz))
  model.restraints[node] = mask
end

"""
    add_load_case!(model)

Add an empty load case to the model. Returns the LoadCase reference.
"""
function add_load_case!(model::Model)
  lc = LoadCase()
  push!(model.load_cases, lc)
  return lc
end

"""
    set_gravity!(lc, gx, gy, gz)

Set gravitational acceleration for a load case (global coordinates).
"""
function set_gravity!(lc::LoadCase, gx, gy, gz)
  lc.gravity = GravityLoad(Float64(gx), Float64(gy), Float64(gz))
end

"""
    add_nodal_load!(lc, node; fx=0, fy=0, fz=0, mx=0, my=0, mz=0)

Add a concentrated load at a node (global coordinates).
"""
function add_nodal_load!(lc::LoadCase, node::Int; fx=0, fy=0, fz=0, mx=0, my=0, mz=0)
  node >= 1 || throw(ArgumentError("Node index must be >= 1, got $node"))
  push!(lc.nodal_loads, ConcentratedLoad(node,
    Float64(fx), Float64(fy), Float64(fz),
    Float64(mx), Float64(my), Float64(mz)))
end

"""
    add_uniform_load!(lc, element; ux=0, uy=0, uz=0)

Add a uniform distributed load to an element (local coordinates, force/length).
"""
function add_uniform_load!(lc::LoadCase, element::Int; ux=0, uy=0, uz=0)
  element >= 1 || throw(ArgumentError("Element index must be >= 1, got $element"))
  push!(lc.uniform_loads, UniformLoad(element,
    Float64(ux), Float64(uy), Float64(uz)))
end

"""
    add_trapezoidal_load!(lc, element; xx1=0,xx2=0,wx1=0,wx2=0, yx1=0,yx2=0,wy1=0,wy2=0, zx1=0,zx2=0,wz1=0,wz2=0)

Add a trapezoidal distributed load to an element (local coordinates).
For each axis (x,y,z): start position, end position, start intensity, end intensity.
"""
function add_trapezoidal_load!(lc::LoadCase, element::Int;
    xx1=0, xx2=0, wx1=0, wx2=0,
    yx1=0, yx2=0, wy1=0, wy2=0,
    zx1=0, zx2=0, wz1=0, wz2=0)
  element >= 1 || throw(ArgumentError("Element index must be >= 1, got $element"))
  push!(lc.trapezoidal_loads, TrapezoidalLoad(element,
    Float64(xx1), Float64(xx2), Float64(wx1), Float64(wx2),
    Float64(yx1), Float64(yx2), Float64(wy1), Float64(wy2),
    Float64(zx1), Float64(zx2), Float64(wz1), Float64(wz2)))
end

"""
    add_point_load!(lc, element; px=0, py=0, pz=0, a=0)

Add an internal point load to an element (local coordinates).
`a` is the distance from node1 along the element.
"""
function add_point_load!(lc::LoadCase, element::Int; px=0, py=0, pz=0, a=0)
  element >= 1 || throw(ArgumentError("Element index must be >= 1, got $element"))
  Float64(a) >= 0 || throw(ArgumentError("Distance a must be non-negative, got $a"))
  push!(lc.point_loads, InternalPointLoad(element,
    Float64(px), Float64(py), Float64(pz), Float64(a)))
end

"""
    add_temperature_load!(lc, element; alpha=0, hy=0, hz=0, ty_pos=0, ty_neg=0, tz_pos=0, tz_neg=0)

Add a temperature load to an element (local coordinates).
"""
function add_temperature_load!(lc::LoadCase, element::Int;
    alpha=0, hy=0, hz=0, ty_pos=0, ty_neg=0, tz_pos=0, tz_neg=0)
  element >= 1 || throw(ArgumentError("Element index must be >= 1, got $element"))
  push!(lc.temperature_loads, TemperatureLoad(element,
    Float64(alpha), Float64(hy), Float64(hz),
    Float64(ty_pos), Float64(ty_neg), Float64(tz_pos), Float64(tz_neg)))
end

"""
    add_prescribed_displacement!(lc, node; dx=0, dy=0, dz=0, rx=0, ry=0, rz=0)

Add a prescribed displacement at a node (global coordinates).
"""
function add_prescribed_displacement!(lc::LoadCase, node::Int;
    dx=0, dy=0, dz=0, rx=0, ry=0, rz=0)
  node >= 1 || throw(ArgumentError("Node index must be >= 1, got $node"))
  push!(lc.prescribed_displacements, PrescribedDisplacement(node,
    Float64(dx), Float64(dy), Float64(dz),
    Float64(rx), Float64(ry), Float64(rz)))
end

"""
    add_node_mass!(model, node; mass=0, Ixx=0, Iyy=0, Izz=0)

Add extra mass and rotational inertia at a node.
"""
function add_node_mass!(model::Model, node::Int; mass=0, Ixx=0, Iyy=0, Izz=0)
  nN = length(model.nodes)
  (1 <= node <= nN) || throw(ArgumentError("Node $node out of range 1:$nN"))
  Float64(mass) >= 0 || throw(ArgumentError("Mass must be non-negative, got $mass"))
  push!(model.node_masses, NodeMass(node,
    Float64(mass), Float64(Ixx), Float64(Iyy), Float64(Izz)))
end

"""
    add_element_extra_mass!(model, element; mass=0)

Add extra mass to an element.
"""
function add_element_extra_mass!(model::Model, element::Int; mass=0)
  nE = length(model.elements)
  (1 <= element <= nE) || throw(ArgumentError("Element $element out of range 1:$nE"))
  Float64(mass) >= 0 || throw(ArgumentError("Mass must be non-negative, got $mass"))
  push!(model.element_extra_masses, ElementExtraMass(element, Float64(mass)))
end
