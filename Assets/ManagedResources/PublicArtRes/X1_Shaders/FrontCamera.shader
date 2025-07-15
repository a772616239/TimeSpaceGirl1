// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "FrontCamera"
{
	Properties
	{
		_scale("scale", Range( 0.4 , 1)) = 1
		_center("center", Vector) = (0,0,0,0)
		_Color("Color", Color) = (1,0.4481132,0.4481132,0)
		_moveX("moveX", Range( -0.2 , 0.2)) = 0
		_moveY("moveY", Range( -0.2 , 0.2)) = 0
		_TestTEX("TestTEX", 2D) = "black" {}
		[Toggle(_L_R_ON)] _L_R("L_R", Float) = 0

	}
	
	SubShader
	{
		
		
		Tags { "RenderType"="Opaque" "Queue"="Transparent" }
	LOD 100

		CGINCLUDE
		#pragma target 3.0
		ENDCG
		Blend Off
		AlphaToMask Off
		Cull Off
		ColorMask RGBA
		ZWrite Off
		ZTest Always
		Offset 0 , 0
		
		
		GrabPass{ }

		Pass
		{
			Name "Unlit"
			Tags { "LightMode"="ForwardBase" }
			CGPROGRAM

			#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
			#define ASE_DECLARE_SCREENSPACE_TEXTURE(tex) UNITY_DECLARE_SCREENSPACE_TEXTURE(tex);
			#else
			#define ASE_DECLARE_SCREENSPACE_TEXTURE(tex) UNITY_DECLARE_SCREENSPACE_TEXTURE(tex)
			#endif


			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
			//only defining to not throw compilation error over Unity 5.5
			#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
			#endif
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"
			#include "UnityShaderVariables.cginc"
			#pragma multi_compile __ _L_R_ON


			struct appdata
			{
				float4 vertex : POSITION;
				float4 color : COLOR;
				
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

			uniform sampler2D _TestTEX;
			uniform float2 _center;
			ASE_DECLARE_SCREENSPACE_TEXTURE( _GrabTexture )
			uniform float _scale;
			uniform float _moveX;
			uniform float _moveY;
			uniform float4 _Color;
			inline float4 ASE_ComputeGrabScreenPos( float4 pos )
			{
				#if UNITY_UV_STARTS_AT_TOP
				float scale = -1.0;
				#else
				float scale = 1.0;
				#endif
				float4 o = pos;
				o.y = pos.w * 0.5f;
				o.y = ( pos.y - o.y ) * _ProjectionParams.x * scale + o.y;
				return o;
			}
			

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float4 ase_clipPos = UnityObjectToClipPos(v.vertex);
				float4 screenPos = ComputeScreenPos(ase_clipPos);
				o.ase_texcoord1 = screenPos;
				
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
				float W_H28 = ( _ScreenParams.x / _ScreenParams.y );
				float2 appendResult53 = (float2(( 1.0 - ( 0.5 + _center.x ) ) , (0.0 + (( 1.0 - ( 0.5 + _center.y ) ) - 0.0) * (W_H28 - 0.0) / (1.0 - 0.0))));
				float4 screenPos = i.ase_texcoord1;
				float4 ase_grabScreenPos = ASE_ComputeGrabScreenPos( screenPos );
				float4 ase_grabScreenPosNorm = ase_grabScreenPos / ase_grabScreenPos.w;
				#ifdef _L_R_ON
				float staticSwitch43 = _center.x;
				#else
				float staticSwitch43 = ( 1.0 - _center.x );
				#endif
				float temp_output_47_0 = ( ( 1.0 / W_H28 ) + -1.0 );
				float2 appendResult16 = (float2(staticSwitch43 , (( 1.0 - temp_output_47_0 ) + (_center.y - 0.0) * (temp_output_47_0 - ( 1.0 - temp_output_47_0 )) / (1.0 - 0.0))));
				float2 appendResult21 = (float2(_moveX , _moveY));
				float2 appendResult36 = (float2(1.0 , W_H28));
				float4 screenColor2 = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_GrabTexture,( ( ( ase_grabScreenPosNorm + float4( -appendResult16, 0.0 , 0.0 ) ) * _scale ) + float4( appendResult16, 0.0 , 0.0 ) + float4( ( appendResult21 * appendResult36 ), 0.0 , 0.0 ) ).xy);
				
				
				finalColor = ( tex2D( _TestTEX, ( float4( appendResult53, 0.0 , 0.0 ) + ase_grabScreenPosNorm ).xy ) + ( screenColor2 * _Color ) );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
195;13;1072;982;1690.22;1052.578;1.720407;True;True
Node;AmplifyShaderEditor.ScreenParams;25;-477.5604,-961.398;Inherit;False;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleDivideOpNode;26;-268.0238,-933.3414;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;28;-51.84203,-936.1223;Inherit;False;W_H;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;30;-2114.607,-121.4799;Inherit;False;28;W_H;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;46;-1888.663,-128.9741;Inherit;False;2;0;FLOAT;1;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;47;-1724.762,-114.0741;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-1;False;1;FLOAT;0
Node;AmplifyShaderEditor.Vector2Node;10;-1639.963,-367.4569;Inherit;False;Property;_center;center;1;0;Create;True;0;0;False;0;False;0,0;0.19,0.75;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.OneMinusNode;45;-1269.663,-359.0903;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;50;-1477.443,-153.0157;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.StaticSwitch;43;-1026.33,-333.778;Inherit;False;Property;_L_R;L_R;6;0;Create;True;0;0;False;0;False;1;0;1;True;;Toggle;2;Key0;Key1;Create;False;True;9;1;FLOAT;0;False;0;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;49;-1166.643,-225.2157;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;16;-781.7541,-269.0862;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.GrabScreenPosition;1;-814.8264,-457.3969;Inherit;False;0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;20;-578.913,232.4513;Inherit;False;Property;_moveY;moveY;4;0;Create;True;0;0;False;0;False;0;0;-0.2;0.2;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;35;-509.3812,367.0192;Inherit;False;28;W_H;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;19;-574.2126,108.1513;Inherit;False;Property;_moveX;moveX;3;0;Create;True;0;0;False;0;False;0;0;-0.2;0.2;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;54;-1365.361,-550.1457;Inherit;False;2;2;0;FLOAT;0.5;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.NegateNode;15;-576.1215,-316.6041;Inherit;False;1;0;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;4;-588.4626,-67.55275;Inherit;False;Property;_scale;scale;0;0;Create;True;0;0;False;0;False;1;1;0.4;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;5;-398.795,-386.4622;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT2;-0.5,-0.5;False;1;FLOAT4;0
Node;AmplifyShaderEditor.DynamicAppendNode;36;-282.1867,336.4307;Inherit;False;FLOAT2;4;0;FLOAT;1;False;1;FLOAT;1;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;21;-259.5651,155.7234;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode;55;-1213.745,-579.4907;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;57;-1229.641,-473.1151;Inherit;False;28;W_H;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;52;-1338.66,-707.4379;Inherit;False;2;2;0;FLOAT;0.5;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;56;-1021.782,-584.3812;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;51;-1056.66,-712.4379;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;3;-207.7583,-379.5271;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;34;-103.6634,136.6116;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;6;-14.45904,-380.6643;Inherit;False;3;3;0;FLOAT4;0,0,0,0;False;1;FLOAT2;0.5,0.5;False;2;FLOAT2;0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.DynamicAppendNode;53;-869.6597,-696.4379;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;37;-474.428,-555.8696;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.ScreenColorNode;2;201.6478,-373.5116;Inherit;False;Global;_GrabScreen0;Grab Screen 0;0;0;Create;True;0;0;False;0;False;Object;-1;False;False;1;0;FLOAT2;0,0;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ColorNode;12;182.8626,-90.04527;Inherit;False;Property;_Color;Color;2;0;Create;True;0;0;False;0;False;1,0.4481132,0.4481132,0;1,1,1,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;11;525.4861,-285.4032;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SamplerNode;31;10.87395,-630.9927;Inherit;True;Property;_TestTEX;TestTEX;5;0;Create;True;0;0;False;0;False;-1;None;ffa405b712ccf914388e37cd1342f15b;True;0;False;black;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;33;864.3134,-473.4101;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;41;-1591.425,-558.8018;Inherit;False;28;W_H;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;1064.157,-484.6498;Float;False;True;-1;2;ASEMaterialInspector;100;1;FrontCamera;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;0;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;2;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;7;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Opaque=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;26;0;25;1
WireConnection;26;1;25;2
WireConnection;28;0;26;0
WireConnection;46;1;30;0
WireConnection;47;0;46;0
WireConnection;45;0;10;1
WireConnection;50;0;47;0
WireConnection;43;1;45;0
WireConnection;43;0;10;1
WireConnection;49;0;10;2
WireConnection;49;3;50;0
WireConnection;49;4;47;0
WireConnection;16;0;43;0
WireConnection;16;1;49;0
WireConnection;54;1;10;2
WireConnection;15;0;16;0
WireConnection;5;0;1;0
WireConnection;5;1;15;0
WireConnection;36;1;35;0
WireConnection;21;0;19;0
WireConnection;21;1;20;0
WireConnection;55;0;54;0
WireConnection;52;1;10;1
WireConnection;56;0;55;0
WireConnection;56;4;57;0
WireConnection;51;0;52;0
WireConnection;3;0;5;0
WireConnection;3;1;4;0
WireConnection;34;0;21;0
WireConnection;34;1;36;0
WireConnection;6;0;3;0
WireConnection;6;1;16;0
WireConnection;6;2;34;0
WireConnection;53;0;51;0
WireConnection;53;1;56;0
WireConnection;37;0;53;0
WireConnection;37;1;1;0
WireConnection;2;0;6;0
WireConnection;11;0;2;0
WireConnection;11;1;12;0
WireConnection;31;1;37;0
WireConnection;33;0;31;0
WireConnection;33;1;11;0
WireConnection;0;0;33;0
ASEEND*/
//CHKSM=AF2CD9AE63A8FBB1A58F325DE99CA358486C22A7