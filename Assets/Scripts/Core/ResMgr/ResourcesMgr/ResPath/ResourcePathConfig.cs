
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
namespace ResMgr
{
    /// <summary>
    /// 资源路径信息配置表。
    /// 1、将ResourcePathConfig.json文件初始化为字典对象。
    /// </summary>
    [System.Serializable]
    [CreateAssetMenu(menuName = "自定义/资源路径配置文件")]
    public class ResourcePathConfig: ScriptableObject,ISerializationCallbackReceiver
    {
        /// <summary>
        /// string空数组
        /// </summary>
        public static string[] EmptyStrArray = new string[0];
        /// <summary>
        /// 资源所属路径列表
        /// </summary>
        [SerializeField]
        private List<string> resPathList;
        /// <summary>
        /// 资源隶属AssetBundle的名称
        /// </summary>
        [SerializeField]
        private List<string> resAbNameList;
        /// <summary>
        /// 资源信息列表只用于生成Json序列化
        /// </summary>
        [SerializeField]
        private List<ResPathInfo> resInfoList;
        /// <summary>
        /// AssetBundle信息列表
        /// </summary>
        [SerializeField]
        private List<AssetBundleInfo> assetBundleList;
        /// <summary>
        /// 资源路径信息表，这个表是ResourcePathConfig.json中的内容，它是在开发环境中生成。
        /// </summary>
        private Dictionary<string, ResPathInfo> resPathInfoMap;
        /// <summary>
        /// 依赖关系列表
        /// </summary>
        private Dictionary<string, AssetBundleInfo> dependences;

        public void Init(List<string> resList,List<string> abNames,Dictionary<string,ResPathInfo> resInfos,Dictionary<string, AssetBundleInfo> dependences) {
            this.resPathList = resList;
            this.resAbNameList = abNames;

            this.resInfoList = new List<ResPathInfo>();
            this.resInfoList.AddRange(resInfos.Values);

            this.assetBundleList = new List<AssetBundleInfo>();
            this.assetBundleList.AddRange(dependences.Values);
        }


        public void OnAfterDeserialize() {
            resPathInfoMap = new Dictionary<string, ResPathInfo>();
            for (int i = 0; i < resInfoList.Count; ++i)
            {
                var info = resInfoList[i];
                resPathInfoMap.Add(info.resName, info);
            }

            dependences = new Dictionary<string, AssetBundleInfo>();
            for (int i = 0; i < assetBundleList.Count; ++i)
            {
                dependences.Add(assetBundleList[i].assetBundleName, assetBundleList[i]);
            }
        }

        public void OnBeforeSerialize() {}


        /// <summary>
        /// 根据资源名称获取资源目录路径
        /// </summary>
        public string GetPath(string resName)
        {
            ResPathInfo info = null;
            if (resPathInfoMap.TryGetValue(resName,out info))
            {
                return resPathList[info.resPathIndex]+"/"+ resName + info.extension;
            }
            return string.Empty;
        }
       
        /// <summary>
        /// 获取依赖关系
        /// </summary>
        /// <param name="assetBundleName"></param>
        /// <returns></returns>
        public string[] GetAllDependencies(string assetBundleName) {
            AssetBundleInfo info = null;
            if (dependences.TryGetValue(assetBundleName,out info)) {
                return info.dependences;
            }
            return EmptyStrArray;
        }

        /// <summary>
        /// 根据资源名称获取资源所属AB名称
        /// </summary>
        public string GetABName(string resName)
        {
            ResPathInfo info = null;
            if (resPathInfoMap.TryGetValue(resName, out info))
            {
				return resAbNameList[resPathInfoMap[resName].resAbNameIndex]+ResConfig.ABExtName;
            }
            return string.Empty;
        }
    }

    /// <summary>
    /// AssetBundle信息
    /// </summary>
    [System.Serializable]
    public class AssetBundleInfo {
        /// <summary>
        /// AB包的名字
        /// </summary>
        [SerializeField]
        public string assetBundleName;
        /// <summary>
        /// 依赖关系
        /// </summary>
        [SerializeField]
        public string[] dependences;

        public AssetBundleInfo(string assetBundleName, string[] dependences)
        {
            this.assetBundleName = assetBundleName;
            this.dependences = dependences;
        }
    }

    /// <summary>
    /// 资源路径属性
    /// </summary>
    [System.Serializable]
    public class ResPathInfo
    {
        /// <summary>
        /// 资源名称
        /// </summary>
        [SerializeField]
        public string resName;
        /// <summary>
        /// 后缀名
        /// </summary>
        [SerializeField]
        public string extension;
        /// <summary>
        /// 资源路径下标
        /// </summary>
        [SerializeField]
        public int resPathIndex;
        /// <summary>
        /// AB名字下标
        /// </summary>
        [SerializeField]
        public int resAbNameIndex;

        public ResPathInfo(string resName,string resNameExt,int resPathIndex, int resAbNameIndex)
        {
            this.resName = resName;
            this.extension = resNameExt;
            this.resPathIndex = resPathIndex;
            this.resAbNameIndex = resAbNameIndex;
        }
    }

}


