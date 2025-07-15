using CreateScript;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace Assets.CreateScript_master.Assets.Plugins.QCreateScript.Editor
{
    class QMoudleManagerVariable
    {
        List<MoudleScript> moudleScriptList = new List<MoudleScript>();

        public int NetNum
        {
            get
            {
                return moudleScriptList.Count;
            }
        }

        public override string ToString()
        {
            return GetBuildUICode();
        }

        StringBuilder register = new StringBuilder();
        StringBuilder statement = new StringBuilder();

        public string GetBuildUICode()
        {
            register.Length = statement.Length = 0;

            for (int i = 0; i < moudleScriptList.Count; i++)
            {
                string moudleName = QConfigure.moudleName;
                string netName = QConfigure.netName;
                string netSubName = QConfigure.netSubName;
                string notes = moudleScriptList[i].notes;        
                string newsName = moudleScriptList[i].newsName;
                string sendClassName = moudleScriptList[i].sendClassName;
                string receiveClassName = moudleScriptList[i].receiveClassName;
                string sendNewsStr = moudleScriptList[i].GetSendNewsStr();
                string receiveNewsStr = moudleScriptList[i].GetReceiveNewsStr();

                if (notes == null || newsName == null || sendClassName == null || 
                    receiveClassName == null || netName == null || netSubName == null ||
                    notes == string.Empty || newsName == string.Empty || sendClassName == string.Empty ||
                    receiveClassName == string.Empty || netName == string.Empty || netSubName == string.Empty)
                    continue;

                string registerName1 = string.Format(QConfigure.registerName, netName, netSubName, newsName);
                string registerName2 = moudleName+ "_" + sendNewsStr;

                string sendNewsCode = string.Format(QConfigure.sendNewsCode, sendClassName, netName + "." + netSubName, netSubName + "." + newsName);
                string acceptNewsCode = string.Format(QConfigure.acceptNewsCode, receiveClassName);

                register.AppendFormat(QConfigure.registerNetCode, notes, registerName1, receiveNewsStr, registerName2, sendNewsStr);
                statement.AppendFormat(QConfigure.statementNetCode, notes, sendNewsStr, receiveNewsStr, sendNewsCode, acceptNewsCode);
            }

            var tmp = string.Format(QConfigure.modelClassCode, register, statement);
            return string.Format(QConfigure.modelCode, QConfigure.moudleName, tmp);
        }

        public void Copy()
        {
            if (QConfigure.selectTransform == null) return;
            GUIUtility.systemCopyBuffer = GetBuildUICode();
            EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.copy, QConfigure.ok);
        }

        public void Clear()
        {
            moudleScriptList.Clear();
        }

        public void Init()
        {

        }

        public void GenerateInfo(int num)
        {
            int currNum = moudleScriptList.Count;

            int generateCount = num - currNum;

            if (generateCount > 0)
            {
                for (int i = 0; i < generateCount; i++)
                {
                    MoudleScript moudle = new MoudleScript();
                    moudleScriptList.Add(moudle);
                }
            }
            else if (generateCount < 0)
            {
                for (int i = currNum - 1; i >= 0; i--)
                {
                    moudleScriptList.Remove(moudleScriptList[i]);
                }
            }


        }

        public void ShowInfo()
        {
            for (int i = 0; i < moudleScriptList.Count; i++)
            {
                EditorGUILayout.Space();
                EditorGUILayout.Space();
                EditorGUILayout.Space();
                EditorGUILayout.BeginVertical();
                {
                    EditorGUILayout.LabelField("消息" + (i + 1));
                    moudleScriptList[i].notes = EditorGUILayout.TextField("消息注释：", moudleScriptList[i].notes);
                    moudleScriptList[i].newsName = EditorGUILayout.TextField("消息名：", moudleScriptList[i].newsName);
                    moudleScriptList[i].sendClassName = EditorGUILayout.TextField("发送消息类名：", moudleScriptList[i].sendClassName);
                    moudleScriptList[i].receiveClassName = EditorGUILayout.TextField("接收消息类名：", moudleScriptList[i].receiveClassName);
                }
                EditorGUILayout.EndVertical();
            }
        }
    }

    class MoudleScript
    {
        public string notes;        //注释
        public string newsName;     //消息名
        public string sendClassName;     //发送消息名
        public string receiveClassName;  //接收消息名

        public string GetSendNewsStr()
        {
            return "Send" + newsName;
        }

        public string GetReceiveNewsStr()
        {
            return "Accept" + newsName;
        }
    }
}
