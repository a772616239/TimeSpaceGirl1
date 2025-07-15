using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace GameCore
{
    /// <summary>
    /// 切换场景不销毁
    /// </summary>
    public class DontDestroyOnLoad : MonoBehaviour
    {
        private void Awake()
        {
            DontDestroyOnLoad(this.gameObject);
        }
    }
}

