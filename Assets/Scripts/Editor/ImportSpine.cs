/// <summary>
/// create with wxl for create base select file win
/// </summary>

using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using Spine.Unity;
using Animation = Spine.Animation;
using System.Text;

public class ImportSpine : EditorWindow
{
    #region definition variable

    private string sourcesFolderPath = ""; // 源文件路径
    private string importFolderPath = ""; // 导入到unity工程的目标文件路径
    private string spineFolderName = ""; // spine文件夹名
    private string spineFileName = ""; // spine 文件名
    private bool createSpinePrefab = true; // 是否生成spine预设
    private SelectFileWin selectFileWin; // 导入文件选择界面 
    private string spinePrefabPath = "Assets/ManagedResources/Prefabs/Live2d/"; // 预制路径
    private string spineAssetPath = "Assets/ManagedResources/Spine/";

    #endregion

    #region OnGUI And ShowWin
    StringBuilder fileImportFailedName;
    string text;
    [MenuItem("Assets/Spine工具/导入工具",priority = 201)]
    private static void StartWin()
    {
        ImportSpine spineWin = EditorWindow.GetWindow<ImportSpine>("Spine文件导入");
        spineWin.maxSize = new Vector2(600f, 125f);
        spineWin.text = "";
    }

    public void init()
    {
        this.sourcesFolderPath = EditorPrefs.GetString("IMPORTSPINE_SOURCESFOLDERPATH");
        this.importFolderPath = EditorPrefs.GetString("IMPORTSPINE_IMPORTFOLDERPATH");
        fileImportFailedName = new StringBuilder();
    }

    private void OnGUI()
    {
        init();
        GUILayout.BeginVertical();
        GUILayout.Space(10f);
        GUILayout.EndVertical();
        GUILayout.BeginHorizontal();
        GUILayout.Label("源文件路径：", GUILayout.ExpandWidth(false));
        this.sourcesFolderPath = GUILayout.TextField(this.sourcesFolderPath);
        if (GUILayout.Button("Browse", GUILayout.ExpandWidth(false)))
        {
            this.sourcesFolderPath =
                EditorUtility.OpenFolderPanel("Resource path", this.sourcesFolderPath, Application.dataPath);
            this.selectFileWin = EditorWindow.GetWindow<SelectFileWin>();
            this.selectFileWin.Show();
            this.selectFileWin.SetSelectFileWinData(this.sourcesFolderPath);
            EditorPrefs.SetString("IMPORTSPINE_SOURCESFOLDERPATH", this.sourcesFolderPath);
        }

        GUILayout.EndHorizontal();
        GUILayout.BeginHorizontal();
        GUILayout.Space(10f);
        GUILayout.Label("目标文件路径：", GUILayout.ExpandWidth(false));
        this.importFolderPath = GUILayout.TextField(this.importFolderPath);
        if (GUILayout.Button("Browse", GUILayout.ExpandWidth(false)))
        {
            this.importFolderPath =
                EditorUtility.OpenFolderPanel("Unity target path", this.importFolderPath, Application.dataPath);
            EditorPrefs.SetString("IMPORTSPINE_IMPORTFOLDERPATH", this.importFolderPath);
        }

        GUILayout.Space(5f);
        GUILayout.EndHorizontal();

        GUILayout.BeginHorizontal();
        GUILayout.Label("是否生成Spine预设？", GUILayout.ExpandWidth(false));
        this.createSpinePrefab = GUILayout.Toggle(this.createSpinePrefab, "");
        GUILayout.Label("设置默认的动作", GUILayout.ExpandWidth(false));
        text = GUILayout.TextArea(text);
        GUILayout.Space(10f);
        GUILayout.EndHorizontal();
        GUILayout.BeginVertical();
        if (GUILayout.Button("导 入"))
        {
            this.ImportSpineResTest();
        }

        GUILayout.EndVertical();
    }

    #endregion

    #region 加后缀名.txt，复制文件到unity工程中 new

