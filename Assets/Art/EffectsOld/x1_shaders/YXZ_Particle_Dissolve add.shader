
// Unlit alpha-blended shader.
// - no lighting
// - no lightmap support
// - no per-material color

Shader "YXZ/Effect/Dissolve add" {
Properties {
	_MainTex ("颜色贴图", 2D) = "white" {}
	_DissolveSrc ("溶解贴图", 2D) = "white" {}
	_Tile("溶解纹理大小", float) = 1
	_DissColor ("溶解颜色", Color) = (1,1,1,1)
	_Amount ("溶解度", Range (0, 1)) = 0
	_Width("宽度",range(0,1)) = 0
}

SubShader {
	Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
//	LOD 100
	
	ZWrite Off
	Blend SrcAlpha One
	cull off
	Pass {  
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_fog
			#pragma multi_compile_particles
			#include "UnityCG.cginc"

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
				return o;
			}

			sampler2D _DissolveSrc;
			fixed4 _DissColor;
			fixed _Amount;
			fixed _Width;
			fixed _Tile;
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.texcoord) * i.color;
				fixed DissolveSrc = UNITY_SAMPLE_1CHANNEL(_DissolveSrc,i.texcoord/_Tile);
				fixed Amount = saturate(DissolveSrc - ((1 - _Amount) * 4-2) * (i.color.a * 4-2) );
				fixed4 Amount1 = Amount > _Width? fixed4(0,0,0,0) : (1 - Amount/_Width) * _DissColor;

				col = col - Amount1;
//
//				Amount = Amount > 0 ? 1 : 0;
//				col.a *= Amount1;
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
		ENDCG
	}
}

}
