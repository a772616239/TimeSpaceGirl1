using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using System.IO;
using System.Text;
using GameCore;

namespace ResMgr
{
    /// <summary>
    /// AsssetBundleManager管理器
    /// </summary>
    public class AssetBundleManager : UnitySingleton<AssetBundleManager>
    {
        /// <summary>
        /// ABLoader列表
        /// </summary>
        Dictionary<string, AssetBundleLoader> bundleMap = new Dictionary<string, AssetBundleLoader>();
        /// <summary>
        /// 加载失败列表
        /// </summary>
        Dictionary<string, AssetBundleLoader> failedMap = new Dictionary<string, AssetBundleLoader>();
        /// <summary>
        /// 等待卸载的列表
        /// </summary>
        List<AssetBundleLoader> unLoadList = new List<AssetBundleLoader>();
        /// <summary>
        /// AssetBundleLoader缓存池
        /// </summary>
        SimplePool loaderPool;
        /// <summary>
        /// 当前使用的AB包
        /// </summary>
        Transform ab;
        /// <summary>
        /// 回收的AB包
        /// </summary>
        Transform abRelease;
        /// <summary>
        /// 加载失败的AB文件
        /// </summary>
        Transform abLoadFailed;

        private void Awake()
        {
            ab= new GameObject("ab").transform;
            ab.SetParent(transform);
            abRelease = new GameObject("abRelease").transform;
            abRelease.SetParent(transform);
            abLoadFailed = new GameObject("abLoadFailed").transform;
            abLoadFailed.SetParent(transform);
            GameObject loader = new GameObject("Loader");
            loader.AddComponent<AssetBundleLoader>();
            loader.transform.SetParent(transform);
            loaderPool = new SimplePool(loader)
            {
                OnCollectOne = CollectLoader,
                OnGetOne = GetLoader
            };
        }

        /// <summary>
        /// 初始化
        /// </summary>
        /// <param name="pathPrefix">路径前缀</param>
        public void Init()
        {
            InvokeRepeating("UpdateAssetBundles", 1, 1);
        }

        public void Dispose()
        {
            //CancelInvoke("UpdateAssetBundles");
            //var bundleList = ListPool<AssetBundleLoader>.Get();
            //bundleList.Clear();
            //ListPool<AssetBundleLoader>.Release(bundleList);
        }

        /// <summary>
        /// 获取loader
        /// </summary>
        /// <param name="gameObj"></param>
        private void GetLoader(GameObject gameObj) {
            gameObj.transform.SetParent(ab);
        }

        /// <summary>
        /// 回收loader
        /// </summary>
        /// <param name="gameObj"></param>
        private void CollectLoader(GameObject gameObj) {
            gameObj.transform.SetParent(abRelease);
        }

        /// <summary>
        /// 清理失败列表
        /// </summary>
        public void ClearFailedMap() {
            List<AssetBundleLoader> bundleList = ListPool<AssetBundleLoader>.Get();
            bundleList.AddRange(failedMap.Values);
            for (int i = 0; i < bundleList.Count; i++) {
                bundleList[i].UnLoad(true);
                loaderPool.CollectOne(bundleList[i].gameObject);
            }
            ListPool<AssetBundleLoader>.Release(bundleList);
            failedMap.Clear();
        }

        /// <summary>
        /// 刷新AB文件
        /// </summary>
        private void UpdateAssetBundles()
        {
            AssetBundleLoader loader = null;
            List<AssetBundleLoader> bundleList = ListPool<AssetBundleLoader>.Get();
            bundleList.AddRange(bundleMap.Values);
            for (int i = 0; i < bundleList.Count; i++)
            {
                loader = bundleList[i];
                if (!loader.IsLoadFinish || loader.IsGlobal)continue;
                if (loader.IsFree) {
                    loader.LifeTime--;
                    if (loader.LifeTime <= 0)
                    {
                        if (!unLoadList.Contains(loader)) unLoadList.Add(loader);
                    }
                }
            }
            ListPool<AssetBundleLoader>.Release(bundleList);
        }

        /// <summary>
        /// 将卸载工作放到每一帧
        /// </summary>
        private void Update()
        {
            UnLoadAssetBundle();
        }

        /// <summary>
        /// 卸载AB文件
        /// </summary>
        private void UnLoadAssetBundle() {
            if (unLoadList.Count == 0) return;
            AssetBundleLoader loader = unLoadList[0];
            unLoadList.RemoveAt(0);
            if (loader.IsFree && loader.LifeTime <= 0)
            {
                UnLoadAssetBundle(loader.Path, true);
            }
            else
            {
                UnLoadAssetBundle();
            }
        }

        /// <summary>
        /// 同步加载AB文件
        /// </summary>
        /// <param name="path"></param>
        /// <returns></returns>
        public AssetBundleLoader LoadAssetBundle(string path,ResourcePathConfig manifest)
        {
            path = path.ToLower();
            AssetBundleLoader loader = null;
            if (failedMap.TryGetValue(path, out loader)) {
                return loader;
            }
            // Debug.Log("LoadAssetBundle-dependences:"+path);
            path = ResConfig.Convert2CombineName(path);

            if (!bundleMap.TryGetValue(path, out loader))
            {
                loader = GetLoader(path);
                Debug.Log("LoadAssetBundle-dependences loader:"+loader.FullPath);

                if (!string.IsNullOrEmpty(loader.FullPath))
                {
                    bundleMap.Add(path, loader);
                    var depPath=ResConfig.Convert2PathName(path);
                    string[] dependences = manifest.GetAllDependencies(depPath);
                    Debug.Log("LoadAssetBundle-dependences path:"+path+"--depPath:"+depPath+"-dependences:"+dependences.Length);
                    loader.LoadAssetBundle();
                    AssetBundleLoader tmpLoader = null;
                    Debug.Log("LoadAssetBundle:"+path+"---dependences:"+dependences.Length);
                    for (int i = 0; i < dependences.Length; i++)
                    {
                        var depConvertPath =ResConfig.Convert2CombineName(dependences[i]);
                        Debug.Log("LoadAssetBundle-dependences:"+depConvertPath);
                        tmpLoader = LoadAssetBundle(depConvertPath, manifest);
                        tmpLoader.AddRefBundle(loader);
                        loader.AddDependence(tmpLoader);
                    }
                }
                else {
                    failedMap.Add(path, loader);
                    loader.LoadFailed();
                    loader.transform.SetParent(abLoadFailed);
                }
            }
            loader.LifeTime = 5;
            return loader;
        }

