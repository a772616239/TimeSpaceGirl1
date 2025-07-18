using System;
using UnityEngine;
using System.Collections.Generic;

namespace XDebug
{
    public static class Log
    {
        public struct LogInfo
        {
            public string str;
            public Color color;
        }

        public static Color BLUE = new Color(0, 0, 1);
        public static Color RED = new Color(1, 0, 0);
        public static Color YELLOW = new Color(1, 1, 0);
        public static Color WHITE = new Color(1, 1, 1);
        public static Color GREEN = new Color(0, 1, 0);
        public static Color BLACK = new Color(0, 0, 0);

        /// <summary>
        /// 控制是否开启debug, -1禁用Unity log, -2完全禁用
        /// </summary>
        public static int isEnabled = 1;
        public static int maxCount = int.MaxValue; //50000;
        public static List<LogInfo> logList = new List<LogInfo>();
        private static bool mIsDownOpenDebug = false;
        private static float mDownY = 0;
        private static bool mIsHideUILog = false;

        static Log()
        {
            GameLogic.GameManager.Instance.AddUpdateEvent(UpdateLog);
        }

        public static Action<string> AfterLog { get; set; }

        private static string getFormatStr(object[] args)
        {
            if (args == null)
                return "[NULL]   ";

            string str = "";
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == null)
                    str += "[NULL] , ";
                else
                    str += args[i] + " , ";
            }
            return str;
        }


        public static void error(params object[] args)
        {
            GameCore.BaseLogger.LogError(getFormatStr(args));
        }


        public static void warning(params object[] args)
        {
            GameCore.BaseLogger.LogWarning(getFormatStr(args));
        }

        public static void l(params object[] args)
        {
            l(WHITE, args);
        }

        public static void lHide(params object[] args)
        {
            if (isEnabled == -2) return;
            if (logList.Count > maxCount)
                clear();

            string str = getFormatStr(args);
            str = "[" + System.DateTime.Now.ToString("hh:mm：ss：ffff") + "] : " + str.Substring(0, str.Length - 3);
            logList.Add(new LogInfo() {str = str, color = WHITE});
        }
        
        public static void l(Color color, params object[] args)
        {
            if (isEnabled == -2) return;
            if (logList.Count > maxCount)
                clear();

            string str = getFormatStr(args);
            str = "[" + System.DateTime.Now.ToString("HH:mm:ss:ffff") + "] : " + str.Substring(0, str.Length - 3);
            logList.Add(new LogInfo() {str = str, color = color});
            if (isEnabled >= 0)
                GameCore.BaseLogger.Log(str);
            if (AfterLog!=null)
            {
                AfterLog(str);
            }
        }

        public static void clear()
        {
            logList.Clear();
        }


        public static void UpdateLog()
        {
            ////////手势控制开启关闭, 左下角滑到右上角开启,再次关闭
            if (isEnabled != -2)
            {
                Vector3 mousePos = Input.mousePosition;
                mousePos.y = Screen.height - mousePos.y;
                if (Input.GetMouseButtonDown(0) && mousePos.x / Screen.width < 0.1f && mousePos.y / Screen.height > 0.9f)
                {
                    mIsDownOpenDebug = true;
                }
                if (Input.GetMouseButtonUp(0))
                {
                    if (mousePos.x / Screen.width > 0.9f && mousePos.y / Screen.height < 0.1f && mIsDownOpenDebug)
                    {
                        //isEnabled += 1;
                        //if (isEnabled == 2)
                        //{
                        //    isEnabled = -2;
                        //}
                        if (GameCore.BaseLogger.level == 0)
                        {
                            GameLogic.Util.SetLogLevel(4); //error
                        }
                        else
                        {
                            GameLogic.Util.SetLogLevel(0); //all
                        }
                        
                        GameLogic.AppConst.isOpenTLog = !GameLogic.AppConst.isOpenTLog;
                        
                    }
                    mIsDownOpenDebug = false;
                }
            }
        }
    }
}

