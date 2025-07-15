
// Unlit alpha-blended shader.
// - no lighting
// - no lightmap support
// - no per-material color

Shader "YXZ/Effect/Dissolve alpha" {
Properties {
	_MainTex ("颜色贴图", 2D) = "white" {}
	_DissolveSrc ("溶解贴图", 2D) = "white" {}
	_Tile("溶解纹理大小", float) = 1
	_DissColor ("溶解颜色", Color) = (1,1,1,1)
	_Amount ("溶解度", Range (0, 1)) = 0.5
	_Width("宽度",range(0,1)) = 0.5
	_Alpha("透明度",range(0,1)) = 1

  [KeywordEnum(OFF,ON)]_CA_SoftParticles("No soft particles", Float) = 0
  _InvFade ("Soft Particles Factor", Range(0.01,5.0)) = 5.0
}

SubShader {
	Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
//	LOD 100
	
	ZWrite Off
	Blend SrcAlpha OneMinusSrcAlpha
	cull off
	Pass {  
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_fog
			#pragma multi_compile_particles
      #pragma multi_compile _CA_SOFTPARTICLES_OFF _CA_SOFTPARTICLES_ON
			
			#include "UnityCG.cginc"

    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
    float _InvFade;
#include "ca_softparticles.cginc"


    //CA_DECLARE_SOFTPARTICLES 

			struct appdata_t {
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				half2 texcoord : TEXCOORD0;
				UNITY_FOG_COORDS(1)
        CA_SOFTPARTICLES_COORDS(2)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			
			v2f vert (appdata_t v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.color = v.color;
				UNITY_TRANSFER_FOG(o,o.vertex);
        CA_TRANSFER_SOFTPARTICLES(o, o.vertex);
				return o;
			}

			sampler2D _DissolveSrc;
			fixed4 _DissColor;
			fixed _Amount;
			fixed _Width;
			fixed _Tile;
			fixed _Alpha;
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.texcoord) * i.color;
				fixed DissolveSrc = UNITY_SAMPLE_1CHANNEL(_DissolveSrc,i.texcoord/_Tile);
				fixed Amount = saturate(DissolveSrc - ((1 - _Amount) * 4-2) * (i.color.a * 4-2));
				col.rgb = col.rgb ;
        CA_SOFTPARTICLES_FADE(i, col.a);

        //CA_SOFTPARTICLES_FADE(i, col.a);
				//col.a *=  Amount/_Width ;
				//col.a *= _Alpha;
        col.a = saturate(col.a * (Amount / _Width) * _Alpha);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
		ENDCG
	}
}

}
