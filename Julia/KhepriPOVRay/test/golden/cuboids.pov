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
polygon {
  5, <0, 0, 2>, <2, 0, 2>, <2, 0, 0>, <0, 0, 0>, <0, 0, 2>
  texture { Material }
}
triangle {
  <0, 0, 0>, <2, 0, 0>, <2, 2, 0>
  texture { Material }
}
triangle {
  <0, 0, 0>, <2, 2, 0>, <0, 2, 0>
  texture { Material }
}
triangle {
  <2, 0, 0>, <2, 0, 2>, <2, 2, 2>
  texture { Material }
}
triangle {
  <2, 0, 0>, <2, 2, 2>, <2, 2, 0>
  texture { Material }
}
triangle {
  <2, 0, 2>, <0, 0, 2>, <0, 2, 2>
  texture { Material }
}
triangle {
  <2, 0, 2>, <0, 2, 2>, <2, 2, 2>
  texture { Material }
}
triangle {
  <0, 0, 2>, <0, 0, 0>, <0, 2, 0>
  texture { Material }
}
triangle {
  <0, 0, 2>, <0, 2, 0>, <0, 2, 2>
  texture { Material }
}
polygon {
  5, <0, 2, 0>, <2, 2, 0>, <2, 2, 2>, <0, 2, 2>, <0, 2, 0>
  texture { Material }
}
polygon {
  5, <4, 0, 2>, <5, 0, 2>, <5, 0, 0>, <4, 0, 0>, <4, 0, 2>
  texture { Material }
}
triangle {
  <4, 0, 0>, <5, 0, 0>, <5, 2, 1>
  texture { Material }
}
triangle {
  <4, 0, 0>, <5, 2, 1>, <3, 2, 1>
  texture { Material }
}
triangle {
  <5, 0, 0>, <5, 0, 2>, <5, 2, 2>
  texture { Material }
}
triangle {
  <5, 0, 0>, <5, 2, 2>, <5, 2, 1>
  texture { Material }
}
triangle {
  <5, 0, 2>, <4, 0, 2>, <3, 2, 2>
  texture { Material }
}
triangle {
  <5, 0, 2>, <3, 2, 2>, <5, 2, 2>
  texture { Material }
}
triangle {
  <4, 0, 2>, <4, 0, 0>, <3, 2, 1>
  texture { Material }
}
triangle {
  <4, 0, 2>, <3, 2, 1>, <3, 2, 2>
  texture { Material }
}
polygon {
  5, <3, 2, 1>, <5, 2, 1>, <5, 2, 2>, <3, 2, 2>, <3, 2, 1>
  texture { Material }
}
polygon {
  5, <6, 0, 3>, <8, 0, 3>, <8, 0, 0>, <7, 0, 2>, <6, 0, 3>
  texture { Material }
}
triangle {
  <7, 0, 2>, <8, 0, 0>, <8, 2, 0>
  texture { Material }
}
triangle {
  <7, 0, 2>, <8, 2, 0>, <7, 2, 2>
  texture { Material }
}
triangle {
  <8, 0, 0>, <8, 0, 3>, <8, 2, 3>
  texture { Material }
}
triangle {
  <8, 0, 0>, <8, 2, 3>, <8, 2, 0>
  texture { Material }
}
triangle {
  <8, 0, 3>, <6, 0, 3>, <6, 2, 3>
  texture { Material }
}
triangle {
  <8, 0, 3>, <6, 2, 3>, <8, 2, 3>
  texture { Material }
}
triangle {
  <6, 0, 3>, <7, 0, 2>, <7, 2, 2>
  texture { Material }
}
triangle {
  <6, 0, 3>, <7, 2, 2>, <6, 2, 3>
  texture { Material }
}
polygon {
  5, <7, 2, 2>, <8, 2, 0>, <8, 2, 3>, <6, 2, 3>, <7, 2, 2>
  texture { Material }
}
plane {<-13.434379999999999,-41.265280000000004,20.70513>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <-10.1817, 22.7753, -42.536>
  look_at <3.25268, 2.07017, -1.27072>
  right x*image_width/image_height
  angle 10.285529115768483
}
