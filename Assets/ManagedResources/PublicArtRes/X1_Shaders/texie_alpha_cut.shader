// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1/texie/alpha_cut"
{
	Properties
	{
		[Enum(back,2,front,1,off,0)]_CullMode("CullMode", Float) = 0
		_MainTex("MainTex", 2D) = "white" {}
		_Main_Tiling_Offset("Main_Tiling_Offset", Vector) = (1,1,0,0)
		_MainSpeed("MainSpeed", Vector) = (0,0,0,0)
		[HDR]_Color("Color", Color) = (0,0,0,0)
		_NoiseTex("NoiseTex", 2D) = "white" {}
		_NoiseSpeed("NoiseSpeed", Vector) = (0,0,0,0)
		_Noise_Tiling_Offset("Noise_Tiling_Offset", Vector) = (1,1,0,0)
		_MaskTex("MaskTex", 2D) = "gray" {}
		_MaskSpeed("MaskSpeed", Vector) = (0,0,0,0)
		_Mask_Tiling_Offset("Mask_Tiling_Offset", Vector) = (1,1,0,0)
		_step("step", Range( 0 , 1)) = 0

	}
	
	SubShader
	{
		
		
		Tags { "RenderType"="Opaque" "Queue"="Transparent" }
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
				float4 ase_color : COLOR;
				float4 ase_texcoord2 : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform float _CullMode;
			uniform sampler2D _MainTex;
			uniform float2 _MainSpeed;
			uniform float4 _Main_Tiling_Offset;
			uniform float4 _Color;
			uniform sampler2D _NoiseTex;
			uniform float2 _NoiseSpeed;
			uniform float4 _Noise_Tiling_Offset;
			uniform sampler2D _MaskTex;
			uniform float2 _MaskSpeed;
			uniform float4 _Mask_Tiling_Offset;
			uniform float _step;

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				o.ase_texcoord1 = v.ase_texcoord;
				o.ase_color = v.color;
				o.ase_texcoord2 = v.ase_texcoord1;
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
				float2 appendResult126 = (float2(_Main_Tiling_Offset.x , _Main_Tiling_Offset.y));
				float2 appendResult127 = (float2(_Main_Tiling_Offset.z , _Main_Tiling_Offset.w));
				float4 texCoord128 = i.ase_texcoord1;
				texCoord128.xy = i.ase_texcoord1.xy * appendResult126 + appendResult127;
				float2 panner130 = ( 1.0 * _Time.y * _MainSpeed + texCoord128.xy);
				float4 tex2DNode44 = tex2D( _MainTex, panner130 );
				float3 MainTex_RGB52 = (( tex2DNode44 * _Color )).rgb;
				float3 VertexColor_RGB67 = (i.ase_color).rgb;
				float MainTex_A53 = ( tex2DNode44.a * _Color.a );
				float2 appendResult42 = (float2(_Noise_Tiling_Offset.x , _Noise_Tiling_Offset.y));
				float2 appendResult43 = (float2(_Noise_Tiling_Offset.z , _Noise_Tiling_Offset.w));
				float4 texCoord11 = i.ase_texcoord1;
				texCoord11.xy = i.ase_texcoord1.xy * appendResult42 + appendResult43;
				float2 panner14 = ( 1.0 * _Time.y * _NoiseSpeed + texCoord11.xy);
				float NoiseTex_R60 = tex2D( _NoiseTex, panner14 ).r;
				float2 appendResult88 = (float2(_Mask_Tiling_Offset.x , _Mask_Tiling_Offset.y));
				float2 appendResult89 = (float2(_Mask_Tiling_Offset.z , _Mask_Tiling_Offset.w));
				float4 texCoord90 = i.ase_texcoord2;
				texCoord90.xy = i.ase_texcoord2.xy * appendResult88 + appendResult89;
				float2 panner93 = ( 1.0 * _Time.y * _MaskSpeed + texCoord90.xy);
				float MaskTex_R64 = tex2D( _MaskTex, panner93 ).r;
				float Alpha105 = ( MainTex_A53 * ( 1.0 - step( ( NoiseTex_R60 * MaskTex_R64 ) , _step ) ) );
				float4 appendResult39 = (float4(( MainTex_RGB52 * VertexColor_RGB67 ) , Alpha105));
				
				
				finalColor = appendResult39;
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
-36;61;1262;457;2692.373;1254.538;3.94539;True;True
Node;AmplifyShaderEditor.CommentaryNode;63;-1871.083,-378.937;Inherit;False;1948.578;530.9781;NoiseTex;8;3;64;87;88;89;90;91;93;遮罩图;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;58;-1860.161,-1107.978;Inherit;False;1954.908;656.9279;NoiseTex;8;41;43;42;17;11;14;60;19;噪波图;1,1,1,1;0;0
Node;AmplifyShaderEditor.Vector4Node;41;-1803.572,-902.0594;Inherit;False;Property;_Noise_Tiling_Offset;Noise_Tiling_Offset;7;0;Create;True;0;0;False;0;False;1,1,0,0;0.8,1,0,-0.03;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector4Node;87;-1784.289,-225.662;Inherit;False;Property;_Mask_Tiling_Offset;Mask_Tiling_Offset;10;0;Create;True;0;0;False;0;False;1,1,0,0;1,1,0,-0.09;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;88;-1529.289,-232.6752;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;89;-1535.289,-126.6619;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;43;-1554.572,-803.0593;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.CommentaryNode;51;-2092.192,-1675.32;Inherit;False;2184.617;540.2427;MainTex;13;130;129;128;127;126;125;44;54;37;2;55;53;52;主图;1,1,1,1;0;0
Node;AmplifyShaderEditor.DynamicAppendNode;42;-1548.572,-899.0594;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector2Node;91;-1111.671,-188.9127;Inherit;False;Property;_MaskSpeed;MaskSpeed;9;0;Create;True;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.TextureCoordinatesNode;11;-1375.402,-899.9697;Inherit;False;0;-1;4;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TextureCoordinatesNode;90;-1336.807,-281.5098;Inherit;False;1;-1;4;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector2Node;17;-1098.353,-849.4719;Inherit;False;Property;_NoiseSpeed;NoiseSpeed;6;0;Create;True;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.Vector4Node;125;-2040.868,-1517.712;Inherit;False;Property;_Main_Tiling_Offset;Main_Tiling_Offset;2;0;Create;True;0;0;False;0;False;1,1,0,0;1,1,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;126;-1785.869,-1524.725;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;127;-1791.869,-1418.712;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.PannerNode;93;-895.0518,-282.5881;Inherit;True;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.PannerNode;14;-932.349,-934.8243;Inherit;True;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector2Node;129;-1368.25,-1480.963;Inherit;False;Property;_MainSpeed;MainSpeed;3;0;Create;True;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.TextureCoordinatesNode;128;-1597.286,-1554.06;Inherit;False;0;-1;4;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;19;-441.6011,-872.8447;Inherit;True;Property;_NoiseTex;NoiseTex;5;0;Create;True;0;0;False;0;False;-1;None;8d00656ba6c362949a05ac636a543114;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;3;-422.3576,-287.0271;Inherit;True;Property;_MaskTex;MaskTex;8;0;Create;True;0;0;False;0;False;-1;None;62e98d1cf29dad943a38b61eb6a9214a;True;0;False;gray;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.PannerNode;130;-1151.631,-1574.638;Inherit;True;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;60;-115.3869,-852.3915;Inherit;False;NoiseTex_R;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;64;-119.2208,-278.9883;Inherit;False;MaskTex_R;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.CommentaryNode;71;187.7695,-414.9498;Inherit;False;1565.347;687.1545;Alpha;9;20;105;65;62;57;142;143;144;145;Alpha合成;1,1,1,1;0;0
Node;AmplifyShaderEditor.SamplerNode;44;-904.2498,-1566.581;Inherit;True;Property;_MainTex;MainTex;1;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ColorNode;2;-824.6144,-1343.511;Inherit;False;Property;_Color;Color;4;1;[HDR];Create;True;0;0;False;0;False;0,0,0,0;1.101916,2.784123,12.29506,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.GetLocalVarNode;65;226.2407,-184.3557;Inherit;False;64;MaskTex_R;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;62;226.9823,-258.9366;Inherit;False;60;NoiseTex_R;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;55;-418.34,-1351.933;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;145;726.1038,-139.6185;Inherit;False;Property;_step;step;11;0;Create;True;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;142;854.5383,-253.0265;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.CommentaryNode;66;-594.5558,229.7383;Inherit;False;669.5709;420.2796;vertexColor;4;25;67;68;40;顶点色;1,1,1,1;0;0
Node;AmplifyShaderEditor.VertexColorNode;25;-538.7739,343.8351;Inherit;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.StepOpNode;143;1024.129,-254.107;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;53;-189.0694,-1332.391;Inherit;False;MainTex_A;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;54;-545.093,-1531.217;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.OneMinusNode;144;1200.58,-251.512;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;37;-401.2576,-1532.62;Inherit;False;True;True;True;False;1;0;COLOR;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;57;230.2766,-336.7531;Inherit;False;53;MainTex_A;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;40;-337.0046,361.0918;Inherit;False;True;True;True;False;1;0;COLOR;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.CommentaryNode;72;197.5717,-944.8583;Inherit;False;938.3711;429.6;RGB;3;38;56;69;RGB合成;1,1,1,1;0;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;67;-128.7148,364.4197;Inherit;False;VertexColor_RGB;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;20;1384.248,-334.9557;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;52;-167.1375,-1496.821;Inherit;False;MainTex_RGB;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;105;1537.713,-330.5583;Inherit;False;Alpha;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;69;665.6021,-611.0592;Inherit;False;67;VertexColor_RGB;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;56;674.3122,-885.4734;Inherit;False;52;MainTex_RGB;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;38;1002.293,-804.8151;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;106;1586.538,-598.0629;Inherit;False;105;Alpha;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;39;1803.49,-759.01;Inherit;False;FLOAT4;4;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;68;-123.1755,453.9178;Inherit;False;VertexColor_A;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;132;-47.63445,680.0519;Inherit;False;Property;_CullMode;CullMode;0;1;[Enum];Create;True;3;back;2;front;1;off;0;0;True;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;1;2453.93,-726.8081;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1/texie/alpha_cut;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;2;True;132;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Opaque=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;88;0;87;1
WireConnection;88;1;87;2
WireConnection;89;0;87;3
WireConnection;89;1;87;4
WireConnection;43;0;41;3
WireConnection;43;1;41;4
WireConnection;42;0;41;1
WireConnection;42;1;41;2
WireConnection;11;0;42;0
WireConnection;11;1;43;0
WireConnection;90;0;88;0
WireConnection;90;1;89;0
WireConnection;126;0;125;1
WireConnection;126;1;125;2
WireConnection;127;0;125;3
WireConnection;127;1;125;4
WireConnection;93;0;90;0
WireConnection;93;2;91;0
WireConnection;14;0;11;0
WireConnection;14;2;17;0
WireConnection;128;0;126;0
WireConnection;128;1;127;0
WireConnection;19;1;14;0
WireConnection;3;1;93;0
WireConnection;130;0;128;0
WireConnection;130;2;129;0
WireConnection;60;0;19;1
WireConnection;64;0;3;1
WireConnection;44;1;130;0
WireConnection;55;0;44;4
WireConnection;55;1;2;4
WireConnection;142;0;62;0
WireConnection;142;1;65;0
WireConnection;143;0;142;0
WireConnection;143;1;145;0
WireConnection;53;0;55;0
WireConnection;54;0;44;0
WireConnection;54;1;2;0
WireConnection;144;0;143;0
WireConnection;37;0;54;0
WireConnection;40;0;25;0
WireConnection;67;0;40;0
WireConnection;20;0;57;0
WireConnection;20;1;144;0
WireConnection;52;0;37;0
WireConnection;105;0;20;0
WireConnection;38;0;56;0
WireConnection;38;1;69;0
WireConnection;39;0;38;0
WireConnection;39;3;106;0
WireConnection;68;0;25;4
WireConnection;1;0;39;0
ASEEND*/
//CHKSM=4AC34B7489BF32A826086DC2BF283767B35A45EF