using System;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 服务器地址，换包强更时
/// 1.需要修改对应服务器ResUrl地址
/// 2.需要修改VersionManager.ResUrl为对应资源版本的变量名
/// </summary>
namespace GameEditor.FrameTool
{
    /// <summary>
    /// 网关服地址
    /// </summary>
    public enum ServerPathType
    {
        /// <summary>
        /// Trunk、Tag开发服
        /// </summary>
        [ServerPathTypeValue("http://120.92.119.145:8080/", "http://120.92.119.145/game_res/", null, "http://120.92.119.145:8081/idip/sfzb/sdk", "http://120.92.119.145:8081/idip/sfzb", "dev")]
        开发服 = 0,

        /// <summary>
        /// 商务服
        /// </summary>
        [ServerPathTypeValue("http://120.92.119.145:8080/", "http://162.62.232.128:81/")]
        商务服,

         /// <summary>
        /// 商务服
        /// </summary>
        [ServerPathTypeValue("http://162.62.232.128:8080/", "http://162.62.232.128:81/")]
        柯测试服,

        /// <summary>
        /// 百度测试
        /// </summary>
        [ServerPathTypeValue("http://106.12.148.155:8080/", "http://106.12.148.155:80/projectxglobal/", "http://106.12.148.155:8082/err", "http://106.12.148.155:8081/idip/sfzb/sdk", "http://106.12.148.155:8081/idip/sfzb")]
        百度新马简中测试服,

        /// <summary>
        /// 百度
        /// </summary>
        [ServerPathTypeValue("http://global-projectx-login.bdgser-oversea.com/", "https://projectx-global.bdgser-oversea.com/projectxglobal/Release/", "http://global-projectx-errlog.bdgser-oversea.com/err", "http://global-projectx-sdk.bdgser-oversea.com/idip/sfzb/sdk", "http://global-projectx-sdk.bdgser-oversea.com/idip/sfzb")]
        百度新马简中正式服,

        /// <summary>
        /// 9377正式服
        /// </summary>
        [ServerPathTypeValue("http://cn_login.emiplay.com/", "http://cn-hotupdate.emiplay.com/", "http://cn_err.emiplay.com/err", "http://cn_pay.emiplay.com/idip/sfzb/sdk", "http://cn_pay.emiplay.com/idip/sfzb")]
        正式服9377,

        /// <summary>
        /// 赤兔测试服
        /// </summary>
        [ServerPathTypeValue("http://120.92.209.58:8080/", "http://120.92.209.58:80/", "http://120.92.209.58:8082/err", "http://120.92.209.58:8081/idip/sfzb/sdk", "http://120.92.209.58:8081/idip/sfzb")]
        赤兔测试服,

        /// <summary>
        /// 赤兔正式服
        /// </summary>
        [ServerPathTypeValue("http://cn-login.caiyanghuyu.com/", "http://cn-hotupdate.caiyanghuyu.com/", "http://cn-err.caiyanghuyu.com/err", "http://cn-pay.caiyanghuyu.com/idip/sfzb/sdk", "http://cn-pay.caiyanghuyu.com/idip/sfzb")]
        赤兔正式服,

        /// <summary>
        /// 韩国测试服
        /// </summary>
        [ServerPathTypeValue("http://daclogin.ilod.co.kr/", "http://dacpu.ilod.co.kr/", "http://dacer.ilod.co.kr/err", "http://dacpay.ilod.co.kr/idip/sfzb/sdk", "http://dacpay.ilod.co.kr/idip/sfzb")]
        韩国测试服,

        /// <summary>
        /// 韩国正式服
        /// </summary>
        [ServerPathTypeValue("http://aclogin.ilod.co.kr/", "http://acpu.ilod.co.kr/", "http://acer.ilod.co.kr/err", "http://acpay.ilod.co.kr/idip/sfzb/sdk", "http://acpay.ilod.co.kr/idip/sfzb")]
        韩国正式服,

        /// <summary>
        /// Quick
        /// </summary>
        [ServerPathTypeValue("http://1.13.176.142:8080/", "http://1.13.176.142:80/", "http://1.13.176.142:8082/err", "http://1.13.176.142:8081/idip/sfzb/sdk", "http://1.13.176.142:8081/idip/sfzb")]
        QuickGame测试服,

        /// <summary>
        /// Quick
        /// </summary>
        [ServerPathTypeValue("http://1.13.165.154:8080/", "http://cn-hotupdate.weiweihudong.cn/", "http://1.13.165.154:8082/err", "http://1.13.165.154:8081/idip/sfzb/sdk", "http://1.13.165.154:8081/idip/sfzb")]
        QuickGame正式服,

