// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "YXZ/Effect/Mix Masking(Without Moving)" {
    Properties {
        _MainTex ("MainTex", 2D) = "white" {}
        _NoiseTex ("NoiseTex", 2D) = "white" {}
        _TintColor ("TintColor", Color) = (1,1,1,1)
        _Exposure ("Exposure", Range(1,10)) = 1
        _SpeedX ("SpeedX", Float) = 10.0
        _SpeedY ("SpeedY", Float) = 0

        [KeywordEnum(OFF,ON)]_CA_SoftParticles("No soft particles", Float) = 0
        _InvFade ("Soft Particles Factor", Range(0.01,5.0)) = 5.0
    }

	CGINCLUDE

		#include "UnityCG.cginc"

    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
		float _InvFade;
		#include "ca_softparticles.cginc"


		sampler2D _MainTex;
		sampler2D _NoiseTex;

		half4 _MainTex_ST;
		half4 _NoiseTex_ST;
		float _Exposure;

		fixed4 _TintColor;
		float _SpeedX;
		float _SpeedY;

		struct v2f {
			half4 pos : SV_POSITION;
			half4 uv : TEXCOORD0;
			fixed4 color : COLOR;
      CA_SOFTPARTICLES_COORDS(1)
		};

		v2f vert(appdata_full v)
		{
			v2f o;

			o.pos = UnityObjectToClipPos (v.vertex);
			o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.uv.zw = TRANSFORM_TEX(v.texcoord, _NoiseTex);
			o.color = v.color;
      CA_TRANSFER_SOFTPARTICLES(o, o.pos);
			return o;
		}

		fixed4 frag( v2f i ) : COLOR
		{
			float4 sp = _Time;
			float2 delta;
			delta.x = sp.x * _SpeedX;
			delta.y = sp.x * _SpeedY; // = float2(sp.x * 10.0, sp.x * 0.0); ////----
			float4 col = tex2D (_MainTex, i.uv.xy + delta) * tex2D (_NoiseTex, i.uv.zw) * _TintColor * _Exposure * i.color;
      CA_SOFTPARTICLES_FADE(i, col.a);
      return col;
		}

	ENDCG

	SubShader {
		Tags { "RenderType" = "Opaque" "IgnoreProjector"="True" "Reflection" = "LaserScope" "Queue" = "Transparent"}
		Cull Off
		ZWrite Off
		Blend SrcAlpha One
		ColorMask RGB
        Fog { Color (0,0,0,0) }

	Pass {

		CGPROGRAM

		#pragma vertex vert
		#pragma fragment frag
    #pragma multi_compile _CA_SOFTPARTICLES_OFF _CA_SOFTPARTICLES_ON
//		#pragma fragmentoption ARB_precision_hint_fastest

		ENDCG

		}

	}
	FallBack Off
}
