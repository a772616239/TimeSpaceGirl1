using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using LuaInterface;
using GameCore;
using System;

namespace GameLogic {
    /// <summary>
    /// 集成自LuaFileUtils，重写里面的ReadFile，
    /// </summary>
    public class LuaLoader : LuaFileUtils
    {
        
        // Use this for initialization
        const string ConfigsName = "InitLuas";
        /// <summary>
        /// 平台的配置,这些文件默认都会到平台里头去加载。
        /// </summary>
        List<string> list = new List<string>();
        public LuaLoader()
        {
            instance = this;
            beZip = AppConst.luaBundleMode;
            InitConfigs();
        }

        public void InitConfigs() {
            string configs = App.ResMgr.LoadAsset<TextAsset>(ConfigsName).text;
            App.ResMgr.UnLoadAsset(ConfigsName);
            string[] configss = configs.Replace("\r\n", "\n").Replace("\n","|").Split('|');
            for (int i = 0; i < configss.Length; i++) {
                if (string.IsNullOrEmpty(configss[i])) continue;
                if (configss[i].Contains("@")) continue;
                list.Add(configss[i]);
            }
        }

        /// <summary>
        /// 添加打入Lua代码的AssetBundle
        /// </summary>
        /// <param name="bundle"></param>
        public void AddBundle(string bundleName)
        {
            string url = Util.DataPath + bundleName.ToLower();
            if (File.Exists(url))
            {
                AssetBundle bundle = AssetBundle.LoadFromFile(url, 0, GameLogic.AppConst.EncyptBytesLength);
                if (bundle != null)
                {
                    bundleName = bundleName.Replace("lua/", "").Replace(".unity3d", "");
                    base.AddSearchBundle(bundleName.ToLower(), bundle);
                }
            }
        }


        /// <summary>
        /// 当LuaVM加载Lua文件的时候，这里就会被调用，
        /// 用户可以自定义加载行为，只要返回byte[]即可。
        /// </summary>
        /// <param name="fileName"></param>
        /// <returns></returns>
        public override byte[] ReadFile(string fileName)
        {
            fileName = fileName.Replace(".lua", string.Empty);
            if (AppConst.luaBundleMode)
            {
                return LoadFromAssetBundle(fileName);
            }
            else
            {
                return base.ReadFile(fileName);
            }
        }


        byte[] LoadFromAssetBundle(string fileName)
        {
            string assetName = fileName.Replace("/", "_");

#if UNITY_ANDROID
            if (IntPtr.Size == 8)
            {
                assetName += "_64";
            }
#elif UNITY_IOS
            assetName += "%64";//iOS只读取64位
#endif
            byte[] bytes = App.ResMgr.LoadAsset<TextAsset>(assetName).bytes;
            //App.ResMgr.UnLoadAsset(game, assetName);
            return bytes;
        }
    }
}
