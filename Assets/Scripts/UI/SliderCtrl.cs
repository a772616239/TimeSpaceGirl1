using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using GameCore;
namespace GameLogic
{
    public class SliderCtrl : MonoBehaviour
    {
        [SerializeField] Slider slider;
        [SerializeField] Text progress;
        float cur;
        /// <summary>
        /// 更新slider
        /// </summary>
        /// <param name="cur">Current.</param>
        /// <param name="max">Max.</param>
        public void UpdateValue(int cur, int max)
        {
            this.cur = 1f * cur / max;
        }

        /// <summary>
        /// 更新slider
        /// </summary>
        /// <param name="value">Value.</param>
        public void UpdateValue(float value)
        {
            this.cur = value;
        }

        /// <summary>
        /// 强制设置slider
        /// </summary>
        /// <param name="value">Value.</param>
        public void SetValue(float value)
        {
            this.cur = value;
            this.slider.value = value;
            this.progress.text = Mathf.Floor(value * 100) + "%";
        }


        void Update()
        {
            if (Mathf.Abs(slider.value - cur) < 0.005)
                return;
            slider.value = Mathf.Lerp(slider.value, cur, Time.deltaTime * 5);
        }
    }
}

