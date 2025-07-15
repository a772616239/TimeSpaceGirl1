// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "YXZ/Effect/Mix Masking(Without Moving)_alphablend" {
    Properties {
      [KeywordEnum(AlphaBlend, LightBlend1, LightBlend2, LightBlend3, ColorAdd)] _EffectEnum("Effect select", int) = 0
      [Toggle(_SOFTBEVEL_ON)] _SoftBevel("淡化斜面", int) = 0
      _BevelRange("淡化斜面限制(x,y,z)", Vector) = (0, 1, 0.5, 0)

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
    half4 _BevelRange;

		fixed4 _TintColor;
		float _SpeedX;
		float _SpeedY;

		struct appdata_t {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
        float3 normal : NORMAL;
    };

		struct v2f {
			half4 pos : SV_POSITION;
			half4 uv : TEXCOORD0;
			fixed4 color : COLOR;
      CA_SOFTPARTICLES_COORDS(1)
#ifdef _SOFTBEVEL_ON
        fixed3 worldPos : TEXCOORD2;
      fixed3 worldNormal : TEXCOORD3;
#endif
    };

		v2f vert(appdata_t v)
		{
			v2f o;

			o.pos = UnityObjectToClipPos (v.vertex);
			o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.uv.zw = TRANSFORM_TEX(v.texcoord, _NoiseTex);
			o.color = v.color;
      CA_TRANSFER_SOFTPARTICLES(o, o.pos);
#ifdef _SOFTBEVEL_ON
      o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
      o.worldNormal = UnityObjectToWorldNormal(v.normal);
#endif
      return o;
		}

		fixed4 frag( v2f i ) : COLOR
		{
			float4 sp = _Time;
			float2 delta;
			delta.x = sp.x * _SpeedX;
			delta.y = sp.x * _SpeedY; // = float2(sp.x * 10.0, sp.x * 0.0); ////----
			float4 col = tex2D (_MainTex, i.uv.xy + delta) * tex2D (_NoiseTex, i.uv.zw) * _TintColor * _Exposure * i.color;
#ifdef _SOFTBEVEL_ON
      half3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz  - i.worldPos);
      half3 worldNormal = normalize(i.worldNormal);
      half fade = abs(dot(worldViewDir, worldNormal));
      col.a = saturate(col.a + lerp(_BevelRange.x, _BevelRange.y, pow(fade, _BevelRange.z)) - 1);
#else
      col.a = saturate(col.a);
#endif
      CA_SOFTPARTICLES_FADE(i, col.a);


#include "blend.cginc"


      return col;
		}

	ENDCG

	SubShader {
		Tags { "RenderType" = "Opaque" "IgnoreProjector"="True" "Reflection" = "LaserScope" "Queue" = "Transparent"}
		Cull Off
		ZWrite Off
		//Blend SrcAlpha OneMinusSrcAlpha
    Blend One SrcAlpha
		ColorMask RGB
        //Fog { Color (0,0,0,0) }

	Pass {

		CGPROGRAM

		#pragma vertex vert
		#pragma fragment frag
#pragma multi_compile _CA_SOFTPARTICLES_OFF _CA_SOFTPARTICLES_ON
#pragma multi_compile _EFFECTENUM_ALPHABLEND _EFFECTENUM_COLORADD _EFFECTENUM_LIGHTBLEND1 _EFFECTENUM_LIGHTBLEND2 _EFFECTENUM_LIGHTBLEND3
#pragma multi_compile __ _SOFTBEVEL_ON
    //		#pragma fragmentoption ARB_precision_hint_fastest

		ENDCG

		}

	}
	FallBack Off
}
