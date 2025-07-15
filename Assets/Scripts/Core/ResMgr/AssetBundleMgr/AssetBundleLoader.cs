using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using Object = UnityEngine.Object;
using GameCore;
using System.IO;

namespace ResMgr
{
    /// <summary>
    /// AB文件加载状态
    /// </summary>
    public enum ABLoaderState
    {
        //等待中
        Wait,
        //加载中
        Loading,
        //加载成功
        Success,
        //加载失败
        Failed,
        //被卸载掉了
        Release
    }

    /// <summary>
    /// AB文件加载器
    /// </summary>
    public class AssetBundleLoader:MonoBehaviour
    {
        public class ABLoaderEvent : UnityEvent<AssetBundleLoader> { };

        /// <summary>
        /// 路径
        /// </summary>
        [SerializeField]
        protected string path;
        /// <summary>
        /// 用于加载的路径
        /// </summary>
        [SerializeField]
        protected string fullPath;
        /// <summary>
        /// AB文件
        /// </summary>
        protected AssetBundle assetBundle;
        /// <summary>
        /// 加载完成回调
        /// </summary>
        protected ABLoaderEvent onLoadFinish;
        /// <summary>
        /// 依赖
        /// </summary>
        [SerializeField]
        protected List<AssetBundleLoader> dependences;
        /// <summary>
        /// 引用AB包
        /// </summary> 
        [SerializeField]
        protected List<AssetBundleLoader> refBundles;
        /// <summary>
        /// 引用的资源
        /// </summary>
        [SerializeField]
        protected List<string> refResDatas;
        /// <summary>
        /// 是否加载完成
        /// </summary>
        protected bool isLoadFinish;
        /// <summary>
        /// 进度
        /// </summary>
        protected float progress;
        /// <summary>
        /// 加载状态
        /// </summary>
        [SerializeField]
        protected ABLoaderState abLoaderState = ABLoaderState.Wait;
        /// <summary>
        /// 优先级,值越大越优先加载
        /// </summary>
        [SerializeField]
        protected int priority;
        /// <summary>
        /// 是否为全局的
        /// </summary>
        [SerializeField]
        protected bool isGlobal;
        /// <summary>
        /// 生命周期剩余
        /// </summary>
        [SerializeField]
        protected int leftLife;

        /// <summary>
        /// ABLoader状态
        /// </summary>
        public ABLoaderState AbLoaderState
        {
            get
            {
                return abLoaderState;
            }
        }

        /// <summary>
        /// 是否加载完成
        /// </summary>
        public bool IsLoadFinish
        {
            get
            {
                return isLoadFinish;
            }
        }

        /// <summary>
        /// 完整的加载路径
        /// </summary>
        public string FullPath {
            get {
                return fullPath;
            }
        }

        /// <summary>
        /// 路径
        /// </summary>
        public string Path
        {
            get
            {
                return path;
            }
        }

        /// <summary>
        /// 是否为全局AB包，全局AB包不会被自动卸载
        /// </summary>
        public bool IsGlobal
        {
            get
            {
                return isGlobal;
            }

            set
            {
                isGlobal = value;
            }
        }

        /// <summary>
        /// 剩余生命周期
        /// </summary>
        public int LifeTime
        {
            get
            {
                return leftLife;
            }

            set
            {
                leftLife = value;
            }
        }

        public float Progress
        {
            get
            {
                return progress;
            }
        }

        private void Awake()
        {
            refBundles = ListPool<AssetBundleLoader>.Get();
            dependences = ListPool<AssetBundleLoader>.Get();
            refResDatas = new List<string>();
            onLoadFinish = new ABLoaderEvent();
        }

        /// <summary>
        /// 初始化
        /// </summary>
        /// <param name="path">加载路径</param>
        /// <param name="dependences">依赖</param>
        public void Init(string path, string fullPath)
        {
            this.path = path;
            this.fullPath = fullPath;
            this.abLoaderState = ABLoaderState.Wait;
        }

        /// <summary>
        /// 添加加载完成回调
        /// </summary>
        /// <param name="action"></param>
        public void AddListener(UnityAction<AssetBundleLoader> action)
        {
            if (action == null) return;
            this.onLoadFinish.AddListener(action);
        }

