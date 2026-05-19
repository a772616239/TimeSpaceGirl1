using System.IO;
using System.Text.RegularExpressions;
using UnityEditor.Android;
using UnityEngine;

public class EnableAABDensitySplit : IPostGenerateGradleAndroidProject
{
    // 指定回调顺序，可以在其他处理之后执行
    public int callbackOrder { get { return 100; } }

    public void OnPostGenerateGradleAndroidProject(string path)
    {
        // Unity 2019.3+ 导出工程后，path 指向的是 unityLibrary 目录。
        // Launcher 模块的 build.gradle 在其同级的 launcher 目录下。
        string launcherBuildGradle = Path.Combine(path, "../launcher/build.gradle");
        
        if (File.Exists(launcherBuildGradle))
        {
            string content = File.ReadAllText(launcherBuildGradle);
            
            // 使用正则匹配默认生成的 density { enableSplit = false }
            Regex regex = new Regex(@"density\s*\{\s*enableSplit\s*=\s*false\s*\}");
            if (regex.IsMatch(content))
            {
                content = regex.Replace(content, "density {\n            enableSplit = true\n        }");
                File.WriteAllText(launcherBuildGradle, content);
                Debug.Log("【打包工具】成功在 launcher/build.gradle 中启用了 App Bundle 的图片密度拆分 (Density Split)。");
            }
            else
            {
                Debug.Log("【打包工具】在 launcher/build.gradle 中未找到 `density { enableSplit = false }` 配置。可能已开启或不需要修改。");
            }
        }
        else
        {
            Debug.LogWarning("【打包工具】未找到 launcher/build.gradle，无法启用图片密度拆分。");
        }
    }
}
