// using System;
// using System.IO;
// using System.Collections.Generic;
// using System.Text.RegularExpressions;
// using UnityEngine;
// using UnityEditor;
// using GameLogic;
//
// namespace GameEditor
// {
//     public class CustomImportSettings : AssetPostprocessor
//     {
//         const int MAX_TEXTURE_SIZE = 2048;
//
//         public static bool enabled = true;
//
//         private static Regex MAP_TEXTURE = new Regex(@"Map/[\d]*/");
//
//         private static TextureImporterSettings importerSettings = new TextureImporterSettings();
//         /// <summary>
//         /// 图片处理
//         /// </summary>
//         private static Dictionary<string, Action<TextureImporter, string>> handlers = new Dictionary<string, Action<TextureImporter, string>>
//         {
//             //UI
//             {"/Atlas/", SetUITexture},
//             {"/IconSprite/", SetIconSpriteTexture},
//             //{"/ArtFont_en/", SetUITexture},
//             {"/BG/", SetBGTexture},
//             {"/BGS/", SetBGSTexture},
//             {"/DynamicAtlas/", SetBGTexture},
//             {"/AnimRes/", SetFrameTexture},
//             {"/AnimResTP/", SetFrameTextureMulti},
//         };
//
//
//         void OnPreprocessAudio()
//         {
//             AudioImporter audioImporter = assetImporter as AudioImporter;
//             SetAudio(audioImporter);
//         }
//
//         //音频导入后处理
//         public void OnPostprocessAudio(AudioClip clip)
//         {
//         }
//
//
//         void OnPreprocessTexture()
//         {
//             if (!enabled) return;
//             TextureImporter importer = assetImporter as TextureImporter;
//             UpdateTextureSetting(importer, assetPath);
//         }
//
//
//         private static void OnPostprocessAllAssets(string[] importedAssets, string[] deletedAssets, string[] movedAssets, string[] movedFromPath)
//         {
//             foreach (string move in movedAssets)
//             {
//                 //这里重新 import一下
//                 AssetDatabase.ImportAsset(move);
//             }
//         }
//
//         /// <summary>
//         /// 设置UI图片自动图集名称,与图片格式
//         /// </summary>
//         static void SetUITexture(TextureImporter importer, string path)
//         {
//             importer.spritePackingTag = GetAtlasName(importer.assetPath);
//             importer.SetTextureSettingsExt(true, TextureImporterType.Sprite, 1, AppConst.PIXELTOWORLD, false, TextureWrapMode.Clamp, FilterMode.Trilinear, TextureImporterNPOTScale.None);
//             // importer.SetPlatformSettingsExt("Android", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("iPhone", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("Standalone", TextureImporterFormat.RGBA32, MAX_TEXTURE_SIZE, 50, false);
//         }
//
//         /// <summary>
//         /// 设置UI图片自动图集名称,与图片格式
//         /// </summary>
//         static void SetIconSpriteTexture(TextureImporter importer, string path)
//         {
//             importer.spritePackingTag = GetIconAtlasName(importer.assetPath);
//             importer.SetTextureSettingsExt(true, TextureImporterType.Sprite, 1, AppConst.PIXELTOWORLD, false, TextureWrapMode.Clamp, FilterMode.Trilinear, TextureImporterNPOTScale.None);
//             // importer.SetPlatformSettingsExt("Android", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("iPhone", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("Standalone", TextureImporterFormat.RGBA32, MAX_TEXTURE_SIZE, 50, false);
//         }
//
//         /// <summary>
//         /// 设置SpritePacker打包好的图集
//         /// </summary>
//         /// <param name="importer"></param>
//         /// <param name="path"></param>
//         static void SetMultipleSprite(TextureImporter importer, string path)
//         {
//             importer.spritePackingTag = string.Empty;
//             importer.SetTextureSettingsExt(true, TextureImporterType.Sprite, 2, AppConst.PIXELTOWORLD, false, TextureWrapMode.Clamp, FilterMode.Trilinear, TextureImporterNPOTScale.None);
//             //importer.SetPlatformSettingsExt("Android", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             //importer.SetPlatformSettingsExt("iPhone", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             //importer.SetPlatformSettingsExt("Standalone", TextureImporterFormat.DXT5, MAX_TEXTURE_SIZE, 50, false);
//         }
//
//         /// <summary>
//         /// 设置UI图片自动图集名称,与图片格式
//         /// </summary>
//         static void SetBGTexture(TextureImporter importer, string path)
//         {
//             importer.spritePackingTag = string.Empty; //GetAtlasName(importer.assetPath);
//             importer.SetTextureSettingsExt(true, TextureImporterType.Sprite, 1, AppConst.PIXELTOWORLD, false, TextureWrapMode.Clamp, FilterMode.Trilinear, TextureImporterNPOTScale.None);
//             // importer.SetPlatformSettingsExt("Android", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("iPhone", TextureImporterFormat.ASTC_10x10, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("Standalone", TextureImporterFormat.RGBA32, MAX_TEXTURE_SIZE, 50, false);
//         }
//
//         /// <summary>
//         /// 设置UI图片自动图集名称,与图片格式
//         /// </summary>
//         static void SetBGSTexture(TextureImporter importer, string path)
//         {
//             importer.spritePackingTag = string.Empty; //GetAtlasName(importer.assetPath);
//             importer.SetTextureSettingsExt(true, TextureImporterType.Sprite, 1, AppConst.PIXELTOWORLD, false, TextureWrapMode.Repeat, FilterMode.Bilinear, TextureImporterNPOTScale.None);
//             // importer.SetPlatformSettingsExt("Android", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("iPhone", TextureImporterFormat.ASTC_10x10, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("Standalone", TextureImporterFormat.RGBA32, MAX_TEXTURE_SIZE, 50, false);
//         }
//
//         /// <summary>
//         /// 设置Frame图片自动图集名称,与图片格式
//         /// </summary>
//         static void SetFrameTexture(TextureImporter importer, string path)
//         {
//             importer.spritePackingTag = GetAnimResName(importer.assetPath);
//             importer.SetTextureSettingsExt(true, TextureImporterType.Sprite, 1, AppConst.PIXELTOWORLD, false, TextureWrapMode.Clamp, FilterMode.Trilinear, TextureImporterNPOTScale.None);
//             // importer.SetPlatformSettingsExt("Android", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("iPhone", TextureImporterFormat.ASTC_10x10, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("Standalone", TextureImporterFormat.RGBA32, MAX_TEXTURE_SIZE, 50, false);
//         }
//
//         /// <summary>
//         /// 设置FrameMulti图片自动图集名称,与图片格式
//         /// </summary>
//         static void SetFrameTextureMulti(TextureImporter importer, string path)
//         {
//             importer.spritePackingTag = GetAnimResNameMulti(importer.assetPath);
//             importer.SetTextureSettingsExt(true, TextureImporterType.Sprite, 2, AppConst.PIXELTOWORLD, false, TextureWrapMode.Clamp, FilterMode.Trilinear, TextureImporterNPOTScale.None);
//             // importer.SetPlatformSettingsExt("Android", TextureImporterFormat.ETC2_RGBA8Crunched, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("iPhone", TextureImporterFormat.ASTC_10x10, MAX_TEXTURE_SIZE, 50, false);
//             // importer.SetPlatformSettingsExt("Standalone", TextureImporterFormat.RGBA32, MAX_TEXTURE_SIZE, 50, false);
//         }
//
//
//
//         public void SetAudio(AudioImporter audioImporter)
//         {
//
//             //audioImporter.SetAudioSettingExt("Android",AudioClipLoadType.Streaming);
//             //audioImporter.SetAudioSettingExt("iPhone", AudioClipLoadType.Streaming);
//             //audioImporter.SetAudioSettingExt("Standalone", AudioClipLoadType.Streaming);
//         }
//
//
//         public static string GetAtlasName(string assetPath)
//         {
//             int index = assetPath.IndexOf("/Atlas/");
//             string atlasName = assetPath.Substring(index + "/Atlas/".Length);
//             index = atlasName.IndexOf("/");
//             if (index != -1)
//             {
//                 atlasName = atlasName.Substring(0, index);
//             }
//             return atlasName;
//         }
//
//
//         public static string GetIconAtlasName(string assetPath)
//         {
//             int index = assetPath.IndexOf("/IconSprite/");
//             string atlasName = assetPath.Substring(index + "/IconSprite/".Length);
//             index = atlasName.IndexOf("/");
//             if (index != -1)
//             {
//                 atlasName = atlasName.Substring(0, index);
//             }
//             return atlasName;
//         }
//
//         public static string GetAnimResName(string assetPath)
//         {
//             int index = assetPath.IndexOf("/AnimRes/");
//             string atlasName = assetPath.Substring(index + 9);
//             index = atlasName.IndexOf("/");
//             if (index != -1)
//             {
//                 atlasName = atlasName.Substring(0, index);
//             }
//             return atlasName;
//         }
//
//         public static string GetAnimResNameMulti(string assetPath)
//         {
//             int index = assetPath.IndexOf("/AnimResTP/");
//             string atlasName = assetPath.Substring(index + 11);
//             index = atlasName.IndexOf("/");
//             if (index != -1)
//             {
//                 atlasName = atlasName.Substring(0, index);
//             }
//             return atlasName;
//         }
//
//         /// <summary>
//         /// 更新一张图片设置
//         /// </summary>
//         public static void UpdateTextureSetting(TextureImporter importer, string assetPath)
//         {
//             importer.spritePackingTag = string.Empty;
//             foreach (var each in handlers)
//             {
//                 if (importer.assetPath.Contains(each.Key))
//                 {
//                     each.Value(importer, each.Key);
//                     break;
//                 }
//             }
//         }
//     }
//
//
//     public static class ImporterExt
//     {
//         /// <summary>
//         /// 更改音效设置
//         /// </summary>
//         /// <param name="importer"></param>
//         /// <param name="platform"></param>
//         /// <param name="loadType"></param>
//         public static void SetAudioSettingExt(this AudioImporter importer, string platform, AudioClipLoadType loadType)
//         {
//             AudioImporterSampleSettings settings = importer.GetOverrideSampleSettings(platform);
//             settings.loadType = loadType;
//             importer.SetOverrideSampleSettings(platform, settings);
//         }
//
//         /// <summary>
//         /// 设置Texture参数
//         /// </summary>
//         /// <param name="importer"></param>
//         /// <param name="type"></param>
//         /// <param name="spriteMode"></param>
//         /// <param name="spritePixelsPerUnit"></param>
//         /// <param name="mipmapEnabled"></param>
//         /// <param name="wrapMode"></param>
//         /// <param name="filterMode"></param>
//         /// <param name="noptScale"></param>
//         public static void SetTextureSettingsExt(this TextureImporter importer, bool alphaIsTransparency, TextureImporterType type, int spriteMode, float spritePixelsPerUnit, bool mipmapEnabled, TextureWrapMode wrapMode, FilterMode filterMode, TextureImporterNPOTScale noptScale)
//         {
//             TextureImporterSettings importerSettings = new TextureImporterSettings();
//             importer.ReadTextureSettings(importerSettings);
//             importerSettings.npotScale = noptScale;
//             importerSettings.spriteMode = spriteMode;
//             importerSettings.spritePixelsPerUnit = spritePixelsPerUnit;
//             importerSettings.mipmapEnabled = mipmapEnabled;
//             importerSettings.wrapMode = wrapMode;
//             importerSettings.filterMode = filterMode;
//             importerSettings.alphaIsTransparency = alphaIsTransparency;
//             importer.SetTextureSettings(importerSettings);
//         }
//
//         /// <summary>
//         /// 设置平台参数
//         /// </summary>
//         /// <param name="importer"></param>
//         /// <param name="platform"></param>
//         /// <param name="format"></param>
//         /// <param name="maxSize"></param>
//         /// <param name="compressionQuality"></param>
//         /// <param name="allowsAlphaSplitting"></param>
//         /// <param name="overridden"></param>
//         public static void SetPlatformSettingsExt(this TextureImporter importer, string platform, TextureImporterFormat format, int maxSize, int compressionQuality, bool allowsAlphaSplitting)
//         {
//             TextureImporterPlatformSettings settings = new TextureImporterPlatformSettings();
//
//             settings.name = platform;
//             settings.maxTextureSize = maxSize;
//             settings.format = format;
//             settings.compressionQuality = compressionQuality;
//             settings.allowsAlphaSplitting = allowsAlphaSplitting;
//             settings.overridden = true;
//             importer.SetPlatformTextureSettings(settings);
//         }
//     }
// }
//
