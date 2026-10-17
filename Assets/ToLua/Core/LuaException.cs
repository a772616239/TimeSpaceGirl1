/*
Copyright (c) 2015-2017 topameng(topameng@qq.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

using System;
using System.Diagnostics;
using System.Reflection;
using System.Text;
using UnityEngine;

namespace LuaInterface
{
    public class LuaException : Exception
    {
        public static Exception luaStack = null;
        public static string projectFolder = null;
        public static int InstantiateCount = 0;
        public static int SendMsgCount = 0;
        public static IntPtr L = IntPtr.Zero;

        public override string StackTrace
        {
            get
            {
                return _stack;
            }
        }

        protected string _stack = string.Empty;        

        public LuaException(string msg, Exception e = null, int skip = 1)
            : base(msg)
        {                                  
            if (e != null)
            {
                if (e is LuaException)
                {
                    _stack = e.StackTrace;
                }
                else
                {                                        
                    StackTrace trace = new StackTrace(e, true);
                    StringBuilder sb = new StringBuilder();
                    ExtractFormattedStackTrace(trace, sb);                    
                    StackTrace self = new StackTrace(skip, true);
                    ExtractFormattedStackTrace(self, sb, trace);
                    _stack = sb.ToString();                    
                }
            }
            else
            {
                StackTrace self = new StackTrace(skip, true);
                StringBuilder sb = new StringBuilder();
                ExtractFormattedStackTrace(self, sb);
                _stack = sb.ToString();
            }                        
        }

        public static Exception GetLastError()
        {
            Exception last = luaStack;
            luaStack = null;
            return last;
        }

        public static void ExtractFormattedStackTrace(StackTrace trace, StringBuilder sb, StackTrace skip = null)
        {
            int begin = 0;

            if (skip != null && skip.FrameCount > 0)
            {
                MethodBase m0 = skip.GetFrame(skip.FrameCount - 1).GetMethod();

                for (int i = 0; i < trace.FrameCount; i++)
                {
                    StackFrame frame = trace.GetFrame(i);
                    MethodBase method = frame.GetMethod();

                    if (method == m0)
                    {
                        begin = i + 1;
                        break;
                    }                    
                }

                sb.AppendLineEx();
            }

            for (int i = begin; i < trace.FrameCount; i++)
            {
                StackFrame frame = trace.GetFrame(i);
                MethodBase method = frame.GetMethod();

                if (method == null || method.DeclaringType == null)
                {
                    continue;
                }                               

                Type declaringType = method.DeclaringType;
                string str = declaringType.Namespace;

                if ( (InstantiateCount == 0 && declaringType == typeof(UnityEngine.Object) &&  method.Name == "Instantiate") //(method.Name == "Internal_CloneSingle"
                    || (SendMsgCount == 0 && declaringType == typeof(GameObject) && method.Name == "SendMessage"))
                {
                    break;
                }

                if ((str != null) && (str.Length != 0))
                {
                    sb.Append(str);
                    sb.Append(".");
                }

                sb.Append(declaringType.Name);
                sb.Append(":");
                sb.Append(method.Name);
                sb.Append("(");
                int index = 0;
                ParameterInfo[] parameters = method.GetParameters();
                bool flag = true;

                while (index < parameters.Length)
                {
                    if (!flag)
                    {
                        sb.Append(", ");
                    }
                    else
                    {
                        flag = false;
                    }

                    sb.Append(parameters[index].ParameterType.Name);
                    index++;
                }

                sb.Append(")");
                string fileName = frame.GetFileName();                

                if (fileName != null)
                {
                    fileName = fileName.Replace('\\', '/');
                    sb.Append(" (at ");

                    if (!string.IsNullOrEmpty(projectFolder) && fileName.StartsWith(projectFolder))
                    {
                        fileName = fileName.Substring(projectFolder.Length, fileName.Length - projectFolder.Length);
                    }

                    sb.Append(fileName);
                    sb.Append(":");
                    sb.Append(frame.GetFileLineNumber().ToString());
                    sb.Append(")");
                }

                if (i != trace.FrameCount - 1)
                {
                    sb.Append("\n");
                }
            }
        }

        public static void Init(IntPtr L0)
        {
            L = L0;
            // 🔴 这段反射在 Unity 6 上会抛 NullReferenceException，导致 Lua 虚拟机初始化
            // 中断、游戏一进就卡死（LuaManager.InitLua -> LuaState..ctor -> 这里）。
            // 原因：Unity 2020.3 的 UnityEngine.StackTraceUtility 有
            //   internal static string projectFolder
            // 这个私有字段，而 Unity 6（6000.x）把这个类型上的字段全部删掉了，
            // GetField 返回 null。原代码直接 field.GetValue(null) ⇒ NRE，且
            // projectFolder 为 null 时下一行的 .Replace 也会炸。
            // 该字段只用于把异常栈里的绝对路径裁成工程相对路径，属于「锦上添花」，
            // 拿不到就应该降级退化，绝不能让它阻断 Lua 启动。
            Type type = typeof(StackTraceUtility);
            FieldInfo field = type.GetField("projectFolder", BindingFlags.Static | BindingFlags.GetField | BindingFlags.NonPublic);
            if (field != null)
            {
                LuaException.projectFolder = (string)field.GetValue(null);
            }

            if (string.IsNullOrEmpty(LuaException.projectFolder))
            {
                // 回退值：仅用于路径裁剪。Android 上 dataPath 与源码路径不匹配 ⇒ 不会命中
                // StartsWith，只是保留完整路径，异常栈依然可读。
                LuaException.projectFolder = Application.dataPath;
            }

            projectFolder = projectFolder.Replace('\\', '/');
#if DEVELOPER
            Debugger.Log("projectFolder is {0}", projectFolder);
#endif
        }
    }
}