using UnityEngine;
using System.Collections;
using SignInSample;
using System;
public class LoginData{
    public bool IsSucc;
    public string PlatformId;
    public LoginData(bool isSucc,string PlatformId)
    {
        this.IsSucc = isSucc;
        this.PlatformId = PlatformId;
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
                if (callback != null)
                {
                    callback(new LoginData(isSucc, id));
                }
            });
            
        }
        else if (platformId==2)
        {
            GooglePlayGamesLogin signin = new GooglePlayGamesLogin();
            signin.LoginAuth((isSucc, id) => {

                XDebug.Log.l("GoogleSignMgr 2:id:" + id);

                if (callback != null)
                {
                    callback(new LoginData(isSucc, id));
                }
            });
        }
        else if (platformId == 3)
        {
            string id = DeviceIdHelper.GetDeviceID();
            XDebug.Log.l("GoogleSignMgr 3:id:" + id);
            if (callback != null)
            {
                callback (new LoginData(true, id));
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
