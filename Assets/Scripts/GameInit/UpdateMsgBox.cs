using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Events;
namespace GameLogic {
    /// <summary>
    /// 更新提示框
    /// </summary>
    public class UpdateMsgBox : MonoBehaviour
    {
        /// <summary>
        /// 左边的按钮
        /// </summary>
        [SerializeField]
        Button buttonL;
        /// <summary>
        /// 左边按钮文字
        /// </summary>
        [SerializeField]
        Text buttonLText;
        /// <summary>
        /// 右边按钮
        /// </summary>
        [SerializeField]
        Button buttonR;
        /// <summary>
        /// 右边按钮文字
        /// </summary>
        [SerializeField]
        Text buttonRText;
        /// <summary>
        /// 右边按钮
        /// </summary>
        [SerializeField]
        Button buttonC;
        /// <summary>
        /// 右边按钮文字
        /// </summary>
        [SerializeField]
        Text buttonCText;
        /// <summary>
        /// 消息
        /// </summary>
        [SerializeField]
        Text msg;
        /// <summary>
        /// title
        /// </summary>
        [SerializeField]
        Text title;
        /// <summary>
        /// 点击回调
        /// </summary>
        UnityAction<int> action;
        protected void Awake()
        {
            buttonL.onClick.AddListener(LClickHandler);
            buttonR.onClick.AddListener(RClickHandler);
            buttonC.onClick.AddListener(CClickHandler);
            title.text = SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.TIPS);
        }

        private void ClosePanel()
        {
            CallBack(-1);
        }

        /// <summary>
        /// 左边按钮点击
        /// </summary>
        private void LClickHandler()
        {
            CallBack(0);
        }
        /// <summary>
        /// 右边按钮点击
        /// </summary>
        private void RClickHandler()
        {
            CallBack(1);
        }
        /// <summary>
        /// 右边按钮点击
        /// </summary>
        private void CClickHandler()
        {
            CallBack(2);
        }

        /// <summary>
        /// 回调
        /// </summary>
        /// <param name="i"></param>
        private void CallBack(int i)
        {
            this.gameObject.SetActive(false);
            if (action != null)
            {
                action(i);
            }
        }

        /// <summary>
        /// 显示提示框，有两个按钮
        /// </summary>
        /// <param name="strL"></param>
        /// <param name="strR"></param>
        /// <param name="msg"></param>
        public void Show(string strL, string strR, string msg, UnityAction<int> action)
        {
            this.gameObject.SetActive(true);
            this.buttonL.gameObject.SetActive(true);
            this.buttonR.gameObject.SetActive(true);
            this.buttonC.gameObject.SetActive(false);
            this.buttonLText.text = strL;
            this.buttonRText.text = strR;
            this.msg.text = msg;
            this.action = action;
        }

        /// <summary>
        /// 显示对话框，只有一个按钮
        /// </summary>
        /// <param name="strc"></param>
        /// <param name="msg"></param>
        /// <param name="action"></param>
        public void Show(string strc, string msg, UnityAction<int> action)
        {
            this.gameObject.SetActive(true);
            this.buttonL.gameObject.SetActive(false);
            this.buttonR.gameObject.SetActive(false);
            this.buttonC.gameObject.SetActive(true);
            this.buttonCText.text = strc;
            this.msg.text = msg;
            this.action = action;
        }


        /// <summary>
        /// 显示对话框，没有按钮
        /// </summary>
        /// <param name="strc"></param>
        /// <param name="msg"></param>
        /// <param name="action"></param>
        public void Show(string msg)
        {
            this.gameObject.SetActive(true);
            this.buttonL.gameObject.SetActive(false);
            this.buttonR.gameObject.SetActive(false);
            this.buttonC.gameObject.SetActive(false);
            this.msg.text = msg;
        }
    }

}
