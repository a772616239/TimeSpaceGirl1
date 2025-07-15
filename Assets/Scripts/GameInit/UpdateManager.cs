using System;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using System.IO;
using GameCore;
using ResUpdate;
using UnityEngine.UI;

namespace GameLogic {

    public class ServerConfig
    {
        public static ServerConfig serverConfig;
        public string join_addr;            //通过web浏览器加入房间或者加入游戏URL地址
        public string server_addroot;       //php后台地址
        //public string config_addr;          //配置地址
        public string server_Ip;            //服务器IP
        public int server_Port;             //服务器端口
        public int maintain_status;         //服务器是否处于维护状态
        public List<string> extent;         //扩展信息
    }

    /// <summary>
    /// 更新管理器
    /// </summary>
    public class UpdateManager : Singleton<UpdateManager>
    {
        /// <summary>
        /// ab包
        /// </summary>
        AssetBundle bundle;

        /// <summary>
        /// 游戏启动调用，开始热更新
        /// </summary>
        public void StartUp() {
            UpdateConfigs.StreamPath = AppConst.StreamPath;
            UpdateConfigs.PersistentDataPath = AppConst.PersistentDataPath;
            CreateUpdatePanel();
        }

        protected ulong[] Crc32Table;
        //生成CRC32码表
        public void GetCRC32Table()
        {
            ulong Crc;
            Crc32Table = new ulong[256];
            int i, j;
            for (i = 0; i < 256; i++)
            {
                Crc = (ulong)i;
                for (j = 8; j > 0; j--)
                {
                    if ((Crc & 1) == 1)
                        Crc = (Crc >> 1) ^ 0xEDB88320;
                    else
                        Crc >>= 1;
                }
                Crc32Table[i] = Crc;
            }
        }

        //获取字符串的CRC32校验值
        public ulong GetCRC32Str(string sInputString)
        {
            //生成码表
            GetCRC32Table();
            byte[] buffer = Encoding.ASCII.GetBytes(sInputString);
            ulong value = 0xffffffff;
            int len = buffer.Length;
            for (int i = 0; i < len; i++)
            {
                value = (value >> 8) ^ Crc32Table[(value & 0xFF) ^ buffer[i]];
            }
            return value ^ 0xffffffff;
        }

        public  string PostServerInfo()
        {
            Hashtable table = new Hashtable();
            table.Add("time", DateUtils.GetTimeIntInfo(null, null, "TotalSeconds", true));
            //table.Add("deviceId", SDKManager.GetDeviceID());
            //table.Add("appVersion", SDKManager.GetAppVersion());
            //table.Add("ip", SDKManager.GetPublicIp());
            //table.Add("platVersion", VersionManager.Instance.GetLocalVersion());
            //table.Add("deviceType", SDKManager.GetDeviceSystemInfo());
            //table.Add("bundleName", SDKManager.GetPackageName());

            ArrayList akeys = new ArrayList(table.Keys);
            akeys.Sort();
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < akeys.Count; i++)
            {
                sb.Append(akeys[i]);
                sb.Append("=");
                sb.Append(table[akeys[i]]);
                sb.Append('&');
            }
            sb.Append("dsfasdtcxv88!0stponxfa=");
            string tmp = FileToCRC32.GetStrCRC32(sb.ToString());  //GetCRC32Str(sb.ToString()).ToString(); //
            table.Add("sign", tmp);
            XDebug.Log.l("sign===" + tmp + "  crcstr:" + sb.ToString());
            var jsonData = MiniJSON.jsonEncode(table);
            XDebug.Log.l("url===" + jsonData);
            return jsonData;
        }

        /// <summary>
        /// 创建更新面板
        /// </summary>
        void CreateUpdatePanel() {
            if (AppConst.bundleMode)
            {
                string path = AppConst.PersistentDataPath + "lz4|updatepanel.unity3d";
                if (!File.Exists(path))
                {
                    path = AppConst.StreamPath + "lz4|updatepanel.unity3d";
                }
                bundle = AssetBundle.LoadFromFile(path, 0, GameLogic.AppConst.EncyptBytesLength);
                if (bundle == null)
                {
                    XDebug.Log.error(string.Format("{0} 不存在，请检查", path ));
                    return;
                }
                GameObject gameObj = bundle.LoadAsset<GameObject>("UpdatePanel");
#if UNITY_EDITOR
                DealEditorMode(gameObj);
#endif
                UnityEngine.Object.Instantiate(gameObj, Vector3.zero, Quaternion.identity);
            }
            else 
            {
#if UNITY_EDITOR
                string path = AppConst.GameResPath + "/UpdatePanel/UpdatePanel.prefab";
                GameObject gameObj = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
                UnityEngine.Object.Instantiate(gameObj, Vector3.zero, Quaternion.identity);
#endif
            }
        }


#if UNITY_EDITOR
        private void DealEditorMode(GameObject prefab)
        {
            if (prefab == null || !(prefab is GameObject)) return;
            var renderers = (prefab as GameObject).GetComponentsInChildren<Renderer>();
            for (int i = 0; i < renderers.Length; i++)
            {
                if (renderers[i].sharedMaterials == null) continue;
                foreach (var each in renderers[i].sharedMaterials)
                {
                    if (each == null || each.shader == null) continue;
                    var shaderName = each.shader.name;
                    var newShader = Shader.Find(shaderName);
                    if (newShader != null)
                    {
                        each.shader = newShader;
                    }
                }
            }

            var images = (prefab as GameObject).GetComponentsInChildren<MaskableGraphic>();
            for (int i = 0; i < images.Length; i++)
            {
                if (images[i].material == null) continue;
                var shaderName = images[i].material.shader.name;
                var newShader = Shader.Find(shaderName);
                if (newShader != null)
                {
                    images[i].material.shader = newShader;
                }
            }
        }
#endif


        /// <summary>
        /// 更新资源
        /// </summary>
        /// <param name="action"></param>
        public void UpdateResources(Action<bool,ResourcesUpdateState,object> action) {
            ResourcesUpdateManager.Instance.BeginUpdate(App.VersionMgr.GetLocalVersion(), action);
        }

        /// <summary>
        /// 卸载更新资源
        /// </summary>
        public void UnLoadUpdateAsset()
        {
            if (bundle != null) bundle.Unload(true);
            bundle = null;
        }
    }
}
