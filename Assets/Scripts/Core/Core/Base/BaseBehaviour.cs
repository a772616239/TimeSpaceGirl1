using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace GameCore
{
    /// <summary>
    /// Mono基类
    /// </summary>
    public class BaseBehaviour : MonoBehaviour
    {
        protected virtual void Awake(){}
        protected virtual void Start(){}
        protected virtual void OnEnable(){}
        protected virtual void OnDisable(){}
        protected virtual void OnDestroy(){}
    }
}

