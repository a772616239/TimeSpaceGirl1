using GameCore;
using LitJson;
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace GameLogic
{
    public enum more_language
    {
        CANEL = 0,
        CONFIRM = 1,
        CONFIRM_CLOSE = 2,
        GET_GAME_SETTINGS = 3,
        RETRY = 4,
        GET_GAME_SETTINGS_FAILED = 5,
        GET_GAME_SETTINGS_ERROR = 6,
        GET_VERSION_INFO = 7,
        GET_GAME_SETTINGS_FAILED_CONFIRM_WIFI = 8,
        DOWNlOAD_FILE_FAILED_CONFIRM_WIFI = 9,
        GET_RESOURCES_SETTINGS = 10,
        GET_RESOURCES_VERSION_FAILED_CONFIRM_WIFI = 11,
        CHECK_RESOURCES_FILE = 12,
        GET_RESOURCES_SETTINGS_FAILED_CONFIRM_WIFI = 13,
        NOT_WIFI_CONFIRM = 14,
        WIFI_CONFIRM = 15,
        DOWNlOAD_RESOURCES_FILE_FAILED_CONFIRM_WIFI = 16,
        DOWNLOAD_NEWEST_APP = 17,
        DOWNLOAD_PROGRESS_RATE = 18,
        DOWNLOAD_PROGRESS = 19,
        UPDATE_COMPLETE = 20,
        RELOAD_RESOURCES = 21,
        TIPS = 22,
        INIT_FAILED = 23,
    }
    /// <summary>
    /// 更新管理器
    /// </summary>
    public class SLanguageMoreLanguageMgr : Singleton<SLanguageMoreLanguageMgr>
    {
        //Hashtable data;
        JsonData jData;
        /// <summary>
        /// 版本号文件
        /// </summary>
        const string languageFilePath = "Language";
        /// <summary>
        /// 版本文件路径
        /// </summary>
        string LanguageFilePath
        {
            get
            {
                return AppConst.PersistentDataPath + languageFilePath + ".json";
            }
        }
        public class languageStruct
        {
            public string chinese;
            public string english;
        }

        public void InitData()
        {
            InitLanguageConfig();
            InitLanguagedictionary();
        }
        private void ReadJson(string strjson)
        {
            XDebug.Log.l(strjson);
            jData = JsonMapper.ToObject<JsonData>(strjson);
        }

        public int GetLanguageType()
        {
            return PlayerPrefs.GetInt("multi_language", AppConst.originLan);
        }

        public void InitLanguageConfig()
        {
            //> 系统语音问题 todo
            //if (!PlayerPrefs.HasKey("multi_language"))
            //{
            //    if (Application.systemLanguage == SystemLanguage.Chinese || Application.systemLanguage == SystemLanguage.ChineseSimplified || Application.systemLanguage == SystemLanguage.ChineseTraditional)
            //    {
            //        PlayerPrefs.SetInt("multi_language", 0);
            //    }
            //    else
            //    {
            //        PlayerPrefs.SetInt("multi_language", 1);
            //    }
            //}


            //string languageStr = "";
            //switch (GetLanguageType())
            //{
            //    case 0: languageStr = "中文";break;
            //    case 1: languageStr = "英文"; break;
            //}
            //XDebug.Log.l("当前语言是：" + languageStr);
        }

        /// <summary>
        /// 初始化
        /// </summary>
        public void InitLanguagedictionary()
        {
            try
            {
                //首先检测读写目录是否有配置文件，如果有读取配置，如果没有，从resource加载
                StreamReader sr;
                if (File.Exists(LanguageFilePath))
                {
                    sr = File.OpenText(LanguageFilePath);
                    if (null != sr)
                    {
                        string strinfo = sr.ReadToEnd();
                        if (strinfo != null && strinfo.Length > 10)
                        {
                            ReadJson(strinfo);
                        }
                    }
                }
                else
                {
                    //加载本地默认配置
                    TextAsset config = Resources.Load<TextAsset>(languageFilePath) as TextAsset;
                    if (null != config)
                    {
                        ReadJson(config.ToString());
                    }
                    else
                    {
                        //取默认值
                        XDebug.Log.l("language.txt is no exist get the default");
                    }
                }
            }
            catch (Exception ex)
            {
                XDebug.Log.l(ex.ToString());
            }
        }

        string languageThrans = "";
        public string GetLanguageChValBykey(more_language language)
        {
            if (this.jData == null)
                this.InitData();
            try
            {
                
                
                string index1 = ((int)language).ToString();
                //var data2 = JsonMapper.ToJson();
                //var data1 = JsonMapper.ToObject<languageStruct>(data2);
                int L = ((int)Math.Floor((double)(GetLanguageType() / 100))) % 100;
                string str = jData[L][index1].ToString();
                languageThrans = str;
                //switch (GetLanguageType())
                //{
                //    case 0:
                //        languageThrans = data1.chinese;
                //        break;
                //    case 1:
                //        languageThrans = data1.english;
                //        break;
                //    default:
                //        languageThrans = data1.chinese;
                //        break;
                //}
            }
            catch (Exception e)
            {
                XDebug.Log.l(e.ToString());
            }
            return languageThrans;
        }
    }
}
