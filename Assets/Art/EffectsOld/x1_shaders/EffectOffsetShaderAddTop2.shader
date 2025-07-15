// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Shader created with Shader Forge v1.36 
// Shader Forge (c) Neat Corporation / Joachim Holmer - http://www.acegikmo.com/shaderforge/
// Note: Manually altering this data may prevent you from opening it in Shader Forge
/*SF_DATA;ver:1.36;sub:START;pass:START;ps:flbk:,iptp:0,cusa:False,bamd:0,cgin:,lico:1,lgpr:1,limd:0,spmd:1,trmd:0,grmd:0,uamb:True,mssp:True,bkdf:False,hqlp:False,rprd:False,enco:False,rmgx:True,imps:True,rpth:0,vtps:0,hqsc:False,nrmq:1,nrsp:0,vomd:0,spxs:False,tesm:0,olmd:1,culm:2,bsrc:0,bdst:0,dpts:2,wrdp:False,dith:0,atcv:False,rfrpo:False,rfrpn:Refraction,coma:15,ufog:False,aust:False,igpj:True,qofs:0,qpre:3,rntp:2,fgom:False,fgoc:False,fgod:False,fgor:False,fgmd:0,fgcr:0,fgcg:0,fgcb:0,fgca:1,fgde:0.01,fgrn:0,fgrf:300,stcl:False,stva:128,stmr:255,stmw:255,stcp:6,stps:0,stfa:0,stfz:0,ofsf:-200,ofsu:0,f2p0:True,fnsp:True,fnfb:False,fsmp:False;n:type:ShaderForge.SFN_Final,id:4795,x:32925,y:32677,varname:node_4795,prsc:2|emission-2393-OUT,custl-4628-OUT;n:type:ShaderForge.SFN_Tex2d,id:6074,x:32235,y:32586,ptovrint:False,ptlb:MainTex,ptin:_MainTex,varname:_MainTex,prsc:0,glob:False,taghide:False,taghdr:False,tagprd:False,tagnsco:False,tagnrm:False,tex:bacb35e072e12ce43acae1d7366e8f36,ntxv:0,isnm:False;n:type:ShaderForge.SFN_Multiply,id:2393,x:32562,y:32778,varname:node_2393,prsc:2|A-6074-RGB,B-2053-RGB,C-797-RGB,D-5996-OUT;n:type:ShaderForge.SFN_VertexColor,id:2053,x:32235,y:32772,varname:node_2053,prsc:2;n:type:ShaderForge.SFN_Color,id:797,x:32235,y:32930,ptovrint:True,ptlb:Color,ptin:_TintColor,varname:_TintColor,prsc:0,glob:False,taghide:False,taghdr:False,tagprd:False,tagnsco:False,tagnrm:False,c1:1,c2:1,c3:1,c4:1;n:type:ShaderForge.SFN_Multiply,id:5996,x:32409,y:32930,varname:node_5996,prsc:2|A-6074-A,B-2053-A,C-797-A;n:type:ShaderForge.SFN_SwitchProperty,id:4628,x:32735,y:32841,ptovrint:False,ptlb:Glow,ptin:_Glow,varname:node_4628,prsc:2,glob:False,taghide:False,taghdr:False,tagprd:False,tagnsco:False,tagnrm:False,on:False|A-8296-OUT,B-2393-OUT;n:type:ShaderForge.SFN_Vector3,id:8296,x:32562,y:32901,varname:node_8296,prsc:2,v1:0,v2:0,v3:0;proporder:797-6074-4628;pass:END;sub:END;*/

Shader "ysj/EffectOffsetShaderAddTop" {
    Properties {
        _TintColor ("Color", Color) = (1,1,1,1)
        _MainTex ("MainTex", 2D) = "white" {}
        [MaterialToggle] _Glow ("Glow", Float ) = 0
    }
    SubShader {
        Tags {
            "IgnoreProjector"="True"
            "Queue"="Transparent"
            "RenderType"="Transparent+100"
        }
        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }
            Blend One One
            Cull Off
            ZWrite Off
			ZTest off
            //Offset -500, 0
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            #pragma multi_compile_fwdbase
            #pragma only_renderers d3d9 d3d11 glcore gles gles3 metal n3ds wiiu 
            #pragma target 2.0
            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            uniform fixed4 _TintColor;
            uniform fixed _Glow;
            struct VertexInput {
                float4 vertex : POSITION;
                float2 texcoord0 : TEXCOORD0;
                float4 vertexColor : COLOR;
            };
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float4 vertexColor : COLOR;
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                o.uv0 = v.texcoord0;
                o.vertexColor = v.vertexColor;
                o.pos = UnityObjectToClipPos(v.vertex );
                return o;
            }
            float4 frag(VertexOutput i, float facing : VFACE) : COLOR {
                float isFrontFace = ( facing >= 0 ? 1 : 0 );
                float faceSign = ( facing >= 0 ? 1 : -1 );
////// Lighting:
////// Emissive:
                fixed4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));
                float3 node_2393 = (_MainTex_var.rgb*i.vertexColor.rgb*_TintColor.rgb*(_MainTex_var.a*i.vertexColor.a*_TintColor.a));
                float3 emissive = node_2393;
                float3 finalColor = emissive + lerp( float3(0,0,0), node_2393, _Glow );
                return fixed4(finalColor,1);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
    CustomEditor "ShaderForgeMaterialInspector"
}
