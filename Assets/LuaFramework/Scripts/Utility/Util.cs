using UnityEngine;
using System;
using System.IO;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using LuaInterface;
using GameLogic;
using UnityEngine.UI;
using DG.Tweening;
using ResUpdate;
using GameCore;
using System.Reflection;
using Spine.Unity;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace GameLogic
{
    public static class Util
    {
        public static string packGameVersion = "";
        public static string updateGameVersion = "";
        public static string netGameVersion = "";

        public static Color gray = Color.gray;
        private static List<string> luaPaths = new List<string>();

        public static int m_lan = 0;

        public static string GetDownloadPackageUrl()
        {
            string download_url = string.Empty;
#if UNITY_IOS
            download_url = AppConst.Download_ipa_Url;
#else
            download_url = AppConst.Download_apk_Url;
#endif
            return download_url;
        }

        public static bool IsFileExist(string fileName)
        {
            return File.Exists(Util.DataPath + fileName);
        }

        public static bool IsExracted()
        {
            bool isExists = Directory.Exists(DataPath) && Directory.Exists(DataPath + "lua/") && File.Exists(DataPath + AppConst.LoadingMD5Flie);
            return isExists;
        }

        public static bool NeedExtractResource()
        {
            return false;
            if (!IsExracted())
                return true;

            return CompareGameVersion(packGameVersion, updateGameVersion) > 0;
        }

        public static int CompareGameVersion(string version1, string version2)
        {
            float result = 0;
            if (string.IsNullOrEmpty(version1) || string.IsNullOrEmpty(version2))
            {
                return version1.CompareTo(version2);
            }
            else
            {
                var temp1 = version1.Split('.');
                var temp2 = version2.Split('.');

                float first1 = 0;
                float.TryParse(temp1[0], out first1);

                float first2 = 0;
                float.TryParse(temp2[0], out first2);

                float middle1 = 0;
                float.TryParse(temp1[1], out middle1);

                float middle2 = 0;
                float.TryParse(temp2[1], out middle2);

                float last1 = 0;
                float.TryParse(temp1[2], out last1);

                float last2 = 0;
                float.TryParse(temp2[2], out last2);

                if (first1 != first2)
                    result = first1 - first2;
                else if (middle1 != middle2)
                    result = middle1 - middle2;
                else
                    result = last1 - last2;

            }

            if (result > 0) return 1;
            else if (result == 0) return 0;
            else return -1;
        }

        public static int Int(object o)
        {
            return Convert.ToInt32(o);
        }

        public static float Float(object o)
        {
            return (float)Math.Round(Convert.ToSingle(o), 2);
        }

        public static long Long(object o)
        {
            return Convert.ToInt64(o);
        }

        public static int Random(int min, int max)
        {
            return UnityEngine.Random.Range(min, max);
        }

        public static float Random(float min, float max)
        {
            return UnityEngine.Random.Range(min, max);
        }

        public static string Uid(string uid)
        {
            int position = uid.LastIndexOf('_');
            return uid.Remove(0, position + 1);
        }

        public static long GetTime()
        {
            TimeSpan ts = new TimeSpan(DateTime.UtcNow.Ticks - new DateTime(1970, 1, 1, 0, 0, 0).Ticks);
            return (long)ts.TotalMilliseconds;
        }

        public static string GetDateTime()
        {
            return DateTime.Now.ToString();
        }

        public static string GetPlatformVersion()
        {
            App.GameMgr.StartCoroutine(GetPlatformText("Platform/" + AppConst.GameVersionFile));
            return packGameVersion;
        }

        private static IEnumerator GetPlatformText(string filePath)
        {
            string versionFilePath = DataPath + filePath;
            if (File.Exists(versionFilePath))
            {
                var lines = File.ReadAllLines(versionFilePath);
                if (lines.Length > 0)
                {
                    if (!string.IsNullOrEmpty(lines[0]))
                    {
                        packGameVersion = lines[0].Trim();
                    }
                }
                yield return null;
            }
            else
            {
                yield return App.GameMgr.StartCoroutine(GetPackageText(filePath));
            }
        }

        private static IEnumerator GetPackageText(string fileName)
        {
            string filePath = GetOriginalPath() + fileName;
            WWW www = new WWW(filePath);
            yield return www;
            if (!string.IsNullOrEmpty(www.error))
            {
                XDebug.Log.error("File " + fileName + " no exist in " + filePath + ",Please check it.");
            }
            else
            {
                if (www.isDone)
                {
                    packGameVersion = www.text.Trim();
                }
            }
        }


        /// <summary>
        /// 搜索子物体组件-GameObject版
        /// </summary>
        public static T Get<T>(GameObject go, string subnode) where T : Component
        {
            if (go != null)
            {
                Transform sub = go.transform.Find(subnode);
                if (sub != null) return sub.GetComponent<T>();
            }
            return null;
        }

        /// <summary>
        /// 搜索子物体组件-Transform版
        /// </summary>
        public static T Get<T>(Transform go, string subnode) where T : Component
        {
            if (go != null)
            {
                Transform sub = go.Find(subnode);
                if (sub != null) return sub.GetComponent<T>();
            }
            return null;
        }

        /// <summary>
        /// 搜索子物体组件-Component版
        /// </summary>
        public static T Get<T>(Component go, string subnode) where T : Component
        {
            return go.transform.Find(subnode).GetComponent<T>();
        }

        /// <summary>
        /// 添加组件
        /// </summary>
        public static T Add<T>(GameObject go) where T : Component
        {
            if (go != null)
            {
                T[] ts = go.GetComponents<T>();
                for (int i = 0; i < ts.Length; i++)
                {
                    if (ts[i] != null) GameObject.Destroy(ts[i]);
                }
                return go.gameObject.AddComponent<T>();
            }
            return null;
        }

        /// <summary>
        /// 添加组件
        /// </summary>
        public static T Add<T>(Transform go) where T : Component
        {
            return Add<T>(go.gameObject);
        }

        public static EventTriggerListener GetEventTriggerListener(GameObject go)
        {
            EventTriggerListener triggerListener = null;
            if (go != null)
            {
                triggerListener = go.GetComponent<EventTriggerListener>();
                if (triggerListener == null)
                {
                    triggerListener = go.AddComponent<EventTriggerListener>();
                }
            }
            return triggerListener;
        }

        public static EventTriggerListener GetEventTriggerListenerWithNil(GameObject go)
        {
            EventTriggerListener triggerListener = null;
            if (go != null)
            {
                triggerListener = go.GetComponent<EventTriggerListener>();
            }
            return triggerListener;
        }


        /// <summary>
        /// 查找子对象
        /// </summary>
        public static GameObject Child(GameObject go, string subnode)
        {
            return Child(go.transform, subnode);
        }

        /// <summary>
        /// 查找子对象
        /// </summary>
        public static GameObject Child(Transform go, string subnode)
        {
            Transform tran = go.Find(subnode);
            if (tran == null) return null;
            return tran.gameObject;
        }

        public static GameObject GetGameObject(GameObject root, string objName)
        {
            if (root == null)
                return null;

            return GetGameObject(root.transform, objName);
        }

        public static GameObject GetGameObject(Transform root, string objName)
        {
            if (root == null || string.IsNullOrEmpty(objName))
                return null;
            if (root.name.CompareTo(objName) == 0)
                return root.gameObject;

            var trans = FindChild(root, objName);
            return trans == null ? null : trans.gameObject;
        }

        public static Transform GetTransform(Transform root, string objName)
        {
            if (root == null)
                return null;
            if (root.name.CompareTo(objName) == 0)
                return root.transform;

            var trans = FindChild(root, objName);
            return trans == null ? null : trans;
        }

        public static Transform GetTransform(GameObject root, string objName)
        {
            if (root == null)
                return null;
            return GetTransform(root.transform, objName);
        }

        public static Transform FindChild(Transform root, string objName)
        {
            var obj = root.Find(objName);
            if (obj != null)
                return obj;

            for (int i = 0; i < root.childCount; i++)
            {
                obj = FindChild(root.GetChild(i), objName);
                if (obj != null)
                    return obj;
            }

            return null;
        }

        /// <summary>
        /// 取平级对象
        /// </summary>
        public static GameObject Peer(GameObject go, string subnode)
        {
            return Peer(go.transform, subnode);
        }

        /// <summary>
        /// 取平级对象
        /// </summary>
        public static GameObject Peer(Transform go, string subnode)
        {
            Transform tran = go.parent.Find(subnode);
            if (tran == null) return null;
            return tran.gameObject;
        }


        /// <summary>
        /// 计算字符串的MD5值
        /// </summary>
        /// 
        public static string md5(string source)
        {
            MD5CryptoServiceProvider md5 = new MD5CryptoServiceProvider();
            byte[] data = System.Text.Encoding.UTF8.GetBytes(source);
            byte[] md5Data = md5.ComputeHash(data, 0, data.Length);
            md5.Clear();

            string destString = "";
            for (int i = 0; i < md5Data.Length; i++)
            {
                destString += System.Convert.ToString(md5Data[i], 16).PadLeft(2, '0');
            }
            destString = destString.PadLeft(32, '0');
            return destString;
        }

        /// <summary>
        /// 计算文件的MD5值
        /// </summary>
        public static string md5file(string file)
        {
            try
            {
                FileStream fs = new FileStream(file, FileMode.Open);
                System.Security.Cryptography.MD5 md5 = new System.Security.Cryptography.MD5CryptoServiceProvider();
                byte[] retVal = md5.ComputeHash(fs);
                fs.Close();

                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < retVal.Length; i++)
                {
                    sb.Append(retVal[i].ToString("x2"));
                }
                return sb.ToString();
            }
            catch (Exception ex)
            {
                throw new Exception("md5file() fail, error:" + ex.Message);
            }
        }

        /// <summary>
        /// 计算buffer的MD5值
        /// </summary>
        public static string md5bytes(byte[] buffer)
        {
            try
            {
                System.Security.Cryptography.MD5 md5 = new System.Security.Cryptography.MD5CryptoServiceProvider();
                byte[] retVal = md5.ComputeHash(buffer);

                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < retVal.Length; i++)
                {
                    sb.Append(retVal[i].ToString("x2"));
                }
                return sb.ToString();
            }
            catch (Exception ex)
            {
                throw new Exception("md5bytes() fail, error:" + ex.Message);
            }
        }


        /// <summary>
        /// 清除所有子节点
        /// </summary>
        public static void ClearChild(Transform go)
        {
            if (go == null) return;
            for (int i = go.childCount - 1; i >= 0; i--)
            {
                GameObject.DestroyImmediate(go.GetChild(i).gameObject);
            }
        }

        /// <summary>
        /// 清理内存
        /// </summary>
        public static void ClearMemory()
        {
            App.LuaMgr.LuaGC();
            Resources.UnloadUnusedAssets();
            GC.Collect();
        }

        /// <summary>
        /// 取得数据存放目录
        /// </summary>
        public static string DataPath
        {
            get
            {
                string game = AppConst.AppName.ToLower();
                if (Application.isMobilePlatform)
                {
                    return Application.persistentDataPath + "/" + game + "/" + AppConst.PlatformPath + "/";
                }
                if (AppConst.DebugMode)
                {
                    return Application.dataPath + "/" + AppConst.AssetDir + "/";
                }
                if (Application.platform == RuntimePlatform.OSXEditor)
                {
                    int i = Application.dataPath.LastIndexOf('/');
                    return Application.dataPath.Substring(0, i + 1) + game + "/" + AppConst.PlatformPath + "/";
                }
                return "c:/" + game + "/" + AppConst.PlatformPath + "/";
            }
        }

        public static string GetRelativePath()
        {
            if (Application.isEditor)  // // 
                return "file:///" + DataPath; //+ System.Environment.CurrentDirectory.Replace("\\", "/") + "/Assets/" + AppConst.AssetRoot + "/";
            else if (Application.isMobilePlatform || Application.isConsolePlatform)
                return "file:///" + DataPath;
            else // For standalone player.
                return "file://" + Application.streamingAssetsPath + "/" + AppConst.PlatformPath + "/";
        }

        public static string GetOriginalPath()
        {
            if (Application.isEditor)
                return "file:///" + Application.dataPath + "/" + AppConst.AssetRoot + "/";
            else if (Application.isMobilePlatform || Application.isConsolePlatform)
            {
                if (Application.platform == RuntimePlatform.Android)
                    return "jar:file://" + Application.dataPath + "!/assets/" + AppConst.PlatformPath + "/";
                else if (Application.platform == RuntimePlatform.IPhonePlayer)
                    return "file:///" + Application.dataPath + "/Raw/" + AppConst.PlatformPath + "/";
                else
                    return "file:///" + Application.dataPath + "/" + AppConst.AssetRoot + "/";
            }
            else // For standalone player.
                return "file://" + Application.streamingAssetsPath + "/" + AppConst.PlatformPath + "/";
        }

        public static void WriteFileToDataPath(string name, string content)
        {
            string outfile = DataPath + name;
            string dir = Path.GetDirectoryName(outfile);
            if (!Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
            if (File.Exists(outfile))
            {
                File.Delete(outfile);
            }
            File.WriteAllText(outfile, content);
        }

        public static string ReadFileFromDataPath(string name)
        {
            string content = null;
            string outfile = DataPath + name;
            if (File.Exists(outfile))
            {
                content = File.ReadAllText(outfile);
            }
            return content;
        }

        public static string GetAvaliableRelativePath()
        {
            var needExract = NeedExtractResource();
            if (needExract)
                return GetOriginalPath();
            else
                return GetRelativePath();
        }

        public static string GetAvaliableRelativePath_File()
        {
            var needExract = NeedExtractResource();
            if (needExract)
                return GetOriginalPath_File();
            else
                return GetRelativePath_File();
        }

        public static string GetOriginalPath_File()
        {
            if (Application.isEditor)
                return Application.dataPath + "/" + AppConst.AssetRoot + "/";
            else if (Application.isMobilePlatform || Application.isConsolePlatform)
            {
                if (Application.platform == RuntimePlatform.Android)
                    return "jar:file://" + Application.dataPath + "!/assets/" + AppConst.PlatformPath + "/";
                else if (Application.platform == RuntimePlatform.IPhonePlayer)
                    return Application.dataPath + "/Raw/" + AppConst.PlatformPath + "/";
                else
                    return "file:///" + Application.dataPath + "/" + AppConst.AssetRoot + "/";
            }
            else // For standalone player.
                return "file://" + Application.streamingAssetsPath + "/" + AppConst.PlatformPath + "/";
        }

        public static string GetRelativePath_File()
        {
            if (Application.isEditor)  // // 
                return DataPath; //+ System.Environment.CurrentDirectory.Replace("\\", "/") + "/Assets/" + AppConst.AssetRoot + "/";
            else if (Application.isMobilePlatform || Application.isConsolePlatform)
                return DataPath;
            else // For standalone player.
                return Application.streamingAssetsPath + "/" + AppConst.PlatformPath + "/";
        }


        /// <summary>
        /// 应用程序内容路径
        /// </summary>
        public static string AppContentPath()
        {
            string path = string.Empty;
            switch (Application.platform)
            {
                case RuntimePlatform.Android:
                    path = Application.streamingAssetsPath + "/" + AppConst.PlatformPath + "/";
                    break;
                case RuntimePlatform.IPhonePlayer:
                    path = Application.streamingAssetsPath + "/" + AppConst.PlatformPath + "/";
                    break;
                default:
                    path = Application.streamingAssetsPath + "/" + AppConst.PlatformPath + "/";
                    break;
            }
            return path;
        }

        public static string AppRootPath()
        {
            string path = string.Empty;
            switch (Application.platform)
            {
                case RuntimePlatform.Android:
                    path = "jar:file://" + Application.dataPath + "!/assets/" + AppConst.PlatformPath + "/";
                    break;
                case RuntimePlatform.IPhonePlayer:
                    path = Application.dataPath + "/Raw/" + AppConst.PlatformPath + "/";
                    break;
                default:
                    path = Application.dataPath + "/" + AppConst.AssetRoot + "/";
                    break;
            }
            return path;
        }

        /// <summary>
        /// 取得行文本
        /// </summary>
        public static string GetFileText(string path)
        {
            return File.ReadAllText(path);
        }

        /// <summary>
        /// 网络可用
        /// </summary>
        public static bool NetAvailable
        {
            get
            {
                return Application.internetReachability != NetworkReachability.NotReachable;
            }
        }

        /// <summary>
        /// 是否是无线
        /// </summary>
        public static bool IsWifi
        {
            get
            {
                return Application.internetReachability == NetworkReachability.ReachableViaLocalAreaNetwork;
            }
        }

        public static void SetLogLevel(int level)
        {
            GameCore.BaseLogger.level = (LogLevel)level;
        }

        public static void Log(params object[] pars)
        {
            XDebug.Log.l(pars);
        }

        public static void LogWarning(string str)
        {
            XDebug.Log.warning(str);
        }

        public static void LogError(string str)
        {
            XDebug.Log.error(str);
        }


        /// <summary>
        /// 防止初学者不按步骤来操作
        /// </summary>
        /// <returns></returns>
        public static int CheckRuntimeFile()
        {
            if (!Application.isEditor) return 0;
            string streamDir = Application.dataPath + "/" + AppConst.AssetRoot + "/";
            if (!Directory.Exists(streamDir))
            {
                return -1;
            }
            else
            {
                string[] files = Directory.GetFiles(streamDir);
                if (files.Length == 0) return -1;

                if (!File.Exists(streamDir + AppConst.LoadingMD5Flie))
                {
                    return -1;
                }
            }
            string sourceDir = AppConst.FrameworkRoot + "/ToLua/Source/Generate/";
            if (!Directory.Exists(sourceDir))
            {
                return -2;
            }
            else
            {
                string[] files = Directory.GetFiles(sourceDir);
                if (files.Length == 0) return -2;
            }
            return 0;
        }

        /// <summary>
        /// 执行Lua方法
        /// </summary>
        public static void CallMethod(string module, string func, params object[] args)
        {
            App.LuaMgr.CallFunction(module + "." + func, args);
        }

        /// <summary>
        /// 检查运行环境
        /// </summary>
        public static bool CheckEnvironment()
        {
#if UNITY_EDITOR
            int resultId = Util.CheckRuntimeFile();
            if (resultId == -1)
            {
                Debug.LogError("没有找到框架所需要的资源，单击Game菜单下Build xxx Resource生成！！");
                EditorApplication.isPlaying = false;
                return false;
            }
            else if (resultId == -2)
            {
                Debug.LogError("没有找到Wrap脚本缓存，单击Lua菜单下Gen Lua Wrap Files生成脚本！！");
                EditorApplication.isPlaying = false;
                return false;
            }
            if (Application.loadedLevelName == "Test" && !AppConst.DebugMode)
            {
                Debug.LogError("测试场景，必须打开调试模式，AppConst.DebugMode = true！！");
                EditorApplication.isPlaying = false;
                return false;
            }
#endif
            return true;
        }

        /// <summary>
        /// 添加点击事件
        /// </summary>
        public static void AddClick(GameObject go, LuaFunction luafunc)
        {
            if (go == null || luafunc == null) return;
            Button btn = go.GetComponent<Button>();
            if (btn == null) return;
            go.GetComponent<Button>().onClick.AddListener(
                delegate ()
                {
                    luafunc.Call(go);
                }
            );
        }

        /// <summary>
        /// 添加点击事件,移除上一个注册的事件
        /// </summary>
        public static void AddOnceClick(GameObject go, LuaFunction luafunc)
        {
            if (go == null || luafunc == null) return;
            Button btn = go.GetComponent<Button>();
            if (btn == null) return;

            go.GetComponent<Button>().onClick.RemoveAllListeners();
            go.GetComponent<Button>().onClick.AddListener(
                delegate ()
                {
                    luafunc.Call(go);
                }
            );


        }

        /// <summary>
        /// 添加长按事件,移除上一个注册的事件
        /// </summary>
        public static void AddLongPressClick(GameObject go, LuaFunction luafunc, float interval)
        {
            if (go == null || luafunc == null) return;
            var lpb = go.GetComponent<LongPressButton>();
            if (lpb == null)
            {
                lpb = go.AddComponent<LongPressButton>();
            }
            lpb.interval = interval;
            lpb.onLongPress.RemoveAllListeners();
            lpb.onLongPress.AddListener(
                delegate ()
                {
                    luafunc.Call(go);
                }
            );
        }

        public static void AddDropDownOption(GameObject go, string optionName)
        {
            if (go == null) return;
            go.GetComponent<Dropdown>().AddOptions(new List<string> { optionName });
        }

        public static void AddDropDownOptionEvent(GameObject go, LuaFunction luafunc)
        {
            if (go == null || luafunc == null) return;
            go.GetComponent<Dropdown>().onValueChanged.AddListener(
                index =>
                {
                    luafunc.Call(index);
                }
            );
        }

        public static void AddScrollBar(GameObject go, LuaFunction luafunc)
        {
            if (go == null || luafunc == null) return;
            go.GetComponent<Scrollbar>().onValueChanged.AddListener(
                delegate (float value)
                {
                    luafunc.Call(go, value);
                }
            );
        }

        public static void AddSlider(GameObject go, LuaFunction luafunc)
        {
            if (go == null || luafunc == null) return;
            go.GetComponent<Slider>().onValueChanged.AddListener(
                delegate (float value)
                {
                    luafunc.Call(go, value);
                }
            );
        }

        public static void AddToggle(GameObject go, LuaFunction func)
        {
            if (go == null || func == null) return;

            go.GetComponent<Toggle>().onValueChanged.AddListener(
                delegate (bool isToggle)
                {
                    func.Call(isToggle);
                }
            );
        }

        //改变该节点下所有粒子的相对层级
        public static void AddParticleSortLayer(GameObject go, int layer)
        {
            if (go == null || layer == 0) return;

            var gos2 = go.GetComponentsInChildren<Renderer>(true);
            for (int i = 0; i < gos2.Length; i++)
            {
                gos2[i].GetComponent<Renderer>().sortingOrder += layer;
            }
        }

        public static void SetParticleSortLayer(GameObject go, int layer)
        {
            if (go == null) return;

            var gos2 = go.GetComponentsInChildren<Renderer>(true);
            for (int i = 0; i < gos2.Length; i++)
            {
                gos2[i].GetComponent<Renderer>().sortingOrder = layer;
            }
        }

        //改变该节点下所有粒子的整体缩放比例
        public static void SetParticleScale(GameObject go, float scale)
        {
            var hasParticleObj = false;
            var particles = go.GetComponentsInChildren<ParticleSystem>(true);
            var max = particles.Length;
            for (int idx = 0; idx < max; idx++)
            {
                var particle = particles[idx];
                if (particle == null) continue;
                hasParticleObj = true;

                var main = particle.main;
                if (main.startSize3D)
                {
                    main.startSizeXMultiplier *= scale;
                    main.startSizeYMultiplier *= scale;
                    main.startSizeZMultiplier *= scale;
                }
                else
                {
                    main.startSizeMultiplier *= scale;
                }

                if (main.startRotation3D)
                {
                    main.startRotationXMultiplier *= scale;
                    main.startRotationYMultiplier *= scale;
                    main.startRotationZMultiplier *= scale;

                }
                else
                {
                    main.startRotationMultiplier *= scale;
                }
                main.startSpeedMultiplier *= scale;
                particle.transform.localScale *= scale;
            }
            if (hasParticleObj)
            {
                go.transform.localScale = new Vector3(scale, scale, scale);
            }
        }

        public static void ClearTrailRender(GameObject go)
        {
            if (go == null) return;
            var gos = go.GetComponentsInChildren<TrailRenderer>();
            for (int i = 0; i < gos.Length; i++)
            {
                gos[i].Clear();
            }
        }

        #region ugui控件修改值不触发事件
        static Slider.SliderEvent emptySliderEvent = new Slider.SliderEvent();
        public static void SliderSet(Slider instance, float value)
        {
            var originalEvent = instance.onValueChanged;
            instance.onValueChanged = emptySliderEvent;
            instance.value = value;
            instance.onValueChanged = originalEvent;
        }

        static Toggle.ToggleEvent emptyToggleEvent = new Toggle.ToggleEvent();
        public static void ToggleSet(Toggle instance, bool value)
        {
            var originalEvent = instance.onValueChanged;
            instance.onValueChanged = emptyToggleEvent;
            instance.isOn = value;
            instance.onValueChanged = originalEvent;
        }

        static InputField.OnChangeEvent emptyInputFieldEvent = new InputField.OnChangeEvent();
        public static void InputFieldSet(InputField instance, string value)
        {
            var originalEvent = instance.onValueChanged;
            instance.onValueChanged = emptyInputFieldEvent;
            instance.text = value;
            instance.onValueChanged = originalEvent;
        }

        static Scrollbar.ScrollEvent emptyScrollEvent = new Scrollbar.ScrollEvent();
        public static void ScrollbarSet(Scrollbar instance, float value)
        {
            var originalEvent = instance.onValueChanged;
            instance.onValueChanged = emptyScrollEvent;
            instance.value = value;
            instance.onValueChanged = originalEvent;
        }

        static Dropdown.DropdownEvent emptyDropdownEvent = new Dropdown.DropdownEvent();
        public static void DropdownSet(Dropdown instance, int value)
        {
            var originalEvent = instance.onValueChanged;
            instance.onValueChanged = emptyDropdownEvent;
            instance.value = value;
            instance.onValueChanged = originalEvent;
        }
        #endregion

        public static void OpenUrl(string str)
        {
            Application.OpenURL(str);
        }

        public static void SetAudioMixer(string resName, AudioSource audioSource)
        {
            UnityEngine.Audio.AudioMixer mixer = App.ResMgr.LoadAsset("GameAudioMixer") as UnityEngine.Audio.AudioMixer;
            if (mixer != null)
            {
                UnityEngine.Audio.AudioMixerGroup group = mixer.FindMatchingGroups(resName)[0];
                if (group != null)
                {
                    audioSource.outputAudioMixerGroup = group;
                }
            }
        }

        public static void AddInputField_OnValueChanged(GameObject go, LuaFunction func)
        {
            if (go == null || func == null) return;

            go.GetComponent<InputField>().onValueChanged.AddListener(
                delegate (string str)
                {
                    func.Call(str);
                }
            );
        }

        public static void AddInputField_OnEndEdit(GameObject go, LuaFunction func)
        {
            if (go == null || func == null) return;

            go.GetComponent<InputField>().onEndEdit.AddListener(
                delegate (string str)
                {
                    func.Call(str);
                }
            );
        }

        public static void ResetRectTransform(GameObject obj)
        {
            var rect = obj.GetComponent<RectTransform>();
            if (rect == null)
                return;

            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
        }

        public static void DoLocalMove(Transform trans, float x, float y, float z, float duration)
        {
            var des = new Vector3(x, y, z);
            trans.DOLocalMove(des, duration);
        }

        public static void DoLocalMoveAdd(Transform trans, float x, float y, float z, float duration)
        {
            Vector3 curPos = trans.localPosition;
            Vector3 endPos = new Vector3(curPos.x + x, curPos.y + y, curPos.z + z);
            trans.DOLocalMove(endPos, duration);
        }

        public static void DoMoveToTarget(Transform trans, Transform target, float x, float y, float z, float duration)
        {
            trans.SetParent(target);
            Vector3 endPos = new Vector3(x, y, z);
            trans.DOLocalMove(endPos, duration);
        }

        public static void DoLocalRotate(Transform trans, float x, float y, float z, float duration)
        {
            trans.DOLocalRotate(new Vector3(x, y, z), duration, RotateMode.LocalAxisAdd);
        }

        public static void DoLocalScale(Transform trans, float x, float y, float z, float duration)
        {
            trans.DOScale(new Vector3(x, y, z), duration);
        }

        public static void DoColor(Graphic graphic, Color start, Color end, float duration)
        {
            graphic.DOKill();
            graphic.color = start;
            graphic.DOColor(end, duration);
        }

        public static void DoColor_Alpha(Graphic graphic, float startAlpha, float endAlpha, float duration)
        {
            graphic.DOKill();
            var startColor = graphic.color;
            startColor.a = startAlpha;

            var endColor = graphic.color;
            endColor.a = endAlpha;

            graphic.color = startColor;
            graphic.DOColor(endColor, duration);
        }

        public static void SetColor(Graphic graphic, Color col)
        {
            graphic.color = col;
        }

        public static void SetColorAlpha_Float(Graphic graphic, float alpha)
        {
            var tempColor = graphic.color;
            tempColor.a = alpha;
            graphic.color = tempColor;
        }

        public static void SetColorAlpha_Int(Graphic graphic, int alpha)
        {
            var tempColor = graphic.color;
            tempColor.a = (float)alpha / 255;
            graphic.color = tempColor;
        }

        public static Color GetFloatColor(float r, float g, float b)
        {
            return new Color(r / 255, g / 255, b / 255);
        }

        public static void DoLoopRotate(Transform trans, float x, float y, float z, float duration)
        {
            trans.DOKill();
            trans.DOLocalRotate(new Vector3(x, y, z), duration, RotateMode.Fast).SetLoops(-1).SetEase(Ease.Linear);
        }

        public static Transform[] GetChildrenTrans(Transform trans)
        {
            var count = trans.childCount;
            var children = new Transform[count];
            for (int i = 0; i < count; i++)
            {
                children[i] = trans.GetChild(i);
            }

            return children;
        }


        public static Sprite LoadSprite(string spriteName)
        {
            //> multiLanguage
            if(m_lan == 0)
            {
                m_lan = PlayerPrefs.GetInt("multi_language", AppConst.originLan);
            }
            //int lan = PlayerPrefs.GetInt("multi_language", AppConst.originLan);
            int L = ((int)Math.Floor((double)(m_lan / 100))) % 100;
            //Debug.LogError(L);
            string _spriteName = spriteName;
            Log("_spriteName:"+_spriteName);
            
            if (_spriteName=="_zh")
            {
                return null;
            }
            
            if (!string.IsNullOrEmpty(_spriteName))
            {
                if(L != 0)
                {
                    if(_spriteName.EndsWith("_zh"))
                    {
                        #region 替换下面注释的代码

                        if(MultiLanguageHelper.MultiLanguageDictionary.ContainsKey(L))
                        {
                            _spriteName = _spriteName.Substring(0, _spriteName.Length - 3) + MultiLanguageHelper.MultiLanguageDictionary[L].SpriteNameSuffix;
                        }

                        #endregion

                        //if(L == 1)
                        //{
                        //    _spriteName = _spriteName.Substring(0, _spriteName.Length - 3) + "_en";
                        //}else if(L == 2)
                        //{

                        //}
                    }
                }

                if (!_spriteName.StartsWith("cn2-"))
                {
                    _spriteName = "cn2-" + _spriteName;
                }
            }
           
            return App.ResMgr.LoadAsset<Sprite>(_spriteName);
        }

        public static void LoadSpriteAsync(string spriteName, Image image)
        {
            App.ResMgr.LoadAssetAsync<Sprite>(spriteName, (tmpName, sprite) =>
            {
                image.sprite = sprite;
            });
        }

        public static void SetGray(GameObject go, bool isGray)
        {
            Material m = App.ResMgr.LoadAsset<Material>("UI-DefaultGray");
            //Material sm = App.ResMgr.LoadAsset<Material>("SkeletonGraphicDefault");

            var images = go.GetComponentsInChildren<MaskableGraphic>(true);
            for (int i = 0; i < images.Length; i++)
            {
                var mate = images[i].material;

                if (mate == null) continue;
                if (mate == Image.defaultGraphicMaterial && isGray)
                {
                    images[i].material = m;
                }
                else if (mate == m && !isGray)
                {
                    images[i].material = Image.defaultGraphicMaterial;
                }
            }
        }

        public static void SetSpineGray(SkeletonGraphic sg, bool isGray)
        {
            Material m = App.ResMgr.LoadAsset<Material>("UI-DefaultGray");
            Material sm = App.ResMgr.LoadAsset<Material>("SkeletonGraphicDefault");

            if (sg.material == null) return;
            if (sg.material == sm && isGray)
            {
                sg.material = m;
            }
            else if (sg.material == m && !isGray)
            {
                sg.material = sm;
            }

        }

        public static void SetColor(GameObject go, Color color)
        {
            var images = go.GetComponentsInChildren<Image>();
            for (int i = 0; i < images.Length; i++)
            {
                images[i].color = color;
            }
        }

        public static void SetChildrenParent(Transform from, Transform to)
        {
            if (from == null || to == null)
                return;

            var count = from.childCount;
            for (int i = 0; i < count; i++)
            {
                from.GetChild(i).SetParent(to);
            }
        }

        public static void SetPosition(Transform trans, float x, float y, float z)
        {
            trans.position = new Vector3(x, y, z);
        }

        public static void SetPositionX(Transform trans, float x)
        {
            trans.position = new Vector3(x, trans.position.y, trans.position.z);
        }

        public static void SetPositionY(Transform trans, float y)
        {
            trans.position = new Vector3(trans.position.x, y, trans.position.z);
        }

        public static void SetPositionZ(Transform trans, float z)
        {
            trans.position = new Vector3(trans.position.x, trans.position.y, z);
        }

        public static void SetLocalPosition(Transform trans, float x, float y, float z)
        {
            trans.localPosition = new Vector3(x, y, z);
        }

        public static void SetLocalPositionX(Transform trans, float x)
        {
            trans.localPosition = new Vector3(x, trans.localPosition.y, trans.localPosition.z);
        }

        public static void SetLocalPositionY(Transform trans, float y)
        {
            trans.localPosition = new Vector3(trans.localPosition.x, y, trans.localPosition.z);
        }

        public static void SetLocalPositionZ(Transform trans, float z)
        {
            trans.localPosition = new Vector3(trans.localPosition.x, trans.localPosition.y, z);
        }

        public static void SetEulerAngles(Transform trans, float x, float y, float z)
        {
            trans.eulerAngles = new Vector3(x, y, z);
        }

        public static void SetEulerAnglesX(Transform trans, float x)
        {
            trans.eulerAngles = new Vector3(x, trans.eulerAngles.y, trans.eulerAngles.z);
        }

        public static void SetEulerAnglesY(Transform trans, float y)
        {
            trans.eulerAngles = new Vector3(trans.eulerAngles.x, y, trans.eulerAngles.z);
        }

        public static void SetEulerAnglesZ(Transform trans, float z)
        {
            trans.eulerAngles = new Vector3(trans.eulerAngles.x, trans.eulerAngles.y, z);
        }

        public static void SetLocalEulerAngles(Transform trans, float x, float y, float z)
        {
            trans.localEulerAngles = new Vector3(x, y, z);
        }

        public static void SetLocalEulerAnglesX(Transform trans, float x)
        {
            trans.localEulerAngles = new Vector3(x, trans.localEulerAngles.y, trans.localEulerAngles.z);
        }

        public static void SetLocalEulerAnglesY(Transform trans, float y)
        {
            trans.localEulerAngles = new Vector3(trans.localEulerAngles.x, y, trans.localEulerAngles.z);
        }

        public static void SetLocalEulerAnglesZ(Transform trans, float z)
        {
            trans.localEulerAngles = new Vector3(trans.localEulerAngles.x, trans.localEulerAngles.y, z);
        }

        public static void SetLocalScale(Transform trans, float x, float y, float z)
        {
            trans.localScale = new Vector3(x, y, z);
        }

        public static void SetLocalScaleX(Transform trans, float x)
        {
            trans.localScale = new Vector3(x, trans.localScale.y, trans.localScale.z);
        }

        public static void SetLocalScaleY(Transform trans, float y)
        {
            trans.localScale = new Vector3(trans.localScale.x, y, trans.localScale.z);
        }

        public static void SetLocalScaleZ(Transform trans, float z)
        {
            trans.localScale = new Vector3(trans.localScale.x, trans.localScale.y, z);
        }

        public static void SetRotation(Transform trans, float x, float y, float z)
        {
            trans.rotation = Quaternion.Euler(new Vector3(x, y, z));
        }

        public static void SetLocalRotation(Transform trans, float x, float y, float z)
        {
            trans.localRotation = Quaternion.Euler(new Vector3(x, y, z));
        }

        public static string Base64Encode(string source)
        {
            string encode = string.Empty;
            byte[] bytes = Encoding.UTF8.GetBytes(source);
            try
            {
                encode = Convert.ToBase64String(bytes);
            }
            catch
            {
                encode = source;
            }
            return encode;
        }
        public static string MD5Encrypt(string str)
        {
            var md5 = new MD5CryptoServiceProvider();
            var bytes = Encoding.ASCII.GetBytes(str);
            var encoded = md5.ComputeHash(bytes);
            var sb = new StringBuilder();
            foreach (var c in encoded)
                sb.Append(c.ToString("x2"));
            return sb.ToString();
        }

        public static Component GetComponentInChildren(GameObject go, string assemblyString, string typeName, bool includeInactive)
        {
            Type type = null;

            if (string.IsNullOrEmpty(assemblyString))
            {
                type = Type.GetType(typeName);
            }
            else
            {
                type = Assembly.Load(assemblyString).GetType(typeName);
            }
            var a = go.GetComponentInChildren(type, includeInactive);
            return a;
        }

        public static Component[] GetComponentsInChildren(GameObject go, string assemblyString, string typeName, bool includeInactive)
        {
            Type t = typeof(MeshRenderer);

            Type type = null;

            if (string.IsNullOrEmpty(assemblyString))
            {
                type = Type.GetType(typeName);
            }
            else
            {
                type = Assembly.Load(assemblyString).GetType(typeName);
            }
            return go.GetComponentsInChildren(type, includeInactive);
        }

        /// <summary>
        /// 3D世界坐标转UI坐标
        /// </summary>
        /// <param name="camera3D">3D摄像机</param>
        /// <param name="worldPos">世界坐标点</param>
        /// <param name="cameraUI">2D摄像机</param>
        /// <param name="rectTransform">容器</param>
        /// <returns>矩形内位置</returns>
        public static Vector3 WorldToLocalInRect(Camera camera3D, Vector3 worldPos, Camera cameraUI, RectTransform rectTransform)
        {
            Vector2 screenPos = camera3D.WorldToScreenPoint(worldPos);

            Vector2 pos;
            RectTransformUtility.ScreenPointToLocalPointInRectangle(rectTransform, screenPos, cameraUI, out pos);

            return pos;
        }

        //缓存SetColor_Spine方法的参数,避免重复new
        public static MaterialPropertyBlock SetColor_Spine_props = new MaterialPropertyBlock();
        /// <summary>
        /// 设置Spine的颜色
        /// </summary>
        /// <param name="transform"></param>
        /// <param name="color"></param>
        public static void SetColor_Spine(SkeletonAnimation skeletonAnimation, Color color)
        {
            MeshRenderer renderer = skeletonAnimation.GetComponent<MeshRenderer>();
            if (renderer != null)
            {
                SetColor_Spine_props.SetColor("_Color", color);

                renderer.SetPropertyBlock(SetColor_Spine_props);
            }

            renderer.GetPropertyBlock(SetColor_Spine_props);
        }

        /// <summary>
        /// 获得Spine的颜色
        /// </summary>
        /// <param name="skeletonAnimation"></param>
        /// <returns></returns>
        public static Color GetColor_Spine(SkeletonAnimation skeletonAnimation)
        {
            MeshRenderer renderer = skeletonAnimation.GetComponent<MeshRenderer>();
            if (renderer != null)
            {
                renderer.GetPropertyBlock(SetColor_Spine_props);

                return SetColor_Spine_props.GetColor("_Color");
            }

            return Color.white;
        }

        /// <summary>
        /// 颜色变化动画
        /// </summary>
        /// <param name="skeletonAnimation"></param>
        /// <param name="start"></param>
        /// <param name="end"></param>
        /// <param name="duration"></param>
        /// <returns></returns>
        public static Tweener DoColor_Spine(SkeletonAnimation skeletonAnimation, Color start, Color end, float duration)
        {
            skeletonAnimation.DOKill();

            return DOTween.To(delegate ()
            {
                return start;
            },
            delegate (Color color)
            {
                SetColor_Spine(skeletonAnimation, color);
            },
            end,
            duration);
        }

        /// <summary>
        /// 颜色变化动画
        /// </summary>
        /// <param name="skeletonAnimation"></param>
        /// <param name="end"></param>
        /// <param name="duration"></param>
        /// <returns></returns>
        public static Tweener DoColor_Spine(SkeletonAnimation skeletonAnimation, Color end, float duration)
        {
            skeletonAnimation.DOKill();

            Color start = GetColor_Spine(skeletonAnimation);
            return DoColor_Spine(skeletonAnimation, start, end, duration);
        }

        /// <summary>
        /// 获得动画时长
        /// </summary>
        /// <param name="animator"></param>
        /// <returns></returns>
        public static float GetAnimatorTime(Animator animator)
        {
            if (animator != null)
            {
                var runtimeAnimatorController = animator.runtimeAnimatorController;
                var animationClips = runtimeAnimatorController.animationClips;
                if (animationClips != null &&
                    animationClips.Length > 0)
                    return animationClips[0].length;
            }

            return 0;
        }
    }
}