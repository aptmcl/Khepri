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
  <0, 0, 0>, <1.0, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -3.0, 0.0, -0.25>
}
box {
  <0, 0, 0>, <1.0, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 2.0, 0.0, -0.25>
}
box {
  <0, 0, 0>, <1.2999999999999998, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -3.0, 0.5, -0.25>
}
box {
  <0, 0, 0>, <1.2999999999999998, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.7000000000000002, 0.5, -0.25>
}
box {
  <0, 0, 0>, <1.5999999999999996, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -3.0, 1.0, -0.25>
}
box {
  <0, 0, 0>, <1.5999999999999996, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.4000000000000004, 1.0, -0.25>
}
box {
  <0, 0, 0>, <1.8999999999999995, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -3.0, 1.5, -0.25>
}
box {
  <0, 0, 0>, <1.8999999999999995, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.1000000000000005, 1.5, -0.25>
}
box {
  <0, 0, 0>, <2.1999999999999993, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -3.0, 2.0, -0.25>
}
box {
  <0, 0, 0>, <2.1999999999999993, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.8000000000000005, 2.0, -0.25>
}
box {
  <0, 0, 0>, <2.4999999999999996, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -3.0, 2.5, -0.25>
}
box {
  <0, 0, 0>, <2.4999999999999996, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.5000000000000004, 2.5, -0.25>
}
box {
  <0, 0, 0>, <2.7999999999999994, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -3.0, 3.0, -0.25>
}
box {
  <0, 0, 0>, <2.7999999999999994, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.20000000000000043, 3.0, -0.25>
}
box {
  <0, 0, 0>, <6.0, 0.5, 0.5>
  texture { Material }
  matrix <1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -3.0, 3.5, -0.25>
}
plane {<0.001291399999999998,-0.21796999999999933,-0.0208600000000001>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <0.0395904, 1.36019, -6.68326>
  look_at <0.038299, 1.38105, -6.46529>
  right x*image_width/image_height
  angle 65.4704525442152
}
