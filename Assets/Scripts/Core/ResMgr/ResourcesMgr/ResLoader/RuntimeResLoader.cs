using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using Object = UnityEngine.Object;
using System.IO;
using GameCore;
using GameLogic;
using UnityEngine.UI;

namespace ResMgr
{
    /// <summary>
    /// 真机资源加载器
    /// </summary>
    public class RuntimeResLoader : ResLoader
    {
        public class ResData
        {
            /// <summary>
            /// 加载完成回调
            /// </summary>
            public UnityEvent OnLoadFinish = new UnityEvent();
            /// <summary>
            /// 资源名字
            /// </summary>
            public string Name { get; set; }
            /// <summary>
            /// 资源文件
            /// </summary>
            public Object Asset { get; set; }
            /// <summary>
            /// 引用数量
            /// </summary>
            public int RefCount { get; set; }
            /// <summary>
            /// 是否加载完成
            /// </summary>
            public bool IsFinish { get; set; }
            /// <summary>
            /// AB文件加载器
            /// </summary>
            public AssetBundleLoader Loader { get; set; }

            /// <summary>
            /// 加载成功
            /// </summary>
            /// <param name="asset"></param>
            public void LoadSuccess(AssetBundleLoader loader, Object asset)
            {
                this.Asset = asset;
                this.Loader = loader;
                this.IsFinish = true;              
#if UNITY_EDITOR
                DealEditorMode();
#endif
                loader.AddRefResData(this.Name);
                OnLoadFinish.Invoke();
                OnLoadFinish.RemoveAllListeners();
            }

            /// <summary>
            /// 加载失败
            /// </summary>
            /// <param name="loader"></param>
            public void LoadFailed(AssetBundleLoader loader)
            {
                this.Loader = loader;
                this.IsFinish = true;
                OnLoadFinish.Invoke();
                OnLoadFinish.RemoveAllListeners();
            }

            /// <summary>
            /// 卸载
            /// </summary>
            public void UnLoad()
            {
                Loader.RemoveRefResData(this.Name);
                if (Asset != null)
                {
                    if (Asset is GameObject)
                        return;
                    Resources.UnloadAsset(Asset);
                }
            }

#if UNITY_EDITOR
            private void DealEditorMode()
            {
                if (Asset is Material)
                {
                    Material mat = Asset as Material;
                    mat.shader = Shader.Find(mat.shader.name);
                    return;
                }
                if (Asset == null || !(Asset is GameObject)) return;
                var renderers = (Asset as GameObject).GetComponentsInChildren<Renderer>();
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

                var images = (Asset as GameObject).GetComponentsInChildren<MaskableGraphic>();
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
            /// 回收
            /// </summary>
            public void Release()
            {
                RefCount = 0;
                Asset = null;
                Loader = null;
                Name = string.Empty;
                IsFinish = false;
                OnLoadFinish.RemoveAllListeners();
            }
        }

        static GameCore.ObjectPool<ResData> resDataPool = new GameCore.ObjectPool<ResData>(null, (resdata) => resdata.Release());
        /// <summary>
        /// 当前资源列表
        /// </summary>
        Dictionary<string, ResData> resMap = new Dictionary<string, ResData>();
        /// <summary>
        /// 加载失败列表
        /// </summary>
        Dictionary<string, ResData> resFailedMap = new Dictionary<string, ResData>();

        /// <summary>
        /// 初始化
        /// </summary>
        public override void Init()
        {
            InitResPathConfig();
        }

        /// <summary>
        /// 初始化资源路径配置
        /// </summary>
        void InitResPathConfig()
        {
			string path = string.Format("LZMA|ResConfigs").ToLower() + ResConfig.ABExtName;
			string fullPath = PathHelper.GetFullPath (path);
            AssetBundle ab = AssetBundle.LoadFromFile(fullPath, 0, GameLogic.AppConst.EncyptBytesLength);
            //AssetBundle ab = AssetBundle.LoadFromMemory(XXTEA.Decrypt(File.ReadAllBytes(fullPath)));
            ResPathConfig = ab.LoadAsset<ResourcePathConfig>("ResourcePathConfig");
            ab.Unload(true);
        }

