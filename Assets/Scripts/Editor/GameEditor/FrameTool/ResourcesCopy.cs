using GameLogic;
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using UnityEditor;
using UnityEngine;

public class ResourcesCopy
{

    [MenuItem("Build/资源拷贝")]
    public static void ChoosePath()
    {
        string tarPath = SelectFolder();
        if (!string.IsNullOrEmpty(tarPath))
        {
            if (Application.platform == RuntimePlatform.OSXEditor)
            {
                Debug.LogError("拷贝：" + Application.dataPath.Replace("Assets", string.Empty) + @"BuildABs/" + AppConst.PlatformPath);
                Debug.LogError("目标：" + tarPath);
                CopyFolder(Application.dataPath.Replace("Assets", string.Empty) + @"BuildABs/" + AppConst.PlatformPath, tarPath);
            }
            else
            {
                if (tarPath == @"C:\"
                    || tarPath == @"D:\"
                    || tarPath == @"E:\"
                    || tarPath == @"F:\"
                    || tarPath == Application.dataPath
                    || tarPath == @"C:\Users\admin\Desktop")
                    MessageBoxTip.MessageBox(IntPtr.Zero, "不可选择：" + tarPath, "提示", 0);
                else
                {
                    int type = MessageBoxTip.MessageBox(IntPtr.Zero, "是否选择：" + tarPath + "\n选择到Android || Ios文件夹", "提示", 1);
                    switch (type)
                    {
                        case 0:
                            break;
                        case 1:
                            Debug.LogError("拷贝：" + Application.dataPath.Replace("Assets", string.Empty) + @"BuildABs/" + AppConst.PlatformPath);
                            Debug.LogError("目标：" + tarPath);
                            CopyFolder(System.Environment.CurrentDirectory + @"\BuildABs\" + AppConst.PlatformPath, tarPath);
                            break;
                    }
                }
            }
        }
        else
            Debug.LogError("未选择路径");
    }

    /// <summary>
    /// 拷贝文件夹
    /// </summary>
    /// <param name = "srcPath">需要被拷贝的文件夹路径</param>
    /// <param name = "tarPath">拷贝目标路径</param>
    private static void CopyFolder(string srcPath, string tarPath)
    {
        DirectoryInfo srcFolder = new DirectoryInfo(srcPath);
        if (!srcFolder.Exists)
            Debug.LogError("不存在：" + srcPath);
        else
        {
            Debug.LogError("正在拷贝资源。。。");
            string tarFolder = Path.GetDirectoryName(tarPath);
            if (Directory.Exists(tarPath))//存在目标文件夹
                Directory.Delete(tarPath, true);//删除文件夹

            Directory.CreateDirectory(tarPath);//创建文件夹
            foreach (var file in Directory.GetFiles(srcPath))
            {
                File.Copy(file, Path.Combine(tarPath, Path.GetFileName(file)), true);
            }

            foreach (var dir in Directory.GetDirectories(srcPath))
            {
                CopyAndReplaceDirectory(dir, Path.Combine(tarPath, Path.GetFileName(dir)));
            }
        }

        Debug.LogError("正在拷贝version。。。");

        string directoryPath = Path.GetDirectoryName(tarPath + "/version.txt");
        if (!Directory.Exists(directoryPath)) Directory.CreateDirectory(directoryPath);
        File.Copy(Application.dataPath + "/Resources/version.txt", tarPath + "/version.txt", true);

        Debug.LogError("拷贝完成");
    }
    /// <summary>
    /// 文件夹拷贝到指定文件夹
    /// </summary>
    /// <param name = "srcPath"></param>
    /// <param name = "tarPath"></param>
    static void CopyAndReplaceDirectory(string srcPath, string tarPath)
    {
        Directory.CreateDirectory(tarPath);
        foreach (var file in Directory.GetFiles(srcPath))
        {
            File.Copy(file, Path.Combine(tarPath, Path.GetFileName(file)), true);
        }

        foreach (var dir in Directory.GetDirectories(srcPath))
        {
            CopyAndReplaceDirectory(dir, Path.Combine(tarPath, Path.GetFileName(dir)));
        }
    }

    /// <summary>
    /// 选择文件夹
    /// </summary>
    /// <returns>目标路径</returns>
    private static string SelectFolder()
    {
        string path = EditorUtility.OpenFolderPanel("选择目标路径", System.Environment.CurrentDirectory, "");
        return path;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public class OpenDialogFile
    {
        public int structSize = 0;
        public IntPtr dlgOwner = IntPtr.Zero;
        public IntPtr instance = IntPtr.Zero;
        public String filter = null;
        public String customFilter = null;
        public int maxCustFilter = 0;
        public int filterIndex = 0;
        public String file = null;
        public int maxFile = 0;
        public String fileTitle = null;
        public int maxFileTitle = 0;
        public String initialDir = null;
        public String title = null;
        public int flags = 0;
        public short fileOffset = 0;
        public short fileExtension = 0;
        public String defExt = null;
        public IntPtr custData = IntPtr.Zero;
        public IntPtr hook = IntPtr.Zero;
        public String templateName = null;
        public IntPtr reservedPtr = IntPtr.Zero;
        public int reservedInt = 0;
        public int flagsEx = 0;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public class OpenDialogDir
    {
        public IntPtr hwndOwner = IntPtr.Zero;
        public IntPtr pidlRoot = IntPtr.Zero;
        public String pszDisplayName = null;
        public String lpszTitle = null;
        public UInt32 ulFlags = 0;
        public IntPtr lpfn = IntPtr.Zero;
        public IntPtr lParam = IntPtr.Zero;
        public int iImage = 0;
    }
    public class DllOpenFileDialog
    {
        [DllImport("Comdlg32.dll", SetLastError = true, ThrowOnUnmappableChar = true, CharSet = CharSet.Auto)]
        public static extern bool GetOpenFileName([In, Out] OpenDialogFile ofn);

        [DllImport("Comdlg32.dll", SetLastError = true, ThrowOnUnmappableChar = true, CharSet = CharSet.Auto)]
        public static extern bool GetSaveFileName([In, Out] OpenDialogFile ofn);

        [DllImport("shell32.dll", SetLastError = true, ThrowOnUnmappableChar = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SHBrowseForFolder([In, Out] OpenDialogDir ofn);

        [DllImport("shell32.dll", SetLastError = true, ThrowOnUnmappableChar = true, CharSet = CharSet.Auto)]
        public static extern bool SHGetPathFromIDList([In] IntPtr pidl, [In, Out] char[] fileName);

    }
    public class MessageBoxTip
    {
        [DllImport("User32.dll", SetLastError = true, ThrowOnUnmappableChar = true, CharSet = CharSet.Auto)]
        public static extern int MessageBox(IntPtr handle, String message, String title, int type);
    }
}