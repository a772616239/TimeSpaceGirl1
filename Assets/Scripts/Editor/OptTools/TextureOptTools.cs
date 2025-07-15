using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;
namespace LJ_OptTools
{
    public class TextureOptUtilities
    {

        struct TextureSizeData
        {
            public int width;
            public int height;
            public Rect[] rects;
            public Vector4[] boarder;
            public string[] spName;
        }


        public static bool NeedExtend( Texture2D tex, TextureImporter ti )
        {
            if (tex == null ||
                (ti.textureType == TextureImporterType.Sprite && !string.IsNullOrEmpty(ti.spritePackingTag))
                ) return false;
            var oWidth = tex.width;
            var oHeight = tex.height;
            if (oWidth <= 0 || oHeight <= 0) return false;

            var tarW = (oWidth / 4 + ((oWidth % 4 > 0) ? 1 : 0)) * 4;
            var tarH = (oHeight / 4 + ((oHeight % 4 > 0) ? 1 : 0)) * 4;

            return oWidth != tarW || oHeight != tarH;
        }

        static TextureSizeData CalcTextureSize( Texture tex, TextureImporter ti )
        {
            var ret = new TextureSizeData();

            var oWidth = tex.width;
            var oHeight = tex.height;
            #region Get Sprites Data
            ret.rects = null;
            ret.spName = null;
            ret.boarder = null;
            if (ti.spriteImportMode == SpriteImportMode.Multiple && ti.spritesheet.Length > 0)
            {
                var spData = ti.spritesheet;
                var length = spData.Length;
                ret.rects = new Rect[length];
                ret.boarder = new Vector4[length];
                ret.spName = new string[length];
                for (var i = 0 ; i < length ; i++)
                {
                    ret.rects[i] = spData[i].rect;
                    ret.spName[i] = spData[i].name;
                    ret.boarder[i] = spData[i].border;
                }
            }

            #endregion

            //图片大小调整为4的整数倍
            var tarW = (oWidth / 4 + ((oWidth % 4 > 0) ? 1 : 0)) * 4;
            var tarH = (oHeight / 4 + ((oHeight % 4 > 0) ? 1 : 0)) * 4;

            ret.width = tarW;
            ret.height = tarH;
            return ret;
        }


        public static void ExtendTexture( string path )
        {
            var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            var ti = AssetImporter.GetAtPath(path) as TextureImporter;
            if (!NeedExtend(tex, ti)) return;


            var sizeData = CalcTextureSize(tex, ti);

            var oWidth = tex.width;
            var oHeight = tex.height;

            var texName = tex.name;
            var texFormat = ti.DoesSourceTextureHaveAlpha() ? TextureFormat.RGBA32 : TextureFormat.RGB24;

            Texture2D tmpTex = null;
            var tmpRT = RenderTexture.GetTemporary(oWidth, oHeight, 0, RenderTextureFormat.ARGB32);
            Graphics.Blit(tex, tmpRT);
            Resources.UnloadAsset(tex);
            RenderTexture.active = tmpRT;
            tmpTex = new Texture2D(oWidth, oHeight, TextureFormat.ARGB32, false);
            tmpTex.ReadPixels(new Rect(0, 0, oWidth, oHeight), 0, 0);
            tmpTex.Apply(false, false);
            RenderTexture.active = null;
            RenderTexture.ReleaseTemporary(tmpRT);
            var texPixels = tmpTex.GetPixels(0, 0, oWidth, oHeight);
            Object.DestroyImmediate(tmpTex);

            var tarW = sizeData.width;
            var tarH = sizeData.height;

            var newTex = new Texture2D(tarW, tarH, texFormat, false, true);
            var defaultPixels = new Color32[tarW * tarH];
            for (int j = 0, jmax = tarH * tarW ; j < jmax ; ++j)
            {
                defaultPixels[j] = Color.clear;
            }
            newTex.SetPixels32(defaultPixels);
            newTex.Apply(true, false);


            newTex.SetPixels(0, 0, oWidth, oHeight, texPixels);
            newTex.Apply(true, false);


            var ext = Path.GetExtension(path).ToLower();

            switch (ext)
            {
                case ".png":
                    File.WriteAllBytes(path, newTex.EncodeToPNG());
                    break;
                case ".jpg":
                    File.WriteAllBytes(path, newTex.EncodeToJPG());
                    break;
                case ".tga":
                    File.WriteAllBytes(path, newTex.EncodeToTGA());
                    break;
            }
            Object.DestroyImmediate(newTex);
            AssetDatabase.ImportAsset(path);

            ti = AssetImporter.GetAtPath(path) as TextureImporter;

            if (sizeData.rects == null || ti.spriteImportMode != SpriteImportMode.Multiple)
            {
                ti.spriteImportMode = SpriteImportMode.Multiple;
                var spData = new SpriteMetaData[1];
                spData[0].name = texName;
                spData[0].rect = new Rect(0f, 0f, oWidth, oHeight);
                spData[0].border = Vector4.zero;
                spData[0].alignment = 0;
                ti.spritesheet = spData;
                ti.SaveAndReimport();
            }
        }


        public static void RemoveBigTexPackageTag( string path )
        {
            var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            if (tex.width < 512 && tex.height < 512) return;

            var ti = AssetImporter.GetAtPath(path) as TextureImporter;
            if (ti.textureType == TextureImporterType.Sprite && !string.IsNullOrEmpty(ti.spritePackingTag))
            {
                ti.spritePackingTag = "";
                ti.SaveAndReimport();
            }

        }

    }


