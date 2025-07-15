using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using System.Linq;

namespace GameEditor.Core
{
    public class CompareDirResources
    {
        static List<string> compareList=new List<string>();
        //------------------------------资源下路径匹配--------------------------------------//
        [MenuItem("Tools/Font/ArtFont资源对比/全路径匹配/ArtFont zh 对比 en 对应路径缺失资源列表")]
        public static void ComparePic_ZHtoen()
        {
            ComparePic("zh","en");
        }

        [MenuItem("Tools/Font/ArtFont资源对比/全路径匹配/ArtFont  jp 对比 en 对应路径缺失资源列表")]
        public static void ComparePic_ZHtojp()
        {
            ComparePic("jp", "en");
        }

        [MenuItem("Tools/Font/ArtFont资源对比/全路径匹配/ArtFont  kr 对比 en 对应路径缺失资源列表")]
        public static void ComparePic_Krtoen()
        {
            ComparePic("kr", "en");
        }

        [MenuItem("Tools/Font/ArtFont资源对比/资源匹配/ArtFont  zh 对比 kr缺失资源")]
        public static void ComparePic_ZHtokr()
        {
            ComparePic("zh", "kr");
        }


        //------------------------------资源匹配--------------------------------------//

        [MenuItem("Tools/Font/ArtFont资源对比/资源匹配/ArtFont  zh 对比 en缺失资源")]
        public static void ComparePath_ZHtoen()
        {
            SearchResources("zh", "en");
        }

        [MenuItem("Tools/Font/ArtFont资源对比/资源匹配/ArtFont  kr 对比 en缺失资源")]
        public static void ComparePath_Krtoen()
        {
            SearchResources("kr", "en");
        }

        [MenuItem("Tools/Font/ArtFont资源对比/资源匹配/ArtFont  jp 对比 en缺失资源")]
        public static void ComparePath_Jptoen()
        {
            SearchResources("jp", "en");
        }

        [MenuItem("Tools/Font/ArtFont资源对比/资源匹配/ArtFont  zh 对比 kr缺失资源")]
        public static void ComparePath_ZHtokr()
        {
            SearchResources("zh", "kr");
        }

        public static void ComparePic(string ori, string dir)
        {
          compareList.Clear();
          string picPath=Application.dataPath+"/"+"ManagedResources/ArtFont_"+dir;
          DirectoryInfo TheMainFolder = new DirectoryInfo(picPath);
          getDirectory(picPath, ori, dir);
          string join="";
          foreach(string i in compareList){
            join+=i;
          }
          File.AppendAllText(Application.dataPath+"/"+string.Format("compare_{0}_vs_{1}.txt",ori,dir), join, System.Text.Encoding.UTF8);
          EditorUtility.ClearProgressBar();
          AssetDatabase.Refresh();
        }

        /*
        * 获得指定路径下所有文件名
        * string path      文件路径
        * string ori       原始对比文件尾缀 例如 en zh
        * string dir       被对比的文件尾缀 
        */
        public static void getFileName(string path,string ori,string dir)
        {
            DirectoryInfo root = new DirectoryInfo(path);
            foreach(FileInfo f in root.GetFiles())
            {
                if(f.Name.Contains(".meta"))
                {
                    continue;
                }
                // Debug.Log(path.Replace("ArtFont_en","ArtFont_zh"));
                // Debug.Log("文件："+f.Name+" 111存在："+File.Exists(path.Replace("en","zh")+"/"+f.Name)+ " 222存在："+File.Exists(path+"/"+f.Name));
                if (File.Exists(path.Replace(dir, ori) +"/"+f.Name.Replace(dir, ori)))
                {
                    Debug.Log("查找到存在文件："+f.Name);
                }else{
                    string warn= "\n未查找到存在文件： " + f.Name.Replace(dir, ori) + " \n文件1 目录："+path.Replace(dir, ori) +"/"+f.Name+" \n  文件2 目录:"+path+"/"+f.Name;
                    Debug.Log(warn);     
                    compareList.Add(warn);
                }
            }
        }


