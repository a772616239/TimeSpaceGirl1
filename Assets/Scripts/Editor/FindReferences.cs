using UnityEngine;
using System.Collections;
using UnityEditor;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using GameEditor.Core;
using GameLogic;
using System.Collections.Generic;
using System.Threading;

public class FindReferences
{
    [MenuItem("Assets/替换为指定资源", false, 10)]
    static private void ReplaceAsset()
    {
        return;
        string replaceGUID = "d86d8a727ce12394cb7af8a758dd3ec7";

        EditorSettings.serializationMode = SerializationMode.ForceText;
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);
        if (Selection.activeObject is DefaultAsset)
        {
            Debug.Log("文件夹路径：" + path);

            System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
            time.Start();

            string[] files = Directory.GetFiles(path).Where(s => !s.EndsWith(".meta")).ToArray();

            string[] ffs = Directory.GetFiles(AppConst.GameResRealPath, "*.*", SearchOption.AllDirectories)
                   .Where(s => withoutExtensions.Contains(Path.GetExtension(s).ToLower())).ToArray();

            Dictionary<string, List<string>> dic = new Dictionary<string, List<string>>();
            string[] guids = new string[files.Length];

            for (int i = 0; i < files.Length; i++)
            {
                dic[files[i]] = new List<string>();
                guids[i] = AssetDatabase.AssetPathToGUID(files[i]);
            }

            string FilePath = null;
            object lockObj = new object();
            int count = 0;
            EditorApplication.update = () =>
            {
                if (count < ffs.Length)
                {
                    EditorUtility.DisplayCancelableProgressBar(string.Format("匹配资源中({0}/{1})", count, ffs.Length), FilePath, (float)count / ffs.Length);
                }
                else
                {
                    EditorApplication.update = null;
                    for (int i = 0; i < files.Length; i++)
                    {
                        Debug.Log("【资源路径】：" + files[i], AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(files[i])));
                        for (int j = 0; j < dic[files[i]].Count; j++)
                        {
                            var obj = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(dic[files[i]][j]));
                            var obj2 = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(files[i]));
                            Debug.LogError("引用路径：" + dic[files[i]][j], obj);
                            var extension = Path.GetExtension(dic[files[i]][j]);

                            if (extension == ".prefab")
                            {
                                var gameObj = obj as GameObject;
                                CheckResRef(gameObj.transform, gameObj.transform, obj2.name);
                                DebugChildName(gameObj.transform, gameObj.transform, obj2.name);
                            }
                        }
                    }

                    EditorUtility.ClearProgressBar();
                    Debug.Log("匹配结束");

