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
  <0, 0, 0>, <0.5, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.5, 0.0, 0.5>
}
box {
  <0, 0, 0>, <0.19999999999999996, 0.19999999999999996, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.5, 0.0, 1.5>
}
box {
  <0, 0, 0>, <0.5, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 2.0, 0.0, 2.0>
}
plane {<-0.983021,-1.284879,0.35200399999999993>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <-0.498875, 0.681738, -0.825617>
  look_at <0.484146, 0.329734, 0.459262>
  right x*image_width/image_height
  angle 39.59775270904986
}
