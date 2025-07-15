using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using GameCore;
using System.IO;
using GameLogic;
using UnityEngine.Networking;

namespace ResUpdate
{
    public class VersionPar
    {
        public string version { get; set; }
        public string sdkLodingUrl { get; set; }
    }
    
    /// <summary>
    /// 资源更新进度
    /// </summary>
    public class ResUpdateProgress
    {
        /// <summary>
        /// 下载成功数量
        /// </summary>
        public int SuccessNum { get; set; }
        /// <summary>
        /// 下载失败数量 
        /// </summary>
        public int FailedNum { get; set; }
        /// <summary>
        /// 所有需要下载的数量
        /// </summary>
        public int TotalNum { get; set; }
        /// <summary>
        /// 已经下载完成的Size:Byte
        /// </summary>
        public long Size { get; set; }

        /// <summary>
        /// 已经下载完成的Size:KB
        /// </summary>
        public float SizeKB
        {
            get { return 1f * Size / 1024; }
        }
        /// <summary>
        /// 已经下载完成的Size:MB
        /// </summary>
        public float SizeMB
        {
            get { return 1f * Size / 1024 / 1024; }
        }
        /// <summary>
        /// 所有需要下载的Size:Byte
        /// </summary>
        public long TotalSize { get; set; }
        /// <summary>
        /// 所有需要下载的Size:KB
        /// </summary>
        public float totalSizeKB
        {
            get { return 1f *TotalSize / 1024; }
        }

        /// <summary>
        /// 所有需要下载的Size:MB
        /// </summary>
        public float TotalSizeMB
        {
            get { return 1f * TotalSize / 1024 / 1024; }
        }

        public float Progress
        {
            get
            {
                if (TotalSize == 0)
                    return 0;
                return 1f * Size / TotalSize;
            }
        }

        /// <summary>
        /// 是否完成
        /// </summary>
        public bool IsFinish
        {
            get
            {
                return TotalNum == (FailedNum + SuccessNum);
            }
        }

        /// <summary>
        /// 下载速度
        /// </summary>
        public float LoadSpeed
        {
            get;
            set;
        }

        /// <summary>
        /// 是否成功
        /// </summary>
        public bool IsSuccess
        {
            get
            {
                return FailedNum == 0;
            }
        }

        /// <summary>
        /// 重置
        /// </summary>
        public void Reset()
        {
            SuccessNum = 0;
            FailedNum = 0;
            TotalNum = 0;
            Size = 0;
            TotalSize = 0;
        }
    }
    public enum ResourcesUpdateState
    {
        //获取游戏版本
        GetGameConfigs,
        //获取游戏版本失败
        GetGameConfigsFailed,
        //下载版本文件
        DownLoadVersionFiles,
        //下载版本文件失败
        DownLoadVersionFilesFailed,
        //从非wifi环境下载
        DownLoadFromNoWifi,
        //wifi环境下载
        DownLoadWithWifi,
        //更新资源
        UpdateResourcesProgress,
        //更新资源失败
        UpdateResourcesFailed,
        //更新完成
        Success,
        //需要更换新包
        OldPackageNeedChange,
    }

    /// <summary>
    /// 资源更新管理器
    /// </summary>
    public class ResourcesUpdateManager : UnitySingleton<ResourcesUpdateManager>
    {
        /// <summary>
        /// 资源更新回调
        /// </summary>
        Action<bool, ResourcesUpdateState, object> resourcsUpdateAction;

        /// <summary>
        /// 需要下载的列表
        /// </summary>
        Dictionary<string, ResourceFile> downLoadFiles = new Dictionary<string, ResourceFile>();

        /// <summary>
        /// 进度统计
        /// </summary>
        Dictionary<string, long> progressInfo = new Dictionary<string, long>();

        /// <summary>
        /// 资源更新进度
        /// </summary>
        ResUpdateProgress progress = new ResUpdateProgress();

        /// <summary>
        /// 下载URL
        /// </summary>
        string downLoadURL;

