#if UNITY_IOS
using System.Runtime.InteropServices;

namespace SDK
{
    public class iOSProxy : Proxy
    {
        //初始化
        [DllImport("__Internal")]
        private static extern void m_SDK_Init();
        public override void Init()
        {
            m_SDK_Init();
        }

        //登录
        [DllImport("__Internal")]
        private static extern void m_SDK_Login();
        public override void Login()
        {
            m_SDK_Login();
        }

        //登录
        [DllImport("__Internal")]
        private static extern void m_SDK_Logout();
        public override void Logout()
        {
            m_SDK_Logout();
        }

        [DllImport("__Internal")]
        private static extern bool m_SDK_IsSupportExit();
        public override bool IsSupportExit()
        {
            return m_SDK_IsSupportExit();
        }

        //退出游戏
        [DllImport("__Internal")]
        private static extern void m_SDK_Exit();
        public override void Exit()
        {
            m_SDK_Exit();
        }

        [DllImport("__Internal")]
        private static extern void m_SDK_SubmitExtraData(
            int dataType,
            int serverId,
            string serverName,
            string zoneID,
            string zoneName,
            string roleID,
            string roleName,
            string roleLevel,
            string guildlD,
            string Vip,
            int moneyNum,
            string roleCreateTime,
            string roleLevelUpTime);
        public override void SubmitExtraData(SDKSubmitExtraDataArgs args)
        {
            m_SDK_SubmitExtraData(args.dataType,
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

        [DllImport("__Internal")]
        private static extern void m_SDK_Pay(
            string rechargeId,
            int showType,
            int productId,
            string productName,
            string productDesc,
            string price,
            string currencyType,
            int ratio,
            int buyNum,
            int coinNum,
            string zoneId,
            string serverID,
            string serverName,
            string accounted,
            string roleID,
            string roleName,
            int roleLevel,
            string vip,
            string guildlD,
            string payNotifyUrl,
            string extension,
            string orderID);
        public override void Pay(SDKPayArgs args)
        {
            m_SDK_Pay(args.rechargeId,
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

        }

        //sdk 绑定
        [DllImport("__Internal")]
        private static extern void m_SDK_Bind();
        public override void Bind()
        {
            m_SDK_Bind();
        }

        //sdk社区
        [DllImport("__Internal")]
        private static extern void m_SDK_Community();
        public override void Community()
        {
            m_SDK_Community();
        }


        [DllImport("__Internal")]
        private static extern void m_SDK_CustomerService();
        public override void CustomerService()
        {
            m_SDK_CustomerService();
        }

        [DllImport("__Internal")]
        private static extern void m_SDK_Relation(string type);
        public override void Relation(string type)
        {
            m_SDK_Relation(type);
        }

        [DllImport("__Internal")]
        private static extern void m_SDK_Cancellation();
        public override void Cancellation()
        {
            m_SDK_Cancellation();
        }

        [DllImport("__Internal")]
        private static extern bool m_SDK_IsCDKey();
        public override bool IsCDKey()
        {
            return m_SDK_IsCDKey();
        }

        [DllImport("__Internal")]
        private static extern void m_SDK_CDKey(string cdkey, string serverID, string roleID);
        public override void CDKey(string cdkey, string serverID, string roleID)
        {
            m_SDK_CDKey(cdkey, serverID, roleID);
        }

        [DllImport("__Internal")]
        private static extern void m_SDK_LoginPanel_Btn1();
        public override void LoginPanel_Btn1()
        {
            m_SDK_LoginPanel_Btn1();
        }

        [DllImport("__Internal")]
        private static extern void m_SDK_LoginPanel_Btn2();
        public override void LoginPanel_Btn2()
        {
            m_SDK_LoginPanel_Btn2();
        }

        //sdk打点功能
        [DllImport("__Internal")]
        private static extern void m_SDK_CustomEvent(int type, string param);
        public override void CustomEvent(int type, string param)
        {
            m_SDK_CustomEvent(type, param);
        }
    }
}

#endif