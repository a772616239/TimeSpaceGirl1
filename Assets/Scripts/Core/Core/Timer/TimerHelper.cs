using System;
using UnityEngine;
using System.Collections.Generic;
namespace GameCore {
    /**
 * 时间器管理器
 */
    public class TimerManager : UnitySingleton<TimerManager>
    {
        /* static fields */

        /* fields */
        /** 定时器列表 */
        Entity header = new Entity();
        /** 定时器缓存列表 */
        Entity cache;

        /* methods */
        /** 更新 */
        private void FixedUpdate()
        {
            Entity entity = this.header;
            Entity next = entity.next;
            if (next == null) return;
            float nowTime = Time.unscaledTime;
            Action action = null;
            UnityEngine.Object unityObj = null; ;
            while (next != null)
            {
                if (next.nextTime < nowTime)
                {
                    action = next.action;
                    unityObj = action.Target as UnityEngine.Object;
                    //判断脚本销毁
                    if (unityObj == null && !object.ReferenceEquals(unityObj, null))
                    {
                        entity.next = next.next;
                        pushEntity(next);
                        next = entity.next;
                        continue;
                    }
                    else
                    {
                        action.Invoke();
                        if (next.once)
                        {
                            entity.next = next.next;
                            pushEntity(next);
                            next = entity.next;
                            continue;
                        }
                    }
                    next.nextTime += next.intervalTime;
                }
                entity = entity.next;
                next = entity.next;
            }
        }
        /** 开始定时器 */
        public void OnTimeInvoke(float intervalTime, Action action, bool firstCall, bool once)
        {
#if UNITY_EDITOR
            Entity entity = this.header.next;
            while (entity != null)
            {
                if (entity.action == action)
                {
                    Debug.LogError(this + ",the same action add,target=" + action.Target + ",method=" + action.Method);
                    break;
                }
                entity = entity.next;
            }
#endif
            Entity newEntity = createEntity();
            newEntity.action = action;
            newEntity.intervalTime = intervalTime;
            newEntity.once = once;
            if (firstCall)
                newEntity.nextTime = Time.unscaledTime;
            else
                newEntity.nextTime = Time.unscaledTime + intervalTime;

            newEntity.next = header.next;
            header.next = newEntity;
        }
        /** 停止执行 */
        public void OnStopInvoke(Action action)
        {
            Entity entity = this.header;
            Entity next = entity.next;
            while (next != null)
            {
                if (next.action == action)
                {
                    entity.next = next.next;
                    pushEntity(next);
                    next = entity.next;
                    break;
                }
                entity = entity.next;
                next = entity.next;
            }
        }
        /** 创建实体 */
        private Entity createEntity()
        {
            Entity entity = null;
            if (cache != null)
            {
                entity = cache;
                cache = entity.next;
                entity.next = null;
                return entity;
            }
            return new Entity();
        }
        /** 实体回收 */
        private void pushEntity(Entity entity)
        {
            entity.action = null;
            entity.next = cache;
            cache = entity;
        }

        /* inner class */
        /** 实体 */
        class Entity
        {
            /* fields */
            /** 回调 */
            public Action action;
            /** 间隔时间 */
            public float intervalTime;
            /** 下一次时间 */
            public float nextTime;
            /** 是否只调用一次 */
            public bool once;

            /** 下一个实体 */
            public Entity next;
        }
    }
}
