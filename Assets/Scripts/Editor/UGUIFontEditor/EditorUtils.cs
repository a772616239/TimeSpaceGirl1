using UnityEngine;
using System.Collections;
using System.IO;

public class EditorUtils : MonoBehaviour 
{	
	/// <summary>
	/// 
	/// </summary>
	/// <param name="dirName"></param>
	/// <returns>filename</returns>
	public static string SelectObjectPathInfo(ref string dirName)
	{
		// Unity 6：activeInstanceID 已废弃，改用 activeEntityId（这里只需判断「有没有选中对象」）
		if (UnityEditor.Selection.activeObject == null)
		{
			return "";
		}

		string path = UnityEditor.AssetDatabase.GetAssetPath(UnityEditor.Selection.activeObject);

		dirName = Path.GetDirectoryName(path) + "/";
		return Path.GetFileName(path);
	}
}
