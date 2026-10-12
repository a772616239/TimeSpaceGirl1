using UnityEngine;
using System.Collections;
using SignInSample;
using System;
public class LoginData{
    public bool IsSucc;
    public string PlatformId;
    public string Pw;
    public LoginData(bool isSucc,string PlatformId, string pw)
    {
        this.IsSucc = isSucc;
        this.PlatformId = PlatformId;
        this.Pw = pw;
    }

}
public class GoogleSignMgr : MonoBehaviour
{
    public static GoogleSignMgr Inst;
    // Use this for initialization
    void Awake()
    {
        Inst = this;
    }
    public int CrtPlatformId;
    public void LoginByPlatformType(int platformId, Action<LoginData> callback)
    {
        this.CrtPlatformId = platformId;
        if (platformId==1){
            // 2026-10-12: Android 真机改用 Play Games 实现。
            // 原因: 原 Google Sign-In 插件依赖 com.google.signin:google-signin-support:1.0.4,
            //       其 jni/arm64-v8a/libnative-googlesignin.so 由 NDK r17 编译 -> 触发
            //       Play「16KB 设备上可能崩溃」告警；该依赖已从 mainTemplate.gradle 移除。
            // 关键: 保持 LoginPlatform=1 与 "go" 账号前缀不变, 因此 Lua 侧 LoginPanel、
            //       PlayerPrefs 的 lastLoginPlatform 语义与老玩家已保存凭据全部不受影响
            //       (lastPlt==1==LoginPlatform -> 走 RequestUser 用旧凭据, 账号不变)。
#if UNITY_ANDROID && !UNITY_EDITOR
            GooglePlayGamesLogin signin = new GooglePlayGamesLogin();
            signin.LoginAuth((isSucc, id) => {
                XDebug.Log.l("GoogleSignMgr 1(PlayGames):id:" + id);

                string name = null;
                string pw = null;
                GetAcc("go" + id, out name, out pw);

                if (callback != null)
                {
                    callback(new LoginData(isSucc, name, pw));
                }
            });
#else
            SigninSampleScript signin = new SigninSampleScript();
            signin.OnSignIn((isSucc,id)=> {
                XDebug.Log.l("GoogleSignMgr 1:id:" + id);

                string name = null;
                string pw = null;
                GetAcc("go" + id, out name, out pw);

                //XDebug.Log.l("GoogleSignMgr 2:pw:" + pw + "-acc:" + name);
                if (callback != null)
                {
                    callback(new LoginData(isSucc, name, pw));
                }
            });
#endif
        }
        else if (platformId==2)
        {
            GooglePlayGamesLogin signin = new GooglePlayGamesLogin();
            signin.LoginAuth((isSucc, id) => {

                XDebug.Log.l("GoogleSignMgr 2:id:" + id);
                string name = null;
                string pw = null;
                GetAcc("pl" + id, out name, out pw);

                //XDebug.Log.l("GoogleSignMgr 2:pw:" + pw + "-acc:" + name);
                if (callback != null)
                {
                    callback(new LoginData(isSucc, name, pw));
                }
            });
        }
        else if (platformId == 3)
        {
            string id = DeviceIdHelper.GetDeviceID();
            XDebug.Log.l("GoogleSignMgr 3:id:" + id);

            string name = null;
            string pw = null;
            string deviceToken = "gt" + id;
            if (Application.isEditor)
            {
                //deviceToken = "gtr" + id;
                deviceToken = "r2gt" + id;

            }
            GetAcc(deviceToken, out name, out pw);

            //XDebug.Log.l("GoogleSignMgr 3:pw:" + pw+"-acc:"+ name);
            if (callback != null)
            {
                callback (new LoginData(true, name,pw));
            }
        }
    }

    public void GetAcc(string tokenid,out string name,out string pw)
    {
        var acc = tokenid.Replace("-", "").Replace("_", "");
        var len = acc.Length;
        if (len>12)
        {
            name = acc.Substring(0, 12);
            pw = acc.Substring(12, Mathf.Min(12, len - 12));
        }
        else
        {
            name = acc;
            pw = acc;
        }

    }

    public void OnRet(bool isSucc,string id)
    {
        if (isSucc)
        {
            PlayerPrefs.SetInt("LastLoginPlatform", this.CrtPlatformId);
        }
    }
}
