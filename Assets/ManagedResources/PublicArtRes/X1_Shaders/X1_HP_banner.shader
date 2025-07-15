// Upgrade NOTE: upgraded instancing buffer 'X1_HP_banner' to new syntax.

// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1_HP_banner"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_HP("HP", Range( 0 , 1)) = 0.422592
		_LV_length("LV_length", Range( 1 , 3)) = 1
		_Icon_set("Icon_set", Range( 1 , 5)) = 1
		_LV("LV", Range( 0 , 999)) = 100
		_Color("Color", Color) = (0,0,0,0)

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
			

			struct appdata
			{
				float4 vertex : POSITION;
				float4 color : COLOR;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_texcoord1 : TEXCOORD1;
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

			uniform sampler2D _MainTex;
			UNITY_INSTANCING_BUFFER_START(X1_HP_banner)
				UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
#define _Color_arr X1_HP_banner
				UNITY_DEFINE_INSTANCED_PROP(float, _Icon_set)
#define _Icon_set_arr X1_HP_banner
				UNITY_DEFINE_INSTANCED_PROP(float, _LV)
#define _LV_arr X1_HP_banner
				UNITY_DEFINE_INSTANCED_PROP(float, _HP)
#define _HP_arr X1_HP_banner
				UNITY_DEFINE_INSTANCED_PROP(float, _LV_length)
#define _LV_length_arr X1_HP_banner
			UNITY_INSTANCING_BUFFER_END(X1_HP_banner)

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				o.ase_texcoord1.zw = v.ase_texcoord1.xy;
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
				float4 _Color_Instance = UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color);
				float _Icon_set_Instance = UNITY_ACCESS_INSTANCED_PROP(_Icon_set_arr, _Icon_set);
				float temp_output_32_0_g74 = ( floor( (int)_Icon_set_Instance ) / max( pow( 10.0 , (float)0 ) , 1.0 ) );
				float ICON_mask12 = ( 1.0 - step( i.ase_texcoord1.xy.y , 0.8 ) );
				float2 appendResult87 = (float2(0.0975 , 0.0));
				float2 bit85 = appendResult87;
				float _LV_Instance = UNITY_ACCESS_INSTANCED_PROP(_LV_arr, _LV);
				float temp_output_32_0_g70 = ( floor( (int)_LV_Instance ) / max( pow( 10.0 , (float)2 ) , 1.0 ) );
				float temp_output_43_0_g70 = ( frac( ( temp_output_32_0_g70 / 10.0 ) ) * 10.0 );
				float FONT_mask14 = step( i.ase_texcoord1.zw.y , 0.5 );
				float temp_output_41_0 = step( i.ase_texcoord1.zw.x , 0.1 );
				float F151 = ( FONT_mask14 * temp_output_41_0 );
				float temp_output_32_0_g71 = ( floor( (int)_LV_Instance ) / max( pow( 10.0 , (float)1 ) , 1.0 ) );
				float temp_output_43_0_g71 = ( frac( ( temp_output_32_0_g71 / 10.0 ) ) * 10.0 );
				float temp_output_42_0 = step( i.ase_texcoord1.zw.x , 0.2 );
				float F252 = ( FONT_mask14 * ( ( 1.0 - temp_output_41_0 ) * temp_output_42_0 ) );
				float temp_output_32_0_g73 = ( floor( (int)_LV_Instance ) / max( pow( 10.0 , (float)0 ) , 1.0 ) );
				float F353 = ( FONT_mask14 * ( ( 1.0 - temp_output_42_0 ) * step( i.ase_texcoord1.zw.x , 0.3 ) ) );
				float4 tex2DNode1 = tex2D( _MainTex, ( ( ( ( i.ase_texcoord1.xy + ( ( float2( 0.2,0 ) * ( frac( ( temp_output_32_0_g74 / 10.0 ) ) * 10.0 ) * float2( 1,1 ) ) * ICON_mask12 ) ) + ( ( bit85 * ( temp_output_43_0_g70 - frac( temp_output_43_0_g70 ) ) * float2( 1,1 ) ) * F151 ) ) + ( ( bit85 * ( temp_output_43_0_g71 - frac( temp_output_43_0_g71 ) ) * float2( 1,1 ) ) * F252 ) ) + ( ( bit85 * ( frac( ( temp_output_32_0_g73 / 10.0 ) ) * 10.0 ) * float2( 1,1 ) ) * F353 ) ) );
				float _HP_Instance = UNITY_ACCESS_INSTANCED_PROP(_HP_arr, _HP);
				float HP_mask13 = ( ( 1.0 - step( i.ase_texcoord1.xy.y , 0.15 ) ) * step( i.ase_texcoord1.xy.y , 0.4 ) );
				float _LV_length_Instance = UNITY_ACCESS_INSTANCED_PROP(_LV_length_arr, _LV_length);
				float4 appendResult18 = (float4(tex2DNode1.r , tex2DNode1.g , tex2DNode1.b , ( tex2DNode1.a * ( 1.0 - ( ( 1.0 - step( i.ase_texcoord1.xy.x , _HP_Instance ) ) * HP_mask13 ) ) * ( 1.0 - ( FONT_mask14 * ( 1.0 - step( i.ase_texcoord1.zw.x , (0.0 + (floor( _LV_length_Instance ) - 0.0) * (1.0 - 0.0) / (10.0 - 0.0)) ) ) ) ) )));
				
				
				finalColor = ( _Color_Instance * appendResult18 );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
