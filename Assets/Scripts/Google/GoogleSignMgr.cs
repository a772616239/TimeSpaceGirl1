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
            SigninSampleScript signin = new SigninSampleScript();
            signin.OnSignIn((isSucc,id)=> {
                XDebug.Log.l("GoogleSignMgr 1:id:" + id);

                string name = null;
                string pw = null;
                GetAcc("go" + id, out name, out pw);

                XDebug.Log.l("GoogleSignMgr 2:pw:" + pw + "-acc:" + name);
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

                XDebug.Log.l("GoogleSignMgr 2:pw:" + pw + "-acc:" + name);
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
                deviceToken = "gt3" + id;
            }
            GetAcc(deviceToken, out name, out pw);

            XDebug.Log.l("GoogleSignMgr 3:pw:" + pw+"-acc:"+ name);
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
