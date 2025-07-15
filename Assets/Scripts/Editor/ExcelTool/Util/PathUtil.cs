using UnityEngine;

namespace GameEditor.Core.Util
{
    public static class PathUtil
    {
        public static string GetAssetPath(string dirPath)
        {
            if (dirPath.StartsWith(Application.dataPath))
            {
                return "Assets" + dirPath.Replace(Application.dataPath, "");
            }
            return string.Empty;
        }

        public static string GetDiskPath(string assetPath)
        {
            if (string.IsNullOrEmpty(assetPath))
            {
                return string.Empty;
            }
            if (!assetPath.StartsWith("Assets"))
            {
                return string.Empty;
            }
            return Application.dataPath + assetPath.Substring(assetPath.IndexOf("Assets") + 6);
        }
    }
}


