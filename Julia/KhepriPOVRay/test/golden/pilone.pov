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
  5, <-53.0, 0.0, 10.0>, <-3.0, 0.0, 10.0>, <-3.0, 0.0, -10.0>, <-53.0, 0.0, -10.0>, <-53.0, 0.0, 10.0>
  texture { Material }
}
triangle {
  <-53.0, 0.0, -10.0>, <-3.0, 0.0, -10.0>, <-13.0, 50.0, -5.0>
  texture { Material }
}
triangle {
  <-53.0, 0.0, -10.0>, <-13.0, 50.0, -5.0>, <-43.0, 50.0, -5.0>
  texture { Material }
}
triangle {
  <-3.0, 0.0, -10.0>, <-3.0, 0.0, 10.0>, <-13.0, 50.0, 5.0>
  texture { Material }
}
triangle {
  <-3.0, 0.0, -10.0>, <-13.0, 50.0, 5.0>, <-13.0, 50.0, -5.0>
  texture { Material }
}
triangle {
  <-3.0, 0.0, 10.0>, <-53.0, 0.0, 10.0>, <-43.0, 50.0, 5.0>
  texture { Material }
}
triangle {
  <-3.0, 0.0, 10.0>, <-43.0, 50.0, 5.0>, <-13.0, 50.0, 5.0>
  texture { Material }
}
triangle {
  <-53.0, 0.0, 10.0>, <-53.0, 0.0, -10.0>, <-43.0, 50.0, -5.0>
  texture { Material }
}
triangle {
  <-53.0, 0.0, 10.0>, <-43.0, 50.0, -5.0>, <-43.0, 50.0, 5.0>
  texture { Material }
}
polygon {
  5, <-43.0, 50.0, -5.0>, <-13.0, 50.0, -5.0>, <-13.0, 50.0, 5.0>, <-43.0, 50.0, 5.0>, <-43.0, 50.0, -5.0>
  texture { Material }
}
polygon {
  5, <3.0, 0.0, 10.0>, <53.0, 0.0, 10.0>, <53.0, 0.0, -10.0>, <3.0, 0.0, -10.0>, <3.0, 0.0, 10.0>
  texture { Material }
}
triangle {
  <3.0, 0.0, -10.0>, <53.0, 0.0, -10.0>, <43.0, 50.0, -5.0>
  texture { Material }
}
triangle {
  <3.0, 0.0, -10.0>, <43.0, 50.0, -5.0>, <13.0, 50.0, -5.0>
  texture { Material }
}
triangle {
  <53.0, 0.0, -10.0>, <53.0, 0.0, 10.0>, <43.0, 50.0, 5.0>
  texture { Material }
}
triangle {
  <53.0, 0.0, -10.0>, <43.0, 50.0, 5.0>, <43.0, 50.0, -5.0>
  texture { Material }
}
triangle {
  <53.0, 0.0, 10.0>, <3.0, 0.0, 10.0>, <13.0, 50.0, 5.0>
  texture { Material }
}
triangle {
  <53.0, 0.0, 10.0>, <13.0, 50.0, 5.0>, <43.0, 50.0, 5.0>
  texture { Material }
}
triangle {
  <3.0, 0.0, 10.0>, <3.0, 0.0, -10.0>, <13.0, 50.0, -5.0>
  texture { Material }
}
triangle {
  <3.0, 0.0, 10.0>, <13.0, 50.0, -5.0>, <13.0, 50.0, 5.0>
  texture { Material }
}
polygon {
  5, <13.0, 50.0, -5.0>, <43.0, 50.0, -5.0>, <43.0, 50.0, 5.0>, <13.0, 50.0, 5.0>, <13.0, 50.0, -5.0>
  texture { Material }
}
box {
  <0, 0, 0>, <8, 8, 20>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -11.0, 0.0, -10.0>
}
box {
  <0, 0, 0>, <8, 8, 20>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 3.0, 0.0, -10.0>
}
box {
  <0, 0, 0>, <22, 8, 8>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -11.0, 20.0, -10.0>
}
plane {<28.447602999999997,-120.5495,-27.55708>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <28.9092, 1.13012, -109.67>
  look_at <0.461597, 28.6872, 10.8795>
  right x*image_width/image_height
  angle 54.43222311461495
}
