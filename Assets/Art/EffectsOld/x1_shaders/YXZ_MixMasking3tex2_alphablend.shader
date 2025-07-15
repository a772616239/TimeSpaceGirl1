// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "YXZ/Effect/Mix Masking(1tex-Moving-noAlpha 2tex-Moving-Alpha 3mask-noMoving)_alphablend" {
    Properties {
        _MainTex ("MainTex", 2D) = "white" {}
        _MainTex2 ("MainTex2", 2D) = "white" {}
        _NoiseTex ("NoiseTex", 2D) = "white" {}
        _TintColor ("TintColor", Color) = (1,1,1,1)
        _TintColor2 ("TintColor", Color) = (1,1,1,1)
        _Exposure ("Exposure", Range(1,10)) = 1
        _Speed ("Speed xy:MainTex  zw:MainTex2", Vector) = (10,0,10,0)
//        _SpeedY ("SpeedY", Float) = 0
//        _SpeedX2 ("SpeedX2", Float) = 10.0
//        _SpeedY2 ("SpeedY2", Float) = 0
        [KeywordEnum(OFF,ON)]_CA_SoftParticles("No soft particles", Float) = 0
        _InvFade ("Soft Particles Factor", Range(0.01,5.0)) = 5.0
    }

	CGINCLUDE

		#include "UnityCG.cginc"

		UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
		float _InvFade;
		#include "ca_softparticles.cginc"

		sampler2D _MainTex;
		sampler2D _MainTex2;
		sampler2D _NoiseTex;

		half4 _MainTex_ST;
		half4 _MainTex2_ST;
		half4 _NoiseTex_ST;
		float _Exposure;

		fixed4 _TintColor;
		fixed4 _TintColor2;
		fixed4 _Speed;
//		float _SpeedY;
//		float _SpeedX2;
//		float _SpeedY2;


		struct v2f {
			half4 pos : SV_POSITION;
			half4 uv : TEXCOORD0;
			half2 uv1 :TEXCOORD1;
			fixed4 color : COLOR;
      CA_SOFTPARTICLES_COORDS(2)
		};

		v2f vert(appdata_full v)
		{
			v2f o;

			o.pos = UnityObjectToClipPos (v.vertex);
			o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.uv.zw = TRANSFORM_TEX(v.texcoord, _MainTex2);
			o.uv1 = TRANSFORM_TEX(v.texcoord, _NoiseTex);
			o.color = v.color;
      CA_TRANSFER_SOFTPARTICLES(o, o.pos);
			return o;
		}

		fixed4 frag( v2f i ) : COLOR
		{
			float4 sp = _Time;
			float2 delta;
			delta.x = sp.x * _Speed.x;
			delta.y = sp.x * _Speed.y; 
			float2 delta2;
			delta2.x = sp.x * _Speed.z;
			delta2.y = sp.x * _Speed.w;

			fixed4 col = tex2D (_MainTex, i.uv.xy + delta) * _TintColor;
//			col.a = 1;
			fixed4 col1 = tex2D (_MainTex2, i.uv.zw + delta2)* _TintColor2;
			fixed4 Noise = tex2D (_NoiseTex, i.uv1);
      CA_SOFTPARTICLES_FADE(i, Noise.a);
			return (col + col1) * Noise * _Exposure * i.color;
		}

	ENDCG

	SubShader {
		Tags { "RenderType" = "Opaque" "IgnoreProjector"="True" "Reflection" = "LaserScope" "Queue" = "Transparent+110"}
		Cull Off
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		ColorMask RGB
        Fog { Color (0,0,0,0) }

	Pass {

		CGPROGRAM

		#pragma vertex vert
		#pragma fragment frag
		#pragma fragmentoption ARB_precision_hint_fastest
    #pragma multi_compile _CA_SOFTPARTICLES_OFF _CA_SOFTPARTICLES_ON

		ENDCG

		}

	}
	FallBack Off
}
