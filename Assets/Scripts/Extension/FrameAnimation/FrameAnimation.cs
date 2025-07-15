using System;
using UnityEngine;

namespace UnrealM
{
    public interface IFrameUpdater
    {
        void OnFrame(int frame);
        void OnComplete();
    }

    [Serializable]
    public class FrameAnimation
    {
        public enum LoopType
        {
            Once,
            Loop,
            PingPong,
        };

        public enum PlayOrder
        {
            Forward,
            Backwards
        };

        public float FPS = 30;

        public LoopType loopType = LoopType.Once;

        public PlayOrder playOrder = PlayOrder.Forward;

        [NonSerialized]
        public int nLength = 0;
        [NonSerialized]
        public int nBegin = 0;
        [NonSerialized]
        public int nEnd   = 0;

        private int nSign = 1;

        public IFrameUpdater iFrameUpdater;


        private Action<FrameAnimation> loopTypeFun;

        //private ActionSequence timer;

        private float time = 0;


        public int nCurFrame { get; private set; }
        public bool isPlaying { get; private set; }
        public int nStartFrame { get; private set; }

        public void Stop()
        {
            isPlaying = false;

            //if (timer != null)
            //{
            //    timer.Stop();
            //}
        }

        public void Play()
        {
            //Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW Play");
            Stop();
            if (nLength <= 0)
            {
                return;
            }

            if (playOrder == PlayOrder.Forward)
            {
                nStartFrame = 0;
                nSign = 1;
            }
            else
            {
                nStartFrame = nLength - 1;
                nSign = -1;
            }

            switch (loopType)
            {
                case LoopType.Once:
                    loopTypeFun = UpdateFrameFuncOnce;
                    break;
                case LoopType.Loop:
                    loopTypeFun = UpdateFrameFuncLoop;
                    break;
                case LoopType.PingPong:
                    loopTypeFun = UpdateFrameFuncPingPong;
                    break;
                default:
                    break;
            }

            //float interval = 1/FPS;
            nCurFrame = nStartFrame;
            isPlaying = true;
            time = 0;
            //Debug.Log("nCurFrame " + nCurFrame);
            //timer = ActionSequenceSystem.Looper(interval, -1, false, UpdateFrame);
        }

        public void PlayClamp(int beginFrame, int endFrame)
        {
            //Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW PlayClamp " + beginFrame + "_" + endFrame);
            Stop();
            if (nLength <= 0)
            {
                Debug.LogError("nLength <= 0");
                return;
            }
            if (beginFrame < 0 || beginFrame > nLength || endFrame < 0 || endFrame > nLength)
            {
                Debug.LogError("beginFrame or endFrame Error!!!");
                return;
            }

            if (endFrame - beginFrame >= 0)
            {
                nSign = 1;
            }
            else
            {
                nSign = -1;
            }
            nBegin = beginFrame;
            nEnd = endFrame;

            loopTypeFun = UpdateFrameFuncClamp;

            //float interval = 1 / FPS;
            nCurFrame = nBegin;
            isPlaying = true;
            time = 0;

            //timer = ActionSequenceSystem.Looper(interval, -1, false, UpdateFrame);
        }

        public void UpdateFrame()
        {
            if (!isPlaying)
                return;

            if (FPS == 0)
            {
                FPS = 30;
            }
            float interval = 1 / FPS;
            time += Time.deltaTime;
            if (time > interval)
            {
                int frames = (int)(time / interval);
                for(int i = 0; i < frames; i++)
                {

                    if (!isPlaying)
                        return;

                    if (iFrameUpdater != null)
                    {
                        iFrameUpdater.OnFrame(nCurFrame);
                    }

                    nCurFrame += nSign;
                    loopTypeFun(this);
                }
                time = time - frames * interval;
            }
            
        }

        #region
        private static void UpdateFrameFuncLoop(FrameAnimation frameAnimation)
        {
            //Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW Loop ##");
            if (frameAnimation.nCurFrame >= frameAnimation.nLength || frameAnimation.nCurFrame < 0)
            {
                //Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW Loop ## finish");
                frameAnimation.nCurFrame = frameAnimation.nStartFrame;
            }
        }

        private static void UpdateFrameFuncOnce(FrameAnimation frameAnimation)
        {
            //Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW Once ##");
            if (frameAnimation.nCurFrame >= frameAnimation.nLength || frameAnimation.nCurFrame < 0)
            {
                //Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW Once ## finish");
                frameAnimation.Stop();
                if (frameAnimation.iFrameUpdater != null)
                {
                    frameAnimation.iFrameUpdater.OnComplete();
                }
            }
        }

        private static void UpdateFrameFuncPingPong(FrameAnimation frameAnimation)
        {
            if (frameAnimation.nSign == 1)
            {
                if (frameAnimation.nCurFrame >= frameAnimation.nLength)
                {
                    frameAnimation.nSign = -1;
                    frameAnimation.nCurFrame -= 2;
                }
            }
            else
            {
                if (frameAnimation.nCurFrame < 0)
                {
                    frameAnimation.nSign = 1;
                    frameAnimation.nCurFrame += 2;
                }
            }
        }

        private static void UpdateFrameFuncClamp(FrameAnimation frameAnimation)
        {
            //Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW Clamp ##");
            if ((frameAnimation.nSign > 0 && frameAnimation.nCurFrame > frameAnimation.nEnd) || (frameAnimation.nSign < 0 && frameAnimation.nCurFrame < frameAnimation.nEnd))
            {
                //Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW Clamp ## finish");
                frameAnimation.Stop();
                if (frameAnimation.iFrameUpdater != null)
                {
                    frameAnimation.iFrameUpdater.OnComplete();
                }
            }
        }
        #endregion
    }
}