//
//  OutlineFill.shader
//  QuickOutline
//
//  Created by Chris Nolet on 2/21/18.
//  Copyright (c) 2018 Chris Nolet. All rights reserved.
//
//  Modified for HDRP: uses user stencil bits 6-7 to avoid
//  collision with HDRP's reserved stencil bits 0-5.
//

Shader "Custom/Outline Fill" {
  Properties {
    [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 0

    _OutlineColor("Outline Color", Color) = (1, 1, 1, 1)
    _OutlineWidth("Outline Width", Range(0, 10)) = 2
  }

  SubShader {
    Tags {
      "Queue" = "Transparent+110"
      "RenderType" = "Transparent"
      "RenderPipeline" = "HDRenderPipeline"
      "DisableBatching" = "True"
    }

    Pass {
      Name "Fill"
      Cull Off
      ZTest [_ZTest]
      ZWrite Off
      Blend SrcAlpha OneMinusSrcAlpha
      ColorMask RGB

      Stencil {
        Ref 64
        ReadMask 64
        Comp NotEqual
      }

      HLSLPROGRAM
      #pragma vertex vert
      #pragma fragment frag

      #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
      #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

      struct appdata {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float3 smoothNormal : TEXCOORD3;
        UNITY_VERTEX_INPUT_INSTANCE_ID
      };

      struct v2f {
        float4 position : SV_POSITION;
        float4 color : COLOR;
        UNITY_VERTEX_OUTPUT_STEREO
      };

      float4 _OutlineColor;
      float _OutlineWidth;

      v2f vert(appdata input) {
        v2f output;

        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        float3 normal = any(input.smoothNormal) ? input.smoothNormal : input.normal;
        float3 viewPosition = TransformWorldToView(TransformObjectToWorld(input.vertex.xyz));
        float3 viewNormal = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, normal));

        output.position = TransformWorldToHClip(
          mul(UNITY_MATRIX_I_V, float4(viewPosition + viewNormal * -viewPosition.z * _OutlineWidth / 1000.0, 1.0)).xyz);
        output.color = _OutlineColor;

        return output;
      }

      float4 frag(v2f input) : SV_Target {
        return input.color;
      }
      ENDHLSL
    }
  }
}
