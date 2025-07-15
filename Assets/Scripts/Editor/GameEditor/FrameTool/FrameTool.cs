using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEngine;
using System.IO;
using ResMgr;
using GameEditor.AssetBundle;
using GameEditor.Core;
using GameCore;
using ResUpdate;
using GameLogic;

namespace GameEditor.FrameTool
{
    public class FrameTool
    {

        /// <summary>
        /// 初始化游戏环境
        /// </summary>
        //[MenuItem("GameFrame/InitResEnvironment", false, 1)]
        //public static void InitResEnvironment()
        //{
        //    ResourcesPathEditor.InitIgnoreList();
        //}

        /// <summary>
        /// 刷新资源配置文件
        /// </summary>
        [MenuItem("GameFrame/刷新资源配置", false, 2)]
        public static void RefreshResPathConfigs()
        {
            ResourcesPathEditor.CreateResourcePathConfig(true);
            EditorUtil.ShowSureDialog("资源配置文件生成完毕!");
        }

        /// <summary>
        /// 检查资源循环依赖
        /// </summary>
        [MenuItem("GameFrame/检查循环依赖", false, 2)]
        public static void CheckDependences()
        {
            ResourcesPathEditor.ForEachCheckDependences();
            EditorUtil.ShowSureDialog("检查完毕!");
        }

        /// <summary>
        /// 战斗服务端验证同步
        /// </summary>
        [MenuItem("GameFrame/战斗逻辑同步", false, 2)]
        public static void BattleLogicSync()
        {
            string p = Application.dataPath;
            p = p.Substring(0, p.LastIndexOf('/'));
            string t1 = p.Substring(p.LastIndexOf('/'), p.Length - p.LastIndexOf('/'));
            //p = p.Substring(0, p.LastIndexOf('/'));
            //string t2 = p.Substring(p.LastIndexOf('/'), p.Length - p.LastIndexOf('/'));
            //p = p.Substring(0, p.LastIndexOf('/'));
            string p2 = p + "/battleWeb" + "/Clinet";

            string[] files = Directory.GetFiles(AppConst.GameResRealPath + "/~Lua/Modules/Battle/Logic", "*.lua", SearchOption.AllDirectories);                  
            foreach (var s in files)
            {
                string s2 = s.Replace(Application.dataPath + "/ManagedResources/~Lua", p2);
                FileUtils.CopyFile(s, s2);
            }
            Debug.LogError("同步完成！");
        }

        [MenuItem("GameFrame/刷新资源配置(NotRename)", false, 2)]
        public static void RefreshResPathConfigsNotRename()
        {
            ResourcesPathEditor.CreateResourcePathConfig(false);
            EditorUtil.ShowSureDialog("完毕! 如有重名需手动修改 之后再次执行(确保无重名) 或执行第一选项");
        }

        /// <summary>
        /// 获取所有游戏
        /// </summary>
        /// <returns></returns>
        public static string[] GetAllGames() {
            string fullPath = EditorUtil.GetFullPath(AppConst.GameResPath);
            string[] directorys = Directory.GetDirectories(fullPath);
            string[] games = new string[directorys.Length];
            string game = string.Empty;
            for (int i = 0; i < directorys.Length; i++)
            {
                game = Path.GetFileName(directorys[i]);
                games[i] = game;
            }
            return games;
        }

        /// <summary>
        /// 刷新选中资源配置文件
        /// </summary>
        [MenuItem("Assets/GameFrame/RefreshResPathConfig")]
        public static void RefreshResPathConfig()
        {
            try
            {
                ResourcesPathEditor.CreateResourcePathConfig(true);
                EditorUtil.ShowSureDialog("资源配置文件生成完毕!");
            }
            catch (Exception e)
            {
                Debug.LogErrorFormat("RefreshResPathConfigError:{0}", e.ToString());
            }
        }


        /// <summary>
        /// 整体打包
        /// </summary>
        public static void BuildAll()
        {
            AssetBundleBuilder.ClearMarks();
            BuildGameAssetBundles();
        }


        [MenuItem("AssetBundle/MarkAllGame")]
        /// <summary>
        /// 标记所有游戏
        /// </summary>
        public static void MarkAllGame()
        {
            MarkGame(false);
            ResourcesPathEditor.CreateResourcePathConfig(true);
        }


        /// <summary>
        /// 检查AB包的资源合法性
        /// 1.AssetBundle的循环依赖
        /// 2.AssetBundle的跨游戏依赖
        /// </summary>
        public static void CheckAssetBundleStates() {
            AssetBundleBuilder.ClearMarks();
            MarkAllGame();
        }

