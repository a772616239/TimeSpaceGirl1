using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.UI;
using System.IO;
using Spine.Unity;


public class CreateSpineTool : MonoBehaviour {

	[MenuItem("Assets/Tools/CreateSpine")]
	public static void CreateSpine()
	{
	
		var objs = Selection.objects;
		if (objs.Length == 0 || objs == null) 
		{
			Debug.LogError("No Selected Item");
			return;
		}

		
		string matPath = "";
		string skePath = "";
		string imgName = "";

		foreach (var item in objs)
		{
			string fileName = AssetDatabase.GetAssetPath(item);
			if (fileName.EndsWith("mat")) {
				matPath = fileName;
				continue;
			}
		
			if (fileName.Contains("SkeletonData")){
				skePath = fileName;
				continue;
			}

			if (fileName.EndsWith("png"))
			{
				imgName = item.name;
				continue;
			}

			
		}

		CreateSpinePrefab(matPath, skePath, imgName);
	}

	private static void CreateSpinePrefab(string matPath, string skePath, string imgName)
	{
		// 预设路径
		string prePath = "Assets/ManagedResources/Prefabs/Map";
		string name = "";
		string tempName = string.Format("live2d_{0}", imgName);
		prePath = string.Format("{0}/{1}", prePath, tempName);

		GameObject go = new GameObject(tempName);
		SkeletonGraphic skeleton = go.GetComponent<SkeletonGraphic>();
		if (skeleton == null) {
			go.AddComponent(typeof(SkeletonGraphic));
		}

		skeleton = go.GetComponent<SkeletonGraphic>();
		Material mat = null;
		SkeletonDataAsset skeAsset = null;
		mat = AssetDatabase.LoadAssetAtPath<Material>(matPath);
		skeAsset = AssetDatabase.LoadAssetAtPath<SkeletonDataAsset>(skePath);
		skeleton.material = mat;
		skeleton.skeletonDataAsset = skeAsset;
		string filePath = string.Format("{0}.prefab", prePath);
		PrefabUtility.CreatePrefab(filePath, go);
		AssetDatabase.SaveAssets();
		AssetDatabase.Refresh();
	}
}