        //获得指定路径下所有子目录名
        public static void getDirectory(string path, string ori, string dir)
        {
            DirectoryInfo root = new DirectoryInfo(path);
            int index=0;
            int rootLen = root.GetDirectories().Length;
            foreach (DirectoryInfo d in root.GetDirectories())
            {
                index++;
                EditorUtility.DisplayProgressBar(string.Format("正在读取： ({0}/{1}) 路径：{2}", index, rootLen,path), index+"", rootLen);
                getFileName(path+"/"+d.Name, ori,dir);
                getDirectory(d.FullName, ori, dir);
            }
            
        }

        public static void SearchResources(string sourceType, string compareType)
        {
            string path = Application.dataPath + "/" + "ManagedResources/ArtFont_"+sourceType;
            string pathDir = Application.dataPath + "/" + "ManagedResources/ArtFont_"+compareType;
            Dictionary<string, string> sourceDate = new Dictionary<string, string>();
            Dictionary<string, string> compareDate = new Dictionary<string, string>();
            sourceDate=SearchFiles(path);   //全资源
            compareDate=SearchFiles(pathDir);//检测缺失资源
            string joinStr = "";
            string pic = "";
            string picPath = "";
            int index = 0;
            foreach (var item in sourceDate)
            {
                if (!compareDate.ContainsKey(item.Key.ToString().Replace(sourceType,compareType))) {
                    Debug.LogError("不存在文件在："+item.Value);
                    joinStr += "不存在文件在：" +item.Key.ToString().Replace(sourceType+".", compareType + ".") + " \n  路径："+ item.Value + "\n";
                    pic += " \n  缺失文件名：" + item.Key.ToString().Replace(sourceType + ".", compareType + ".");
                    picPath += " \n  缺失文件对应路径：" + item.Value.ToString().Replace(sourceType + ".", compareType + ".");
                    index++;
                }
            }
            File.WriteAllText(Application.dataPath + "/" + string.Format("compare{0}{1}_log.txt", sourceType, compareType),
                string.Format("丢失文件总数：{0}\n"+ joinStr, index), System.Text.Encoding.UTF8);
            File.WriteAllText(Application.dataPath + "/" + string.Format("compare{0}{1}_name.txt", sourceType, compareType), 
                string.Format("丢失文件总数：{0}\n" + pic, index), System.Text.Encoding.UTF8);
            File.WriteAllText(Application.dataPath + "/" + string.Format("compare{0}{1}_path.txt", sourceType, compareType), 
                string.Format("丢失文件总数：{0}\n" + picPath, index), System.Text.Encoding.UTF8);
            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
        }

        public static Dictionary<string,string> SearchFiles(string path) {
            Dictionary<string, string> date = new Dictionary<string, string>();
            List<string> directories = new List<string>();
            List<string> files = new List<string>();
            getFileDirectories(path, directories);
            //Debug.LogError("文件夹数：" + directories.Count);
            for (int i = 0; i < directories.Count; i++)
            {
                List<string> orifiles = Directory.GetFiles(directories[i], "*", SearchOption.TopDirectoryOnly).Where(s => !s.EndsWith(".meta")).ToList();
                if (orifiles.Count > 0)
                {
                    for (int j = 0; j < orifiles.Count; j++)
                    {
                       // Debug.LogError("文件全路径：" + orifiles[j]);
                        int index = orifiles[j].Split(new string[] { "/" }, System.StringSplitOptions.RemoveEmptyEntries).Count();
                        date[orifiles[j].Split(new string[] { "/", "\\" }, System.StringSplitOptions.RemoveEmptyEntries)[index]] = orifiles[j];
                        files.Add(orifiles[j].Split(new string[] { "/", "\\" }, System.StringSplitOptions.RemoveEmptyEntries)[index]);
                        EditorUtility.DisplayProgressBar(string.Format("正在读取 {0}： ({1}/{2}) 路径：{3}", directories[i], i, directories.Count, path), orifiles[j] + "", j/ orifiles.Count);
                        // Debug.LogError("文件：" + orifiles[j].Split(new string[] { "/", "\\" }, System.StringSplitOptions.RemoveEmptyEntries)[index]);
                    }
                }
            }
            //Debug.LogError("文件数：" + files.Count);
            return date;

        }

        //------------------------------资源匹配--------------------------------------//
        static void getFileDirectories(string path, List<string> list)
        {
            string[] directies = Directory.GetDirectories(path, "*", SearchOption.AllDirectories);
            foreach (var item in directies)
            {
                list.Add(item.Replace("\\", "/"));
                getFileDirectories(item, list);
            }
        }

    }

}

