# KhepriThebes 3D Solids Example
# Demonstrates 3D solid operations using Thebes native objects
#
# This example follows Khepri's backend-portable design:
# - Changing "using KhepriThebes" to another backend (e.g., KhepriAutoCAD)
#   should produce equivalent results

using KhepriThebes

# Reset for a fresh start
delete_all_shapes()

# Set camera for a good view of all shapes
set_view(xyz(80, 80, 60), xyz(0, 0, 0))

println("Creating 3D solids...")

# Box at (-30, -30)
box(xyz(-30, -30, 0), 15, 15, 15)

# Sphere at (0, -30)
sphere(xyz(0, -30, 7.5), 7.5)

# Cylinder at (30, -30)
cylinder(xyz(30, -30, 0), 7.5, 15)

# Cone at (-30, 0)
cone(xyz(-30, 0, 0), 7.5, 15)

# Torus at (0, 0)
torus(xyz(0, 0, 5), 10, 3)

# Cone frustum at (30, 0)
cone_frustum(xyz(30, 0, 0), 10, 15, 5)

# Pyramid with a square base at (-30, 30)
pyramid([xyz(-35, 25, 0), xyz(-25, 25, 0), xyz(-25, 35, 0), xyz(-35, 35, 0)],
        xyz(-30, 30, 15))

# Another sphere at (30, 30)
sphere(xyz(30, 30, 7.5), 7.5)

println("3D solids created!")

# Render the scene and return the result for VSCode inline display
render_view("3d_solids_output")
# In VSCode, the returned ThebesSVGFile will be displayed inline
