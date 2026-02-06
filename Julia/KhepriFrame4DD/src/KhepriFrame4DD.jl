module KhepriFrame4DD
using KhepriBase

# functions that need specialization
include(khepribase_interface_file())

include("Frame4DD.jl")

function __init__()
  set_backend_family(default_truss_bar_family(),
    frame4dd,
    frame4dd_truss_bar_family(
      E=210e09,         # E (Young's modulus)
      G=81e09,          # G (Kirchoff's or Shear modulus)
      p=0.0,            # Roll angle
      d=7.701e3))       # RO (Density)

  add_current_backend(frame4dd)
end

end
