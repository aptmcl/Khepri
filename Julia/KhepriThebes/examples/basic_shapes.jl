# KhepriThebes Basic Shapes Example
# Demonstrates 3D visualization using Thebes/Luxor
#
# This example follows Khepri's backend-portable design:
# - Changing "using KhepriThebes" to another backend (e.g., KhepriAutoCAD)
#   should produce equivalent results
# - Only the backend() call needs to change per backend

using KhepriThebes

# Reset for a fresh start
delete_all_shapes()

# Adjust the camera view (works across all backends)
set_view(xyz(50, 50, 30), xyz(0, 0, 0))

println("Creating basic shapes...")

# Points
point(xyz(0, 0, 0))
point(xyz(10, 0, 0))
point(xyz(0, 10, 0))

# Lines
line(xyz(-5, -5, 0), xyz(5, -5, 0))
line([xyz(-5, -5, 0), xyz(0, -3, 2), xyz(5, -5, 0)])

# Polygons
polygon(xyz(-8, 2, 0), xyz(-6, 2, 0), xyz(-7, 4, 2))
rectangle(xyz(6, 2, 0), 3, 2)

# Circles
circle(xyz(0, 0, 0), 2)

# Arc
arc(xyz(-8, 8, 0), 2, 0, pi)

# Filled shapes (portable across backends)
surface_polygon(xyz(2, 6, 0), xyz(5, 6, 0), xyz(3.5, 9, 2))

println("Shapes created!")

# Standard Khepri render workflow (works across all backends)
# Returns a displayable file object for VSCode inline display
render_view("output")
