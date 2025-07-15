using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using GameCore;
namespace ResMgr {

    /// <summary>
    /// 资源管理器
    /// </summary>
    public class ResourcesManager : UnitySingleton<ResourcesManager>
    {
        /// 资源加载器
        /// </summary>
        ResourcesLoader resLoader;

        /// <summary>
        /// 是否为发布版本
        /// </summary>
        bool isReleaseVer;

		/// <summary>
		/// 初始化
		/// </summary>
		/// <param name="isReleaseVer">If set to <c>true</c> is release ver.</param>
		public void Init(bool isReleaseVer) {
            this.isReleaseVer = isReleaseVer;
			if (isReleaseVer) {
				AssetBundleManager.Instance.Init ();
			}
            resLoader = new ResourcesLoader(isReleaseVer);
        }

        /// <summary>
        /// 同步加载资源
        /// </summary>
        /// <param name="assetName">资源名字</param>
        /// <returns></returns>
        public Object LoadAsset(string assetName) {
            return resLoader.LoadAsset(assetName);
        }


        /// <summary>
        /// 同步加载资源
        /// </summary>
        /// <param name="assetName">资源名字</param>
        /// <returns></returns>
        public T LoadAsset<T>(string assetName) where T :Object {
            return resLoader.LoadAsset<T>(assetName);
        }


        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <param name="assetName">资源名字</param>
        /// <param name="action">资源加载回调</param>
        public void LoadAssetAsync(string assetName,UnityAction<string,Object> action) {
            resLoader.LoadAssetAsync(assetName, action);
        }

        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <typeparam name="T">资源类型</typeparam>
        /// <param name="assetName">资源名</param>
        /// <param name="action">加载完成回调</param>
        public void LoadAssetAsync<T>(string assetName, UnityAction<string, T> action) where T : Object {
            resLoader.LoadAssetAsync<T>(assetName,action);
        }

        /// <summary>
        /// 是否拥有某个资源
        /// </summary>
        /// <param name="assetName">资源名</param>
        /// <returns></returns>
        public bool HaveAsset(string assetName) {
            return resLoader.HaveAsset(assetName);
        }


        /// <summary>
        /// 卸载资源
        /// </summary>
        /// <param name="assetName"></param>
        public void UnLoadAsset(string assetName) {
            resLoader.UnLoadAsset(assetName);
        }

        /// <summary>
        /// 卸载未使用的资源和AB包
        /// </summary>
        public void UnLoadUnUseAssetAndAssetBundle() {
            resLoader.UnLoadUnUseAssetAndAssetBundle();
        }

        /// <summary>
        /// 卸载所有资源
        /// </summary>
        public void UnLoadAll() {
            resLoader.UnLoadAll();
            AssetBundleManager.Instance.UnLoadAll();
        }

#if UNITY_EDITOR
        private void Update()
        {
            resLoader.Update();
        }
#endif
    }
}
