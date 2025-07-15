﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;

namespace CreateScript
{

    public struct VariableJson
    {
        public bool isVariable;
        public bool isAttribute;
        public bool isEvent;
        public int index;
        public bool isOpen;
        public string name;
        public string type;
        public string findPath;
    }

    public class QVariableState
    {
        public static int space = 20;
        public static GUILayoutOption toggleMaxWidth = GUILayout.Width(50);
        public static GUILayoutOption popupMaxWidth = GUILayout.Width(100);

        public bool isVariable = false;
        public bool isAttribute = false;
        public bool isEvent = false;
        public int index = 0;
        private int oldIndex;
        public bool isOpen = true;
        private string[] comNames;

        public bool isSelectEvent = true;

        public Action<string> onTypeChanged;
        public void SetIndex(string name, Transform t)
        {
            comNames = QGlobalFun.GetComponentsName(t);

            int count = comNames.Length;
            for (int i = 0; i < count; i++)
            {
                if (name == comNames[i])
                {
                    index = i;
                    break;
                }
            }
        }

        public void Reset()
        {
            comNames = null;
        }

        public bool Update(Transform t, int depth)
        {
            var rect = EditorGUILayout.BeginHorizontal();
            {
                if (isVariable) EditorGUI.DrawRect(rect, new Color(0, 0.5f, 0, 0.3f));

                isVariable = EditorGUILayout.ToggleLeft("变量", isVariable, toggleMaxWidth);

                if(!isVariable)
                {
                    isAttribute = false;
                    isEvent = false;
                }

                {
                    GUI.enabled = isVariable;
                    isAttribute = EditorGUILayout.ToggleLeft("属性器", isAttribute, toggleMaxWidth);

                    GUI.enabled = !isVariable? false:isSelectEvent;
                    isEvent = EditorGUILayout.ToggleLeft("事件", isEvent, toggleMaxWidth);
                    GUI.enabled = true;

                }
                
                oldIndex = index;
                comNames = QGlobalFun.GetComponentsName(t);
                index = EditorGUILayout.Popup(index, comNames, popupMaxWidth);
                if (oldIndex != index)
                {
                    onTypeChanged(comNames[index]);
                }

                GUILayout.Space(depth * space);

                if (t.childCount > 0)
                {
                    isOpen = EditorGUILayout.Foldout(isOpen, t.name, true);
                }
                else
                {
                    EditorGUILayout.LabelField(t.name);
                }
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space();

            return isOpen;
        }
    }
}