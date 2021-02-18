/*
  
  Internal tool for cie.inc to  
  - calculate xyz<->rgb matrices
  - calculate chromatic adaption matrices
  - calculate all CIE standard illuminants
  - calculate infinite temperature whitepoint
  - initialize RefWhiteSP
  
  Note:
  the factor 1.4388/1.4380 is the result of
  the revised Boltzmann constant. Look at the
  description for the PlanckBlackBody function
  in cie.inc for details. 
  
  Ive, 4/2003.

*/

#declare CIE_MultiObserver = true; 
#declare CIE_Debug = true;
#include "CIE.inc"
#include "espd_cie_standard.inc"
                  
CIE_ColorSystemWhitepoint(sRGB_ColSys,Daylight2Whitepoint((1.4388/1.4380)*6500))

//=======================================================================
           
#declare A   = Blackbody2Whitepoint(2856);

#declare B   = Illuminant2Whitepoint(ES_Illuminant_B);
#declare C   = Illuminant2Whitepoint(ES_Illuminant_C);

#declare D50 = Daylight2Whitepoint((1.4388/1.4380)*5000);
#declare D55 = Daylight2Whitepoint((1.4388/1.4380)*5500);
#declare D65 = Daylight2Whitepoint((1.4388/1.4380)*6500);
#declare D75 = Daylight2Whitepoint((1.4388/1.4380)*7500);

#declare E   = Illuminant2Whitepoint(ES_Illuminant_E);

#declare F1  = Illuminant2Whitepoint(ES_Illuminant_F1);
#declare F2  = Illuminant2Whitepoint(ES_Illuminant_F2);
#declare F3  = Illuminant2Whitepoint(ES_Illuminant_F3);
#declare F4  = Illuminant2Whitepoint(ES_Illuminant_F4);
#declare F5  = Illuminant2Whitepoint(ES_Illuminant_F5);
#declare F6  = Illuminant2Whitepoint(ES_Illuminant_F6);
#declare F7  = Illuminant2Whitepoint(ES_Illuminant_F7);
#declare F8  = Illuminant2Whitepoint(ES_Illuminant_F8);
#declare F9  = Illuminant2Whitepoint(ES_Illuminant_F9);
#declare F10 = Illuminant2Whitepoint(ES_Illuminant_F10);
#declare F11 = Illuminant2Whitepoint(ES_Illuminant_F11);
#declare F12 = Illuminant2Whitepoint(ES_Illuminant_F12);

#declare I   = Blackbody2Whitepoint(1e16);

//==================================================================

#if (CIE_MultiObserver)
#macro DebugWP(I,W)
  #debug concat("#declare Illuminant_",I," = array[3][2] {\n")
  #debug concat("  {",str(W[0][0],1,5),", ",str(W[0][1],1,5),"}\n")
  #debug concat("  {",str(W[1][0],1,5),", ",str(W[1][1],1,5),"}\n")
  #debug concat("  {",str(W[2][0],1,5),", ",str(W[2][1],1,5),"}\n")
  #debug "}\n"
#end   
#else
#macro DebugWP(I,W)
  #debug concat("#declare Illuminant_",I," = array[2] \n")
  #debug concat("  {",str(W[0],1,5),", ",str(W[1],1,5)"}\n")
#end   
#end

#macro DebugRefWhiteD(K)
  #local M1=0; #local M2=0;
  DaylightM1M2((1.4388/1.4380)*K,M1,M2)
  #debug "RefWhiteSP = spline{ linear_spline\n"
  #local I=0;
  #while (I<77) 
    #debug concat("  ",str(380+I*5,1,0),", ",str((DS012[I][0]+M1*DS012[I][1]+M2*DS012[I][2])/100,1,6),"\n")
    #local I=I+1;
  #end
  #debug "}\n"
#end


#debug "\n"

DebugWP("A",A)
DebugWP("B",B)
DebugWP("C",C)
DebugWP("D50",D50)
DebugWP("D55",D55)
DebugWP("D65",D65)
DebugWP("D75",D75)
DebugWP("E",E)
DebugWP("F1",F1)
DebugWP("F2",F2)
DebugWP("F3",F3)
DebugWP("F4",F4)
DebugWP("F5",F5)
DebugWP("F6",F6)
DebugWP("F7",F7)
DebugWP("F8",F8)
DebugWP("F9",F9)
DebugWP("F10",F10)
DebugWP("F11",F11)
DebugWP("F12",F12)
DebugWP("InfiniteTemp",I)

#debug "\n"

DebugRefWhiteD(5000)

#debug "\n"

//==================================================================

