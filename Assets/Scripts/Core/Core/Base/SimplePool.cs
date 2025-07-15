using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
namespace GameCore
{
    /// <summary>
    /// 简单的池子
    /// </summary>
    public class SimplePool
    {
        /// <summary>
        /// 获取一个回调
        /// </summary>
        public Action<GameObject> OnGetOne;
        /// <summary>
        /// 回收一个回调
        /// </summary>
        public Action<GameObject> OnCollectOne;
        /// <summary>
        /// 预制体
        /// </summary>
        GameObject prefab;
        /// <summary>
        /// 正在使用的列表
        /// </summary>
        List<GameObject> useList = new List<GameObject>();
        /// <summary>
        /// 未使用列表
        /// </summary>
        List<GameObject> unUseList = new List<GameObject>();
        public SimplePool(GameObject prefab)
        {
            this.prefab = prefab;
            if (prefab == null)
                 BaseLogger.LogError((object)"Prefab is null!");
        }
        /// <summary>
        /// 获取一个
        /// </summary>
        /// <param name="active"></param>
        /// <returns></returns>
        public GameObject GetOne(bool active = true)
        {
            GameObject gameObj = null;
            if (unUseList.Count > 0)
            {
                gameObj = unUseList[0];
                unUseList.RemoveAt(0);
            }
            else
            {
                gameObj = GameObject.Instantiate(prefab);
            }
            useList.Add(gameObj);
            gameObj.SetActive(active);
            if (OnGetOne != null)
                OnGetOne(gameObj);
            return gameObj;
        }

        public List<GameObject> UseList
        {
            get { return useList; }
        }

        public T GetOne<T>(bool active = true) where T : MonoBehaviour
        {
            return GetOne(active).GetComponent<T>();
        }
        /// <summary>
        /// 回收一个
        /// </summary>
        /// <param name="gameObj"></param>
        /// <param name="isActive"></param>
        public void CollectOne(GameObject gameObj, bool isActive = false)
        {
            useList.Remove(gameObj);
            unUseList.Add(gameObj);
            gameObj.SetActive(false);
            if (OnCollectOne != null)
                OnCollectOne(gameObj);
        }

        /// <summary>
        /// 回收所有物体
        /// </summary>
        /// <param name="isActive"></param>
        public void CollectAll(bool isActive = false)
        {
            while (useList.Count > 0)
            {
                CollectOne(useList[0], isActive);
            }
        }

        /// <summary>
        /// 隐藏所有不用的
        /// </summary>
        public void HideAllUnUse()
        {
            for (int i = 0; i < unUseList.Count; i++)
            {
                unUseList[i].gameObject.SetActive(false);
            }
        }


        public void Dispose()
        {
            prefab = null;
            for (int i = 0; i < useList.Count; i++)
            {
                GameObject.Destroy(useList[i]);
            }
            useList.Clear();
            for (int i = 0; i < unUseList.Count; i++)
            {
                GameObject.Destroy(unUseList[i]);
            }
            unUseList.Clear();
        }
    }

}

