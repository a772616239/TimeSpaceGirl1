using System;
using System.Text;
using System.IO;
namespace ResMgr
{
	/// <summary>
	/// 路径工具
	/// </summary>
	public class PathHelper
	{
		/// <summary>
		/// StringBuilder
		/// </summary>
		static StringBuilder stringBuilder = new StringBuilder();

		/// <summary>
		/// 获取完整路径
		/// </summary>
		/// <returns>The full path.</returns>
		/// <param name="keyPath">Key path.</param>
		public static string GetFullPath(string keyPath){
			stringBuilder.Length = 0;
			string path = stringBuilder.Append(ResConfig.PersistentDataPath).Append(keyPath).ToString();
			if (!File.Exists(path))
			{
				stringBuilder.Length = 0;
				path = stringBuilder.Append(ResConfig.StreamPath).Append(keyPath).ToString();
			}
			return path;
		}
	}
}

