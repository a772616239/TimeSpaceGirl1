using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;

// 创建bmfont  
public class CreateFontEditor : Editor
{
    [MenuItem("Tools/Font/CreateBMFont")]
    static void CreateFont()
    {
        Object obj = Selection.activeObject;
        string fntPath = AssetDatabase.GetAssetPath(obj);
        CreateFontByPath(fntPath);

        //if (fntPath.IndexOf(".fnt") == -1)
        //{
        //    // 不是字体文件  
        //    return;
        //}

        //string imgPathName = fntPath.Replace(".fnt", "_Tex.tga");
        //string MatPathName = fntPath.Replace(".fnt", "_mat.mat");
        //string customFontPath = fntPath.Replace(".fnt", "_cfont.fontsettings");
        //if(!File.Exists(imgPathName))
        //{
        //    Debug.LogWarning("Image File Not Found");
        //}

        //if (!File.Exists(customFontPath))
        //{
        //    var font = new Font(customFontPath);
        //    AssetDatabase.CreateAsset(font, customFontPath);
        //}

        //Debug.Log(fntPath);
        //StreamReader reader = new StreamReader(new FileStream(fntPath, FileMode.Open));

        //List<CharacterInfo> charList = new List<CharacterInfo>();

        //Regex reg = new Regex(@"char id=(?<id>\d+)\s+x=(?<x>\d+)\s+y=(?<y>\d+)\s+width=(?<width>\d+)\s+height=(?<height>\d+)\s+xoffset=(?<xoffset>\d+)\s+yoffset=(?<yoffset>\d+)\s+xadvance=(?<xadvance>\d+)\s+");
        //string line = reader.ReadLine();
        //int lineHeight = 0;
        //int texWidth = 1;
        //int texHeight = 1;

        //while (line != null)
        //{
        //    if (line.IndexOf("char id=") != -1)
        //    {
        //        Match match = reg.Match(line);
        //        if (match != Match.Empty)
        //        {
        //            var id = System.Convert.ToInt32(match.Groups["id"].Value);
        //            var x = System.Convert.ToInt32(match.Groups["x"].Value);
        //            var y = System.Convert.ToInt32(match.Groups["y"].Value);
        //            var width = System.Convert.ToInt32(match.Groups["width"].Value);
        //            var height = System.Convert.ToInt32(match.Groups["height"].Value);
        //            var xoffset = System.Convert.ToInt32(match.Groups["xoffset"].Value);
        //            var yoffset = System.Convert.ToInt32(match.Groups["yoffset"].Value);
        //            var xadvance = System.Convert.ToInt32(match.Groups["xadvance"].Value);

        //            CharacterInfo info = new CharacterInfo();
        //            info.index = id;
        //            float uvx = 1f * x / texWidth;
        //            float uvy = 1 - (1f * y / texHeight);
        //            float uvw = 1f * width / texWidth;
        //            float uvh = -1f * height / texHeight;

        //            info.uvBottomLeft = new Vector2(uvx, uvy);
        //            info.uvBottomRight = new Vector2(uvx + uvw, uvy);
        //            info.uvTopLeft = new Vector2(uvx, uvy + uvh);
        //            info.uvTopRight = new Vector2(uvx + uvw, uvy + uvh);

        //            info.minX = xoffset;
        //            info.minY = yoffset + height / 2;   // 这样调出来的效果是ok的，原理未知  
        //            info.glyphWidth = width;
        //            info.glyphHeight = -height; // 同上，不知道为什么要用负的，可能跟unity纹理uv有关  
        //            info.advance = xadvance;

        //            charList.Add(info);
        //        }
        //    }
        //    else if (line.IndexOf("scaleW=") != -1)
        //    {
        //        Regex reg2 = new Regex(@"common lineHeight=(?<lineHeight>\d+)\s+.*scaleW=(?<scaleW>\d+)\s+scaleH=(?<scaleH>\d+)");
        //        Match match = reg2.Match(line);
        //        if (match != Match.Empty)
        //        {
        //            lineHeight = System.Convert.ToInt32(match.Groups["lineHeight"].Value);
        //            texWidth = System.Convert.ToInt32(match.Groups["scaleW"].Value);
        //            texHeight = System.Convert.ToInt32(match.Groups["scaleH"].Value);
        //        }
        //    }
        //    line = reader.ReadLine();
        //}

        //var tex = (Texture2D)AssetDatabase.LoadAssetAtPath(imgPathName, typeof(Texture2D));
        //Material mat = (Material)AssetDatabase.LoadAssetAtPath(MatPathName, typeof(Material));
        //if (mat == null)
        //{
        //    //创建材质球
        //    mat = new Material(Shader.Find("GUI/Text Shader"));
        //    mat.SetTexture("_MainTex", tex);
        //    AssetDatabase.CreateAsset(mat, MatPathName);
        //}
        //else
        //{
        //    mat.shader = Shader.Find("GUI/Text Shader");
        //    mat.SetTexture("_MainTex", tex);
        //}

        //Font customFont = AssetDatabase.LoadAssetAtPath<Font>(customFontPath);
        //customFont.characterInfo = charList.ToArray();
        //customFont.material = mat;

        //AssetDatabase.SaveAssets();
        //AssetDatabase.Refresh();
        //Debug.Log(customFontPath);
    }

