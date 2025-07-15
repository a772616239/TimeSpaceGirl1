/**
 * 问题1：参数传递最好改用json...懒得去搞了！！！
 * 问题2：安卓和IOS端所需的相关参数竟然不同，MMP！！！，凑合用不改了。。。
 */
using UnityEngine;

namespace SDK
{
    public class AndroidProxy : Proxy
    {
        public static AndroidJavaObject currentActivity;

        private const string CLS_UNITY_PLAYER = "com.unity3d.player.UnityPlayer";

        public AndroidProxy()
        {
            var player = new AndroidJavaClass(CLS_UNITY_PLAYER);
            currentActivity = player.GetStatic<AndroidJavaObject>("currentActivity");
        }

        public override void Init()
        {
            currentActivity.Call("Init");
        }

        public override void Login()
        {
            currentActivity.Call("Login");
        }

        //登出
        public override void Logout()
        {
            currentActivity.Call("Logout");
        }

        public override bool IsSupportExit()
        {
            return currentActivity.Call<bool>("IsSupportExit");
        }

        public override void Exit()
        {
            currentActivity.Call("ExitGame");
        }

        public override void SubmitExtraData(SDKSubmitExtraDataArgs args)
        {
            currentActivity.Call("SubmitExtraData", args.dataType,
                                            args.serverID,
                                            args.serverName,
                                            args.zoneID,
                                            args.zoneName,
                                            args.roleID,
                                            args.roleName,
                                            args.roleLevel,
                                            args.guildID,
                                            args.Vip,
                                            args.moneyNum,
                                            args.roleCreateTime,
                                            args.roleLevelUpTime);
        }

        public override void Pay(SDKPayArgs args)
        {

            Debug.Log("consumerId = " + args.roleID +
                ",consumerName= " + args.roleName +
                ",mhtCurrency= " + args.coinNum +
                ",vipLevel= " + args.vip +
                ",playerName= " + args.guildID +
                ",roleName= " + args.roleName +
                ",roleId= " + args.roleID +
                ",orderDec= " + args.productDesc +
                ",amount= " + args.price +
                ",balance= " + "100" +
                ",goodDec= " + args.productName +
                ",count= " + args.buyNum +
                ",goodsId= " + args.productId +
                ",ext= " + args.extension +
                ",orderID= " + args.orderID //GameLogic.Util.Base64Encode(args.extension)
                );

            currentActivity.Call("Pay",
                args.rechargeId,
                args.showType,
                args.productId,
                args.productName,
                args.productDesc,
                args.price,
                args.currencyType,
                args.ratio,
                args.buyNum,
                args.coinNum,
                args.zoneId,
                args.serverID,
                args.serverName,
                args.accounted,
                args.roleID,
                args.roleName,
                args.roleLevel,
                args.vip,
                args.guildID,
                args.payNotifyUrl,
                args.extension,
                args.orderID);
            //GameLogic.Util.Base64Encode(args.extension));
        }



        ////SDK截屏
        //public override void ShotCapture()
        //{
        //    StartCoroutine(ScreenShotPNG());
        //}
        //IEnumerator ScreenShotPNG()
        //{
        //    yield return new WaitForEndOfFrame();
        //    int width = Screen.width;
        //    int height = Screen.height;
        //    Texture2D screenShot = new Texture2D(width, height, TextureFormat.RGB24, false);
        //    screenShot.ReadPixels(new Rect(0, 0, width, height), 0, 0);
        //    screenShot.Apply();
        //    byte[] bytes = screenShot.EncodeToPNG();
        //    Destroy(screenShot);
        //    currentActivity.Call("SendScreenshotData", bytes);
        //}

        public override void Bind()
        {
            currentActivity.Call("Bind");
        }
        ////sdk 获取设备标识
        //   public override string GetDeviceID()
        //   {
        //       return currentActivity.Call<string>("GetDeviceID");
        //   }
        //   //sdk 获取IMEI
        //   public override string GetIMEICode()
        //   {
        //       return currentActivity.Call<string>("GetIMEICode");
        //   }
        //   //sdk获取支付订单号
        //   public override string GetPayOrderID()
        //   {
        //       return currentActivity.Call<string>("GetOrderID");
        //   }

        public override void CustomerService()
        {
            currentActivity.Call("CustomerService");
        }

        public override void Relation(string type)
        {
            currentActivity.Call("Relation", type);
        }

        public override void Cancellation()
        {
            currentActivity.Call("Cancellation");
        }

        public override bool IsCDKey()
        {
            return currentActivity.Call<bool>("IsCDKey");
        }

        public override void CDKey(string cdkey, string serverID, string roleID)
        {
            currentActivity.Call("CDKey", cdkey, serverID, roleID);
        }

        public override void LoginPanel_Btn1()
        {
            currentActivity.Call("LoginPanel_Btn1");
        }

        public override void LoginPanel_Btn2()
        {
            currentActivity.Call("LoginPanel_Btn2");
        }

        //sdk打点功能
        public override void CustomEvent(int type, string param)
        {
            currentActivity.Call("CustomEvent", type, param);
        }
    }
}