        /// <summary>
        /// 加载资源
        /// </summary>
        /// <typeparam name="T">资源类型</typeparam>
        /// <param name="name">资源名字</param>
        /// <returns></returns>
        public override T LoadAsset<T>(string name)
        {
            T asset = null;
            ResData resData = null;
            if (resFailedMap.TryGetValue(name, out resData))
            {
                return null;
            }
            Debug.Log("LoadAsset:"+"-name:"+name);
            if (resMap.TryGetValue(name, out resData))
            {
                resData.RefCount++;
                asset = resData.Asset as T;
            }
            else
            {
                string path = ResPathConfig.GetABName(name);
                if (string.IsNullOrEmpty(path))
                {
                    if (BaseLogger.isDebug) BaseLogger.LogErrorFormat("没有找到包含资源{0}的AssetBundle！", name);
                    return null;
                }
                Debug.Log("LoadAsset:"+"path:"+path+"-name:"+name);
                AssetBundleLoader loader = AssetBundleManager.Instance.LoadAssetBundle(path, ResPathConfig);
                resData = resDataPool.Get();
                resData.Name = name;
                resData.RefCount++;
                resMap.Add(name, resData);
                asset = loader.LoadAsset<T>(name);
                resData.LoadSuccess(loader, asset);
            }
            return asset;
        }

        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="name">资源名字</param>
        /// <param name="action">完成回调</param>
        public override void LoadAssetAsync<T>(string name, UnityAction<string, T> action)
        {
            ResData resData = null;
            if (resFailedMap.TryGetValue(name, out resData))
            {
                action(name, null);
                return;
            }
            if (resMap.TryGetValue(name, out resData))
            {
                if (resData.IsFinish)
                {
                    resData.RefCount++;
                    action(name, resData.Asset as T);
                }
                else
                {
                    resData.RefCount++;
                    resData.OnLoadFinish.AddListener(() =>
                    {
                        action(name, resData.Asset as T);
                    });
                }
            }
            else
            {
                string path = ResPathConfig.GetABName(name);
                if (string.IsNullOrEmpty(path))
                {
                    if (BaseLogger.isDebug) BaseLogger.LogErrorFormat("没有找到资源包{0}的AssetBundle！path:", name, path);
                    action(name, null);
                    return;
                }
                resData = resDataPool.Get();
                resData.Name = name;
                resData.RefCount++;
                resData.OnLoadFinish.AddListener(() =>
                {
                    action(name, resData.Asset as T);
                });
                resMap.Add(name, resData);
                Debug.Log("path:"+path+"-name:"+name);
                AssetBundleManager.Instance.LoadAssetBundleAsyn(path, (tmpLoader) =>
                {
                    if (tmpLoader.AbLoaderState == ABLoaderState.Failed)
                    {
                        if (BaseLogger.isDebug) BaseLogger.LogErrorFormat("异步加载资源失败:{0}", name);
                        OnLoadFailed(resData, tmpLoader);
                        return;
                    }
                    tmpLoader.LoadAssetAsyn<T>(name, (tmpAsset) =>
                    {
                        if (tmpAsset != null)
                            resData.LoadSuccess(tmpLoader, tmpAsset);
                        else
                        {
                            OnLoadFailed(resData, tmpLoader);
                            if (BaseLogger.isDebug) BaseLogger.LogErrorFormat("异步加载资源失败:{0}", name);
                        }
                    });
                }, ResPathConfig);
            }
        }


        /// <summary>
        /// 加载失败列表
        /// </summary>
        /// <param name="resData"></param>
        /// <param name="loader"></param>
        void OnLoadFailed(ResData resData, AssetBundleLoader loader)
        {
            if (resMap.ContainsKey(resData.Name))
            {
                resMap.Remove(resData.Name);
            }
            if (!resFailedMap.ContainsKey(resData.Name))
            {
                resFailedMap.Add(resData.Name, resData);
            }
            resData.LoadFailed(loader);
        }

        /// <summary>
        /// 清理失败列表
        /// </summary>
        public override void ClearFailedMap()
        {
            List<ResData> list = ListPool<ResData>.Get();
            list.AddRange(resFailedMap.Values);
            for (int i = 0; i < list.Count; i++)
            {
                resDataPool.Release(list[i]);
            }
            ListPool<ResData>.Release(list);
            resFailedMap.Clear();
            AssetBundleManager.Instance.ClearFailedMap();
        }

        /// <summary>
        /// 卸载资源
        /// </summary>
        /// <param name="name"></param>
        public override void UnLoadAsset(string name)
        {
            ResData resData = null;
            if (resMap.TryGetValue(name, out resData))
            {
                resData.RefCount--;
                if (resData.RefCount <= 0)
                {
                    resMap.Remove(name);
                    resData.UnLoad();
                    resDataPool.Release(resData);
                }
            }
        }

        /// <summary>
        /// 卸载未使用资源
        /// </summary>
        public override void UnLoadUnUseAsset()
        {
            List<ResData> list = ListPool<ResData>.Get();
            list.AddRange(resMap.Values);
            ResData resData = null;
            for (int i = 0; i < list.Count; i++)
            {
                resData = list[i];
                if (!resData.IsFinish) continue;
                if (resData.RefCount != 0) continue;
                resMap.Remove(resData.Name);
                resData.UnLoad();
                resDataPool.Release(resData);
            }
            ListPool<ResData>.Release(list);
            resFailedMap.Clear();
            AssetBundleManager.Instance.UnLoadUnUseAssetBundles();
        }

        /// <summary>
        /// 无条件卸载所有资源
        /// </summary>
        public override void UnLoadAll()
        {
            List<ResData> list = ListPool<ResData>.Get();
            list.AddRange(resMap.Values);
            ResData resData = null;
            for (int i = 0; i < list.Count; i++)
            {
                resData = list[i];
                resMap.Remove(resData.Name);
                resData.UnLoad();
                resDataPool.Release(resData);
            }
            ListPool<ResData>.Release(list);
            resFailedMap.Clear();
            AssetBundleManager.Instance.UnLoadUnUseAssetBundles();
        }

        /// <summary>
        /// 是否有某个资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <returns></returns>
        public override bool HaveAsset(string assetName)
        {
            return !string.IsNullOrEmpty(ResPathConfig.GetABName(assetName));
        }


        public override void Update()
        {
        }
    }
}
