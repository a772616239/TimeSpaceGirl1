using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEngine;

namespace GameLogic
{
    public static class GameExtension
    {
        public static T AddMissingComponent<T>(this GameObject gameObj) where T : Component
        { 
            T t = gameObj.GetComponent<T>();
            if (t == null) t = gameObj.AddComponent<T>();
            return t;
        }
    }
}