        /// <summary>
        /// 异步加载AB文件
        /// </summary>
        /// <param name="path"></param>
        /// <param name="action"></param>
        public AssetBundleLoader LoadAssetBundleAsyn(string path,UnityAction<AssetBundleLoader> action, ResourcePathConfig manifest)
        {
            path = path.ToLower();
            AssetBundleLoader loader = null;
            //如果已经加载失败了，就不加载了
            if (failedMap.TryGetValue(path, out loader))
            {
                action(loader);
                return loader;
            }
            path = ResConfig.Convert2CombineName(path);

            if (!bundleMap.TryGetValue(path, out loader))
            {
                loader = GetLoader(path);
                if (action != null)
                {
                    loader.AddListener(action);
                }
                if (!string.IsNullOrEmpty(loader.FullPath))
                {
                    bundleMap.Add(path, loader);
                    var depPath=ResConfig.Convert2PathName(path);

                    string[] dependences = manifest.GetAllDependencies(depPath);
                    StartCoroutine(LoadAsssetBundleAsyn(loader, dependences, manifest));
                }
                else {
                    //如果加载路径为空，就不加载了
                    failedMap.Add(path, loader);
                    loader.LoadFailed();
                    return loader;
                }
            }
            else {
                if (action != null && loader.IsLoadFinish)
                {
                    action(loader);
                }
                else {
                    loader.AddListener(action);
                }
            }
            loader.LifeTime = 5;
            return loader;
        }

        /// <summary>
        /// 开启协程加载AB文件
        /// </summary>
        /// <param name="loader"></param>
        /// <returns></returns>
        private IEnumerator LoadAsssetBundleAsyn(AssetBundleLoader loader,string[] dependences, ResourcePathConfig manifest)
        {
            List<AssetBundleLoader> list = ListPool<AssetBundleLoader>.Get();
            string dependence = string.Empty;
            AssetBundleLoader dependenceLoader = null;
            for (int i = 0; i < dependences.Length; i++)
            {
                dependence = dependences[i];
                var depConvertPath =ResConfig.Convert2CombineName(dependences[i]);

                dependenceLoader = LoadAssetBundleAsyn(depConvertPath, null, manifest);
                //添加引用
                dependenceLoader.AddRefBundle(loader);
                //添加依赖
                loader.AddDependence(dependenceLoader);
                list.Add(dependenceLoader);
            }
            //先加载依赖项
            while (list.Count > 0)
            {
                if (list[0].IsLoadFinish)
                {
                    list.RemoveAt(0);
                    continue;
                }
                yield return 1;
            }
            ListPool<AssetBundleLoader>.Release(list);
            //如果等待过程中,没有被同步加载,加载自己
            if (!loader.IsLoadFinish)
            {
                yield return loader.LoadAssetBundleAsyn();
            }
        }

        /// <summary>
        /// 获取Loader
        /// </summary>
        /// <param name="fullPath"></param>
        /// <param name="dependences"></param>
        /// <returns></returns>
        private AssetBundleLoader GetLoader(string path)
        {
			string fullPath = PathHelper.GetFullPath(path);
            AssetBundleLoader loader = loaderPool.GetOne<AssetBundleLoader>();
            loader.name = path;
            loader.Init(path, fullPath);
            return loader;
        }


        /// <summary>
        /// 卸载掉不用的AB包,忽略掉生命周期，直接卸载
        /// </summary>
        public void UnLoadUnUseAssetBundles() {
            AssetBundleLoader loader = null;
            List<AssetBundleLoader> bundleList = ListPool<AssetBundleLoader>.Get();
            bundleList.AddRange(bundleMap.Values);
            for (int i = 0; i < bundleList.Count; i++) {
                loader = bundleList[i];
                if (!loader.IsLoadFinish || loader.IsGlobal) continue;
                if (loader.IsFree) {
                    loader.LifeTime = 0;
                    unLoadList.Add(loader);
                }
            }
            ListPool<AssetBundleLoader>.Release(bundleList);
        }

        /// <summary>
        /// 强制卸载所有AB包
        /// </summary>
        public void UnLoadAll() {
            StopAllCoroutines();
            AssetBundleLoader loader = null;
            List<AssetBundleLoader> bundleList = ListPool<AssetBundleLoader>.Get();
            bundleList.AddRange(bundleMap.Values);
            for (int i = 0; i < bundleList.Count; i++)
            {
                loader = bundleList[i];
                UnLoadAssetBundle(loader.Path, true);
            }
            ListPool<AssetBundleLoader>.Release(bundleList);
            unLoadList.Clear();
        }


        /// <summary>
        /// 卸载AB文件
        /// </summary>
        /// <param name="path"></param>
        public void UnLoadAssetBundle(string path,bool isForce)
        {
            AssetBundleLoader loader = null;
            if (bundleMap.TryGetValue(path, out loader))
            {
                bundleMap.Remove(path);
                loader.UnLoad(isForce);
                loaderPool.CollectOne(loader.gameObject);
            }
        }
    }
}

