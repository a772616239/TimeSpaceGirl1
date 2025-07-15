// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1_UI_zhuchangjin_feichuan"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_HDRTex("HDRTex", 2D) = "black" {}
		_MoveSize("MoveSize", Vector) = (0,0,0,0)
		_HighLight("HighLight", Range( 1 , 10)) = 1
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
		Cull Back
		ColorMask RGBA
		ZWrite Off
		ZTest Always
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


			struct appdata
			{
				float4 vertex : POSITION;
				float4 color : COLOR;
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
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform float4 _MoveSize;
			uniform sampler2D _HDRTex;
			uniform float4 _HDRTex_ST;
			uniform float _HighLight;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float mulTime24 = _Time.y * _MoveSize.z;
				float mulTime27 = _Time.y * _MoveSize.w;
				float3 appendResult18 = (float3(sin( mulTime24 ) , sin( mulTime27 ) , 0.0));
				float3 appendResult16 = (float3(_MoveSize.x , _MoveSize.y , 0.0));
				float4 transform6 = mul(unity_WorldToObject,float4( ( float3(1,1,0) * ( appendResult18 + float3( -0.5,-0.5,0 ) ) * appendResult16 ) , 0.0 ));
				
				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = 0;
				float3 vertexValue = float3(0, 0, 0);
				#if ASE_ABSOLUTE_VERTEX_POS
				vertexValue = v.vertex.xyz;
				#endif
				vertexValue = transform6.xyz;
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
				float2 uv_HDRTex = i.ase_texcoord1.xy * _HDRTex_ST.xy + _HDRTex_ST.zw;
				float4 tex2DNode29 = tex2D( _HDRTex, uv_HDRTex );
				float3 appendResult32 = (float3(tex2DNode29.r , tex2DNode29.g , tex2DNode29.b));
				float mulTime38 = _Time.y * 6.0;
				float2 uv_MainTex = i.ase_texcoord1.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				
				
				finalColor = ( float4( ( appendResult32 * _HighLight * ( ( sin( mulTime38 ) + 1.0 ) * 0.5 ) ) , 0.0 ) + tex2D( _MainTex, uv_MainTex ) );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
-186;82;1035;634;1520.46;838.155;1.3;True;True
Node;AmplifyShaderEditor.Vector4Node;19;-1796.546,488.8513;Inherit;False;Property;_MoveSize;MoveSize;2;0;Create;True;0;0;False;0;False;0,0,0,0;0.1,0.06,0.3,0.6;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleTimeNode;24;-1269.1,248.9931;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;38;-925.113,-439.9015;Inherit;False;1;0;FLOAT;6;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;27;-1256.607,384.1143;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SinOpNode;23;-1004.6,241.5329;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SinOpNode;26;-931.0017,391.7878;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SinOpNode;39;-680.6133,-433.3617;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;18;-729.0736,281.6505;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SamplerNode;29;-785.0431,-811.315;Inherit;True;Property;_HDRTex;HDRTex;1;0;Create;True;0;0;False;0;False;-1;None;7133614f6b5e5e14e9b3f8ef4bc82528;True;0;False;black;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;40;-513.949,-486.0151;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;28;-561.5867,281.2512;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;-0.5,-0.5,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DynamicAppendNode;16;-537.7188,578.9873;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;30;-620.3983,-600.9731;Inherit;False;Property;_HighLight;HighLight;3;0;Create;True;0;0;False;0;False;1;10;1;10;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;41;-343.949,-463.0151;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;3;-666.8675,61.7347;Inherit;False;Constant;_Vector0;Vector 0;1;0;Create;True;0;0;False;0;False;1,1,0;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.DynamicAppendNode;32;-374.3983,-768.9731;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;4;-349.7983,132.047;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SamplerNode;2;-577.7268,-272.8642;Inherit;True;Property;_MainTex;MainTex;0;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;31;-160.3983,-690.9731;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;34;-88.63647,-522.4386;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.WorldToObjectTransfNode;6;-28.24772,125.372;Inherit;False;1;0;FLOAT4;0,0,0,1;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;1;113.8419,-147.6838;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1_UI_zhuchangjin_feichuan;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;0;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;7;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;24;0;19;3
WireConnection;27;0;19;4
WireConnection;23;0;24;0
WireConnection;26;0;27;0
WireConnection;39;0;38;0
WireConnection;18;0;23;0
WireConnection;18;1;26;0
WireConnection;40;0;39;0
WireConnection;28;0;18;0
WireConnection;16;0;19;1
WireConnection;16;1;19;2
WireConnection;41;0;40;0
WireConnection;32;0;29;1
WireConnection;32;1;29;2
WireConnection;32;2;29;3
WireConnection;4;0;3;0
WireConnection;4;1;28;0
WireConnection;4;2;16;0
WireConnection;31;0;32;0
WireConnection;31;1;30;0
WireConnection;31;2;41;0
WireConnection;34;0;31;0
WireConnection;34;1;2;0
WireConnection;6;0;4;0
WireConnection;1;0;34;0
WireConnection;1;1;6;0
ASEEND*/
//CHKSM=FDF202722C36723B96327F362F19FADD0685EFCD