    private void ImportSpineResTest()
    {
        selectFileWin.spinePrefabPathList.Clear();
        if (!this.CheckExceptionPath())
        {
            return;
        }

        // 得到当前需要导入哪些文件
        List<string> importFiles = new List<string>();
        Dictionary<string, List<string>> fileDict = this.selectFileWin.FileDict;
        Dictionary<string, FileSelectVal> fileSelectState = this.selectFileWin.FileSelectState;
        IDictionaryEnumerator fileSelectStateDictE = fileSelectState.GetEnumerator();
        while (fileSelectStateDictE.MoveNext())
        {
            if (((FileSelectVal) fileSelectStateDictE.Value).stateVal)
            {
                importFiles.AddRange(fileDict[fileSelectStateDictE.Key.ToString()]);
            }
        }

        // 检查是否有导入文件
        if (!this.CheckExceptionFile(importFiles.Count))
        {
            return;
        }

        // 获取目标文件夹
        DirectoryInfo importFolderInfo = null;
        
        for (int i = 0; i < importFiles.Count; i++)
        {
            if (File.Exists(importFiles[i]))
            {
                // 加后缀名
                FileInfo aInfo = new FileInfo(importFiles[i]);
                string operaionFileName = importFiles[i];
                if (aInfo.Extension == ".atlas")
                {
                    operaionFileName += ".txt";
                    if (File.Exists(operaionFileName) && EditorUtility.DisplayDialog("提示",
                            "重命名时存在同名文件：《" + aInfo.Name + ".txt》，是否替换？", "替 换", "跳 过"))
                    {
                        File.Delete(operaionFileName);
                        File.Move(importFiles[i], operaionFileName);
                    }
                    else
                    {
                        File.Move(importFiles[i], operaionFileName);
                    }
                }

                else if (aInfo.Extension == ".skel")
                {
                    operaionFileName += ".bytes";
                    if (File.Exists(operaionFileName) && EditorUtility.DisplayDialog("提示",
                            "重命名时存在同名文件：《" + aInfo.Name + ".txt》，是否替换？", "替 换", "跳 过"))
                    {
                        File.Delete(operaionFileName);
                        File.Move(importFiles[i], operaionFileName);
                    }

                    else
                    {
                        File.Move(importFiles[i], operaionFileName);
                    }
                }

                // 移动                
                FileInfo bInfo = new FileInfo(operaionFileName);

                string[] fileNameSp = bInfo.Name.Split('.');
                string filename = fileNameSp[0];
                string prefabPath = spinePrefabPath + "/" + filename; 
               
                string importFolderName = this.importFolderPath + "/" + filename;
                if (!Directory.Exists(importFolderName))
                {
                    importFolderInfo = Directory.CreateDirectory(importFolderName);
                    selectFileWin.spinePrefabPathList.Add(prefabPath);
                }
                else
                {
                    importFolderInfo = new DirectoryInfo(importFolderName);
                }

                string importTargetFileName = importFolderInfo.FullName + "//" + bInfo.Name;
                if (File.Exists(importTargetFileName))
                {
                    if (EditorUtility.DisplayDialog("提示", "粘贴文件时存在同名文件：《" + bInfo.Name + "》，是否替换 ？", "替 换", "跳 过"))
                    {
                        File.Delete(importTargetFileName);
                        File.Copy(bInfo.FullName, importTargetFileName);
                    }
                }
                else
                {
                    File.Copy(bInfo.FullName, importTargetFileName);
                }
            }
            else
            {
                fileImportFailedName.AppendLine(string.Format("{0}不存在", importFiles[i]));
            }
        }

        AssetDatabase.Refresh();
        if (createSpinePrefab)
        {
            for (int i = 0; i < selectFileWin.spinePrefabPathList.Count; i++)
            {
                CreatePrefabTest(selectFileWin.spinePrefabPathList[i]);
            }
        }
    }

    #endregion

    #region 异常检查

