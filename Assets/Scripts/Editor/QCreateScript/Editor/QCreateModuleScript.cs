using CreateScript;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace Assets.CreateScript_master.Assets.Plugins.QCreateScript.Editor
{
    class QCreateModuleScript : EditorWindow
    {
        public static QCreateModuleScript window;

        private QMoudleManagerVariable manager = new QMoudleManagerVariable();

        //[MenuItem("MyTools/CreateModuleScript")]
        private static void ShowWindow()
        {
            window = GetWindow<QCreateModuleScript>();
            window.Show();
        }


        private void OnGUI()
        {
            SelectTarget();

            EditorGUILayout.BeginHorizontal();
            {
                DrawLeft();
                DrawRight();
            }
            EditorGUILayout.EndHorizontal();
        }

        private void DrawLeft()
        {
            EditorGUILayout.BeginVertical();
            {
                DrawCreatePath();
                EditorGUILayout.Space();
                EditorGUILayout.Space();
                EditorGUILayout.BeginHorizontal();
                EditorGUILayout.EndHorizontal();
                EditorGUILayout.Space();
                EditorGUILayout.BeginHorizontal();
                EditorGUILayout.EndHorizontal();
                EditorGUILayout.BeginHorizontal();
                {
                    if (GUILayout.Button("复制代码", GUILayout.Width(540), GUILayout.Height(50))) manager.Copy();
                }
                EditorGUILayout.EndHorizontal();

                DrawTable();

            }
            EditorGUILayout.EndVertical();
        }

        private Vector2 tablePos;
        private void DrawTable()
        {
            manager.GenerateInfo(QConfigure.netNum);

            tablePos = EditorGUILayout.BeginScrollView(tablePos);
            {
                if (QConfigure.selectTransform != null)
                {
                    manager.ShowInfo();
                }
            }
            EditorGUILayout.EndScrollView();
        }

        private Vector2 pos;
        private void DrawRight()
        {
            EditorGUILayout.BeginVertical();
            {
                var rect = EditorGUILayout.GetControlRect();
                rect.height = 35;
                GUI.Box(rect, "代码预览", "GroupBox");
                GUILayout.Space(20);

                {
                    pos = EditorGUILayout.BeginScrollView(pos, GUILayout.Width(position.width * 0.5f));
                    {
                        if (QConfigure.selectTransform != null)
                        {
                            var str = manager.ToString();
                            var array = QGlobalFun.GetStringList(str);
                            EditorGUILayout.BeginVertical();
                            {
                                foreach (var item in array)
                                {
                                    GUILayout.Label(item);
                                }
                            }
                            EditorGUILayout.EndVertical();

                        }
                    }
                    EditorGUILayout.EndScrollView();
                }
            }
            EditorGUILayout.EndVertical();
        }

        private void DrawCreatePath()
        {
            EditorGUILayout.Space();
            if (QConfigure.moudleName == null)
            {
                QConfigure.moudleName = QGlobalFun.GetMoudleString(QConfigure.selectTransform.name);
            }

            EditorGUILayout.BeginHorizontal();
            {
                QConfigure.moudleName = EditorGUILayout.TextField("ClassName：", QConfigure.moudleName);
                if (GUILayout.Button("默认"))
                {
                    QConfigure.moudleName = EditorGUILayout.TextField("ClassName：", QGlobalFun.GetMoudleString(QConfigure.selectTransform.name));
                }

            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            {
                QConfigure.netName = EditorGUILayout.TextField("NetName：", QConfigure.netName);
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            {
                QConfigure.netSubName = EditorGUILayout.TextField("NetSubName：", QConfigure.netSubName);
            }
            EditorGUILayout.EndHorizontal();


            EditorGUILayout.BeginHorizontal();
            {
                string netNum = EditorGUILayout.TextField("NetNum：", QConfigure.netNum.ToString());
                QConfigure.netNum = netNum != string.Empty ? int.Parse(netNum) : manager.NetNum;
            }
            EditorGUILayout.EndHorizontal();
        }

        private void SelectTarget()
        {
            if (QConfigure.selectTransform != Selection.activeTransform)
            {
                if (QConfigure.selectTransform != null)
                {
                    manager.Clear();
                }
                QConfigure.selectTransform = Selection.activeTransform;
                if (QConfigure.selectTransform != null)
                {
                    manager.Init();
                }
                if (Selection.gameObjects.Length == 1)
                {
                    QConfigure.selectTransform = Selection.gameObjects[0].transform;
                    if (QConfigure.selectTransform != null)
                    {
                        manager.Init();
                    }
                }
            }
        }
    }

}
