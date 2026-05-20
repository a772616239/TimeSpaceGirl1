using UnityEngine;
using UnityEditor;

public class ClearGuestLoginTool
{
    [MenuItem("Tools/登录/清除游客账号缓存 (切新游客)")]
    public static void ClearGuestLoginData()
    {
        // 1. 强制生成新的随机设备 ID 覆盖旧的
        string newId = System.Guid.NewGuid().ToString();
        PlayerPrefs.SetString("SaveDeviceKey", newId);
        // 2. 清除 LoginPanel.lua 中的账号缓存
        PlayerPrefs.DeleteKey("openIdkey");
        PlayerPrefs.DeleteKey("openIdPw");
        PlayerPrefs.DeleteKey("lastLoginPlatform");
        
        PlayerPrefs.Save();
        
        // 反射重置 DeviceIdHelper 的静态变量，防止不需要重启Unity
        var type = typeof(DeviceIdHelper);
        var field = type.GetField("_deviceId", System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.Public);
        if (field != null)
        {
            field.SetValue(null, null);
        }
        
        Debug.Log("已清除游客账号及本地登录缓存！下次点击【游客登录】将生成新账号。");
    }
}
