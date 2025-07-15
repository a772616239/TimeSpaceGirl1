using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace ResUpdate {

    /// <summary>
    /// 热更新配置
    /// </summary>
    public class UpdateConfigs
    {
        /// <summary>
        /// 游戏ID
        /// </summary>
        public static int appId;
        /// <summary>
        /// 配置文件名字
        /// </summary>
        public const string FILES = "files.unity3d";
        /// <summary>
        /// 临时文件的结尾
        /// </summary>
        public const string TMP_SUFFIX = ".tmp";
        /// <summary>
        /// 限制大小，超过该限制在非wifi环境下会提示下载大小
        /// </summary>
        public static long LimitSize = (long)(1024 * 0.5);
        /// <summary>
        /// 获取游戏版本URL
        /// </summary>
        public static string GameVersionUrl;
        /// <summary>
        /// 流媒体根目录
        /// </summary>
        public static string StreamPath;
        /// <summary>
        /// 持久化目录
        /// </summary>
        public static string PersistentDataPath;
    }

}
