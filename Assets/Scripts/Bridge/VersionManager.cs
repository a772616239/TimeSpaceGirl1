using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using GameCore;
using ResUpdate;
using System.Linq;
namespace GameLogic
{
    public class Version
    {
        Hashtable info;

        public Version(string json)
        {
            info = MiniJSON.jsonDecode(json) as Hashtable;
        }       

        public string ToJson()
        {
            return MiniJSON.jsonEncode(info);
        }

        public string GetInfo(string key)
        {
            if (info.ContainsKey(key))
            {
                return info[key] as string;
            }
            return null;
        }

        public void RemoveInfo(string key)
        {
            if (info.ContainsKey(key))
            {
                info.Remove(key);
            }
        }

        public void SetInfo(string key, string value)
        {
            info[key] = value;
        }
    }
    /// <summary>
    /// 版本管理器
    /// </summary>
    public class VersionManager : Singleton<VersionManager>
    {
        /// <summary>
        /// 版本号文件
        /// </summary>
        const string VersionsFile = "version";
        /// <summary>
        /// 外部版本号
        /// </summary>
        Version externalVersion;
        /// <summary>
        /// 流媒体目录中的游戏及其版本号
        /// </summary>
        Version internalVersion;
        
        public void Initialize()
        {
            InitVersions();
        }

        /// <summary>
        /// 初始化资源版本号
        /// </summary>
        public void InitVersions()
        {
            try
            {
                if (File.Exists(VersionsFilePath))
                {
                    System.Text.Encoding utf8 = new System.Text.UTF8Encoding(false);
                    externalVersion = new Version(File.ReadAllText(VersionsFilePath, utf8));
                }
            }
            catch (Exception e) {
                Debug.LogError(e);
            }

            try
            {
                internalVersion = new Version(Resources.Load<TextAsset>(VersionsFile).text);
            }
            catch(Exception e)
            {
                Debug.LogError(e);
            }

        }

        /// <summary>
        /// 保存版本号
        /// </summary>
        /// <param name="version"></param>
        public void SaveVersion(VersionPar vp)
        {
            if (externalVersion != null)
            {
                Debug.Log(string.Format("Save Vertion Before {0}", externalVersion.ToJson()));
                Debug.Log(vp.version);
                Debug.Log(vp.sdkLodingUrl);
                externalVersion.SetInfo("version", vp.version);
                externalVersion.SetInfo("sdkLodingUrl", vp.sdkLodingUrl);
                SaveToFiles(externalVersion);
                Debug.Log(string.Format("Save Vertion Final {0}", externalVersion.ToJson()));
                return;
            }
            if (internalVersion != null)
            {
                internalVersion.SetInfo("version", vp.version);
                internalVersion.SetInfo("sdkLodingUrl", vp.sdkLodingUrl);
                SaveToFiles(internalVersion);
                return;
            }
        }

        /// <summary>
        /// 获取版本号
        /// 1.优先从外部拿
        /// 2.拿不到返回-1
        /// </summary>
        /// <returns></returns>
        public string GetLocalVersion()
        {
            if (externalVersion != null)
            {
                return externalVersion.GetInfo("version");
            }

            if (internalVersion != null)
            {
                return internalVersion.GetInfo("version");
            }
            return null;
        }

        /// <summary>
        /// 对比版本号，返回不一样的位数 -1表示对比异常，0表示相同，其余表示按位不同
        /// </summary>
        /// <param name="ver1"></param>
        /// <param name="ver2"></param>
        /// <returns></returns>
        public static int VersionCompare(string ver1, string ver2)
        {
            string[] vs1 = ver1.Split('.');
            string[] vs2 = ver2.Split('.');

            if(vs1.Length != vs2.Length)
            {
                return -1;         
            }

            int v1, v2;
            for (int i = 0; i < vs1.Length; i++)
            {
                if (!int.TryParse(vs1[i], out v1))
                {
                    return -1;
                }
                if (!int.TryParse(vs2[i], out v2))
                {
                    return -1;
                }
                if (v1 != v2)
                {
                    return i + 1;
                }
            }
            return 0;
        }

        /// <summary>
        /// 获取版本内容，优先拿外部
        /// </summary>
        /// <param name="key"></param>
        /// <returns></returns>
        public string GetVersionInfo(string key)
        {
            if (externalVersion != null)
            {
                if(externalVersion.GetInfo(key) != null)
                {
                    return externalVersion.GetInfo(key);
                }
            }

            if (internalVersion != null)
            {
                return internalVersion.GetInfo(key);
            }
            return null;
        }

        public string GetVersionInfoStream(string key)
        {
            if (internalVersion != null)
            {
                return internalVersion.GetInfo(key);
            }
            return null;
        }

        /// <summary>
        /// 保存到文件
        /// </summary>
        void SaveToFiles(Version version)
        {
            string directoryPath = Path.GetDirectoryName(VersionsFilePath);
            if (!Directory.Exists(directoryPath)) Directory.CreateDirectory(directoryPath);

            System.Text.Encoding utf8 = new System.Text.UTF8Encoding(false);
            File.WriteAllText(VersionsFilePath, version.ToJson(), utf8);
        }

        /// <summary>
        /// 版本文件路径
        /// </summary>
        string VersionsFilePath
        {
            get
            {
                return AppConst.PersistentDataPath + VersionsFile + ".txt";
            }
        }

        /// <summary>
        ///  检测包版本，用于比较本地包与线上包的差异，有差异则需要更换新包
        /// </summary>
        public static bool CheckPackageVersionSame(string checkVersion)
        { 
            string localPackageVersion = Instance.GetVersionInfoStream("packageVersion");
            if(localPackageVersion != null && checkVersion != null)
            {
                return localPackageVersion.Equals(checkVersion);
            }else if(localPackageVersion == null && checkVersion == null)
            {
                return true;
            }
            return false;
        }
    }
}