        public static void AssetsDuplicatedInMultBundlesCache(int type)
        {
            string target;
            foreach(var path in AssetBundleBrowser.AssetBundleModel.Model.AssetsDuplicatedInMultBundlesCache)
            {
                if(type == 1)
                {
                    Debug.LogError("path：" + path);
                }
                else
                {
                    Debug.LogError("正在移动：" + path);
                    string extension = Path.GetExtension(path).ToLower();
                    switch (extension)
                    {
                        case ".png":
                        case ".tga":
                            target = "Textures/";
                            break;
                        case ".mat":
                            target = "Materials/";
                            break;
                        case ".fbx":
                            target = "Models/";
                            break;
                        case ".anim":
                        case ".controller":
                            target = "Animations/";
                            break;
                        default:
                            target = null;
                            break;
                    }
                    if (target != null)
                    {
                        File.Move(Application.dataPath + path.Replace("Assets", ""),
                            AppConst.GameResRealPath + "/PublicArtRes/" + target + Path.GetFileNameWithoutExtension(path) + extension);
                        File.Move(Application.dataPath + path.Replace("Assets", "") + ".meta",
                            AppConst.GameResRealPath + "/PublicArtRes/" + target + Path.GetFileNameWithoutExtension(path) + extension + ".meta");
                    }
                }        
            }
            AssetDatabase.Refresh();
        }

        /// <summary>
        /// 打包游戏
        /// </summary>
        public static void BuildGameAssetBundles() 
        {
            AssetBundleBuilder.ClearMarks();
            MarkGame(true);
            string exportPath = AssetBundleConfig.GetExportPath(EditorUserBuildSettings.activeBuildTarget);
            if (Directory.Exists(exportPath))
                Directory.Delete(exportPath, true);
            AssetBundleBuilder.BuildAssetBundleWithType(exportPath, AssetBundleConfig.LZ4Options, EditorUserBuildSettings.activeBuildTarget, CompressType.LZ4);
            AssetBundleBuilder.BuildAssetBundleWithType(exportPath, AssetBundleConfig.LZMAOptions, EditorUserBuildSettings.activeBuildTarget, CompressType.LZMA);
            AssetBundleBuilder.BuildAssetBundleWithType(exportPath, AssetBundleConfig.NoneOptions, EditorUserBuildSettings.activeBuildTarget, CompressType.NoCompress);
            CreateCRCFiles(exportPath);
            AssetBundleBuilder.ClearManifest(exportPath);
            EditorUtil.OpenFolderAndSelectFile(exportPath);
        }

        public static void test()
        {
            string exportPath = AssetBundleConfig.GetExportPath(EditorUserBuildSettings.activeBuildTarget);
            CreateCRCFiles(exportPath);

        }

        public static string CombinePack = "CombinePack";
        /// <summary>
        /// 拷贝AssetBundle到StreamingAssets
        /// </summary>
        /// <param name="games"></param>
        public static void CopyAssetBundleToStreamingAssets() 
        {
            string exportPath =AssetBundleConfig.GetExportPath(EditorUserBuildSettings.activeBuildTarget)+"/"+CombinePack;
            string streamingPath = GetStreamingAssetPath(EditorUserBuildSettings.activeBuildTarget);
            //Debug.LogError(streamingPath);
            if (Directory.Exists(streamingPath)) Directory.Delete(streamingPath,true);
            FileUtils.CopyDir(exportPath, streamingPath);

            ////> multiLan
            //int L = ((int)Math.Floor((double)(AppConst.originLan / 100))) % 100;
            //if (L != 1)
            //{
            //    string delPath = streamingPath + @"/lz4/artfont_en";
            //    if (Directory.Exists(delPath))
            //    {
            //        Directory.Delete(delPath, true);
            //    }
            //    else
            //    {
            //        Debug.LogError("CopyAssetBundleToStreamingAssets artfont_en not found Error!");
            //    }
            //}

            #region 替换上面注释代码,删除非选中语言的文件夹
            int L = ((int)Math.Floor((double)(AppConst.originLan / 100))) % 100;
            foreach (var item in MultiLanguageHelper.MultiLanguageDictionary)
            {
                if (item.Key != 0//留下中文,因为有引用关系,不然加载不到AB
                      && item.Key != L)
                {
                    string delPath = streamingPath + @"/lz4/" + item.Value.DirName;
                    if (Directory.Exists(delPath))
                    {
                        Directory.Delete(delPath, true);
                    }
                    else
                    {
                        Debug.LogError("CopyAssetBundleToStreamingAssets " + item.Value.DirName + " not found Error!"+delPath);
                    }
                }
            }
            #endregion

            string copyFilePath = exportPath.Substring(0, exportPath.LastIndexOf('/')) + @"/files.unity3d";
            if (File.Exists(copyFilePath))
            {
                string delFilePath = streamingPath + @"/files.unity3d";
                if(File.Exists(delFilePath))
                {
                    File.Delete(delFilePath);
                    File.Copy(copyFilePath, delFilePath);
                }
                else
                {
                    Debug.LogError("CopyAssetBundleToStreamingAssets del files Error! not found");
                }
            }
            else
            {
                Debug.LogError("CopyAssetBundleToStreamingAssets files.unity3d not found Error!");
            }



            CopyResourceFiles();
        }

