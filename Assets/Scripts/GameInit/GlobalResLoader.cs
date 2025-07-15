using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using GameCore;
using Object = UnityEngine.Object;

namespace GameLogic
{
    /// <summary>
    /// 全局资源加载器
    /// </summary>
    public class GlobalResLoader
    {

        List<Object> list = new List<Object>();
        /// <summary>
        /// 加载完成回调
        /// </summary>
        Action action;
        /// <summary>
        /// 加载完成数量
        /// </summary>
        int finishCount;
        /// <summary>
        /// 所有数量
        /// </summary>
        int totalCount;
        /// <summary>
        /// 加载全局资源
        /// </summary>
        public void LoadGlobalRes(Action action) {
            this.action = action;
            App.ResMgr.Initialize(AppConst.bundleMode);
            StringArrayConfig config = App.ResMgr.LoadAsset<StringArrayConfig>("InitResConfig");
            App.ResMgr.UnLoadAsset(config.name);
            totalCount = config.Configs.Length;
            for (int i = 0; i < config.Configs.Length; i++)
            {
                App.ResMgr.LoadAssetAsync(config.Configs[i],LoadOneFinish);
            }
        }

        public void UnLoadAll() {
            for(int i=0;i<list.Count;i++){
                if (list[i] == null) continue;
                App.ResMgr.UnLoadAsset(list[i].name);
            }
            list.Clear();
        }

        /// <summary>
        /// 详细的进度
        /// </summary>
        public float Progress {
            get {
                if (totalCount == 0) return 1f;
                return finishCount / totalCount;
            }
        }

        /// <summary>
        /// 是否加载完成
        /// </summary>
        public bool IsLoadFinish {
            get {
                return finishCount == totalCount;
            }
        }

        /// <summary>
        /// 加载完成回调
        /// </summary>
        /// <param name="loader"></param>
        private void LoadOneFinish(string name,Object asset) {
            list.Add(asset);
            finishCount++;
            if (IsLoadFinish&&action!=null) {
                action();
                action = null;
            }
        }
    }
}

