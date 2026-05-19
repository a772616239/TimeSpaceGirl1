using UnityEngine;
using UnityEditor;
using Spine.Unity;
using System.IO;
using System.Linq;

namespace Spine.Skills
{
    public class SpineImportHelper : Editor
    {
        [MenuItem("Tools/Spine/Process Selected Folder")]
        public static void ProcessSelectedFolder()
        {
            Object selected = Selection.activeObject;
            string path = AssetDatabase.GetAssetPath(selected);
            
            if (string.IsNullOrEmpty(path) || !AssetDatabase.IsValidFolder(path))
            {
                Debug.LogError("Please select a folder containing Spine assets.");
                return;
            }

            Debug.Log($"Processing Spine assets in: {path}");
            
            AssetDatabase.Refresh();

            // Find assets
            string[] guids = AssetDatabase.FindAssets("t:SkeletonDataAsset", new[] { path });
            if (guids.Length == 0)
            {
                Debug.LogError("No SkeletonDataAsset found in selected folder.");
                return;
            }

            string skeletonDataPath = AssetDatabase.GUIDToAssetPath(guids[0]);
            SkeletonDataAsset skeletonDataAsset = AssetDatabase.LoadAssetAtPath<SkeletonDataAsset>(skeletonDataPath);

            guids = AssetDatabase.FindAssets("t:SpineAtlasAsset", new[] { path });
            if (guids.Length == 0)
            {
                Debug.LogError("No SpineAtlasAsset found in selected folder.");
                return;
            }

            string atlasPath = AssetDatabase.GUIDToAssetPath(guids[0]);
            SpineAtlasAsset atlasAsset = AssetDatabase.LoadAssetAtPath<SpineAtlasAsset>(atlasPath);

            // Link them
            bool changed = false;
            if (skeletonDataAsset.atlasAssets == null || skeletonDataAsset.atlasAssets.Length == 0 || skeletonDataAsset.atlasAssets[0] != atlasAsset)
            {
                skeletonDataAsset.atlasAssets = new AtlasAssetBase[] { atlasAsset };
                changed = true;
            }

            if (changed)
            {
                EditorUtility.SetDirty(skeletonDataAsset);
                AssetDatabase.SaveAssets();
                Debug.Log("<color=green>Successfully linked Atlas to SkeletonDataAsset.</color>");
            }

            // Verify
            skeletonDataAsset.Clear();
            var data = skeletonDataAsset.GetSkeletonData(true);
            if (data == null)
            {
                Debug.LogError("Failed to parse SkeletonData. Ensure version compatibility.");
            }
            else
            {
                Debug.Log($"<color=green>Spine Import Success!</color> Found {data.Animations.Count} animations.");
            }
        }
    }
}