-1061;511;1061;841;3186.395;178.5377;1;True;True
Node;AmplifyShaderEditor.TexCoordVertexDataNode;39;-938.1296,-628.2114;Inherit;False;1;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TexCoordVertexDataNode;2;-949.8983,-1004.247;Inherit;False;0;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.StepOpNode;41;-594.7759,-602.9489;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;84;-1870.205,481.6376;Inherit;False;Constant;_bit;bit;6;0;Create;True;0;0;False;0;False;0.0975;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.StepOpNode;3;-572.4248,-1272.846;Inherit;True;2;0;FLOAT;0;False;1;FLOAT;0.8;False;1;FLOAT;0
Node;AmplifyShaderEditor.StepOpNode;6;-564.6248,-768.0463;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;44;-439,-558;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;9;-358.4247,-1268.846;Inherit;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.StepOpNode;42;-606.076,-450.8487;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.2;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;87;-1679.205,531.6376;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;14;-409.6553,-800.7341;Inherit;False;FONT_mask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;45;-256,-512;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;46;-435.176,-397.0487;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;12;-135.4245,-1267.846;Inherit;False;ICON_mask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;48;-68.27601,-815.8484;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;85;-1540.605,475.8376;Inherit;False;bit;-1;True;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.StepOpNode;43;-595.3761,-339.0487;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.3;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;27;-2975.915,-8.591797;Inherit;False;InstancedProperty;_Icon_set;Icon_set;3;0;Create;True;0;0;False;0;False;1;1;1;5;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;47;-282.176,-354.0487;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;86;-2272.205,49.63763;Inherit;False;85;bit;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;54;-2430.125,244.6334;Inherit;False;InstancedProperty;_LV;LV;4;0;Create;True;0;0;False;0;False;100;100;0;999;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;51;198.8703,-779.3079;Inherit;False;F1;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;147;-2679.565,-0.5184631;Inherit;False;Bit10_int_A;-1;;74;9b1bc74eefedca1478fc6ded3b040839;0;4;1;INT;0;False;2;INT;0;False;33;FLOAT2;0.2,0;False;34;FLOAT2;1,1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.StepOpNode;4;-565.4247,-1012.646;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.15;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;49;-70.57602,-595.3486;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;30;-2678.833,171.1583;Inherit;False;12;ICON_mask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;76;-1316.547,1195.48;Inherit;False;InstancedProperty;_LV_length;LV_length;2;0;Create;True;0;0;False;0;False;1;0;1;3;0;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;143;-2014.372,-64.21004;Inherit;False;Bit10_int;-1;;70;1ac6be822737a564ba708826c4fe831b;0;4;1;INT;0;False;2;INT;2;False;33;FLOAT2;0,0;False;34;FLOAT2;1,1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;88;-1907.205,148.6376;Inherit;False;85;bit;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;57;-2060.297,100.5864;Inherit;False;51;F1;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.FloorOpNode;78;-1001.397,1208.795;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;50;-76.57601,-353.0487;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;52;197.5701,-551.8087;Inherit;False;F2;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TexCoordVertexDataNode;26;-2647.251,-159.8201;Inherit;False;0;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.OneMinusNode;10;-426.4247,-1016.646;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;29;-2442.795,130.5045;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.StepOpNode;5;-569.4247,-905.6463;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.4;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;53;205.37,-350.3084;Inherit;False;F3;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;67;-1880.555,255.264;Inherit;False;52;F2;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;144;-1658.93,8.467609;Inherit;False;Bit10_int;-1;;71;1ac6be822737a564ba708826c4fe831b;0;4;1;INT;0;False;2;INT;1;False;33;FLOAT2;0,0;False;34;FLOAT2;1,1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;56;-1793.403,-69.8465;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0.08;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;28;-2293.773,-142.5164;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TexCoordVertexDataNode;73;-945.1725,1000.174;Inherit;False;1;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TexCoordVertexDataNode;15;-1065.204,346.7576;Inherit;False;0;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;17;-1127.302,530.6249;Inherit;False;InstancedProperty;_HP;HP;1;0;Create;True;0;0;False;0;False;0.422592;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;89;-1613.205,261.6376;Inherit;False;85;bit;1;0;OBJECT;;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TFHCRemapNode;77;-843.0806,1192.519;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;10;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;11;-262.4245,-999.6462;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;70;-1365.296,343.1383;Inherit;False;53;F3;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;68;-1396.661,43.83116;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0.08;False;1;FLOAT2;0
Node;AmplifyShaderEditor.StepOpNode;75;-628.5408,1081.551;Inherit;True;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;58;-1604.459,-136.3365;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;13;-106.755,-1027.534;Inherit;False;HP_mask;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FunctionNode;146;-1353.937,173.7163;Inherit;False;Bit10_int_A;-1;;73;9b1bc74eefedca1478fc6ded3b040839;0;4;1;INT;0;False;2;INT;0;False;33;FLOAT2;0,0;False;34;FLOAT2;1,1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.StepOpNode;16;-788.1681,389.0094;Inherit;True;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;65;-1229.252,-142.0663;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GetLocalVarNode;74;-615.2245,887.7247;Inherit;True;14;FONT_mask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;20;-809.2856,669.7567;Inherit;True;13;HP_mask;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;71;-1134.402,170.7055;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0.08;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode;80;-360.7362,1174.765;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;22;-543.4443,448.6367;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;23;-376.9833,507.0222;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;79;-377.0113,976.5;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;72;-966.9932,-15.192;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode;81;-214.2572,982.4184;Inherit;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;24;-154.6218,538.0784;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;1;-265.5576,24.74917;Inherit;True;Property;_MainTex;MainTex;0;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;19;53.00426,326.6443;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;82;181.1537,-100.3074;Inherit;False;InstancedProperty;_Color;Color;5;0;Create;True;0;0;False;0;False;0,0,0,0;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;18;215.8495,195.2878;Inherit;False;FLOAT4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;83;506.8165,16.48206;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;733.5745,25.70626;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1_HP_banner;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;0;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;7;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;41;0;39;1
WireConnection;3;0;2;2
WireConnection;6;0;39;2
WireConnection;44;0;41;0
WireConnection;9;0;3;0
WireConnection;42;0;39;1
WireConnection;87;0;84;0
WireConnection;14;0;6;0
WireConnection;45;0;44;0
WireConnection;45;1;42;0
WireConnection;46;0;42;0
WireConnection;12;0;9;0
WireConnection;48;0;14;0
WireConnection;48;1;41;0
WireConnection;85;0;87;0
WireConnection;43;0;39;1
WireConnection;47;0;46;0
WireConnection;47;1;43;0
WireConnection;51;0;48;0
WireConnection;147;1;27;0
WireConnection;4;0;2;2
WireConnection;49;0;14;0
WireConnection;49;1;45;0
WireConnection;143;1;54;0
WireConnection;143;33;86;0
WireConnection;78;0;76;0
WireConnection;50;0;14;0
WireConnection;50;1;47;0
WireConnection;52;0;49;0
WireConnection;10;0;4;0
WireConnection;29;0;147;0
WireConnection;29;1;30;0
WireConnection;5;0;2;2
WireConnection;53;0;50;0
WireConnection;144;1;54;0
WireConnection;144;33;88;0
WireConnection;56;0;143;0
WireConnection;56;1;57;0
WireConnection;28;0;26;0
WireConnection;28;1;29;0
WireConnection;77;0;78;0
WireConnection;11;0;10;0
WireConnection;11;1;5;0
WireConnection;68;0;144;0
WireConnection;68;1;67;0
WireConnection;75;0;73;1
WireConnection;75;1;77;0
WireConnection;58;0;28;0
WireConnection;58;1;56;0
WireConnection;13;0;11;0
WireConnection;146;1;54;0
WireConnection;146;33;89;0
WireConnection;16;0;15;1
WireConnection;16;1;17;0
WireConnection;65;0;58;0
WireConnection;65;1;68;0
WireConnection;71;0;146;0
WireConnection;71;1;70;0
WireConnection;80;0;75;0
WireConnection;22;0;16;0
WireConnection;23;0;22;0
WireConnection;23;1;20;0
WireConnection;79;0;74;0
WireConnection;79;1;80;0
WireConnection;72;0;65;0
WireConnection;72;1;71;0
WireConnection;81;0;79;0
WireConnection;24;0;23;0
WireConnection;1;1;72;0
WireConnection;19;0;1;4
WireConnection;19;1;24;0
WireConnection;19;2;81;0
WireConnection;18;0;1;1
WireConnection;18;1;1;2
WireConnection;18;2;1;3
WireConnection;18;3;19;0
WireConnection;83;0;82;0
WireConnection;83;1;18;0
WireConnection;0;0;83;0
ASEEND*/
//CHKSM=A9C7027ADFB181E44CBAE98CFE9B6DDCECA45615