using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace GameEditor.Core.Util
{
    public delegate object DrawObjectInList(object obj, Type t);

    public static class GTEditorGUI
    {
        public static void DrawLayoutHorizontalLine()
        {
            Rect r = GUILayoutUtility.GetLastRect();
            Color og = GUI.backgroundColor;
            GUI.backgroundColor = Color.black;
            GUI.Box(new Rect(0f, r.y + r.height + 2, Screen.width, 2f), "");
            GUI.backgroundColor = og;

            GUILayout.Space(6);
        }

        public static void DrawObjectListEditor<T>(string title, List<T> list, ref bool isFoldout, 
                                                    DrawObjectInList OnDrawObj,Color bgColor, bool isReadonly = false) where T : class
        {
            int delIndex = -1;
            int moveIndex = -1;
            int moveStep = 0;

            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            {
                EditorGUILayout.BeginHorizontal();
                {
                    isFoldout = EditorGUILayout.Foldout(isFoldout, title, true);
                    if (!isReadonly)
                    {
                        Color tbgColor = GUI.backgroundColor;
                        GUI.backgroundColor = bgColor;
                        if (GUILayout.Button("+", GUILayout.Width(40)))
                        {
                            if (list == null)
                                list = new List<T>();

                            list.Add(default(T));
                        }
                        if (GUILayout.Button("-", GUILayout.Width(40)))
                        {
                            if (list != null && list.Count > 0)
                                list.RemoveAt(list.Count - 1);
                        }
                        GUI.backgroundColor = tbgColor;
                    }
                }
                EditorGUILayout.EndHorizontal();

                if (isFoldout)
                {
                    EditorGUI.indentLevel++;
                    if (list == null)
                    {
                        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
                        {
                            EditorGUILayout.LabelField("The list is NULL");
                        }
                        EditorGUILayout.EndVertical();
                    }
                    else
                    {
                        for (int i = 0; i < list.Count; i++)
                        {
                            EditorGUILayout.BeginHorizontal(EditorStyles.helpBox);
                            {
                                EditorGUILayout.LabelField("" + (i + 1), GUILayout.Width(40));
                                if (OnDrawObj != null)
                                {
                                    if (isReadonly)
                                    {
                                        OnDrawObj(list[i], typeof(T));
                                    }
                                    else
                                    {
                                        list[i] = (T)OnDrawObj(list[i], typeof(T));
                                    }
                                }
                                if (!isReadonly)
                                {
                                    Color tbgColor = GUI.backgroundColor;
                                    GUI.backgroundColor = bgColor;
                                    EditorGUILayout.BeginVertical(GUILayout.Width(50));
                                    {
                                        if (GUILayout.Button("-", GUILayout.Width(40)))
                                        {
                                            delIndex = i;
                                        }
                                        if (i != 0)
                                        {
                                            if (GUILayout.Button("\u25B2", GUILayout.Width(40)))
                                            {
                                                moveIndex = i;
                                                moveStep = -1;
                                            }
                                        }
                                        if (i != list.Count - 1)
                                        {
                                            if (GUILayout.Button("\u25BC", GUILayout.Width(40)))
                                            {
                                                moveIndex = i;
                                                moveStep = 1;
                                            }
                                        }
                                    }
                                    EditorGUILayout.EndVertical();
                                    GUI.backgroundColor = tbgColor;
                                }
                            }
                            EditorGUILayout.EndHorizontal();
                        }
                    }
                    EditorGUI.indentLevel--;
                }
            }
            EditorGUILayout.EndVertical();

            if (list != null && delIndex >= 0 && delIndex < list.Count)
            {
                list.RemoveAt(delIndex);
            }
            if(list!=null && moveIndex>=0 && moveStep != 0)
            {
                int targetIndex = moveIndex + moveStep;
                T moveObj = list[moveIndex];
                T targetObj = list[targetIndex];
                list[moveIndex] = targetObj;
                list[targetIndex] = moveObj;
            }
            delIndex = -1;
            moveIndex = -1;
            moveStep = 0;
        }

        public static void DrawHorizontalSplitter(Rect dragRect)
        {
            if (Event.current.type != EventType.Repaint)
                return;

            Color orgColor = GUI.color;
            Color tintColor = (EditorGUIUtility.isProSkin) ? new Color(0.12f, 0.12f, 0.12f, 1.333f) : new Color(0.6f, 0.6f, 0.6f, 1.333f);
            GUI.color = GUI.color * tintColor;
            Rect splitterRect = new Rect(dragRect.x - 1, dragRect.y, 2, dragRect.height);
            GUI.DrawTexture(splitterRect, EditorGUIUtility.whiteTexture);
            GUI.color = orgColor;
        }

        public static void DrawVerticalSplitter(Rect dragRect)
        {
            if (Event.current.type != EventType.Repaint)
                return;

            Color orgColor = GUI.color;
            Color tintColor = (EditorGUIUtility.isProSkin) ? new Color(0.12f, 0.12f, 0.12f, 1.333f) : new Color(0.6f, 0.6f, 0.6f, 1.333f);
            GUI.color = GUI.color * tintColor;
            Rect splitterRect = new Rect(dragRect.x, dragRect.y + 1, dragRect.width, 1f);
            GUI.DrawTexture(splitterRect, EditorGUIUtility.whiteTexture);
            GUI.color = orgColor;
        }

        public static void DrawArrow(Vector2 from, Vector2 to, Color color)
        {
            Handles.BeginGUI();
            Handles.color = color;
            Handles.DrawAAPolyLine(3, from, to);
            Vector2 v0 = from - to;
            v0 *= 10 / v0.magnitude;
            Vector2 v1 = new Vector2(v0.x * 0.866f - v0.y * 0.5f, v0.x * 0.5f + v0.y * 0.866f);
            Vector2 v2 = new Vector2(v0.x * 0.866f + v0.y * 0.5f, v0.x * -0.5f + v0.y * 0.866f); ;
            Handles.DrawAAPolyLine(3, to + v1, to, to + v2);
            Handles.EndGUI();
        }
    }

    public static class GTEditorGUIStyle
    {
        private static GUIStyle labelMidCenterStyle = null;
        public static GUIStyle LabelMidCenterStyle
        {
            get
            {
                if(labelMidCenterStyle == null)
                {
                    labelMidCenterStyle = new GUIStyle(GUI.skin.GetStyle("Label"));
                    labelMidCenterStyle.alignment = TextAnchor.MiddleCenter;
                }
                return labelMidCenterStyle;
            }
        }

        private static GUIStyle labelMidLeftWrapStyle = null;
        public static GUIStyle LabelMidLeftWrapStyle
        {
            get
            {
                if (labelMidLeftWrapStyle == null)
                {
                    labelMidLeftWrapStyle = new GUIStyle(GUI.skin.GetStyle("Label"));
                    labelMidLeftWrapStyle.alignment = TextAnchor.MiddleLeft;
                    labelMidLeftWrapStyle.wordWrap = true;
                    
                }
                return labelMidLeftWrapStyle;
            }
        }

        private static GUIStyle bigLabelMidCeneterStyle = null;
        public static GUIStyle BigLabelMidCeneterStyle
        {
            get
            {
                if (bigLabelMidCeneterStyle == null)
                {
                    bigLabelMidCeneterStyle = new GUIStyle(GUI.skin.GetStyle("Label"));
                    bigLabelMidCeneterStyle.alignment = TextAnchor.MiddleCenter;
                    bigLabelMidCeneterStyle.fontSize = 20;
                }
                return bigLabelMidCeneterStyle;
            }
        }

        private static GUIStyle toolbarMidCenterStyle = null;
        public static GUIStyle ToolbarMidCenterStyle
        {
            get
            {
                if (toolbarMidCenterStyle == null)
                {
                    toolbarMidCenterStyle = new GUIStyle(GUI.skin.GetStyle("Toolbar"));
                    toolbarMidCenterStyle.alignment = TextAnchor.MiddleCenter;
                }
                return toolbarMidCenterStyle;
            }
        }

        
    }
}


