using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;
using System.Text;

namespace LJ_OptTools
{
    public class TextureSizeOptUtilities
    {
        public struct TextureSizeData
        {
            public int width;
            public int height;
            public SpriteMetaData[] spDatas;
        }

        public static bool NeedExtend(Texture2D tex, TextureImporter ti)
        {
            if (tex == null ||//用packingTag打图集 和 本身就是2的整数幂的 不需要处理
                (ti.textureType == TextureImporterType.Sprite && !string.IsNullOrEmpty(ti.spritePackingTag)))
            if (ti != null && (tex == null ||//用packingTag打图集 和 本身就是2的整数幂的 不需要处理
                               (ti.textureType == TextureImporterType.Sprite && !string.IsNullOrEmpty(ti.spritePackingTag)))
                ) return false;
            var oWidth = tex.width;
            var oHeight = tex.height;
            if (oWidth <= 0 || oHeight <= 0) return false;

            var tarW = (oWidth / 4 + ((oWidth % 4 > 0) ? 1 : 0)) * 4;
            var tarH = (oHeight / 4 + ((oHeight % 4 > 0) ? 1 : 0)) * 4;

            return oWidth != tarW || oHeight != tarH;
        }

        public static TextureSizeData CalcTextureSize(Texture tex, TextureImporter ti)
        {
            var ret = new TextureSizeData();

            var oWidth = tex.width;
            var oHeight = tex.height;
            #region Get Sprites Data          
            if (ti.spriteImportMode == SpriteImportMode.Multiple && ti.spritesheet.Length > 0) //精灵表单
            {
                var spData = ti.spritesheet;
                var length = spData.Length;
                ret.spDatas = new SpriteMetaData[length];
                for (var i = 0; i < length; i++)
                {
                    ret.spDatas[i] = spData[i];
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

        public static bool ExtendTexture(string path)
        {
            var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            var ti = AssetImporter.GetAtPath(path) as TextureImporter;
            if (!NeedExtend(tex, ti)) return false;  //不是4的整数倍的才进行处理

            var sizeData = CalcTextureSize(tex, ti);

            var oWidth = tex.width;
            var oHeight = tex.height;

            var texName = tex.name;
            var texFormat = ti.DoesSourceTextureHaveAlpha() ? TextureFormat.RGBA32 : TextureFormat.RGB24;

            Color[] texPixels = null;

            if (tex.isReadable)
            {
                texPixels = tex.GetPixels(0, 0, oWidth, oHeight);
            }
            else
            {
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
                texPixels = tmpTex.GetPixels(0, 0, oWidth, oHeight);
                Object.DestroyImmediate(tmpTex);
            }

            var tarW = sizeData.width;
            var tarH = sizeData.height;

            var newTex = new Texture2D(tarW, tarH, texFormat, false, true);
            var defaultPixels = new Color32[tarW * tarH];
            for (int j = 0, jmax = tarH * tarW; j < jmax; ++j)
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

            ti.spriteImportMode = SpriteImportMode.Multiple;
            if (sizeData.spDatas == null || sizeData.spDatas.Length < 1)
            {
                var spData = new SpriteMetaData[1];
                spData[0].name = texName;
                spData[0].rect = new Rect(0f, 0f, oWidth, oHeight);
                spData[0].border = Vector4.zero;
                spData[0].alignment = 0;
                ti.spritesheet = spData;
            }
            else
            {
                var newSPSheet = new SpriteMetaData[sizeData.spDatas.Length];
                for (int i = 0; i < sizeData.spDatas.Length; i++)
                {
                    newSPSheet[i] = sizeData.spDatas[i];
                }
                ti.spritesheet = newSPSheet;
            }
            AssetDatabase.WriteImportSettingsIfDirty(path);
            AssetDatabase.ImportAsset(path);
            return true;
        }

        public static void SettingPlantformTex(TextureImporter ti, TextureImporterPlatformSettings setting, bool useCrunched, bool pot)
        {

            if (!setting.overridden)
            {
                setting.overridden = true;
            }
            //带透明通道   压缩格式测试完更改
            if (ti.DoesSourceTextureHaveAlpha())
            {
                if (useCrunched)
                {
                    if (setting.format != TextureImporterFormat.ETC2_RGBA8Crunched)
                        setting.format = TextureImporterFormat.ETC2_RGBA8Crunched;
                }
                else
                {
                    if (setting.format != TextureImporterFormat.ASTC_5x5)
                        setting.format = TextureImporterFormat.ASTC_5x5;
                }

            }
            else  //不带透明通道
            {
                if (useCrunched)
                {
                    if (pot && setting.format != TextureImporterFormat.ETC_RGB4Crunched)
                        setting.format = TextureImporterFormat.ETC_RGB4Crunched;
                    else
                        setting.format = TextureImporterFormat.ETC2_RGBA8Crunched;
                }
                else
                {
                    if (setting.format != TextureImporterFormat.ASTC_5x5)
                        setting.format = TextureImporterFormat.ASTC_5x5;
                }
            }

            if (setting.compressionQuality != 50)
            {
                setting.compressionQuality = 50;
            }

        }

        public static void SetTextureFormat(string path, bool useCrunched)
        {
            if (string.IsNullOrEmpty(path)) return;
            var ti = AssetImporter.GetAtPath(path) as TextureImporter;
            if (ti == null)
            {
                Debug.LogWarning("Can load TextureImporter:" + path);
                return;
            }
            if (ti.textureShape != TextureImporterShape.Texture2D)
            {
                return;
            }

            if (ti.textureType == TextureImporterType.Sprite)
            {
                TextureImporterSettings tis = new TextureImporterSettings();
                ti.ReadTextureSettings(tis);
                if (tis.spriteMeshType != SpriteMeshType.FullRect)
                {
                    tis.spriteMeshType = SpriteMeshType.FullRect;
                    ti.SetTextureSettings(tis);
                    AssetDatabase.WriteImportSettingsIfDirty(path);
                }
            }

            var pAndSetting = ti.GetPlatformTextureSettings("Android");
            var piPSetting = ti.GetPlatformTextureSettings("iPhone");
            var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            bool pot = Mathf.IsPowerOfTwo(tex.width) && Mathf.IsPowerOfTwo(tex.height);
            SettingPlantformTex(ti, pAndSetting, useCrunched, pot);
            ti.SetPlatformTextureSettings(pAndSetting);
            SettingPlantformTex(ti, piPSetting, useCrunched, pot);
            ti.SetPlatformTextureSettings(piPSetting);

            AssetDatabase.WriteImportSettingsIfDirty(path);
        }

    }


    public class TextureSizeOptTool
    {
        [MenuItem("Tools/图片优化/优化选中文件夹中的图片-ASTC", priority = 1)]
        public static void OnMenuItem_ASTC()
        {
            OptUITexSelectTex(false);
        }

        [MenuItem("Tools/图片优化/优化选中文件夹中的图片-Crunched", priority = 2)]
        public static void OnMenuItem_Crunched()
        {
            OptUITexSelectTex(true);
        }

        public static void OptUITexSelectTex(bool useCrunched)
        {

            var guids = Selection.assetGUIDs;
            var filePaths = new List<string>();
            foreach (var id in guids)
            {
                var path = AssetDatabase.GUIDToAssetPath(id);
                //可判断文件是否存在
                if (File.Exists(path))
                {
                    if (!filePaths.Contains(path))
                        filePaths.Add(path);

                }  //可判断文件路径是否存在
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

            for (int i = 0; i < filePaths.Count; i++)
            {
                string path = filePaths[i];
                TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;

                if (importer != null)
                {
                    Debug.Log($"Texture Importer found at path: {path}");
                    // Debug.Log($"Texture Type: {importer.textureType}");
                    // Debug.Log($"Max Texture Size: {importer.maxTextureSize}");
                    // Debug.Log($"Texture Format: {importer.textureCompression}");
                    // Debug.Log($"Alpha Source: {importer.alphaSource}");
                    TextureImporterPlatformSettings settings = importer.GetPlatformTextureSettings("Android");
                    if (settings.format==TextureImporterFormat.ETC_RGB4Crunched||settings.format==TextureImporterFormat.ETC2_RGBA8Crunched)
                    {
                        Debug.Log("已经是crunched，忽略："+path);
                        return;
                        continue;
                    }
                    // 你可以在这里获取更多设置或进行修改
                }
                else
                {
                    Debug.LogWarning("TextureImporter not found or path is incorrect.");
                }
                
                EditorUtility.DisplayProgressBar(
                    string.Format("Opt UI Texture({0}/{1})", i, filePaths.Count)
                    , path
                    , i * 1f / filePaths.Count
                    );
                TextureSizeOptUtilities.ExtendTexture(path);
                TextureSizeOptUtilities.SetTextureFormat(path, useCrunched);
            }
            AssetDatabase.Refresh();
            AssetDatabase.SaveAssets();

            EditorUtility.ClearProgressBar();
        }

        [MenuItem("Tools/图片优化/检查ManagedResources中所有图片格式", priority = 0)]
        public static void OnMenuItem_Check()
        {
            var guid = AssetDatabase.FindAssets("t:Texture", new string[] { "Assets/ManagedResources" });
            List<string> floders = new List<string>();
            int errorTexCount = 0;
            
            for (int i = 0; i < guid.Length; i++)
            {
                string id = guid[i];
                var path = AssetDatabase.GUIDToAssetPath(id);
                EditorUtility.DisplayProgressBar(
                   string.Format("Check Texture({0}/{1})", i, guid.Length)
                   , path
                   , i * 1f / guid.Length
                   );
                var ti = AssetImporter.GetAtPath(path) as TextureImporter;
                if (ti == null)
                {
                    //Debug.LogError("No TextureImporter:" + path);
                    continue;
                }
                if (
                    path.StartsWith("Assets/ManagedResources/Atlas")
                    ) continue;

               
                var floder = Path.GetDirectoryName(path);

                var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);

                var pAndSetting = ti.GetPlatformTextureSettings("Android");
                var piPSetting = ti.GetPlatformTextureSettings("iPhone");

                if (!pAndSetting.overridden || !piPSetting.overridden)
                {
                    if (!floders.Contains(floder)) floders.Add(floder);
                    ++errorTexCount;
                    continue;
                }

                if (pAndSetting.format < TextureImporterFormat.ASTC_4x4 || piPSetting.format < TextureImporterFormat.ASTC_4x4)
                {
                    if (!floders.Contains(floder)) floders.Add(floder);
                    ++errorTexCount;
                    continue;
                }

                if (tex.width % 4 != 0 || tex.height % 4 != 0)
                {
                    if (!floders.Contains(floder)) floders.Add(floder);
                    ++errorTexCount;
                    continue;
                }
            }
            if (floders.Count > 0)
            {
                Debug.Log("Error Tex Count:" + errorTexCount);
                StringBuilder sb = new StringBuilder();
                foreach (var f in floders)
                {
                    sb.AppendLine(f);
                }
                Debug.Log(sb.ToString());
            }
            EditorUtility.ClearProgressBar();
        }


        [MenuItem("Tools/图片优化/检查Material引用的图片", priority = 0)]
        public static void OnMenuItem_CheckMat()
        {
            var guid = AssetDatabase.FindAssets("t:Material");
            StringBuilder info = new StringBuilder();
            for (int i = 0; i < guid.Length; i++)
            {
                var path = AssetDatabase.GUIDToAssetPath(guid[i]);
                EditorUtility.DisplayProgressBar(
                  string.Format("检查Material引用的图片({0}/{1})", i, guid.Length)
                  , path
                  , i * 1f / guid.Length
                  );

                var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
                var shader = mat.shader;
                int pCount = ShaderUtil.GetPropertyCount(shader);
                for (int j = 0; j < pCount; j++)
                {
                    if (ShaderUtil.GetPropertyType(shader, j) != ShaderUtil.ShaderPropertyType.TexEnv) continue;
                    var pName = ShaderUtil.GetPropertyName(shader, j);
                    var tex = mat.GetTexture(pName);
                    var texPath = AssetDatabase.GetAssetPath(tex);
                    var ti = AssetImporter.GetAtPath(texPath) as TextureImporter;
                    if (ti == null) continue;
                    if( ti.textureType == TextureImporterType.Sprite)
                    {
                        info.AppendFormat("{0} : {1} ->> {2}\r\n",path,pName,texPath);
                    }
                }

            }
            if( info.Length > 0)
            {
                Debug.Log(info.ToString());
            }

            EditorUtility.ClearProgressBar();
        }
    }



}
