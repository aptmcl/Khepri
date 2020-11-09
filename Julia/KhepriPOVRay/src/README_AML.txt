The light model used rely on the work of Jaime Vives Piqueres,
available at
http://www.ignorancia.org

Particularly, we rely on a modified version of Lightsys to simulate
a realistic sky (and other sources of light)
http://www.ignorancia.org/index.php/technical/lightsys/
http://www.ignorancia.org/wp-content/uploads/zips/lightsys4d.zip

The package should be installed in

C:/Users/aml/Documents/POV-Ray/v3.7/include/

The modifications were needed to adapt Lightsys to the Radiosity method of
POVRay. They are done by the backend itself, that injects code in the output
to prevent the definition of a macro, namely, in file CIE_Skylight.inc:84

// fiLuminous corrected for allowing user to specify its own value and
// to prevent #default{} from spewing troubles here - Philippe 08 june 2003
#ifndef (fiLuminous)
  #local fiLuminous=finish{ambient 1 diffuse 0 specular 0 phong 0 reflection 0 crand 0 irid{0}}
#end

Given that we are using radiosity, we pre-define fiLuminous to prevent ambient light, i.e.,

#local fiLuminous=finish{ambient 0 emission 1 diffuse 0 specular 0 phong 0 reflection 0 crand 0 irid{0}}

and we then proceed with loading of the file.
