using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using System.Text;



[CustomEditor(typeof(GameLogic.GameSettings),true)]
public class GameSettingInspector : Editor {

    SerializedProperty mLoglevel;
    SerializedProperty mServerInfos;
    SerializedProperty mIsDebug;
    SerializedProperty mIsUpdate;
	SerializedProperty mIsGuide;
    SerializedProperty mIsOpenGM;
    SerializedProperty mIsSDK;
    SerializedProperty mIsSDKLogin;
    SerializedProperty mIsBundleMode;
    SerializedProperty mluaBundleMode;
    SerializedProperty mDownload_Resouces_Url;
    SerializedProperty mServerIndex;
    SerializedProperty m_SettingInfo;
    SerializedProperty mIsOpenTLog;
    SerializedProperty mIsOpenBLog;
    SerializedProperty mOriginLan;


    void OnEnable()
    {
        m_SettingInfo = serializedObject.FindProperty("settingInfo");
        if (m_SettingInfo != null)
        {
            mLoglevel = m_SettingInfo.FindPropertyRelative("logLevel");
            mServerInfos = m_SettingInfo.FindPropertyRelative("serverInfos");
            mIsDebug = m_SettingInfo.FindPropertyRelative("isDebug");
            mIsBundleMode = m_SettingInfo.FindPropertyRelative("bundleMode");
            mIsUpdate = m_SettingInfo.FindPropertyRelative("isUpdate");
			mIsGuide = m_SettingInfo.FindPropertyRelative("isGuide");
            mIsOpenGM = m_SettingInfo.FindPropertyRelative("isOpenGM");
            mIsSDK = m_SettingInfo.FindPropertyRelative("isSDK");
            mIsSDKLogin = m_SettingInfo.FindPropertyRelative("isSDKLogin");
            mluaBundleMode = m_SettingInfo.FindPropertyRelative("luaBundleMode");
            //mDownload_Resouces_Url = m_SettingInfo.FindPropertyRelative("download_Resouces_Url");
            //mServerIndex = m_SettingInfo.FindPropertyRelative("currentServerIndex");
            mIsOpenTLog = m_SettingInfo.FindPropertyRelative("isOpenTLog");
            mIsOpenBLog = m_SettingInfo.FindPropertyRelative("isOpenBLog");
            mOriginLan = m_SettingInfo.FindPropertyRelative("originLan");
        }
    }


    public override void OnInspectorGUI()
    {
        EditorGUI.BeginChangeCheck();
        GUILayout.BeginVertical();
        if (m_SettingInfo != null)
        {
            GameCore.LogLevel logLevel = (GameCore.LogLevel)mLoglevel.enumValueIndex;
            mLoglevel.enumValueIndex = System.Convert.ToInt32(EditorGUILayout.EnumPopup("日志等级:", logLevel));
            mIsDebug.boolValue = EditorGUILayout.Toggle("是否开启调试模式:", mIsDebug.boolValue);
            mIsUpdate.boolValue = EditorGUILayout.Toggle("是否开启热更新:", mIsUpdate.boolValue);
			mIsGuide.boolValue = EditorGUILayout.Toggle("是否开启引导:", mIsGuide.boolValue);
            mIsOpenGM.boolValue = EditorGUILayout.Toggle("是否开启GM工具:", mIsOpenGM.boolValue);
            mIsSDK.boolValue = EditorGUILayout.Toggle("是否勾选SDK:", mIsSDK.boolValue);
            mIsSDKLogin.boolValue = EditorGUILayout.Toggle("是否勾选SDK登录:", mIsSDKLogin.boolValue);
            mIsBundleMode.boolValue = EditorGUILayout.Toggle("是否为ab包模式:", mIsBundleMode.boolValue);
            mluaBundleMode.boolValue = EditorGUILayout.Toggle("是否开启LuaAB包模式:", mluaBundleMode.boolValue);
            mIsOpenTLog.boolValue = EditorGUILayout.Toggle("是否开启LuaTLog:", mIsOpenTLog.boolValue);
            mIsOpenBLog.boolValue = EditorGUILayout.Toggle("是否开启战斗BLog:", mIsOpenBLog.boolValue);
            //GameLogic.MultiLan lan = (GameLogic.MultiLan)mOriginLan.enumValueIndex;
            //mOriginLan.enumValueIndex = System.Convert.ToInt32(EditorGUILayout.EnumPopup("初始语言:", lan));
            mOriginLan.intValue = EditorGUILayout.IntField("初始语言id", mOriginLan.intValue);
            //mDownload_Resouces_Url.stringValue = EditorGUILayout.TextField("资源服务器地址:", mDownload_Resouces_Url.stringValue);

            //if (mServerInfos != null)
            //{
            //    if (mServerInfos.isArray && mServerInfos.arraySize > 0)
            //    {
            //        List<string> tmp = new List<string>();
            //        for (int i = 0; i < mServerInfos.arraySize; i++)
            //        {
            //            var eleProperty = mServerInfos.GetArrayElementAtIndex(i);
            //            if (eleProperty != null)
            //            {
            //                if (!string.IsNullOrEmpty(eleProperty.FindPropertyRelative("ServerName").stringValue))
            //                    tmp.Add(eleProperty.FindPropertyRelative("ServerName").stringValue);
            //            }
            //        }
            //        mServerIndex.intValue = EditorGUILayout.Popup("选择服务器:", mServerIndex.intValue, tmp.ToArray());
            //    }
            //    EditorGUILayout.PropertyField(mServerInfos, new GUIContent("服务器列表："), true);
            //}

            GUILayout.EndVertical();
            if (EditorGUI.EndChangeCheck())
            {
                serializedObject.ApplyModifiedProperties();
            }
        }
    }
}