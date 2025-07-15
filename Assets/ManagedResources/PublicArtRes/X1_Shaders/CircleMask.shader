// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/CircleMask" {
	Properties
	{
		[PerRendererData]_MainTex ("Texture", 2D) = "white" {}
		_R ("Radius", Range(0, 6)) = 0.1
		_X ("OffsetX", Range(0, 1)) = 0.5
		_Y ("OffsetY", Range(0, 1)) = 0.5
		_ScaleX ("ScaleX", Range(0, 10)) = 1
		_ScaleY ("ScaleY", Range(0, 10)) = 1
		_Trans ("Trans", Range(0, 10)) = 1
		_CutOff ("Cut Off", Range(0, 1)) = 1
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		LOD 100
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
	

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float4 color    : COLOR;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				fixed4 color    : COLOR;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o = (v2f)0;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			sampler2D _MainTex;
			float _R;
			float _X;
			float _Y;
			float _ScaleX;
			float _ScaleY;
			float _Trans;
			fixed _CutOff;

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv) * i.color;
				float x = (i.uv.x - _X) *_ScaleX;
				float y = (i.uv.y - _Y) *_ScaleY;
				float S = sqrt(x * x + y * y);
				float k = pow(2, S/_R * -4) * _Trans;
				float atten = clamp(0, 1, k);
				float alpha = (1-atten)*_CutOff;
				return fixed4(col.rgb, alpha);
			}
			ENDCG
		}
	}
}