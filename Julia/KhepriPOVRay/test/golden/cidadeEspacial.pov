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
sphere {
  <0, 0, 0>, 1.0
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 8.0>, 0.25
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.0, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 8.0>, 0.25
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 8.0>, 0.25
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -4.0, 0.0>
}
sphere {
  <-4.0, 0.0, 0.0>, 0.5
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -6.0, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -2.0, 0.0>
}
sphere {
  <-6.0, 0.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -7.0, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -6.0, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -6.0, -1.0, 0.0>
}
sphere {
  <-7.0, 0.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -7.5, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -7.0, 0.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -7.0, -0.5, 0.0>
}
sphere {
  <-7.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-7.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-7.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-7.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-7.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.5, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -5.0, 0.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -5.0, -0.5, 0.0>
}
sphere {
  <-5.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -6.5, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -6.0, 0.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -6.0, -0.5, -1.0>
}
sphere {
  <-6.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, -0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -6.5, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -6.0, 0.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -6.0, -0.5, 1.0>
}
sphere {
  <-6.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, -0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, -1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -6.5, -1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -6.0, -1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -6.0, -1.5, 0.0>
}
sphere {
  <-6.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, -1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, -1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -6.5, 1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -6.0, 1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -6.0, 0.5, 0.0>
}
sphere {
  <-6.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-6.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.0, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -1.0, 0.0>
}
sphere {
  <-3.0, 0.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, 0.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, -0.5, 0.0>
}
sphere {
  <-3.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -0.5, 0.0>
}
sphere {
  <-1.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -0.5, -1.0>
}
sphere {
  <-2.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -0.5, 1.0>
}
sphere {
  <-2.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, -1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, -1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -1.5, 0.0>
}
sphere {
  <-2.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, 0.5, 0.0>
}
sphere {
  <-2.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, -2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.0, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 0.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -1.0, -2.0>
}
sphere {
  <-5.0, 0.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.5, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -5.0, 0.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -5.0, -0.5, -2.0>
}
sphere {
  <-5.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, 0.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, -0.5, -2.0>
}
sphere {
  <-3.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 0.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 0.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -0.5, -3.0>
}
sphere {
  <-4.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 0.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -0.5, -1.0>
}
sphere {
  <-4.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, -1.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, -1.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -1.5, -2.0>
}
sphere {
  <-4.5, -1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, -1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 1.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 1.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, 0.5, -2.0>
}
sphere {
  <-4.5, 1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, 2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.0, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -1.0, 2.0>
}
sphere {
  <-5.0, 0.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.5, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -5.0, 0.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -5.0, -0.5, 2.0>
}
sphere {
  <-5.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, 0.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, -0.5, 2.0>
}
sphere {
  <-3.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 0.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -0.5, 1.0>
}
sphere {
  <-4.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 0.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 0.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -0.5, 3.0>
}
sphere {
  <-4.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, -1.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, -1.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -1.5, 2.0>
}
sphere {
  <-4.5, -1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, -1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 1.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 1.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, 0.5, 2.0>
}
sphere {
  <-4.5, 1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.0, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, -2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -3.0, 0.0>
}
sphere {
  <-5.0, -2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.5, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -5.0, -2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -5.0, -2.5, 0.0>
}
sphere {
  <-5.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, -2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, -2.5, 0.0>
}
sphere {
  <-3.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, -2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, -2.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -2.5, -1.0>
}
sphere {
  <-4.5, -2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, -2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, -2.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, -2.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -2.5, 1.0>
}
sphere {
  <-4.5, -2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, -2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, -3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, -3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -3.5, 0.0>
}
sphere {
  <-4.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, -1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, -1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, -1.5, 0.0>
}
sphere {
  <-4.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.0, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, 1.0, 0.0>
}
sphere {
  <-5.0, 2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -5.5, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -5.0, 2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -5.0, 1.5, 0.0>
}
sphere {
  <-5.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-5.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, 2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, 1.5, 0.0>
}
sphere {
  <-3.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 2.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, 1.5, -1.0>
}
sphere {
  <-4.5, 2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 2.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 2.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, 1.5, 1.0>
}
sphere {
  <-4.5, 2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, 0.5, 0.0>
}
sphere {
  <-4.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -4.5, 3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -4.0, 3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -4.0, 2.5, 0.0>
}
sphere {
  <-4.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-4.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, 0.0>, 0.5
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.0, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -2.0, 0.0>
}
sphere {
  <2.0, 0.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -1.0, 0.0>
}
sphere {
  <1.0, 0.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -0.5, 0.0>
}
sphere {
  <0.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, 0.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, -0.5, 0.0>
}
sphere {
  <2.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -0.5, -1.0>
}
sphere {
  <1.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -0.5, 1.0>
}
sphere {
  <1.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, -1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, -1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -1.5, 0.0>
}
sphere {
  <1.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, 0.5, 0.0>
}
sphere {
  <1.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 5.0, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 6.0, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 6.0, -1.0, 0.0>
}
sphere {
  <5.0, 0.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 4.5, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 5.0, 0.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 5.0, -0.5, 0.0>
}
sphere {
  <4.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <7.0, 0.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 6.5, 0.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 7.0, 0.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 7.0, -0.5, 0.0>
}
sphere {
  <6.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <7.5, 0.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <7.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <7.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <7.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <7.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 5.5, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 6.0, 0.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 6.0, -0.5, -1.0>
}
sphere {
  <5.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <6.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <6.0, -0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 5.5, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 6.0, 0.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 6.0, -0.5, 1.0>
}
sphere {
  <5.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <6.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <6.0, -0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, -1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 5.5, -1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 6.0, -1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 6.0, -1.5, 0.0>
}
sphere {
  <5.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, -1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <6.0, -1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <6.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 5.5, 1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 6.0, 1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 6.0, 0.5, 0.0>
}
sphere {
  <5.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <6.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, -2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.0, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 0.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -1.0, -2.0>
}
sphere {
  <3.0, 0.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, 0.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, -0.5, -2.0>
}
sphere {
  <2.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 4.5, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 5.0, 0.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 5.0, -0.5, -2.0>
}
sphere {
  <4.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <5.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 0.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 0.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -0.5, -3.0>
}
sphere {
  <3.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 0.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -0.5, -1.0>
}
sphere {
  <3.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, -1.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, -1.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -1.5, -2.0>
}
sphere {
  <3.5, -1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, -1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 1.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 1.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, 0.5, -2.0>
}
sphere {
  <3.5, 1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, 2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.0, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -1.0, 2.0>
}
sphere {
  <3.0, 0.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, 0.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, -0.5, 2.0>
}
sphere {
  <2.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 4.5, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 5.0, 0.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 5.0, -0.5, 2.0>
}
sphere {
  <4.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <5.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 0.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -0.5, 1.0>
}
sphere {
  <3.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 0.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 0.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -0.5, 3.0>
}
sphere {
  <3.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, -1.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, -1.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -1.5, 2.0>
}
sphere {
  <3.5, -1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, -1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 1.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 1.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, 0.5, 2.0>
}
sphere {
  <3.5, 1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.0, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, -2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -3.0, 0.0>
}
sphere {
  <3.0, -2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, -2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, -2.5, 0.0>
}
sphere {
  <2.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, -2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 4.5, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 5.0, -2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 5.0, -2.5, 0.0>
}
sphere {
  <4.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, -2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, -2.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -2.5, -1.0>
}
sphere {
  <3.5, -2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, -2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, -2.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, -2.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -2.5, 1.0>
}
sphere {
  <3.5, -2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, -2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, -3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, -3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -3.5, 0.0>
}
sphere {
  <3.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, -1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, -1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, -1.5, 0.0>
}
sphere {
  <3.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.0, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, 1.0, 0.0>
}
sphere {
  <3.0, 2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, 2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, 1.5, 0.0>
}
sphere {
  <2.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 4.5, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 5.0, 2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 5.0, 1.5, 0.0>
}
sphere {
  <4.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <5.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 2.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, 1.5, -1.0>
}
sphere {
  <3.5, 2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 2.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 2.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, 1.5, 1.0>
}
sphere {
  <3.5, 2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, 0.5, 0.0>
}
sphere {
  <3.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 3.5, 3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 4.0, 3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 4.0, 2.5, 0.0>
}
sphere {
  <3.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <4.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -4.0>, 0.5
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.0, 0.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -2.0, -4.0>
}
sphere {
  <-2.0, 0.0, -4.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.0, 0.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -1.0, -4.0>
}
sphere {
  <-3.0, 0.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, 0.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, 0.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, -0.5, -4.0>
}
sphere {
  <-3.5, 0.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, 0.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 0.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -0.5, -4.0>
}
sphere {
  <-1.5, 0.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 0.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 0.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, -5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -0.5, -5.0>
}
sphere {
  <-2.5, 0.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 0.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 0.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -0.5, -3.0>
}
sphere {
  <-2.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, -1.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, -1.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -1.5, -4.0>
}
sphere {
  <-2.5, -1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, -1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 1.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 1.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, 0.5, -4.0>
}
sphere {
  <-2.5, 1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -4.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -1.0, -4.0>
}
sphere {
  <1.0, 0.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 0.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -0.5, -4.0>
}
sphere {
  <0.5, 0.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 0.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, 0.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, 0.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, -0.5, -4.0>
}
sphere {
  <2.5, 0.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, 0.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 0.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, -5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -0.5, -5.0>
}
sphere {
  <1.5, 0.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 0.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 0.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -0.5, -3.0>
}
sphere {
  <1.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, -1.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, -1.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -1.5, -4.0>
}
sphere {
  <1.5, -1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, -1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 1.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, 0.5, -4.0>
}
sphere {
  <1.5, 1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -6.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0, -6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -7.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.0, -6.0>
}
sphere {
  <-1.0, 0.0, -6.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 0.0, -6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, -6.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -0.5, -6.0>
}
sphere {
  <-1.5, 0.0, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 0.0, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, -6.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -0.5, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.5, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -6.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 0.0, -6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, -6.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -0.5, -6.0>
}
sphere {
  <0.5, 0.0, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 0.0, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -6.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -0.5, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.5, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -7.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, -7.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -7.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -0.5, -7.0>
}
sphere {
  <-0.5, 0.0, -7.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 0.0, -7.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -7.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -6.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, -7.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, -7.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -0.5, -5.0>
}
sphere {
  <-0.5, 0.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 0.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -6.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -1.0, -6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, -6.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.5, -6.0>
}
sphere {
  <-0.5, -1.0, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -1.0, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -6.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -6.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 1.0, -6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, -6.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 0.5, -6.0>
}
sphere {
  <-0.5, 1.0, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 1.0, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -6.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, -6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.0, -2.0>
}
sphere {
  <-1.0, 0.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -0.5, -2.0>
}
sphere {
  <-1.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 0.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -0.5, -2.0>
}
sphere {
  <0.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 0.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -0.5, -3.0>
}
sphere {
  <-0.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 0.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -0.5, -1.0>
}
sphere {
  <-0.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 0.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -1.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.5, -2.0>
}
sphere {
  <-0.5, -1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 1.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 0.5, -2.0>
}
sphere {
  <-0.5, 1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 1.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -4.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, -2.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -3.0, -4.0>
}
sphere {
  <-1.0, -2.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, -2.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, -2.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -2.5, -4.0>
}
sphere {
  <-1.5, -2.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, -2.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, -2.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -2.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -2.5, -4.0>
}
sphere {
  <0.5, -2.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, -2.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -2.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, -5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -2.5, -5.0>
}
sphere {
  <-0.5, -2.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -2.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -2.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -2.5, -3.0>
}
sphere {
  <-0.5, -2.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -2.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -3.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -3.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -3.5, -4.0>
}
sphere {
  <-0.5, -3.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -3.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -1.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.5, -4.0>
}
sphere {
  <-0.5, -1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -4.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 2.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.0, -4.0>
}
sphere {
  <-1.0, 2.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 2.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 2.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, 1.5, -4.0>
}
sphere {
  <-1.5, 2.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 2.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 2.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 2.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 1.5, -4.0>
}
sphere {
  <0.5, 2.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 2.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 2.0, -5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, -5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.5, -5.0>
}
sphere {
  <-0.5, 2.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 2.0, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, -5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 2.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.5, -3.0>
}
sphere {
  <-0.5, 2.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 2.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 1.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 0.5, -4.0>
}
sphere {
  <-0.5, 1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 1.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, -4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 3.0, -4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 3.0, -4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 2.5, -4.0>
}
sphere {
  <-0.5, 3.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 3.0, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, -4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, -4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 4.0>, 0.5
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.0, 0.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -2.0, 4.0>
}
sphere {
  <-2.0, 0.0, 4.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.0, 0.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -1.0, 4.0>
}
sphere {
  <-3.0, 0.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, 0.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, 0.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, -0.5, 4.0>
}
sphere {
  <-3.5, 0.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, 0.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 0.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -0.5, 4.0>
}
sphere {
  <-1.5, 0.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 0.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 0.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -0.5, 3.0>
}
sphere {
  <-2.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 0.0, 5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 0.0, 4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -0.5, 5.0>
}
sphere {
  <-2.5, 0.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 0.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, -1.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, -1.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -1.5, 4.0>
}
sphere {
  <-2.5, -1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, -1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 1.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 1.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, 0.5, 4.0>
}
sphere {
  <-2.5, 1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 4.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -1.0, 4.0>
}
sphere {
  <1.0, 0.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 0.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -0.5, 4.0>
}
sphere {
  <0.5, 0.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 0.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, 0.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, 0.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, -0.5, 4.0>
}
sphere {
  <2.5, 0.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, 0.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 0.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -0.5, 3.0>
}
sphere {
  <1.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 0.0, 5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 0.0, 4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -0.5, 5.0>
}
sphere {
  <1.5, 0.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 0.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, -1.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, -1.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -1.5, 4.0>
}
sphere {
  <1.5, -1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, -1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 1.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, 0.5, 4.0>
}
sphere {
  <1.5, 1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.0, 2.0>
}
sphere {
  <-1.0, 0.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -0.5, 2.0>
}
sphere {
  <-1.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 0.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -0.5, 2.0>
}
sphere {
  <0.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 0.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -0.5, 1.0>
}
sphere {
  <-0.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 0.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -0.5, 3.0>
}
sphere {
  <-0.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 0.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -1.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.5, 2.0>
}
sphere {
  <-0.5, -1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 1.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 0.5, 2.0>
}
sphere {
  <-0.5, 1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 1.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 6.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0, 6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.0, 6.0>
}
sphere {
  <-1.0, 0.0, 6.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 0.0, 6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, 5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -0.5, 6.0>
}
sphere {
  <-1.5, 0.0, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 0.0, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.0, 6.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -0.5, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 0.5, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 6.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 0.0, 6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -0.5, 6.0>
}
sphere {
  <0.5, 0.0, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 0.0, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.0, 6.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -0.5, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 0.5, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, 5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -0.5, 5.0>
}
sphere {
  <-0.5, 0.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 0.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 7.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, 7.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 6.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -0.5, 7.0>
}
sphere {
  <-0.5, 0.0, 7.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 0.0, 7.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 6.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.0, 7.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, 7.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, 7.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 6.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -1.0, 6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, 5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.5, 6.0>
}
sphere {
  <-0.5, -1.0, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -1.0, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 6.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 6.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 1.0, 6.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 5.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 0.5, 6.0>
}
sphere {
  <-0.5, 1.0, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 1.0, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 6.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, 6.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 4.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, -2.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -3.0, 4.0>
}
sphere {
  <-1.0, -2.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, -2.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, -2.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -2.5, 4.0>
}
sphere {
  <-1.5, -2.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, -2.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, -2.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -2.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -2.5, 4.0>
}
sphere {
  <0.5, -2.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, -2.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -2.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -2.5, 3.0>
}
sphere {
  <-0.5, -2.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -2.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -2.0, 5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, 4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -2.5, 5.0>
}
sphere {
  <-0.5, -2.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -2.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -3.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -3.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -3.5, 4.0>
}
sphere {
  <-0.5, -3.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -3.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -1.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.5, 4.0>
}
sphere {
  <-0.5, -1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 4.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 2.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.0, 4.0>
}
sphere {
  <-1.0, 2.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 2.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 2.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, 1.5, 4.0>
}
sphere {
  <-1.5, 2.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 2.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 2.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 2.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 1.5, 4.0>
}
sphere {
  <0.5, 2.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 2.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 2.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.5, 3.0>
}
sphere {
  <-0.5, 2.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 2.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 5.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 2.0, 5.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, 4.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.5, 5.0>
}
sphere {
  <-0.5, 2.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 2.0, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 5.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, 5.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 1.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 0.5, 4.0>
}
sphere {
  <-0.5, 1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 1.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, 4.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 3.0, 4.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 3.0, 3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 2.5, 4.0>
}
sphere {
  <-0.5, 3.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 3.0, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, 4.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, 4.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, 0.0>, 0.5
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.0, -4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -4.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -6.0, 0.0>
}
sphere {
  <-2.0, -4.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.0, -4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, -4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -5.0, 0.0>
}
sphere {
  <-3.0, -4.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, -4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, -4.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, -4.5, 0.0>
}
sphere {
  <-3.5, -4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, -4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, -4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, -4.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -4.5, 0.0>
}
sphere {
  <-1.5, -4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, -4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, -4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, -4.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -4.5, -1.0>
}
sphere {
  <-2.5, -4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, -4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -3.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, -4.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, -4.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -4.5, 1.0>
}
sphere {
  <-2.5, -4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, -4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -3.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -5.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, -5.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, -5.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -5.5, 0.0>
}
sphere {
  <-2.5, -5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, -5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -5.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -5.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, -3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, -3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, -3.5, 0.0>
}
sphere {
  <-2.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, -4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, -4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -5.0, 0.0>
}
sphere {
  <1.0, -4.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, -4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -4.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -4.5, 0.0>
}
sphere {
  <0.5, -4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, -4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -4.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, -4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, -4.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, -4.5, 0.0>
}
sphere {
  <2.5, -4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, -4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, -4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, -4.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -4.5, -1.0>
}
sphere {
  <1.5, -4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, -4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -3.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, -4.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, -4.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -4.5, 1.0>
}
sphere {
  <1.5, -4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, -4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -3.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -5.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, -5.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, -5.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -5.5, 0.0>
}
sphere {
  <1.5, -5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, -5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -5.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -5.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, -3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, -3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, -3.5, 0.0>
}
sphere {
  <1.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, -2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, -4.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -4.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -5.0, -2.0>
}
sphere {
  <-1.0, -4.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, -4.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, -4.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -4.5, -2.0>
}
sphere {
  <-1.5, -4.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, -4.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -3.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, -4.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -4.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -4.5, -2.0>
}
sphere {
  <0.5, -4.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, -4.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -3.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -4.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -4.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -4.5, -3.0>
}
sphere {
  <-0.5, -4.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -4.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -4.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -4.5, -1.0>
}
sphere {
  <-0.5, -4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -5.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -5.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -5.5, -2.0>
}
sphere {
  <-0.5, -5.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -5.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -3.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -3.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -3.5, -2.0>
}
sphere {
  <-0.5, -3.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -3.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, 2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, -4.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -4.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -5.0, 2.0>
}
sphere {
  <-1.0, -4.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, -4.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, -4.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -4.5, 2.0>
}
sphere {
  <-1.5, -4.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, -4.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -4.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -3.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, -4.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -4.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -4.5, 2.0>
}
sphere {
  <0.5, -4.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, -4.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -4.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -3.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -4.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -4.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -4.5, 1.0>
}
sphere {
  <-0.5, -4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -4.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -4.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -4.5, 3.0>
}
sphere {
  <-0.5, -4.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -4.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -5.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -5.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -5.5, 2.0>
}
sphere {
  <-0.5, -5.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -5.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -3.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -3.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -3.5, 2.0>
}
sphere {
  <-0.5, -3.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -3.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, -6.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -6.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -7.0, 0.0>
}
sphere {
  <-1.0, -6.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, -6.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, -6.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -6.5, 0.0>
}
sphere {
  <-1.5, -6.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, -6.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -6.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -6.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -6.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -6.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, -6.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -6.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -6.5, 0.0>
}
sphere {
  <0.5, -6.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, -6.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -6.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -6.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -6.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -6.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -6.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -6.5, -1.0>
}
sphere {
  <-0.5, -6.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -6.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -6.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -6.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -6.5, 1.0>
}
sphere {
  <-0.5, -6.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -6.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -7.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -7.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -7.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -7.5, 0.0>
}
sphere {
  <-0.5, -7.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -7.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -7.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -7.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -7.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -6.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -5.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -5.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -5.5, 0.0>
}
sphere {
  <-0.5, -5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -3.0, 0.0>
}
sphere {
  <-1.0, -2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, -2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, -2.5, 0.0>
}
sphere {
  <-1.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, -2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, -2.5, 0.0>
}
sphere {
  <0.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, -2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -2.5, -1.0>
}
sphere {
  <-0.5, -2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -2.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -2.5, 1.0>
}
sphere {
  <-0.5, -2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -3.5, 0.0>
}
sphere {
  <-0.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, -1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, -1.5, 0.0>
}
sphere {
  <-0.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, -1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, -0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, 0.0>, 0.5
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.0, 4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 4.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 4.0>, 0.125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 2.0, 0.0>
}
sphere {
  <-2.0, 4.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.0, 4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, 3.0, 0.0>
}
sphere {
  <-3.0, 4.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -3.5, 4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -3.0, 4.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -3.0, 3.5, 0.0>
}
sphere {
  <-3.5, 4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.5, 4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-3.0, 4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 4.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, 3.5, 0.0>
}
sphere {
  <-1.5, 4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 4.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, 3.5, -1.0>
}
sphere {
  <-2.5, 4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 3.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 4.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 4.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, 3.5, 1.0>
}
sphere {
  <-2.5, 4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 3.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, 2.5, 0.0>
}
sphere {
  <-2.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 5.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -2.5, 5.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -2.0, 5.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -2.0, 4.5, 0.0>
}
sphere {
  <-2.5, 5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.5, 5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 5.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 5.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-2.0, 5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, 3.0, 0.0>
}
sphere {
  <1.0, 4.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 4.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 3.5, 0.0>
}
sphere {
  <0.5, 4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 4.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 2.5, 4.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 3.0, 4.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 3.0, 3.5, 0.0>
}
sphere {
  <2.5, 4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.5, 4.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <3.0, 4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 4.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, 3.5, -1.0>
}
sphere {
  <1.5, 4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 3.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 4.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 4.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, 3.5, 1.0>
}
sphere {
  <1.5, 4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 3.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, 2.5, 0.0>
}
sphere {
  <1.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 5.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.5, 5.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 5.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 2.0, 4.5, 0.0>
}
sphere {
  <1.5, 5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.5, 5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 5.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 5.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <2.0, 5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, -2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 4.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 4.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 3.0, -2.0>
}
sphere {
  <-1.0, 4.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 4.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 4.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, 3.5, -2.0>
}
sphere {
  <-1.5, 4.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 4.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 3.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 4.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 4.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 3.5, -2.0>
}
sphere {
  <0.5, 4.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 4.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 3.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, -3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 4.0, -3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 4.0, -3.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 3.5, -3.0>
}
sphere {
  <-0.5, 4.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 4.0, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, -3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.5, -3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 4.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 4.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 3.5, -1.0>
}
sphere {
  <-0.5, 4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 4.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 3.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 3.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 2.5, -2.0>
}
sphere {
  <-0.5, 3.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 3.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, -2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 5.0, -2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 5.0, -2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 4.5, -2.0>
}
sphere {
  <-0.5, 5.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 5.0, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, -2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.5, -2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, 2.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 4.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 4.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 3.0, 2.0>
}
sphere {
  <-1.0, 4.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 4.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 4.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, 3.5, 2.0>
}
sphere {
  <-1.5, 4.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 4.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 3.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 4.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 4.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 4.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 3.5, 2.0>
}
sphere {
  <0.5, 4.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 4.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 3.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 4.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 4.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 4.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 3.5, 1.0>
}
sphere {
  <-0.5, 4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 4.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, 3.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 4.0, 3.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 4.0, 2.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 3.5, 3.0>
}
sphere {
  <-0.5, 4.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 4.0, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.0, 3.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.5, 3.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 3.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 3.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 2.5, 2.0>
}
sphere {
  <-0.5, 3.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 3.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, 2.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 5.0, 2.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 5.0, 1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 4.5, 2.0>
}
sphere {
  <-0.5, 5.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 5.0, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, 2.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.5, 2.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0>
}
sphere {
  <-1.0, 2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, 1.5, 0.0>
}
sphere {
  <-1.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 2.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 2.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 1.5, 0.0>
}
sphere {
  <0.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 2.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 2.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.5, -1.0>
}
sphere {
  <-0.5, 2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 2.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 2.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 2.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 1.5, 1.0>
}
sphere {
  <-0.5, 2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 2.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 1.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 0.5, 0.0>
}
sphere {
  <-0.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 1.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 0.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 1.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 3.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 3.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 2.5, 0.0>
}
sphere {
  <-0.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 3.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 2.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 3.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.0, 0.0>, 0.25
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 6.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 6.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 2.0>, 0.0625
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 5.0, 0.0>
}
sphere {
  <-1.0, 6.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.5, 6.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 6.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, -1.0, 5.5, 0.0>
}
sphere {
  <-1.5, 6.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-0.5, 6.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 6.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 6.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <-1.0, 6.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 6.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.5, 6.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 6.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 5.5, 0.0>
}
sphere {
  <0.5, 6.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.5, 6.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 6.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 6.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <1.0, 6.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.0, -1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 6.0, -1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 6.0, -1.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 5.5, -1.0>
}
sphere {
  <-0.5, 6.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 6.0, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.0, -1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.5, -1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.0, 1.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 6.0, 1.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 6.0, 0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 5.5, 1.0>
}
sphere {
  <-0.5, 6.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 6.0, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.0, 1.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.5, 1.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 5.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 5.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 4.5, 0.0>
}
sphere {
  <-0.5, 5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 5.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 4.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 5.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 7.0, 0.0>, 0.125
  texture { Material }
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -0.5, 7.0, 0.0>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <-1.0, 0.0, 1.2246467991473532e-16, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 7.0, -0.5>
}
cylinder {
  <0, 0, 0>, <0.0, 0.0, 1.0>, 0.03125
  texture { Material }
  matrix <6.123233995736766e-17, 0.0, 1.0, -1.0, 0.0, 6.123233995736766e-17, 0.0, 1.0, 0.0, 0.0, 6.5, 0.0>
}
sphere {
  <-0.5, 7.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.5, 7.0, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 7.0, -0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 7.0, 0.5>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 6.5, 0.0>, 0.0625
  texture { Material }
}
sphere {
  <0.0, 7.5, 0.0>, 0.0625
  texture { Material }
}
plane {<11.55684,5.87514,3.256026>, -10000 texture { pigment { color rgb <0,0,0> }}}
camera {
  location <3.79426, 2.4499, 3.1758>
  look_at <-7.76258, -0.806126, -2.69934>
  right x*image_width/image_height
  angle 54.43222311461495
}