    /// <summary>
    /// 重命名、复制文件前的异常检查
    /// </summary>    
    private bool CheckExceptionPath()
    {
        if (string.IsNullOrEmpty(this.sourcesFolderPath) || !Directory.Exists(this.sourcesFolderPath))
        {
            if (EditorUtility.DisplayDialog("", "请选择正确的导入Spine所在的 《文件夹》！", "确 定"))
            {
                this.sourcesFolderPath =
                    EditorUtility.OpenFolderPanel("Resource path", this.sourcesFolderPath, Application.dataPath);
                selectFileWin = EditorWindow.GetWindow<SelectFileWin>();
                selectFileWin.Show();
                selectFileWin.name = "selectFileWin";
                selectFileWin.SetSelectFileWinData(this.sourcesFolderPath);
            }

            return false;
        }

        if (string.IsNullOrEmpty(this.importFolderPath) || !Directory.Exists(this.importFolderPath))
        {
            if (EditorUtility.DisplayDialog("", "请选择正确的导入到unity的 《文件夹》！", "确 定"))
            {
                this.importFolderPath =
                    EditorUtility.OpenFolderPanel("Unity target path", this.importFolderPath, Application.dataPath);
            }

            return false;
        }

        return true;
    }


    /// <summary>
    /// 检测当前是否有导入文件
    /// </summary>    
    private bool CheckExceptionFile(int _select_import_file_count)
    {
        if (_select_import_file_count <= 0)
        {
            if (EditorUtility.DisplayDialog("", "请先选择需要导入的《文件》！！", "确 定"))
            {
                selectFileWin = EditorWindow.GetWindow<SelectFileWin>();
                selectFileWin.Show();
                selectFileWin.SetSelectFileWinData(this.sourcesFolderPath);
            }

            return false;
        }

        return true;
    }

    #endregion

    #region 创建spine预制

    /// <summary>
    /// 创建spine预设
    /// </summary>
    /// <param name="_spinePrefabPath"></param>
    public void CreatePrefabTest(string _spinePrefabPath)
    {
        if (!File.Exists(_spinePrefabPath + ".prefab"))
        {
            string[] _spineSplit = _spinePrefabPath.Split('/');
            string _spineName = _spineSplit[_spineSplit.Length - 1];
            GameObject skeletonPrefab = new GameObject();
            skeletonPrefab.AddComponent<RectTransform>();
            SkeletonGraphic skeletonGraphic = skeletonPrefab.AddComponent<SkeletonGraphic>();
            skeletonGraphic.skeletonDataAsset =
                AssetDatabase.LoadAssetAtPath<SkeletonDataAsset>(
                    spineAssetPath + _spineName + "/" + _spineName + "_SkeletonData.asset");
            //            skeletonGraphic.material =
            //                AssetDatabase.LoadAssetAtPath<Material>(
            //                    spineAssetPath + _spineName + "/" + _spineName + "_Material.mat");
            if (skeletonGraphic.skeletonDataAsset == null)
            {
                fileImportFailedName.AppendLine(string.Format("{0}没有_SkeletonData.asset文件", _spineName));
            }
            skeletonGraphic.material = SpineDefaultMat;
            skeletonGraphic.startingLoop = true;
            skeletonGraphic.raycastTarget = true;
            skeletonGraphic.startingAnimation = "";

            var skeltonData = skeletonGraphic.skeletonDataAsset.GetSkeletonData(false);
            var anims = skeltonData.Animations;
            if (anims != null && anims.Count > 0)
            {
                Animation firstAnim = null;
                foreach (var a in anims)
                {
                    if (a != null)
                    {
                        if (firstAnim == null)
                        {
                            firstAnim = a;
                        }
                        if (a.Name.ToLower().Contains("text"))
                        {
                            skeletonGraphic.startingAnimation = a.Name;
                            break;
                        }
                    }
                }

                if (firstAnim != null && string.IsNullOrEmpty(skeletonGraphic.startingAnimation))
                {
                    skeletonGraphic.startingAnimation = firstAnim.Name;
                }
                else
                {
                    fileImportFailedName.AppendLine(string.Format("{0}没有动作idle", _spineName));
                }
            }
            else
            {
                fileImportFailedName.AppendLine(string.Format("{0}没有动作文件", _spineName));
            }
            string prefabPath = _spinePrefabPath + ".prefab";
            if (File.Exists(prefabPath))
            {
                GameObject go = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
                PrefabUtility.ReplacePrefab(skeletonPrefab, go);
            }

            PrefabUtility.CreatePrefab(_spinePrefabPath + ".prefab", skeletonPrefab,
                ReplacePrefabOptions.ReplaceNameBased);
            GameObject.DestroyImmediate(skeletonPrefab);
        }
        if (fileImportFailedName.Length > 0)
        {
            File.WriteAllText("E:/有问题的spine动画.csv", fileImportFailedName.ToString());
            System.Diagnostics.Process.Start("E:/有问题的spine动画.csv");
        }        
    }

