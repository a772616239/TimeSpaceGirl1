//using UnityEngine;
//using System.Collections;
//using UnityEngine.UI;
//using System;

//public class TestLogin : MonoBehaviour
//{
//    public Button googleLogin;
//    public Button googleplayLogin;
//    public Text retText;

//    // Use this for initialization
//    void Start()
//    {
//        googleLogin.onClick.AddListener(OneGoogleLoginClick);
//        googleplayLogin.onClick.AddListener(OneGooglePlayLoginClick);

//    }

//    private void OneGooglePlayLoginClick()
//    {
//        GoogleSignMgr.Inst.LoginByPlatformType(2, (ret,str) =>
//        {
//            retText.text = str;
//        });
//    }

//    private void OneGoogleLoginClick()
//    {
//        GoogleSignMgr.Inst.LoginByPlatformType(1, (ret, str) =>
//        {
//            retText.text = str;
//        });
//    }
//}
