// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1/SceneEffect"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		[HDR]_Color("Color", Color) = (0,0,0,0)
		_NoiseTex("NoiseTex", 2D) = "white" {}
		_rotate("rotate", Range( -1 , 1)) = 0
		_NoiseSpeed("NoiseSpeed", Vector) = (0,0,0,0)
		_Noise_Tiling_Offset("Noise_Tiling_Offset", Vector) = (1,1,0,0)
		_Move_Y("Move_Y", Float) = 0
		_Top_Y("Top_Y", Range( 0 , 1)) = 0
		_Bottom_Y("Bottom_Y", Range( 0 , 1)) = 0
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

			#define ASE_ABSOLUTE_VERTEX_POS 1


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

			uniform float SceneScale;
			uniform float _Bottom_Y;
			uniform float _Top_Y;
			uniform float _Move_Y;
			uniform float4 _Color;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
			uniform sampler2D _NoiseTex;
			uniform float _rotate;
			uniform float4 _Noise_Tiling_Offset;
			uniform float2 _NoiseSpeed;
			float4 MyCustomExpression1_g8( float4 vertexPos )
			{
				float3 upCamVec = normalize ( UNITY_MATRIX_V._m10_m11_m12 );
				float3 forwardCamVec = -normalize ( UNITY_MATRIX_V._m20_m21_m22 );
				float3 rightCamVec = normalize( UNITY_MATRIX_V._m00_m01_m02 );
				float4x4 rotationCamMatrix = float4x4( rightCamVec, 0, upCamVec, 0, forwardCamVec, 0, 0, 0, 0, 1 );
				vertexPos= mul(vertexPos, rotationCamMatrix );
				return vertexPos;
			}
			
			float3 RotateAroundAxis( float3 center, float3 original, float3 u, float angle )
			{
				original -= center;
				float C = cos( angle );
				float S = sin( angle );
				float t = 1 - C;
				float m00 = t * u.x * u.x + C;
				float m01 = t * u.x * u.y - S * u.z;
				float m02 = t * u.x * u.z + S * u.y;
				float m10 = t * u.x * u.y + S * u.z;
				float m11 = t * u.y * u.y + C;
				float m12 = t * u.y * u.z - S * u.x;
				float m20 = t * u.x * u.z - S * u.y;
				float m21 = t * u.y * u.z + S * u.x;
				float m22 = t * u.z * u.z + C;
				float3x3 finalMatrix = float3x3( m00, m01, m02, m10, m11, m12, m20, m21, m22 );
				return mul( finalMatrix, original ) + center;
			}
			

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float H_W187 = ( ( _ScreenParams.y / _ScreenParams.x ) * max( SceneScale , 1.0 ) );
				float temp_output_200_0 = ( H_W187 * 0.5 );
				float3 appendResult199 = (float3(v.vertex.xyz.x , (( -temp_output_200_0 * _Bottom_Y ) + (v.vertex.xyz.y - -0.5) * (( temp_output_200_0 - (1.0 + (_Top_Y - 0.0) * (0.0 - 1.0) / (1.0 - 0.0)) ) - ( -temp_output_200_0 * _Bottom_Y )) / (0.5 - -0.5)) , v.vertex.xyz.z));
				float4 appendResult3_g8 = (float4(( appendResult199 + ( float3(0,1,0) * _Move_Y ) ) , 1.0));
				float4 vertexPos1_g8 = appendResult3_g8;
				float4 localMyCustomExpression1_g8 = MyCustomExpression1_g8( vertexPos1_g8 );
				float4 transform159 = mul(unity_WorldToObject,mul( unity_CameraToWorld, float4(0,0,10,1) ));
				
				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = 0;
				float3 vertexValue = float3(0, 0, 0);
				#if ASE_ABSOLUTE_VERTEX_POS
				vertexValue = v.vertex.xyz;
				#endif
				vertexValue = ( localMyCustomExpression1_g8 + transform159 ).xyz;
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
				float2 uv_MainTex = i.ase_texcoord1.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				float4 temp_output_4_0 = ( _Color * tex2D( _MainTex, uv_MainTex ) );
				float2 texCoord22 = i.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float3 rotatedValue26 = RotateAroundAxis( float3( 0.5,0.5,0 ), float3( texCoord22 ,  0.0 ), float3( 0,0,1 ), ( _rotate * UNITY_PI ) );
				float2 appendResult29 = (float2(_Noise_Tiling_Offset.x , _Noise_Tiling_Offset.y));
				float2 appendResult28 = (float2(_Noise_Tiling_Offset.z , _Noise_Tiling_Offset.w));
				float4 appendResult15 = (float4((temp_output_4_0).rgb , ( (temp_output_4_0).a * tex2D( _NoiseTex, ( ( rotatedValue26 * float3( appendResult29 ,  0.0 ) ) + float3( appendResult28 ,  0.0 ) + float3( ( _Time.y * _NoiseSpeed ) ,  0.0 ) ).xy ).r )));
				
				
				finalColor = appendResult15;
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
-1078;5;1061;1120;2291.085;1050.862;2.229856;True;True
Node;AmplifyShaderEditor.ScreenParams;163;-478.825,16.63988;Inherit;False;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;209;-398.487,237.502;Inherit;False;Global;SceneScale;SceneScale;9;0;Create;True;0;0;False;0;False;1;2.220211;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMaxOpNode;211;-165.4979,189.2699;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleDivideOpNode;188;-180.3005,81.2743;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;210;7.996161,98.09271;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;187;225.0994,94.9743;Inherit;False;H_W;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;195;-1907.89,525.2728;Inherit;False;187;H_W;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;205;-1800.169,674.1912;Inherit;False;Property;_Top_Y;Top_Y;7;0;Create;True;0;0;False;0;False;0;0.847;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;24;-2119.91,-328.2737;Inherit;False;Property;_rotate;rotate;3;0;Create;True;0;0;False;0;False;0;0;-1;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;200;-1693.98,541.42;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.PiNode;23;-2094.91,-209.2738;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;204;-1474.962,534.4427;Inherit;False;Property;_Bottom_Y;Bottom_Y;8;0;Create;True;0;0;False;0;False;0;1;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.NegateNode;201;-1365.196,422.5637;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;22;-2106.627,-40.58139;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;25;-1826.911,-269.2738;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;208;-1441.49,680.1617;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;1;False;4;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Vector4Node;27;-1805.599,-18.45659;Inherit;False;Property;_Noise_Tiling_Offset;Noise_Tiling_Offset;5;0;Create;True;0;0;False;0;False;1,1,0,0;1,1,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleSubtractOpNode;206;-1216.77,621.3729;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;32;-1950.794,188.2069;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RotateAboutAxisNode;26;-1674.301,-225.1253;Inherit;False;False;4;0;FLOAT3;0,0,1;False;1;FLOAT;0;False;2;FLOAT3;0.5,0.5,0;False;3;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DynamicAppendNode;29;-1489.599,-71.45684;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector2Node;20;-1943.859,289.0265;Inherit;False;Property;_NoiseSpeed;NoiseSpeed;4;0;Create;True;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;203;-1186.176,414.5518;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.PosVertexDataNode;108;-1278.36,189.0719;Inherit;False;0;0;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;33;-1553.523,227.129;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector3Node;172;-776.3439,476.5181;Inherit;False;Constant;_Vector0;Vector 0;7;0;Create;True;0;0;False;0;False;0,1,0;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.RangedFloatNode;171;-777.0768,645.0573;Inherit;False;Property;_Move_Y;Move_Y;6;0;Create;True;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;28;-1484.828,42.64248;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ColorNode;3;-935.748,-734.2778;Inherit;False;Property;_Color;Color;1;1;[HDR];Create;True;0;0;False;0;False;0,0,0,0;0.490566,0.3216447,0.3216447,1;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;30;-1326.598,-231.4567;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT2;0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SamplerNode;5;-1018.279,-452.192;Inherit;True;Property;_MainTex;MainTex;0;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TFHCRemapNode;198;-1003.351,318.5569;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;-0.5;False;2;FLOAT;0.5;False;3;FLOAT;-1;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.CameraToWorldMatrix;154;-378.4116,482.4134;Inherit;False;0;1;FLOAT4x4;0
Node;AmplifyShaderEditor.DynamicAppendNode;199;-752.2587,208.181;Inherit;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.Vector4Node;158;-394.9835,638.9307;Inherit;False;Constant;_Vector1;Vector 1;6;0;Create;True;0;0;False;0;False;0,0,10,1;0,0,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;4;-575.8864,-604.9798;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleAddOpNode;31;-1162.598,-176.4567;Inherit;False;3;3;0;FLOAT3;0,0,0;False;1;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;174;-570.4653,469.8703;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;175;-378.0129,338.722;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;156;-121.9545,587.0442;Inherit;False;2;2;0;FLOAT4x4;0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SamplerNode;11;-872.7936,-210.1956;Inherit;True;Property;_NoiseTex;NoiseTex;2;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ComponentMaskNode;13;-273.4276,-421.134;Inherit;False;False;False;False;True;1;0;COLOR;0,0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;14;-56.7712,-237.217;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.WorldToObjectTransfNode;159;74.15349,558.0442;Inherit;False;1;0;FLOAT4;0,0,0,1;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.FunctionNode;151;-17.38772,229.4734;Inherit;False;billboard;-1;;8;b211c269cbbb05d4a9f0ad7052ad4440;0;1;2;FLOAT3;0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.ComponentMaskNode;12;-233.017,-592.8005;Inherit;False;True;True;True;False;1;0;COLOR;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.BillboardNode;113;2125.717,-465.7204;Inherit;False;Spherical;True;0;1;FLOAT3;0
Node;AmplifyShaderEditor.DynamicAppendNode;15;133.1908,-289.4071;Inherit;False;FLOAT4;4;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleAddOpNode;160;305.26,254.733;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;689.7167,-238.7792;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1/SceneEffect;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;2;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;0;0;1;True;False;;False;0
WireConnection;211;0;209;0
WireConnection;188;0;163;2
WireConnection;188;1;163;1
WireConnection;210;0;188;0
WireConnection;210;1;211;0
WireConnection;187;0;210;0
WireConnection;200;0;195;0
WireConnection;201;0;200;0
WireConnection;25;0;24;0
WireConnection;25;1;23;0
WireConnection;208;0;205;0
WireConnection;206;0;200;0
WireConnection;206;1;208;0
WireConnection;26;1;25;0
WireConnection;26;3;22;0
WireConnection;29;0;27;1
WireConnection;29;1;27;2
WireConnection;203;0;201;0
WireConnection;203;1;204;0
WireConnection;33;0;32;0
WireConnection;33;1;20;0
WireConnection;28;0;27;3
WireConnection;28;1;27;4
WireConnection;30;0;26;0
WireConnection;30;1;29;0
WireConnection;198;0;108;2
WireConnection;198;3;203;0
WireConnection;198;4;206;0
WireConnection;199;0;108;1
WireConnection;199;1;198;0
WireConnection;199;2;108;3
WireConnection;4;0;3;0
WireConnection;4;1;5;0
WireConnection;31;0;30;0
WireConnection;31;1;28;0
WireConnection;31;2;33;0
WireConnection;174;0;172;0
WireConnection;174;1;171;0
WireConnection;175;0;199;0
WireConnection;175;1;174;0
WireConnection;156;0;154;0
WireConnection;156;1;158;0
WireConnection;11;1;31;0
WireConnection;13;0;4;0
WireConnection;14;0;13;0
WireConnection;14;1;11;1
WireConnection;159;0;156;0
WireConnection;151;2;175;0
WireConnection;12;0;4;0
WireConnection;15;0;12;0
WireConnection;15;3;14;0
WireConnection;160;0;151;0
WireConnection;160;1;159;0
WireConnection;0;0;15;0
WireConnection;0;1;160;0
ASEEND*/
//CHKSM=BB48DF7EBF38E22FCE82FA0A5F57D3B359860C8A