    public static void CreateFontByPath(string fntPath)
    {
        if (fntPath.IndexOf(".fnt") == -1)
        {
            // 不是字体文件  
            return;
        }

        string imgPathName = fntPath.Replace(".fnt", "_Tex.tga");
        string MatPathName = fntPath.Replace(".fnt", "_mat.mat");
        string customFontPath = fntPath.Replace(".fnt", "_cfont.fontsettings");
        if (!File.Exists(imgPathName))
        {
            Debug.LogWarning("Image File Not Found");
        }

        if (!File.Exists(customFontPath))
        {
            var font = new Font(customFontPath);
            AssetDatabase.CreateAsset(font, customFontPath);
        }

        Debug.Log(fntPath);
        StreamReader reader = new StreamReader(new FileStream(fntPath, FileMode.Open));

        List<CharacterInfo> charList = new List<CharacterInfo>();

        Regex reg = new Regex(@"char id=(?<id>\d+)\s+x=(?<x>\d+)\s+y=(?<y>\d+)\s+width=(?<width>\d+)\s+height=(?<height>\d+)\s+xoffset=(?<xoffset>\d+)\s+yoffset=(?<yoffset>\d+)\s+xadvance=(?<xadvance>\d+)\s+");
        string line = reader.ReadLine();
        int lineHeight = 0;
        int texWidth = 1;
        int texHeight = 1;

        while (line != null)
        {
            if (line.IndexOf("char id=") != -1)
            {
                Match match = reg.Match(line);
                if (match != Match.Empty)
                {
                    var id = System.Convert.ToInt32(match.Groups["id"].Value);
                    var x = System.Convert.ToInt32(match.Groups["x"].Value);
                    var y = System.Convert.ToInt32(match.Groups["y"].Value);
                    var width = System.Convert.ToInt32(match.Groups["width"].Value);
                    var height = System.Convert.ToInt32(match.Groups["height"].Value);
                    var xoffset = System.Convert.ToInt32(match.Groups["xoffset"].Value);
                    var yoffset = System.Convert.ToInt32(match.Groups["yoffset"].Value);
                    var xadvance = System.Convert.ToInt32(match.Groups["xadvance"].Value);

                    CharacterInfo info = new CharacterInfo();
                    info.index = id;
                    float uvx = 1f * x / texWidth;
                    float uvy = 1 - (1f * y / texHeight);
                    float uvw = 1f * width / texWidth;
                    float uvh = -1f * height / texHeight;

                    info.uvBottomLeft = new Vector2(uvx, uvy);
                    info.uvBottomRight = new Vector2(uvx + uvw, uvy);
                    info.uvTopLeft = new Vector2(uvx, uvy + uvh);
                    info.uvTopRight = new Vector2(uvx + uvw, uvy + uvh);

                    info.minX = xoffset;
                    info.minY = yoffset + height / 2;   // 这样调出来的效果是ok的，原理未知  
                    info.glyphWidth = width;
                    info.glyphHeight = -height; // 同上，不知道为什么要用负的，可能跟unity纹理uv有关  
                    info.advance = xadvance;

                    charList.Add(info);
                }
            }
            else if (line.IndexOf("scaleW=") != -1)
            {
                Regex reg2 = new Regex(@"common lineHeight=(?<lineHeight>\d+)\s+.*scaleW=(?<scaleW>\d+)\s+scaleH=(?<scaleH>\d+)");
                Match match = reg2.Match(line);
                if (match != Match.Empty)
                {
                    lineHeight = System.Convert.ToInt32(match.Groups["lineHeight"].Value);
                    texWidth = System.Convert.ToInt32(match.Groups["scaleW"].Value);
                    texHeight = System.Convert.ToInt32(match.Groups["scaleH"].Value);
                }
            }
            line = reader.ReadLine();
        }

        var tex = (Texture2D)AssetDatabase.LoadAssetAtPath(imgPathName, typeof(Texture2D));
        Material mat = (Material)AssetDatabase.LoadAssetAtPath(MatPathName, typeof(Material));
        if (mat == null)
        {
            //创建材质球
            mat = new Material(Shader.Find("GUI/Text Shader"));
            mat.SetTexture("_MainTex", tex);
            AssetDatabase.CreateAsset(mat, MatPathName);
        }
        else
        {
            mat.shader = Shader.Find("GUI/Text Shader");
            mat.SetTexture("_MainTex", tex);
        }

        Font customFont = AssetDatabase.LoadAssetAtPath<Font>(customFontPath);
        customFont.characterInfo = charList.ToArray();
        customFont.material = mat;
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log(customFontPath);
    }

}  
