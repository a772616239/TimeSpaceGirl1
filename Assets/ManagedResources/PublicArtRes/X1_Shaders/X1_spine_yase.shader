// Upgrade NOTE: upgraded instancing buffer 'X1_spineyase' to new syntax.

// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1_spine/yase"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_LerpTex("LerpTex", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_HDR("HDR", Range( 0 , 2)) = 0
		[HDR]_LightColor("LightColor", Color) = (1.756863,3.764706,4,1)
		[HideInInspector] _texcoord( "", 2D ) = "white" {}

	}
	
	SubShader
	{
		
		
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
	LOD 100

		CGINCLUDE
		#pragma target 3.0
		ENDCG
		Blend SrcAlpha OneMinusSrcAlpha
		AlphaToMask Off
		Cull Off
		ColorMask RGBA
		ZWrite Off
		ZTest LEqual
		Offset 0 , 0
		
		
		
		Pass
		{
			Name "Unlit"
			Tags { "LightMode"="ForwardBase" }
			CGPROGRAM

			

			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
			//only defining to not throw compilation error over Unity 5.5
			#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
			#endif
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"
			#include "UnityShaderVariables.cginc"
			#define ASE_NEEDS_VERT_POSITION


			struct appdata
			{
				float4 vertex : POSITION;
				float4 color : COLOR;
				float3 ase_normal : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 vertex : SV_POSITION;
				#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
				float3 worldPos : TEXCOORD0;
				#endif
				float4 ase_texcoord1 : TEXCOORD1;
				float4 ase_color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform sampler2D _MainTex;
			uniform float4 _LightColor;
			uniform sampler2D _LerpTex;
			UNITY_INSTANCING_BUFFER_START(X1_spineyase)
				UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
#define _MainTex_ST_arr X1_spineyase
				UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
#define _Color_arr X1_spineyase
				UNITY_DEFINE_INSTANCED_PROP(float4, _LerpTex_ST)
#define _LerpTex_ST_arr X1_spineyase
				UNITY_DEFINE_INSTANCED_PROP(float, _HDR)
#define _HDR_arr X1_spineyase
			UNITY_INSTANCING_BUFFER_END(X1_spineyase)

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				//Calculate new billboard vertex position and normal;
				float3 upCamVec = normalize ( UNITY_MATRIX_V._m10_m11_m12 );
				float3 forwardCamVec = -normalize ( UNITY_MATRIX_V._m20_m21_m22 );
				float3 rightCamVec = normalize( UNITY_MATRIX_V._m00_m01_m02 );
				float4x4 rotationCamMatrix = float4x4( rightCamVec, 0, upCamVec, 0, forwardCamVec, 0, 0, 0, 0, 1 );
				v.ase_normal = normalize( mul( float4( v.ase_normal , 0 ), rotationCamMatrix )).xyz;
				//This unfortunately must be made to take non-uniform scaling into account;
				//Transform to world coords, apply rotation and transform back to local;
				v.vertex = mul( v.vertex , unity_ObjectToWorld );
				v.vertex = mul( v.vertex , rotationCamMatrix );
				v.vertex = mul( v.vertex , unity_WorldToObject );
				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				o.ase_color = v.color;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = 0;
				float3 vertexValue = float3(0, 0, 0);
				#if ASE_ABSOLUTE_VERTEX_POS
				vertexValue = v.vertex.xyz;
				#endif
				vertexValue = 0;
				#if ASE_ABSOLUTE_VERTEX_POS
				v.vertex.xyz = vertexValue;
				#else
				v.vertex.xyz += vertexValue;
				#endif
				o.vertex = UnityObjectToClipPos(v.vertex);

				#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				#endif
				return o;
			}
			
			fixed4 frag (v2f i ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				fixed4 finalColor;
				#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
				float3 WorldPosition = i.worldPos;
				#endif
				float4 _MainTex_ST_Instance = UNITY_ACCESS_INSTANCED_PROP(_MainTex_ST_arr, _MainTex_ST);
				float2 uv_MainTex = i.ase_texcoord1.xy * _MainTex_ST_Instance.xy + _MainTex_ST_Instance.zw;
				float4 tex2DNode1 = tex2D( _MainTex, uv_MainTex );
				float4 _Color_Instance = UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color);
				float3 appendResult8 = (float3(_Color_Instance.r , _Color_Instance.g , _Color_Instance.b));
				float _HDR_Instance = UNITY_ACCESS_INSTANCED_PROP(_HDR_arr, _HDR);
				float3 appendResult18 = (float3(_LightColor.r , _LightColor.g , _LightColor.b));
				float4 _LerpTex_ST_Instance = UNITY_ACCESS_INSTANCED_PROP(_LerpTex_ST_arr, _LerpTex_ST);
				float2 uv_LerpTex = i.ase_texcoord1.xy * _LerpTex_ST_Instance.xy + _LerpTex_ST_Instance.zw;
				float3 lerpResult19 = lerp( ( appendResult8 + _HDR_Instance ) , ( (0.1 + (abs( ( frac( ( _Time.y + tex2DNode1.r ) ) + -0.5 ) ) - 0.0) * (1.0 - 0.1) / (0.5 - 0.0)) * appendResult18 ) , tex2D( _LerpTex, uv_LerpTex ).r);
				float4 appendResult10 = (float4(lerpResult19 , _Color_Instance.a));
				
				
				finalColor = ( tex2DNode1 * appendResult10 * i.ase_color );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
7;28;1105;761;571.1318;1497.712;1.055323;True;True
Node;AmplifyShaderEditor.SamplerNode;1;-1188.649,-1107.716;Inherit;True;Property;_MainTex;MainTex;0;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleTimeNode;11;-880.8013,-1327.873;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;12;-696.8124,-1305.634;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FractNode;13;-489.8945,-1335.842;Inherit;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;14;-311.1455,-1322.735;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;5;-962.6519,-790.1698;Inherit;False;InstancedProperty;_Color;Color;2;0;Create;True;0;0;False;0;False;1,1,1,1;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.AbsOpNode;15;-65.73135,-1316.589;Inherit;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;17;-239.3492,-1082.841;Inherit;False;Property;_LightColor;LightColor;4;1;[HDR];Create;True;0;0;False;0;False;1.756863,3.764706,4,1;1.756863,3.764706,4,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;9;-750.7542,-608.2578;Inherit;False;InstancedProperty;_HDR;HDR;3;0;Create;True;0;0;False;0;False;0;0;0;2;0;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;8;-654.0781,-785.2195;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DynamicAppendNode;18;23.92527,-1043.089;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.TFHCRemapNode;23;128.006,-1280.541;Inherit;True;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0.5;False;3;FLOAT;0.1;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;20;-192.1163,-743.1181;Inherit;True;Property;_LerpTex;LerpTex;1;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;7;-467.2825,-771.9133;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;22;370.1792,-1105.165;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT3;2,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.LerpOp;19;248.9812,-834.8937;Inherit;False;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.VertexColorNode;6;-457.3407,-577.9197;Inherit;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;10;398.4112,-762.45;Inherit;False;FLOAT4;4;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;3;676.8848,-797.5161;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;2;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.BillboardNode;2;-182.0234,309.0124;Inherit;False;Spherical;False;0;1;FLOAT3;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;755.1766,-475.2537;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1_spine/yase;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;2;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;12;0;11;0
WireConnection;12;1;1;1
WireConnection;13;0;12;0
WireConnection;14;0;13;0
WireConnection;15;0;14;0
WireConnection;8;0;5;1
WireConnection;8;1;5;2
WireConnection;8;2;5;3
WireConnection;18;0;17;1
WireConnection;18;1;17;2
WireConnection;18;2;17;3
WireConnection;23;0;15;0
WireConnection;7;0;8;0
WireConnection;7;1;9;0
WireConnection;22;0;23;0
WireConnection;22;1;18;0
WireConnection;19;0;7;0
WireConnection;19;1;22;0
WireConnection;19;2;20;1
WireConnection;10;0;19;0
WireConnection;10;3;5;4
WireConnection;3;0;1;0
WireConnection;3;1;10;0
WireConnection;3;2;6;0
WireConnection;0;0;3;0
WireConnection;0;1;2;0
ASEEND*/
//CHKSM=C7995304B10E4CAED7EB8A55B41D30C1CCE1D4D6