﻿using UnityEngine;
namespace GameCore {
    public abstract class Singleton<T> where T : class, new()
    {
        private static T _instance;
        private static object _lock = new object();

        public static T Instance
        {
            get
            {
                if (_instance == null)
                {
                    lock (_lock)
                    {
                        if (_instance == null)
                        {
                            _instance = new T();
                        }
                    }     
                }
                return _instance;
            }
        }
    }


    public class UnitySingleton<T> : MonoBehaviour where T : MonoBehaviour
    {
        private static T _instance;

        public static T Instance
        {
            get
            {
                if (_instance == null)
                {
                    if ((_instance = Object.FindObjectOfType<T>()) == null)
                    {
                        GameObject go = new GameObject(typeof(T).ToString());
                        _instance = go.AddComponent<T>();
                    }
                    if (Application.isPlaying) UnityEngine.Object.DontDestroyOnLoad(_instance.gameObject);
                }

                return _instance;
            }
        }
    }




}
