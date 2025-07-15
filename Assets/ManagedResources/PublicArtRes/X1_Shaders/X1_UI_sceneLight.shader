// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1_UI_sceneLight"
{
	Properties
	{
		[NoScaleOffset]_MainTex("MainTex", 2D) = "white" {}

	}
	
	SubShader
	{
		
		
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
	LOD 100

		CGINCLUDE
		#pragma target 3.0
		ENDCG
		Blend One One
		AlphaToMask Off
		Cull Back
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
			#define ASE_NEEDS_VERT_COLOR
			#define ASE_NEEDS_VERT_POSITION
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

			uniform sampler2D _MainTex;
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
			
			float3 HSVToRGB( float3 c )
			{
				float4 K = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
				float3 p = abs( frac( c.xxx + K.xyz ) * 6.0 - K.www );
				return c.z * lerp( K.xxx, saturate( p - K.xxx ), c.y );
			}
			

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float mulTime73 = _Time.y * (0.4 + (v.color.b - 0.0) * (3.0 - 0.4) / (1.0 - 0.0));
				float2 texCoord54 = v.ase_texcoord.xy * float2( 1,1 ) + float2( 0,0 );
				float3 appendResult60 = (float3(( ( texCoord54.x - 0.5 ) * 2.0 ) , texCoord54.y , 0.0));
				float3 rotatedValue2 = RotateAroundAxis( v.vertex.xyz, ( v.vertex.xyz + ( float3(30,300,0) * appendResult60 ) ), float3( 0,0,1 ), -( ( v.color.r * UNITY_PI ) * sin( mulTime73 ) ) );
				
				o.ase_color = v.color;
				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = 0;
				float3 vertexValue = float3(0, 0, 0);
				#if ASE_ABSOLUTE_VERTEX_POS
				vertexValue = v.vertex.xyz;
				#endif
				vertexValue = rotatedValue2;
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
				float color65 = i.ase_color.g;
				float3 hsvTorgb68 = HSVToRGB( float3(color65,1.0,1.0) );
				float highLight67 = i.ase_color.a;
				float temp_output_33_0 = ( 0.1357962 + 0.5 );
				float2 texCoord10 = i.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float temp_output_27_0 = (0.0 + (atan2( ((float2( -1,0 ) + (texCoord10 - float2( 0,0 )) * (float2( 1,1 ) - float2( -1,0 )) / (float2( 1,1 ) - float2( 0,0 )))).x , ((float2( -1,0 ) + (texCoord10 - float2( 0,0 )) * (float2( 1,1 ) - float2( -1,0 )) / (float2( 1,1 ) - float2( 0,0 )))).y ) - -UNITY_PI) * (1.0 - 0.0) / (UNITY_PI - -UNITY_PI));
				float smoothstepResult29 = smoothstep( temp_output_33_0 , ( temp_output_33_0 + 0.05 ) , temp_output_27_0);
				float temp_output_35_0 = ( -0.1357962 + 0.5 );
				float smoothstepResult31 = smoothstep( ( temp_output_35_0 + -0.05 ) , temp_output_35_0 , temp_output_27_0);
				float clampResult43 = clamp( pow( ( 1.0 - distance( texCoord10 , float2( 0.5,0 ) ) ) , 2.0 ) , 0.0 , 1.0 );
				
				
				finalColor = float4( ( ( hsvTorgb68 * (0.0 + (highLight67 - 0.0) * (10.0 - 0.0) / (1.0 - 0.0)) ) * ( ( 1.0 - smoothstepResult29 ) * smoothstepResult31 * clampResult43 ) ) , 0.0 );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
-1079;680;1044;985;801.274;-749.4839;1.897345;True;False
Node;AmplifyShaderEditor.TextureCoordinatesNode;10;-1272.535,-341.6441;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TFHCRemapNode;23;-1015.365,52.3605;Inherit;True;5;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;2;FLOAT2;1,1;False;3;FLOAT2;-1,0;False;4;FLOAT2;1,1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TFHCRemapNode;21;-985.3845,-212.2601;Inherit;True;5;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;2;FLOAT2;1,1;False;3;FLOAT2;-1,0;False;4;FLOAT2;1,1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.ComponentMaskNode;22;-682.4636,-192.1923;Inherit;True;True;False;True;True;1;0;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;32;-728.7241,369.8282;Inherit;False;Constant;_Float1;Float 1;1;0;Create;True;0;0;False;0;False;0.1357962;0.1357962;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.PiNode;26;-440.2177,178.0805;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;24;-694.355,54.6372;Inherit;True;False;True;True;True;1;0;FLOAT2;0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.VertexColorNode;63;-536.9855,830.8347;Inherit;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TextureCoordinatesNode;54;11.03515,1555.253;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.NegateNode;28;-278.1082,31.09163;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;75;-245.8776,1214.198;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0.4;False;4;FLOAT;3;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;33;-122.7614,235.1226;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;61;259.8128,1514.091;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.NegateNode;34;-260.12,346.0266;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DistanceOpNode;13;-386.0232,-334.3466;Inherit;False;2;0;FLOAT2;0,0;False;1;FLOAT2;0.5,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ATan2OpNode;17;-342.2278,-210.1466;Inherit;True;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;67;-201.5962,1050.821;Inherit;False;highLight;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;65;-207.9309,909.4756;Inherit;False;color;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;27;-52.63099,-108.8935;Inherit;True;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;62;409.8129,1527.091;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;35;-109.8227,380.0652;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;14;-44.38145,-322.3118;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;36;41.44074,232.4828;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0.05;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;73;-25.82233,1240.036;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;69;763.1226,-651.995;Inherit;False;65;color;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;71;855.0409,-456.1414;Inherit;False;67;highLight;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;60;628.6603,1564.842;Inherit;True;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SmoothstepOpNode;29;608.774,-139.0283;Inherit;True;3;0;FLOAT;0;False;1;FLOAT;0.7;False;2;FLOAT;0.75;False;1;FLOAT;0
Node;AmplifyShaderEditor.PiNode;7;-199.1778,803.977;Inherit;False;1;0;FLOAT;0.1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;37;85.23581,329.3087;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;-0.05;False;1;FLOAT;0
Node;AmplifyShaderEditor.SinOpNode;74;175.1777,1188.036;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.Vector3Node;53;523.6271,1240.72;Inherit;False;Constant;_Vector0;Vector 0;5;0;Create;True;0;0;False;0;False;30,300,0;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.PowerNode;40;264.8435,-332.4777;Inherit;False;False;2;0;FLOAT;0;False;1;FLOAT;2;False;1;FLOAT;0
Node;AmplifyShaderEditor.PosVertexDataNode;4;526.9319,1074.07;Inherit;False;0;0;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.OneMinusNode;38;911.7283,-76.27747;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;55;811.2891,1388.661;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.HSVToRGBNode;68;1051.745,-656.9474;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;1;False;2;FLOAT;1;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SmoothstepOpNode;31;654.3624,216.2265;Inherit;True;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;12;289.8309,917.6324;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ClampOpNode;43;564.9635,-342.7603;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;72;1061.183,-456.1477;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;10;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;52;988.6743,1212.416;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.NegateNode;8;496.5284,774.3791;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;39;1243.577,-86.53371;Inherit;True;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;70;1307.198,-658.4048;Inherit;True;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RotateAboutAxisNode;2;1342.655,891.5195;Inherit;False;False;4;0;FLOAT3;0,0,1;False;1;FLOAT;0;False;2;FLOAT3;0,200,0;False;3;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;51;1722.756,-388.9374;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SamplerNode;1;355.0216,1771.229;Inherit;True;Property;_MainTex;MainTex;0;1;[NoScaleOffset];Create;True;0;0;True;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;2324.839,127.7578;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1_UI_sceneLight;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;4;1;False;-1;1;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;0;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;0;0;1;True;False;;False;0
WireConnection;23;0;10;0
WireConnection;21;0;10;0
WireConnection;22;0;21;0
WireConnection;24;0;23;0
WireConnection;28;0;26;0
WireConnection;75;0;63;3
WireConnection;33;0;32;0
WireConnection;61;0;54;1
WireConnection;34;0;32;0
WireConnection;13;0;10;0
WireConnection;17;0;22;0
WireConnection;17;1;24;0
WireConnection;67;0;63;4
WireConnection;65;0;63;2
WireConnection;27;0;17;0
WireConnection;27;1;28;0
WireConnection;27;2;26;0
WireConnection;62;0;61;0
WireConnection;35;0;34;0
WireConnection;14;0;13;0
WireConnection;36;0;33;0
WireConnection;73;0;75;0
WireConnection;60;0;62;0
WireConnection;60;1;54;2
WireConnection;29;0;27;0
WireConnection;29;1;33;0
WireConnection;29;2;36;0
WireConnection;7;0;63;1
WireConnection;37;0;35;0
WireConnection;74;0;73;0
WireConnection;40;0;14;0
WireConnection;38;0;29;0
WireConnection;55;0;53;0
WireConnection;55;1;60;0
WireConnection;68;0;69;0
WireConnection;31;0;27;0
WireConnection;31;1;37;0
WireConnection;31;2;35;0
WireConnection;12;0;7;0
WireConnection;12;1;74;0
WireConnection;43;0;40;0
WireConnection;72;0;71;0
WireConnection;52;0;4;0
WireConnection;52;1;55;0
WireConnection;8;0;12;0
WireConnection;39;0;38;0
WireConnection;39;1;31;0
WireConnection;39;2;43;0
WireConnection;70;0;68;0
WireConnection;70;1;72;0
WireConnection;2;1;8;0
WireConnection;2;2;4;0
WireConnection;2;3;52;0
WireConnection;51;0;70;0
WireConnection;51;1;39;0
WireConnection;0;0;51;0
WireConnection;0;1;2;0
ASEEND*/
//CHKSM=7ECF5258295A9E15DF73D521492EE6EBD980A984