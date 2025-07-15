using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using LuaInterface;
using GameCore;
#if UNITY_IOS
using System.Runtime.InteropServices;
#endif
namespace GameLogic {
    public class PhoneManager : UnitySingleton<PhoneManager>
    {
        AndroidJavaClass jc;
        AndroidJavaObject jo;

        string wifiData;
        float battarry_value = 1f;
        private static AndroidJavaObject mainActivity;
        private static bool initWXPay = false;
        private static LuaFunction onScuessPayHandle;
        private static LuaFunction onFailPayHandle;
        private static LuaFunction onUserCancelHandle;

        public static AndroidJavaObject MainActivity
        {
            get
            {
                if (mainActivity == null)
                {
                    using (var jc = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
                    {
                        mainActivity = jc.GetStatic<AndroidJavaObject>("currentActivity");
                    }
                }
                return mainActivity;
            }
        }

        public static void LocalTestAppPay(int payType, string appId, string partnerId, string apiKey, string totalfee, string bodyStr, string notifyUrl, bool isCreditCard, string callBackBackObjectName, string callBackFunctionName)
        {
            if (Application.isMobilePlatform)
            {
#if UNITY_ANDROID
                var wxPay = new AndroidJavaClass("com.doudou.dwc.AppPaySDK");
                if (wxPay != null)
                {
                    if (!initWXPay)
                    {
                        if (wxPay.CallStatic<bool>("InitUnityActivity", MainActivity, appId))
                        {
                            initWXPay = true;
                        }
                    }
                    if (initWXPay)
                    {
                        object[] objs = new object[] { payType, appId, partnerId, apiKey, totalfee, bodyStr, notifyUrl, isCreditCard ? 0 : 1, callBackBackObjectName, "WXPayCallBack" };
                        wxPay.CallStatic("LocationPayReq", objs);
                    }
                }
#endif
            }
        }

        //package="Sign=WXPay"
        public static void AppPay(int payType, string appid, string tokenId, string callBackBackObjectName, LuaFunction onScuessPay, LuaFunction onFailPay, LuaFunction onUserCancel)
        {
            if (Application.isMobilePlatform)
            {
                onScuessPayHandle = onScuessPay;
                onFailPayHandle = onFailPay;
                onUserCancelHandle = onUserCancel;
#if UNITY_ANDROID
                var wxPay = new AndroidJavaClass("com.doudou.dwc.AppPaySDK");
                if (wxPay != null)
                {
                    if (!initWXPay)
                    {
                        if (wxPay.CallStatic<bool>("InitUnityActivity", MainActivity, appid))
                        {
                            initWXPay = true;
                        }
                    }
                    if (initWXPay)
                    {
                        object[] objs = new object[] { payType, appid, tokenId, callBackBackObjectName, "PayCallBack" };
                        wxPay.CallStatic("PayReq", objs);
                    }
                }
                else
                {
                    GameLogic.Util.Log("No exsit AndroidJavaClass com.doudou.dwc.AppPaySDK");
                }
#elif UNITY_IPHONE || UNITY_IOS
           // AppPay(tokenId,callBackBackObjectName,"WXPayCallBack");
#endif
            }
        }

        public void PayCallBack(string msg)
        {
            switch (msg)
            {
                case "0":
                    if (onScuessPayHandle != null)
                    {
                        onScuessPayHandle.Call();
                    }
                    break;
                case "-1":
                    if (onFailPayHandle != null)
                    {
                        onFailPayHandle.Call();
                    }
                    break;
                case "-2":
                    if (onUserCancelHandle != null)
                    {
                        onUserCancelHandle.Call();
                    }
                    break;
            }
        }


#if UNITY_IOS
    //[DllImport("__Internal")]
    //private static extern float getiOSBatteryLevel();
   //  [DllImport("__Internal")]
   // private static extern void AppPay(string tokenId, string callBackObjectName,string callBackFunctionName);
	//[DllImport("__Internal")]
	//private static extern int getSignalStrength();
#endif

        public void BatteryValue()
        {
#if UNITY_ANDROID

#if !UNITY_EDITOR

        jc = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
        jo = jc.GetStatic<AndroidJavaObject>("currentActivity");
        wifiData = jo.Call<string>("ObtainWifiInfo");
        OnWifiDataBack(wifiData);

        // _BatteryState.value = GetBattery();//电量
        string batt = jo.Call<string>("MonitorBatteryState");
        print("----------更新电量-----------" + batt);
        if (float.TryParse(batt, out battarry_value))
        {
            //_BatteryState.value = battarry_value;
        }
        else { print("错误参数！"); }
    
#endif

#elif UNITY_IOS
         //battarry_value = getiOSBatteryLevel();//电量
#endif
        }



        /// <summary>
        /// 获取当前网络类型（2g、3g、4g/Wifi/无）
        /// </summary>
        /// <returns></returns>
        public static NetworkReachability GetNetworkReachabilityType()
        {
            return Application.internetReachability;
            /*
             * 
       Mark:   
       1.Application.internetReachability == NetworkReachability.ReachableViaCarrierDataNetwork  →  "当前为运行商网络（2g、3g、4g）";

       2.Application.internetReachability == NetworkReachability.ReachableViaLocalAreaNetwork  →  "当前为Wifi网络";

       3.Application.internetReachability == NetworkReachability.NotReachable  → "没有连接网络"**/
        }



        int xinhao = 0;
        int OnWifiDataBack(string wifiData)
        {
            string[] args = wifiData.Split('|');
            if (int.TryParse(args[0], out xinhao))
            {
                print(xinhao);
            }
            if (xinhao == 4)
            {
                print("信号很好");
                return 3;
            }
            else if (xinhao == 3)
            {
                print("信号一般");
                return 2;
            }
            else
            {
                print("信号很弱");
                return 1;
            }
        }
        public float GetBatteryValue()
        {
            BatteryValue();
            return battarry_value;
        }

        enum NetType
        {
            None = 0,
            G,//4G
            W,//wifi
            D,//未连接
        }
        public int GetNetType()
        {
            if (Application.internetReachability == NetworkReachability.ReachableViaLocalAreaNetwork)
            {
                return (int)NetType.W;
            }
            else if (Application.internetReachability == NetworkReachability.ReachableViaCarrierDataNetwork)
            {
                return (int)NetType.G;
            }
            else if (Application.internetReachability == NetworkReachability.NotReachable)
            {
                return (int)NetType.D;
            }
            return (int)NetType.None;
        }

        public string TimeYear()
        {
            return DateTime.Now.Year.ToString();
        }

        public string TimeMonth()
        {
            return DateTime.Now.Month.ToString();
        }

        public string TimeDay()
        {
            return DateTime.Now.Day.ToString();
        }

        public string TimeHour()
        {
            return DateTime.Now.Hour.ToString();
        }

        public string TimeMinute()
        {
            return DateTime.Now.Minute.ToString();
        }
    }

}
