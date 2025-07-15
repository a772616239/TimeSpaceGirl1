
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "YXZ/Effect/Distort_Rim" {
//Properties 
//	{
//		_MainTex ("主贴图", 2D) = "white" {}
//		_Opacity("透明度",range(0,1)) = 1
//		_Outer("边缘光范围",range(0,3)) = 0.2
//		_Color("边缘光颜色", Color) = (1,1,1,1)
//		_texColor("贴图颜色", Color) = (1,1,1,1)
//    
//	}
//	SubShader {
//		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Opaque"}
////		LOD 100
////		Blend SrcAlpha OneMinusSrcAlpha 
//		ColorMask RGB
//	 	Lighting Off 
//		pass
//		{
//		    CGPROGRAM
//		    #pragma vertex vert
//		    #pragma fragment frag
//		    #include "unitycg.cginc"
//		    fixed _Opacity;
//		   
//			sampler2D _MainTex;
//			fixed4 _MainTex_ST;
//			fixed4 _Color;
//			fixed _Outer;
//			fixed4 _texColor;
//
//		    struct v2f
//		    {
//		      fixed4 vertex: POSITION;
//		      fixed3 normal:TEXCOORD0;
//			  fixed2 texcoord : TEXCOORD1;
//			  fixed4 color:COLOR;
//			  fixed3 worldPos : TEXCOORD2;
//		    };
//
//		    v2f vert(appdata_full v)
//		    {
//		        v2f o;
//		        o.vertex = mul(UNITY_MATRIX_MVP,v.vertex);
//		        o.normal = UnityObjectToWorldNormal(v.normal);;
//		        o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
//		        o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
//		        o.color = v.color;
//		        return o;
//		    }
//
//		    fixed4 frag (v2f i): COLOR
//		    {
////		        fixed3 N= mul(IN.normal,(float3x3)unity_WorldToObject);
////		        N = normalize(N);
////		        fixed3 worldPos = mul(unity_ObjectToWorld,IN.vertex).xyz;
//		        fixed3 V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
////		        V = normalize(V);
//
//		        fixed bright = 1.0 - saturate(dot(i.normal,V));
//		        bright = pow(bright,_Outer);
////		        _MainColor.a *=bright;
//                fixed4 mainTex = tex2D(_MainTex, i.texcoord);
//                fixed4 col = mainTex * _texColor * i.color.a;
//                col.a =  mainTex.a;
//                col += bright * _Color;
//                col.a *=_Opacity;
//		        return col ;
//		    }
//		    ENDCG
//		}
//
//	}
//}

Properties {
	_MainTex ("颜色贴图", 2D) = "white" {}
	_Outer("边缘光范围",range(0,3)) = 0.2
	_Color("边缘光颜色", Color) = (1,1,1,1)
	_DissolveSrc ("溶解贴图", 2D) = "white" {}
	_Tile("溶解纹理大小", float) = 1
	_DissColor ("溶解颜色", Color) = (1,1,1,1)
	_Amount ("溶解度", Range (0, 1)) = 0.5
	_Width("宽度",range(0,1)) = 0.5
//	_Alpha("透明度",range(0,1)) = 1
}

SubShader {
	Tags { "RenderType"="Opaque"  }
//	LOD 100
	
//	ZWrite Off
//	Blend SrcAlpha OneMinusSrcAlpha
//	cull off
	Pass {  
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fog
			#pragma multi_compile_particles
			
			#include "UnityCG.cginc"

			struct appdata_t {
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				fixed3 normal:NORMAL;
				fixed4 color : COLOR;
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				fixed4 color : COLOR;
				half2 texcoord : TEXCOORD0;
				half3 worldPos : TEXCOORD1;
				 fixed3 normal:TEXCOORD2;
				UNITY_FOG_COORDS(3)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			
			v2f vert (appdata_t v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.color = v.color;
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			sampler2D _DissolveSrc;
			fixed4 _DissColor;
			fixed _Amount;
			fixed _Width;
			fixed _Tile;
			fixed _Alpha;
			fixed4 _Color;
			fixed _Outer;

			fixed4 frag (v2f i) : SV_Target
			{
				fixed3 V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
				fixed bright = 1.0 - saturate(dot(i.normal,V));
		        bright = pow(bright,_Outer);



				fixed4 col = tex2D(_MainTex, i.texcoord) * i.color + bright * _Color;
//				col.rgb += bright * _Color;
				fixed DissolveSrc = UNITY_SAMPLE_1CHANNEL(_DissolveSrc,i.texcoord/_Tile);
				fixed Amount = saturate(DissolveSrc - ((1 - _Amount) * 4-2) * (i.color.a * 4-2));

				fixed Amount1 = Amount > _Width? 0 : Amount/_Width;
				col.rgb = col.rgb *Amount1* _DissColor.rgb * _DissColor.a*2 +  (1 - Amount1)* col.rgb;


				col.rgb = col.rgb;
				col.a *=  Amount ;
//				col.a *= _Alpha;
				clip(col.a-.5);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
//				return fixed4(Amount1,1);
			}
		ENDCG
	}
}

}
