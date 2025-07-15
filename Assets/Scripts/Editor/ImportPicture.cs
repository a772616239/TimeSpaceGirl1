// using System.IO;
// using System.Linq;
// using System.Reflection;
// // using Sirenix.Utilities.Editor;
// using UnityEditor;
// // using UnityEditor.AddressableAssets;
// // using UnityEditor.AddressableAssets.Settings;
// using UnityEngine;
//  
// public class ImportPicture : AssetPostprocessor
// {
//     
//     void OnPreprocessTexture()
// {
//     TextureImporter importer = assetImporter as TextureImporter;
//     if (importer != null&&!assetPath.Contains("Spine"))
//     {
//         if (!EditorPrefs.HasKey(assetPath))
//         {
//             EditorPrefs.SetBool(assetPath, true);
//             // importer.textureType = TextureImporterType.Default;
//             // Debug.Log("new:" + importer.assetPath);
//
//             SetPlatformTextureSettings(importer, "iPhone", true,assetPath);
//             SetPlatformTextureSettings(importer, "Android", false,assetPath);
//         }
//         else
//         {
//             if (importer.textureType == TextureImporterType.Sprite)
//             {
//                 // 可以为 Sprite 类型进行其他处理
//             }
//             else if (importer.textureType == TextureImporterType.Default)
//             {
//                 Debug.Log("Tex old:" + importer.assetPath);
//             }
//         }
//     }
// }
//
//     void SetPlatformTextureSettings(TextureImporter importer, string platform, bool isIphone,string path)
//     {
//         TextureImporterPlatformSettings settings = importer.GetPlatformTextureSettings(platform);
//         bool isPowerOfTwo = IsPowerOfTwo(importer);
//         bool divisible4 = IsDivisibleOf4(importer);
//
//         (int width, int height) = GetTextureImporterSize(importer);
//         TextureImporterFormat defaultAlpha;
//         TextureImporterFormat defaultNotAlpha;
//         // Debug.Log("isPowerOfTwo"+isPowerOfTwo+"-divisible4"+divisible4+"width-"+width+"=height-"+height+"--importer.maxTextureSize:"+importer.maxTextureSize+"--platform:"+platform);
//         if ((isPowerOfTwo||divisible4)&&(width>settings.maxTextureSize||height>settings.maxTextureSize))
//         {
//             settings.maxTextureSize *= 2;
//             // Debug.Log("maxTextureSize-"+settings.maxTextureSize);
//         }
//
//         // 如果是 iPhone 平台
//         if (isIphone)
//         {
//             defaultAlpha = isPowerOfTwo ? TextureImporterFormat.PVRTC_RGBA4 : TextureImporterFormat.ASTC_6x6;
//             defaultNotAlpha = isPowerOfTwo ? TextureImporterFormat.PVRTC_RGB4 : TextureImporterFormat.ASTC_6x6;
//         }
//         else // 如果是 Android 平台
//         {
//             // 使用 divisible4 判断来选择压缩格式
//             if (divisible4)
//             {
//                 if (isPowerOfTwo)
//                 {
//                     // if (path.ToLower().Contains("eff"))
//                     // {
//                     //     defaultAlpha = TextureImporterFormat.PVRTC_RGBA4;
//                     //     defaultNotAlpha = TextureImporterFormat.PVRTC_RGB4;
//                     // }
//                     // else
//                     {
//                         defaultAlpha = TextureImporterFormat.ETC2_RGBA8Crunched;
//                         defaultNotAlpha = TextureImporterFormat.ETC_RGB4Crunched;
//                     }
//                 }
//                 else
//                 {
//                     defaultAlpha = TextureImporterFormat.ETC2_RGBA8Crunched;
//                     defaultNotAlpha = TextureImporterFormat.ETC2_RGBA8Crunched;
//                 }
//             }
//             else
//             {
//                 defaultAlpha = TextureImporterFormat.ASTC_6x6;
//                 defaultNotAlpha = TextureImporterFormat.ASTC_6x6;
//             }
//         }
//
//         var targetFormat = importer.DoesSourceTextureHaveAlpha() ? defaultAlpha : defaultNotAlpha;
//         if (settings.format!=targetFormat||!settings.overridden)
//         {
//             settings.overridden = true;
//             settings.format = targetFormat;
//             // 通用设置
//             importer.isReadable = false;
//             importer.mipmapEnabled = false;
//             // importer.wrapMode = TextureWrapMode.Clamp;
//             if (!isIphone) // 针对 Android 平台的额外设置
//             {
//                 settings.androidETC2FallbackOverride = AndroidETC2FallbackOverride.Quality32Bit;
//             }
//
//             importer.SetPlatformTextureSettings(settings);
//             AssetDatabase.ImportAsset(importer.assetPath, ImportAssetOptions.ForceUpdate);
//         }
//     }
//
//     static void OnPostprocessAllAssets(           
//         string[] importedAssets,
//         string[] deletedAssets,
//         string[] movedAssets,
//         string[] movedFromAssetPaths)
//     {
//         foreach (string path in deletedAssets)
//         {
//             // Debug.Log("现在变更的文件的路径是" + path);
//             EditorPrefs.DeleteKey(path);
//         }
//     
//     }
//     private static string GetPrefix(string input)
//     {
//         int count = input.Count(c => c == '_');
//         if (count>=2)
//         {
//             // 查找字符串中的第一个下划线位置
//             int underscoreIndex = input.IndexOf('_');
//
//             // 如果有下划线，返回第一个下划线前的部分
//             if (underscoreIndex >= 0)
//             {
//                 // 返回从开头到第一个下划线（包含下划线）
//                 return input.Substring(0, input.IndexOf('_', underscoreIndex + 1));
//             }
//             else
//             {
//                 // 如果没有下划线，返回整个字符串
//                 return input;
//             }
//         }
//         else
//         {
//             var str= input.Split('_');
//             return str[0];
//         }
//     }
//     // public static void AddDynamicLabel(string assetPath,string label)
//     // {
//     //     // 获取默认的 AddressableAssetSettings
//     //     AddressableAssetSettings settings = AddressableAssetSettingsDefaultObject.Settings;
//     //
//     //     // 获取资源的路径
//     //     // string assetPath = "Assets/Bundles/FUI/_SpecialsPack_atlas0.png";
//     //     // string label = "TqsPack";
//     //     Debug.Log("assetPath:"+assetPath+"---label:"+label);
//     //     // 查找该资源的条目
//     //     AddressableAssetEntry entry = settings.FindAssetEntry(AssetDatabase.AssetPathToGUID(assetPath));
//     //     // 检查标签是否已经存在
//     //     // 如果标签不存在，则添加
//     //     settings.AddLabel(label);
//     //     if (entry != null)
//     //     {
//     //         // 添加标签
//     //         entry.labels.Add(label);
//     //
//     //         // 保存设置
//     //         EditorUtility.SetDirty(settings);
//     //         AssetDatabase.SaveAssets();
//     //         Debug.Log("Label added: " + label);
//     //     }
//     //     else
//     //     {
//     //         CreateAssetEntry(assetPath, settings);
//     //         AddDynamicLabel(assetPath, label);
//     //         //Debug.LogError("Asset entry not found!");
//     //     }
//     // }
//     // private static void CreateAssetEntry(string assetPath, AddressableAssetSettings settings)
//     // {
//     //     // 获取资源的 GUID
//     //     string guid = AssetDatabase.AssetPathToGUID(assetPath);
//     //
//     //     // 创建新的条目
//     //     AddressableAssetEntry newEntry = settings.CreateOrMoveEntry(guid, settings.DefaultGroup);
//     //     newEntry.SetAddress(Path.GetFileNameWithoutExtension(assetPath),false);
//     //     // 保存设置
//     //     EditorUtility.SetDirty(settings);
//     //     AssetDatabase.SaveAssets();
//     //
//     //     // Debug.Log("New entry created and label added: " + label);
//     // }
//
//     // 当资源被删除时调用
//     static void OnDeleteAsset(string assetPath)
//     {
//         Debug.Log($"资源已删除: {assetPath}");
//
//         // 这里可以添加删除后的相关逻辑
//         // 比如从数据库中移除与该资源相关的记录，清理缓存等
//     }
//     
//     bool IsDivisibleOf4(TextureImporter importer)
//     {
//         (int width, int height) = GetTextureImporterSize(importer);
//         return (width % 4 == 0 && height % 4 == 0);
//     }
//     
//     bool IsPowerOfTwo(TextureImporter importer)
//     {
//         
//         (int width, int height) = GetTextureImporterSize(importer);
//         return (width == height) && (width > 0) && ((width & (width - 1)) == 0);
//     }
//  
//     (int, int) GetTextureImporterSize(TextureImporter importer)
//     {
//         if (importer != null)
//         {
//             object[] args = new object[2];
//             MethodInfo mi = typeof(TextureImporter).GetMethod("GetWidthAndHeight", BindingFlags.NonPublic | BindingFlags.Instance);
//             mi.Invoke(importer, args);
//             return ((int)args[0], (int)args[1]);
//         }
//         return (0, 0);
//     }
// }