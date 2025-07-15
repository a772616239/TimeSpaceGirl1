using UnityEngine;
using UnityEditor;
using GameCore;
using System.Collections;
using System.IO;
using System;

namespace GameLogic
{
    public class MConfig
    {
        Hashtable info;

        public MConfig(string json)
        {
            info = MiniJSON.jsonDecode(json) as Hashtable;
        }

        public string ToJson()
        {
            return MiniJSON.jsonEncode(info);
        }

        public string GetInfo(string key)
        {
            string[] ks = key.Split('.');
            Hashtable ins = info;
            for (int i = 0; i < ks.Length; i++)
            {
                string k = ks[i];
                if (!ins.ContainsKey(k))
                {
                    break;
                }
                // 没有下一个值直接返回
                if (i + 1 == ks.Length)
                {
                    return ins[k] as string;
                }
                else
                {
                    ins = ins[k] as Hashtable;
                }
            }
            
            return null;
        }

        public void RemoveInfo(string key)
        {
            string[] ks = key.Split('.');
            Hashtable ins = info;
            for (int i = 0; i < ks.Length; i++)
            {
                string k = ks[i];
                if (!ins.ContainsKey(k))
                {
                    break;
                }
                // 
                if (i + 1 == ks.Length)
                {
                    ins.Remove(k);
                }
                else
                {
                    ins = ins[k] as Hashtable;
                }
            }
        }

        public void SetInfo(string key, string value)
        {
            string[] ks = key.Split('.');
            Hashtable ins = info;
            for (int i = 0; i < ks.Length; i++)
            {
                string k = ks[i];
                if (!ins.ContainsKey(k))
                {
                    break;
                }
                // 
                if (i + 1 == ks.Length)
                {
                    ins[k] = value;
                }
                else
                {
                    ins = ins[k] as Hashtable;
                }
            }
        }
    }
    public class ConfigManager : Singleton<ConfigManager>
    {

        /// <summary>
        /// 版本号文件
        /// </summary>
        const string configFile = "config";
        /// <summary>
        /// 版本文件路径
        /// </summary>
        string configFilePath
        {
            get
            {
                return AppConst.PersistentDataPath + configFile + ".txt";
            }
        }
        
        MConfig NetInfo;
        // 初始化 获取本地的数据
        public void Init()
        {
            try
            {
                if (File.Exists(configFilePath))
                {
                    NetInfo = new MConfig(File.ReadAllText(configFilePath, System.Text.Encoding.UTF8));
                }
            }
            catch (Exception e)
            {
                Debug.LogError(e);
            }
        }

        public void SetNetInfo(string info)
        {

            try
            {
                NetInfo = new MConfig(info);
                SaveToFiles();
            }
            catch (Exception e)
            {
                Debug.LogError(e);
            }
        }

        /// <summary>
        /// 保存到文件
        /// </summary>
        void SaveToFiles()
        {
            string directoryPath = Path.GetDirectoryName(configFilePath);
            if (!Directory.Exists(directoryPath)) Directory.CreateDirectory(directoryPath);
            File.WriteAllText(configFilePath, NetInfo.ToJson(), System.Text.Encoding.UTF8);
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="key"></param>
        /// <returns></returns>
        public string GetConfigInfo(string key)
        {
            string v = GetConfigNetInfo(key);
            if (v != null) return v;
            return null;
        }
        public string GetConfigNetInfo(string key)
        {
            if (NetInfo == null) return null;
            string v = NetInfo.GetInfo(key);
            return v;
        }
    }
}