                    time.Stop();
                    Debug.LogError("耗时：" + time.ElapsedMilliseconds);
                }
            };

            for (int i = 0; i < ffs.Length; i++)
            {
                int index = i;
                ThreadPool.QueueUserWorkItem(q =>
                {
                    string file = File.ReadAllText(ffs[index]);

                    for (int j = 0; j < files.Length; j++)
                    {
                        if (Regex.IsMatch(file, guids[j]))
                        {
                            dic[files[j]].Add(ffs[index]);
                        }
                    }

                    lock (lockObj)
                    {
                        count++;
                        FilePath = ffs[index];
                    }
                });
            }
        }
        else
        {
            if (!string.IsNullOrEmpty(path))
            {
                string guid = AssetDatabase.AssetPathToGUID(path);
                string[] files = Directory.GetFiles(AppConst.GameResRealPath, "*.*", SearchOption.AllDirectories)
                    .Where(s => withoutExtensions.Contains(Path.GetExtension(s).ToLower())).ToArray();

                System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
                time.Start();

                string FilePath = null;
                object lockObj = new object();
                int count = 0;
                List<string> list = new List<string>();

                EditorApplication.update = () =>
                {
                    if (count < files.Length)
                    {
                        EditorUtility.DisplayCancelableProgressBar(string.Format("匹配资源中({0}/{1})", count, files.Length), FilePath, (float)count / files.Length);
                    }
                    else
                    {
                        AssetDatabase.Refresh();

                        EditorApplication.update = null;
                        Debug.Log("【资源路径】：" + path, AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(path)));

                        for (int i = 0; i < list.Count; i++)
                        {
                            var obj = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(list[i]));
                            Debug.LogError("引用路径：" + list[i], obj);
                            var extension = Path.GetExtension(list[i]);

                            if (extension == ".prefab")
                            {
                                var gameObj = obj as GameObject;
                                CheckResRef(gameObj.transform, gameObj.transform, Selection.activeObject.name);
                                DebugChildName(gameObj.transform, gameObj.transform, Selection.activeObject.name);
                            }
                        }

                        EditorUtility.ClearProgressBar();
                        Debug.Log("匹配结束");

                        time.Stop();
                        Debug.LogError("耗时：" + time.ElapsedMilliseconds);
                    }
                };


                for (int i = 0; i < files.Length; i++)
                {
                    int index = i;
                    ThreadPool.QueueUserWorkItem(q =>
                    {
                        string file = File.ReadAllText(files[index]);

                        if (Regex.IsMatch(file, guid))
                        {
                            list.Add(files[index]);

                            //开始替换为指定guid
                            file = file.Replace(guid, replaceGUID);
                            File.WriteAllText(files[index], file);
                        }

                        lock (lockObj)
                        {
                            count++;
                            FilePath = files[index];
                        }
                    });
                }
            }
        }
    }

    static string withoutExtensions = "*.prefab*.unity*.mat*.shader*.asset*.controller";
    [MenuItem("Assets/Find References", false, 10)]
    static private void Find()
    {
        EditorSettings.serializationMode = SerializationMode.ForceText;
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);
        if (Selection.activeObject is DefaultAsset)
        {
            Debug.Log("文件夹路径：" + path);

            System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
            time.Start();

            string[] files = Directory.GetFiles(path).Where(s => !s.EndsWith(".meta")).ToArray();

            string[] ffs = Directory.GetFiles(AppConst.GameResRealPath, "*.*", SearchOption.AllDirectories)
                   .Where(s => withoutExtensions.Contains(Path.GetExtension(s).ToLower())).ToArray();

            Dictionary<string, List<string>> dic = new Dictionary<string, List<string>>();
            string[] guids = new string[files.Length];

            for (int i = 0; i < files.Length; i++)
            {
                dic[files[i]] = new List<string>();
                guids[i] = AssetDatabase.AssetPathToGUID(files[i]);
            }

            string FilePath = null;
            object lockObj = new object();
            int count = 0;
            EditorApplication.update = () =>
            {
                if (count < ffs.Length)
                {
                    EditorUtility.DisplayCancelableProgressBar(string.Format("匹配资源中({0}/{1})", count, ffs.Length), FilePath, (float)count / ffs.Length);
                }
                else
                {
                    EditorApplication.update = null;
                    for (int i = 0; i < files.Length; i++)
                    {
                        Debug.Log("【资源路径】：" + files[i], AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(files[i])));
                        for (int j = 0; j < dic[files[i]].Count; j++)
                        {
                            var obj = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(dic[files[i]][j]));
                            var obj2 = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(files[i]));
                            Debug.LogError("引用路径：" + dic[files[i]][j], obj);
                            var extension = Path.GetExtension(dic[files[i]][j]);

                            if (extension == ".prefab")
                            {
                                var gameObj = obj as GameObject;
                                CheckResRef(gameObj.transform, gameObj.transform, obj2.name);
                                DebugChildName(gameObj.transform, gameObj.transform, obj2.name);
                            }
                        }
                    }

                    EditorUtility.ClearProgressBar();
                    Debug.Log("匹配结束");

                    time.Stop();
                    Debug.LogError("耗时：" + time.ElapsedMilliseconds);
                }
            };

            for (int i = 0; i < ffs.Length; i++)
            {
                int index = i;
                ThreadPool.QueueUserWorkItem(q =>
                {
                    string file = File.ReadAllText(ffs[index]);

                    for (int j = 0; j < files.Length; j++)
                    {
                        if (Regex.IsMatch(file, guids[j]))
                        {
                            dic[files[j]].Add(ffs[index]);
                        }
                    }

                    lock (lockObj)
                    {
                        count++;
                        FilePath = ffs[index];
                    }
                });
            }
        }
        else
        {
            if (!string.IsNullOrEmpty(path))
            {
                string guid = AssetDatabase.AssetPathToGUID(path);
                string[] files = Directory.GetFiles(AppConst.GameResRealPath, "*.*", SearchOption.AllDirectories)
                    .Where(s => withoutExtensions.Contains(Path.GetExtension(s).ToLower())).ToArray();

                System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
                time.Start();

                string FilePath = null;
                object lockObj = new object();
                int count = 0;
                List<string> list = new List<string>();

                EditorApplication.update = () =>
                {
                    if (count < files.Length)
                    {
                        EditorUtility.DisplayCancelableProgressBar(string.Format("匹配资源中({0}/{1})", count, files.Length), FilePath, (float)count / files.Length);
                    }
                    else
                    {
                        EditorApplication.update = null;
                        Debug.Log("【资源路径】：" + path, AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(path)));

                        for (int i = 0; i < list.Count; i++)
                        {
                            var obj = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(list[i]));
                            Debug.LogError("引用路径：" + list[i], obj);
                            var extension = Path.GetExtension(list[i]);

                            if (extension == ".prefab")
                            {
                                var gameObj = obj as GameObject;
                                CheckResRef(gameObj.transform, gameObj.transform, Selection.activeObject.name);
                                DebugChildName(gameObj.transform, gameObj.transform, Selection.activeObject.name);
                            }
                        }

                        EditorUtility.ClearProgressBar();
                        Debug.Log("匹配结束");

                        time.Stop();
                        Debug.LogError("耗时：" + time.ElapsedMilliseconds);
                    }
                };


                for (int i = 0; i < files.Length; i++)
                {
                    int index = i;
                    ThreadPool.QueueUserWorkItem(q =>
                    {
                        string file = File.ReadAllText(files[index]);

                        if (Regex.IsMatch(file, guid))
                        {
                            list.Add(files[index]);
                        }

                        lock (lockObj)
                        {
                            count++;
                            FilePath = files[index];
                        }
                    });
                }
            }
        }
    }

    static void DebugChildName(Transform parent, Transform topParent, string targetName)
    {
        for (int i = 0; i < parent.childCount; i++)
        {
            var child = parent.GetChild(i);
            CheckResRef(child, topParent, targetName);
            if (child.childCount > 0)
            {
                DebugChildName(child, topParent, targetName);
            }
        }
    }

    static void CheckResRef(Transform tran, Transform topParent, string targetName)
    {
        bool isShowPath = false;
        var image = tran.GetComponent<UnityEngine.UI.Image>();
        isShowPath |= image != null && image.sprite != null && image.sprite.name == targetName;

        var image2 = tran.GetComponent<SpriteRenderer>();
        isShowPath |= image2 != null && image2.sprite != null && image2.sprite.name == targetName;

        var text = tran.GetComponent<UnityEngine.UI.Text>();
        isShowPath |= text != null && text.font != null && text.font.name == targetName;

        var mat = tran.GetComponent<Renderer>();
        isShowPath |= mat != null && mat.sharedMaterial != null && mat.sharedMaterial.name == targetName;

        var anim = tran.GetComponent<Animator>();
        isShowPath |= anim != null && anim.runtimeAnimatorController != null && anim.runtimeAnimatorController.name == targetName;

        var spine1 = tran.GetComponent<Spine.Unity.SkeletonGraphic>();
        isShowPath |= spine1 != null && spine1.skeletonDataAsset != null && spine1.skeletonDataAsset.name == targetName;

        var spine2 = tran.GetComponent<Spine.Unity.SkeletonAnimation>();
        isShowPath |= spine2 != null && spine2.skeletonDataAsset != null && spine2.skeletonDataAsset.name == targetName;

        if (isShowPath)
        {
            Debug.LogWarning("【预制体内部路径】：" + tran.GetPathToParent(topParent));
        }
    }

    [MenuItem("Assets/一键绑定动画按钮", false, 10)]
    static void BindingAnimButton()
    {
        if (!EditorUtility.DisplayDialog("提示", "确定修改该资源所关联的按钮组件？注意这会影响所有相关的预设", "确定", "取消"))
        {
            return;
        }
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);
        if (!string.IsNullOrEmpty(path))
        {
            string guid = AssetDatabase.AssetPathToGUID(path);
            string[] files = Directory.GetFiles(AppConst.GameResRealPath, "*.*", SearchOption.AllDirectories)
                .Where(s => withoutExtensions.Contains(Path.GetExtension(s).ToLower())).ToArray();

            System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
            time.Start();

            string FilePath = null;
            object lockObj = new object();
            int count = 0;
            List<string> list = new List<string>();

            EditorApplication.update = () =>
            {
                if (count < files.Length)
                {
                    EditorUtility.DisplayCancelableProgressBar(string.Format("匹配资源中({0}/{1})", count, files.Length), FilePath, (float)count / files.Length);
                }
                else
                {
                    EditorApplication.update = null;
                    Debug.Log("【资源路径】：" + path, AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(path)));

                    var o = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(path));
                    var anim = AssetDatabase.LoadAssetAtPath<RuntimeAnimatorController>("Assets/ManagedResources/PublicArtRes/Animations/CommonButton.controller");

                    for (int i = 0; i < list.Count; i++)
                    {
                        var obj = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(list[i]));
                        //Debug.LogError("引用路径：" + list[i], obj);
                        var extension = Path.GetExtension(list[i]);

                        if (extension == ".prefab")
                        {
                            var gameObj = obj as GameObject;
                            CheckResRef(gameObj.transform, gameObj.transform, Selection.activeObject.name);
                            DebugChildName(gameObj.transform, gameObj.transform, Selection.activeObject.name);

                            var images = gameObj.GetComponentsInChildren<UnityEngine.UI.Image>(true);
                            for (int j = 0; j < images.Length; j++)
                            {
                                if (images[j].sprite != null && images[j].sprite.name == o.name)
                                {
                                    var btnGo = images[j].gameObject.GetComponent<UnityEngine.UI.Button>();
                                    if (btnGo != null)
                                    {
                                        btnGo.transition = UnityEngine.UI.Selectable.Transition.Animation;
                                        var ac = btnGo.gameObject.GetComponent<Animator>();
                                        if (ac == null)
                                        {
                                            ac = btnGo.gameObject.AddComponent<Animator>();
                                        }
                                        ac.runtimeAnimatorController = anim;
                                    }
                                }
                            }
                            AssetDatabase.SaveAssets();
                            EditorUtility.SetDirty(gameObj);
                        }
                    }
                    AssetDatabase.Refresh();

                    EditorUtility.ClearProgressBar();
                    Debug.Log("匹配结束");

                    time.Stop();
                    Debug.LogError("耗时：" + time.ElapsedMilliseconds);
                }
            };


            for (int i = 0; i < files.Length; i++)
            {
                int index = i;
                ThreadPool.QueueUserWorkItem(q =>
                {
                    string file = File.ReadAllText(files[index]);

                    if (Regex.IsMatch(file, guid))
                    {
                        list.Add(files[index]);
                    }

                    lock (lockObj)
                    {
                        count++;
                        FilePath = files[index];
                    }
                });
            }
        }
    }

    static string MoveToPath = AppConst.GameResRealPath + "/PublicArtRes/";
    [MenuItem("Assets/MoveToPublicRes/Material", false, 10)]
    static void MoveToPublicResMat()
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);
        string extension = Path.GetExtension(path).ToLower();
        if (Selection.activeObject is Material)
        {
            File.Move(Application.dataPath + path.Replace("Assets", ""), MoveToPath + "Materials/" + Selection.activeObject.name + extension);
            File.Move(Application.dataPath + path.Replace("Assets", "") + ".meta", MoveToPath + "Materials/" + Selection.activeObject.name + extension + ".meta");
            AssetDatabase.Refresh();
        }
    }
    [MenuItem("Assets/MoveToPublicRes/Texture", false, 10)]
    static void MoveToPublicResTex()
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);
        string extension = Path.GetExtension(path).ToLower();
        if (Selection.activeObject is Texture)
        {
            File.Move(Application.dataPath + path.Replace("Assets", ""), MoveToPath + "Textures/" + Selection.activeObject.name + extension);
            File.Move(Application.dataPath + path.Replace("Assets", "") + ".meta", MoveToPath + "Textures/" + Selection.activeObject.name + extension + ".meta");
            AssetDatabase.Refresh();
        }
    }

    [MenuItem("Assets/MoveToPublicRes/Model", false, 10)]
    static void MoveToPublicResMod()
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);
        string extension = Path.GetExtension(path).ToLower();
        if (Selection.activeObject is GameObject)
        {
            File.Move(Application.dataPath + path.Replace("Assets", ""), MoveToPath + "Models/" + Selection.activeObject.name + extension);
            File.Move(Application.dataPath + path.Replace("Assets", "") + ".meta", MoveToPath + "Models/" + Selection.activeObject.name + extension + ".meta");
            AssetDatabase.Refresh();
        }
    }

    [MenuItem("Assets/Find References", true)]
    static private bool VFind()
    {
        string path = AssetDatabase.GetAssetPath(Selection.activeObject);
        return (!string.IsNullOrEmpty(path));
    }

    //[MenuItem("Assets/批量添加粒子层级", false, 10)]
    static void AddLayer()
    {
        int targetLayer = 100;
        int deltaLayer = -1000;
        UnityEngine.Events.UnityAction<GameObject> action = go =>
        {
            var gos = go.GetComponentsInChildren<ParticleSystem>(true);
            for (int i = 0; i < gos.Length; i++)
            {
                int layer = gos[i].GetComponent<Renderer>().sortingOrder;
                Debug.LogError(layer);
                if (layer > targetLayer)
                {
                    gos[i].GetComponent<Renderer>().sortingOrder += deltaLayer;
                }
            }
            var gos2 = go.GetComponentsInChildren<TrailRenderer>(true);
            for (int i = 0; i < gos2.Length; i++)
            {
                int layer = gos2[i].GetComponent<Renderer>().sortingOrder;
                Debug.LogError(layer);
                if (layer > targetLayer)
                {
                    gos2[i].GetComponent<Renderer>().sortingOrder += deltaLayer;
                }
            }
            AssetDatabase.Refresh();
        };
        if (Selection.activeObject is GameObject)
        {
            action(Selection.activeObject as GameObject);
        }
        else if (Selection.activeObject is DefaultAsset)
        {
            string[] files = Directory.GetFiles(AssetDatabase.GetAssetPath(Selection.activeObject)).Where(s => !s.EndsWith(".meta")).ToArray();
            for (int i = 0; i < files.Length; i++)
            {
                Debug.LogError("查找路径：" + files[i]);
                var obj = AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(files[i]));
                if (obj is GameObject)
                {
                    action(obj as GameObject);
                }
            }
        }
    }

    static private string GetRelativeAssetsPath(string path)
    {
        return "Assets" + Path.GetFullPath(path).Replace(Path.GetFullPath(Application.dataPath), "").Replace('\\', '/');
    }

    [MenuItem("Assets/Find Denpendencies", false, 11)]
    private static void OnSearchForReferences()
    {
        //确保鼠标右键选择的是一个Prefab
        if (Selection.gameObjects.Length != 1)
        {
            return;
        }

        var go = Selection.gameObjects[0];
        //判断GameObject是否为一个Prefab的引用
        if (PrefabUtility.GetPrefabType(go) == PrefabType.Prefab)
        {
            //UnityEngine.Object parentObject = PrefabUtility.GetPrefabParent(go);
            string path = AssetDatabase.GetAssetPath(go);
            var dependencies = AssetDatabase.GetDependencies(path);
            for (int i = 0; i < dependencies.Length; i++)
            {
                Debug.Log("Dependency: " + dependencies[i]);
            }

            List<string> list = new List<string>();
            for (int i = 0; i < dependencies.Length; i++)
            {
                string t1 = dependencies[i].Substring(0, dependencies[i].LastIndexOf('/'));
                if (t1.Contains("Atlas") && !list.Contains(t1))
                {
                    Debug.LogError("Dependency: " + t1);
                    list.Add(t1);
                }
            }
        }
    }

    public static string GetGameObjectPath(GameObject obj)
    {
        string path = "/" + obj.name;
        while (obj.transform.parent != null)
        {
            obj = obj.transform.parent.gameObject;
            path = "/" + obj.name + path;
        }
        return path;
    }
}