        /// <summary>
        /// 本地版本号
        /// </summary>
        string localVersion;
        string sdkLodingUrl;

        DateTime startTime;


        /// <summary>
        /// 开始更新
        /// </summary>
        /// <param name="resourcsUpdateAction">资源更新回调</param>
        public void BeginUpdate(string localVersion, Action<bool, ResourcesUpdateState, object> resourcsUpdateAction)
        {
            this.localVersion = localVersion;
            this.resourcsUpdateAction = resourcsUpdateAction;
            this.downLoadFiles.Clear();
            this.progress.Reset();
            StartCoroutine(GetGameVersion());
        }


        /// <summary>
        /// 是否允许非wifi情况下下载
        /// </summary>
        /// <param name="wifi"></param>
        public void BeginDownLoad(bool allowDownLoadFromNoWifi)
        {
            if (downLoadFiles.Count == 0) 
            {
                UpdateSuccess();
                return;
            }

            Action startDownAction = () => {
                startTime = DateTime.Now;
                progressInfo.Clear();

                foreach (var each in downLoadFiles.Values)
                {
                    ResourceDownloadManager.Instance.StartDownload(each.fileName, downLoadURL, "", OnDownLoadFileProgress, OnDownLoadFileFinish);
                }
            };
            if (!IsNetWorkReachable(allowDownLoadFromNoWifi))
            {
                SetResourcesUpdateState(false, ResourcesUpdateState.DownLoadFromNoWifi, new object[] { progress.TotalSize, startDownAction });
            }
            else
            {
                SetResourcesUpdateState(false, ResourcesUpdateState.DownLoadWithWifi, new object[] { progress.TotalSize, startDownAction });   
            }
        }



        /// <summary>
        /// 下载进度回调
        /// </summary>
        /// <param name="fileName"></param>
        /// <param name="downLoadProgress"></param>
        void OnDownLoadFileProgress(string fileName, DownLoadProgress downLoadProgress)
        {
            if (!progressInfo.ContainsKey(fileName))
            {
                progressInfo.Add(fileName, downLoadProgress.Size);
            }
            progressInfo[fileName] = downLoadProgress.Size;
            this.progress.Size = 0;
            foreach (var each in progressInfo.Values)
            {
                this.progress.Size += each;
            }
           
            TimeSpan span = DateTime.Now - startTime;
            float second = (float)span.TotalSeconds;
            if (second > 0.0001)
            {
               this.progress.LoadSpeed = this.progress.Size / 1024 / second;
            }
            //更新进度
            SetResourcesUpdateState(false, ResourcesUpdateState.UpdateResourcesProgress, this.progress);
        }

        /// <summary>
        /// 下载文件完成
        /// </summary>
        /// <param name="fileName">文件名</param>
        /// <param name="result">下载结果</param>
        void OnDownLoadFileFinish(string fileName, bool result)
        {
            downLoadFiles.Remove(fileName);
            if (result)
            {
                progress.SuccessNum++;
            }
            else
            {
                progress.FailedNum++;
            }

            if (progress.IsFinish)
            {
                if (progress.IsSuccess)
                {
                    UpdateSuccess();
                }
                else
                {
                    Debug.LogError("load fail==============="+fileName);
                    SetResourcesUpdateState(true, ResourcesUpdateState.UpdateResourcesFailed);
                }
            }

        }

        /// <summary>
        /// 网络是否可用
        /// </summary>
        /// <param name="allowDownLoadFromNoWifi"></param>
        /// <returns></returns>
        bool IsNetWorkReachable(bool allowDownLoadFromNoWifi)
        {
            if (!allowDownLoadFromNoWifi && Application.internetReachability == NetworkReachability.ReachableViaCarrierDataNetwork) return false;
            return true;
        }