    public class TextureOptTool
    {
        [MenuItem("Assets/优化工具/UI贴图优化工具")]
        public static void OnMenuItem_UITexOpt()
        {
            var guids = Selection.assetGUIDs;
            var filePaths = new List<string>();
            foreach (var id in guids)
            {
                var path = AssetDatabase.GUIDToAssetPath(id);
                if (File.Exists(path))
                {
                    if (!filePaths.Contains(path))
                        filePaths.Add(path);
                } else if (Directory.Exists(path))
                {
                    var subFileGuids = AssetDatabase.FindAssets("t:Texture", new string[] { path });
                    if (subFileGuids != null && subFileGuids.Length > 0)
                    {
                        foreach (var subId in subFileGuids)
                        {
                            var subPath = AssetDatabase.GUIDToAssetPath(subId);
                            if (!filePaths.Contains(subPath))
                                filePaths.Add(subPath);
                        }
                    }
                }
            }

            if (filePaths.Count < 1) return;
            // GameEditor.CustomImportSettings.enabled = false;
            for (int i = 0 ; i < filePaths.Count ; i++)
            {
                string path = filePaths[i];
                EditorUtility.DisplayProgressBar(string.Format("Opt UI Texture({0}/{1})", i, filePaths.Count), path, i * 1f / filePaths.Count);
                TextureOptUtilities.RemoveBigTexPackageTag(path);
                TextureOptUtilities.ExtendTexture(path);
            }
            AssetDatabase.Refresh();
            AssetDatabase.SaveAssets();
            // GameEditor.CustomImportSettings.enabled = false;
            EditorUtility.ClearProgressBar();
        }


        [MenuItem("Assets/优化工具/UI特效贴图快速压缩")]
        public static void OnMenuItem_UITexOpt2()
        {
            var guids = Selection.assetGUIDs;
            var filePaths = new List<string>();
            foreach (var id in guids)
            {
                var path = AssetDatabase.GUIDToAssetPath(id);
                if (File.Exists(path))
                {
                    if (!filePaths.Contains(path))
                        filePaths.Add(path);
                }
                else if (Directory.Exists(path))
                {
                    var subFileGuids = AssetDatabase.FindAssets("t:Texture", new string[] { path });
                    if (subFileGuids != null && subFileGuids.Length > 0)
                    {
                        foreach (var subId in subFileGuids)
                        {
                            var subPath = AssetDatabase.GUIDToAssetPath(subId);
                            if (!filePaths.Contains(subPath))
                                filePaths.Add(subPath);
                        }
                    }
                }
            }

            if (filePaths.Count < 1) return;
            // GameEditor.CustomImportSettings.enabled = false;
            for (int i = 0; i < filePaths.Count; i++)
            {
                string path = filePaths[i];
                EditorUtility.DisplayProgressBar(string.Format("Opt UI Texture({0}/{1})", i, filePaths.Count), path, i * 1f / filePaths.Count);
                
                var ti = AssetImporter.GetAtPath(path) as TextureImporter;
                bool isUpdate = false;

                if (ti == null)
                    continue;
                //带透明通道
                if (ti.DoesSourceTextureHaveAlpha())
                {
                    var pAndSetting = ti.GetPlatformTextureSettings("Android");
                    var piPSetting = ti.GetPlatformTextureSettings("iPhone");

                    if (!pAndSetting.overridden || pAndSetting.format != TextureImporterFormat.ETC2_RGBA8Crunched)
                    {
                        pAndSetting.overridden = true;
                        pAndSetting.format = TextureImporterFormat.ETC2_RGBA8Crunched;
                        pAndSetting.compressionQuality = 50;
                        pAndSetting.maxTextureSize = pAndSetting.maxTextureSize > 2048 ? 2048 : pAndSetting.maxTextureSize;
                        ti.SetPlatformTextureSettings(pAndSetting);
                        isUpdate = true;
                    }
                    if (!piPSetting.overridden || piPSetting.format != TextureImporterFormat.ETC2_RGBA8Crunched)
                    {
                        piPSetting.overridden = true;
                        piPSetting.format = TextureImporterFormat.ETC2_RGBA8Crunched;
                        piPSetting.compressionQuality = 50;
                        pAndSetting.maxTextureSize = pAndSetting.maxTextureSize > 2048 ? 2048 : pAndSetting.maxTextureSize;
                        ti.SetPlatformTextureSettings(piPSetting);
                        isUpdate = true;
                    }
                }
                else //不带透明通道
                {
                    var pAndSetting = ti.GetPlatformTextureSettings("Android");
                    var piPSetting = ti.GetPlatformTextureSettings("iPhone");
                    
                    if (!pAndSetting.overridden || pAndSetting.format != TextureImporterFormat.ETC_RGB4Crunched)
                    {
                        pAndSetting.overridden = true;
                        pAndSetting.format = TextureImporterFormat.ETC_RGB4Crunched;
                        pAndSetting.compressionQuality = 50;
                        pAndSetting.maxTextureSize = pAndSetting.maxTextureSize > 2048 ? 2048 : pAndSetting.maxTextureSize;
                        ti.SetPlatformTextureSettings(pAndSetting);
                        isUpdate = true;
                    }
                    if (!piPSetting.overridden || piPSetting.format != TextureImporterFormat.ETC_RGB4Crunched)
                    {
                        piPSetting.overridden = true;
                        piPSetting.format = TextureImporterFormat.ETC_RGB4Crunched;
                        piPSetting.compressionQuality = 50;
                        pAndSetting.maxTextureSize = pAndSetting.maxTextureSize > 2048 ? 2048 : pAndSetting.maxTextureSize;
                        ti.SetPlatformTextureSettings(piPSetting);
                        isUpdate = true;
                    }
                }
                if (isUpdate)
                    ti.SaveAndReimport();
            }
            AssetDatabase.Refresh();
            AssetDatabase.SaveAssets();
            // GameEditor.CustomImportSettings.enabled = false;
            EditorUtility.ClearProgressBar();
        }
    }

}