        /// <summary>
        /// 单打lua资源
        /// </summary>
        public static bool BuildLuaAssetBundles()
        {
            AssetImporter ai = AssetImporter.GetAtPath(AppConst.GameResPath + "/LuaBytes");
            if(ai == null)
            {
                Debug.LogError("lua资源不存在！请先打全包！");
                return false;
            }

            AssetBundleBuilder.ClearMarks();
            MarkGame(true);

            AssetBundleBuild build = new AssetBundleBuild();
            build.assetBundleName = ai.assetBundleName;
            build.assetBundleVariant = ai.assetBundleVariant;
            build.assetNames = new string[] { ai.assetPath };

            AssetImporter ai2 = AssetImporter.GetAtPath(AppConst.GameResPath + "/ResConfigs");
            AssetBundleBuild build2 = new AssetBundleBuild();
            build2.assetBundleName = ai2.assetBundleName;
            build2.assetBundleVariant = ai2.assetBundleVariant;
            build2.assetNames = new string[] { ai2.assetPath };

            string exportPath = AssetBundleConfig.GetExportPath(EditorUserBuildSettings.activeBuildTarget);
            var manifest = BuildPipeline.BuildAssetBundles(exportPath, new AssetBundleBuild[] { build, build2 }, BuildAssetBundleOptions.DeterministicAssetBundle, EditorUserBuildSettings.activeBuildTarget);

            // 加密 文件前加入128个空字符
            foreach (var name in manifest.GetAllAssetBundles())
            {
                var uniqueSalt = Encoding.UTF8.GetBytes(name);
                string pn = Path.Combine(exportPath, name);
                byte[] oldData = File.ReadAllBytes(pn);
                int len = (int)GameLogic.AppConst.EncyptBytesLength;
                int newOldLen = len + oldData.Length;//定死了,128个空byte
                var newData = new byte[newOldLen];
                for (int tb = 0; tb < oldData.Length; tb++)
                {
                    newData[len + tb] = oldData[tb];
                }
                FileStream fs = File.OpenWrite(pn);//打开写入进去
                fs.Write(newData, 0, newOldLen);
                fs.Close();
            }


            CreateCRCFiles(exportPath);
            AssetBundleBuilder.ClearManifest(exportPath);
            AssetDatabase.Refresh();
           
            return true;
        }

        /// <summary>
        /// 数据目录
        /// </summary>
        static string AppDataPath
        {
            get { return Application.dataPath.ToLower(); }
        }

        public static void CopyResourceFiles()
        {
            string AssetRoot = "StreamingAssets/Android";
            if (BuildTarget.iOS == EditorUserBuildSettings.activeBuildTarget)
            {
                AssetRoot = "StreamingAssets/IOS";
            }
            string ResourcePath = "Resources/";
            string resPath = AppDataPath + "/" + AssetRoot + "/";
            ///----------------------创建文件列表-----------------------
            string newFilePath = resPath + "/" + ResourcePath;
            if (Directory.Exists(newFilePath))
                Directory.Delete(newFilePath, true);

            Directory.CreateDirectory(newFilePath);
            string sourcePath = Application.dataPath + "/Resources/";
            string[] files = Directory.GetFiles(sourcePath, "*", SearchOption.AllDirectories);

            foreach (var file in files)
            {
                FileInfo info = new FileInfo(file);
                File.Copy(file, newFilePath + info.Name, true);
            }
        }

        public static void SaveVersionFile()
        {
            
        }

