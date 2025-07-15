using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System;

public class NotchScreenUtil
{
    private static NotchScreenUtil _instance;

    public static NotchScreenUtil Instance
    {
        get
        {
            if (_instance == null)
            {
                _instance = new NotchScreenUtil();
            }

            return _instance;
        }
    }

#if UNITY_EDITOR

#elif UNITY_IOS
    //初始化
    [DllImport("__Internal")]
    private static extern string m_GetNotchHeight();
#elif UNITY_ANDROID
    private AndroidJavaObject jo;
    private AndroidJavaObject context;
    private AndroidJavaClass adi;
#endif


    private NotchScreenUtil()
    {
        try
        {
#if UNITY_EDITOR

#elif UNITY_IOS

#elif UNITY_ANDROID
        using (var up = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        {
            context = up.GetStatic<AndroidJavaObject>("currentActivity");

                adi = new AndroidJavaClass("com.bluewhale.androidutils.NotchScreenUtil");
                if (adi != null)
                {
                    jo = adi.CallStatic<AndroidJavaObject>("instance");
                    if (jo != null)
                    {
                        jo.Call("Init", context);
                    }
                }
        }
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }
    }


    public void Init()
    {
        Debug.Log("设备信息初始化");
    }


    // 获取刘海屏高度
    public int GetNotchHeight()
    {
        int height = 0;

        try
        {
#if UNITY_EDITOR

#elif UNITY_IOS
            height = (int)Mathf.Floor(Convert.ToSingle(m_GetNotchHeight()));
#elif UNITY_ANDROID
            if (jo != null)
            {
                height = jo.CallStatic<int>("getNotchHeight");
            }
#endif
        }
        catch (Exception e)
        {
            Debug.LogError(e);
        }

        return height;
    }


}