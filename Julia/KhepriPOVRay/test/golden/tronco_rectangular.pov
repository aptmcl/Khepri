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
  5, <-40.4, 0.0, 25.15>, <40.4, 0.0, 25.15>, <40.4, 0.0, -25.15>, <-40.4, 0.0, -25.15>, <-40.4, 0.0, 25.15>
  texture { Material }
}
triangle {
  <-40.4, 0.0, -25.15>, <40.4, 0.0, -25.15>, <27.55, 344.0, -17.15>
  texture { Material }
}
triangle {
  <-40.4, 0.0, -25.15>, <27.55, 344.0, -17.15>, <-27.55, 344.0, -17.15>
  texture { Material }
}
triangle {
  <40.4, 0.0, -25.15>, <40.4, 0.0, 25.15>, <27.55, 344.0, 17.15>
  texture { Material }
}
triangle {
  <40.4, 0.0, -25.15>, <27.55, 344.0, 17.15>, <27.55, 344.0, -17.15>
  texture { Material }
}
triangle {
  <40.4, 0.0, 25.15>, <-40.4, 0.0, 25.15>, <-27.55, 344.0, 17.15>
  texture { Material }
}
triangle {
  <40.4, 0.0, 25.15>, <-27.55, 344.0, 17.15>, <27.55, 344.0, 17.15>
  texture { Material }
}
triangle {
  <-40.4, 0.0, 25.15>, <-40.4, 0.0, -25.15>, <-27.55, 344.0, -17.15>
  texture { Material }
}
triangle {
  <-40.4, 0.0, 25.15>, <-27.55, 344.0, -17.15>, <-27.55, 344.0, 17.15>
  texture { Material }
}
polygon {
  5, <-27.55, 344.0, -17.15>, <27.55, 344.0, -17.15>, <27.55, 344.0, 17.15>, <-27.55, 344.0, 17.15>, <-27.55, 344.0, -17.15>
  texture { Material }
}
polygon {
  5, <160.0, 0.0, 25.0>, <240.0, 0.0, 25.0>, <240.0, 0.0, -25.0>, <160.0, 0.0, -25.0>, <160.0, 0.0, 25.0>
  texture { Material }
}
triangle {
  <160.0, 0.0, -25.0>, <240.0, 0.0, -25.0>, <205.0, 300.0, -15.0>
  texture { Material }
}
triangle {
  <160.0, 0.0, -25.0>, <205.0, 300.0, -15.0>, <195.0, 300.0, -15.0>
  texture { Material }
}
triangle {
  <240.0, 0.0, -25.0>, <240.0, 0.0, 25.0>, <205.0, 300.0, 15.0>
  texture { Material }
}
triangle {
  <240.0, 0.0, -25.0>, <205.0, 300.0, 15.0>, <205.0, 300.0, -15.0>
  texture { Material }
}
triangle {
  <240.0, 0.0, 25.0>, <160.0, 0.0, 25.0>, <195.0, 300.0, 15.0>
  texture { Material }
}
triangle {
  <240.0, 0.0, 25.0>, <195.0, 300.0, 15.0>, <205.0, 300.0, 15.0>
  texture { Material }
}
triangle {
  <160.0, 0.0, 25.0>, <160.0, 0.0, -25.0>, <195.0, 300.0, -15.0>
  texture { Material }
}
triangle {
  <160.0, 0.0, 25.0>, <195.0, 300.0, -15.0>, <195.0, 300.0, 15.0>
  texture { Material }
}
polygon {
  5, <195.0, 300.0, -15.0>, <205.0, 300.0, -15.0>, <205.0, 300.0, 15.0>, <195.0, 300.0, 15.0>, <195.0, 300.0, -15.0>
  texture { Material }
}
polygon {
  5, <375.0, 0.0, 25.0>, <425.0, 0.0, 25.0>, <425.0, 0.0, -25.0>, <375.0, 0.0, -25.0>, <375.0, 0.0, 25.0>
  texture { Material }
}
triangle {
  <375.0, 0.0, -25.0>, <425.0, 0.0, -25.0>, <435.0, 350.0, -35.0>
  texture { Material }
}
triangle {
  <375.0, 0.0, -25.0>, <435.0, 350.0, -35.0>, <365.0, 350.0, -35.0>
  texture { Material }
}
triangle {
  <425.0, 0.0, -25.0>, <425.0, 0.0, 25.0>, <435.0, 350.0, 35.0>
  texture { Material }
}
triangle {
  <425.0, 0.0, -25.0>, <435.0, 350.0, 35.0>, <435.0, 350.0, -35.0>
  texture { Material }
}
triangle {
  <425.0, 0.0, 25.0>, <375.0, 0.0, 25.0>, <365.0, 350.0, 35.0>
  texture { Material }
}
triangle {
  <425.0, 0.0, 25.0>, <365.0, 350.0, 35.0>, <435.0, 350.0, 35.0>
  texture { Material }
}
triangle {
  <375.0, 0.0, 25.0>, <375.0, 0.0, -25.0>, <365.0, 350.0, -35.0>
  texture { Material }
}
triangle {
  <375.0, 0.0, 25.0>, <365.0, 350.0, -35.0>, <365.0, 350.0, 35.0>
  texture { Material }
}
polygon {
  5, <365.0, 350.0, -35.0>, <435.0, 350.0, -35.0>, <435.0, 350.0, 35.0>, <365.0, 350.0, 35.0>, <365.0, 350.0, -35.0>
  texture { Material }
}
polygon {
  5, <590.0, 0.0, 20.0>, <610.0, 0.0, 20.0>, <610.0, 0.0, -20.0>, <590.0, 0.0, -20.0>, <590.0, 0.0, 20.0>
  texture { Material }
}
triangle {
  <590.0, 0.0, -20.0>, <610.0, 0.0, -20.0>, <645.0, 320.0, -5.0>
  texture { Material }
}
triangle {
  <590.0, 0.0, -20.0>, <645.0, 320.0, -5.0>, <555.0, 320.0, -5.0>
  texture { Material }
}
triangle {
  <610.0, 0.0, -20.0>, <610.0, 0.0, 20.0>, <645.0, 320.0, 5.0>
  texture { Material }
}
triangle {
  <610.0, 0.0, -20.0>, <645.0, 320.0, 5.0>, <645.0, 320.0, -5.0>
  texture { Material }
}
triangle {
  <610.0, 0.0, 20.0>, <590.0, 0.0, 20.0>, <555.0, 320.0, 5.0>
  texture { Material }
}
triangle {
  <610.0, 0.0, 20.0>, <555.0, 320.0, 5.0>, <645.0, 320.0, 5.0>
  texture { Material }
}
triangle {
  <590.0, 0.0, 20.0>, <590.0, 0.0, -20.0>, <555.0, 320.0, -5.0>
  texture { Material }
}
triangle {
  <590.0, 0.0, 20.0>, <555.0, 320.0, -5.0>, <555.0, 320.0, 5.0>
  texture { Material }
}
polygon {
  5, <555.0, 320.0, -5.0>, <645.0, 320.0, -5.0>, <645.0, 320.0, 5.0>, <555.0, 320.0, 5.0>, <555.0, 320.0, -5.0>
  texture { Material }
}
plane {<-1476.843,-4115.689899999999,356.07500000000005>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <-1224.75, 528.056, -4154.03>
  look_at <252.093, 171.981, -38.3401>
  right x*image_width/image_height
  angle 10.285529115768483
}
