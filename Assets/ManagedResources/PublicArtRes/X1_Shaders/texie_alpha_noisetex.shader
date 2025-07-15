// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1/texie/alpha_noise"
{
	Properties
	{
		_stencil("stencil", Float) = 0
		_MainTex("MainTex", 2D) = "white" {}
		_NoiseTex("NoiseTex", 2D) = "white" {}
		_ColorTex("ColorTex", 2D) = "white" {}
		_noiseScale("noiseScale", Range( 0 , 1)) = 0
		_NoiseSpeed("NoiseSpeed", Vector) = (0,0,0,0)
		_Noise_Tiling_Offset("Noise_Tiling_Offset", Vector) = (1,1,0,0)

	}
	
	SubShader
	{
		
		
		Tags { "RenderType"="TransparentCutout" "Queue"="Transparent+10" }
	LOD 100

		CGINCLUDE
		#pragma target 3.0
		ENDCG
		Blend SrcAlpha OneMinusSrcAlpha
		AlphaToMask Off
		Cull Off
		ColorMask RGBA
		ZWrite Off
		ZTest Always
		Offset 0 , 0
		Stencil
		{
			Ref [_stencil]
			CompFront Equal
			PassFront Replace
			FailFront Keep
			ZFailFront Keep
			CompBack Always
			PassBack Keep
			FailBack Keep
			ZFailBack Keep
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
				float4 ase_color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform float _stencil;
			uniform sampler2D _ColorTex;
			uniform sampler2D _MainTex;
			uniform sampler2D _NoiseTex;
			uniform float2 _NoiseSpeed;
			uniform float4 _Noise_Tiling_Offset;
			uniform float _noiseScale;

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				o.ase_texcoord1 = v.ase_texcoord;
				o.ase_color = v.color;
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
				float2 texCoord10 = i.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 appendResult20 = (float2(_Noise_Tiling_Offset.x , _Noise_Tiling_Offset.y));
				float2 appendResult19 = (float2(_Noise_Tiling_Offset.z , _Noise_Tiling_Offset.w));
				float4 texCoord22 = i.ase_texcoord1;
				texCoord22.xy = i.ase_texcoord1.xy * appendResult20 + appendResult19;
				float2 panner23 = ( 1.0 * _Time.y * _NoiseSpeed + texCoord22.xy);
				float temp_output_14_0 = (0.0 + (_noiseScale - 0.0) * (0.1 - 0.0) / (1.0 - 0.0));
				float temp_output_12_0 = (-temp_output_14_0 + (tex2D( _NoiseTex, panner23 ).r - 0.0) * (temp_output_14_0 - -temp_output_14_0) / (1.0 - 0.0));
				float2 appendResult17 = (float2(temp_output_12_0 , temp_output_12_0));
				float4 tex2DNode2 = tex2D( _MainTex, ( texCoord10 + appendResult17 ) );
				float2 appendResult25 = (float2(tex2DNode2.b , 0.5));
				float4 tex2DNode24 = tex2D( _ColorTex, appendResult25 );
				float4 appendResult26 = (float4(tex2DNode24.r , tex2DNode24.g , tex2DNode24.b , tex2DNode2.a));
				
				
				finalColor = ( appendResult26 * i.ase_color );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
-71;70;1262;457;1348.877;700.5299;1.860382;True;True
Node;AmplifyShaderEditor.Vector4Node;18;-2933.592,-138.2509;Inherit;False;Property;_Noise_Tiling_Offset;Noise_Tiling_Offset;6;0;Create;True;0;0;False;0;False;1,1,0,0;0.3,0.3,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;19;-2684.592,-39.25077;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;20;-2678.592,-135.2508;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;13;-1953,205.1546;Inherit;False;Property;_noiseScale;noiseScale;4;0;Create;True;0;0;False;0;False;0;0.162;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.Vector2Node;21;-2455.609,121.3498;Inherit;False;Property;_NoiseSpeed;NoiseSpeed;5;0;Create;True;0;0;False;0;False;0,0;0.1,0.1;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.TextureCoordinatesNode;22;-2505.422,-136.1612;Inherit;False;0;-1;4;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.PannerNode;23;-2119.459,-84.23022;Inherit;True;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TFHCRemapNode;14;-1664,189.1546;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;11;-1793.001,-46.84545;Inherit;True;Property;_NoiseTex;NoiseTex;2;0;Create;True;0;0;False;0;False;-1;None;be9ecca5dcf360447b48ef3a9eac9f1d;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.NegateNode;15;-1494.883,79.15455;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;12;-1362.487,-19.30966;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;10;-1368.901,-161.0453;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;17;-1152.114,-15.39651;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;16;-1034.136,-182.7438;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerNode;2;-901.0546,-263.3622;Inherit;True;Property;_MainTex;MainTex;1;0;Create;True;0;0;False;0;False;-1;None;fadbd74d99a6a7a4b80dfd1cafd1cf3a;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;25;-575.9009,-281.2444;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0.5;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerNode;24;-422.1245,-362.9607;Inherit;True;Property;_ColorTex;ColorTex;3;0;Create;True;0;0;False;0;False;-1;None;7da861754146e3d47befd5af89067211;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;26;-74.44741,-259.4295;Inherit;True;FLOAT4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.VertexColorNode;9;-43.24553,-23.81776;Inherit;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;8;218.7683,-123.9467;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;1;-13.8619,163.2113;Inherit;False;Property;_stencil;stencil;0;0;Create;True;0;0;True;0;False;0;2;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;379.0999,-139.4;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1/texie/alpha_noise;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;2;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;True;255;True;1;255;False;-1;255;False;-1;5;False;-1;3;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;7;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=TransparentCutout=RenderType;Queue=Transparent=Queue=10;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;19;0;18;3
WireConnection;19;1;18;4
WireConnection;20;0;18;1
WireConnection;20;1;18;2
WireConnection;22;0;20;0
WireConnection;22;1;19;0
WireConnection;23;0;22;0
WireConnection;23;2;21;0
WireConnection;14;0;13;0
WireConnection;11;1;23;0
WireConnection;15;0;14;0
WireConnection;12;0;11;1
WireConnection;12;3;15;0
WireConnection;12;4;14;0
WireConnection;17;0;12;0
WireConnection;17;1;12;0
WireConnection;16;0;10;0
WireConnection;16;1;17;0
WireConnection;2;1;16;0
WireConnection;25;0;2;3
WireConnection;24;1;25;0
WireConnection;26;0;24;1
WireConnection;26;1;24;2
WireConnection;26;2;24;3
WireConnection;26;3;2;4
WireConnection;8;0;26;0
WireConnection;8;1;9;0
WireConnection;0;0;8;0
ASEEND*/
//CHKSM=234A8FC916A7F88B91B89BD883AF4C560DB7CB5E