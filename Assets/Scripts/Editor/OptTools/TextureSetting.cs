using System.IO;
using UnityEditor;
using UnityEngine;

namespace LJ_OptTools
{
    public class TextureSetting
    {
        static void SettingTex( string texPath )
        {
            if (string.IsNullOrEmpty(texPath)) return;


            var ti = AssetImporter.GetAtPath(texPath) as TextureImporter;
            if (ti == null)
            {
                Debug.LogWarning("Can load TextureImporter:" + texPath);
                return;
            }
            if (ti.textureShape != TextureImporterShape.Texture2D)
            {
                return;
            }

            var pAndSetting = ti.GetPlatformTextureSettings("Android");
            var piPSetting = ti.GetPlatformTextureSettings("iPhone");
            bool needReimport = false;

            if (SettingPlantformTex(ti, pAndSetting))
            {
                ti.SetPlatformTextureSettings(pAndSetting);
                needReimport = true;
            }
            if (SettingPlantformTex(ti, piPSetting))
            {
                ti.SetPlatformTextureSettings(piPSetting);
                needReimport = true;
            }

            if (needReimport)
            {
                ti.SaveAndReimport();
            }

        }

        static bool SettingPlantformTex( TextureImporter ti, TextureImporterPlatformSettings setting )
        {
            bool needReimport = false;

            if (!setting.overridden)
            {
                setting.overridden = true;
                needReimport = true;
            }
            //带透明通道
            if (ti.DoesSourceTextureHaveAlpha()
                || ti.textureShape == TextureImporterShape.TextureCube
            )
            {
                if (setting.format != TextureImporterFormat.ASTC_5x5)
                {
                    needReimport = true;
                    setting.format = TextureImporterFormat.ASTC_5x5;
                }

                //} else  //不带透明通道
                //{
                //    if (setting.format != TextureImporterFormat.ETC2_RGB4)
                //    {
                //        needReimport = true;
                //        setting.format = TextureImporterFormat.ETC2_RGB4;
                //    }
            }

            if (setting.compressionQuality < 100)
            {
                setting.compressionQuality = 100;
                needReimport = true;
            }

            return needReimport;
        }


        [MenuItem("Assets/优化工具/Spine贴图优化工具")]
        static void OnMenuItem_SceneTextureTest()
        {
            var res = AssetDatabase.FindAssets("t:Texture", new string[] { "Assets/ManagedResources/Effects/Spine" });
            if (res == null || res.Length < 1) return;

            for (int i = 0, imax = res.Length ; i < res.Length ; i++)
            {
                var path = AssetDatabase.GUIDToAssetPath(res[i]);
                EditorUtility.DisplayProgressBar(string.Format("{0}/{1}", i, imax), path, i * 1f / imax);
                SettingTex(path);
            }
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorUtility.ClearProgressBar();
        }


    }

}