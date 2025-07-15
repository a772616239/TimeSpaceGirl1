
Shader "YXZ/Effect/Alpha Blended" {
Properties {
  [KeywordEnum(AlphaBlend, LightBlend1, LightBlend2, LightBlend3, ColorAdd)] _EffectEnum("Effect select", int) = 0

	_TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
	_MainTex ("Particle Texture", 2D) = "white" {}
  [Toggle(_SOFTBEVEL_ON)] _SoftBevel("淡化斜面", int) = 0
  _BevelRange("淡化斜面限制(x,y,z)", Vector) = (0, 1, 0.5, 0)
//	_Iuminance("Iuminance", range(0,2)) = 1
  [KeywordEnum(OFF,ON)]_CA_SoftParticles("No soft particles", Float) = 0
  _InvFade ("Soft Particles Factor", Range(0.01,5.0)) = 5.0
}

Category {
	Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Opaque" }
	//Blend SrcAlpha OneMinusSrcAlpha
  Blend One SrcAlpha
	ColorMask RGB
	Cull Off Lighting Off ZWrite Off

	SubShader {
		Pass {
		
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
//			#pragma fragmentoption ARB_precision_hint_fastest
#pragma multi_compile _EFFECTENUM_ALPHABLEND _EFFECTENUM_LIGHTBLEND1 _EFFECTENUM_LIGHTBLEND2 _EFFECTENUM_LIGHTBLEND3 _EFFECTENUM_COLORADD 
#pragma multi_compile _CA_SOFTPARTICLES_OFF _CA_SOFTPARTICLES_ON
#pragma multi_compile_local __ _SOFTBEVEL_ON
			#include "UnityCG.cginc"

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
  float _InvFade;
#include "ca_softparticles.cginc"

			sampler2D _MainTex;
			fixed4 _TintColor;
      half4 _BevelRange;
			
			struct appdata_t {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
        float3 normal : NORMAL;
      };

			struct v2f {
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
        UNITY_FOG_COORDS(1)
        CA_SOFTPARTICLES_COORDS(2)
#ifdef _SOFTBEVEL_ON
        fixed3 worldPos : TEXCOORD3;
        fixed3 worldNormal : TEXCOORD4;
#endif
      };
			
			float4 _MainTex_ST;

			v2f vert (appdata_t v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.color = v.color;
				o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
#ifdef _SOFTBEVEL_ON
        o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
        o.worldNormal = UnityObjectToWorldNormal(v.normal);
#endif
				UNITY_TRANSFER_FOG(o,o.vertex);
        CA_TRANSFER_SOFTPARTICLES(o, o.vertex);
        return o;
			}
//			fixed _Iuminance;
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = 2.0 * i.color * _TintColor * tex2D(_MainTex, i.texcoord);
//				col.rgb = lerp(Luminance(col.rgb), col.rgb,_Iuminance);
#ifdef _SOFTBEVEL_ON
      half3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz  - i.worldPos);
      half3 worldNormal = normalize(i.worldNormal);
      half fade = abs(dot(worldViewDir, worldNormal));
      col.a = saturate(col.a + lerp(_BevelRange.x, _BevelRange.y, pow(fade, _BevelRange.z)) - 1);
#endif
        CA_SOFTPARTICLES_FADE(i, col.a);
        UNITY_APPLY_FOG(i.fogCoord, col);
#include "blend.cginc"

				return col;
			}
			ENDCG 
		}
	}	
}
}
