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
cylinder {
  <0, 0, 0>, <0.0, 0.0, 20.0>, 1
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 14.0>, 1
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -7.0, 9.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 10.0>, 1
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.0, 13.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 6.0>, 1
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.0, 17.0, 0.0>
}
plane {<30.22175,-55.8266,18.3987>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <28.1736, 26.8575, -50.1646>
  look_at <-2.04815, 8.4588, 5.662>
  right x*image_width/image_height
  angle 39.59775270904986
}
