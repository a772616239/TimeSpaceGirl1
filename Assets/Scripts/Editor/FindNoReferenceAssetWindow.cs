using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;
using System.Linq;
using UnityEditor;
using System.Text;
using System.Text.RegularExpressions;
using GameLogic;
/// <summary>
/// 查找无引用资源（当前为贴图）version 2.0
/// Copyright (c) 2018 Ganchong Xingli
/// </summary>
public class FindNoReferenceAssetWindow:EditorWindow {
	/// <summary>
	/// 匹配资源类型库
	/// </summary>
	public static string ContainsExtensions = "*.*";//"*.prefab*.unity*.mat*.asset";
	/// <summary>
	/// Lua文件夹屏蔽库
	/// </summary>
	public static string WithoutLuaExtensions = "";//"*3rd*.idea*Base*Common*UITools*Logic*";

	/// <summary>
	/// 所有游戏
	/// </summary>
	string[] games;
    /// <summary>
    /// 匹配资源类型库
    /// </summary>
    string containsExtensions = ContainsExtensions;
    /// <summary>
    /// Lua文件夹屏蔽库
    /// </summary>
    string withoutLuaExtensions = WithoutLuaExtensions;
	/// <summary>
	/// 是否检查所有游戏
	/// </summary>
	bool isCheckAllGames;
    /// <summary>
    /// 是否交叉检查
    /// </summary>
    bool isCorssCheck;
    /// <summary>
    /// 是否显示动态加载列表
    /// </summary>
    bool isShowDynamicList;
	/// <summary>
	/// 资源GUID列表
	/// </summary>
	List<string> AssetFileGuidList;
	/// <summary>
	/// 无引用资源 guid列表
	/// </summary>
	List<string> NoRefAssetGuidList;
	/// <summary>
	/// 没有直接引用但动态加载列表
	/// </summary>
	Dictionary<string,string> DynamicLoadAssetList;
	/// <summary>
	/// 所有检查的游戏
	/// </summary>
	Dictionary<string,bool> CheckGames;

    /// <summary>
    /// 查找资源目录
    /// </summary>
    public static string FindPath = AppConst.GameResRealPath + "/{0}";
    /// <summary>
    /// 资源目录
    /// </summary>
    public static string AssetPath = AppConst.GameResRealPath + "/{0}/Textures";
    /// <summary>
    /// Lua文件路径
    /// </summary>
    public static string LuaFilesPath = AppConst.GameResRealPath + "/{0}/~Lua";

    List<string> checkList = new List<string>();

	[MenuItem("Tools/查找无引用贴图", false, 1)]
	static void Init()
	{
		// Get existing open window or if none, make a new one:
		FindNoReferenceAssetWindow window = (FindNoReferenceAssetWindow)EditorWindow.GetWindow(typeof(FindNoReferenceAssetWindow));
		window.Show();
        window.titleContent = new GUIContent("查找无引用资源");
		window.InitWindow();
	}

	/// <summary>
	/// 初始化窗口
	/// </summary>
	void InitWindow()
	{
		InitSize();
		InitGames ();
		//FindNoReferences();
	}

	/// <summary>
	/// 初始化大小
	/// </summary>
	void InitSize()
	{
		minSize = new Vector2(700, 700);
		maxSize = new Vector2(700, 700);
	}

	/// <summary>
	/// 初始化游戏
	/// </summary>
	void InitGames()
	{
		CheckGames = new Dictionary<string, bool> ();
		games = Directory.GetDirectories(AppConst.GameResRealPath);
		for (int i = 0; i < games.Length; i++)
		{
			games[i] = Path.GetFileNameWithoutExtension(games[i]);
			CheckGames.Add (games[i],false);
		}
	}

	void OnGUI()
	{
		ShowCheckGames ();
        ShowWithout();
        ShowButtons();
	}