        /// <summary>
        /// 添加依赖项
        /// </summary>
        /// <param name="loader"></param>
        public void AddDependence(AssetBundleLoader loader) {
            dependences.Add(loader);
        }

        /// <summary>
        /// 添加AssetBundle对AssetBundle的引用
        /// </summary>
        /// <param name="bundleName"></param>
        public void AddRefBundle(AssetBundleLoader bundleName)
        {
            refBundles.Add(bundleName);
        }

        /// <summary>
        ///移除AssetBundle对AssetBundle的引用
        /// </summary>
        /// <param name="bundleName"></param>
        public void RemoveRefBundle(AssetBundleLoader bundleName)
        {
            refBundles.Remove(bundleName);
        }

        /// <summary>
        /// 添加资源对AssetBundle的引用
        /// </summary>
        /// <param name="resName"></param>
        public void AddRefResData(string resName) {
            refResDatas.Add(resName);
            if(BaseLogger.isDebug) BaseLogger.LogFormat("AddRefResData:{0}--path:->{1}--count:->>{2}", resName, path, refResDatas.Count);
        }

        /// <summary>
        /// 移除资源对AssetBundle的引用
        /// </summary>
        /// <param name="resName"></param>
        public void RemoveRefResData(string resName) {
            refResDatas.Remove(resName);
            if (BaseLogger.isDebug) BaseLogger.LogFormat("RemoveRefResData:{0}--path:->{1}--count:->{2}", resName, path, refResDatas.Count);
        }

        /// <summary>
        /// 是否可以被释放掉了
        /// </summary>
        public bool IsFree{
            get {
                return refResDatas.Count == 0 && refBundles.Count == 0;
            }
        }

        /// <summary>
        /// 加载资源
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="assetName"></param>
        /// <returns></returns>
        public T LoadAsset<T>(string assetName) where T : Object
        {
            if (BaseLogger.isDebug) BaseLogger.LogFormat("<color=#FFFF00>LoadAsset:{0}</color>", assetName);
            if (assetBundle != null)
            {
#if XNCS
                XNCSUtils.BeginSample("LoadAsset:{0}",path);
#endif
                T t = assetBundle.LoadAsset<T>(assetName);
#if XNCS
                XNCSUtils.EndSample();
#endif
                return t;
            }
            return null;
        }



        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <param name="assetName"></param>
        /// <param name="action"></param>
        public void LoadAssetAsyn<T>(string assetName, UnityAction<T> action) where T : Object
        {
            StartCoroutine(_LoadAssetAsyn<T>(assetName,action));
        }


        /// <summary>
        /// 异步加载资源
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="assetName"></param>
        /// <param name="action"></param>
        /// <returns></returns>
        private IEnumerator _LoadAssetAsyn<T>(string assetName,UnityAction<T> action) where T : Object
        {
            if (BaseLogger.isDebug) BaseLogger.LogFormat("<color=#FFFF00>LoadAssetAsyn:{0}</color>", assetName);
            if (assetBundle != null)
            {

                AssetBundleRequest request = assetBundle.LoadAssetAsync<T>(assetName);
                yield return request;
                if (request != null) {
                    action(request.asset as T);
                    yield break;
                }
            }
            action(null);
        }

        /// <summary>
        /// 加载所有资源
        /// </summary>
        public Object[] LoadAllAsset()
        {
            if (assetBundle != null)
            {
#if XNCS
                XNCSUtils.BeginSample("LoadAllAsset,Path ={0}",path);
#endif
                Object[] objs = assetBundle.LoadAllAssets();
#if XNCS
                XNCSUtils.EndSample();
#endif
                return objs;
            }
            return null;
        }

        /// <summary>
        /// 加载所有资源
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <returns></returns>
        public T[] LoadAllAsset<T>() where T : Object
        {
            if (assetBundle != null)
            {
#if XNCS
                XNCSUtils.BeginSample("LoadAllAsset<T>:{0}",path);
#endif
                T[] ts = assetBundle.LoadAllAssets<T>();
#if XNCS
                XNCSUtils.EndSample();
#endif
                return ts;
            }
            return null;
        }

