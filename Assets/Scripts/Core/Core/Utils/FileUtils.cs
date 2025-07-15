using System;
using System.IO;

namespace GameCore {
    /// <summary>
    /// 文件工具
    /// </summary>
    public static class FileUtils
    {
        /// <summary>
        /// 拷贝文件
        /// </summary>
        public static void CopyFile(string inPath, string outPath) {
            try
            {
                string directoryPath = Path.GetDirectoryName(outPath);
                if (!Directory.Exists(directoryPath)) Directory.CreateDirectory(directoryPath);
                File.Copy(inPath, outPath, true);
            }
            catch (Exception e)
            {
                throw (e);
            }
        }

        /// <summary>
        /// 创建目录
        /// </summary>
        /// <param name="path"></param>
        public static void CreateDirectory(string path) {
            if (!Directory.Exists(path))
                Directory.CreateDirectory(path);

        }

        /// <summary>
        /// 写入所有text
        /// </summary>
        public static void WriteAllText(string path, string text) {
            try
            {
                string directoryPath = Path.GetDirectoryName(path);
                if (!Directory.Exists(directoryPath)) Directory.CreateDirectory(directoryPath);
                File.WriteAllText(path, text);
            }
            catch (Exception e)
            {
                throw (e);
            }
        }
        /// <summary>
        /// 写入所有Bytes
        /// </summary>
        public static void WriteAllBytes(string path, byte[] bytes) {
            try {
                string directoryPath = Path.GetDirectoryName(path);
                if (!Directory.Exists(directoryPath)) Directory.CreateDirectory(directoryPath);
                File.WriteAllBytes(path, bytes);
            }
            catch (Exception e) {
                throw (e);
            }
        }

        /// <summary>
        /// 移动文件或者目录
        /// </summary>
        /// <param name="inFile"></param>
        /// <param name="outFile"></param>
        public static void MoveFile(string inFile, string outFile)
        {
            string dir = Path.GetDirectoryName(outFile);
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            if (File.Exists(outFile)) File.Delete(outFile);
            File.Move(inFile, outFile);
        }

        /// <summary>
        /// 拷贝文件夹
        /// </summary>
        /// <param name="fromDir"></param>
        /// <param name="toDir"></param>
        public static void CopyDir(string fromDir, string toDir)
        {
            if (!Directory.Exists(fromDir))
                return;
            if (Directory.Exists(toDir))
            {
                Directory.Delete(toDir, true);
            }
            Directory.CreateDirectory(toDir);
            string[] files = Directory.GetFiles(fromDir);
            foreach (string formFileName in files)
            {
                string fileName = Path.GetFileName(formFileName);
                string toFileName = Path.Combine(toDir, fileName);
                File.Copy(formFileName, toFileName);
            }
            string[] fromDirs = Directory.GetDirectories(fromDir);
            foreach (string fromDirName in fromDirs)
            {
                string dirName = Path.GetFileName(fromDirName);
                string toDirName = Path.Combine(toDir, dirName);
                CopyDir(fromDirName, toDirName);
            }
        }

        public static void Delete(string v)
        {
            if (File.Exists(v))
                File.Delete(v);
        }
    }
}
