// VisitorLoginHelper.cs

using System;
using ETModel;
using UnityEngine;

public static class DeviceIdHelper
{
    public const string SaveDeviceKey = "SaveDeviceKey";
    public static string _deviceId;

    public static string SaveDeviceId
    {
        get
        {
            if (PlayerPrefs.HasKey(SaveDeviceKey))
            {
                _deviceId= PlayerPrefs.GetString(SaveDeviceKey);
                return _deviceId;
            }
            return _deviceId;
        }
        set
        {
            PlayerPrefs.SetString(SaveDeviceKey,value);
            _deviceId = value;
        }
    }
    public static string GetDeviceID()
    {
        if (!string.IsNullOrEmpty(SaveDeviceId))
        {
            return SaveDeviceId;
        }
        string deviceId=Guid.NewGuid().ToString();
#if UNITY_IOS&&!UNITY_EDITOR
            // iOS使用IdentifierForVendor (需Unity 2019.4+)
        deviceId  =UnityEngine.iOS.Device.vendorIdentifier;

#elif UNITY_ANDROID&&!UNITY_EDITOR
              // Android使用ANDROID_ID（可能重置）
        using (AndroidJavaClass unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        {
            AndroidJavaObject currentActivity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
            using (AndroidJavaObject contentResolver = currentActivity.Call<AndroidJavaObject>("getContentResolver"))
            {
                using (AndroidJavaClass secure = new AndroidJavaClass("android.provider.Settings$Secure"))
                {
                    var deviceId1 = secure.CallStatic<string>("getString", contentResolver, "android_id");
                    Debug.Log("Android ID: " + deviceId1);
                    if (!string.IsNullOrEmpty(deviceId1))
                    {
                        deviceId=deviceId1;
                    }
                }
            }
        }

#else
        // 其他平台用Unity生成的设备ID（可能不稳定）
        deviceId= SystemInfo.deviceUniqueIdentifier;
#endif
        SaveDeviceId=deviceId;
        return SaveDeviceId;
    }
    
}