using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using GameCore;
namespace GameLogic {
    /// <summary>
    /// UI深度适应
    /// </summary>
    [RequireComponent(typeof(Canvas))]
    [RequireComponent(typeof(GraphicRaycaster))]
    public class UIDepthAdapter : MonoBehaviour
    {
        /// <summary>
        /// 目标画布
        /// </summary>
        [SerializeField]
        Canvas targetCanvas;
        /// <summary>
        /// 自身画布相对于目标画布的偏移值
        /// </summary>
        [SerializeField]
        int offset;
        /// <summary>
        /// 自身画布
        /// </summary>
        Canvas canvas;
        /// <summary>
        /// 射线发射器
        /// </summary>
        GraphicRaycaster graphicRaycaster;
        private void Awake()
        {
            canvas = this.gameObject.AddMissingComponent<Canvas>();
            graphicRaycaster = this.gameObject.AddMissingComponent<GraphicRaycaster>();

        }

        private void Start()
        {
            if (targetCanvas == null && this.transform.parent != null)
                targetCanvas = this.transform.parent.gameObject.GetComponentInParent<Canvas>();
        }

        private void Update()
        {
            if (canvas && targetCanvas)
            {
                int targetDepth = targetCanvas.sortingOrder + offset;
                canvas.overrideSorting = true;
                if (canvas.sortingOrder != targetDepth)
                {
                    canvas.sortingOrder = targetDepth;
                }
            }
        }
    }

}
