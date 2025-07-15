using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using LuaInterface;
using System.Reflection;
using System.IO;
using UnityEngine.SceneManagement;
using GameCore;

#if UNITY_IOS
using System.Runtime.InteropServices;
#endif

namespace GameLogic
{
    public class GameManager : UnitySingleton<GameManager>
    {
        private Action UpdateAction;
        private string uid = string.Empty;
        /// <summary>
        /// 初始化游戏管理器
        /// </summary>
        void Awake()
        {
            Init();
        }
        /// <summary>
        /// 初始化
        /// </summary>
        void Init()
        {
            DontDestroyOnLoad(gameObject);  //防止销毁自己
        }


        public void Restart() { 

        }


        public void Reset() 
        {
        }

        /// <summary>
        /// 析构函数
        /// </summary>
        void OnDestroy()
        {
            if (App.NetWorkMgr != null)
            {
                App.NetWorkMgr.Unload();
            }
            if (App.LuaMgr != null)
            {
                App.LuaMgr.Close();
            } 
        }


        public void AddUpdateEvent(Action updateEvent)
        {
            if (updateEvent != null)
            {
                UpdateAction= (Action)Delegate.Combine(UpdateAction, updateEvent);
            }
        }

        public void RemoveUpdateEvent(Action updateEvent)
        {
            if (UpdateAction != null && updateEvent!=null)
            {
                UpdateAction=(Action) Delegate.Remove(UpdateAction, updateEvent);// UpdateAction -= updateEvent;
            }
        }


         void Update()
        {
            if (UpdateAction != null)
            {
                UpdateAction.Invoke();
            }
        }

        /// <summary>
        /// 把分享图片移动到persistentDataPath
        /// </summary>
        /// <returns></returns>
        IEnumerator MoveShareImg()
        {
            string dataPath = Util.DataPath;
            string resPath = Util.AppRootPath();
            string infile = resPath + "Resources/share_img.png";
            string outfile = dataPath + "Resources/share_img.png";
            string dir = Path.GetDirectoryName(outfile);
            if (!Directory.Exists(dir))
                Directory.CreateDirectory(dir);
            if (File.Exists(outfile))
            {
                yield break;
            }

            if (Application.platform == RuntimePlatform.Android)
            {
                WWW www = new WWW(infile);
                yield return www;

                if (www.isDone)
                {
                    File.WriteAllBytes(outfile, www.bytes);
                }
                yield return 0;
            }
            else
            {
                if (File.Exists(outfile))
                {
                    File.Delete(outfile);
                }

                File.Copy(infile, outfile, true);
            }

            yield return new WaitForEndOfFrame();
        }

        public string GetUid()
        {
            return this.uid;
        }

        public void SetUid(string uid)
        {
            this.uid = uid;
        }
    }
}