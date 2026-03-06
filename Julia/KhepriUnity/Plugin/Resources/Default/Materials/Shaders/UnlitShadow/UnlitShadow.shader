// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnlitWithShadows" 
{
	Properties
	{
		_Color("Color", COLOR) = (1,1,1,1)
		_MainTex("Texture", 2D) = "white" {}
	}
	
	Subshader 
	{
		Tags
		{ 
			"RenderType" = "" 
			"Queue" = "Geometry" 
			"PerformanceChecks" = "False" 
		}

		Pass 
		{
			Name "Diffuse"
			Tags{ "LightMode" = "ForwardBase" }
			Lighting Off

			CGPROGRAM
				#pragma multi_compile_fwdbase
				#pragma vertex Vert
				#pragma fragment Frag
				#include "UnityCG.cginc"
				#include "AutoLight.cginc"

				uniform half4 _Color;
				uniform sampler2D _MainTex;
				uniform half4 _MainTex_ST;

				struct V2f {
					half4 pos : SV_POSITION;
					half2 uv : TEXCOORD0;
					SHADOW_COORDS(1)
				};

				V2f Vert(appdata_base v)
				{
					V2f o;
					o.pos = UnityObjectToClipPos(v.vertex);
					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

					TRANSFER_SHADOW(o);

					return o;
				}

				half4 Frag(V2f i) : SV_Target
				{
					half4 tex = tex2D(_MainTex, i.uv) * _Color;

					return tex * SHADOW_ATTENUATION(i);
				}
			ENDCG
		}

		Pass
		{
			Name "ShadowCaster"
			Tags
			{ 
				"LightMode" = "ShadowCaster" 
				"IgnoreProjector" = "True"
			}

			ZWrite On

			CGPROGRAM
				#pragma target 3.0

				#pragma shader_feature _ALPHAPREMULTIPLY_ON
				#pragma multi_compile_shadowcaster

				#pragma vertex vertShadowCaster
				#pragma fragment fragShadowCaster

				#include "UnityStandardShadow.cginc"

			ENDCG
		}
	}
}