using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using System.Text;
using System.IO;

namespace GameEditor.Core
{
    public class ArtFontTool
    {
        [MenuItem("Tools/对比图片字/中韩")]
        public static void Find_zh_kr()
        {
            string leftPath = Application.dataPath + "\\ManagedResources\\ArtFont_kr";
            string rightPath = Application.dataPath + "\\ManagedResources\\ArtFont_zh";
            Find(leftPath, rightPath);
        }
        [MenuItem("Tools/对比图片字/中日")]
        public static void Find_zh_jp()
        {
            string leftPath = Application.dataPath + "\\ManagedResources\\ArtFont_jp";
            string rightPath = Application.dataPath + "\\ManagedResources\\ArtFont_zh";
            Find(leftPath, rightPath);
        }

        [MenuItem("Tools/对比图片字/中英")]
        public static void Find_zh_en()
        {
            string leftPath = Application.dataPath + "\\ManagedResources\\ArtFont_en";
            string rightPath = Application.dataPath + "\\ManagedResources\\ArtFont_zh";
            Find(leftPath, rightPath);
        }

        public static void Find(string leftPath, string rightPath)
        {
            List<string> allArtFontList = new List<string>();
            Debug.Log("开始查找");
            //string leftPath = Application.dataPath + "\\ManagedResources\\ArtFont_kr";
            //string rightPath = Application.dataPath + "\\ManagedResources\\ArtFont_zh";
            DirectoryInfo Folder_left = new DirectoryInfo(leftPath);
            DirectoryInfo[] leftInfos = Folder_left.GetDirectories();
            List<string> leftFontPngList = new List<string>();

            DirectoryInfo Folder_right = new DirectoryInfo(rightPath);
            DirectoryInfo[] rightInfos = Folder_right.GetDirectories();
            List<string> rightFontPngList = new List<string>();

            for (int i = 0; i < rightInfos.Length; i++)
            {
                bool notHave = true;
                for (int j = 0; j < leftInfos.Length; j++)
                {
                    //对比文件夹名
                    if (leftInfos[j].Name == rightInfos[i].Name)
                    {
                        notHave = false;
                    }
                }
                if (notHave)
                {
                    //若没有则添加到表
                    string foldPath = rightPath + "\\" + rightInfos[i].Name;
                    if (Directory.Exists(foldPath))
                    {
                        DirectoryInfo direction = new DirectoryInfo(foldPath);
                        FileInfo[] files = direction.GetFiles("*", SearchOption.AllDirectories);
                        for (int j = 0; j < files.Length; j++)
                        {
                            if (files[j].Name.EndsWith(".meta"))
                            {
                                continue;
                            }
                            allArtFontList.Add(files[j].Name);
                        }
                    }
                }
                else
                {
                    //若有则对比文件夹下每个图片名
                    string rightFoldPath = rightPath + "\\" + rightInfos[i].Name;
                    if (Directory.Exists(rightFoldPath))
                    {
                        DirectoryInfo direction = new DirectoryInfo(rightFoldPath);
                        FileInfo[] files = direction.GetFiles("*", SearchOption.AllDirectories);
                        for (int j = 0; j < files.Length; j++)
                        {
                            if (files[j].Name.EndsWith(".meta"))
                            {
                                continue;
                            }
                            rightFontPngList.Add(files[j].Name);
                        }
                    }

                    string leftFoldPath = leftPath + "\\" + rightInfos[i].Name;
                    if (Directory.Exists(leftFoldPath))
                    {
                        DirectoryInfo direction = new DirectoryInfo(leftFoldPath);
                        FileInfo[] files = direction.GetFiles("*", SearchOption.AllDirectories);
                        for (int j = 0; j < files.Length; j++)
                        {
                            if (files[j].Name.EndsWith(".meta"))
                            {
                                continue;
                            }
                            leftFontPngList.Add(files[j].Name);
                        }
                    }
                }
            }
            //对比每个图片名
            for (int rightIndex = 0; rightIndex < rightFontPngList.Count; rightIndex++)
            {
                bool have = false;
                string right = rightFontPngList[rightIndex].Substring(0, rightFontPngList[rightIndex].Length - 6);
                for (int leftIndex = 0; leftIndex < leftFontPngList.Count; leftIndex++)
                {
                    string left = leftFontPngList[leftIndex].Substring(0, leftFontPngList[leftIndex].Length - 6);
                    if (right == left)
                    {
                        have = true;
                    }
                }
                if (have == false)
                {
                    allArtFontList.Add(rightFontPngList[rightIndex]);
                }
            }
            Debug.Log("查找结束");
            Debug.Log("写入中");
            string txTPath = Application.dataPath + "\\ArtFont.txt";
            string[] str = allArtFontList.ToArray();
            // 判断文件是否存在，不存在则创建，否则清空重新写入
            if (!File.Exists(txTPath))
            {
                FileStream fs = new FileStream(txTPath, FileMode.Append);
                StreamWriter sw = new StreamWriter(fs);
                for(int v = 0; v < allArtFontList.Count; v++)
                {
                    sw.WriteLine(allArtFontList[v]);
                }
                sw.Close();
            }
            else
            {
                File.WriteAllText(txTPath, string.Empty);
                File.WriteAllLines(txTPath, str);
            }
            Debug.Log("写入结束");
            Debug.Log("路径：" + Application.dataPath + "\\ArtFont.txt");
        }
    }
}
