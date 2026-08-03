LightsysIV
==========

  Lightsys is now much more than an automatic lighting system for POV-Ray. It 
includes the CIE XYZ Color Model for POV-Ray by Ive, wich Lightsys uses for the
light colors, but that can be used for many other purposes (the most notable
the use of reflective spectrums). It also includes an adaptation of the Skylight
include by Philippe Debar, to make it usable with Lightsys and the CIE.inc.


Installation
------------

  Copy the main include files to your include directory, or better configure 
  the LightsysIV folder as and additional library path on your povray.ini or
  your .povrayrc. You need to do this to render the demo and test scene, as
  they are on separate folders (or move the demo and test files to the main
  LightsysIV folder).


Contents
--------

  / 

   CIE.inc: main XYZ color space macros 
   CIE_precalculation.pov : precalculate system stuff, for the curious only.
   CIE_Skylight.inc: lightsys version of Skylight.inc by Philippe Debar
   CIE_tools.inc: auxiliar CIE macros

   lightsys.inc : macros to create realistic lights using spectrums 
   lightsys_constants.inc : other non-spectral data for use with lightsys 
   lightsys_colors.inc : precalculated colors for use with lightsys 

   readme.txt : this file
   readme_cie.txt : help file for the CIE package. 
   readme_lightsys.txt : help file for the Lightsys package.
   readme_skylight.txt : help file for the Skylight include.
 
   espd_cie_standard.inc: emission SPDs for standard CIE illuminants 
   espd_lightsys.inc : emission SPDs for real illuminants 
   espd_sun.inc : accurate extraterrestrial sun emission SPD 
   lspd_elements : line spectra for some atomic elements & aux. macros 
   rspd_aster.inc : reflectance SPDs for some ASTER samples 
   rspd_lunar.inc : reflectance SPDs for ASTER lunar samples 
   rspd_jvp.inc : reflectance SPDs sampled at home by Jaime Vives 
   rspd_pantone_*.inc : reflectance SPDs for some PANTONE colors 

  /tests 

   test_lightsys.pov : basic test scene for lightsys
   test_kelvin.pov : test scene for the blackbody temperature converters
   test_espd.pov : emission SPD visualization for comparisons
   test_sun.pov : solar spectrum test for espd_sun.inc
   test_lspd.pov :  line SPD visualization for comparisons
   test_rspd.pov :  reflectance SPD visualization for comparisons
   test_cornell.pov : classic cornell-box test (3)
   rspd_cornell : reflectance SPDs for the Cornell Box materials 

  /demos 

   demo_indoor1.pov : usage demo for indoor scenes 
   demo_indoor2.pov : another demo for indoor scenes
   demo_outdoor.pov : usage demo for outdoor setups 
   demo_space1.pov : usage demos for space setups 
   demo_space2.pov : usage demos for space setups 
   demo_starfield.inc : common stafield macros for the space setup demos
   demo_image_map.pov : demo of image_map CIE color transformations
   demo_cyndi_cubes.pov : demo of image_map CIE color transformations
   im_test_*.jpg: test image maps for demo_image_map.pov 
   cyndi.png & ryb.png : test image maps for several demo scenes

  /templates 

   LightsysIV basic scene.txt : template for basic LightsysIV scene
   LightsysIV indoor scene.txt : template for typical indoor scene
   LightsysIV skylight scene.txt : template for skylight scene
   LightsysIV basic scene.bmp : thumbnail for the basic template 
   LightsysIV indoor scene.bmp : thumbnail for the indoor template
   LightsysIV skylight scene.bmp : thumbnail for the skylight template


Usage
-----

  See the specific readme files for more details, and look at the demos and 
  tests folders for some real examples.


--
Jaime & Ive, Oct-2003. 