        /// <summary>
        /// 创建CRC文件
        /// </summary>
        /// <param name="exportPath"></param>
        public static void CreateCRCFiles(string exportPath) 
        {
            string fullPath = exportPath;
            if (!Directory.Exists(fullPath))
                return;
            string[] files = Directory.GetFiles(fullPath, "*.unity3d", SearchOption.AllDirectories);
            string savePath = string.Format("{0}/CRC/game.asset", Application.dataPath);
            string saveAssetPath = EditorUtil.GetAssetsPath(savePath);
            ResourceFiles resourceFiles = null;
            if (File.Exists(savePath))
            {
                resourceFiles = AssetDatabase.LoadAssetAtPath<ResourceFiles>(saveAssetPath);
            }
            else 
            {
                string directory = Path.GetDirectoryName(savePath);
                if (!Directory.Exists(directory)) Directory.CreateDirectory(directory);
                resourceFiles = ScriptableObject.CreateInstance<ResourceFiles>();
                AssetDatabase.CreateAsset(resourceFiles,saveAssetPath);
            }
            if (resourceFiles == null)
            {
                string message = string.Format("资源CRC信息列表文件{0}错误，请查看", savePath);
                EditorUtility.DisplayDialog("提示", message, "确定");
                return;
            }
            if(resourceFiles.files==null)
                resourceFiles.files = new List<ResourceFile>();
            resourceFiles.files.Clear();
            FileInfo info = null;
            ResourceFile file = null;
            for (int i = 0; i < files.Length; i++)  
            {
                files[i] = EditorUtil.FixedWindowsPath(files[i]);
                info = new FileInfo(files[i]);
                file = new ResourceFile();
                file.id = i + 1;
                file.fileName = files[i].Replace(exportPath+"/",string.Empty);
                file.size = info.Length;
                file.crc = FileToCRC32.GetFileCRC32(files[i]);
                resourceFiles.files.Add(file);
            }
            EditorUtility.SetDirty(resourceFiles);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            AssetBundleBuilder.BuildAssetBundle(resourceFiles, "files", exportPath, AssetBundleConfig.LZMAOptions, EditorUserBuildSettings.activeBuildTarget);

            //以下生成StreamingAssets用的files.unity3d文件
            if (File.Exists(savePath))
            {
                resourceFiles = AssetDatabase.LoadAssetAtPath<ResourceFiles>(saveAssetPath);
            }
            else
            {
                string directory = Path.GetDirectoryName(savePath);
                if (!Directory.Exists(directory)) Directory.CreateDirectory(directory);
                resourceFiles = ScriptableObject.CreateInstance<ResourceFiles>();
                AssetDatabase.CreateAsset(resourceFiles, saveAssetPath);
            }
            resourceFiles.files.Clear();
            info = null;
            file = null;
            int idx = 0;
            for (int i = 0; i < files.Length; i++)
            {
                files[i] = EditorUtil.FixedWindowsPath(files[i]);
                string sub = files[i].Substring(0, files[i].LastIndexOf('/'));
                int L = ((int)Math.Floor((double)(AppConst.originLan / 100))) % 100;
                //if (sub.EndsWith("artfont_en") && L != 1)
                //{
                //    continue;
                //}
                ////if (sub.EndsWith("artfont_xx") && AppConst.originLan != 2)
                ////{
                ////    continue;
                ////}
                #region 替换上面注释代码,作用是非选中语言的资源不添加进记录列表

                bool isNotNeedAdd = false;
                foreach (var item in MultiLanguageHelper.MultiLanguageDictionary)
                {
                    if (sub.EndsWith(item.Value.DirName) && L != item.Key)
                    {
                        isNotNeedAdd = true;
                        continue;
                    }
                }
                if (isNotNeedAdd)
                {
                    continue;
                }

                #endregion

                info = new FileInfo(files[i]);
                file = new ResourceFile();
                file.id = idx + 1;
                file.fileName = files[i].Replace(exportPath + "/", string.Empty);
                file.size = info.Length;
                file.crc = FileToCRC32.GetFileCRC32(files[i]);
                resourceFiles.files.Add(file);
                idx++;
            }
            EditorUtility.SetDirty(resourceFiles);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            string multiFilesExportStr = exportPath.Substring(0, exportPath.LastIndexOf('/'));
            AssetBundleBuilder.BuildAssetBundle(resourceFiles, "files", multiFilesExportStr, AssetBundleConfig.LZMAOptions, EditorUserBuildSettings.activeBuildTarget);
        }