        /// <summary>
        /// 获取游戏版本号
        /// </summary>
        /// <returns></returns>
        IEnumerator GetGameVersion()
        {
            SetResourcesUpdateState(false, ResourcesUpdateState.GetGameConfigs);

            if (!AppConst.isUpdate)
            {
                UpdateSuccess();
                yield break;
            }

            downLoadURL = VersionManager.Instance.GetVersionInfo("resUrl") + VersionManager.Instance.GetVersionInfo("packageVersion") + "/" + AppConst.PlatformPath + "/";
            string resUrl = downLoadURL + AppConst.GameVersionFile;
            Debug.Log("Download_Resouces_Url:" + resUrl);

            UnityWebRequest request = UnityWebRequest.Get(resUrl);
            request.certificateHandler = new AcceptAllCertificatesSignedWithASpecificPublicKey();

            yield return request.SendWebRequest();
            if (request.isNetworkError)
            {
                SetResourcesUpdateState(true, ResourcesUpdateState.GetGameConfigsFailed);
            }
            else
            {
                Debug.Log("www.text:" + request.downloadHandler.text);
                Hashtable table = MiniJSON.jsonDecode(request.downloadHandler.text) as Hashtable;

                if (table == null)
                {
                    SetResourcesUpdateState(true, ResourcesUpdateState.GetGameConfigsFailed);
                }
                else
                {
                    string packageVersion = table["packageVersion"] as string;
                    if (VersionManager.CheckPackageVersionSame(packageVersion))
                    {
                        string version = table["version"] as string;
                        int result = VersionManager.VersionCompare(version, localVersion);
                        //下载链接
                        Debug.Log(string.Format("ResUpdate=====>InitDownLoadURL,Version:{0},loadVersion:{1}", version, localVersion));
                        Debug.Log(string.Format("Version Compare result:{0}", result));
                       
                        //如果版本号一致，就不进行更新了               
                        //if (result == 0)
                        //{
                        //    Debug.Log(string.Format("version:{0},版本号一致，更新完成", version));
                        //    UpdateSuccess();
                        //}
                        //else
                        //{
                            localVersion = version;
                            sdkLodingUrl = table["sdkLodingUrl"] as string;
                            Debug.Log(string.Format("vertion_txt {0}", localVersion, sdkLodingUrl));

                        DownLoadVersionFiles();
                        //}
                    }
                    else
                    {
                        string upAPKurl = table["upAPKurl"] as string;
                        Debug.Log("upApkUrl" + upAPKurl);
                        Application.OpenURL(upAPKurl);
                        SetResourcesUpdateState(true, ResourcesUpdateState.OldPackageNeedChange);
                    }

                }
            }

            //DownLoadVersionFiles();
        }

        /// <summary>
        /// 下载版本文件
        /// </summary>
        /// <param name="game"></param> 
        /// <param name="version"></param>
        /// <returns></returns>
        void DownLoadVersionFiles()
        {
            SetResourcesUpdateState(false, ResourcesUpdateState.DownLoadVersionFiles);
            ResourceDownloadManager.Instance.StartDownload(UpdateConfigs.FILES, downLoadURL, "", null, DownLoadVersionFilesFinishCallBack);
        }


        /// <summary>
        /// 下载版本文件结束回调
        /// </summary>
        /// <param name="fileName"></param>
        /// <param name="isSuccess"></param>
        void DownLoadVersionFilesFinishCallBack(string fileName, bool isSuccess)
        {
            Debug.Log(string.Format("ResUpdate=====>DownLoadVersionFilesFinishCallBack,FileName:{0},IsSuccess:{1}", fileName, isSuccess));
            if (isSuccess)
            {
                CalculateDownLoadFiles();
            }
            else
            {
                SetResourcesUpdateState(false, ResourcesUpdateState.DownLoadVersionFilesFailed);
            }
        }

