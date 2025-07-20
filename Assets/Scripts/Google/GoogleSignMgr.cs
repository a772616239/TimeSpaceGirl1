using UnityEngine;
using System.Collections;
using SignInSample;
using System;

public class GoogleSignMgr : MonoBehaviour
{
    public static GoogleSignMgr Inst;
    // Use this for initialization
    void Awake()
    {
        Inst = this;
    }
    public int CrtPlatformId;
    public void LoginByPlatformType(int platformId, Action<bool, string> callback)
    {
        this.CrtPlatformId = platformId;
        if (platformId==1){
            SigninSampleScript signin = new SigninSampleScript();
            signin.OnSignIn(callback);
            
        }
        else if (platformId==2)
        {
            GooglePlayGamesLogin play = new GooglePlayGamesLogin();
            play.LoginAuth(callback);
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