        /// <summary>
        /// 加载AB文件
        /// </summary>
        virtual public bool LoadAssetBundle()
        {
            if (BaseLogger.isDebug) BaseLogger.LogFormat("<color=#00FF00>LoadAssetBundle:{0}</color>", path);
#if XNCS
            XNCSUtils.BeginSample("LoadAssetBundle:{0}",path);
#endif
            //assetBundle = AssetBundle.LoadFromMemory(XXTEA.Decrypt(File.ReadAllBytes(fullPath)));
            assetBundle = AssetBundle.LoadFromFile(fullPath, 0, GameLogic.AppConst.EncyptBytesLength);
#if XNCS
            XNCSUtils.EndSample();
#endif
            if (assetBundle != null)
            {
                LoadOver();
                return true;
            }
            else
            {
                if (BaseLogger.isDebug)
                    BaseLogger.LogError("同步加载失败:AssetBundle:" + path);
                if(fullPath.Contains(ResConfig.StreamPath))
                    XDebug.Log.error("StreamingAssets 路径资源丢失，请重新打包包内资源!");
                LoadFailed();
                return false;
            }

        }
        /// <summary>
        /// 异步加载AB文件
        /// </summary>
        /// <returns></returns>
        virtual public IEnumerator LoadAssetBundleAsyn()
        {
            if (BaseLogger.isDebug) BaseLogger.LogFormat("<color=#00FF00>LoadAssetBundleAsyn:{0}</color>", path);
            abLoaderState = ABLoaderState.Loading;
            AssetBundleCreateRequest request = AssetBundle.LoadFromFileAsync(fullPath, 0, GameLogic.AppConst.EncyptBytesLength);
            //AssetBundleCreateRequest request = AssetBundle.LoadFromMemoryAsync(XXTEA.Decrypt(File.ReadAllBytes(fullPath)));
            while (!request.isDone)
            {
                progress = request.progress;
                yield return null;
            }
            if (request.assetBundle != null)
            {
                assetBundle = request.assetBundle;
                LoadOver();
            }
            else
            {
                if (BaseLogger.isDebug) BaseLogger.LogErrorFormat("异步加载AB失败!,AssetBundle:", path);
                LoadFailed();
            }
        }

        /// <summary>
        /// 加载完成
        /// </summary>
        protected void LoadOver()
        {
            abLoaderState = ABLoaderState.Success;
            isLoadFinish = true;
            progress = 1f;

            onLoadFinish.Invoke(this);
            onLoadFinish.RemoveAllListeners();
        }


        /// <summary>
        /// 加载失败
        /// </summary>
        public void LoadFailed()
        {
            abLoaderState = ABLoaderState.Failed;
            isLoadFinish = true;
            progress = 1f;
            onLoadFinish.Invoke(this);
            onLoadFinish.RemoveAllListeners();
        }


        /// <summary>
        /// 卸载AB文件
        /// </summary>
        public void UnLoad(bool isForce)
        {
            if (BaseLogger.isDebug) BaseLogger.LogFormat("<color=#FF0000>UnLoadAssetBundle:{0}</color>", path);
            //移除引用
            for (int i = 0; i < dependences.Count; i++) {
                dependences[i].RemoveRefBundle(this);
            }
            if (assetBundle != null) {
#if XNCS
                XNCSUtils.BeginSample("UnLoadAssetBundle:{0},IsForce:{1}",path,isForce);
#endif
                assetBundle.Unload(isForce);
#if XNCS
                XNCSUtils.EndSample();
#endif
            }
            Release();
        }

        /// <summary>
        /// 清理方法，回收的时候调用
        /// </summary>
        public void Release()
        {
            StopAllCoroutines();
            priority = 0;
            progress = 0f;
            isLoadFinish = false;
            onLoadFinish.RemoveAllListeners();
            assetBundle = null;
            abLoaderState = ABLoaderState.Release;
            dependences.Clear();
            refBundles.Clear();
            isGlobal = false;
        }
    }

}
