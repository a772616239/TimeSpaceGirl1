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
            PlayerSettings.Android.keystoreName = "user.keystore";
            PlayerSettings.Android.keystorePass = "Wang177752";
            PlayerSettings.Android.keyaliasName = "name";
            PlayerSettings.Android.keyaliasPass = "Wang177752";
            Debug.Log("【打包工具】已自动设置 Android 签名和密码。");
        }
    }
}
