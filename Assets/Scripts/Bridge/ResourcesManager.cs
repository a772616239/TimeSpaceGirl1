using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using LuaInterface;
using GameCore;
namespace GameLogic {
    /// <summary>
    /// 资源管理器
    /// </summary>
    public class ResourcesManager : Singleton<ResourcesManager>
    {
        public bool isLoading;
        ResMgr.ResourcesManager resMgr = ResMgr.ResourcesManager.Instance;

        /// <summary>
        /// 初始化
        /// </summary>
        public void Initialize(bool isReleaseVer)
        {
            //资源路径配置
            ResMgr.ResConfig.PersistentDataPath = AppConst.PersistentDataPath;
            ResMgr.ResConfig.StreamPath = AppConst.StreamPath;
            resMgr.Init(isReleaseVer);
			Debug.LogFormat("================>ResourcesManager.Initialize,isReleaseVer:{0}",isReleaseVer);
        }

        /// <summary>
        /// 同步加载资源
        /// </summary>
        /// <typeparam name="T">资源类型</typeparam>
        /// <param name="assetName">资源名</param>
        /// <returns></returns>
        [NoToLua]
        public T LoadAsset<T>(string assetName) where T : Object
        {
            if (assetName.ToLower().Contains("x1")&&!assetName.StartsWith("cn2-"))
            {
                assetName = "cn2-" + assetName;
            }
            return resMgr.LoadAsset<T>(assetName);
        }

        /// <summary>
        /// 同步加载资源
        /// </summary>
        /// <param name="assetName">资源名</param>
        /// <returns></returns>
        public Object LoadAsset(string assetName)
        {
            if (assetName.ToLower().Contains("x1")&&!assetName.StartsWith("cn2-"))
            {
                assetName = "cn2-" + assetName;
            }
            return resMgr.LoadAsset<Object>(assetName);
        }

        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="assetName"></param>
        /// <param name="action"></param>
        [NoToLua]
        public void LoadAssetAsync<T>(string assetName, UnityAction<string, T> action) where T : Object
        {
            resMgr.LoadAssetAsync<T>(assetName, action);
        }

        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <param name="action"></param>
        [NoToLua]
        public void LoadAssetAsync(string assetName, UnityAction<string, Object> action)
        {
            resMgr.LoadAssetAsync<Object>(assetName, action);
        }


        /// <summary>
        /// Lua异步加载资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <param name="luaFunction"></param>
        public void LoadAssetAsync(string assetName, LuaFunction luaFunction)
        {
            resMgr.LoadAssetAsync<Object>(assetName, (name, obj) =>
            {
                if (luaFunction != null)
                {
                    luaFunction.Call(name, obj);
                }
            });
        }

        /// <summary>
        /// 卸载资源
        /// </summary>
        /// <param name="assetName"></param>
        public void UnLoadAsset(string assetName)
        {
            resMgr.UnLoadAsset(assetName);
        }

        /// <summary>
        /// 卸载游戏
        /// </summary>
        public void UnLoadGame()
        {
            resMgr.UnLoadAll();
        }

        /// <summary>
        /// 卸载没有使用的资源和AssetBundle
        /// </summary>
        public void UnLoadUnUseAssetAndAssetBundle()
        {
            resMgr.UnLoadUnUseAssetAndAssetBundle();
        }

        /// <summary>
        /// 是否拥有某个资源
        /// </summary>
        /// <param name="asset">资源名</param>
        /// <returns></returns>
        public bool HaveAsset(string asset)
        {
            return resMgr.HaveAsset(asset);
        }

        /// <summary>
        /// 卸载掉所有资源（平台和游戏）
        /// </summary>
        public void UnLoadAll() {
            resMgr.UnLoadAll();
        }


        public void Reset()
        {
        }

    }

}
