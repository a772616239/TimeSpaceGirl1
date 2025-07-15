using System.Collections;
using System.Collections.Generic;
using System;
using System.Threading;

namespace GameCore {
    /// <summary>
    /// 线程管理器
    /// </summary>
    public class ThreadManager : UnitySingleton<ThreadManager>
    {
        /// <summary>
        /// 最大线程数量
        /// </summary>
        public static int maxThreads = 8;
        /// <summary>
        /// 当前线程数量
        /// </summary>
        int numThreads;
        /// <summary>
        /// 等待回调列表
        /// </summary>
        List<Action> actions = new List<Action>();
        /// <summary>
        /// 当前回调列表
        /// </summary>
        List<Action> currentActions = new List<Action>();

        /// <summary>
        /// 主线程回调
        /// </summary>
        /// <param name="action"></param>
        public void QueueOnMainThread(Action action)
        {
            lock (actions)
            {
                actions.Add(action);
            }
        }

        /// <summary>
        /// 分线程异步工作
        /// </summary>
        /// <param name="a"></param>
        /// <returns></returns>
        public void RunAsync(Action a)
        {
            while (numThreads >= maxThreads)
            {
                Thread.Sleep(1);
            }
            Interlocked.Increment(ref numThreads);
            ThreadPool.QueueUserWorkItem(RunAction, a);
        }

        private void RunAction(object action)
        {
            try
            {
                ((Action)action)();
            }
            catch
            {
            }
            finally
            {
                Interlocked.Decrement(ref numThreads);
            }
        }

        void Update()
        {
            lock (actions)
            {
                currentActions.Clear();
                currentActions.AddRange(actions);
                actions.Clear();
            }
            for(int i = 0; i < currentActions.Count; i++)
            {
                currentActions[i]();
            }
        }
    }

}
