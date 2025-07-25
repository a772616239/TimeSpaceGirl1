﻿using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace GameLogic {

	[Serializable]
	public class PoolInfo {
		public string poolName;
		public GameObject prefab;
		public int poolSize;
		public bool fixedSize;
	}

	public class GameObjectPool 
    {
        private int maxSize;
		private int poolSize;
		private string poolName;
        private bool isAutoCreate;
        private Transform poolRoot;
        private GameObject poolObjectPrefab;
        private Stack<GameObject> availableObjStack = new Stack<GameObject>();

        public GameObjectPool(string poolName, GameObject poolObjectPrefab, int initCount,  Transform pool,bool isAutoCreate=true) {
			this.poolName = poolName;
			this.poolSize = initCount;
            this.poolRoot = pool;
            this.poolObjectPrefab = poolObjectPrefab;
            this.isAutoCreate = isAutoCreate;
			//populate the pool
			for(int index = 0; index < initCount; index++) 
            {
				AddObjectToPool(NewObjectInstance());
			}
		}

		//o(1)
        private void AddObjectToPool(GameObject go)
        {
			//add to pool
            go.SetActive(false);
            availableObjStack.Push(go);
            go.transform.SetParent(poolRoot, false);
		}

        private GameObject NewObjectInstance()
        {
            return GameObject.Instantiate(poolObjectPrefab) as GameObject;
		}

		public GameObject NextAvailableObject(bool isActive=false) {
            GameObject go = null;
			if(availableObjStack.Count > 0) 
            {
				go = availableObjStack.Pop();
			}
            else 
            {
                if (this.isAutoCreate)
                {
                    AddObjectToPool(NewObjectInstance());
                    if (availableObjStack.Count > 0)
                    {
                        go = availableObjStack.Pop();
                    }
                }
                else
                    Debug.LogError("No object available & cannot grow pool: " + poolName);
			}
   
            if (go != null)
                go.SetActive(isActive);
            return go;
		} 
		
		//o(1)
        public void ReturnObjectToPool(string pool, GameObject po) 
        {
            if (poolName.Equals(pool))
            {
                AddObjectToPool(po);
			}
            else 
            {
				Debug.LogError(string.Format("Trying to add object to incorrect pool {0} ", poolName));
			}
		}

        public void ClearGameObjectPool()
        {
            foreach (var obj in availableObjStack)
            {
                if (obj != null)
                    UnityEngine.Object.Destroy(obj);
            }
            availableObjStack.Clear();
        }
	}
}
