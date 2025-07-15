using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using GameCore;
using System;
using Object = UnityEngine.Object;
namespace ResMgr
{
    /// <summary>
    /// 资源加载器
    /// </summary>
    public abstract class ResLoader
    {
        /// <summary>
        /// 资源路径管理类
        /// </summary>
        protected ResourcePathConfig ResPathConfig;

        /// <summary>
        /// 初始化
        /// </summary>
        abstract public void Init();

        /// <summary>
        /// 加载资源
        /// </summary>
        /// <typeparam name="T">资源类型</typeparam>
        /// <param name="name">资源名</param>
        /// <returns></returns>
        abstract public T LoadAsset<T>(string name) where T : Object;

        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <typeparam name="T">资源类型</typeparam>
        /// <param name="name">资源名</param>
        /// <param name="action">资源回调</param>
        /// <returns></returns>
        abstract public void LoadAssetAsync<T>(string name, UnityAction<string, T> action) where T : Object;

        /// <summary>
        /// 是否拥有某个资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <returns></returns>
        abstract public bool HaveAsset(string assetName);

        /// <summary>
        /// 卸载资源
        /// </summary>
        abstract public void UnLoadAsset(string name);

        /// <summary>
        /// 清理失败列表
        /// </summary>
        abstract public void ClearFailedMap();

        /// <summary>
        /// 卸载不使用的资源
        /// </summary>
        abstract public void UnLoadUnUseAsset();

        /// <summary>
        /// 卸载所有的资源
        /// </summary>
        abstract public void UnLoadAll();

        /// <summary>
        /// 更新
        /// </summary>
        abstract public void Update();
    }
}