    #endregion

    
    [MenuItem("Assets/Spine工具/预设批量配置",priority = 201)]
    private static void onMenuItem_SetSpineAnim()
    {
        var guids = AssetDatabase.FindAssets("t:prefab", new string[] { "Assets/ManagedResources/Prefabs/Live2d" });
        Debug.Log(guids.Length);
        if (guids == null || guids.Length < 1) return;
        for (int i = 0,imax = guids.Length; i < imax; i++)
        {
            var path = AssetDatabase.GUIDToAssetPath(guids[i]);
            if (EditorUtility.DisplayCancelableProgressBar("", path, i * 1f / imax)) break;

            var pb = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            SetSpineAnim(pb);

            if ((i + 1) % 10 == 0)
            {
                EditorUtility.UnloadUnusedAssetsImmediate();
                System.GC.Collect();
            }

        }
        EditorUtility.ClearProgressBar();
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
    }

    private static void SetSpineAnim(GameObject prefab)
    {
        if (prefab == null) return;
        SkeletonGraphic skeletonGraphic = prefab.GetComponent<SkeletonGraphic>();
        if (skeletonGraphic == null) return;
        if (skeletonGraphic.skeletonDataAsset == null)
        {
            Debug.LogErrorFormat("Missing Spine SkeletonDataAsset:{0}",prefab.name);
            return;
        }
        var skeltonData = skeletonGraphic.skeletonDataAsset.GetSkeletonData(false);
        if (skeltonData == null)
        {
            Debug.LogErrorFormat("Missing Spine SkeltonData:{0}",prefab.name);
            return;
        }

        skeletonGraphic.startingAnimation = "";
        var anims = skeltonData.Animations;
        if (anims != null && anims.Count > 0)
        {
            Animation firstAnim = null;
            foreach (var a in anims)
            {
                if (a != null)
                {
                    if (firstAnim == null)
                    {
                        firstAnim = a;
                    }
                    if (a.Name.ToLower().Contains("idle"))
                    {
                        skeletonGraphic.startingAnimation = a.Name;
                        break;
                    }
                }
            }

            if (firstAnim != null&&string.IsNullOrEmpty(skeletonGraphic.startingAnimation))
            {
                skeletonGraphic.startingAnimation = firstAnim.Name;
            }
        }
        skeletonGraphic.startingLoop = true;
        skeletonGraphic.raycastTarget = true;
        skeletonGraphic.material = SpineDefaultMat;
        EditorUtility.SetDirty(prefab);
        AssetDatabase.SaveAssets();
    }

    private static Material spineDefaultMat = null;

    private static Material SpineDefaultMat
    {
        get
        {
            if (spineDefaultMat == null)
            {
                spineDefaultMat =
                    AssetDatabase.LoadAssetAtPath<Material>("Assets/ManagedResources/PublicArtRes/Materials/SkeletonGraphicDefault.mat");
            }

            return spineDefaultMat;
        }
    }

}