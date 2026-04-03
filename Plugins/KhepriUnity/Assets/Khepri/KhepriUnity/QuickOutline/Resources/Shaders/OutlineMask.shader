//
//  OutlineMask.shader
//  QuickOutline
//
//  Created by Chris Nolet on 2/21/18.
//  Copyright (c) 2018 Chris Nolet. All rights reserved.
//
//  Modified for HDRP: uses user stencil bits 6-7 to avoid
//  collision with HDRP's reserved stencil bits 0-5.
//

Shader "Custom/Outline Mask" {
  Properties {
    [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 0
  }

  SubShader {
    Tags {
      "Queue" = "Transparent+100"
      "RenderType" = "Transparent"
      "RenderPipeline" = "HDRenderPipeline"
    }

    Pass {
      Name "Mask"
      Cull Off
      ZTest [_ZTest]
      ZWrite Off
      ColorMask 0

      Stencil {
        Ref 64
        WriteMask 64
        Comp Always
        Pass Replace
      }
    }
  }
}
