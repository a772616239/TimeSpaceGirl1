using UnityEngine;

/*
 * 
 * 日志输出类
 * 
 * **/
namespace GameCore
{
    public enum LogLevel
    {
        All = 0,
        Debug,
        Info,
        Warn,
        Error,
        Fatal,
        Off
    }

    public class BaseLogger
    {
        public static bool isDebug = false;
        /// <summary>
        /// 日志等级
        /// </summary>
        public static LogLevel level;
         
        public static void Log(object content)
        {
            if ((int)level <= (int)LogLevel.Info)
            {
                Debug.Log(content);
            }
        }
        public static void Log(object message, Object content)
        {
            if ((int)level <= (int)LogLevel.Info)
            {
                Debug.Log(message, content);
            }
        }

        public static void LogFormat(string format, params object[] args)
        {
            if ((int)level <= (int)LogLevel.Info)
            {
                Debug.LogFormat(format, args);
            }
        }
        public static void LogWarning(object content)
        {
            if ((int)level <= (int)LogLevel.Warn)
            {
                Debug.LogWarning(content);
            }
        }

        public static void LogWarning(object message, Object content)
        {
            if ((int)level <= (int)LogLevel.Warn)
            {
                Debug.LogWarning(message, content);
            }
        }


        public static void LogWarningFormat(string format, params object[] args)
        {
            if ((int)level <= (int)LogLevel.Warn)
            {
                Debug.LogWarningFormat(format, args);
            }
        }


        public static void LogError(object content)
        {
            if ((int)level <= (int)LogLevel.Error)
            {
                Debug.LogError(content);
            }
        }


        public static void LogError(object message, Object content)
        {
            if ((int)level <= (int)LogLevel.Error)
            {
                Debug.LogError(message, content);
            }
        }

        public static void LogErrorFormat(string format, params object[] args)
        {
            if ((int)level <= (int)LogLevel.Error)
            {
                Debug.LogErrorFormat(format, args);
            }
        }

        public static void LogL(object content)
        {
            Debug.Log(content);
        }

    }
}