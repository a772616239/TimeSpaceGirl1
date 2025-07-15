using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

namespace CreateScript
{
    public class QCreateScript : EditorWindow
    {
        public static QCreateScript window;

        private QManagerVariable manager = new QManagerVariable();

        [MenuItem("Tools/CreateUIScript")]
        private static void ShowWindow()
        {
            QManagerVariable.isMain = true;
            window = GetWindow<QCreateScript>();
            window.Show();
        }

        private void Awake()
        {
            manager = new QManagerVariable();
            if (QConfigure.selectTransform != null)
                manager.Init();
        }

        [InitializeOnLoadMethod]
        private static void App()
        {
            Selection.selectionChanged += () =>
            {
                if (window != null)
                {
                    window.manager.Clear();
                    window.Repaint();
                }
            };
        }

        private void OnGUI()
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
                if(Selection.gameObjects.Length==1){
                    QConfigure.selectTransform = Selection.gameObjects[0].transform;
                    if(QConfigure.selectTransform!=null){
                        manager.Init();
                    }
                }
            }

            Test();
            EditorGUILayout.BeginHorizontal();
            {
                if (QConfigure.version == 2)
                {
                    DrawLeftListView();
                }
                
                DrawLeft();
                DrawRight();
            }
            EditorGUILayout.EndHorizontal();

            if (!EditorApplication.isCompiling)
            {
                if (QConfigure.IsCompiling())
                {
                    manager.Init();
                }
            }
        }

        private void Test()
        {/*
            if(GUILayout.Button("Test")){
                manager.GetBindingInfoToJson();
            }*/
        }

        private void DrawCreatePath()
        {
            EditorGUILayout.Space();
            if(QConfigure.className == null)
            {
                QConfigure.className = QGlobalFun.GetString(QConfigure.selectTransform.name);
            }
            EditorGUILayout.BeginHorizontal();
            {
                QConfigure.className = EditorGUILayout.TextField("ClassName：", QConfigure.className);
                if (GUILayout.Button("默认"))
                {
                    QConfigure.className = EditorGUILayout.TextField("ClassName：", QGlobalFun.GetString(QConfigure.selectTransform.name));
                }
                    
            }

            EditorGUILayout.EndHorizontal();

        }

        Vector2 leftViewPos;
        private void DrawLeftListView()
        {
            /*EditorGUILayout.BeginVertical(GUILayout.MaxWidth(200));
            {
                EditorGUILayout.LabelField("已生成界面", "");
                leftViewPos = EditorGUILayout.BeginScrollView(leftViewPos);
                {
                }
                EditorGUILayout.EndScrollView();
            }
            EditorGUILayout.EndVertical();*/
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

        private Vector2 tablePos;
        private void DrawTable()
        {
            EditorGUILayout.Space();
            EditorGUILayout.BeginHorizontal();
            {
                if (GUILayout.Button("全选变量")) manager.TotalSelectVariable();
                if (GUILayout.Button("全选属性器")) manager.TotalAttribute();
                if (GUILayout.Button("全选事件")) manager.TotalEvent();
                if (GUILayout.Button("全折叠")) manager.TotalFold(false);
                if (GUILayout.Button("查找赋值")) 
                {
                    manager.isFind = true; 
                    if (!QManagerVariable.isCsharpMode) 
                        manager.SetAllValue();
                }
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            {
                if (GUILayout.Button("全取消变量")) manager.TotalSelectVariable(false);
                if (GUILayout.Button("全取消属性器")) manager.TotalAttribute(false);
                if (GUILayout.Button("全取消事件")) manager.TotalEvent(false);
                if (GUILayout.Button("全展开")) manager.TotalFold();
                if (GUILayout.Button("取消查找")) manager.isFind = false;
               
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.BeginHorizontal();
            {
                if (GUILayout.Button("主物体")) manager.SetMain(true);

                if (GUILayout.Button("子物体")) manager.SetMain(false);

            }

            EditorGUILayout.EndHorizontal();


            EditorGUILayout.BeginHorizontal();
            {
                if (GUILayout.Button("一键完事", GUILayout.Width(540), GUILayout.Height(35)))
                {
                    //if (QManagerVariable.isCsharpMode)
                    //    CsharpModeOver();
                    //else
                    //    ValueModeOver();

                    LuaModeOver();
                    manager.Copy();
                }
            }
            EditorGUILayout.EndHorizontal();

            
            EditorGUILayout.Space();
            tablePos = EditorGUILayout.BeginScrollView(tablePos);
            {
                if (QConfigure.selectTransform != null)
                {
                    DrawRow(QConfigure.selectTransform);
                }
            }
            EditorGUILayout.EndScrollView();
        }

        protected void CsharpModeOver()
        {
            QConfigure.className = EditorGUILayout.TextField("ClassName：", QGlobalFun.GetString(QConfigure.selectTransform.name));
            manager.TetalSelectVariableTwo();
            manager.isFind = true;
            manager.TotalEvent();
        }
        protected void ValueModeOver()
        {
            QConfigure.className = EditorGUILayout.TextField("ClassName：", QGlobalFun.GetString(QConfigure.selectTransform.name));
            manager.TetalSelectVariableThree();
            manager.isFind = true;
            manager.TotalEvent();
            manager.SetAllValue();
        }

        protected void LuaModeOver()
        {
            QConfigure.className = EditorGUILayout.TextField("ClassName：", QGlobalFun.GetString(QConfigure.selectTransform.name));
            manager.TetalSelectVariableThree();
            manager.isFind = true;
            manager.TotalEvent();
        }


        private void DrawRow(Transform tr, int depth = 0)
        {
            foreach (Transform t in tr)
            {
                if (manager[t].state.Update(t, depth) && t.childCount > 0)
                {
                    DrawRow(t, depth + 1);
                }
            }
        }
    }
}