        /// <summary>
        /// 计算需要下载的文件列表
        /// </summary>
        void CalculateDownLoadFiles()
        {
            if (BaseLogger.isDebug) BaseLogger.Log("ResUpdate=====>CalculateDownLoadFiles");
            List<ResourceFile> newFiles = GetNewResourceFiles();
            List<ResourceFile> streamFiles = GetStreamResourceFiles();
            List<ResourceFile> persistentFiles = GetPersistentDataResourcesFiles();
            ResourceFile newFile = null;
            ResourceFile streamFile = null;
            ResourceFile persistentFile = null;

            for (int i = 0; i < newFiles.Count; i++)
            {
                //> multiLan
                string[] nameArray = newFiles[i].fileName.Split('/');
                if(nameArray.Length > 1)
                {
                    //int L = ((int)Math.Floor((double)(AppConst.originLan / 100))) % 100;
                    //if (nameArray[nameArray.Length - 2] == "artfont_en")
                    //{
                    //    if (PlayerPrefs.GetInt("multi_language_ResOpen_en", 0) == 0 && L != 1)
                    //        continue;
                    //}
                    #region 替换上面注释代码,意思是当前选中类型的语言比对下载,不是当前选中的语言不需要对比下载
                    int lan = PlayerPrefs.GetInt("multi_language", AppConst.originLan);
                    int L = ((int)Math.Floor((double)(lan / 100))) % 100;//当前语言类型
                    if (nameArray[nameArray.Length - 2].Contains("artfont_"))
                    {//文件夹匹配多语言格式
                        if (MultiLanguageHelper.MultiLanguageDictionary.ContainsKey(L))
                        {
                            if (nameArray[nameArray.Length - 2] != MultiLanguageHelper.MultiLanguageDictionary[L].DirName)
                            {//文件夹名字不是指定语言的文件夹
                                continue;
                            }
                        }
                    }

                    #endregion
                }
                

                newFile = newFiles[i];
                streamFile = GetResourceFile(streamFiles, newFile.fileName);
                persistentFile = GetResourceFile(persistentFiles, newFile.fileName);
                if (CheckNeedDownLoad(newFile, streamFile, persistentFile))
                {
                    BaseLogger.LogFormat("NeedDownLoad====>FileName:{3}:[NewFile.CRC:{0}],[StreamFile.CRC:{1}],[PersistentFile.CRC:{2}]",
                        newFile!=null?newFile.crc:"Null",
                        streamFile != null ? streamFile.crc : "Null",
                        persistentFile != null ? persistentFile.crc : "Null",
                        newFile.fileName
                        );
                    this.progress.TotalSize += newFile.size;
                    downLoadFiles.Add(newFile.fileName, newFile);
                }
            }
            progress.TotalNum = downLoadFiles.Count;
            DeleteUnUseFiles(persistentFiles);
            BeginDownLoad(false);
        }

        /// <summary>
        /// 删除掉没用的资源
        /// </summary>
        void DeleteUnUseFiles(List<ResourceFile> files)
        {
            if(BaseLogger.isDebug) BaseLogger.LogFormat("ResUpdate=====>DeleteUnUseFiles,Count:{0}", files != null ? files.Count : 0);
            if (files == null) return;
            for (int i = 0; i < files.Count; i++)
            {
                if (files[i].fileName.Contains(UpdateConfigs.FILES)) continue;
                FileUtil.DeleteFile(UpdateConfigs.PersistentDataPath + files[i].fileName);
            }
        }

        /// <summary>
        /// 检查是否需要下载
        /// </summary>
        /// <param name="newFile"></param>
        /// <param name="streamFile"></param>
        /// <param name="persistentFile"></param>
        /// <returns></returns>
        bool CheckNeedDownLoad(ResourceFile newFile, ResourceFile streamFile, ResourceFile persistentFile)
        {
            if (streamFile == null)
            {
                //如果本地没有，需要更新
                if (persistentFile == null) return true;
                //如果本地的与服务器的不一样，需要更新
                return File.Exists(UpdateConfigs.PersistentDataPath + persistentFile.fileName) && persistentFile.crc != newFile.crc;
            }
            else
            {
                //如果没有外部文件，与内部文件对比
                if (persistentFile == null || !File.Exists(UpdateConfigs.PersistentDataPath + persistentFile.fileName)) return streamFile.crc != newFile.crc;
                //如果有外部文件与服务器文件一致，不需要更新
                if (newFile.crc == persistentFile.crc)
                {
                    return false;
                }
                //如果内部文件与服务器文件一致,说明强更后的APK中包含最新的资源,需要删除本地外部文件
                else if (newFile.crc == streamFile.crc)
                {
                    FileUtil.DeleteFile(UpdateConfigs.PersistentDataPath + newFile.fileName);
                    return false;
                }
                else
                {
                    return true;
                }
            }
        }

