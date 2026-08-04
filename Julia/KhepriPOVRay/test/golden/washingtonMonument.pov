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
  5, <-1.543054966925665e-15, 0, -8.4>, <-8.4, 0, 1.0287033112837768e-15>, <5.143516556418884e-16, 0, 8.4>, <8.4, 0, 0.0>, <-1.543054966925665e-15, 0, -8.4>
  texture { Material }
}
triangle {
  <8.4, 0, 0.0>, <5.143516556418884e-16, 0, 8.4>, <3.214697847761802e-16, 152.4, 5.25>
  texture { Material }
}
triangle {
  <8.4, 0, 0.0>, <3.214697847761802e-16, 152.4, 5.25>, <5.25, 152.4, 0.0>
  texture { Material }
}
triangle {
  <5.143516556418884e-16, 0, 8.4>, <-8.4, 0, 1.0287033112837768e-15>, <-5.25, 152.4, 6.429395695523604e-16>
  texture { Material }
}
triangle {
  <5.143516556418884e-16, 0, 8.4>, <-5.25, 152.4, 6.429395695523604e-16>, <3.214697847761802e-16, 152.4, 5.25>
  texture { Material }
}
triangle {
  <-8.4, 0, 1.0287033112837768e-15>, <-1.543054966925665e-15, 0, -8.4>, <-9.644093543285407e-16, 152.4, -5.25>
  texture { Material }
}
triangle {
  <-8.4, 0, 1.0287033112837768e-15>, <-9.644093543285407e-16, 152.4, -5.25>, <-5.25, 152.4, 6.429395695523604e-16>
  texture { Material }
}
triangle {
  <-1.543054966925665e-15, 0, -8.4>, <8.4, 0, 0.0>, <5.25, 152.4, 0.0>
  texture { Material }
}
triangle {
  <-1.543054966925665e-15, 0, -8.4>, <5.25, 152.4, 0.0>, <-9.644093543285407e-16, 152.4, -5.25>
  texture { Material }
}
polygon {
  5, <5.25, 152.4, 0.0>, <3.214697847761802e-16, 152.4, 5.25>, <-5.25, 152.4, 6.429395695523604e-16>, <-9.644093543285407e-16, 152.4, -5.25>, <5.25, 152.4, 0.0>
  texture { Material }
}
polygon {
  5, <-9.644093543285407e-16, 152.4, -5.25>, <-5.25, 152.4, 6.429395695523604e-16>, <3.214697847761802e-16, 152.4, 5.25>, <5.25, 152.4, 0.0>, <-9.644093543285407e-16, 152.4, -5.25>
  texture { Material }
}
triangle {
  <0.0, 169.3, 0.0>, <-9.644093543285407e-16, 152.4, -5.25>, <5.25, 152.4, 0.0>
  texture { Material }
}
triangle {
  <0.0, 169.3, 0.0>, <5.25, 152.4, 0.0>, <3.214697847761802e-16, 152.4, 5.25>
  texture { Material }
}
triangle {
  <0.0, 169.3, 0.0>, <3.214697847761802e-16, 152.4, 5.25>, <-5.25, 152.4, 6.429395695523604e-16>
  texture { Material }
}
triangle {
  <0.0, 169.3, 0.0>, <-5.25, 152.4, 6.429395695523604e-16>, <-9.644093543285407e-16, 152.4, -5.25>
  texture { Material }
}
plane {<-99.5886,425.71799999999996,-161.53338000000002>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <-32.7059, 4.69462, 169.073>
  look_at <66.8827, 166.228, -256.645>
  right x*image_width/image_height
  angle 83.97442499163331
}
