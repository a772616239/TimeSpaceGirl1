using UnityEngine;
using System;
using System.Net;
using System.IO;
using System.Text;
using System.Threading;
using System.Collections;
using System.Collections.Generic;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Text.RegularExpressions;
using GameCore;

namespace ResUpdate
{
    /// <summary>
    /// 下载进度
    /// </summary>
    public class DownLoadProgress 
    {
        /// <summary>
        /// 已经下载的大小：Byte
        /// </summary>
        public long Size
        {
            get;
            private set;
        }
        /// <summary>
        /// 已经下载的大小：KB
        /// </summary>
        public float SizeKB
        {
            get
            {
                return 1f * Size / 1024;
            }
        }

        /// <summary>
        /// 已经下载的大小：MB
        /// </summary>
        public float SizeMB {
            get {
                return 1f * Size / 1024/1024;
            }
        }

        /// <summary>
        /// 需要下载的大小:Byte
        /// </summary>
        public long TotalSize
        {
            get;
            private set;
        }

        /// <summary>
        /// 需要下载的大小:KB
        /// </summary>
        public float TotalSizeKB {
            get {
                return 1f * TotalSize / 1024;
            }
        }


        /// <summary>
        /// 需要下载的大小:MB
        /// </summary>
        public float TotalSizeMB
        {
            get {
                return 1f * TotalSize / 1024/1024;
            }
        }

        /// <summary>
        /// 进度
        /// </summary>
        public float Progress {
            get {
                if (TotalSize == 0) return 1f;
                return Mathf.Clamp01(1f * Size / TotalSize);
            } 
        }
        /// <summary>
        /// 下载速度
        /// </summary>
        public float LoadSpeed
        {
            get;
            private set;
        }

        /// <summary>
        /// 更新进度
        /// </summary>
        /// <param name="size">已经下载的大小</param>
        /// <param name="totalSize">需要下载的大小</param>
        internal void UpdateProgress(long size, long totalSize,float speed) 
        {
            this.Size = size;
            this.TotalSize = totalSize;
            this.LoadSpeed = speed;
        }

        /// <summary>
        /// 重置
        /// </summary>
        internal void Reset() {
            this.Size = 0;
            this.TotalSize = 0;
        }
    }

    /// <summary>
    /// 资源下载器
    /// </summary>
    public class ResourceDownloadManager : UnitySingleton<ResourceDownloadManager>
    {
        /// <summary>
        /// 下载更新间隔
        /// </summary>
        const float DOWNLOAD_UPDATE_INTERVAL = 0.05f;
        /// <summary>
        /// 下载线程数量
        /// </summary>
        const int MAX_DOWNLOAD_THREADS_COUNT = 3;
        /// <summary>
        /// 线程下载器池
        /// </summary>
        ObjectPool<ThreadDownloader> downloadRequestPool = new ObjectPool<ThreadDownloader>(l=>l.Init(), l => l.Reset());
        /// <summary>
        /// 线程下载器
        /// </summary>
        List<ThreadDownloader> downloadRequestList = new List<ThreadDownloader>();
        /// <summary>
        /// 下载完成的数据
        /// </summary>
        Dictionary<string, bool> finishedRequest = new Dictionary<string, bool>();
        /// <summary>
        /// 当前正在下载的数量
        /// </summary>
        int curDownloadingCount;
        /// <summary>
        /// 当前网络状态
        /// </summary>
        NetworkReachability curNetworkStatus = NetworkReachability.NotReachable;

        /// <summary>
        /// 下载URL
        /// </summary>
        public string downloadURL
        {
            get;
            set;
        }

        /// <summary>
        /// 是否允许从数据流量下载
        /// </summary>
        public bool allowDowloadFromWWAN
        {
            get;
            set;
        }

        void Update() 
        {
            UpdateDownLoadList();
        }

        /// <summary>
        /// 更新下载列表
        /// </summary>
        void UpdateDownLoadList()
        {
            if (downloadRequestList.Count == 0)return;
            UpdateCurNetworkStatus();
            ProcessDownloadList();
        }

        /// <summary>
        /// 处理下载列表
        /// </summary>
        void ProcessDownloadList()
        {
            var count = Mathf.Min(MAX_DOWNLOAD_THREADS_COUNT, downloadRequestList.Count);
            var i = curDownloadingCount;
            for (; i < count; ++i)
            {
                downloadRequestList[i].Start();
                curDownloadingCount++;
            }
            for (i = 0; i < curDownloadingCount; )
            {
                var downloadRequest = downloadRequestList[i];
                
                if (downloadRequest.downLoadState == DownloadState.Finished)
                {
                    finishedRequest.Add(downloadRequest.fileName, downloadRequest.isSuccess);
                    downloadRequestList.RemoveAt(i);
                    curDownloadingCount--;
                    downloadRequest.UpdateCallBack();
                    downloadRequest.FinishCallback();
                    downloadRequestPool.Release(downloadRequest);
                }
                else
                {
                    downloadRequest.UpdateCallBack();
                    ++i;
                }
            }
        }

