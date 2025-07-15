using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class ShadowProjector : MonoBehaviour 
{
    public Projector projector;
    //
    public Camera lightCamera;
    public RenderTexture shadowTex;
    //
    public Camera mainCamera;
    public List<Renderer> shadowCasterList = new List<Renderer>();
    public BoxCollider boundsCollider;
    public Transform bgSp; 
    public float boundsOffset = 1;//边界偏移，
    public Shader shadowReplaceShader;
    public bool IsFinished = false;
    public bool isAddFish = false;
	void Start () 
    {
        /*
        projector = GetComponent<Projector>();
        mainCamera = GameObject.FindGameObjectWithTag("MainCamera").GetComponent<Camera>();
        bgSp = mainCamera.transform.Find("BG1");
        if(lightCamera == null)
        {
            lightCamera = gameObject.AddComponent<Camera>();
            lightCamera.orthographic = true;
            lightCamera.cullingMask = LayerMask.GetMask("Fish");
            lightCamera.clearFlags = CameraClearFlags.SolidColor;
            lightCamera.backgroundColor = new Color(0,0,0,0);
       
            shadowTex = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGB32);
            shadowTex.filterMode = FilterMode.Bilinear;
            lightCamera.targetTexture = shadowTex;
            lightCamera.SetReplacementShader(shadowReplaceShader, "RenderType");
            projector.material.SetTexture("_ShadowTex", shadowTex);
            projector.ignoreLayers = LayerMask.GetMask("Fish");
        } 
         
        GameObject plane = GameObject.Find("Main Camera/FishRoot");
        if (plane != null)
        {
            foreach (Transform trans in plane.transform)
                if (trans.gameObject.layer == LayerMask.NameToLayer("Fish"))
                    shadowCasterList.Add(trans.gameObject.GetComponentInChildren<Renderer>());
        }//*/
        #if UNITY_EDITOR
        //boundsCollider = new GameObject("Test use to show bounds").AddComponent<BoxCollider>();
        #endif
       
	}

    /// <summary>
    /// 设置阴影渲染
    /// </summary>
    /// <param name="renderer"></param> 增加阴影渲染
    /// <param name="isAdd"></param>  是否加入渲染队列
    public void SetShadowCaster(Renderer renderer,bool isAdd)
    {
        if (isAdd)
           shadowCasterList.Add(renderer);
        else
           shadowCasterList.Remove(renderer);
    }
    public void SetBlackGround(Transform bg)
    {
        bgSp = bg;
    }

    void LateUpdate()
    {
        if (!IsFinished)
        {
            //Debug.LogError("为初始化");
            return;
        }
            
        if(isAddFish)
        {
            isAddFish = false;
            //GameObject plane = GameObject.Find("Main Camera/FishRoot");
            //if (plane != null)
            //{
                //foreach (Transform trans in plane.transform)
                //    if (trans.gameObject.layer == LayerMask.NameToLayer("Fish"))
            shadowCasterList.Add(bgSp.gameObject.GetComponentInChildren<Renderer>());
            //}
        }
        //求阴影产生物体的包围盒
        Bounds b = new Bounds();
        for (int i = 0; i < shadowCasterList.Count; i++)
        {
            if(shadowCasterList[i] != null)
            {
                b.Encapsulate(shadowCasterList[i].bounds);
            }
        }
        b.extents += Vector3.one * boundsOffset;
#if UNITY_EDITOR
        if (boundsCollider != null)
        {
            boundsCollider.center = b.center;
            boundsCollider.size = b.size;
        }
#endif
        //根据mainCamera来更新lightCamera和projector的位置，和设置参数
        ShadowUtils.SetLightCamera(b, lightCamera);
        lightCamera.farClipPlane = Mathf.Max(lightCamera.farClipPlane, bgSp.transform.localPosition.z+10);
        projector.aspectRatio = lightCamera.aspect;
        projector.orthographicSize = lightCamera.orthographicSize;
        projector.nearClipPlane = lightCamera.nearClipPlane;
        projector.farClipPlane = lightCamera.farClipPlane+1000;
	}
}
