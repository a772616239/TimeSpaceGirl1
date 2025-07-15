// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "X1/UI/Hexinka"
{
	Properties
	{
		_NoiseTex("NoiseTex", 2D) = "white" {}
		_MainTex("MainTex", 2D) = "white" {}
		_Stnecil("Stnecil", Float) = 0
		_StencilComp("StencilComp", Float) = 0
		_Vector2("Vector 2", Vector) = (0,0,0,0)
		_Gradual("Gradual", 2D) = "white" {}
		_UV("UV", Vector) = (1,1,0,0)
		_POW("POW", Range( 0 , 1)) = 1
		//[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0

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
			#include "UnityUI.cginc"

			#pragma multi_compile __ UNITY_UI_CLIP_RECT
            #pragma multi_compile __ UNITY_UI_ALPHACLIP


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
				
				float4 worldPos : TEXCOORD0;
				
				float4 ase_texcoord1 : TEXCOORD1;
				//--------------
				//float4 worldPosition : TEXCOORD1;
                half4  mask : TEXCOORD2;
				//--------------
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform float _Stnecil;
			uniform float _StencilComp;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
			uniform sampler2D _Gradual;
			uniform sampler2D _NoiseTex;
			uniform float2 _UV;
			uniform float4 _Vector2;
			uniform float _POW;
			//--------------
			float4 _ClipRect;
            //float4 _MainTex_ST;
            float _MaskSoftnessX;
            float _MaskSoftnessY;
			//--------------
			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				float4 vPosition = UnityObjectToClipPos(v.vertex);
                o.worldPos = v.vertex;
                o.vertex = vPosition;

                float2 pixelSize = vPosition.w;
                pixelSize /= float2(1, 1) * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy));
				float4 clampedRect = clamp(_ClipRect, -2e10, 2e10);
                float2 maskUV = (v.vertex.xy - clampedRect.xy) / (clampedRect.zw - clampedRect.xy);

				o.ase_texcoord1.xy = v.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.zw = float2( maskUV.x, maskUV.y);
				o.mask = half4(v.vertex.xy * 2 - clampedRect.xy - clampedRect.zw, 0.25 / (0.25 * half2(_MaskSoftnessX, _MaskSoftnessY) + abs(pixelSize.xy)));
				float3 vertexValue = float3(0, 0, 0);
				
				
				
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
				float2 uv_MainTex = i.ase_texcoord1.xy * _MainTex_ST.xy;
				float2 texCoord58 = i.ase_texcoord1.xy * _UV + float2( 0,0 );
				float2 appendResult65 = (float2(_Vector2.x , _Vector2.y));
				float4 tex2DNode51 = tex2D( _NoiseTex, ( texCoord58 + ( appendResult65 * _Time.y ) ) );
				float2 texCoord64 = i.ase_texcoord1.xy * _UV + float2( 0,0 );
				float2 appendResult67 = (float2(_Vector2.z , _Vector2.w));
				float4 tex2DNode53 = tex2D( _NoiseTex, ( texCoord64 + ( appendResult67 * _Time.y ) ) );
				float2 texCoord69 = i.ase_texcoord1.xy * float2( 1,1 ) + float2( 0,0 );
				float2 appendResult70 = (float2((0.0 + (( tex2DNode51.r + tex2DNode53.r ) - 0.0) * (1.0 - 0.0) / (2.0 - 0.0)) , texCoord69.y));
				float temp_output_91_0 = ( (1.0 + (_POW - 0.0) * (3.0 - 1.0) / (1.0 - 0.0)) + ( (0.0 + (sin( ( _Time.y * UNITY_PI ) ) - -1.0) * (0.4 - 0.0) / (1.0 - -1.0)) * 1.0 ) );
				float4 appendResult87 = (float4(temp_output_91_0 , temp_output_91_0 , temp_output_91_0 , 1.0));
				
				
				finalColor = ( ( tex2D( _MainTex, uv_MainTex ) * tex2D( _Gradual, appendResult70 ) ) * appendResult87 );

				#ifdef UNITY_UI_CLIP_RECT
                half2 m = saturate((_ClipRect.zw - _ClipRect.xy - abs(i.mask.xy)) * i.mask.zw);
                finalColor.a *= m.x * m.y;
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip (finalColor.a - 0.001);
                #endif

                finalColor.rgb *= finalColor.a;
				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "ASEMaterialInspector"
	
	
}
/*ASEBEGIN
Version=18707
-1073;487;1061;908;-1166.38;126.978;1;True;True
Node;AmplifyShaderEditor.Vector4Node;66;-1432.756,-81.2897;Inherit;False;Property;_Vector2;Vector 2;4;0;Create;True;0;0;False;0;False;0,0,0,0;0.14,-0.03,-0.2,-0.11;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.DynamicAppendNode;67;-1046.366,98.36926;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.DynamicAppendNode;65;-999.6057,-327.3978;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector2Node;74;-869.3973,-467.051;Inherit;False;Property;_UV;UV;6;0;Create;True;0;0;False;0;False;1,1;0.3,0.3;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.SimpleTimeNode;60;-921.647,356.8405;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleTimeNode;54;-894.9124,-97.03018;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;62;-657.9432,233.4704;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;64;-655.2675,67.25118;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TextureCoordinatesNode;58;-628.5332,-386.6194;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;56;-631.2089,-220.4002;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;63;-373.6102,211.0326;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleAddOpNode;59;-346.8759,-242.838;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleTimeNode;93;1172.548,110.806;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;51;4.581872,-199.5213;Inherit;True;Property;_NoiseTex;NoiseTex;0;0;Create;True;0;0;False;0;False;-1;None;329cbd31cdf818f4b8813fbc6dd32a92;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;53;11.39652,127.1135;Inherit;True;Property;_TextureSample0;Texture Sample 0;0;0;Create;True;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Instance;51;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.PiNode;96;1378.168,113.5816;Inherit;False;1;0;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SinOpNode;94;1595.949,113.6059;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;71;431.1541,15.53878;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;89;1749.855,95.15813;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;-1;False;2;FLOAT;1;False;3;FLOAT;0;False;4;FLOAT;0.4;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;69;700.9183,-301.1982;Inherit;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;81;1602.991,-221.9398;Inherit;False;Property;_POW;POW;7;0;Create;True;0;0;False;0;False;1;0;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;72;617.42,38.34687;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;2;False;3;FLOAT;0;False;4;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;70;984.7735,-224.1114;Inherit;False;FLOAT2;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;90;1997.667,86.81256;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.TFHCRemapNode;84;1926.163,-215.8773;Inherit;False;5;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;1;False;4;FLOAT;3;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;91;2259.773,-85.5346;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;75;1188.235,-721.3826;Inherit;True;Property;_MainTex;MainTex;1;0;Create;True;0;0;True;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;68;1183.03,-242.1754;Inherit;True;Property;_Gradual;Gradual;5;0;Create;True;0;0;False;0;False;-1;None;1bad291f41e2a934fb43f64dfb10d749;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;76;1803.139,-505.8156;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.DynamicAppendNode;87;2460.184,-41.53534;Inherit;False;FLOAT4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;1;False;1;FLOAT4;0
Node;AmplifyShaderEditor.RangedFloatNode;25;-227.5883,805.2778;Inherit;False;Property;_StencilComp;StencilComp;3;0;Create;True;0;0;True;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;85;2625.145,-403.8381;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT4;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;52;538.4758,-40.32349;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;24;-196.6139,723.9551;Inherit;False;Property;_Stnecil;Stnecil;2;0;Create;True;0;0;True;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;2854.327,-519.4949;Float;False;True;-1;2;ASEMaterialInspector;100;1;X1/UI/Hexinka;0770190933193b94aaa3065e307002fa;True;Unlit;0;0;Unlit;2;True;2;5;False;-1;10;False;-1;0;1;False;-1;0;False;-1;True;0;False;-1;0;False;-1;False;False;False;False;False;False;True;0;False;-1;True;0;False;-1;True;True;True;True;True;0;False;-1;False;False;False;True;True;255;True;24;255;False;-1;255;False;-1;7;True;25;1;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;True;2;False;-1;True;3;False;-1;True;True;0;False;-1;0;False;-1;True;2;RenderType=Transparent=RenderType;Queue=Transparent=Queue=0;True;2;0;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;1;LightMode=ForwardBase;False;0;;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;1;True;False;;False;0
WireConnection;67;0;66;3
WireConnection;67;1;66;4
WireConnection;65;0;66;1
WireConnection;65;1;66;2
WireConnection;62;0;67;0
WireConnection;62;1;60;0
WireConnection;64;0;74;0
WireConnection;58;0;74;0
WireConnection;56;0;65;0
WireConnection;56;1;54;0
WireConnection;63;0;64;0
WireConnection;63;1;62;0
WireConnection;59;0;58;0
WireConnection;59;1;56;0
WireConnection;51;1;59;0
WireConnection;53;1;63;0
WireConnection;96;0;93;0
WireConnection;94;0;96;0
WireConnection;71;0;51;1
WireConnection;71;1;53;1
WireConnection;89;0;94;0
WireConnection;72;0;71;0
WireConnection;70;0;72;0
WireConnection;70;1;69;2
WireConnection;90;0;89;0
WireConnection;84;0;81;0
WireConnection;91;0;84;0
WireConnection;91;1;90;0
WireConnection;68;1;70;0
WireConnection;76;0;75;0
WireConnection;76;1;68;0
WireConnection;87;0;91;0
WireConnection;87;1;91;0
WireConnection;87;2;91;0
WireConnection;85;0;76;0
WireConnection;85;1;87;0
WireConnection;52;0;51;1
WireConnection;52;1;53;1
WireConnection;0;0;85;0
ASEEND*/
//CHKSM=E915244B44FAAB0EAE9ADF0516FB9001184B7DB0