        /// <summary>
        /// 校验结果
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="certificate"></param>
        /// <param name="chain"></param>
        /// <param name="errors"></param>
        /// <returns></returns>
        public static bool CheckValidationResult(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors)
        {
            return true;
        }

        /// <summary>
        /// 开始下载文件
        /// </summary>
        /// <param name="file">文件名</param>
        /// <param name="url">下载地址</param>
        /// <param name="saveDirectory">保存的文件夹</param>
        /// <param name="size">文件大小</param>
        /// <param name="crc">文件CRC</param>
        /// <param name="finishAction">完成回调</param>
        /// <param name="postContent">请求参数</param>
        public void StartDownload(string file, string url, string saveDirectory, long size, string crc,Action<string,DownLoadProgress> progressAction=null , Action<string,bool> finishAction = null, string postContent = "")
        {
            if (FindInDownLoadList(file) != -1)
            {
                return;
            }

            if (finishedRequest.ContainsKey(file))
            {
                if (BaseLogger.isDebug) Debug.Log(string.Format("Re download file: {0}.", file));
                finishedRequest.Remove(file);
            }

            var downloadRequest = downloadRequestPool.Get();
            var stringBuilder = new StringBuilder();
            var savePath = stringBuilder.Append(UpdateConfigs.PersistentDataPath).Append(saveDirectory).Append(file).ToString();
            downloadRequest.Init(file, url, savePath, size, crc,progressAction, finishAction, postContent);
            downloadRequestList.Add(downloadRequest);
        }

        /// <summary>
        /// 开始下载文件
        /// </summary>
        /// <param name="file"></param>
        /// <param name="url"></param>
        /// <param name="saveDirectory"></param>
        /// <param name="finishAction"></param>
        /// <param name="postContent"></param>
        public void StartDownload(string file, string url, string saveDirectory, Action<string, DownLoadProgress> progressAction = null, Action<string,bool> finishAction = null, string postContent = "")
        {
            if (FindInDownLoadList(file) != -1)
            {
                return;
            }

            if (finishedRequest.ContainsKey(file))
            {
                if (BaseLogger.isDebug) Debug.Log(string.Format("Re download file: {0}.", file));
                finishedRequest.Remove(file);
            }

            var downloadRequest = downloadRequestPool.Get();
            var stringBuilder = new StringBuilder();
            var savePath = stringBuilder.Append(UpdateConfigs.PersistentDataPath).Append(saveDirectory).Append(file).ToString();
            downloadRequest.Init(file, url, savePath,progressAction,finishAction, postContent);
            downloadRequestList.Add(downloadRequest);
        }

        /// <summary>
        /// 是否下载完成
        /// </summary>
        /// <param name="file">文件名</param>
        /// <returns></returns>
        public bool IsFinishDownload(string file)
        {
            return finishedRequest.ContainsKey(file);
        }

        /// <summary>
        /// 是否下载成功
        /// </summary>
        /// <param name="file">文件名</param>
        /// <returns></returns>
        public bool IsDownloadSuccess(string file)
        {
            bool isSuccess = false;
            finishedRequest.TryGetValue(file, out isSuccess);
            return isSuccess;
        }

        /// <summary>
        /// 是否在下载中
        /// </summary>
        /// <param name="file">文件名</param>
        /// <returns></returns>
        public int FindInDownLoadList(string file)
        {
            var count = downloadRequestList.Count;
            for (var i = 0; i < count; ++i)
            {
                if (downloadRequestList[i].fileName == file)
                {
                    return i;
                }
            }

            return -1;
        }

        /// <summary>
        /// 网络是否可用
        /// </summary>
        public bool IsNetworkReachable
        {
            get
            {
                return ((allowDowloadFromWWAN && curNetworkStatus == UnityEngine.NetworkReachability.ReachableViaCarrierDataNetwork)
                        || curNetworkStatus == UnityEngine.NetworkReachability.ReachableViaLocalAreaNetwork);
            }
        }

        /// <summary>
        /// 更新网络状态
        /// </summary>
        void UpdateCurNetworkStatus()
        {
            NetworkReachability state = Application.internetReachability;
            if (curNetworkStatus != state)
            {
                curNetworkStatus = state;
                if (BaseLogger.isDebug) Debug.Log(string.Format("curNetworkStatus changed:{0}", curNetworkStatus));

                if (!IsNetworkReachable)
                {
                    ClearDownloadRequestList();
                }
            }
        }


        /// <summary>
        /// 清理下载列表
        /// </summary>
        void ClearDownloadRequestList()
        {
            var count = downloadRequestList.Count;
            for (var i = curDownloadingCount; i < count; i++)
            {
                var downloadRequest = downloadRequestList[i];
                downloadRequest.FinishCallback();
                downloadRequestPool.Release(downloadRequest);
            }
            downloadRequestList.RemoveRange(curDownloadingCount, count - curDownloadingCount);
            if (BaseLogger.isDebug) BaseLogger.Log("Remove all waiting download file");
        }
    }
}