	/// <summary>
	/// 选择哪些游戏需要检查
	/// </summary>
	void ShowCheckGames()
	{
		EditorGUILayout.BeginVertical();
		EditorGUILayout.HelpBox("请勾选需要检查的游戏", MessageType.None, true);
		//全选/反选
		bool tmpAllGames = isCheckAllGames;
		isCheckAllGames = EditorGUILayout.Toggle("All/None", isCheckAllGames);
        EditorGUILayout.Space();
		if (tmpAllGames != isCheckAllGames) 
		{
			string[] keys = CheckGames.Keys.ToArray<string>();
			foreach (var each in keys)
			{
				CheckGames[each] = isCheckAllGames;
			}
		}

		for (int i = 0; i < games.Length; i++)
		{
			CheckGames[games[i]] = EditorGUILayout.Toggle(games[i], CheckGames[games[i]]);
		}
        EditorGUILayout.EndVertical();
        EditorGUILayout.Space();
        EditorGUILayout.Space();

        EditorGUILayout.BeginVertical();
        isCorssCheck = EditorGUILayout.Toggle("是否交叉检查?", isCorssCheck);
        isShowDynamicList = EditorGUILayout.Toggle("是否显示动态加载列表?", isShowDynamicList);
        EditorGUILayout.EndVertical();
        EditorGUILayout.Space();
	}
    /// <summary>
    /// 显示屏蔽库
    /// </summary>
    void ShowWithout()
    {
        EditorGUILayout.BeginVertical();
        containsExtensions = EditorGUILayout.TextField("匹配资源类型库?", containsExtensions);
        withoutLuaExtensions = EditorGUILayout.TextField("Lua文件夹屏蔽库?", withoutLuaExtensions);
        EditorGUILayout.EndVertical();
        EditorGUILayout.Space();
    }
    /// <summary>
    /// 显示Build按钮
    /// </summary>
    void ShowButtons()
    {
        if (GUILayout.Button("开始检查", GUILayout.Height(40f)))
        {
            FindNoReferences();
        }
    }

	/// <summary>
	/// 查找无引用贴图
	/// </summary>
	void FindNoReferences()
	{
        checkList.Clear();
        if (isCorssCheck)
        {
            ResetList();
            foreach (var game in CheckGames)
            {
                if (!game.Value) continue;
                CollectAllAsset(game.Key);
            }
            foreach(var game in CheckGames)
            {
                if (!game.Value) continue;
                checkList.Add(game.Key);
            }
            ResetList();
            CollectAllAsset(checkList[0]);
            FindReferences(checkList[0]);
        }
        else {
            foreach (var game in CheckGames) {
                if (!game.Value) continue;
                checkList.Add(game.Key);
            }
            ResetList();
            CollectAllAsset(checkList[0]);
            FindReferences(checkList[0]);
        }
	}

    void ResetList()
    {
        AssetFileGuidList = new List<string>();
        NoRefAssetGuidList = new List<string>();
        DynamicLoadAssetList = new Dictionary<string, string>();
    }

	/// <summary>
	/// 搜集所有的资源
	/// </summary>
	void CollectAllAsset(string game)
	{
        string assetPath = string.Format(AssetPath, game);
        var files = Directory.GetFiles(assetPath, "*.*", SearchOption.AllDirectories).Where(item => { return Path.GetExtension(item) == ".png" || Path.GetExtension(item) == ".jpg"; });
		foreach (var path in files) {
			if(string.IsNullOrEmpty(path))continue;
			var guid = AssetDatabase.AssetPathToGUID (GetRelativeAssetsPath(path));
			AssetFileGuidList.Add(guid);
		}
	}

