
Shader "YXZ/Effect/Additive" {
Properties {
	_TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
	_MainTex ("Particle Texture", 2D) = "white" {}
//	_Iuminance("Iuminance", range(0,2)) = 1
  [KeywordEnum(OFF,ON)]_CA_SoftParticles("soft particles", Float) = 0
  _InvFade ("Soft Particles Factor", Range(0.01,5.0)) = 5.0
}

Category {
	Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Opaque" }
	Blend SrcAlpha One
	ColorMask RGB
	Cull Off Lighting Off ZWrite Off
	
	SubShader {
		Pass {
		
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
      #pragma multi_compile _CA_SOFTPARTICLES_OFF _CA_SOFTPARTICLES_ON
      //			#pragma fragmentoption ARB_precision_hint_fastest

			#include "UnityCG.cginc"
			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
			float _InvFade;
			#include "ca_softparticles.cginc"

			sampler2D _MainTex;
			fixed4 _TintColor;
			
			struct appdata_t {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				float2 texcoord : TEXCOORD0;
        CA_SOFTPARTICLES_COORDS(1)
      };

			
			float4 _MainTex_ST;

			v2f vert (appdata_t v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.color = v.color;
				o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
        CA_TRANSFER_SOFTPARTICLES(o, o.vertex);
        return o;
			}

//			fixed _Iuminance;
			
			fixed4 frag (v2f i) : SV_Target
			{				
        CA_SOFTPARTICLES_FADE(i, i.color.a);
        fixed4 col = 2.0f * i.color * _TintColor * tex2D(_MainTex, i.texcoord);
        col.a = saturate(col.a);
        return col;
			}


			ENDCG 
		}
	}	
}
}
