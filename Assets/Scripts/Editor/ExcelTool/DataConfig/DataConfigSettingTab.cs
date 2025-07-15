using GameEditor.Core.Util;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace GameEditor.Core.DataConfig
{
    public class DataConfigSettingTab
    {
        public DataConfigSettingTab()
        {
        }

        public bool IsValidSetting()
        {
            if (string.IsNullOrEmpty(DataConfigSetting.execlDir))
            {
                return false;
            }
            if(Directory.Exists(DataConfigSetting.execlDir))
            {
                return false;
            }
            return true;
        }

        public void OnGUI(Rect rect)
        {
            DataConfigSetting setting = DataConfigWindow.window.setting;
            GUILayout.BeginArea(rect);
            {
                EditorGUILayout.BeginVertical(EditorStyles.helpBox,GUILayout.ExpandHeight(true));
                {
                    EditorGUILayout.LabelField("Setting", GTEditorGUIStyle.BigLabelMidCeneterStyle, GUILayout.Height(25));
                    EditorGUILayout.BeginHorizontal();
                    {
                        EditorGUILayout.TextField("Excel Dir:", DataConfigSetting.execlDir);
                        if (GUILayout.Button("Brower", GUILayout.Width(60)))
                        {
                            DataConfigSetting.execlDir = BrowerFolder("Excel Dir", DataConfigSetting.execlDir);
                        }
                    }
                    EditorGUILayout.EndHorizontal();

                    EditorGUILayout.BeginHorizontal();
                    {
                        EditorGUILayout.TextField("Client Dir:", setting.clientOutputDir);
                        if (GUILayout.Button("Brower", GUILayout.Width(60)))
                        {
                            setting.clientOutputDir = BrowerFolder("Client Dir", setting.clientOutputDir);
                            if(string.IsNullOrEmpty(setting.clientOutputDir))
                            {
                                setting.clientOutputDir = Application.dataPath + "/Scripts/LuaScripts/DataConfig/Config";
                            }
                        }
                    }
                    EditorGUILayout.EndHorizontal();

                    EditorGUILayout.BeginHorizontal();
                    {
                        EditorGUILayout.TextField("Server Dir:", setting.serverOutputDir);
                        if (GUILayout.Button("Brower", GUILayout.Width(60)))
                        {
                            setting.serverOutputDir = BrowerFolder("Server Dir", setting.serverOutputDir);
                        }
                    }
                    EditorGUILayout.EndHorizontal();

                    GUILayout.FlexibleSpace();
                    EditorGUILayout.BeginHorizontal(GUILayout.ExpandWidth(true));
                    {
                        GUILayout.FlexibleSpace();
                        if(GUILayout.Button("Apply",GUILayout.Width(120)))
                        {
                            DataConfigWindow.window.OnSettingChanged();
                        }
                    }
                    EditorGUILayout.EndHorizontal();
                }
                EditorGUILayout.EndVertical();
            }
            GUILayout.EndArea();
        }

        private string BrowerFolder(string title,string folder)
        {
            string folderPath = folder;
            string path = EditorUtility.OpenFolderPanel(title, folderPath, "");
            if(!string.IsNullOrEmpty(path))
            {
                folderPath = path;
            }
            return folderPath;
        }
    }
}
