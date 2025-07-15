using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using System.Text.RegularExpressions;
using System.IO;
using System.Text;
using System.Threading;
using System.Linq;
using System.Collections;
using GameLogic;

namespace Assets.Scripts.Editor.LanguageTool
{
    public static class LanguageTool
    {
        // key = ‘文字’ value = ‘ID'   导出数据时使用 
        private static Dictionary<string, int> L2ID = new Dictionary<string, int>();
        // key = ‘ID’ value = ‘文字’  导入数据时使用 
        private static Dictionary<int, string> ID2L = new Dictionary<int, string>();
        private static Dictionary<int, string> ID2Path = new Dictionary<int, string>();
        // id自增的标志
        private static int IDFlag = 10000;

        // excel 路径
        private static string PrefrabCSVPath = Environment.CurrentDirectory + "/data_execl/Language_data/LanguageText.csv";
        private static string LuaCSVPath = Environment.CurrentDirectory + "/data_execl/Language_data/LanguageLua.csv";
        //工程中带文字的资源路径
        private static string ArtFontPath = Environment.CurrentDirectory + "/data_execl/Language_data/AtrFontPath.csv";
        // prefrab 路径
        private static string[] PrefrabPath = new string[] { "Assets/ManagedResources/Prefabs/UI", "Assets/ManagedResources/UpdatePanel" };
        //private static string[] PrefrabPath = new string[] { "Assets/ManagedResources/UpdatePanel" };
        // lua 路径
        private static string[] LuaPath = new string[] {
            "Assets/ManagedResources/~Lua/Modules",
            "Assets/ManagedResources/~Lua/View",
            "Assets/ManagedResources/~Lua/Common"
        };
        private static string[] SpecialLuaPath = new string[] {
            "Assets/ManagedResources/~Lua/Common/functions.lua",
            "Assets/ManagedResources/~Lua/Common/GlobalDefine.lua",
            "Assets/ManagedResources/~Lua/Framework/Framework.lua",
            "Assets/ManagedResources/~Lua/Logic/Network.lua",
            //"Assets/ManagedResources/~Lua/Modules/DynamicActivity/ShengXingYouLi.lua"
        };
        private static string[] ExceptLuaPath = new string[] {
            "Assets/ManagedResources/~Lua/Modules/Main/GMPanel.lua"
        };
        

        // lua数据文件路径
        private static string LuaDataPath = "Assets/ManagedResources/~Lua/Common/Language.lua";
        // 
        private static System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();

