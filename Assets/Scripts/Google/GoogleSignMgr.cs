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
                var acc = ("go" + id).Replace("-", "");
                var len = acc.Length;
                var name = acc.Substring(0, 12);
                var pw = acc.Substring(12, Mathf.Min(12, len));

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
                var acc = ("pl" + id).Replace("-", "");
                var len = acc.Length;
                var name = acc.Substring(0, 12);
                var pw = acc.Substring(12, Mathf.Min(12,len));

                if (callback != null)
                {
                    callback(new LoginData(isSucc, name, pw));
                }
            });
        }
        else if (platformId == 3)
        {
            string id = DeviceIdHelper.GetDeviceID();
            var acc= ("gu" + id).Replace("-", "");
            var len= acc.Length;
            var name = acc.Substring(0, 12);
            var pw = acc.Substring(12, Mathf.Min(12, len));

            XDebug.Log.l("GoogleSignMgr 3:id:" + id);
            if (callback != null)
            {
                callback (new LoginData(true, name,pw));
            }
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
