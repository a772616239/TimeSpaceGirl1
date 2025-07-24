using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using GameCore;
using System;
using Object = UnityEngine.Object;
using GameLogic;

namespace ResMgr {
#if UNITY_EDITOR
    /// <summary>
    /// 编辑器下资源加载
    /// </summary>
    public class EditorResLoader : ResLoader
    {
        class EditorResData {
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
            /// 加载成功
            /// </summary>
            /// <param name="asset"></param>
            public void LoadSuccess(Object asset)
            {
                this.Asset = asset;
                this.IsFinish = true;
                OnLoadFinish.Invoke();
                OnLoadFinish.RemoveAllListeners();
            }

            /// <summary>
            /// 加载失败
            /// </summary>
            /// <param name="loader"></param>
            public void LoadFailed()
            {
                this.IsFinish = true;
                OnLoadFinish.Invoke();
                OnLoadFinish.RemoveAllListeners();
            }

            /// <summary>
            /// 卸载
            /// </summary>
            public void UnLoad()
            {
                if (Asset != null)
                {
                    if (Asset is GameObject)
                        return;
                    Resources.UnloadAsset(Asset);
                }
            }

            /// <summary>
            /// 回收
            /// </summary>
            public void Release()
            {
                RefCount = 0;
                Asset = null;
                Name = string.Empty;
                IsFinish = false;
                OnLoadFinish.RemoveAllListeners();
            }
        }
        /// <summary>
        /// 对象池
        /// </summary>
        static GameCore.ObjectPool<EditorResData> resDataPool = new GameCore.ObjectPool<EditorResData>(null, (resdata) => resdata.Release());
        /// <summary>
        /// 当前资源列表
        /// </summary>
        Dictionary<string, EditorResData> resMap = new Dictionary<string, EditorResData>();
        /// <summary>
        /// 加载失败列表
        /// </summary>
        Dictionary<string, EditorResData> resFailedMap = new Dictionary<string, EditorResData>();
        /// <summary>
        /// 待加载列表
        /// </summary>
        List<Action> loadList = new List<Action>();

        public override void Init()
        {
            ResPathConfig = LoadAssetEditor<ResourcePathConfig>(string.Format("{0}/ResConfigs/ResourcePathConfig.asset", AppConst.GameResPath));
        }

        public override void Update()
        {
            if (loadList.Count == 0) return;
            //模拟异步加载，把待加载的资源列表随机分配到之后的几帧执行加载操作
            int i = UnityEngine.Random.Range(0, loadList.Count);
            Action action = loadList[i];
            loadList.Remove(action);
            action.Invoke();
        }

        /// <summary>
        /// 同步加载资源
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="name"></param>
        /// <returns></returns>
        public override T LoadAsset<T>(string name)
        {
            T asset = null;
            EditorResData resData = null;

            if (resMap.TryGetValue(name, out resData))
            {
                resData.RefCount++;
                asset = resData.Asset as T;
            }
            else {
                string path = ResPathConfig.GetPath(name);
                if (string.IsNullOrEmpty(path))
                {
                    if (BaseLogger.isDebug) BaseLogger.LogErrorFormat("没有找到资源{0}！", name);
                    return null;
                }
                // Debug.Log("LoadAsset Editor:"+"-path:"+path);

                resData = resDataPool.Get();
                resData.Name = name;
                resData.RefCount++;
                resMap.Add(name, resData);
                asset = LoadAssetEditor<T>(path);
                resData.LoadSuccess(asset);
            }
            return asset;
        }

        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="name"></param>
        /// <param name="action"></param>
        public override void LoadAssetAsync<T>(string name, UnityAction<string, T> action)
        {
            EditorResData resData = null;
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
            else {
                string path = ResPathConfig.GetPath(name);
                if (string.IsNullOrEmpty(path))
                {
                    if (BaseLogger.isDebug) BaseLogger.LogErrorFormat("没有找到资源{0}！", name);
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
                loadList.Add(()=> {
                    T asset = LoadAssetEditor<T>(path);
                    resData.LoadSuccess(asset);
                });
            }
        }

        /// <summary>
        /// 卸载资源
        /// </summary>
        /// <param name="name"></param>
        public override void UnLoadAsset(string name)
        {
            EditorResData resData = null;
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
        /// 是否拥有某个资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <returns></returns>
        public override bool HaveAsset(string assetName)
        {
            return !string.IsNullOrEmpty(ResPathConfig.GetPath(assetName));
        }

        /// <summary>
        /// 卸载未使用资源
        /// </summary>
        public override void UnLoadUnUseAsset()
        {
            List<EditorResData> list = ListPool<EditorResData>.Get();
            list.AddRange(resMap.Values);
            EditorResData resData = null;
            for (int i = 0; i < list.Count; i++)
            {
                resData = list[i];
                if (!resData.IsFinish) continue;
                if (resData.RefCount != 0) continue;
                resMap.Remove(resData.Name);
                resData.UnLoad();
                resDataPool.Release(resData);
            }
            ListPool<EditorResData>.Release(list);
            resFailedMap.Clear();
            AssetBundleManager.Instance.UnLoadUnUseAssetBundles();
        }

        /// <summary>
        /// 清除加载失败列表
        /// </summary>
        public override void ClearFailedMap()
        {
            List<EditorResData> list = ListPool<EditorResData>.Get();
            list.AddRange(resFailedMap.Values);
            for (int i = 0; i < list.Count; i++)
            {
                resDataPool.Release(list[i]);
            }
            ListPool<EditorResData>.Release(list);
            resFailedMap.Clear();
            AssetBundleManager.Instance.ClearFailedMap();
        }

        /// <summary>
        /// 卸载所有资源
        /// </summary>
        public override void UnLoadAll()
        {
            List<EditorResData> list = ListPool<EditorResData>.Get();
            list.AddRange(resMap.Values);
            EditorResData resData = null;
            for (int i = 0; i < list.Count; i++)
            {
                resData = list[i];
                resMap.Remove(resData.Name);
                resData.UnLoad();
                resDataPool.Release(resData);
            }
            ListPool<EditorResData>.Release(list);
            resFailedMap.Clear();
            AssetBundleManager.Instance.UnLoadUnUseAssetBundles();
        }

        T LoadAssetEditor<T>(string path) where T : Object
        {
            T t = null;
            t = UnityEditor.AssetDatabase.LoadAssetAtPath<T>(path);
            return t;
        }
    }
#endif
}
