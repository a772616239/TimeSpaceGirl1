using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

public class AutoSignKeystore : IPreprocessBuildWithReport
{
    public int callbackOrder => 0;

    public void OnPreprocessBuild(BuildReport report)
    {
        if (report.summary.platformGroup == BuildTargetGroup.Android)
        {
            PlayerSettings.Android.useCustomKeystore = true;
            PlayerSettings.Android.keystoreName = "beauty.keystore";
            PlayerSettings.Android.keystorePass = "Wxf950329";
            PlayerSettings.Android.keyaliasName = "xing";
            PlayerSettings.Android.keyaliasPass = "Wxf950329";
            Debug.Log("【打包工具】已自动设置 Android 签名和密码。");
        }
    }
}
