// 反常的定义宏，使用_CA_SOFTPARTICLES_OFF而不使用_CA_SOFTPARTICLES_ON来做定义是由于
// Shader和Material Keyword规则决定的:
// 1.如果Material中没有定义Keyword，则可以通过Shader中Enable/Disable
// 2.如果Material中定义了Keyword，则通过Shader中Enable/Disable无效

//#define _CA_SOFTPARTICLES_OFF
#if defined(_CA_SOFTPARTICLES_OFF)
# define CA_SOFTPARTICLES_COORDS(N)
# define CA_TRANSFER_SOFTPARTICLES(O, VERTEX)
# define CA_SOFTPARTICLES_FADE(I, A)
#else
# define CA_SOFTPARTICLES_COORDS(N)  float4 projPos : TEXCOORD##N;
# define CA_TRANSFER_SOFTPARTICLES(O, VERTEX) O.projPos = ComputeScreenPos(VERTEX); COMPUTE_EYEDEPTH(O.projPos.z);
# define CA_SOFTPARTICLES_FADE(I, A)    A *= ComputeSoftParticlesFade(I.projPos)
#endif

#define CA_DECLARE_SOFTPARTICLES       UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture); float _InvFade;
//UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
//float _InvFade;


half ComputeSoftParticlesFade(float4 projPos)
{
  float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(projPos)));
  float partZ = projPos.z;
  float fade = saturate (_InvFade * (sceneZ-partZ));

  // 屏蔽正交摄像机中的软粒子效果，防止UI中无法渲染软粒子效果，在也可以避免多相机切换软粒子宏
  // 但是需要注意，多个透视相机时，如果有相机没有渲染深度纹理，可能会无法显示软粒子特效
  return fade * (1 - unity_OrthoParams.w);
}
