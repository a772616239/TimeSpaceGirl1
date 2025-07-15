using System;

namespace ResMgr
{
	/// <summary>
	/// 资源配置
	/// </summary>
	public static class ResConfig
	{
		/// <summary>
		/// AB包的扩展名
		/// </summary>
		public static string ABExtName = ".unity3d";
		/// <summary>
		/// 持久化目录
		/// </summary>
		public static string PersistentDataPath;
		/// <summary>
		/// 流媒体资源目录
		/// </summary>
		public static string StreamPath;
		// "/"->'|'
		public static string Convert2CombineName(string path)
		{
			return path.Replace("/", "|");
		}
		
		public static string Convert2PathName(string path)
		{
			return path.Replace("|", "/");
		}
	}
}

