using System;
using UnityEngine;
using GameCore;
using System.Net;
using GameLogic;
using System.Collections;
using System.Text.RegularExpressions;
using System.Collections.Generic;
using System.IO;
using LuaInterface;
using System.Runtime.InteropServices;
using System.Text;

namespace SDK
{
    public class SDKManager : UnitySingleton<SDKManager>
    {
        public delegate void InitLaunchAction(string data);
        public InitLaunchAction onInitLaunchCallback;

        public delegate void RegisterAction(string data);
        public RegisterAction onRegisterCallback;

        public delegate void LoginAction(string data);
        public LoginAction onLoginCallback;

        public delegate void PayAction(string data);
        public PayAction onPayCallback;

        public delegate void SwitchAccountAction(string data);
        public SwitchAccountAction onSwitchAccountCallback;

        public delegate void LogoutAction(string data);
        public LogoutAction onLogoutCallback;

        public delegate void MessageAction(string data);
        public MessageAction onMessageCallback;


        private static Proxy proxy;


        public bool IsInit { get; private set; }
        public void Initialize()
        {
            // 初始化
#if UNITY_IOS
            proxy = this.gameObject.AddComponent<iOSProxy>();
#elif UNITY_ANDROID
            proxy = this.gameObject.AddComponent<AndroidProxy>();
#else
            proxy = this.gameObject.AddComponent<Proxy>();
#endif
            // 初始化硬件信息
            AndroidDeviceInfo.Instance.DeviceInit();
            // 屏幕适配
            NotchScreenUtil.Instance.Init();
            // 初始化
            Init();
            IsInit = true;
        }


        void Update()
        {
            if (!AppConst.isSDKLogin) return;
            if (proxy==null)
            {
                return;
            }
            var msg = proxy.PopMessage();
            if (null == msg)
            {
                return;
            }
            Debug.LogFormat("[KTSDK] PopMessage - this: {0}, msgId: {1}, data: {2}", GetHashCode(), msg.msgId, msg.data);
            switch (msg.msgId)
            {
                case MessageDef.MSG_InitCallback:
                    if (null != onInitLaunchCallback)
                    {
                        onInitLaunchCallback(msg.data);
                    }
                    break;
                case MessageDef.MSG_RegisterCallback:
                    if (null != onRegisterCallback)
                    {
                        onRegisterCallback(msg.data);
                    }
                    break;
                case MessageDef.MSG_LoginCallback:
                    if (null != onLoginCallback)
                    {
                        onLoginCallback(msg.data);
                    }
                    break;
                case MessageDef.MSG_PayCallback:
                    if (null != Instance.onPayCallback)
                    {
                        onPayCallback(msg.data);
                    }
                    break;
                case MessageDef.MSG_SwitchAccountCallback:
                    if (null != onSwitchAccountCallback)
                    {
                        onSwitchAccountCallback(msg.data);
                    }
                    break;
                case MessageDef.MSG_LogoutCallback:
                    if (null != onLogoutCallback)
                    {
                        onLogoutCallback(msg.data);
                    }
                    break;
                case MessageDef.MSG_MessageCallback:
                    if (null != onMessageCallback)
                    {
                        onMessageCallback(msg.data);
                    }
                    break;
                default:
                    break;
            }
        }

        /// <summary>
        /// 相关接口
        /// </summary>
        //sdk 登录
        public void Init()
        {
            proxy.Init();
        }
        //sdk 登录
        public void Login()
        {
            proxy.Login();
        }
        //sdk 登录
        public void Logout()
        {
            proxy.Logout();
        }
        //sdk 数据上报
        public void SubmitExtraData(SDKSubmitExtraDataArgs args)
        {
            proxy.SubmitExtraData(args);
        }
        //sdk 支付
        public void Pay(SDKPayArgs args)
        {
            proxy.Pay(args);
        }
        //是否支持弹出退出框
        public bool IsSupportExit()
        {
            return proxy.IsSupportExit();
        }
        //sdk 退出
        public void ExitGame()
        {
            proxy.Exit();
        }
        //sdk获取支付订单号
        public string GetPayOrderID()
        {
            return "";
        }
        //sdk 绑定
        public void Bind()
        {
            proxy.Bind();
        }
        //sdk 社区
        public void Community()
        {
            proxy.Community();
        }
        //sdk 客服
        public void CustomerService()
        {
            proxy.CustomerService();
        }
        //sdk 账户关联
        public void Relation(string type)
        {
            proxy.Relation(type);
        }
        //sdk 账号注销
        public void Cancellation()
        {
            proxy.Cancellation();
        }
        //sdk 是否有兑换码功能
        public bool IsCDKey()
        {
            return proxy.IsCDKey();
        }
        //sdk 兑换码
        public void CDKey(string cdkey,string serverID, string roleID)
        {
            proxy.CDKey(cdkey, serverID, roleID);
        }
        //sdk 登录界面预留按钮1功能
        public void LoginPanel_Btn1()
        {
            proxy.LoginPanel_Btn1();
        }
        //sdk 登录界面预留按钮2功能
        public void LoginPanel_Btn2()
        {
            proxy.LoginPanel_Btn2();
        }

        //sdk 埋点
        public void CustomEvent(int type, string param)
        {
            if (proxy != null) proxy.CustomEvent(type, param);
        }

        /// <summary>
        /// ///////// sdk层回调
        /// </summary>
        /// <param name="data"></param>
        //sdk init 回调
        public void InitCallback(string data)
        {
            Debug.Log("Helper : InitCallback - data: " + data);
            proxy.PushMessage(new Message
            {
                msgId = MessageDef.MSG_InitCallback,
                data = data
            });
        }
        //sdk 注册 回调
        public void RegisterCallback(string data)
        {
            Debug.Log("Helper : RegisterCallback - data: " + data);
            proxy.PushMessage(new Message
            {
                msgId = MessageDef.MSG_RegisterCallback,
                data = data
            });
        }
        //sdk login 回调
        public void LoginCallback(string data)
        {
            Debug.Log("Helper : LoginCallback - data: " + data);
            proxy.PushMessage(new Message
            {
                msgId = MessageDef.MSG_LoginCallback,
                data = data
            });
        }
        //sdk Pay回调
        public void PayCallback(string data)
        {
            Debug.Log("Helper : PayCallback - data: " + data);
            proxy.PushMessage(new Message
            {
                msgId = MessageDef.MSG_PayCallback,
                data = data
            });
        }

        //sdk SwitchAccount回调
        public void SwitchAccountCallback(string data)
        {
            Debug.Log("Helper : SwitchAccountCallback - data: " + data);
            proxy.PushMessage(new Message
            {
                msgId = MessageDef.MSG_SwitchAccountCallback,
                data = data
            });
        }

        //sdk Logout回调
        public void LogoutCallback(string data)
        {
            Debug.Log("Helper : LogoutCallback - data: " + data);
            proxy.PushMessage(new Message
            {
                msgId = MessageDef.MSG_LogoutCallback,
                data = data
            });
        }

        //sdk 消息窗回调
        public void MessageCallback(string data)
        {
            Debug.Log("Helper : MessageCallback - data: " + data);
            proxy.PushMessage(new Message
            {
                msgId = MessageDef.MSG_MessageCallback,
                data = data
            });
        }
        public void SetSeverData(string data)
        {
            SendLogToServer.Instance.SetAnalytics(data);
        }

        public void DebugSdk(string data)
        {
            Debug.LogError("Helper : SDKDebug - data: " + data);
        }
    }
}
