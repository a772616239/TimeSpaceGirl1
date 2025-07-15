// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1_UI_guaji_water"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_speed("speed", Range( 0 , 1)) = 1
		_MinLight("MinLight", Range( 0 , 1)) = 0
		_cutTime("cutTime", Float) = 0
		_Stnecil("Stnecil", Float) = 0
		_StencilComp("StencilComp", Float) = 0
		_UVtex("UVtex", 2D) = "white" {}
		_cut("cut", Range( 0 , 1)) = 0
		_BackColor("BackColor", Color) = (0,0,0,0)
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
		ZTest LEqual
		Offset 0 , 0
		Stencil
		{
			Ref [_Stnecil]
			Comp [_StencilComp]
			Pass Keep
			Fail Keep
			ZFail Keep
		}
		
		
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
			#define ASE_NEEDS_FRAG_COLOR


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
				float4 ase_color : COLOR;
				float4 ase_texcoord1 : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform float _StencilComp;
			uniform float _Stnecil;
			uniform float4 _BackColor;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
			uniform float _speed;
			uniform float _cutTime;
			uniform float _MinLight;
			uniform sampler2D _UVtex;
			uniform float4 _UVtex_ST;
			uniform float _cut;

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				o.ase_color = v.color;
				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = 0;
				float3 vertexValue = float3(0, 0, 0);
				#if ASE_ABSOLUTE_VERTEX_POS
				vertexValue = v.vertex.xyz;
				#endif
				vertexValue = vertexValue;
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
				float temp_output_31_0 = (0.0 + (i.ase_color.a - 0.0) * (2.0 - 0.0) / (1.0 - 0.0));
				float2 uv_MainTex = i.ase_texcoord1.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				float4 tex2DNode1 = tex2D( _MainTex, uv_MainTex );
				float mulTime26 = _Time.y * _speed;
				float clampResult40 = clamp( (-_cutTime + (abs( (-1.0 + (frac( ( tex2DNode1.r + mulTime26 ) ) - 0.0) * (1.0 - -1.0) / (1.0 - 0.0)) ) - 0.0) * (1.0 - -_cutTime) / (1.0 - 0.0)) , 0.0 , 1.0 );
				float temp_output_37_0 = (_MinLight + (clampResult40 - 0.0) * (1.0 - _MinLight) / (1.0 - 0.0));
				float2 uv_UVtex = i.ase_texcoord1.xy * _UVtex_ST.xy + _UVtex_ST.zw;
				float4 tex2DNode49 = tex2D( _UVtex, uv_UVtex );
				float mulTime50 = _Time.y * 0.3;
				float temp_output_69_0 = (-1.28 + (_cut - 0.0) * (-0.75 - -1.28) / (1.0 - 0.0));
				float2 appendResult52 = (float2(( (0.25 + (tex2DNode49.r - 0.0) * (0.75 - 0.25) / (1.0 - 0.0)) + mulTime50 ) , ( (0.25 + (tex2DNode49.g - 0.0) * (0.75 - 0.25) / (1.0 - 0.0)) + temp_output_69_0 )));
				float4 tex2DNode45 = tex2D( _MainTex, appendResult52 );
				float4 lerpResult67 = lerp( _BackColor , float4( ( (i.ase_color).rgb * (1.0 + (max( temp_output_31_0 , 1.0 ) - 1.0) * (20.0 - 1.0) / (2.0 - 1.0)) * temp_output_37_0 ) , 0.0 ) , tex2DNode45.b);
				float4 tex2DNode61 = tex2D( _UVtex, uv_UVtex );
				float2 appendResult58 = (float2(( (0.25 + (tex2DNode61.r - 0.0) * (0.75 - 0.25) / (1.0 - 0.0)) - mulTime50 ) , ( temp_output_69_0 + 0.02 + (0.25 + (tex2DNode61.g - 0.0) * (0.75 - 0.25) / (1.0 - 0.0)) )));
				float4 appendResult14 = (float4(lerpResult67.rgb , ( min( temp_output_31_0 , 1.0 ) * temp_output_37_0 * tex2DNode1.g * max( tex2DNode45.b , tex2D( _MainTex, appendResult58 ).b ) )));
				
				
				finalColor = appendResult14;
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
95;30;1052;628;1355.005;-389.0981;1.867973;True;False
Node;AmplifyShaderEditor.RangedFloatNode;29;-1851.614,-448.8238;Inherit;False;Property;_speed;speed;1;0;Create;True;0;0;False;0;False;1;0.698;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;26;-1500.73,-486.5703;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;1;-1833.359,-733.0653;Inherit;True;Property;_MainTex;MainTex;0;0;Create;True;0;0;False;0;False;-1;0edd3cd0d88bed6418f766afd928775d;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;25;-1216.296,-690.8917;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FractNode;27;-1001.537,-703.4071;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;61;-566.3033,1233.354;Inherit;True;Property;_TextureSample2;Texture Sample 2;6;0;Create;True;0;0;False;0;False;-1;2bc8ff7c2c8e8f841b86894a28f1fea9;2bc8ff7c2c8e8f841b86894a28f1fea9;True;0;False;white;Auto;False;Instance;49;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;49;-571.4996,688.905;Inherit;True;Property;_UVtex;UVtex;6;0;Create;True;0;0;False;0;False;-1;2bc8ff7c2c8e8f841b86894a28f1fea9;2bc8ff7c2c8e8f841b86894a28f1fea9;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;54;-431.7695,1066.588;Inherit;False;Property;_cut;cut;7;0;Create;True;0;0;False;0;False;0;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;41;-608.7545,-412.2315;Inherit;False;Property;_cutTime;cutTime;3;0;Create;True;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;24;-842.464,-695.1087;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;-1;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.NegateNode;42;-449.2705,-419.2893;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;50;-691.5659,1095.857;Inherit;False;1;0;FLOAT;0.3;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;55;-114.6801,770.0846;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0.25;False;4;FLOAT;0.75;False;1;FLOAT;0
Node;AmplifyShaderEditor.AbsOpNode;28;-574.34,-664.1362;Inherit;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;69;-78.42642,1020.148;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;-1.28;False;4;FLOAT;-0.75;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;63;-105.3203,1479.317;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0.25;False;4;FLOAT;0.75;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;60;-86.38486,1269.883;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0.25;False;4;FLOAT;0.75;False;1;FLOAT;0
Node;AmplifyShaderEditor.VertexColorNode;10;-974.3242,186.8805;Inherit;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TFHCRemapNode;56;-73.46033,564.1524;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0.25;False;4;FLOAT;0.75;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;51;247.2646,674.6321;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;64;265.2811,1313.006;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0.02;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;62;254.6454,1171.33;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;31;-497.5274,300.7747;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;53;251.2689,883.8127;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;39;-279.5034,-625.3206;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;-1;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;52;424.9932,637.4275;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMaxOpNode;33;-233.5274,287.7747;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;58;473.8547,1194.732;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ClampOpNode;40;80.26659,-552.1271;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;38;-100.1667,-275.3564;Inherit;False;Property;_MinLight;MinLight;2;0;Create;True;0;0;False;0;False;0;0.325;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;45;587.3497,383.9074;Inherit;True;Property;_TextureSample0;Texture Sample 0;0;0;Create;True;0;0;False;0;False;-1;None;ce23ecaa423db1848adaef5fae832696;True;0;False;white;Auto;False;Instance;1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TFHCRemapNode;34;-76.17931,212.3355;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;1;False;2;FLOAT;2;False;3;FLOAT;1;False;4;FLOAT;20;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;13;-327.1389,79.37015;Inherit;False;True;True;True;False;1;0;COLOR;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SamplerNode;57;635.2157,887.8212;Inherit;True;Property;_TextureSample1;Texture Sample 1;0;0;Create;True;0;0;False;0;False;-1;None;ce23ecaa423db1848adaef5fae832696;True;0;False;white;Auto;False;Instance;1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TFHCRemapNode;37;455.025,-503.7458;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMinOpNode;32;-222.5274,488.7747;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;68;987.1658,-957.9733;Inherit;False;Property;_BackColor;BackColor;8;0;Create;True;0;0;False;0;False;0,0,0,0;0.6773894,0.4292453,1,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;11;941.9362,-309.3095;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMaxOpNode;66;1003.275,442.2844;Inherit;True;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;35;1219.935,43.69778;Inherit;False;4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.LerpOp;67;1475.362,-642.8415;Inherit;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;44;-1242.818,-163.7123;Inherit;False;Property;_StencilComp;StencilComp;5;0;Create;True;0;0;True;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;14;1633.763,-229.483;Inherit;False;FLOAT4;4;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;1;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;43;-1239.456,-250.5718;Inherit;False;Property;_Stnecil;Stnecil;4;0;Create;True;0;0;True;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;2022.514,-225.55;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1_UI_guaji_water;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;0;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;True;255;True;43;255;False;-1;255;False;-1;5;True;44;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;26;0;29;0
WireConnection;25;0;1;1
WireConnection;25;1;26;0
WireConnection;27;0;25;0
WireConnection;24;0;27;0
WireConnection;42;0;41;0
WireConnection;55;0;49;2
WireConnection;28;0;24;0
WireConnection;69;0;54;0
WireConnection;63;0;61;2
WireConnection;60;0;61;1
WireConnection;56;0;49;1
WireConnection;51;0;56;0
WireConnection;51;1;50;0
WireConnection;64;0;69;0
WireConnection;64;2;63;0
WireConnection;62;0;60;0
WireConnection;62;1;50;0
WireConnection;31;0;10;4
WireConnection;53;0;55;0
WireConnection;53;1;69;0
WireConnection;39;0;28;0
WireConnection;39;3;42;0
WireConnection;52;0;51;0
WireConnection;52;1;53;0
WireConnection;33;0;31;0
WireConnection;58;0;62;0
WireConnection;58;1;64;0
WireConnection;40;0;39;0
WireConnection;45;1;52;0
WireConnection;34;0;33;0
WireConnection;13;0;10;0
WireConnection;57;1;58;0
WireConnection;37;0;40;0
WireConnection;37;3;38;0
WireConnection;32;0;31;0
WireConnection;11;0;13;0
WireConnection;11;1;34;0
WireConnection;11;2;37;0
WireConnection;66;0;45;3
WireConnection;66;1;57;3
WireConnection;35;0;32;0
WireConnection;35;1;37;0
WireConnection;35;2;1;2
WireConnection;35;3;66;0
WireConnection;67;0;68;0
WireConnection;67;1;11;0
WireConnection;67;2;45;3
WireConnection;14;0;67;0
WireConnection;14;3;35;0
WireConnection;0;0;14;0
ASEEND*/
//CHKSM=8ECE3771E15DB6ABF80F909CFB9281A5FB89A73F