        /// <summary>
        /// 解析版本文件
        /// </summary>
        List<ResourceFile> GetNewResourceFiles()
        {
            AssetBundle bundle = AssetBundle.LoadFromFile(UpdateConfigs.PersistentDataPath + UpdateConfigs.FILES);//, 0, AppConst.EncyptBytesLength);
            ResourceFiles files = bundle.LoadAsset<ResourceFiles>("game");
            List<ResourceFile> list = files.files;
            bundle.Unload(true);
            return list;
        }

        /// <summary>
        /// 获取流媒体目录中的文件：可能有，可能没有
        /// </summary>
        /// <returns></returns>
        List<ResourceFile> GetStreamResourceFiles()
        {
            AssetBundle bundle = AssetBundle.LoadFromFile(UpdateConfigs.StreamPath + UpdateConfigs.FILES);//, 0, AppConst.EncyptBytesLength);
            if (bundle != null)
            {
                ResourceFiles files = bundle.LoadAsset<ResourceFiles>("game");
                List<ResourceFile> list = files.files;
                bundle.Unload(true);
                return list;
            }
            else
            {
                Debug.LogError("GetStreamResourceFiles is null!");
            }
            return null;
        }

        /// <summary>
        /// 获取持久化目录中的文件
        /// </summary>
        /// <returns></returns>
        List<ResourceFile> GetPersistentDataResourcesFiles()
        {
            if (BaseLogger.isDebug) BaseLogger.Log("ResUpdate=====>GetPersistentDataResourcesFiles");
            string[] files = FileUtil.GetAllFiles(UpdateConfigs.PersistentDataPath);
            List<ResourceFile> list = new List<ResourceFile>();
            string fileName = string.Empty;
            for (int i = 0; i < files.Length; i++)
            {
                fileName = files[i].Replace(UpdateConfigs.PersistentDataPath, string.Empty).Replace("\\","/");
                ResourceFile file = new ResourceFile(fileName, FileToCRC32.GetFileCRC32(files[i]));
                list.Add(file);
            }
            return list;
        }

        /// <summary>
        /// 获取资源文件
        /// </summary>
        /// <param name="files"></param>
        /// <param name="fileName"></param>
        /// <returns></returns>
        ResourceFile GetResourceFile(List<ResourceFile> files, string fileName)
        {
            if (files == null) return null;
            ResourceFile file = null;
            for (int i = 0; i < files.Count; i++)
            {
                if (files[i].fileName == fileName)
                {
                    file = files[i];
                    //找到了就从列表中删掉
                    files.RemoveAt(i);
                    break;
                }
            }
            return file;
        }



        void UpdateSuccess() {
            VersionPar vp = new VersionPar();
            vp.version = localVersion;
            vp.sdkLodingUrl = sdkLodingUrl;
            SetResourcesUpdateState(true, ResourcesUpdateState.Success, vp);
        }


        /// <summary>
        /// 设置资源更新状态
        /// </summary>
        /// <param name="isFinish">是否已经更新完成</param>
        /// <param name="state">更新状态</param>
        /// <param name="param">参数</param>
        void SetResourcesUpdateState(bool isFinish, ResourcesUpdateState state, object param = null)
        {
            ThreadManager.Instance.QueueOnMainThread(() => {
                if (resourcsUpdateAction != null)
                {
                    resourcsUpdateAction(isFinish, state, param);
                }

                if (isFinish)
                {
                    resourcsUpdateAction = null;
                }
            });
        }
    }
}
