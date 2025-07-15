// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "UI Particles/Mask"
{
	Properties
	{
		[HideInInspector]_MainTex ("Texture", 2D) = "white" {}
		_Stencil ("Stencil ID", Float) = 1	
		_StencilWriteMask ("Stencil Write Mask", Float) = 255
		_StencilReadMask ("Stencil Read Mask", Float) = 255
		_StencilComp("Stencil Comparison", Float) = 8
		_StencilOp("Stencil Operation", Float) = 0		
		_StencilReadMask("Stencil Read Mask", Float) = 255
		_ColorMask("Color Mask", Float) = 15
	}

	

	SubShader
	{
		Tags
		{ 
			"Queue"="Transparent" 
			"IgnoreProjector"="True" 
			"RenderType"="Transparent" 
			"PreviewType"="Plane"
			"CanUseSpriteAtlas"="True"
		}
		
		Stencil
		{
			Ref [_Stencil]
			//WriteMask [_StencilWriteMask]		
			//ReadMask [_StencilReadMask]	
			Comp Always
			Pass Replace
		}
		Cull Off
		Lighting Off
		ZWrite Off
		Blend Zero One

		Pass
		{
			Name "ParticalMask"
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			//#pragma target 2.0

			#include "UnityCG.cginc"
			#include "UnityUI.cginc"

			#pragma multi_compile __ UNITY_UI_ALPHACLIP
			
			struct appdata_t
			{
				float4 vertex   : POSITION;			
			};

			struct v2f
			{
				float4 vertex   : SV_POSITION;
			};
			

			v2f vert(appdata_t IN)
			{
				v2f OUT;
				OUT.vertex = UnityObjectToClipPos(IN.vertex);
				return OUT;
			}

			sampler2D _MainTex;

			fixed4 frag(v2f IN) : SV_Target
			{
				fixed4 color =  0;
				return color;
			}
		ENDCG
		}
	}
}
