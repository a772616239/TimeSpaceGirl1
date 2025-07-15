// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1/mozhate_gangqin"
{
	Properties
	{
		[Enum(back,2,front,1,off,0)]_CullMode("CullMode", Float) = 0
		_MainTex("MainTex", 2D) = "white" {}
		[HDR]_Color1("Color 1", Color) = (1,1,1,1)
		_MainTex_2("MainTex_2", 2D) = "white" {}
		[HDR]_Color2("Color 2", Color) = (1,1,1,1)
		_MoveTex("MoveTex", 2D) = "black" {}
		_AlphaTex("AlphaTex", 2D) = "black" {}
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] _texcoord2( "", 2D ) = "white" {}

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
		Cull [_CullMode]
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


			struct appdata
			{
				float4 vertex : POSITION;
				float4 color : COLOR;
				float4 ase_texcoord1 : TEXCOORD1;
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

			uniform float _CullMode;
			uniform sampler2D _MoveTex;
			uniform float4 _Color1;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
			uniform float4 _Color2;
			uniform sampler2D _MainTex_2;
			uniform sampler2D _AlphaTex;
			uniform float4 _AlphaTex_ST;

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float mulTime45 = _Time.y * 0.5;
				float2 appendResult48 = (float2(( v.ase_texcoord1.x + mulTime45 ) , v.ase_texcoord1.y));
				
				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				o.ase_texcoord1.zw = v.ase_texcoord1.xy;
				float3 vertexValue = float3(0, 0, 0);
				#if ASE_ABSOLUTE_VERTEX_POS
				vertexValue = v.vertex.xyz;
				#endif
				vertexValue = ( float3(0,0,1) * tex2Dlod( _MoveTex, float4( appendResult48, 0, 0.0) ).r );
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
				float mulTime23 = _Time.y * 0.4;
				float2 uv_MainTex = i.ase_texcoord1.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				float4 tex2DNode22 = tex2D( _MainTex, uv_MainTex );
				float clampResult30 = clamp( ( abs( ( frac( ( mulTime23 + tex2DNode22.r ) ) + -0.5 ) ) * 2.0 ) , 0.0 , 1.0 );
				float temp_output_16_0 = step( i.ase_texcoord1.xy.y , 0.5 );
				float4 appendResult43 = (float4(1.0 , 1.0 , 1.0 , temp_output_16_0));
				float mulTime37 = _Time.y * 0.5;
				float2 appendResult38 = (float2(mulTime37 , mulTime37));
				float4 appendResult42 = (float4(_Color2.r , _Color2.g , _Color2.b , ( _Color2.a * tex2D( _MainTex_2, ( i.ase_texcoord1.xy + appendResult38 ) ).r )));
				float4 lerpResult17 = lerp( ( ( _Color1 * clampResult30 * tex2DNode22.a ) * appendResult43 ) , appendResult42 , ( 1.0 - temp_output_16_0 ));
				float2 uv2_AlphaTex = i.ase_texcoord1.zw * _AlphaTex_ST.xy + _AlphaTex_ST.zw;
				float4 appendResult51 = (float4(1.0 , 1.0 , 1.0 , tex2D( _AlphaTex, uv2_AlphaTex ).r));
				
				
				finalColor = ( lerpResult17 * appendResult51 );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
2125;96;1581;878;1640.616;1093.089;1.6;True;True
Node;AmplifyShaderEditor.SimpleTimeNode;23;-1492.887,-1171.811;Inherit;False;1;0;FLOAT;0.4;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;22;-1621.057,-1471.083;Inherit;True;Property;_MainTex;MainTex;1;0;Create;True;0;0;False;0;False;-1;None;3e13f492eb5e87643a5ba093853c6963;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;24;-1252.294,-1322.316;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.FractNode;25;-1105.951,-1322.892;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;37;-1219.931,-559.9513;Inherit;False;1;0;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;26;-969.8977,-1270.814;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode;27;-837.8975,-1275.652;Inherit;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TexCoordVertexDataNode;35;-1037.182,-726.7366;Inherit;False;0;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;38;-983.8314,-579.3314;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;36;-792.2772,-697.246;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TexCoordVertexDataNode;15;-902.407,-297.1705;Inherit;False;0;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;28;-663.4973,-1254.652;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.StepOpNode;16;-526.8347,-315.6364;Inherit;True;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;30;-417.4215,-1282.029;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;45;-516.3398,341.6412;Inherit;False;1;0;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;41;-504.7921,-912.1163;Inherit;False;Property;_Color2;Color 2;4;1;[HDR];Create;True;0;0;False;0;False;1,1,1,1;1.037833,1.693306,3.482202,0.7607843;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;33;-634.3253,-668.041;Inherit;True;Property;_MainTex_2;MainTex_2;3;0;Create;True;0;0;False;0;False;-1;None;d3d0fca3ac4da324f9796bc37288805b;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TexCoordVertexDataNode;46;-523.6254,136.2952;Inherit;False;1;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ColorNode;29;-647.8181,-1549.447;Inherit;False;Property;_Color1;Color 1;2;1;[HDR];Create;True;0;0;False;0;False;1,1,1,1;0,0.6822754,4.164235,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;49;-282.1607,-682.5264;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;31;-169.0805,-1371.535;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.DynamicAppendNode;43;-104.9734,-557.7838;Inherit;False;FLOAT4;4;0;FLOAT;1;False;1;FLOAT;1;False;2;FLOAT;1;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleAddOpNode;47;-275.1448,168.9214;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;48;-123.1448,179.9214;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode;40;-115.648,-325.5366;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;44;68.07558,-944.327;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.DynamicAppendNode;42;-148.8443,-817.2456;Inherit;False;FLOAT4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SamplerNode;50;-112.3769,-231.4775;Inherit;True;Property;_AlphaTex;AlphaTex;6;0;Create;True;0;0;False;0;False;-1;None;e7375d97672767e4e9ac1045cc6d6875;True;1;False;black;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.LerpOp;17;346.6522,-695.7167;Inherit;False;3;0;FLOAT4;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;2;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SamplerNode;18;48.65678,122.5158;Inherit;True;Property;_MoveTex;MoveTex;5;0;Create;True;0;0;False;0;False;-1;None;56ae2a78b1d51e042b4f73601e007d64;True;1;False;black;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector3Node;20;269.0451,-124.0077;Inherit;False;Constant;_Vector0;Vector 0;1;0;Create;True;0;0;False;0;False;0,0,1;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.DynamicAppendNode;51;369.6897,-461.8477;Inherit;False;FLOAT4;4;0;FLOAT;1;False;1;FLOAT;1;False;2;FLOAT;1;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;21;503.3114,-24.41718;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;52;558.1154,-560.304;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;32;-1456.416,-1079.61;Inherit;False;Property;_CullMode;CullMode;0;1;[Enum];Create;True;3;back;2;front;1;off;0;0;True;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;1;749.3915,-559.8322;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1/mozhate_gangqin;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;2;True;32;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;24;0;23;0
WireConnection;24;1;22;1
WireConnection;25;0;24;0
WireConnection;26;0;25;0
WireConnection;27;0;26;0
WireConnection;38;0;37;0
WireConnection;38;1;37;0
WireConnection;36;0;35;0
WireConnection;36;1;38;0
WireConnection;28;0;27;0
WireConnection;16;0;15;2
WireConnection;30;0;28;0
WireConnection;33;1;36;0
WireConnection;49;0;41;4
WireConnection;49;1;33;1
WireConnection;31;0;29;0
WireConnection;31;1;30;0
WireConnection;31;2;22;4
WireConnection;43;3;16;0
WireConnection;47;0;46;1
WireConnection;47;1;45;0
WireConnection;48;0;47;0
WireConnection;48;1;46;2
WireConnection;40;0;16;0
WireConnection;44;0;31;0
WireConnection;44;1;43;0
WireConnection;42;0;41;1
WireConnection;42;1;41;2
WireConnection;42;2;41;3
WireConnection;42;3;49;0
WireConnection;17;0;44;0
WireConnection;17;1;42;0
WireConnection;17;2;40;0
WireConnection;18;1;48;0
WireConnection;51;3;50;1
WireConnection;21;0;20;0
WireConnection;21;1;18;1
WireConnection;52;0;17;0
WireConnection;52;1;51;0
WireConnection;1;0;52;0
WireConnection;1;1;21;0
ASEEND*/
//CHKSM=1C434244548BDF5FD6817286F329804D41D0DC3A