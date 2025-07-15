using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using GameCore;
using System;

namespace GameLogic
{
    /// <summary>
    /// UI特效
    /// </summary>
    public class UIEffect : MonoBehaviour
    {
        /// <summary>
        /// 目标画布
        /// </summary>
        [SerializeField]
        protected Canvas canvas;
        /// <summary>
        /// 偏移值
        /// </summary>
        [SerializeField]
        protected int offset;
        /// <summary>
        /// 渲染器有序列表（SortingOrder排序）
        /// </summary>
        List<Renderer> list = new List<Renderer>();

        public Canvas Canvas
        {
            get
            {
                if (canvas == null)
                    canvas = this.transform.GetComponentInParent<Canvas>();
                return canvas;
            }
            set
            {
                canvas = value;
            }
        }


        private void Awake()
        {
            list.AddRange(GetComponentsInChildren<Renderer>());
            list.Sort(RendererCompare.Instance);
        }


        /// <summary>
        /// 设置特效的偏移值,保证特效内部偏移值正确
        /// </summary>
        /// <param name="offset"></param>
        public void SetOffset(int offset)
        {
            this.offset = offset;
        }



        private void Update()
        {
            if (Canvas)
            {
                int count = 0;
                int tmpOrder = int.MinValue;
                for (int i = 0; i < list.Count; i++)
                {
                    if (tmpOrder < list[i].sortingOrder)
                    {
                        tmpOrder = list[i].sortingOrder;
                        count++;
                    }
                    list[i].sortingOrder = Canvas.sortingOrder + offset + count;
                }
            }
        }
    }

    /// <summary>
    /// 渲染器比较工具
    /// </summary>
    public class RendererCompare : Singleton<RendererCompare>, IComparer<Renderer>
    {
        public int Compare(Renderer x, Renderer y)
        {
            if (x.sortingOrder > y.sortingOrder)
                return 1;
            else if (x.sortingOrder == y.sortingOrder)
                return 0;
            else
                return -1;
        }
    }
}

