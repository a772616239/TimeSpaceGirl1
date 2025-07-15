using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace UnrealM
{
    [CustomEditor(typeof(SpriteAnimationClip), true)]
    [CanEditMultipleObjects]
    public class SpriteAnimationClipEditor : Editor
    {
        private static string[] PrefrabPath = new string[] { "Assets/ManagedResources/test" };

        private static System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();

        [MenuItem("Tools/Sprite Animation/Create Clip")]
        private static void CreateSpriteAnimationClip()
        {
            SpriteAnimationClip.CreateSpriteAnimationClip("NewClip");
        }

        public override void OnInspectorGUI()
        {
            //if (GUILayout.Button("Sort"))
            //{
            //    for (int i = 0; i < targets.Length; i++)
            //    {
            //        SpriteAnimationClip s = targets[i] as SpriteAnimationClip;
            //        s.Sort();
            //    }
            //}

            if (GUILayout.Button("Load by First Frame"))
            {
                for (int i = 0; i < targets.Length; i++)
                {
                    SpriteAnimationClip s = targets[i] as SpriteAnimationClip;
                    s.LoadByFirstFrame();
                }
            }

            base.OnInspectorGUI();
        }

        //> 设置frame第一帧
        [MenuItem("Tools/Sprite Animation/SetFirstFrame")]
        private static void SetFirstFrame()
        {
            return;

            if (EditorUtility.DisplayDialog("SetFirstFrame", "设置unit_ turret节点设置为第1帧，是否继续？", "是", "否"))
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
                        Transform childup = newPrefab.transform.Find("up/turret");
                        Transform childdown = newPrefab.transform.Find("down/turret");
                        if (childup != null)
                        {
                            var imageAni = childup.gameObject.GetComponentInChildren<ImageAnimation>(true);
                            ImageAnimation s = imageAni as ImageAnimation;
                            s.image = s.GetComponent<Image>();
                            if (s.image)
                            {
                                //Undo.RecordObject(s.image, "Setup First Frame");
                                s.image.sprite = s.clips[0].sprites[0];
                                s.image.SetNativeSize();
                            }
                        }

                        if (childdown != null)
                        {
                            var imageAni = childdown.gameObject.GetComponentInChildren<ImageAnimation>(true);
                            ImageAnimation s = imageAni as ImageAnimation;
                            s.image = s.GetComponent<Image>();
                            if (s.image)
                            {
                                //Undo.RecordObject(s.image, "Setup First Frame");
                                s.image.sprite = s.clips[0].sprites[0];
                                s.image.SetNativeSize();
                            }
                        }

                        PrefabUtility.SaveAsPrefabAsset(newPrefab, path);
                        UnityEngine.Object.DestroyImmediate(newPrefab);
                    }
                }
                time.Stop();
                EditorUtility.ClearProgressBar();
                Debug.Log("设置完成");
            }
        }
    }
}