        /// <summary>
        /// 拷贝Lua文件
        /// </summary>
        public static void CopyLuaFiles() {
                string luaBytesFullPath = EditorUtil.GetFullPath(string.Format("{0}/LuaBytes", AppConst.GameResPath));
                if (!Directory.Exists(luaBytesFullPath))
                {
                    Directory.CreateDirectory(luaBytesFullPath);
                }
                List<string> files = EditorUtil.GetFiles(luaBytesFullPath, "*", SearchOption.AllDirectories);
                for (int i = 0; i < files.Count; i++) {
                    File.Delete(files[i]);
                }
                string luaFullPath = EditorUtil.GetFullPath(string.Format("{0}/~Lua", AppConst.GameResPath));
                files = EditorUtil.GetFiles(luaFullPath, "*.lua", SearchOption.AllDirectories);
                string inPath = string.Empty;
                string outPath = string.Empty;
                for (int i = 0; i < files.Count; i++) {
                    inPath = files[i];
                    outPath = inPath.Replace(luaFullPath+"/", string.Empty).Replace("/","_").Replace(".lua",".bytes");
                    outPath = luaBytesFullPath + "/" + outPath;
                    //FileUtils.CopyFile(inPath, outPath);    
                    Packager.EncodeLuaFile(inPath, outPath);
                }
                Debug.LogFormat("拷贝Lua文件完成!");
                //检查是否真的Lua文件拷贝完成
                {
                    files = EditorUtil.GetFiles(luaBytesFullPath, "*", SearchOption.AllDirectories);
                    if (files.Count == 0)
                    {
                        EditorUtility.DisplayDialog("Lua转换为二进制文件出错", "Mac机是不是LuaEncoder\\luajit_mac\\64\\luajit和LuaEncoder\\luajit_mac\\32\\luajit没给权限?\r\n打开终端->输入:chmod空格777空格->把luajit文件拖到终端->回车,两个文件都得执行","确定");
                        throw new Exception("Lua转换为二进制文件出错,\r\nMac机是不是LuaEncoder\\luajit_mac\\64\\luajit和LuaEncoder\\luajit_mac\\32\\luajit没给权限?\r\n打开终端->输入:chmod空格777空格->把luajit文件拖到终端->回车,两个文件都得执行");
                    }
                }

                AssetDatabase.Refresh();
        }

        /// <summary>
        /// 处理lua文件
        /// </summary>
        /// <param name="inpath"></param>
        /// <param name="outPath"></param>
        public static void HandleLuaFile(string inpath, string outPath) { 

        }

        /// <summary>
        /// 标记一个游戏
        /// </summary>
        public static void MarkGame(bool refreshConfig = false)
        {
                //拷贝Lua文件
                CopyLuaFiles();
                //标记Lua
                string buildConfigPath = string.Format("{0}/EditorConfigs/BuildConfigs.asset", AppConst.GameResPath);
                AssetBundleBuildConfigs configs = AssetDatabase.LoadAssetAtPath<AssetBundleBuildConfigs>(buildConfigPath);
                AssetBundleBuildConfig[] paths = configs.OneFloderOneBundle;
                for (int i = 0; i < paths.Length; i++)
                {
                    if (string.IsNullOrEmpty(paths[i].Path))
                    {
                        Debug.LogErrorFormat("MarkGame error:BuildConfigs contain null floder." + paths[i].Path);
                        continue;
                    }
                    AssetBundleBuilder.MarkOneFloderOneBundle(paths[i].Path, paths[i].CompressType);
                }
                paths = configs.SubFloderOneBundle;
                for (int i = 0; i < paths.Length; i++)
                {
                    if (string.IsNullOrEmpty(paths[i].Path))
                    {
                        Debug.LogErrorFormat("MarkGame error:BuildConfigs contain null  floder.");
                        continue;
                    }
                    AssetBundleBuilder.MarkSubFloderOneBundle(paths[i].Path,paths[i].CompressType);
                }

                paths = configs.OneAssetOneBundle;
                for (int i = 0; i < paths.Length; i++)
                {
                    if (string.IsNullOrEmpty(paths[i].Path))
                    {
                        Debug.LogErrorFormat("MarkGame error:BuildConfigs contain null  floder");
                        continue;
                    }
                    AssetBundleBuilder.MarkOneAssetOneBundle(paths[i].Path, true, paths[i].CompressType);
                }
                if (refreshConfig)ResourcesPathEditor.CreateResourcePathConfig(true);
                Debug.LogFormat("标记游戏完成!");
        }

        /// <summary>
        /// 获取流媒体目录
        /// </summary>
        /// <param name="target"></param>
        /// <returns></returns>
        public static string GetStreamingAssetPath(BuildTarget target) {
            string floder = "Other";
            switch (target)
            {
                case BuildTarget.Android:
                    floder = "Android";
                    break;
                case BuildTarget.iOS:
                    floder = "IOS";
                    break;
                case BuildTarget.StandaloneWindows:
                    floder = "Windows";
                    break;
                case BuildTarget.StandaloneWindows64:
                    floder = "Windows";
                    break;
            }
            return Application.streamingAssetsPath + "/" + floder;
        }

    }
}