	/// <summary>
	/// 查找引用
	/// </summary>
	void FindReferences(string game)
	{
		int startIndex = 0;
		int count = AssetFileGuidList.Count;
		string guid = AssetFileGuidList [startIndex];
		string curAssetPath = AssetDatabase.GUIDToAssetPath (guid);
        string findPath = string.Format(FindPath,game);
		string[] files = Directory.GetFiles(findPath, "*.*", SearchOption.AllDirectories)
			.Where(s => containsExtensions.Contains(Path.GetExtension(s).ToLower())).ToArray();
		int findIndex = 0;
		bool haveRef = false;
		EditorApplication.update += delegate() {
			string file = files [findIndex];

			bool isCancel = EditorUtility.DisplayCancelableProgressBar ("查找资源中。。。", curAssetPath.Replace(AssetPath.Replace(Application.dataPath,"Assets")+"/",""), (float)(findIndex+startIndex*files.Length) / (float)(count*files.Length));

			if (Regex.IsMatch (File.ReadAllText (file), guid)) {
				haveRef = true;
			}
			findIndex++;
			if(findIndex>=files.Length)
			{
				findIndex = 0;
				startIndex++;
				if(!haveRef&&!MatchLuaFiles(curAssetPath,game)){
					NoRefAssetGuidList.Add(guid);
				}
				haveRef = false;
				if(startIndex<count){
					guid = AssetFileGuidList[startIndex];
					curAssetPath = AssetDatabase.GUIDToAssetPath (guid);
				}
			}
			if (isCancel || startIndex >= count) {
				EditorUtility.ClearProgressBar ();
				EditorApplication.update = null;
				findIndex = 0;
				startIndex = 0;
                DebugNoRefList(game);
                DebugDynamicLoadList(game);
                checkList.Remove(game);
                if (checkList.Count > 0)
                {
                    ResetList();
                    CollectAllAsset(checkList[0]);
                    FindReferences(checkList[0]);
                }
			}
		};

	}

	/// <summary>
	/// 获取资源真实路径
	/// </summary>
	private string GetRelativeAssetsPath(string path)
	{
		return "Assets" + Path.GetFullPath(path).Replace(Path.GetFullPath(Application.dataPath), "").Replace('\\', '/');
	}

	/// <summary>
	/// 打印无引用资源列表
	/// </summary>
	void DebugNoRefList(string game)
	{
        Debug.Log(string.Format("=============================={0}无引用资源列表Start================================",game));
		foreach (var guid in NoRefAssetGuidList) {
			if (string.IsNullOrEmpty (guid))
				continue;
			Debug.Log (AssetDatabase.GUIDToAssetPath (guid));
		}
        Debug.Log(string.Format("=============================={0}无引用资源列表  End================================\n", game));
	}

	/// <summary>
	/// 打印动态加载资源列表
	/// </summary>
	void DebugDynamicLoadList(string game)
	{
        if (!isShowDynamicList) return;
        Debug.Log(string.Format("=============================={0}动态加载资源列表Start================================", game));
		DirectoryInfo directoryInfo;
		foreach (var dic in DynamicLoadAssetList) {
			if (string.IsNullOrEmpty (dic.Key))
				continue;
			directoryInfo = new DirectoryInfo (dic.Key);
			Debug.Log (string.Format("Asset:{0} is dynamic load in lua file {1}",directoryInfo.Name,dic.Value));
		}
        Debug.Log(string.Format("=============================={0}动态加载资源列表  End================================\n", game));
	}

	/// <summary>
	/// 匹配lua文件
	/// </summary>
	bool MatchLuaFiles(string assetPath,string game)
	{
		DirectoryInfo directoryInfo = new DirectoryInfo (assetPath);
		var assetName = directoryInfo.Name.Replace(".jpg","").Replace(".png","");
        var luaFilesPath = string.Format(LuaFilesPath,game);
        directoryInfo = new DirectoryInfo(luaFilesPath);
		var dirctoryInfos = directoryInfo.GetDirectories ().Where(item=>!withoutLuaExtensions.Contains(item.Name));
		foreach(var info in dirctoryInfos)
		{
			if (info == null)
				continue;
			var files = Directory.GetFiles (info.FullName, "*.*", SearchOption.AllDirectories);
			foreach(var file in files)
			{
				if (file.EndsWith (".meta"))
					continue;
				var text = File.ReadAllText (file);
				if (Regex.IsMatch (File.ReadAllText (file), assetName)) {
					DynamicLoadAssetList.Add (assetPath,file);
					return true;
				}
                if(Regex.IsMatch(assetName,"[0-9]{1,}$")){
                    var str = assetName.Substring(0, assetName.Length - 1);
                    if (Regex.IsMatch(File.ReadAllText(file), str))
                    {
                        DynamicLoadAssetList.Add(assetPath, file);
                        return true;
                    }
                }
			}
		}
		return false;
	}
}
