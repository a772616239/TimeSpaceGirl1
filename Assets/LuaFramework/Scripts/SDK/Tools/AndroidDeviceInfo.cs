using System;
using UnityEngine;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class AndroidDeviceInfo
{
    private AndroidJavaObject jo;
    private AndroidJavaObject context;

    private static AndroidDeviceInfo _instance;

    public static AndroidDeviceInfo Instance
    {
        get
        {
            if (_instance == null)
            {
                _instance = new AndroidDeviceInfo();
            }

            return _instance;
        }
    }


#if UNITY_IOS
    ////设备机型类型
    //[DllImport("__Internal")]
    //private static extern string m_GetDeviceBrand();
    ////设备机型名称
    //[DllImport("__Internal")]
    //private static extern string m_GetDeviceModel();
    ////设备系统版本号
    //[DllImport("__Internal")]
    //private static extern string m_GetSystemVersion();
    ////设备分辨率
    //[DllImport("__Internal")]
    //private static extern string m_GetScreenRatio();
    ////设备运营商类型
    //[DllImport("__Internal")]
    //private static extern string m_GetOperatorName();
    ////设备网络状态
    //[DllImport("__Internal")]
    //private static extern string m_GetNetworkType();
    ////获取IP
    //[DllImport("__Internal")]
    //private static extern string m_GetLocalIpAddress();
    ////获取设备标识
    //[DllImport("__Internal")]
    //private static extern string m_GetDeviceID();
    ////获取IMEI
    //[DllImport("__Internal")]
    //private static extern string m_GetIMEICode();
    ////获取app名
    //[DllImport("__Internal")]
    //private static extern string m_GetAppName();
    ////获取版本名称
    //[DllImport("__Internal")]
    //private static extern string m_GetVersionName();
    ////获取版本号
    //[DllImport("__Internal")]
    //private static extern int m_GetVersionCode();
    ////获取包名
    //[DllImport("__Internal")]
    //private static extern string m_GetPackageName();
#endif




    private AndroidDeviceInfo()
    {
#if UNITY_ANDROID
        using (var up = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        {
            context = up.GetStatic<AndroidJavaObject>("currentActivity");
            using (var adi = new AndroidJavaClass("com.bluewhale.androidutils.AndroidDeviceInfo"))
            {
                jo = adi.CallStatic<AndroidJavaObject>("instance");
                jo.Call("Init", context);
            }
        }
#endif
    }
    public void DeviceInit()
    {
        Debug.Log("设备信息初始化");
    }
    //设备机型类型
    public string GetDeviceBrand()
    {
        string type = "";
        try
        {
#if UNITY_IOS
            //type = m_GetDeviceBrand();

#elif UNITY_ANDROID
            type = jo.CallStatic<string>("GetDeviceBrand");
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }
        return type;
    }
    //设备机型名称
    public string GetDeviceModel()
    {
        string type = "";
        try
        {
#if UNITY_IOS
            //type = m_GetDeviceModel();

#elif UNITY_ANDROID
            type = jo.CallStatic<string>("GetDeviceModel");
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }
        return type;
    }
    //设备系统版本号
    public string GetSystemVersion()
    {
        string type = "";
        try
        {
#if UNITY_IOS
            //type = m_GetSystemVersion();

#elif UNITY_ANDROID
            type = jo.CallStatic<string>("GetSystemVersion");
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }
        return type;
    }
    //设备分辨率
    public string GetScreenRatio()
    {
        string type = "";
        try
        {
#if UNITY_IOS
            //type = m_GetScreenRatio();

#elif UNITY_ANDROID
            type = jo.CallStatic<string>("GetScreenRatio", context);
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }
        return type;
    }
    //设备运营商类型
    public string GetOperatorName()
    {
        string type = "";
        try
        {

#if UNITY_IOS
            //type = m_GetOperatorName();
#elif UNITY_ANDROID
            type = jo.CallStatic<string>("GetOperatorName", context);
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }
        return type;
    }
    //设备网络状态
    public string GetNetworkType()
    {
        string type = "";
        try
        {
#if UNITY_IOS
            //type = m_GetNetworkType();
#elif UNITY_ANDROID
            type = jo.CallStatic<string>("GetNetworkType", context);
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }
        return type;
    }
    //获取IP
    public string GetLocalIpAddress()
    {
        string type = "";
        try
        {
#if UNITY_IOS
            //type = m_GetLocalIpAddress();
#elif UNITY_ANDROID
            type = jo.CallStatic<string>("GetLocalIpAddress", context);
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }
        return type;
    }
    //sdk 获取设备标识
    public string GetDeviceID()
    {
#if UNITY_IOS
        //return m_GetDeviceID();
        return "";       
#elif UNITY_ANDROID
        return jo.CallStatic<string>("GetDeviceID");
#else
        return "";
#endif
    }
    //sdk 获取IMEI
    public string GetIMEICode()
    {
#if UNITY_IOS
        //return m_GetIMEICode();
        return "";
#elif UNITY_ANDROID
        return jo.CallStatic<string>("GetIMEICode");
#else
        return "";
#endif
    }
    //sdk 获取app名
    public string GetAppName()
    {
#if UNITY_IOS
        //return m_GetAppName();
        return "";
#elif UNITY_ANDROID
        return jo.CallStatic<string>("getAppName");
#else
        return "";
#endif
    }
    //sdk 获取版本名称
    public string GetVersionName()
    {
#if UNITY_IOS
        //return m_GetVersionName();
        return "";
#elif UNITY_ANDROID
        return jo.CallStatic<string>("getVersionName");
#else
        return "";
#endif
    }
    //sdk 获取版本号
    public int GetVersionCode()
    {
#if UNITY_IOS
        //return m_GetVersionCode();
        return 0;
#elif UNITY_ANDROID
        return jo.CallStatic<int>("getVersionCode");
#else
        return 0;
#endif
    }
    //sdk 获取包名
    public string GetPackageName()
    {

#if UNITY_IOS
        //return m_GetPackageName();
        return "";
#elif UNITY_ANDROID
        return jo.CallStatic<string>("getPackageName");
#else
        return "";
#endif
    }




#if UNITY_IOS
//设备机型类型
    //[DllImport("__Internal")]
    //private static extern void m_CopyToClipBoard(string str);
    ////设备机型名称
    //[DllImport("__Internal")]
    //private static extern string m_PasteFromClipBoard();
#endif


    //暂时存放--复制粘贴功能（本不隶属于此）
    public void SetCopyValue(string str)
    {

#if UNITY_IOS
        //m_CopyToClipBoard(str);
#elif UNITY_ANDROID
        jo.CallStatic("CopyToClipBoard", str);
#else
#endif
    }
    public string GetPastValue()
    {
        string result = "";

#if UNITY_IOS
        //result = m_PasteFromClipBoard();
#elif UNITY_ANDROID
        result = jo.CallStatic<string>("PasteFromClipBoard", context);
#else
        
#endif
        return result;
    }

}
