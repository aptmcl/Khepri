#version 3.7;
#include "colors.inc"
#include "CIE.inc"
#include "lightsys.inc"
#include "lightsys_constants.inc"
#include "sunpos.inc"
#declare Current_Turbidity = 5;
//To solve a bug in CIE_Skylight.in
#local fiLuminous=finish{ambient 0 emission 1 diffuse 0 specular 0 phong 0 reflection 0 crand 0 irid{0}}
#include "CIE_Skylight.inc"
global_settings {
  assumed_gamma 1.0
  radiosity {
  }
}
#default {finish {ambient 0 diffuse 1}}
light_source{
  #local xpto = SunPos(2020, 9, 21, 10, 0, 0, 39, 9);
vrotate(<0,0,1000000000>,<-Al,Az,0>)

  Light_Color(SunColor,3)
  translate SolarPosition
}
#include "transforms.inc"
#declare Material =
  texture { pigment { color rgb 0.3 } finish { reflection 0 ambient 0 }}
box {
  <0, 0, 0>, <1.0, 3.0, 4.0>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 2.0, 1.0, 1.0>
}
cone {
  <6.0, 0.0, 0.0>, 1, <8.0, 5.0, 0.9999999999999999>, 0
  texture { Material }
}
cone {
  <11.0, 0.0, 1.0>, 2, <10.0, 5.0, 0.0>, 1
  texture { Material }
}
sphere {
  <8, 5, 4>, 2
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 7.3484692283495345>, 1
  texture { Material }
  matrix <-0.44721359549995815, 0.0, -0.8944271909999157, 0.8520128672302583, 0.3042903097250923, -0.42600643361512935, -0.2721655269759087, 0.9525793444156804, 0.13608276348795434, 8.0, 0.0, 7.0>
}
polygon {
  6, <-1.8896645112857848, -0.6824130297015307, 1.7225915421756426>, <-1.0997586234714412, -0.4217544467213374, 0.891885936822521>, <-1.5539557199405738, 0.42175444672133755, 0.21059029211882196>, <-2.6245708509643566, 0.6824130297015306, 0.6202320326577853>, <-2.8320502943378436, 0.0, 1.5547001962252291>, <-1.8896645112857848, -0.6824130297015307, 1.7225915421756426>
  texture { Material }
}
triangle {
  <2.0, 7.000000000000001, 7.0>, <-1.8896645112857848, -0.6824130297015307, 1.7225915421756426>, <-2.8320502943378436, 0.0, 1.5547001962252291>
  texture { Material }
}
triangle {
  <2.0, 7.000000000000001, 7.0>, <-2.8320502943378436, 0.0, 1.5547001962252291>, <-2.6245708509643566, 0.6824130297015306, 0.6202320326577853>
  texture { Material }
}
triangle {
  <2.0, 7.000000000000001, 7.0>, <-2.6245708509643566, 0.6824130297015306, 0.6202320326577853>, <-1.5539557199405738, 0.42175444672133755, 0.21059029211882196>
  texture { Material }
}
triangle {
  <2.0, 7.000000000000001, 7.0>, <-1.5539557199405738, 0.42175444672133755, 0.21059029211882196>, <-1.0997586234714412, -0.4217544467213374, 0.891885936822521>
  texture { Material }
}
triangle {
  <2.0, 7.000000000000001, 7.0>, <-1.0997586234714412, -0.4217544467213374, 0.891885936822521>, <-1.8896645112857848, -0.6824130297015307, 1.7225915421756426>
  texture { Material }
}
torus {
  2, 1
  texture { Material }
  rotate <90, 0, 0>
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 14.0, 5.0, 6.0>
}
plane {<1.7567700000000004,-30.834400000000002,7.8561499999999995>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <8.057, 9.5719, -23.2615>
  look_at <6.30023, 1.71575, 7.5729>
  right x*image_width/image_height
  angle 39.59775270904986
}
