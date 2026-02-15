# Manual test for KhepriUnreal
# Prerequisites:
# 1. Unreal Engine Editor must be running with the Khepri plugin loaded
# 2. The plugin starts a server on port 11010

using Pkg
Pkg.activate("/home/aml/Projects/Khepri/Julia/KhepriUnreal")

using KhepriUnreal
using KhepriBase

println("KhepriUnreal Test Suite")
println("=======================")
println("Unreal port: ", unreal_port)
println()

# Try to connect
println("Connecting to Unreal Engine...")
try
  backend(unreal)
  println("✓ Connected to Unreal Engine!")
catch e
  println("✗ Failed to connect: ", e)
  println()
  println("Make sure Unreal Engine is running with the Khepri plugin loaded.")
  println("The plugin should be listening on port ", unreal_port)
  exit(1)
end

println()
println("Running tests...")
println()

# Clear any existing geometry
println("1. Clearing scene...")
delete_all_shapes()
println("   ✓ Scene cleared")

# Test Tier 0 - Curves
println()
println("2. Testing Tier 0 - Curves")

println("   - Point...")
point(xyz(0, 0, 0))
println("   ✓ Point created")

println("   - Line...")
line(xyz(0, 0, 0), xyz(5, 0, 0), xyz(5, 5, 0))
println("   ✓ Line created")

println("   - Polygon...")
polygon(xyz(10, 0, 0), xyz(15, 0, 0), xyz(15, 5, 0), xyz(10, 5, 0))
println("   ✓ Polygon created")

println("   - Circle...")
circle(xyz(20, 2.5, 0), 2.5)
println("   ✓ Circle created")

println("   - Rectangle...")
rectangle(xyz(25, 0, 0), 5, 5)
println("   ✓ Rectangle created")

# Test Tier 1 - Basic Surfaces
println()
println("3. Testing Tier 1 - Basic Surfaces")

println("   - Triangle surface...")
surface_polygon(xyz(0, 10, 0), xyz(5, 10, 0), xyz(2.5, 15, 0))
println("   ✓ Triangle surface created")

println("   - Quad surface...")
surface_polygon(xyz(10, 10, 0), xyz(15, 10, 0), xyz(15, 15, 0), xyz(10, 15, 0))
println("   ✓ Quad surface created")

println("   - Surface circle...")
surface_circle(xyz(22.5, 12.5, 0), 2.5)
println("   ✓ Surface circle created")

# Test Tier 3 - Solids
println()
println("4. Testing Tier 3 - Solids")

println("   - Sphere...")
sphere(xyz(0, 0, 10), 2)
println("   ✓ Sphere created")

println("   - Box...")
box(xyz(10, 0, 10), 4, 4, 4)
println("   ✓ Box created")

println("   - Cylinder...")
cylinder(xyz(20, 2, 10), 2, xyz(20, 2, 16))
println("   ✓ Cylinder created")

println("   - Cone...")
cone(xyz(30, 2, 10), 2, 6)
println("   ✓ Cone created")

println("   - Cone frustum...")
cone_frustum(xyz(40, 2, 10), 2, 4, 1)
println("   ✓ Cone frustum created")

println("   - Torus...")
torus(xyz(50, 2, 12), 3, 1)
println("   ✓ Torus created")

println("   - Pyramid...")
pyramid([xyz(60, 0, 10), xyz(64, 0, 10), xyz(64, 4, 10), xyz(60, 4, 10)], xyz(62, 2, 16))
println("   ✓ Pyramid created")

# Test Boolean operations
println()
println("5. Testing Boolean Operations")

println("   - Subtraction (box - sphere)...")
let b = box(xyz(0, 20, 10), 6, 6, 6),
    s = sphere(xyz(3, 23, 13), 3)
  subtraction(b, s)
end
println("   ✓ Subtraction created")

println("   - Union (two boxes)...")
let b1 = box(xyz(15, 20, 10), 4, 4, 4),
    b2 = box(xyz(17, 22, 12), 4, 4, 4)
  union(b1, b2)
end
println("   ✓ Union created")

# Test view
println()
println("6. Testing View")
println("   - Setting view...")
set_view(xyz(30, -30, 40), xyz(30, 10, 10), 35)
println("   ✓ View set")

println()
println("=======================")
println("All tests completed!")
println()
println("Check Unreal Engine to see the created geometry.")
