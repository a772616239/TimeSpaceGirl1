using UnityEngine;
using System;
using System.Collections.Generic;
using Object = UnityEngine.Object;
using GameCore;
using UnityEngine.Events;
namespace ResMgr 
{
    /// <summary>
    /// 资源加载器
    /// </summary>
    public class ResourcesLoader
    {
        /// <summary>
        /// 资源加载器
        /// </summary>
        ResLoader resLoader;

        /// <summary>
        /// 是否为发布版本
        /// </summary>
        bool isReleaseVer;

        public ResourcesLoader(bool isReleaseVer) {
            this.isReleaseVer = isReleaseVer;
            InitResLoader();
        }

        /// <summary>
        /// 初始化资源路径配置
        /// </summary>
        public void InitResLoader() {
            if (isReleaseVer)
            {
                resLoader = new RuntimeResLoader();
            }
            else {
#if UNITY_EDITOR
                resLoader = new EditorResLoader();
#endif
            }
            resLoader.Init();
        }


        /// <summary>
        /// 清理掉不用的资源和资源包
        /// </summary>
        public void UnLoadUnUseAssetAndAssetBundle() {
            resLoader.UnLoadUnUseAsset();
        }


        /// <summary>
        /// 清理加载失败列表
        /// </summary>
        public void ClearFailedMap() {
            resLoader.ClearFailedMap();
        }

        /// <summary>
        /// 同步加载asset资源
        /// </summary>
        public T LoadAsset<T>(string assetName) where T : Object
        {
            return resLoader.LoadAsset<T>(assetName);
        }

        /// <summary>
        /// 同步加载asset资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <returns></returns>
        public Object LoadAsset(string assetName) {
            return resLoader.LoadAsset<Object>(assetName);
        }

        /// <summary>
        /// 异步加载asset方法
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="assetName"></param>
        /// <param name="callBack"></param>
        public void LoadAssetAsync<T>(string assetName, UnityAction<string, T> callBack) where T : Object
        {
            resLoader.LoadAssetAsync<T>(assetName, callBack);
        }

        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <param name="callBack"></param>
        public void LoadAssetAsync(string assetName, UnityAction<string, Object> callBack) {
            resLoader.LoadAssetAsync<Object>(assetName, callBack);
        }


        /// <summary>
        /// 是否有某个资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <returns></returns>
        public bool HaveAsset(string assetName) {
            return resLoader.HaveAsset(assetName);
        }

        /// <summary>
        /// 卸载所有资源
        /// </summary>
        public void UnLoadAll() {
            resLoader.UnLoadAll();
        }
   

        /// <summary>
        /// 卸载指定资源
        /// </summary>
        /// <param name="assetName"></param>
        public void UnLoadAsset(string assetName)
        {
            resLoader.UnLoadAsset(assetName);
        }

        /// <summary>
        /// 清空管理器缓存的AssetObject
        /// </summary>
        public void ClearMemory()
        {
            UnLoadUnUseAssetAndAssetBundle();
        }

        public void Update()
        {
            resLoader.Update();
        }
    }
}