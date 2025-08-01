using System.Collections;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;
using UnityEngine.UI;
using GameLogic;
using System.IO;
using XDebug;

/// <summary>
/// 游戏启动驱动
/// </summary>
public class GameStart : MonoBehaviour
{
    private AssetBundle bundle;

    void Start()
    {
        Shader.SetGlobalFloat("SceneScale", 1.5f);

        Debug.Log("### GameStart");
        if (Application.isEditor && AppConst.bundleMode && AppConst.isUpdate)
        {
            if (!System.IO.Directory.Exists(Util.AppContentPath()))
            {
                XDebug.Log.error("还未打包平台资源，移放到StreamAssets目录");
                return;
            }
        }

        if (Application.isEditor)
        {
            PlayerPrefs.SetInt("gameStart",2);
            App.Instance.Initialize();
            UpdateManager.Instance.StartUp();
            //playSplash();
        }
        else
        {
            AppConst.bundleMode = true;
            AppConst.luaBundleMode = true;
            AppConst.isGuide = true;
            //AppConst.isOpenGM = true;
            if (AppConst.bundleMode) //先走闪屏流程
            {
                if (AppConst.isSDKLogin && !SDK.SDKManager.Instance.IsInit) //当登录sdk时，等待初始化完成后再走闪屏流程
                {
                    // SendLogToServer.Instance.SetAnalytics("2");
                    // SDK.SDKManager.Instance.Initialize();
                    //
                    // SDK.SDKManager.Instance.onInitLaunchCallback += s => {
                    //     // playSplash();
                    //     PlayerPrefs.SetInt("gameStart",2);
                    // };
                    PlayerPrefs.SetInt("gameStart",2);

                    playSplash();
                }
                else
                {
                    PlayerPrefs.SetInt("gameStart",2);
                    playSplash();
                }
            }
        }
        SDK.SdkCustomEvent.CustomEvent("游戏激活");
    }

    void playSplash()
    {
        //string path = AppConst.PersistentDataPath + "lz4/splashpanel.unity3d";
        //if (!File.Exists(path))
        //{
        //    path = AppConst.StreamPath + "lz4/splashpanel.unity3d";
        //}
        //bundle = AssetBundle.LoadFromFile(path, 0, GameLogic.AppConst.EncyptBytesLength);
        //GameObject gameObj = bundle.LoadAsset<GameObject>("SplashPanel");
        //GameObject gameObj2 = Instantiate(gameObj, Vector3.zero, Quaternion.identity);
        //Image image = gameObj2.transform.Find("Canvas/image").GetComponent<Image>();

        //image.color = new Color(image.color.r, image.color.g, image.color.b, 0);
        //image.DOFade(1, 1).OnComplete(() =>
        //{
        //    image.DOFade(0, 1).SetDelay(1).OnComplete(() =>
        //    {
        //        DestroyImmediate(gameObj2);
        //        if (bundle != null) bundle.Unload(true);
        //        bundle = null;
                App.Instance.Initialize();
                UpdateManager.Instance.StartUp();
                //StartCoroutine(playMovice());
        //    });
        //});
    }

    //IEnumerator playMovice()
    //{
    //    Handheld.PlayFullScreenMovie("PV_v5_0521_1.mp4", Color.black, FullScreenMovieControlMode.CancelOnInput);

    //    yield return new WaitForEndOfFrame();

    //    App.Instance.Initialize();
    //    UpdateManager.Instance.StartUp();
    //}
}
