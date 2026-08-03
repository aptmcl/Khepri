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
triangle {
  <1, 0, 0>, <1, 0, 2>, <1.0, 1.0, 2.0>
  -1
}
triangle {
  <1, 0, 0>, <1.0, 1.0, 2.0>, <1.0, 1.0, 0.0>
  -1
}
triangle {
  <1, 0, 2>, <15, 0, 2>, <15.0, 1.0, 2.0>
  -1
}
triangle {
  <1, 0, 2>, <15.0, 1.0, 2.0>, <1.0, 1.0, 2.0>
  -1
}
triangle {
  <15, 0, 2>, <15, 0, 7>, <15.0, 1.0, 7.0>
  -1
}
triangle {
  <15, 0, 2>, <15.0, 1.0, 7.0>, <15.0, 1.0, 2.0>
  -1
}
triangle {
  <15, 0, 7>, <6, 0, 7>, <6.0, 1.0, 7.0>
  -1
}
triangle {
  <15, 0, 7>, <6.0, 1.0, 7.0>, <15.0, 1.0, 7.0>
  -1
}
triangle {
  <6, 0, 7>, <3, 0, 6>, <3.0, 1.0, 6.0>
  -1
}
triangle {
  <6, 0, 7>, <3.0, 1.0, 6.0>, <6.0, 1.0, 7.0>
  -1
}
triangle {
  <3, 0, 6>, <13, 0, 6>, <13.0, 1.0, 6.0>
  -1
}
triangle {
  <3, 0, 6>, <13.0, 1.0, 6.0>, <3.0, 1.0, 6.0>
  -1
}
triangle {
  <13, 0, 6>, <13, 0, 3>, <13.0, 1.0, 3.0>
  -1
}
triangle {
  <13, 0, 6>, <13.0, 1.0, 3.0>, <13.0, 1.0, 6.0>
  -1
}
triangle {
  <13, 0, 3>, <5, 0, 3>, <5.0, 1.0, 3.0>
  -1
}
triangle {
  <13, 0, 3>, <5.0, 1.0, 3.0>, <13.0, 1.0, 3.0>
  -1
}
triangle {
  <5, 0, 3>, <0, 0, 5>, <0.0, 1.0, 5.0>
  -1
}
triangle {
  <5, 0, 3>, <0.0, 1.0, 5.0>, <5.0, 1.0, 3.0>
  -1
}
triangle {
  <0, 0, 5>, <0, 0, 2>, <0.0, 1.0, 2.0>
  -1
}
triangle {
  <0, 0, 5>, <0.0, 1.0, 2.0>, <0.0, 1.0, 5.0>
  -1
}
triangle {
  <0, 0, 2>, <1, 0, 0>, <1.0, 1.0, 0.0>
  -1
}
triangle {
  <0, 0, 2>, <1.0, 1.0, 0.0>, <0.0, 1.0, 2.0>
  -1
}
plane {<-16.3902,-62.930099999999996,76.8981>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <-8.1453, 71.7539, -54.7236>
  look_at <8.2449, -5.1442, 8.2065>
  right x*image_width/image_height
  angle 10.336935952676605
}
