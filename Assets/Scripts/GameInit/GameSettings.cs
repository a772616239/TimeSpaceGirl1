using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using GameCore;

namespace GameLogic {
    //public enum MultiLan
    //{
    //    CN = 0,
    //    EN
    //}

    [System.Serializable]
    public class ServerInfo
    {
       public string ServerName;
       public string ServerUrl;
    }

    [System.Serializable]
    public class SettingInfo
    {
        /// <summary>
        /// logLevel
        /// </summary>
        public LogLevel logLevel;
        /// <summary>
        /// 是否为debug
        /// </summary>
        public bool isDebug;
        /// <summary>
        /// 是否为ab包模式
        /// </summary>
        public bool bundleMode;
        /// <summary>
        /// 是否开启LuaAB包模式
        /// </summary>
        public bool luaBundleMode;
        /// <summary>
        /// 是否开启热更新
        /// </summary>
        public bool isUpdate;
        /// <summary>
        /// 是否开启SDK
        /// </summary>
        public bool isSDK;
        /// <summary>
        /// 是否开启SDK登录
        /// </summary>
        public bool isSDKLogin;
        /// <summary>
        /// 是否开启新手引导
        /// </summary>
        public bool isGuide;
        /// <summary>
        /// 是否开启GM
        /// </summary>
        public bool isOpenGM;
        /// <summary>
        /// 是否勾选TLog(lua表结构log)
        /// </summary>
        public bool isOpenTLog;
        /// <summary>
        /// 是否勾选BLog(战斗数据log)
        /// </summary>
        public bool isOpenBLog;
        /// <summary>
        /// 初始语言
        /// </summary>
        public int originLan;
    }

    [ExecuteInEditMode]
    /// <summary>
    /// 游戏设置
    /// </summary>
    public class GameSettings : MonoBehaviour
    {
        [SerializeField]
        public SettingInfo settingInfo;
        void Awake()
        {
            InitGameSettings();
        }

        void Update()
        {
           InitGameSettings();
           
        }

       void InitGameSettings()
        {
            if (settingInfo != null)
            {
                if (!PlayerPrefs.HasKey("multi_language"))
                {
                    settingInfo.originLan=GetSystemLanguage2();
                }
                
                BaseLogger.isDebug = settingInfo.isDebug;
                BaseLogger.level = settingInfo.logLevel;
                AppConst.bundleMode = settingInfo.bundleMode;
                AppConst.isUpdate = settingInfo.isUpdate;
				AppConst.isGuide = settingInfo.isGuide;
                AppConst.isOpenGM = settingInfo.isOpenGM;
                AppConst.isSDK = settingInfo.isSDK;
                AppConst.isSDKLogin = settingInfo.isSDKLogin;
                AppConst.luaBundleMode = settingInfo.luaBundleMode;
                AppConst.isOpenTLog = settingInfo.isOpenTLog;
                AppConst.isOpenBLog = settingInfo.isOpenBLog;
                AppConst.originLan = settingInfo.originLan;

                AppConst.ChannelType = SDK.SDKChannelConfigManager.Instance.ChannelType;
            }
            Application.targetFrameRate = AppConst.GameFrameRate;        
        }

            public static int GetSystemLanguage2()
            {
                SystemLanguage sysLang = Application.systemLanguage;
                
                // 使用switch-case将系统语言映射到你的枚举
                switch (sysLang)
                {
                    case SystemLanguage.ChineseSimplified:    return 10001;   // 简体中文
                    case SystemLanguage.ChineseTraditional:   return 10001;   // 繁体中文
                    case SystemLanguage.English:              return 10101;   // 英语
                   
                    case SystemLanguage.Japanese:             return 10201;   // 日语
                    case SystemLanguage.Korean:               return 10301;   // 韩语
                    
                    // case SystemLanguage.m:                return LangManager.LANG_TYPE2.MS;   // 马来语
                    // 其他未列出的语言默认返回英语
                    default: return 10001;
                }
            }
    }

}
