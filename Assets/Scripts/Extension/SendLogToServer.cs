//using GameVersion;
using GameLogic;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Networking;
using GameCore;

/// <summary>
/// 发送日志到服务器
/// </summary>
public class SendLogToServer
{
    public static SendLogToServer Instance = new SendLogToServer();

    //private string deviceModel;

    /// <summary>
    /// 过滤关键字
    /// </summary>
    //private string[] ignoreKeywords = new string[]
    //{
    //    "连接超时",
    //    "发送请求",
    //    "SocketError",
    //    "连接错误",
    //    "System.Net.WebException",
    //};

    /// <summary>
    /// 热更设置的过滤关键字
    /// </summary>
    //public string[] IgnoreKeywordsForHotDll = new string[0];

    public void Init()
    {
        // if(GameLogic.AppConst.isSDKLogin)
        // {
        //     Application.logMessageReceived += handleLogMessageReceived;
        // }
        
        //deviceModel = SystemInfo.deviceModel;
    }

    private void handleLogMessageReceived(string condition, string stackTrace, LogType type)
    {
        //for (int i = 0; i < ignoreKeywords.Length; i++)
        //{
        //    if (condition.Contains(ignoreKeywords[i]))
        //    {//过滤掉,不发送
        //        return;
        //    }
        //}

        //for (int i = 0; i < IgnoreKeywordsForHotDll.Length; i++)
        //{
        //    if (condition.Contains(IgnoreKeywordsForHotDll[i]))
        //    {//过滤掉,不发送
        //        return;
        //    }
        //}

        //LogItem item = new global::SendLogToServer.LogItem();
        //item.uid = 0;
        //if (HotCSharpManager.Instance.IsInit)
        //{
        //    if (HotCSharpClassMapping.PlayerData != null)
        //    {
        //        if (HotCSharpClassMapping.PlayerData.IsLogin)
        //        {
        //            item.uid = HotCSharpInfoCache.UserLongId;
        //        }
        //    }
        //}
        //item.channelId = Channel.Instance.GetChannelID();
        //item.logType = (int)type;
        //item.log = condition + "\r\n" + stackTrace;
        //item.version = GameVersionManager.Instance.GameVersion;
        //item.deviceModel = deviceModel;
        //item.dateTime = DateTimeToJavaLongTime(DateTime.Now);
        //sendLog(item);

        if(type == LogType.Error || type == LogType.Exception)
        {
            if(App.GameMgr.GetUid() != string.Empty)
            {
                string uid = App.GameMgr.GetUid();
                string channelId = App.VersionMgr.GetVersionInfo("subChannel");
                int logType = (int)type;
                string log = condition + "\r\n" + stackTrace;
                string version = App.VersionMgr.GetVersionInfo("version");
                string deviceModel = SystemInfo.deviceModel;
                long dateTime = DateTimeToJavaLongTime(DateTime.Now);
                string data = string.Empty;
                data = string.Concat("uid;", uid);
                data = string.Concat(data, ";channelId;", channelId);
                data = string.Concat(data, ";logType;", logType.ToString());
                data = string.Concat(data, ";log;", log);
                data = string.Concat(data, ";version;", version);
                data = string.Concat(data, ";deviceModel;", deviceModel);
                data = string.Concat(data, ";dateTime;", dateTime.ToString());

                string logUrl = App.VersionMgr.GetVersionInfo("logUrl");
                if (!string.IsNullOrEmpty(logUrl))
                {
                    App.NetWorkMgr.SendHttpPost_Json_CSharp(logUrl, data, delegate (string response)
                    {
                        if (response == "ok")
                        {//发送成功
                    }
                    },
                    delegate ()
                    {
                    });
                }
            }
        }

    }
    public void SetAnalytics(string step)
    {
        VersionManager version = new VersionManager();
        version.Initialize();
        string channel = version.GetVersionInfo("channel");
        string url = GameLogic.AppConst.ToServerAddr + "?param0=" + AndroidDeviceInfo.Instance.GetDeviceID() + "&param1=" + channel + "&param2=" + step;
        App.NetWorkMgr.SendAndroidData(url);
    }
    IEnumerator HttpSetdata(string url)
    {
        if (string.IsNullOrEmpty(url))
        {
           
        }
        Debug.Log(url);
        UnityWebRequest request = UnityWebRequest.Get(url);
        request.certificateHandler = new AcceptAllCertificatesSignedWithASpecificPublicKey();

        yield return request.SendWebRequest();
        if (request.isNetworkError)
        {
            Util.LogError("url::" + url + " HttpGet Error:    " + request.error);
            
            yield break;
        }
        else
        {
            //var result = Encoding.UTF8.GetString(getData.bytes);
            //var result = request.downloadHandler.text;

        }

    }
    private const long toUValue = 621355968000000000;

    /// <summary>
    /// 指定时间转成Java服务器long时间
    /// </summary>
    /// <param name="dateTime"></param>
    /// <returns></returns>
    public static long DateTimeToJavaLongTime(DateTime dateTime)
    {
        return (dateTime.ToUniversalTime().Ticks - toUValue) / 10000;
    }

    private void sendLog(LogItem item)
    {
        //if (string.IsNullOrEmpty(GameConfigManager.Instance.PostLogPath))
        //{
        //    return;
        //}

        //string json = LitJson.JsonMapper.ToJson(item);

        //HttpMessage.RequestHttpThread(GameConfigManager.Instance.PostLogPath, HttpMethods.Post, System.Text.Encoding.UTF8.GetBytes(json), delegate (string response)
        //{
        //    if (response == "ok")
        //    {//发送成功
        //    }
        //},
        //delegate (HttpMessage httpManager)
        //{
        //    int a = 0;
        //});
    }

    public class LogItem
    {
        /// <summary>
        /// UserID,如果未登录,是0
        /// </summary>
        public long uid;
        /// <summary>
        /// 渠道ID
        /// </summary>
        public string channelId;
        /// <summary>
        /// 日志类型
        /// </summary>
        public int logType;
        /// <summary>
        /// 日志内容
        /// </summary>
        public string log;
        /// <summary>
        /// 游戏版本
        /// </summary>
        public string version;
        /// <summary>
        /// 设备型号
        /// </summary>
        public string deviceModel;
        /// <summary>
        /// 本地时间戳,转换为Java时间
        /// </summary>
        public long dateTime;
    }
}