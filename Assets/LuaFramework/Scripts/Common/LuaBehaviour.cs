using UnityEngine;
using LuaInterface;
using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine.UI;
using UnityEngine.SceneManagement;

namespace GameLogic
{
    public class LuaBehaviour : MonoBehaviour
    {
        private string data = null;
        private Dictionary<string, LuaFunction> buttons = new Dictionary<string, LuaFunction>();

        protected void Awake()
        {
            Util.CallMethod(name, "Awake", gameObject);
        }

        protected void Start()
        {
            Util.CallMethod(name, "Start");
        }

        protected void OnClick()
        {
            Util.CallMethod(name, "OnClick");

        }

        protected void OnClickEvent(GameObject go)
        {
            Util.CallMethod(name, "OnClick", go);
        }

        /// <summary>
        /// 添加单击事件
        /// </summary>
        public void AddClick(GameObject go, LuaFunction luafunc)
        {
            if (go == null || luafunc == null) return;
            buttons.Add(go.name, luafunc);
            go.GetComponent<Button>().onClick.AddListener(
                delegate()
                {
                    luafunc.Call(go);
                }
            );
        }

        public void AddClickToChild(GameObject root, string btnName, LuaFunction luafunc)
        {
            if (root == null || luafunc == null || string.IsNullOrEmpty(btnName)) return;

            var btnTrans = root.transform.Find(btnName);
            if (btnTrans == null) return;

            AddClick(btnTrans.gameObject, luafunc);
        }

        public void AddToggle(GameObject go, LuaFunction func)
        {
            if (go == null || func == null) return;

            go.GetComponent<Toggle>().onValueChanged.AddListener(
                delegate(bool isToggle)
                {
                    func.Call(isToggle);
                }
            );
        }

        public void AddInputField_OnValueChanged(GameObject go, LuaFunction func)
        {
            if (go == null || func == null) return;

            go.GetComponent<InputField>().onValueChanged.AddListener(
                delegate(string str)
                {
                    func.Call(str);
                }
            );
        }

        public void AddInputField_OnEndEdit(GameObject go, LuaFunction func)
        {
            if (go == null || func == null) return;

            go.GetComponent<InputField>().onEndEdit.AddListener(
                delegate(string str)
                {
                    func.Call(str);
                }
            );
        }

        /// <summary>
        /// 删除单击事件
        /// </summary>
        /// <param name="go"></param>
        public void RemoveClick(GameObject go)
        {
            if (go == null) return;
            LuaFunction luafunc = null;
            if (buttons.TryGetValue(go.name, out luafunc))
            {
                luafunc.Dispose();
                luafunc = null;
                buttons.Remove(go.name);
            }
        }

        /// <summary>
        /// 清除单击事件
        /// </summary>
        public void ClearClick()
        {
            foreach (var de in buttons)
            {
                if (de.Value != null)
                {
                    de.Value.Dispose();
                }
            }
            buttons.Clear();
        }

        //-----------------------------------------------------------------
        protected void OnDestroy()
        {
            ClearClick();
           App.ResMgr.UnLoadAsset(name);
          //  Util.ClearMemory();
            Debug.LogFormat("~{0} was destroy!",name);
        }
    }
}