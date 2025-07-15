// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1_backgroud_UV"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_Speed_Tilling("Speed_Tilling", Vector) = (0,0,1,1)
		_Offset_WH("Offset_WH", Vector) = (0,0,1,1)
		_time("time", Float) = 1
		_timeAdd("timeAdd", Float) = 1
		[Toggle(_TIMETEST_ON)] _timeTest("timeTest", Float) = 0
		[Toggle(_ISLOOP_ON)] _ISLoop("ISLoop", Float) = 0

	}
	
	SubShader
	{
		
		
		Tags { "RenderType"="Transparent" "Queue"="Background" }
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
			#pragma multi_compile __ _ISLOOP_ON
			#pragma shader_feature _TIMETEST_ON


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

			uniform sampler2D _MainTex;
			uniform float _time;
			uniform float _timeAdd;
			uniform float4 _Speed_Tilling;
			uniform float4 _Offset_WH;

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

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
				#ifdef _TIMETEST_ON
				float staticSwitch80 = _Time.y;
				#else
				float staticSwitch80 = _time;
				#endif
				float2 appendResult39 = (float2(_Speed_Tilling.x , _Speed_Tilling.y));
				float2 appendResult40 = (float2(_Speed_Tilling.z , _Speed_Tilling.w));
				float2 temp_output_72_0 = ( frac( ( i.ase_texcoord1.xy + ( ( staticSwitch80 + _timeAdd ) * appendResult39 ) ) ) * appendResult40 );
				#ifdef _ISLOOP_ON
				float2 staticSwitch83 = frac( temp_output_72_0 );
				#else
				float2 staticSwitch83 = min( temp_output_72_0 , float2( 1,1 ) );
				#endif
				float2 appendResult44 = (float2(_Offset_WH.x , _Offset_WH.y));
				float2 appendResult46 = (float2(_Offset_WH.z , _Offset_WH.w));
				
				
				finalColor = tex2D( _MainTex, (appendResult44 + (staticSwitch83 - float2( 0,0 )) * (appendResult46 - appendResult44) / (float2( 1,1 ) - float2( 0,0 ))) );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
18;30;1107;766;2002.368;1112.541;1.342378;True;True
Node;AmplifyShaderEditor.RangedFloatNode;79;-2879.16,-368.5413;Inherit;False;Property;_time;time;3;0;Create;True;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;35;-2887.64,-473.0868;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;87;-2656.048,-338.7052;Inherit;False;Property;_timeAdd;timeAdd;4;0;Create;True;0;0;False;0;False;1;1;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.StaticSwitch;80;-2711.16,-440.5413;Inherit;False;Property;_timeTest;timeTest;5;0;Create;True;0;0;False;0;False;0;0;1;True;;Toggle;2;Key0;Key1;Create;False;True;9;1;FLOAT;0;False;0;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Vector4Node;38;-3229.897,-526.3352;Inherit;False;Property;_Speed_Tilling;Speed_Tilling;1;0;Create;True;0;0;False;0;False;0,0,1,1;0.135,0,3,1;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;84;-2466.048,-430.7052;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;39;-2863.465,-260.9308;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TexCoordVertexDataNode;27;-2843.842,-826.7925;Inherit;False;0;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;36;-2320.12,-362.8409;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;74;-2429.495,-845.1129;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;40;-2853.021,-595.4279;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.FractNode;71;-2220.782,-869.1947;Inherit;True;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;72;-1909.891,-844.7399;Inherit;True;2;2;0;FLOAT2;0,0;False;1;FLOAT2;3,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector4Node;42;-1586.89,-366.6631;Inherit;False;Property;_Offset_WH;Offset_WH;2;0;Create;True;0;0;False;0;False;0,0,1,1;0.01,0,0.508,0.53;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.FractNode;82;-1596.278,-590.6436;Inherit;True;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMinOpNode;76;-1626.817,-808.5373;Inherit;True;2;0;FLOAT2;0,0;False;1;FLOAT2;1,1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;46;-1314.171,-285.7844;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;44;-1314.881,-396.0769;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.StaticSwitch;83;-1325.242,-674.576;Inherit;False;Property;_ISLoop;ISLoop;6;0;Create;True;0;0;False;0;False;1;0;1;True;;Toggle;2;Key0;Key1;Create;False;True;9;1;FLOAT2;0,0;False;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT2;0,0;False;6;FLOAT2;0,0;False;7;FLOAT2;0,0;False;8;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TFHCRemapNode;45;-1050.121,-629.5152;Inherit;False;5;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;2;FLOAT2;1,1;False;3;FLOAT2;0,0;False;4;FLOAT2;1,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TexturePropertyNode;4;-1158.885,-974.8444;Inherit;True;Property;_MainTex;MainTex;0;0;Create;True;0;0;False;0;False;None;314b3991243d1df43b9a519344ad38ad;False;white;Auto;Texture2D;-1;0;2;SAMPLER2D;0;SAMPLERSTATE;1
Node;AmplifyShaderEditor.ComponentMaskNode;81;-1525.685,-1080.598;Inherit;True;True;False;True;True;1;0;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;1;-766.7771,-781.9297;Inherit;True;Property;_TextureSample0;Texture Sample 0;0;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector3Node;90;-535.7014,-331.7496;Inherit;False;Constant;_Vector0;Vector 0;8;0;Create;True;0;0;False;0;False;0,0,0;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;-418.6505,-762.0137;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1_backgroud_UV;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;0;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;7;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Background=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;80;1;79;0
WireConnection;80;0;35;0
WireConnection;84;0;80;0
WireConnection;84;1;87;0
WireConnection;39;0;38;1
WireConnection;39;1;38;2
WireConnection;36;0;84;0
WireConnection;36;1;39;0
WireConnection;74;0;27;0
WireConnection;74;1;36;0
WireConnection;40;0;38;3
WireConnection;40;1;38;4
WireConnection;71;0;74;0
WireConnection;72;0;71;0
WireConnection;72;1;40;0
WireConnection;82;0;72;0
WireConnection;76;0;72;0
WireConnection;46;0;42;3
WireConnection;46;1;42;4
WireConnection;44;0;42;1
WireConnection;44;1;42;2
WireConnection;83;1;76;0
WireConnection;83;0;82;0
WireConnection;45;0;83;0
WireConnection;45;3;44;0
WireConnection;45;4;46;0
WireConnection;81;0;72;0
WireConnection;1;0;4;0
WireConnection;1;1;45;0
WireConnection;0;0;1;0
ASEEND*/
//CHKSM=C0B50C5EA5FD501421E72C5138818A94F9455117