        /// <summary>
        /// 长尾测试服
        /// </summary>
        [ServerPathTypeValue("http://1.13.176.142:8080/", "http://1.13.176.142:80/cw/", "http://1.13.176.142:8082/err", "http://1.13.176.142:8081/idip/sfzb/sdk", "http://1.13.176.142:8081/idip/sfzb")]
        长尾测试服,
        
        /// <summary>
        /// 长尾正式服
        /// </summary>
        [ServerPathTypeValue("http://1.13.165.154:8080/", "http://cn-hotupdate.weiweihudong.cn/cw/", "http://1.13.165.154:8082/err", "http://1.13.165.154:8081/idip/sfzb/sdk", "http://1.13.165.154:8081/idip/sfzb")]
        长尾正式服,

        /// <summary>
        /// 99测试服
        /// </summary>
        [ServerPathTypeValue("http://43.139.240.49:8080/", "http://43.139.240.49:80/", "http://43.139.240.49:8082/err", "http://43.139.240.49:8081/idip/sfzb/sdk", "http://43.139.240.49:8081/idip/sfzb")]
        测试服99,

        /// <summary>
        /// 99正式服
        /// </summary>
        [ServerPathTypeValue("http://yjqsl-login.boomegg.cn/", "http://yjqsl-static.boomegg.cn/", "http://yjqsl-err.boomegg.cn/err", "http://yjqsl-pay.boomegg.cn/idip/sfzb/sdk", "http://yjqsl-pay.boomegg.cn/idip/sfzb")]
        正式服99,
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public sealed class ServerPathTypeValueAttribute : Attribute
    {
        public string ServerUrl { get; private set; }
        public string ResUrl { get; private set; }
        public string LogUrl { get; private set; }
        public string SDKLoginUrl { get; private set; }
        public string PayUrl { get; private set; }
        public string Channel { get; private set; }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="serverUrl">游戏服地址</param>
        /// <param name="resUrl">资源地址</param>
        /// <param name="logUrl">错误收集地址</param>
        /// <param name="sdkLoginUrl">SDK登录地址</param>
        /// <param name="payUrl">支付地址</param>
        /// <param name="channel">用于控制同一服务器下可显示的区服 pc为正式，dev为研发，其他需求另加</param>
        public ServerPathTypeValueAttribute(string serverUrl, string resUrl = null, string logUrl = null, string sdkLoginUrl = null, string payUrl = null, string channel = "pc")
        {
            this.ServerUrl = serverUrl;
            this.ResUrl = resUrl;
            this.LogUrl = logUrl;
            this.SDKLoginUrl = sdkLoginUrl;
            this.PayUrl = payUrl;
            this.Channel = channel;
        }
    }


    public class ServerPathManager
    {
        public static ServerPathManager Instance = new ServerPathManager();

        //不应该直接调用该字段,有可能为null
        private Dictionary<ServerPathType, ServerPathTypeValueAttribute> serverPathDictionary;

        /// <summary>
        /// 服务器地址记录
        /// </summary>
        public Dictionary<ServerPathType, ServerPathTypeValueAttribute> ServerPathDictionary
        {
            get
            {
                if (serverPathDictionary == null)
                {
                    serverPathDictionary = new Dictionary<ServerPathType, ServerPathTypeValueAttribute>();

                    //读取枚举上的信息
                    ServerPathType[] values = (ServerPathType[])Enum.GetValues(typeof(ServerPathType));

                    foreach (var value in values)
                    {
                        System.Reflection.FieldInfo fi = value.GetType().GetField(Enum.GetName(typeof(ServerPathType), value));
                        object[] attrs = fi.GetCustomAttributes(typeof(ServerPathTypeValueAttribute), false);
                        ServerPathTypeValueAttribute typeInfo = attrs.Length == 0 ? null : (ServerPathTypeValueAttribute)attrs[0];
                        serverPathDictionary.Add(value, typeInfo);
                    }
                }

                return serverPathDictionary;
            }
        }

        public ServerPathTypeValueAttribute this[ServerPathType key]
        {
            get
            {
                try
                {
                    return ServerPathDictionary[key];
                }
                catch (KeyNotFoundException ex)
                {
                    Debug.LogErrorFormat("未找到{0}对应的服务器地址", key);
                }

                return null;
            }
        }
    }
}
