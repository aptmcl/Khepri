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
cone {
  <0.0, 0.0, 0.0>, 1, <5.0, 0.0, 0.0>, 2
  texture { Material }
}
cone {
  <0.0, 0.0, 0.0>, 1, <0.0, 0.0, 5.0>, 2
  texture { Material }
}
cone {
  <0.0, 0.0, 0.0>, 1, <0.0, 5.0, 0.0>, 2
  texture { Material }
}
cone {
  <0.0, 0.0, 0.0>, 1, <-5.0, 0.0, 0.0>, 2
  texture { Material }
}
cone {
  <0.0, 0.0, 0.0>, 1, <0.0, 0.0, -5.0>, 2
  texture { Material }
}
cone {
  <0.0, 0.0, 0.0>, 1, <0.0, -5.0, 0.0>, 2
  texture { Material }
}
cone {
  <12.0, 0.0, 0.0>, 2, <17.0, 0.0, 0.0>, 1
  texture { Material }
}
cone {
  <12.0, 0.0, 0.0>, 2, <12.0, 0.0, 5.0>, 1
  texture { Material }
}
cone {
  <12.0, 0.0, 0.0>, 2, <12.0, 5.0, 0.0>, 1
  texture { Material }
}
cone {
  <12.0, 0.0, 0.0>, 2, <7.0, 0.0, 0.0>, 1
  texture { Material }
}
cone {
  <12.0, 0.0, 0.0>, 2, <12.0, 0.0, -5.0>, 1
  texture { Material }
}
cone {
  <12.0, 0.0, 0.0>, 2, <12.0, -5.0, 0.0>, 1
  texture { Material }
}
cone {
  <24.0, 0.0, 0.0>, 2, <26.0, 0.0, 0.0>, 4
  texture { Material }
}
cone {
  <24.0, 0.0, 0.0>, 2, <24.0, 0.0, 2.0>, 4
  texture { Material }
}
cone {
  <24.0, 0.0, 0.0>, 2, <24.0, 2.0, 0.0>, 4
  texture { Material }
}
cone {
  <24.0, 0.0, 0.0>, 2, <22.0, 0.0, 0.0>, 4
  texture { Material }
}
cone {
  <24.0, 0.0, 0.0>, 2, <24.0, 0.0, -2.0>, 4
  texture { Material }
}
cone {
  <24.0, 0.0, 0.0>, 2, <24.0, -2.0, 0.0>, 4
  texture { Material }
}
plane {<-0.16999999999999993,-0.8299999999999983,0.5299999999999976>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <2.79, 23.97, -35.61>
  look_at <2.96, 23.44, -34.78>
  right x*image_width/image_height
  angle 39.59775270904986
}
