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
            // 🔴 2026-10-12 事故与回滚（勿再改回去）：
            // 72502790b 曾把 Android 真机 platformId==1 改成走 GooglePlayGamesLogin（Play Games），
            // 目的是移除 com.google.signin:google-signin-support 以消除 Play 的 16KB 告警。
            // 但 Play Games 的 Social.localUser.id 与 Google Sign-In 的 task.Result.UserId 是**两套
            // 身份体系**，同一个 Google 账号返回不同 id（实测 21 位数字 vs 20 字符），而账号名
            // 由该 id 派生（GetAcc("go"+id)）⇒ 老玩家在清数据/重装/换机后会被判成新号。
            // 实测 libnative-googlesignin.so 的 PT_LOAD p_align = 0x10000(64KB)，远高于 16KB 硬门槛，
            // 移除它只为消一条软告警，得不偿失 ⇒ 回滚为 Google Sign-In，保持 id 口径不变。
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
