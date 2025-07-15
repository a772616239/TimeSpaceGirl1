// �����Ķ���꣬ʹ��_CA_SOFTPARTICLES_OFF����ʹ��_CA_SOFTPARTICLES_ON��������������
// Shader��Material Keyword���������:
// 1.���Material��û�ж���Keyword�������ͨ��Shader��Enable/Disable
// 2.���Material�ж�����Keyword����ͨ��Shader��Enable/Disable��Ч

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

  // ��������������е�������Ч������ֹUI���޷���Ⱦ������Ч������Ҳ���Ա��������л������Ӻ�
  // ������Ҫע�⣬���͸�����ʱ����������û����Ⱦ����������ܻ��޷���ʾ��������Ч
  return fade * (1 - unity_OrthoParams.w);
}