        // 从本地加载文字数据
        private static void LoadLDataFromCSV(string CSVPath)
        {
            ClearLData();

            if (!File.Exists(CSVPath))
            {
                File.Create(CSVPath).Dispose();
            }
            
            //
            time.Start();
            string[] filestr = File.ReadAllLines(CSVPath, System.Text.Encoding.Default);
            if(filestr.Length == 1)
            {
                EditorUtility.ClearProgressBar();
                return;
            }
            for (int i = 0; i < filestr.Length; i++)
            {
                EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, filestr.Length), "正在导入表数据：", (float)i / filestr.Length);
                string[] strList = filestr[i].Split(',');
                int id = Convert.ToInt32(strList[0]);
                string L = DecodeStr(strList[1]);
                string path = DecodeStr(strList[2]);
                if (!L2ID.ContainsKey(L))
                {
                    L2ID.Add(L, id);
                }
                ID2L.Add(id, L);
                ID2Path.Add(id, path);
                if (i + 1 == filestr.Length)
                {
                    IDFlag = id;
                }
            }
            time.Stop();
            EditorUtility.ClearProgressBar();
        }
        // 保存文字数据到本地
        private static void SaveLDataToCSV(string CSVPath)
        {
            if (!File.Exists(CSVPath))
            {
                File.Create(CSVPath).Dispose();
            }
            time.Start();
            string[] strList = new string[ID2L.Keys.Count];
            int i = 0;
            foreach (int id in ID2L.Keys)
            {
                EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, ID2L.Keys.Count), "正在保存数据到本地：", (float)i / ID2L.Keys.Count);
                string value = "";
                ID2L.TryGetValue(id, out value);
                value = EncodeStr(value);
                strList[i] = id + "," + value;
                i++;
            }
            File.WriteAllLines(CSVPath, strList, System.Text.Encoding.Default);
            time.Stop();
            EditorUtility.ClearProgressBar();
        }


        // 将数据写入lua文件
        private static void WriteToLuaData()
        {
            if (!File.Exists(LuaDataPath))
            {
                File.Create(LuaDataPath).Dispose();
            }

            time.Start();
            // 构建数据
            int keyCount = ID2L.Keys.Count;
            string[] strList = new string[keyCount+2];
            strList[0] = "Language = {";
            int i = 1;
            foreach (int id in ID2L.Keys)
            {
                EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, keyCount), "正在生成数据：", (float)i / keyCount);
                string value = "";
                ID2L.TryGetValue(id, out value);
                // 一些转义字符要处理
                value = value.Replace("\n", "\\n");

                strList[i] = "\t[" + id + "] = GetLanguageStrById(" + id + "),";
                i++;
            }
            strList[i] = "}";

            // 写入lua文件
            EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", keyCount, keyCount), "正在写入Language.lua：", 0);
            File.WriteAllLines(LuaDataPath, strList, System.Text.Encoding.UTF8);

            // 停止
            time.Stop();
            EditorUtility.ClearProgressBar();
        }

        // 清空本地数据
        private static void ClearLData()
        {
            L2ID.Clear();
            ID2L.Clear();
            ID2Path.Clear();
            IDFlag = 10000;
        }
        //添加数据 返回数据的ID
        private static int AddLData(string L, string path = "")
        {
            int id = 0;
            if (L2ID.TryGetValue(L, out id))
            {
                return id;
            }
            else
            {
                id = ++IDFlag;
                L2ID.Add(L, id);
                ID2L.Add(id, L);
                ID2Path.Add(id, path);
                Debug.LogWarning("新增：" + id + "|" + L);
                return id;
            }
        }


        private static string EncodeStr(string txt)
        {
            txt = txt.Replace("\n", "\\n");
            txt = txt.Replace("\r", "\\r");
            txt = txt.Replace(",", "\\，");
            txt = txt.Replace("\"", "\\\"");
            return txt;
        }
        private static string DecodeStr(string txt)
        {
            txt = txt.Replace("\\n", "\n");
            txt = txt.Replace("\\r", "\r");
            txt = txt.Replace("\\，", ",");
            txt = txt.Replace("\\\"", "\"");
            return txt;
        }


        // 将Text替换为LanguageText,并拷贝属性
        private static void changeTextToLanguageText(Transform tr)
        {
            Text t = tr.GetComponent<Text>();
            Color color = t.color;
            Font font = t.font;
            FontStyle fontStyle = t.fontStyle;
            int fontSize = t.fontSize;
            bool supportRichText = t.supportRichText;
            string text = t.text;
            float lineSpacing = t.lineSpacing;
            TextAnchor alignment = t.alignment;
            HorizontalWrapMode horizontalOverflow = t.horizontalOverflow;
            VerticalWrapMode verticalOverflow = t.verticalOverflow;
            bool resizeTextForBestFit = t.resizeTextForBestFit;
            int resizeTextMinSize = t.resizeTextMinSize;
            int resizeTextMaxSize = t.resizeTextMaxSize;
            bool raycastTarget = t.raycastTarget;
            UnityEngine.Object.DestroyImmediate(t, true);

            LanguageText lt = tr.gameObject.GetComponent<LanguageText>()? tr.gameObject.GetComponent<LanguageText>() : tr.gameObject.AddComponent<LanguageText>();
            lt.LanguageIndex = 0;
            lt.color = color;
            lt.font = font;
            lt.fontStyle = fontStyle;
            lt.fontSize = fontSize;
            lt.supportRichText = supportRichText;
            lt.text = text;
            lt.lineSpacing = lineSpacing;
            lt.alignment = alignment;
            lt.horizontalOverflow = horizontalOverflow;
            lt.verticalOverflow = verticalOverflow;
            lt.resizeTextForBestFit = resizeTextForBestFit;
            lt.resizeTextMinSize = resizeTextMinSize;
            lt.resizeTextMaxSize = resizeTextMaxSize;
            lt.raycastTarget = raycastTarget;
        }



        // 将LanguageText替换为Text,并拷贝属性
        private static void changeLanguageTextToText(Transform tr)
        {
            LanguageText t = tr.GetComponent<LanguageText>();
            Color color = t.color;
            Font font = t.font;
            FontStyle fontStyle = t.fontStyle;
            int fontSize = t.fontSize;
            bool supportRichText = t.supportRichText;
            string text = t.text;
            float lineSpacing = t.lineSpacing;
            TextAnchor alignment = t.alignment;
            HorizontalWrapMode horizontalOverflow = t.horizontalOverflow;
            VerticalWrapMode verticalOverflow = t.verticalOverflow;
            bool resizeTextForBestFit = t.resizeTextForBestFit;
            int resizeTextMinSize = t.resizeTextMinSize;
            int resizeTextMaxSize = t.resizeTextMaxSize;
            bool raycastTarget = t.raycastTarget;
            
            UnityEngine.Object.DestroyImmediate(t, true);

            try
            {
                Text lt = tr.gameObject.AddComponent<Text>();
                lt.color = color;
                lt.font = font;
                lt.fontStyle = fontStyle;
                lt.fontSize = fontSize;
                lt.supportRichText = supportRichText;
                lt.text = text;
                lt.lineSpacing = lineSpacing;
                lt.alignment = alignment;
                lt.horizontalOverflow = horizontalOverflow;
                lt.verticalOverflow = verticalOverflow;
                lt.resizeTextForBestFit = resizeTextForBestFit;
                lt.resizeTextMinSize = resizeTextMinSize;
                lt.resizeTextMaxSize = resizeTextMaxSize;
                lt.raycastTarget = raycastTarget;
            }
            catch(Exception e)
            {
                Debug.LogWarning(e.Message);
            }
        }


        // 将所有包含中文的Text转为LanguageText
        //[MenuItem("LanguageTool/prefrab/Text转LanguageText")]
        public static void UITextToLanguageText()
        {
            if (EditorUtility.DisplayDialog("转换提示", "此操作会将所有Prefrab中的包含中文字符的Text组件转换为LanguageText组件，是否继续？", "是", "否")) //显示对话框
            {
               
                string[] allPath = AssetDatabase.FindAssets("t:Prefab", PrefrabPath);

                Regex reg = new Regex(@"[\u4e00-\u9fa5]");//正则表达式，判断是否包含中文字符

                time.Start();
                for (int i = 0; i < allPath.Length; i++)
                { 
                    string path = AssetDatabase.GUIDToAssetPath(allPath[i]);
                    EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, allPath.Length), "正在转换：" + path, (float)i / allPath.Length);

                    var obj = AssetDatabase.LoadAssetAtPath(path, typeof(GameObject)) as GameObject;
                    if (obj != null)
                    {
                        var newPrefab = PrefabUtility.InstantiatePrefab(obj) as GameObject;
                        var texts = newPrefab.GetComponentsInChildren<Text>(true);
                        var isChange = false;
                        foreach (var text in texts)
                        {
                            if (text.GetType().ToString() != "LanguageText" && reg.IsMatch(text.text))
                            {
                                isChange = true;
                                changeTextToLanguageText(text.transform);
                            }
                        }
                        // 改变后才保存
                        if (isChange)
                        {
                            // 检测inputField
                            CheckInputField(newPrefab);
                            Debug.Log(path);
                            PrefabUtility.SaveAsPrefabAsset(newPrefab, path);
                        }
                        UnityEngine.Object.DestroyImmediate(newPrefab);
                    }
                }
                time.Stop();
                EditorUtility.ClearProgressBar();
                Debug.Log("转换完成");
            }
        }

        // 将所有包含中文的Text转为LanguageText
        //[MenuItem("LanguageTool/prefrab/处理丢失Text的InputField")]
        public static void CheckInputField(GameObject go)
        { 
            var ips = go.GetComponentsInChildren<InputField>(true);
            foreach(var ip in ips)
            {
                ip.placeholder = ip.transform.GetChild(0).GetComponent<Text>();
                ip.textComponent = ip.transform.GetChild(1).GetComponent<Text>();
            }
        }



        // 将所有包含中文资源的预设信息导出成表
        //[MenuItem("LanguageTool/prefrab/导出带有文字资源预设信息")]
        public static void UIArtFontToCsv()
        {
            string[] exlArr = new string[2000];
            int index = 1;
            exlArr[0] = "id,预设名称,文字图片挂载对象路径,资源名称,加载图片代码";
            string artFontDir = Environment.CurrentDirectory + "\\FontArt\\ArtFont_zh\\";
            string[] files = Directory.GetFiles(artFontDir, "*.png", SearchOption.AllDirectories);
            List<string> _list = new List<string>();
            for (int i = 0; i < files.Length; i++)
            {
                string fileName = Path.GetFileNameWithoutExtension(files[i]);
                _list.Add(fileName);
            }

            string[] allPath = AssetDatabase.FindAssets("t:Prefab", PrefrabPath);
            time.Start();
            for (int i = 0; i < allPath.Length; i++)
            {
                string path = AssetDatabase.GUIDToAssetPath(allPath[i]);
                EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, allPath.Length), "正在查找：" + path, (float)i / allPath.Length);

                var obj = AssetDatabase.LoadAssetAtPath(path, typeof(GameObject)) as GameObject;
                if (obj != null)
                {
                    var newPrefab = PrefabUtility.InstantiatePrefab(obj) as GameObject;
                    var images = newPrefab.GetComponentsInChildren<Image>(true);
                    foreach (var image in images)
                    {
                        if (image.sprite != null)
                        {
                            if (_list.Contains(image.sprite.name))
                            {
                                Debug.Log(string.Format("预设名称:{0}  资源名称:{1}", newPrefab.name, image.sprite.name));
                                string _path = image.name;
                                Transform imageObj = image.transform;
                                for (int j = 0; j < 10; j++)
                                {
                                    if (imageObj.parent == null || imageObj.parent == newPrefab.transform) break;
                                    _path = imageObj.transform.parent.name + @"/" + _path;
                                    imageObj = imageObj.transform.parent;
                                }
                                Debug.Log(string.Format("文字图片挂载对象路径:{0}", _path));
                                string newImageName = image.sprite.name + "_zh";
                                string dynLoadStr = string.Format("Util.GetGameObject(self.gameObject，\"{0}\"):GetComponent(\"Image\").sprite=Util.LoadSprite(\"{1}\")", _path, newImageName);
                                string _str = string.Format("{0},{1},{2},{3},{4}", index, newPrefab.name, _path, newImageName, dynLoadStr);
                                exlArr[index] = _str;
                                index++;
                            }
                        }
                    }
                    UnityEngine.Object.DestroyImmediate(newPrefab);
                }
            }
            if (!File.Exists(ArtFontPath))
            {
                File.Create(ArtFontPath).Dispose();
            }
            File.WriteAllLines(ArtFontPath, exlArr, System.Text.Encoding.Default);
            time.Stop();
            EditorUtility.ClearProgressBar();
            Debug.Log("查找完成");
        }
        //[MenuItem("LanguageTool/prefrab/指定图片加载到预设")]
        public static void SpriteToPrefab()
        {
            if (!File.Exists(ArtFontPath))
            {
                Debug.Log("未找到此文件" + ArtFontPath);
                return;
            }
            string[] csvArr = File.ReadAllLines(ArtFontPath, System.Text.Encoding.Default);
            Dictionary<string, List<string>> dic = new Dictionary<string, List<string>>();
            for (int i = 1; i < csvArr.Length; i++)
            {
                string[] strList = csvArr[i].Split(',');
                string prefabName = DecodeStr(strList[1]);
                string imgObjPath = string.Format("{0}#{1}", DecodeStr(strList[2]), DecodeStr(strList[3]));
                if (!dic.ContainsKey(prefabName))
                {
                    List<string> list = new List<string>() { imgObjPath };
                    dic.Add(prefabName, list);
                }
                else
                {
                    dic[prefabName].Add(imgObjPath);
                }
            }

            int index = 0;
            string[] exlArr = new string[2000];
            string[] allPath = AssetDatabase.FindAssets("t:Prefab", PrefrabPath);
            for (int i = 0; i < allPath.Length; i++)
            {
                string path = AssetDatabase.GUIDToAssetPath(allPath[i]);
                string[] arr = path.Split('/');
                string prefabName = arr[arr.Length - 1].Split('.')[0];
                EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, allPath.Length), "正在导入表数据：", (float)i / allPath.Length);
                if (dic.ContainsKey(prefabName))
                {
                    string assetPath = AssetDatabase.GUIDToAssetPath(allPath[i]);
                    var obj = AssetDatabase.LoadAssetAtPath(path, typeof(GameObject)) as GameObject;
                    var newPrefab = PrefabUtility.InstantiatePrefab(obj) as GameObject;
                    if (obj != null)
                    {
                        for (int j = 0; j < dic[prefabName].Count; j++)
                        {
                            string[] obsparr = dic[prefabName][j].Split('#');
                            Debug.Log("预设名称:" + prefabName);
                            Debug.Log("挂载图片对象路径:" + obsparr[0]);
                            Debug.Log("图片资源名称:" + obsparr[1]);
                            var imageObj = newPrefab.transform.Find(obsparr[0]);
                            if (imageObj != null)
                            {
                                string[] pathList = Directory.GetFiles(Environment.CurrentDirectory + "\\Assets\\ManagedResources", string.Format("{0}.png", obsparr[1]), SearchOption.AllDirectories);
                                if (pathList.Length > 0)
                                {
                                    Image img = imageObj.GetComponent<Image>();
                                    if (img!=null)
                                    {
                                        string spStr = pathList[0].Replace("E:\\jieling_client\\", "");
                                        Debug.Log("图片资源路径：" + spStr);                                        
                                        img.sprite = AssetDatabase.LoadAssetAtPath<Sprite>(spStr);
                                    }
                                    else
                                    {
                                        Debug.LogWarning("该路径下面找不到Image组件：" + obsparr[0]);
                                    }
                                }
                            }
                            else
                            {
                                Debug.LogError("找不到此路径挂载图片对象路径:" + prefabName);
                                string _str = string.Format("{0},{1},{2}", prefabName, obsparr[0], obsparr[1]);
                                exlArr[index] = _str;
                                index++;
                            }
                        }
                    }
                    PrefabUtility.SaveAsPrefabAsset(newPrefab, path);
                    UnityEngine.Object.DestroyImmediate(newPrefab);
                }
            }
            //File.WriteAllLines(Environment.CurrentDirectory + "/data_execl/Language_data/挂载中文图片路径修改预设.csv", exlArr, System.Text.Encoding.Default);
            EditorUtility.ClearProgressBar();
        }

        // 将所有LanguageText导出为数据表
        [MenuItem("LanguageTool/prefrab/导出所有Text中文数据到LangeageText.csv")]
        public static void LanguageTextToExcel()
        {
            
            // 加载本地数据
            LoadLDataFromCSV(PrefrabCSVPath);
            // 遍历所有的LanguageText
            time.Start();
            string[] allPath = AssetDatabase.FindAssets("t:Prefab", PrefrabPath);

            Regex reg = new Regex(@"[\u4e00-\u9fa5]");//正则表达式，判断是否包含中文字符

            for (int i = 0; i < allPath.Length; i++)
            {
                string path = AssetDatabase.GUIDToAssetPath(allPath[i]);
                EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, allPath.Length), "正在检索：" + path, (float)i / allPath.Length);
                var obj = AssetDatabase.LoadAssetAtPath(path, typeof(GameObject)) as GameObject;
                if (obj != null)
                {
                    var newPrefab = PrefabUtility.InstantiatePrefab(obj) as GameObject;
                    var texts = newPrefab.GetComponentsInChildren<Text>(true);
                    foreach (var text in texts)
                    {
                        if (reg.IsMatch(text.text))
                        {
                            
                           
                            //text.LanguageIndex = lid;
                            string _path = text.name;
                            Transform imageObj = text.transform;
                            for (int k = 0; k < 15; k++)
                            {
                                if (imageObj.parent == null || imageObj.parent == newPrefab.transform)
                                {
                                    _path = imageObj.transform.parent.name + @"/" + _path;
                                    break;
                                }
                                    
                                _path = imageObj.transform.parent.name + @"/" + _path;
                                imageObj = imageObj.transform.parent;
                            }
                            int lid = AddLData(text.text, _path);
                        }
                    }
                    //PrefabUtility.SaveAsPrefabAsset(newPrefab, path);
                    UnityEngine.Object.DestroyImmediate(newPrefab);
                }
            }
            time.Stop();
            EditorUtility.ClearProgressBar();
            // 数据保存到本地
            //SaveLDataToCSV(PrefrabCSVPath);


            if (!File.Exists(PrefrabCSVPath))
            {
                File.Create(PrefrabCSVPath).Dispose();
            }
            time.Start();
            string[] strList = new string[ID2L.Keys.Count];
            int j = 0;
            foreach (int id in ID2L.Keys)
            {
                EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", j, ID2L.Keys.Count), "正在保存数据到本地：", (float)j / ID2L.Keys.Count);
                string value = "";
                ID2L.TryGetValue(id, out value);
                value = EncodeStr(value);
                string path = "";
                ID2Path.TryGetValue(id, out path);
                strList[j] = id + "," + value + "," + path;
                j++;
            }
            File.WriteAllLines(PrefrabCSVPath, strList, System.Text.Encoding.Default);
            time.Stop();
            EditorUtility.ClearProgressBar();


            // 清理本地数据
            ClearLData();
            Debug.Log("导出数据完成");
        }

        // 从数据表导入文本
        [MenuItem("LanguageTool/prefrab/导入数据表")]
        public static void LoadExcelToLanguageText()
        {
            // 加载本地数据
            LoadLDataFromCSV(PrefrabCSVPath);
            //
            time.Start();
            // 遍历所有的LanguageText
            string[] allPath = AssetDatabase.FindAssets("t:Prefab", PrefrabPath);
            for (int i = 0; i < allPath.Length; i++)
            {
                string path = AssetDatabase.GUIDToAssetPath(allPath[i]);
                EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, allPath.Length), "正在导入：" + path, (float)i / allPath.Length);
                var obj = AssetDatabase.LoadAssetAtPath(path, typeof(GameObject)) as GameObject;
                if (obj != null)
                {
                    var newPrefab = PrefabUtility.InstantiatePrefab(obj) as GameObject;
                    var texts = newPrefab.GetComponentsInChildren<LanguageText>(true);
                    foreach (var text in texts)
                    {
                        int lid = text.LanguageIndex;
                        if (lid != 0)
                        {
                            string lan = "";
                            ID2L.TryGetValue(lid, out lan);
                            text.text = lan;
                        }
                    }
                    PrefabUtility.SaveAsPrefabAsset(newPrefab, path);
                    UnityEngine.Object.DestroyImmediate(newPrefab);
                }
            }
            time.Stop();
            EditorUtility.ClearProgressBar();
            // 清理本地数据
            ClearLData();
            Debug.Log("导入数据完成");
        }

        // 将所有包含中文的LanguageText转为Text
        // 暂时屏蔽此功能
        //[MenuItem("LanguageTool/prefrab/LanguageText转Text")]
        public static void UILanguageTextToText()
        {
            if (EditorUtility.DisplayDialog("转换提示", "此操作会将所有Prefrab中的LanguageText组件转换为Text组件，是否继续？", "是", "否")) //显示对话框
            {

                string[] allPath = AssetDatabase.FindAssets("t:Prefab", PrefrabPath);

                time.Start();
                for (int i = 0; i < allPath.Length; i++)
                {
                    string path = AssetDatabase.GUIDToAssetPath(allPath[i]);
                    EditorUtility.DisplayProgressBar(string.Format("({0}/{1})", i, allPath.Length), "正在转换：" + path, (float)i / allPath.Length);

                    var obj = AssetDatabase.LoadAssetAtPath(path, typeof(GameObject)) as GameObject;
                    if (obj != null)
                    {
                        var newPrefab = PrefabUtility.InstantiatePrefab(obj) as GameObject;
                        var texts = newPrefab.GetComponentsInChildren<LanguageText>(true);
                        var isChange = false;
                        foreach (var text in texts)
                        {
                            isChange = true;
                            changeLanguageTextToText(text.transform);
                        }
                        // 改变后才保存
                        if (isChange)
                        {
                            // 检测inputField
                            CheckInputField(newPrefab);
                            PrefabUtility.SaveAsPrefabAsset(newPrefab, path);
                        }
                        UnityEngine.Object.DestroyImmediate(newPrefab);
                    }
                }
                time.Stop();
                EditorUtility.ClearProgressBar();
                Debug.Log("转换完成");
            }
        }

        /// <summary>
        /// -------------------------------------------------lua 
        /// </summary>
        /// 

        private static bool IsExceptLuaPath(string path)
        {
            foreach(string eptName in ExceptLuaPath)
            {
                if (path.Replace("\\", "/").Equals(eptName))
                {
                    return true;
                }
            }
            return false;
        }

        // 遍历lua文件的每一行找到 中文数据并替换
        private static void CheckLuaPath(string path)
        {
            if (IsExceptLuaPath(path))
            {
                Debug.Log("Except lua file: " + path);
                return;
            }
            string[] lines = File.ReadAllLines(path, System.Text.Encoding.UTF8);
            if (lines.Length <= 0)
            {
                return;
            }
            string[] wlines = new string[lines.Length - 1];
            string lastLine = "";
            for (int lIndex = 0; lIndex < lines.Length; lIndex++)
            {
                string line = lines[lIndex].Trim();
                if (!line.StartsWith("--") && !line.StartsWith("Log"))
                {
                    Regex reg = new Regex("\"[^\"]*?[\u4e00-\u9fa5][^\"]*?\"");//正则表达式，判断是否包含中文字符
                    if (reg.IsMatch(line))
                    {
                        MatchCollection mc = reg.Matches(line);
                        for (int mi = 0; mi < mc.Count; mi++)
                        {
                            string s = mc[mi].Value.Trim('"');
                            // 这里做个转换，否则可能导致包含转义字符的文字重复导出
                            s = s.Replace("\\n", "\n");
                            int id = AddLData(s);
                            lines[lIndex] = lines[lIndex].Replace(mc[mi].Value, "Language[" + id + "]");
                        }
                    }
                }

                if (lIndex == lines.Length - 1)
                {
                    lastLine = lines[lIndex];
                }
                else
                {
                    wlines[lIndex] = lines[lIndex];
                }
            }
            File.WriteAllLines(path, wlines, System.Text.Encoding.UTF8);
            File.AppendAllText(path, lastLine, System.Text.Encoding.UTF8);
        }
        // 遍历lua文件的每一行找到 中文数据并替换
        private static void RevertLuaPath(string path, Dictionary<int, string> o)
        {
            string[] lines = File.ReadAllLines(path, System.Text.Encoding.UTF8);
            if (lines.Length <= 0)
            {
                return;
            }
            string[] wlines = new string[lines.Length - 1];
            string lastLine = "";
            for (int lIndex = 0; lIndex < lines.Length; lIndex++)
            {
                string line = lines[lIndex].Trim();
                Regex reg = new Regex("Language\\[[^Language\\[]*?[0-9][^\\]]*?\\]");//正则表达式，判断是否包含中文字符
                if (reg.IsMatch(line))
                {
                    MatchCollection mc = reg.Matches(line);
                    for (int mi = 0; mi < mc.Count; mi++)
                    {
                        string r = mc[mi].Value.Trim();
                        int id = Convert.ToInt32(r.Substring(9, 5));
                        string t;
                        o.TryGetValue(id, out t);
                        if(t == null)
                        {
                            t = "\"未找到文字\"";
                            Debug.LogError(path + " : " + id + " 未找到文字");
                        }
                        lines[lIndex] = lines[lIndex].Replace(r, t);
                    }
                }

                if (lIndex == lines.Length - 1)
                {
                    lastLine = lines[lIndex];
                }
                else
                {
                    wlines[lIndex] = lines[lIndex];
                }
            }
            File.WriteAllLines(path, wlines, System.Text.Encoding.UTF8);
            File.AppendAllText(path, lastLine, System.Text.Encoding.UTF8);
        }

        // 遍历所有的可能包含中文文本的lua文件
        //[MenuItem("LanguageTool/lua/导出lua文本")]
        public static void ExportLanguageFromLua()
        {
            // 加载本地数据
            LoadLDataFromCSV(LuaCSVPath);

            time.Start();
            // 检索
            for (int i = 0; i < LuaPath.Length; i++)
            {
                string folderPath = LuaPath[i];
                string[] pathList = Directory.GetFiles(folderPath, "*.lua", SearchOption.AllDirectories);
                for (int pIndex = 0; pIndex < pathList.Length; pIndex++)
                {
                    EditorUtility.DisplayProgressBar(string.Format(folderPath + "({0}/{1})", pIndex, pathList.Length), "正在检索数据：", (float)pIndex / pathList.Length);
                    CheckLuaPath(pathList[pIndex]);
                }
            }
            // 特殊lua文件
            for (int pIndex = 0; pIndex < SpecialLuaPath.Length; pIndex++)
            {
                EditorUtility.DisplayProgressBar(SpecialLuaPath[pIndex], "正在检索数据：", (float)pIndex / SpecialLuaPath.Length);
                CheckLuaPath(SpecialLuaPath[pIndex]);
            }

            // 停止
            time.Stop();
            EditorUtility.ClearProgressBar();

            // 保存数据到本地
            SaveLDataToCSV(LuaCSVPath);
            // 将数据写入lua
            WriteToLuaData();
            // 清理本地数据
            ClearLData();
            // 
            Debug.Log("导出完成");
        }

        // 遍历所有的可能包含中文文本的lua文件
        //[MenuItem("LanguageTool/lua/测试")]
        public static void CheckLanguage()
        {
            // 加载本地数据
            LoadLDataFromCSV(LuaCSVPath);
            int id = AddLData("第\n%s\n天");
            Debug.Log(id);
            // 清理本地数据
            ClearLData();
            // 
            Debug.Log("导出完成");
        }


        // LanguageLua.csv转换为Language.lua
        //[MenuItem("LanguageTool/lua/生成Language.lua")]
        public static void LoadLuaCSVToLuaData()
        {
            // 加载本地数据
            LoadLDataFromCSV(LuaCSVPath);
            // 将数据写入lua
            WriteToLuaData();
            // 清理本地数据
            ClearLData();
            //
            Debug.Log("数据已生成");
        }


        // 将language.lua中的中文还原到代码中
        //[MenuItem("LanguageTool/lua/Revert Language To Code")]
        private static void RevertLanguage()
        {
            Dictionary<int, string> o = ReadFromLanguage();

            // 检索
            for (int i = 0; i < LuaPath.Length; i++)
            {
                string folderPath = LuaPath[i];
                string[] pathList = Directory.GetFiles(folderPath, "*.lua", SearchOption.AllDirectories);
                for (int pIndex = 0; pIndex < pathList.Length; pIndex++)
                {
                    EditorUtility.DisplayProgressBar(string.Format(folderPath + "({0}/{1})", pIndex, pathList.Length), "正在还原数据：" + pathList[pIndex], (float)pIndex / pathList.Length);
                    RevertLuaPath(pathList[pIndex], o);
                }
            }
            // 特殊lua文件
            for (int pIndex = 0; pIndex < SpecialLuaPath.Length; pIndex++)
            {
                EditorUtility.DisplayProgressBar(SpecialLuaPath[pIndex], "正在还原数据：", (float)pIndex / SpecialLuaPath.Length);
                RevertLuaPath(SpecialLuaPath[pIndex], o);
            }


            EditorUtility.ClearProgressBar();


        }

        // 从language.lua中读取数据
        //[MenuItem("LanguageTool/lua/读取language.lua")]
        private static Dictionary<int, string> ReadFromLanguage()
        {

            // 加载本地数据
            LoadLDataFromCSV(LuaCSVPath);

            Dictionary<int, string> o = new Dictionary<int, string>();
            //
            if (!File.Exists(LuaDataPath))
            {
                Debug.LogError("未找到language.lua");
                return o;
            }
            //
            string[] lines = File.ReadAllLines(LuaDataPath, System.Text.Encoding.UTF8);
            if (lines.Length <= 0)
            {
                return o;
            }
            //
            for (int i = 0; i < lines.Length; i++)
            {
                string str = lines[i].Trim();
                if (str.StartsWith("["))
                {
                    int num = Convert.ToInt32(str.Substring(1, 5));
                    //string content = str.Substring(10, str.Length - 11);
                    string content = str.Substring(29, str.Length - 31);
                    Debug.Log(content);
                    o.Add(num, content);
                }
            }
            // 清理本地数据
            ClearLData();
            return o;
        }


        public static void WriteAllLinesBetter(string path, params string[] lines)
        {
            if (path == null)
                throw new ArgumentNullException("path");
            if (lines == null)
                throw new ArgumentNullException("lines");

            using (var stream = File.OpenWrite(path))
            {
                stream.SetLength(0);
                
                using (var writer = new StreamWriter(stream, System.Text.Encoding.UTF8))
                //using (var writer = new StreamWriter(stream, new System.Text.UTF8Encoding(false)))
                {
                    if (lines.Length > 0)
                    {
                        for (var i = 0; i < lines.Length - 1; i++)
                        {
                            writer.WriteLine(lines[i]);
                        }
                        writer.Write(lines[lines.Length - 1]);
                    }
                }
            }
        }


        // 遍历lua文件的每一行找到 log打印并删除
        //[MenuItem("LanguageTool/lua/删除Log打印")]
        private static void DeleteLog()
        {
            time.Start();
            // 检索
            for (int i = 0; i < LuaPath.Length; i++)
            {
                string folderPath = LuaPath[i];
                string[] pathList = Directory.GetFiles(folderPath, "*.lua", SearchOption.AllDirectories);
                for (int pIndex = 0; pIndex < pathList.Length; pIndex++)
                {
                    EditorUtility.DisplayProgressBar(string.Format(folderPath + "({0}/{1})", pIndex, pathList.Length), "正在检索数据：", (float)pIndex / pathList.Length);

                    string[] lines = File.ReadAllLines(pathList[pIndex], System.Text.Encoding.UTF8);
                    for (int lIndex = 0; lIndex < lines.Length; lIndex++)
                    {
                        string line = lines[lIndex].Trim();
                        if (line.StartsWith("WYLog(Language") || line.StartsWith("--WYLog(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if(line.StartsWith("JYHLog(Language") || line.StartsWith("--JYHLog(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("WKLog(Language") || line.StartsWith("--WKLog(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("Log(Language") || line.StartsWith("--Log(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("LogError(Language") || line.StartsWith("--LogError(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("LogRed(Language") || line.StartsWith("--LogRed(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("LogGreen(Language") || line.StartsWith("--LogGreen(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("LogBlue(Language") || line.StartsWith("--LogBlue(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("LogPink(Language") || line.StartsWith("--LogPink(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("LogYellow(Language") || line.StartsWith("--LogYellow(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        else if (line.StartsWith("LogPurple(Language") || line.StartsWith("--LogPurple(Language"))
                        {
                            lines[lIndex] = "";
                        }
                        //else if (line.StartsWith("logErrorTrace("))
                        //{

                        //    lines[lIndex] = lines[lIndex].Replace("logErrorTrace(", "Log(");
                        //}
                        //else if (line.StartsWith("--logErrorTrace("))
                        //{
                        //    lines[lIndex] = lines[lIndex].Replace("--logErrorTrace(", "--Log(");
                        //}
                        //else if (line.StartsWith("-- logErrorTrace("))
                        //{
                        //    lines[lIndex] = lines[lIndex].Replace("-- logErrorTrace(", "-- Log(");
                        //}
                    }
                    WriteAllLinesBetter(pathList[pIndex], lines);
                }
            }
            // 停止
            time.Stop();
            EditorUtility.ClearProgressBar();
            Debug.Log("删除完成");
        }


        //[MenuItem("所有Prefab添加PrefabInfoHerlper组件")]
        //static void AddPrefabInfoHelper() {
        //    UnityEngine.Object[] selObjs = Selection.GetFiltered(typeof(UnityEngine.Object), SelectionMode.DeepAssets);
        //    for (int i = 0; i < selObjs.Length; i++)
        //    {
        //        Object selObj = selObjs[i];
        //        string selfPath = AssetDatabase.GetAssetPath(selObj);
        //        if (selfPath.EndsWith(".prefab"))
        //        {
        //            string[] dependPaths = AssetDatabase.GetDependencies(selfPath);
        //            GameObject go = GameObject.Instantiate(selObj) as GameObject;
        //            PrefabInfoHelper pih = go.GetComponent<PrefabInfoHelper>();
        //            if (pih == null)
        //            {
        //                pih = go.AddComponent<PrefabInfoHelper>();
        //            }
        //            pih.isInstanced = false;
        //            pih.selfPath = selfPath;
        //            pih.dependPathList.Clear();
        //            pih.dependPathList.AddRange(dependPaths);
        //            PrefabUtility.ReplacePrefab(go, selObj, ReplacePrefabOptions.ConnectToPrefab);
        //            GameObject.DestroyImmediate(go);
        //        }
        //    }
        //}

        //---------------扩展UGUI右键Text/Image
        //[MenuItem("GameObject/UI/LanguageText")]
        //static void TextLabel()
        //{
        //    //-------创建TextLabel
        //    GameObject go = new GameObject();
        //    go.name = "Text";
        //    LanguageText t = go.AddComponent(typeof(LanguageText)) as LanguageText;
        //    t.text = "New TextLabel";
        //    t.GetComponent<RectTransform>().localPosition = Vector3.zero;
        //    t.transform.localScale = Vector3.one;
        //    Selection.activeObject = go;
        //}

        private static string[] _ArtFontExt = new string[] { "_en" };
        //[MenuItem("LanguageTool/artFont/本地化资源名称检测")]
        private static void AllArtFontNameCheck()
        {
            Debug.LogWarning("名称检测:  _zh"); 
            CheckAllArtFont("_zh", "ArtFont");
            for(int i = 0; i < _ArtFontExt.Length; i++)
            {
                string ext = _ArtFontExt[i];
                Debug.LogWarning("名称检测:  "+ ext);
                CheckAllArtFont(ext, "ArtFont"+ ext);
            }
            Debug.LogWarning("资源名称检测完成");
        }
        private static void CheckAllArtFont(string artTab, string directoryName)
        {
            string dirPath = Environment.CurrentDirectory + "\\Assets\\ManagedResources";
            Debug.Log(dirPath);

            List<string> dirs = new List<string>(Directory.GetDirectories(dirPath, directoryName, SearchOption.AllDirectories));
            List<string> artFontDirs = new List<string>();
            for (int i = 0; i < dirs.Count; i++)
            {
                string[] files = Directory.GetFiles(dirs[i]);
                for (int j = 0; j < files.Length; j++)
                {
                    string _ex = Path.GetExtension(files[j]);
                    if (_ex.Contains(".meta")) continue;
                    string fileName = Path.GetFileNameWithoutExtension(files[j]);
                    if (fileName.EndsWith(artTab)) continue;
                    if (fileName.EndsWith("_zh") || fileName.EndsWith("_en") || fileName.EndsWith("_vi"))
                    {
                        Debug.Log("文件路径" + files[j]);
                        fileName = fileName.Substring(0, fileName.Length - 3);
                    }
                    // 空格 替换为 下划线
                    fileName = fileName.Replace(" ", "_");
                    fileName = Path.GetDirectoryName(files[j]) + "/" + fileName + artTab + _ex;
                    Debug.Log("文件名：" + fileName);
                    EditorUtility.DisplayProgressBar("遍历图片资源目录", string.Format("正在检索数据：{0}/{1}", i, dirs.Count), (float)i / dirs.Count);
                    AssetDatabase.MoveAsset(files[j].Replace(Environment.CurrentDirectory + "\\", ""), fileName.Replace(Environment.CurrentDirectory + "\\", ""));
                }
            }
            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
        }

        //[MenuItem("LanguageTool/multiLanguage/导出所有ArtFont到ArtFont_zh")]
        private static void ExportAllArtFont()
        {
            Debug.Log("开始整合文字资源图片");
            GetAllArtFont("\\FontArt\\ArtFont_zh\\", "ArtFont");
            //for (int i = 0; i < _ArtFontExt.Length; i++)
            //{
            //    string ext = _ArtFontExt[i];
            //    GetAllArtFont("\\FontArt\\ArtFont"+ ext + "\\", "ArtFont" + ext);
            //}
            Debug.LogWarning("资源整合完成");
        }
        private static void GetAllArtFont(string _targetDir, string _artFontDir)
        {
            string dirPath = Environment.CurrentDirectory + "\\Assets\\ManagedResources";
            string copyPathDir = Environment.CurrentDirectory + _targetDir;
            if (Directory.Exists(copyPathDir))
            {
                Directory.Delete(copyPathDir, true);
            }
            Directory.CreateDirectory(copyPathDir);
            List<string> dirs = new List<string>(Directory.GetDirectories(dirPath, _artFontDir, SearchOption.AllDirectories));
            for (int i = 0; i < dirs.Count; i++)
            {
                string[] files = Directory.GetFiles(dirs[i]);
                for (int j = 0; j < files.Length; j++)
                {
                    if (!files[j].Contains(".png") && !files[j].Contains(".jpg")) continue;
                    if (files[j].Contains(".meta")) continue;
                    string[] nameArr = files[j].Split('\\');
                    string targetPath = copyPathDir + nameArr[nameArr.Length - 1];
                    if (!File.Exists(targetPath))
                    {
                        File.Copy(files[j], targetPath);
                    }
                }
            }
            Debug.Log("整合完成，路径是:" + copyPathDir);
        }

        //[MenuItem("LanguageTool/multiLanguage/将所有ArtFont重命名为_zh")]
        private static void AllArtFontRenameZh()
        {
            string ResPath = "Assets/ManagedResources";
            //string dirPath = Environment.CurrentDirectory + "\\Assets\\ManagedResources";
            List<string> dirs = new List<string>(Directory.GetDirectories(ResPath, "ArtFont", SearchOption.AllDirectories));
            for (int i = 0; i < dirs.Count; i++)
            {
                
                string[] files = Directory.GetFiles(dirs[i]);
                for (int j = 0; j < files.Length; j++)
                {
                    EditorUtility.DisplayCancelableProgressBar("遍历ArtFont", string.Format("正在检索数据：{0}/{1}", j, files.Length), (float)j / files.Length);
                    if (!files[j].Contains(".png") && !files[j].Contains(".jpg")) continue;
                    string fileName = Path.GetFileNameWithoutExtension(files[j]);
                    if (fileName.EndsWith("_zh")) continue;
                    if (files[j].Contains(".meta")) continue;
                    string extension = Path.GetExtension(files[j]);
                    string path = files[j];
                    //> rename
                    string msg = AssetDatabase.RenameAsset(path, fileName + "_zh");
                    if (msg != "")
                    {
                        Debug.LogError("_zh重命名失败");
                        Debug.LogError(path);
                    }
                    //> move
                    //string[] pathArray = path.Split('\\');
                    //string strPath = "";
                    //for (int k = 0; k < pathArray.Length - 1; k++)
                    //{
                    //    strPath = strPath + pathArray[k] + "\\";
                    //}
                    //File.Move(path, strPath + fileName + "_zh" + extension);
                    //File.Move(path + ".meta", strPath + fileName + "_zh" + extension + ".meta");
                    //AssetDatabase.Refresh();
                }
            }
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorUtility.ClearProgressBar();
        }
        //[MenuItem("LanguageTool/multiLanguage/修改lua_pic2newStr(_zh)")]
        private static void ChangeStrToZhStr()
        {
            time.Start();

            string ResPath = "Assets/ManagedResources";
            List<string> dirs = new List<string>(Directory.GetDirectories(ResPath, "ArtFont", SearchOption.AllDirectories));
            List<string> filesPath = new List<string>();
            for (int i = 0; i < dirs.Count; i++)
            {
                string[] files = Directory.GetFiles(dirs[i]);
                for (int j = 0; j < files.Length; j++)
                {
                    string fileName = Path.GetFileNameWithoutExtension(files[j]);
                    if(fileName.EndsWith("_zh"))
                    {
                        filesPath.Add(fileName.Substring(0, fileName.Length - 3));
                    }
                }
            }
            Debug.LogError("filesPath Num");
            Debug.LogError(filesPath.Count);
            // 检索
            for (int i = 0; i < LuaPath.Length; i++)
            {
                string folderPath = LuaPath[i];
                string[] pathList = Directory.GetFiles(folderPath, "*.lua", SearchOption.AllDirectories);
                for (int pIndex = 0; pIndex < pathList.Length; pIndex++)
                {
                    EditorUtility.DisplayProgressBar(string.Format(folderPath + "({0}/{1})", pIndex, pathList.Length), "正在检索数据：", (float)pIndex / pathList.Length);

                    string[] lines = File.ReadAllLines(pathList[pIndex], System.Text.Encoding.UTF8);
                    for (int lIndex = 0; lIndex < lines.Length; lIndex++)
                    {
                        string line = lines[lIndex];
                        List<string> matchList = new List<string>();
                        for(int k = 0; k < filesPath.Count; k++)
                        {
                            if (line.Contains("\"" + filesPath[k] + "\""))
                            {
                                matchList.Add(filesPath[k]);
                            }
                        }
                        //> replace
                        for (int k = 0; k < matchList.Count; k++)
                        {
                            line = line.Replace("\"" + matchList[k] + "\"", "\"" + matchList[k] + "_zh" + "\"");
                        }

                        lines[lIndex] = line;


                    }
                    WriteAllLinesBetter(pathList[pIndex], lines);
                }
            }
            // 停止
            time.Stop();
            EditorUtility.ClearProgressBar();
            Debug.Log("替换完成");
        }

        //[MenuItem("LanguageTool/multiLanguage/修改lua_pic2newStr(_zh)2")]
        private static void ChangeStrToZhStr2()
        {
            time.Start();

            string ResPath = "Assets/ManagedResources";
            List<string> dirs = new List<string>(Directory.GetDirectories(ResPath, "ArtFont_zh", SearchOption.AllDirectories));
            List<string> filesPath = new List<string>();
            for (int i = 0; i < dirs.Count; i++)
            {
                string[] files = Directory.GetFiles(dirs[i], "*.*", SearchOption.AllDirectories);
                for (int j = 0; j < files.Length; j++)
                {
                    string fileName = Path.GetFileNameWithoutExtension(files[j]);
                    if (fileName.EndsWith("_zh"))
                    {
                        filesPath.Add(fileName.Substring(0, fileName.Length - 3));
                    }
                }
            }
            Debug.LogError("filesPath Num");
            Debug.LogError(filesPath.Count);
            // 检索
            for (int i = 0; i < LuaPath.Length; i++)
            {
                string folderPath = LuaPath[i];
                string[] pathList = Directory.GetFiles(folderPath, "*.lua", SearchOption.AllDirectories);
                for (int pIndex = 0; pIndex < pathList.Length; pIndex++)
                {
                    EditorUtility.DisplayProgressBar(string.Format(folderPath + "({0}/{1})", pIndex, pathList.Length), "正在检索数据：", (float)pIndex / pathList.Length);

                    string[] lines = File.ReadAllLines(pathList[pIndex], System.Text.Encoding.UTF8);
                    for (int lIndex = 0; lIndex < lines.Length; lIndex++)
                    {
                        string line = lines[lIndex];
                        List<string> matchList = new List<string>();
                        for (int k = 0; k < filesPath.Count; k++)
                        {
                            if (line.Contains("\"" + filesPath[k] + "\""))
                            {
                                matchList.Add(filesPath[k]);
                            }
                        }
                        //> replace
                        for (int k = 0; k < matchList.Count; k++)
                        {
                            line = line.Replace("\"" + matchList[k] + "\"", "\"" + matchList[k] + "_zh" + "\"");
                        }

                        lines[lIndex] = line;


                    }
                    WriteAllLinesBetter(pathList[pIndex], lines);
                }
            }
            // 停止
            time.Stop();
            EditorUtility.ClearProgressBar();
            Debug.Log("替换完成");
        }

        /// <summary>
        /// 格式化路径成Asset的标准格式
        /// </summary>
        /// <param name="filePath"></param>
        /// <returns></returns>
        public static string FormatAssetPath(string filePath)
        {
            var newFilePath1 = filePath.Replace("\\", "/");
            var newFilePath2 = newFilePath1.Replace("//", "/").Trim();
            newFilePath2 = newFilePath2.Replace("///", "/").Trim();
            newFilePath2 = newFilePath2.Replace("\\\\", "/").Trim();
            return newFilePath2;
        }

        //[MenuItem("LanguageTool/artFont/对比导出差异资源")]
        private static void CheckArtFont()
        {
            // 检测一遍文件名
            AllArtFontNameCheck();
            // 整合所有资源
            ExportAllArtFont();

            // 开始导出差异资源
            string artFontPath = Environment.CurrentDirectory + "\\FontArt\\不一致资源\\";
            if (Directory.Exists(artFontPath))
            {
                Directory.Delete(artFontPath, true);
            }

            string zhDirPath = Environment.CurrentDirectory + "\\FontArt\\ArtFont_zh\\";

            string[] zhFiles = Directory.GetFiles(zhDirPath);
            string zhFolder = artFontPath + "zh\\";
            Directory.CreateDirectory(zhFolder);
            for (int x = 0; x < _ArtFontExt.Length; x++)
            {
                string ext = _ArtFontExt[x];
                string extDirPath = Environment.CurrentDirectory + "\\FontArt\\ArtFont" + ext + "\\";
                
                // 导出未翻译的资源
                string extFolder = zhFolder + ext + "\\";
                Directory.CreateDirectory(extFolder);
                for (int i = 0; i < zhFiles.Length; i++)
                {
                    // 中文文件名
                    string fileNameWithExt = Path.GetFileName(zhFiles[i]);
                    // 翻译文件名
                    string targetName = fileNameWithExt.Replace("_zh.", ext + ".");
                    // 获取目标文件路径（不包含后缀），并判断是否存在
                    string[] nameArr = targetName.Split('.');
                    string targetPath = extDirPath + nameArr[0];
                    if (!File.Exists(targetPath + ".png") && !File.Exists(targetPath + ".jpg"))
                    {
                        Debug.Log(zhFiles[i]);
                        string copyPath = extFolder + fileNameWithExt;
                        File.Copy(zhFiles[i], copyPath);
                    }
                }


                // 导出冗余的翻译资源
                string extOutPath = artFontPath + ext + "\\";
                Directory.CreateDirectory(extOutPath);
                string[] extFiles = Directory.GetFiles(extDirPath);
                for (int i = 0; i < extFiles.Length; i++)
                {
                    string fileNameWithExt = Path.GetFileName(extFiles[i]);
                    string targetName = fileNameWithExt.Replace(ext + ".", "_zh.");
                    string[] nameArr = targetName.Split('.');
                    string targetPath = zhDirPath + nameArr[0];
                    if (!File.Exists(targetPath + ".png") && !File.Exists(targetPath + ".jpg"))
                    {
                        Debug.Log(extFiles[i]);
                        string copyPath = extOutPath + fileNameWithExt;
                        File.Copy(extFiles[i], copyPath);
                    }
                }
            }

        }
        

        //[MenuItem("LanguageTool/artFont/重命名图片")]
        private static void RenameFile()
        {
            string[] files = Directory.GetFiles("D:/美术/本地化/简中_越南语", "*", SearchOption.AllDirectories);
            ChangeFileNameArt(files);
            files = Directory.GetFiles("D:/美术/本地化/简中_越南语", "*", SearchOption.AllDirectories);
            ChangeFileName(files, "_vi");
            string[] files1 = Directory.GetFiles("D:/美术/本地化/简中_英", "*", SearchOption.AllDirectories);
            ChangeFileNameArt(files1);
            files1 = Directory.GetFiles("D:/美术/本地化/简中_英", "*", SearchOption.AllDirectories);
            ChangeFileName(files1, "_en");
        }
        private static void ChangeFileNameArt(string[] files)
        {
            Debug.Log("文件数量" + files.Length);
            for (int i = 0; i < files.Length; i++)
            {
                if (files[i].EndsWith(".png.png"))
                {
                    File.Copy(files[i], files[i].Substring(0, files[i].Length - 3),true);
                    File.Delete(files[i]);
                }
            }
        }
        private static int SortFileName(string a, string b)
        {
            var a1 = Directory.GetParent(a);
            var b1 = Directory.GetParent(b);
            int a2 = int.Parse(a1.Name.Substring(4, a1.Name.Length - 4));
            int b2 = int.Parse(a1.Name.Substring(4, a1.Name.Length - 4));
            if (a2 > b2)
            {
                return 1;
            }
            else
            {
                return -1;
            }
        }
        private static void ChangeFileName(string[] files,string _ext)
        {
            
            List<string> temp = files.ToList();
            temp.Sort(SortFileName);
            Dictionary<string, string> dic = new Dictionary<string, string>();
            
            for (int i = 0; i < temp.Count; i++)
            {
                EditorUtility.DisplayProgressBar("遍历图片资源目录", string.Format("正在检索数据：{0}/{1}", i, temp.Count), (float)i / temp.Count);
                string fileName = Path.GetFileNameWithoutExtension(temp[i]);               
                if (fileName.EndsWith("_zh") || fileName.EndsWith("_en") || fileName.EndsWith("_vi"))
                {
                    fileName = fileName.Substring(0, fileName.Length - 3);
                }
                if (dic.ContainsKey(fileName))
                {
                    dic[fileName] = temp[i];
                }
                else
                {
                    dic.Add(fileName, temp[i]);
                }
            }
            foreach (KeyValuePair<string, string> keyValue in dic)
            {
                string _ex = Path.GetExtension(keyValue.Value);
                string fileName = "E:/JL_Client/Assets/ManagedResources/ArtFont" + _ext + "/" + keyValue.Key + _ext + _ex;
                File.Copy(keyValue.Value, fileName, true);
            }
            Debug.Log("完成");
            EditorUtility.ClearProgressBar();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }
        //[MenuItem("LanguageTool/artFont/资源分类")]
        private static void FileClassFied()
        {
            string dirPath = Environment.CurrentDirectory + "\\Assets\\ManagedResources";
            string enPath = dirPath + "/ArtFont_en/";
            string viPath = dirPath + "/ArtFont_vi/";
            List<string> dirs = new List<string>(Directory.GetDirectories(dirPath, "ArtFont", SearchOption.AllDirectories));
            for (int i = 0; i < dirs.Count; i++)
            {
                EditorUtility.DisplayProgressBar("创建图片资源目录", 
                    string.Format("{0}:{1}/{2}", dirs[i], i, dirs.Count), (float)i / dirs.Count);
                string dirName = GetDirName(dirs[i]);
                if (string.IsNullOrEmpty(dirName))
                {
                    continue;
                }               
                if (!Directory.Exists(enPath + dirName))
                {
                    Directory.CreateDirectory(enPath + dirName);
                }
                if (!Directory.Exists(viPath + dirName))
                {
                    Directory.CreateDirectory(viPath + dirName);
                }
                string[] zhFiles = Directory.GetFiles(dirs[i]);
                for (int j = 0; j < zhFiles.Length; j++)
                {
                    string fileName = Path.GetFileNameWithoutExtension(zhFiles[j]);
                    string _ex = Path.GetExtension(zhFiles[j]);
                    if (_ex == ".meta")
                    {
                        continue;
                    }
                    if (fileName.EndsWith("_zh"))
                    {
                        fileName = fileName.Substring(0, fileName.Length - 3);
                    }
                    EditorUtility.DisplayProgressBar("整理图片",
                    string.Format("{0}:{1}/{2}", fileName, j, zhFiles.Length), (float)j / zhFiles.Length);
                    string enFileName = fileName + "_en" + _ex;
                    string viFileName = fileName + "_vi" + _ex;
                    if (File.Exists(enPath + enFileName))
                    {
                        SortingImage(enFileName, "Assets/ManagedResources/ArtFont_en/", "Assets/ManagedResources/ArtFont_en/" + dirName);
                    }
                    if (File.Exists(viPath + viFileName))
                    {
                        SortingImage(viFileName, "Assets/ManagedResources/ArtFont_vi/", "Assets/ManagedResources/ArtFont_vi/" + dirName);
                    }
                }
            }
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorUtility.ClearProgressBar();
        }
        private static string GetDirName(string str)
        {
            string[] strs = str.Split('\\');
            bool isAdd = false;
            string dirName = "";
            for (int i = 0; i < strs.Length; i++)
            {
                if (strs[i] == "ManagedResources")
                {
                    isAdd = true;
                    continue;
                }
                if (isAdd)
                {
                    if (string.IsNullOrEmpty(dirName))
                    {
                        dirName = strs[i];
                    }
                    else
                    {
                        dirName = dirName + "#" + strs[i];
                    }
                }
            }
            return dirName;
        }
        private static void SortingImage(string fileName,string oldPath,string newPath)
        {
            AssetDatabase.MoveAsset(oldPath + fileName, newPath + "/" + fileName);
        }
        //[MenuItem("LanguageTool/lua/输出language.lua已使用表")]
        private static void SetDatalanguage()
        {
            SetData = "";
            // GetFiles(Environment.CurrentDirectory+"/Assets/ManagedResources/~Lua");
            foreach ( string f  in readlist(Environment.CurrentDirectory+"/Assets/ManagedResources/~Lua")) // xiaobaigang为文件夹名称
            {
             // this.ListBox1.Items.Add(f);
            } 

            File.WriteAllText(Environment.CurrentDirectory+"/LanaguageTextFile.txt", SetData, System.Text.Encoding.UTF8);
            Debug.Log("导出language数据完成："+Environment.CurrentDirectory+"/LanaguageTextFile.txt");
        }
        public static string SetData;
        public static System.Collections.ArrayList alst; 

        public  static void GetFiles(string dir)
        {
            Debug.Log(dir);
            try
            {
                string[] files = Directory.GetFiles(dir);//得到文件
                foreach (string file in files)//循环文件
                {
                    string exname = file.Substring(file.LastIndexOf(".") + 1);//得到后缀名// if (".txt|.aspx".IndexOf(file.Substring(file.LastIndexOf(".") + 1)) > -1)//查找.txt .aspx结尾的文件
                    if (".lua".IndexOf(file.Substring(file.LastIndexOf(".") + 1)) > -1)//如果后缀名为.txt文件
                    {
                        FileInfo fi = new FileInfo(file);//建立FileInfo对象
                        Debug.Log(fi.FullName);
                        string[] ReadText = File.ReadAllLines(fi.FullName, Encoding.Default);
                        foreach (string item in ReadText)
                        {
                            int lsItemIndex=item.IndexOf("Language");
                            if(lsItemIndex!=-1)
                            {
                                Debug.Log(lsItemIndex);
                                char[] charls = item.ToCharArray();
                                // for(int i = 0; i < charls.Length; i++)
                                // {
                                //     Debug.Log(i.ToString()+"|||"+charls[i]);
                                // }
                                SetData=SetData+"\r\n"+charls[lsItemIndex+9].ToString()+charls[lsItemIndex+10].ToString()+charls[lsItemIndex+11].ToString()+charls[lsItemIndex+12].ToString()+charls[lsItemIndex+13].ToString();
                                Debug.Log(charls[lsItemIndex+9].ToString()+charls[lsItemIndex+10].ToString()+charls[lsItemIndex+11].ToString()+charls[lsItemIndex+12].ToString()+charls[lsItemIndex+13].ToString());
                            }
                        }
                    }
                }
            }
            catch
            {

            }
        }
          public static string[] readlist( string path)
          {
              alst =  new System.Collections.ArrayList(); // 建立ArrayList对象
              GetDirs(path); // 得到文件夹
              return ( string[])alst.ToArray( typeof( string)); // 把ArrayList转化为string[]
            }
        public static void GetDirs( string d) // 得到所有文件夹
        {
            GetFiles(d); // 得到所有文件夹里面的文件
            try
            {
                string[] dirs = Directory.GetDirectories(d);
                foreach ( string dir  in dirs)
                {
                    GetDirs(dir); // 递归
                }
            }
            catch
            {

            }
        } 
         //[MenuItem("LanguageTool/lua/输出language.lua的debug已使用表")]
        private static void SetDatalanguageDebug()
        {
            SetDataDebug = "";
            // GetFiles(Environment.CurrentDirectory+"/Assets/ManagedResources/~Lua");
            int lsDebugFi = 0;
            foreach ( string f  in readlistDebug(Environment.CurrentDirectory+"/Assets/ManagedResources/~Lua",false,"",1)) // xiaobaigang为文件夹名称
            {
                lsDebugFi = lsDebugFi++;
                EditorUtility.DisplayProgressBar("查询debug中的language", "正在查询查询" + f, lsDebugFi / readlistDebug(Environment.CurrentDirectory + "/Assets/ManagedResources/~Lua", false, "", 1).Length);
                // this.ListBox1.Items.Add(f);
            } 
            string[] newDataIndex=SetDataDebug.Split(',');
            SetDataDebugAll = "";
            lsDebugFi = 0;
            foreach (string f in readlistDebug(Environment.CurrentDirectory + "/Assets/ManagedResources/~Lua", true, "", 1)) // xiaobaigang为文件夹名称
            {
                EditorUtility.DisplayProgressBar("查询debug中的language", "正在查询查询" + f, lsDebugFi / readlistDebug(Environment.CurrentDirectory + "/Assets/ManagedResources/~Lua", false, "", 1).Length);
                // this.ListBox1.Items.Add(f);
            }
            string[] newDataIndexAll= SetDataDebugAll.Split(',');
            for (int i = 0; i < newDataIndex.Length; i++)
            {
                for (int j = 0; j < newDataIndexAll.Length; j++)
                {
                    EditorUtility.DisplayProgressBar("对比数据" + newDataIndex[i], "对比数据中：" + newDataIndex[i] + "/" + newDataIndexAll[j], i / newDataIndex.Length);
                    if (newDataIndex[i]=="")
                    {
                        break;
                    }
                    if (newDataIndex[i]== newDataIndexAll[j])
                    {
                        newDataIndex[i] = "";
                    }
                }
            }
            EditorUtility.ClearProgressBar();
            SetDataDebug = "";
            for (int i = 0; i < newDataIndex.Length; i++)
            {
                SetDataDebug = SetDataDebug + "\r\n" + newDataIndex[i];
            }
            File.WriteAllText(Environment.CurrentDirectory+"/LanaguageDebugTextFile.txt", SetDataDebug, System.Text.Encoding.UTF8);
            Debug.Log("导出language数据完成："+Environment.CurrentDirectory+"/LanaguageDebugTextFile.txt");
        }
        public static string SetDataDebug;
        public static string SetDataDebugAll;
        public static string[] newDataIndex;
        public static System.Collections.ArrayList alstDebug; 
        public static string[] logStr={"Log","LogError","LogWarn","LogRed","LogGreen","LogBlue","LogPink","LogYellow","LogPurple","LogColor"};
        public  static void GetFilesDebug(string dir,bool bo,string languageData_ls,int indexNum)
        {
            Debug.Log(dir);
            try
            {
                string[] files = Directory.GetFiles(dir);//得到文件
                foreach (string file in files)//循环文件
                {
                    string exname = file.Substring(file.LastIndexOf(".") + 1);//得到后缀名// if (".txt|.aspx".IndexOf(file.Substring(file.LastIndexOf(".") + 1)) > -1)//查找.txt .aspx结尾的文件
                    if (".lua".IndexOf(file.Substring(file.LastIndexOf(".") + 1)) > -1)//如果后缀名为.txt文件
                    {
                        FileInfo fi = new FileInfo(file);//建立FileInfo对象
                        Debug.Log(fi.FullName);
                        string[] ReadText = File.ReadAllLines(fi.FullName, Encoding.Default);
                        foreach (string item in ReadText)
                        {
                            bool lsitem=false;
                            foreach(string logItem in logStr)
                            {
                                int lsItemIndex=item.IndexOf(logItem);
                                if(lsItemIndex!=-1){
                                    lsitem=true;
                                }
                            }
                            if(lsitem)
                            {
                                if(bo)
                                {

                                }else
                                {
                                    int lsDebugItem=item.IndexOf("Language");
                                    if (lsDebugItem!=-1)
                                    {
                                        char[] charls = item.ToCharArray();
                                        // for(int i = 0; i < charls.Length; i++)
                                        // {
                                            //     Debug.Log(i.ToString()+"|||"+charls[i]);
                                            // }
                                        SetDataDebug=SetDataDebug+","+charls[lsDebugItem+9].ToString()+charls[lsDebugItem+10].ToString()+charls[lsDebugItem+11].ToString()+charls[lsDebugItem+12].ToString()+charls[lsDebugItem+13].ToString();
                                        Debug.Log(charls[lsDebugItem+9].ToString()+charls[lsDebugItem+10].ToString()+charls[lsDebugItem+11].ToString()+charls[lsDebugItem+12].ToString()+charls[lsDebugItem+13].ToString());
                                    }
                                }
                            }
                            else
                            {
                                if(bo)
                                {
                                    int lsDebugItem = item.IndexOf("Language");
                                    if (lsDebugItem != -1)
                                    {
                                        int lsItemIndex = item.IndexOf("Language");
                                        if (lsItemIndex != -1)
                                        {
                                            Debug.Log(lsItemIndex);
                                            char[] charls = item.ToCharArray();
                                            // for(int i = 0; i < charls.Length; i++)
                                            // {
                                            //     Debug.Log(i.ToString()+"|||"+charls[i]);
                                            // }
                                            SetDataDebugAll = SetDataDebugAll + "," + charls[lsItemIndex + 9].ToString() + charls[lsItemIndex + 10].ToString() + charls[lsItemIndex + 11].ToString() + charls[lsItemIndex + 12].ToString() + charls[lsItemIndex + 13].ToString();
                                            Debug.Log(charls[lsItemIndex + 9].ToString() + charls[lsItemIndex + 10].ToString() + charls[lsItemIndex + 11].ToString() + charls[lsItemIndex + 12].ToString() + charls[lsItemIndex + 13].ToString());
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch
            {

            }
        }
          public static string[] readlistDebug( string path,bool bo,string languageData_ls,int indexNum)
          {
              alstDebug =  new System.Collections.ArrayList(); // 建立ArrayList对象
              GetDirsDebug(path,bo,languageData_ls, indexNum); // 得到文件夹
              return ( string[])alstDebug.ToArray( typeof( string)); // 把ArrayList转化为string[]
            }
        public static void GetDirsDebug( string d,bool bo,string languageData_ls,int indexNum) // 得到所有文件夹
        {
            GetFilesDebug(d,bo,languageData_ls, indexNum); // 得到所有文件夹里面的文件
            try
            {
                string[] dirs = Directory.GetDirectories(d);
                foreach ( string dir  in dirs)
                {
                    GetDirsDebug(dir,bo,languageData_ls, indexNum); // 递归
                }
            }
            catch
            {

            }
        } 
    }
}
