using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using GameCore;
using ResMgr;
using GameLogic;
using ResourcesManager = GameLogic.ResourcesManager;

/// <summary>
/// 游戏入口
/// </summary>
public class App : UnitySingleton<App>
{
    /// <summary>
    /// 资源管理器
    /// </summary>
    public static ResourcesManager ResMgr
    {
        get
        {
            return ResourcesManager.Instance;
        }
    }

    /// <summary>
    /// AB包管理器
    /// </summary>
    public static AssetBundleManager AssetBundleMgr
    {
        get
        {
            return AssetBundleManager.Instance;
        }
    }

    /// <summary>
    /// BuglySdk管理器
    /// </summary>
    //public static BuglySdkManager BuglySdkMgr {
    //    get {
    //        return BuglySdkManager.Instance;
    //    }
    //}

    /// <summary>
    /// Lua管理器
    /// </summary>
    public static LuaManager LuaMgr
    {
        get
        {
            return LuaManager.Instance;
        }
    }

    /// <summary>
    /// 对象池管理器
    /// </summary>
    public static ObjectPoolManager ObjectPoolMgr
    {
        get
        {
            return ObjectPoolManager.Instance;
        }
    }

    /// <summary>
    /// 网络管理器
    /// </summary>
    public static NetworkManager NetWorkMgr
    {
        get
        {
            return NetworkManager.Instance;
        }
    }

    public static CompressManager CompressMgr
    {
        get
        {
            return CompressManager.Instance;
        }
    }

    public static GameManager GameMgr
    {
        get
        {
            return GameManager.Instance;
        }
    }
    public static IAPManager IAPMgr
    {
        get
        {
            return IAPManager.Inst;
        }
    }
    public static GoogleSignMgr GoogleSignMgr
    {
        get
        {
            return GoogleSignMgr.Inst;
        }
    }
    //public static TapDBManager TBDMgr
    //{
    //    get
    //    {
    //        return TapDBManager.Instance;
    //    }
    //}
    //public static BuglyManager BuglyMgr
    //{
    //    get
    //    {
    //        return BuglyManager.Instance;
    //    }
    //}

    //public static SoundManager SoundMgr {
    //    get {
    //        return SoundManager.Instance;
    //    }
    //}

    //public static PhoneManager PhoneMgr {
    //    get {
    //        return PhoneManager.Instance;
    //    }
    //}

    //public static UmengSdkManager UmengSdkMgr {
    //    get {
    //        return UmengSdkManager.Instance;
    //    }
    //}

    public static ImageDownloadManager ImageDownloadMgr
    {
        get
        {
            return ImageDownloadManager.Instance;
        }
    }

    public static SpeakManager SpeakMgr
    {
        get
        {
            return SpeakManager.Instance;
        }
    }

    public static SDK.SDKManager SDKMgr
    {
        get
        {
            return SDK.SDKManager.Instance;
        }
    }

    //public static ShareSDKManager ShareSDKMgr {
    //    get {
    //        return ShareSDKManager.Instance;
    //    }
    //}

    /// <summary>
    /// 版本管理器
    /// </summary>
    public static VersionManager VersionMgr
    {
        get
        {
            return VersionManager.Instance;
        }
    }
   public static ConfigManager ConfigMgr
    {
        get
        {
            return ConfigManager.Instance;
        }
    }

    /// <summary>
    /// 初始化
    /// </summary>
    public void Initialize()
    {
        ConfigMgr.Init();
        VersionMgr.Initialize();
    }

    /// <summary>
    /// 启动框架
    /// </summary>
    public void StartUp()
    {
        Caching.ClearCache();
        InitManager();
        InitLuaMgr();

        SendLogToServer.Instance.Init();
    }

    /// <summary>
    /// 初始化资源管理器
    /// </summary>
    public void InitResMgr()
    {

    }

    /// <summary>
    /// 初始化管理器
    /// </summary>
    void InitManager()
    {
    }

    /// <summary>
    /// 初始化游戏
    /// </summary>
    void InitLuaMgr()
    {
        LuaMgr.InitLua();

        LuaMgr.InitStart();
        //开始游戏逻辑
        LuaMgr.DoFile("Logic/Game");
        //加载网络
        LuaMgr.DoFile("Logic/SocketManager");
        //初始化网络
        NetWorkMgr.OnInit();
        //初始化完成
        Util.CallMethod("Game", "Initialize");
    }


    /// <summary>
    /// 重启游戏
    /// 返回登录界面，重启Lua虚拟机
    /// </summary>
    public void ReStart()
    {
        try
        {
            StartCoroutine(BeginReStart());
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }

    }

    IEnumerator BeginReStart()
    {
        ResMgr.UnLoadAll();
        yield return new WaitForEndOfFrame();
        LuaMgr.Reset();
        NetWorkMgr.Reset();
        ImageDownloadMgr.Reset();
        Util.m_lan = 0;
        //ShareSDKMgr.Reset();
        UpdateManager.Instance.StartUp();
    }

    public void CallLuaMessage(string msgID, object data)
    {
        Util.CallMethod("Network", "OnLuaMessage", msgID, data);
    }




    /// <summary>
    /// 应用程序获得焦点/失去焦点
    /// </summary>
    /// <param name="hasFocus"></param>
    void OnApplicationFocus(bool hasFocus)
    {
        Util.CallMethod("Game", "OnApplicationFocus", hasFocus);
    }

    /// <summary>
    /// 应用程序暂停/恢复
    /// </summary>
    /// <param name="pauseStatus"></param>
    void OnApplicationPause(bool pauseStatus)
    {
        Util.CallMethod("Game", "OnApplicationPause", pauseStatus);
    }

    /// <summary>
    /// 应用程序退出
    /// </summary>
    void OnApplicationQuit()
    {
        Util.CallMethod("Game", "OnApplicationQuit");
    }

}

