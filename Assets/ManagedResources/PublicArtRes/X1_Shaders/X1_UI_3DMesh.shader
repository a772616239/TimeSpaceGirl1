// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "x1_UI_3Dmesh"
{
	Properties
	{
		_FOV("FOV", Range( 0 , 1)) = 0
		[Enum(back,2,front,1,off,0)]_CullMode("CullMode", Float) = 0
		_RefTex("RefTex", 2D) = "white" {}
		[HDR]_refcolor("refcolor", Color) = (1,1,1,1)
		[HDR]_color("color", Color) = (1,1,1,1)
		_MTex("MTex", 2D) = "white" {}
		_MainTex("MainTex", 2D) = "white" {}
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
				float3 ase_normal : NORMAL;
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
				float4 ase_texcoord2 : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform sampler2D _MainTex;
			uniform float _CullMode;
			uniform float _FOV;
			uniform sampler2D _RefTex;
			uniform float4 _refcolor;
			uniform sampler2D _MTex;
			uniform float4 _MTex_ST;
			uniform float4 _color;
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

				float3 rotatedValue69 = RotateAroundAxis( float3( 0,0,0 ), v.vertex.xyz, float3( 0,1,0 ), _Time.y );
				float4 appendResult25 = (float4(rotatedValue69 , 1.0));
				float4 temp_output_3_0 = mul( unity_WorldToCamera, mul( unity_ObjectToWorld, appendResult25 ) );
				float3 appendResult11 = (float3((temp_output_3_0).xyw));
				float4 transform36 = mul(unity_WorldToObject,mul( unity_CameraToWorld, ( temp_output_3_0 + float4( ( ( (temp_output_3_0).z - (mul( unity_WorldToCamera, mul( unity_ObjectToWorld, float4(0,0,0,1) ) )).z ) * -_FOV * appendResult11 ) , 0.0 ) ) ));
				float3 POS71 = rotatedValue69;
				
				float3 ase_worldNormal = UnityObjectToWorldNormal(v.ase_normal);
				o.ase_texcoord1.xyz = ase_worldNormal;
				
				o.ase_texcoord2.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.w = 0;
				o.ase_texcoord2.zw = 0;
				float3 vertexValue = float3(0, 0, 0);
				#if ASE_ABSOLUTE_VERTEX_POS
				vertexValue = v.vertex.xyz;
				#endif
				vertexValue = ( transform36 + float4( POS71 , 0.0 ) ).xyz;
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
				float3 ase_worldNormal = i.ase_texcoord1.xyz;
				float3 normalizedWorldNormal = normalize( ase_worldNormal );
				float3 rotatedValue76 = RotateAroundAxis( float3( 0,0,0 ), normalizedWorldNormal, float3( 0,1,0 ), _Time.y );
				float2 uv_MTex = i.ase_texcoord2.xy * _MTex_ST.xy + _MTex_ST.zw;
				float4 tex2DNode59 = tex2D( _MTex, uv_MTex );
				float4 appendResult65 = (float4(( ( (tex2DNode59).rgb * tex2DNode59.a ) * (_color).rgb ) , tex2DNode59.a));
				
				
				finalColor = ( ( tex2D( _RefTex, ( ( mul( UNITY_MATRIX_V, float4( rotatedValue76 , 0.0 ) ).xyz * 0.5 ) + 0.5 ).xy ) * _refcolor ) + appendResult65 );
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
-1086;580;1061;415;469.521;1527.453;3.187908;True;True
Node;AmplifyShaderEditor.PosVertexDataNode;1;-2057.878,-130.2108;Inherit;False;0;0;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleTimeNode;75;-2050.544,-304.0078;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RotateAboutAxisNode;69;-1777.024,-322.0669;Inherit;False;False;4;0;FLOAT3;0,1,0;False;1;FLOAT;10;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.Vector4Node;24;-976.7856,209.7673;Inherit;False;Constant;_Vector0;Vector 0;0;0;Create;True;0;0;False;0;False;0,0,0,1;0,0,0,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ObjectToWorldMatrixNode;20;-963.1571,-20.41282;Inherit;False;0;1;FLOAT4x4;0
Node;AmplifyShaderEditor.DynamicAppendNode;25;-1315.802,-174.719;Inherit;False;FLOAT4;4;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;1;False;1;FLOAT4;0
Node;AmplifyShaderEditor.ObjectToWorldMatrixNode;15;-1097.186,-454.7746;Inherit;False;0;1;FLOAT4x4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;18;-677.0558,141.8874;Inherit;False;2;2;0;FLOAT4x4;0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;16;-811.0848,-292.4744;Inherit;False;2;2;0;FLOAT4x4;0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.WorldToCameraMatrix;14;-856.5847,-464.0745;Inherit;False;0;1;FLOAT4x4;0
Node;AmplifyShaderEditor.WorldToCameraMatrix;19;-722.5558,-29.71272;Inherit;False;0;1;FLOAT4x4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;17;-459.91,67.42914;Inherit;False;2;2;0;FLOAT4x4;0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;3;-581.5258,-306.2469;Inherit;False;2;2;0;FLOAT4x4;0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleTimeNode;77;-1455.78,-1275.227;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.WorldNormalVector;43;-1369.489,-1016.915;Inherit;False;True;1;0;FLOAT3;0,0,0;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.ComponentMaskNode;27;-301.7058,109.6787;Inherit;False;False;False;True;False;1;0;FLOAT4;0,0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;7;-313.9851,-107.9701;Inherit;False;False;False;True;False;1;0;FLOAT4;0,0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;10;-438.8947,350.2133;Inherit;False;Property;_FOV;FOV;0;0;Create;True;0;0;False;0;False;0;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.ComponentMaskNode;6;-308.785,-205.4701;Inherit;False;True;True;False;True;1;0;FLOAT4;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ViewMatrixNode;41;-638.0622,-1316.898;Inherit;False;0;1;FLOAT4x4;0
Node;AmplifyShaderEditor.RotateAboutAxisNode;76;-990.3693,-1171.922;Inherit;False;False;4;0;FLOAT3;0,1,0;False;1;FLOAT;10;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleSubtractOpNode;8;-78.68528,-2.670004;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.NegateNode;47;-52.52637,197.401;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;11;-5.557663,-197.0971;Inherit;False;FLOAT3;4;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SamplerNode;59;-193.8916,-858.1172;Inherit;True;Property;_MTex;MTex;5;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;42;-479.5188,-1287.112;Inherit;False;2;2;0;FLOAT4x4;0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;44;-492.3362,-1129.737;Float;False;Constant;_Float1;Float 1;-1;0;Create;True;0;0;False;0;False;0.5;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;9;135.8146,-27.37005;Inherit;False;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ComponentMaskNode;63;262.3845,-842.9359;Inherit;False;True;True;True;False;1;0;COLOR;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ColorNode;61;19.70116,-648.249;Inherit;False;Property;_color;color;4;1;[HDR];Create;True;0;0;False;0;False;1,1,1,1;0.9145284,0.2877358,1,0.4117647;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;45;-312.2665,-1250.665;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;46;-133.057,-1222.689;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ComponentMaskNode;67;312.5692,-664.0932;Inherit;False;True;True;True;False;1;0;COLOR;0,0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.CameraToWorldMatrix;22;180.8526,-453.175;Inherit;False;0;1;FLOAT4x4;0
Node;AmplifyShaderEditor.SimpleAddOpNode;12;252.427,-302.0264;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;64;638.6434,-811.1975;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;71;-1383.328,-397.3716;Inherit;False;POS;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.ColorNode;49;84.36146,-1047.072;Inherit;False;Property;_refcolor;refcolor;3;1;[HDR];Create;True;0;0;False;0;False;1,1,1,1;0.454902,0.7686275,1.741176,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;40;66.54621,-1259.123;Inherit;True;Property;_RefTex;RefTex;2;0;Create;True;0;0;False;0;False;-1;None;a0b7e90efcc72a44894a5557f5d00d93;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;23;476.7222,-363.4297;Inherit;False;2;2;0;FLOAT4x4;0,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1;False;1;FLOAT4;0,0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;62;820.6129,-758.9471;Inherit;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;72;1154.605,-95.11746;Inherit;False;71;POS;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.DynamicAppendNode;65;1006.215,-678.6418;Inherit;False;FLOAT4;4;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.WorldToObjectTransfNode;36;1041.025,-366.7841;Inherit;False;1;0;FLOAT4;0,0,0,1;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;48;579.7666,-1146.793;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleAddOpNode;73;1431.579,-317.9562;Inherit;False;2;2;0;FLOAT4;0,0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SimpleAddOpNode;60;1239.854,-1086.499;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;50;702.3689,-1457.771;Inherit;False;Property;_CullMode;CullMode;1;1;[Enum];Create;True;3;back;2;front;1;off;0;0;True;0;False;0;2;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;68;-280.2053,-556.3987;Inherit;True;Property;_MainTex;MainTex;6;0;Create;True;0;0;True;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.PosVertexDataNode;74;1194.798,33.11578;Inherit;False;0;0;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;1851.995,-1084.596;Float;False;True;-1;2;ASEMaterialInspector;100;1;x1_UI_3Dmesh;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;0;True;50;True;True;True;True;True;0;False;-1;False;False;False;True;False;255;False;-1;255;False;-1;255;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;0;0;1;True;False;;False;0
WireConnection;69;1;75;0
WireConnection;69;3;1;0
WireConnection;25;0;69;0
WireConnection;18;0;20;0
WireConnection;18;1;24;0
WireConnection;16;0;15;0
WireConnection;16;1;25;0
WireConnection;17;0;19;0
WireConnection;17;1;18;0
WireConnection;3;0;14;0
WireConnection;3;1;16;0
WireConnection;27;0;17;0
WireConnection;7;0;3;0
WireConnection;6;0;3;0
WireConnection;76;1;77;0
WireConnection;76;3;43;0
WireConnection;8;0;7;0
WireConnection;8;1;27;0
WireConnection;47;0;10;0
WireConnection;11;0;6;0
WireConnection;42;0;41;0
WireConnection;42;1;76;0
WireConnection;9;0;8;0
WireConnection;9;1;47;0
WireConnection;9;2;11;0
WireConnection;63;0;59;0
WireConnection;45;0;42;0
WireConnection;45;1;44;0
WireConnection;46;0;45;0
WireConnection;46;1;44;0
WireConnection;67;0;61;0
WireConnection;12;0;3;0
WireConnection;12;1;9;0
WireConnection;64;0;63;0
WireConnection;64;1;59;4
WireConnection;71;0;69;0
WireConnection;40;1;46;0
WireConnection;23;0;22;0
WireConnection;23;1;12;0
WireConnection;62;0;64;0
WireConnection;62;1;67;0
WireConnection;65;0;62;0
WireConnection;65;3;59;4
WireConnection;36;0;23;0
WireConnection;48;0;40;0
WireConnection;48;1;49;0
WireConnection;73;0;36;0
WireConnection;73;1;72;0
WireConnection;60;0;48;0
WireConnection;60;1;65;0
WireConnection;0;0;60;0
WireConnection;0;1;73;0
ASEEND*/
//CHKSM=F34C6046FD3DC37B6E5C8547947C5884851BC2BC