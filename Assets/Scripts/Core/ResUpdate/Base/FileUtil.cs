using UnityEngine;
using System;
using System.Text;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using GameCore;
namespace ResUpdate
{
    public class FileUtil
    {
        /// <summary>
        /// 打开文件流，如果不存在，就创建一个文件
        /// </summary>
        /// <param name="filePath"></param>
        /// <returns></returns>
        public static Stream ForceOpenFileStream(string filePath)
        {
            var directory = Path.GetDirectoryName(filePath);
            if (!Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            Stream fileStream = null;
            try
            {
                fileStream = new FileStream(filePath, FileMode.OpenOrCreate, FileAccess.Write);
            }
            catch (Exception e)
            {
                if (fileStream != null)
                {
                    fileStream.Close();
                    fileStream = null;
                }

                if (BaseLogger.isDebug) Debug.LogWarning(string.Format("Failed to force open file stream: {0}, error {1}!", filePath, e.Message));
            }

            return fileStream;
        }

        /// <summary>
        /// 加载文件
        /// </summary>
        /// <param name="filePath"></param>
        /// <returns></returns>
        public static string LoadTextFile(string filePath)
        {
            string text = string.Empty;
            if (File.Exists(filePath))
            {
                text = File.ReadAllText(filePath);
            }
            else
            {
                if (BaseLogger.isDebug) Debug.LogWarning("Load text file is not exist: " + filePath);
            }

            return text;
        }

        /// <summary>
        /// 保存文件
        /// </summary>
        /// <param name="filePath"></param>
        /// <param name="content"></param>
        public static void SaveTextFile(string filePath, string content)
        {
            var stream = ForceOpenFileStream(filePath);
            if (stream == null)
                return;
            var writer = new StreamWriter(stream);
            writer.Write(content);
            writer.Close();
            stream.Close();
        }

        /// <summary>
        /// 打开文件流
        /// </summary>
        /// <param name="filePath"></param>
        /// <returns></returns>
        public static Stream OpenFileStream(string filePath)
        {
            Stream fileStream = null;
            try
            {
                fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
            }
            catch (Exception e)
            {
                if (fileStream != null)
                {
                    fileStream.Close();
                    fileStream = null;
                }

                if (BaseLogger.isDebug) Debug.LogWarning(string.Format("Failed to open file stream: {0}, error {1}", filePath, e.Message));
            }

            return fileStream;
        }

        /// <summary>
        /// 创建一个目录
        /// </summary>
        /// <param name="dirPath"></param>
        public static void CreateDirectory(string dirPath)
        {
            if (!Directory.Exists(dirPath))
                Directory.CreateDirectory(dirPath);
        }

        /// <summary>
        /// 获取文件扩展名
        /// </summary>
        /// <param name="fileName"></param>
        /// <returns></returns>
        public static string GetFileSuffix(string fileName)
        {
            var index = fileName.LastIndexOf('.');
            if (index == -1)
                return string.Empty;
            return fileName.Substring(index);
        }

        public static string GetFilePathWithoutSuffix(string fileName)
        {
            var index = fileName.LastIndexOf('.');
            if (index == -1)
                return fileName;
            else
                return fileName.Substring(0, index);
        }
        
        /// <summary>
        /// 移动文件
        /// </summary>
        /// <param name="srcFilePath"></param>
        /// <param name="destFilePath"></param>
        public static void MoveFile(string srcFilePath, string destFilePath)
        {
            if (File.Exists(srcFilePath))
            {
                if (File.Exists(destFilePath))
                    File.Delete(destFilePath);
                File.Move(srcFilePath, destFilePath);
            }
        }


        /// <summary>
        /// 删除文件
        /// </summary>
        /// <param name="path"></param>
        /// <returns></returns>

        public static bool DeleteFile(string path)
        {
            if (!File.Exists(path))
            {
                return false;
            }

            try
            {
                File.Delete(path);
                return true;
            }
            catch (System.Exception ex)
            {
                if (BaseLogger.isDebug) Debug.LogWarning(string.Format("Failed to deleteFile file {0}: {1}", path, ex.Message));
                return false;
            }
        }


        /// <summary>
        /// 拷贝文件
        /// </summary>
        /// <param name="srcfile"></param>
        /// <param name="destfile"></param>
        /// <returns></returns>
        public static IEnumerator CopyFile(string srcfile, string destfile)
        {
            if (srcfile.Contains("jar:"))
            {
                WWW www = new WWW(srcfile);
                yield return www;
                File.WriteAllBytes(destfile, www.bytes);
                www.Dispose();
                yield break;
            }
            else
            {
                File.Copy(srcfile, destfile);
            }

            yield break;
        }

        public static long GetFileBytesSize(string filePath)
        {
            if (!File.Exists(filePath))
                return 0;
            long byteSize = 0;
            var stream = OpenFileStream(filePath);
            if (stream != null)
            {
                byteSize = stream.Length;
                stream.Close();
            }
            return byteSize;
        }

        public static string[] GetAllFiles(string rootPath)
        {
            if (!Directory.Exists(rootPath))
                return new string[] { };
            return Directory.GetFiles(rootPath, "*", SearchOption.AllDirectories);
        }
        
    }
}
