// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1/noiseTEX/normal"
{
	Properties
	{
		[Enum(back,2,front,1,off,0)]_CullMode1("CullMode", Float) = 0
		_MainTex("MainTex", 2D) = "white" {}
		_Main_Tiling_Offset1("Main_Tiling_Offset", Vector) = (1,1,0,0)
		_MainSpeed1("MainSpeed", Vector) = (0,0,0,0)
		_NoiseTex("NoiseTex", 2D) = "white" {}
		_Noise_Tiling_Offset1("Noise_Tiling_Offset", Vector) = (1,1,0,0)
		_NoiseSpeed1("NoiseSpeed", Vector) = (0,0,0,0)
		_noiseScale("noiseScale", Range( 0 , 1)) = 0
		[HDR]_Color("Color", Color) = (0,0,0,0)

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
		Cull [_CullMode1]
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
				float4 ase_texcoord2 : TEXCOORD2;
				float4 ase_color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform float _CullMode1;
			uniform sampler2D _MainTex;
			uniform float2 _MainSpeed1;
			uniform float4 _Main_Tiling_Offset1;
			uniform sampler2D _NoiseTex;
			uniform float2 _NoiseSpeed1;
			uniform float4 _Noise_Tiling_Offset1;
			uniform float _noiseScale;
			uniform float4 _Color;

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				o.ase_texcoord1 = v.ase_texcoord;
				o.ase_texcoord2 = v.ase_texcoord1;
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
				float2 appendResult10 = (float2(_Main_Tiling_Offset1.x , _Main_Tiling_Offset1.y));
				float2 appendResult11 = (float2(_Main_Tiling_Offset1.z , _Main_Tiling_Offset1.w));
				float4 texCoord12 = i.ase_texcoord1;
				texCoord12.xy = i.ase_texcoord1.xy * appendResult10 + appendResult11;
				float2 panner14 = ( 1.0 * _Time.y * _MainSpeed1 + texCoord12.xy);
				float2 appendResult25 = (float2(texCoord12.z , texCoord12.w));
				float2 appendResult16 = (float2(_Noise_Tiling_Offset1.x , _Noise_Tiling_Offset1.y));
				float2 appendResult17 = (float2(_Noise_Tiling_Offset1.z , _Noise_Tiling_Offset1.w));
				float4 texCoord18 = i.ase_texcoord1;
				texCoord18.xy = i.ase_texcoord1.xy * appendResult16 + appendResult17;
				float2 panner20 = ( 1.0 * _Time.y * _NoiseSpeed1 + texCoord18.xy);
				float4 texCoord27 = i.ase_texcoord2;
				texCoord27.xy = i.ase_texcoord2.xy * float2( 1,1 ) + float2( 0,0 );
				float temp_output_7_0 = ( (-0.5 + (tex2D( _NoiseTex, panner20 ).r - 0.0) * (0.5 - -0.5) / (1.0 - 0.0)) * max( _noiseScale , texCoord27.z ) );
				float2 appendResult8 = (float2(temp_output_7_0 , temp_output_7_0));
				
				
				finalColor = ( tex2D( _MainTex, ( panner14 + appendResult25 + appendResult8 ) ) * _Color * i.ase_color );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
7;80;1802;939;2568.055;509.1548;1.6;True;True
Node;AmplifyShaderEditor.Vector4Node;15;-3092.736,67.78239;Inherit;False;Property;_Noise_Tiling_Offset1;Noise_Tiling_Offset;5;0;Create;True;0;0;False;0;False;1,1,0,0;5,1,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;17;-2784.475,215.7366;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;16;-2734.674,47.5936;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector2Node;19;-2320.526,146.1352;Inherit;False;Property;_NoiseSpeed1;NoiseSpeed;6;0;Create;True;0;0;False;0;False;0,0;3,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.TextureCoordinatesNode;18;-2520.28,15.76487;Inherit;False;0;-1;4;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.PannerNode;20;-2087.534,14.40526;Inherit;True;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;6;-1517.93,285.6682;Inherit;False;Property;_noiseScale;noiseScale;7;0;Create;True;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;27;-1473.657,383.6452;Inherit;False;1;-1;4;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector4Node;9;-1932.855,-324.8533;Inherit;False;Property;_Main_Tiling_Offset1;Main_Tiling_Offset;2;0;Create;True;0;0;False;0;False;1,1,0,0;1,1,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;4;-1754.774,49.53376;Inherit;True;Property;_NoiseTex;NoiseTex;4;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TFHCRemapNode;5;-1313.562,64.62182;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;-0.5;False;4;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMaxOpNode;29;-1179.255,303.6451;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;11;-1683.856,-225.8534;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;10;-1677.856,-331.8662;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;7;-1027.5,132;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;12;-1489.273,-361.2013;Inherit;False;0;-1;4;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector2Node;13;-1282.869,-173.0579;Inherit;False;Property;_MainSpeed1;MainSpeed;3;0;Create;True;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.DynamicAppendNode;25;-1003.252,-64.35473;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.PannerNode;14;-1009.669,-293.1368;Inherit;True;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;8;-859.5,118;Inherit;True;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;26;-644.8516,-67.55482;Inherit;False;3;3;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerNode;1;-469.5,-84;Inherit;True;Property;_MainTex;MainTex;1;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ColorNode;22;-386.7887,111.9677;Inherit;False;Property;_Color;Color;8;1;[HDR];Create;True;0;0;False;0;False;0,0,0,0;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.VertexColorNode;23;-366.7887,290.9677;Inherit;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;21;-54.7887,-19.03235;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;24;-848.7169,399.6632;Inherit;False;Property;_CullMode1;CullMode;0;1;[Enum];Create;True;3;back;2;front;1;off;0;0;True;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;171.6267,-54.69424;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1/noiseTEX/normal;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;0;True;24;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;17;0;15;3
WireConnection;17;1;15;4
WireConnection;16;0;15;1
WireConnection;16;1;15;2
WireConnection;18;0;16;0
WireConnection;18;1;17;0
WireConnection;20;0;18;0
WireConnection;20;2;19;0
WireConnection;4;1;20;0
WireConnection;5;0;4;1
WireConnection;29;0;6;0
WireConnection;29;1;27;3
WireConnection;11;0;9;3
WireConnection;11;1;9;4
WireConnection;10;0;9;1
WireConnection;10;1;9;2
WireConnection;7;0;5;0
WireConnection;7;1;29;0
WireConnection;12;0;10;0
WireConnection;12;1;11;0
WireConnection;25;0;12;3
WireConnection;25;1;12;4
WireConnection;14;0;12;0
WireConnection;14;2;13;0
WireConnection;8;0;7;0
WireConnection;8;1;7;0
WireConnection;26;0;14;0
WireConnection;26;1;25;0
WireConnection;26;2;8;0
WireConnection;1;1;26;0
WireConnection;21;0;1;0
WireConnection;21;1;22;0
WireConnection;21;2;23;0
WireConnection;0;0;21;0
ASEEND*/
//CHKSM=45BAE63B707FCD6EE66BB983F1B6308EAE661ABD