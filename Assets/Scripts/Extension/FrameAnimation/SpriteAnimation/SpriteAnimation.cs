using System;
using UnityEngine;

namespace UnrealM
{
    public abstract class SpriteAnimation : MonoBehaviour, IFrameUpdater
    {
        public FrameAnimation frameAnimation = new FrameAnimation();

        public bool autoPlay = false;

        [HideInInspector]
        public bool isHiddenAtAwake;

        
        public enum EndMode
        {
            DoNothing,
            Hide,
            Destory,
            DisplayFirstFrame
        };

        public EndMode endMode;
        public Action onComplete;

        [HideInInspector]
        public int nCurClipIndex = 0;

        public SpriteAnimationClip clips;

        public bool isPlaying { get { return frameAnimation.isPlaying; } }
        protected Sprite[] curSprites { get { return clips[nCurClipIndex].sprites; } }

        private void OnEnable()
        {
            if (autoPlay)
            {
                Play();
            }
        }

        private void OnDisable()
        {
            //Debug.LogError("sprite animation OnDisable stop");
            //Stop();
        }

        public void Stop()
        {
            frameAnimation.Stop();
        }

        public void Update()
        {
            //Debug.LogError(string.Format("SpriteAnimation Update {0}    {1}", curSprites[0].name, frameAnimation.isPlaying));
            frameAnimation.UpdateFrame();
        }

        void FixedUpdate()
        {
            //Debug.Log("fixupdate" + Time.fixedDeltaTime);
        }

        public void Play(int nClipIndex)
        {
            nCurClipIndex = nClipIndex;
            Play();
        }

        public void Play()
        {
            frameAnimation.iFrameUpdater = this;
            frameAnimation.Stop();
            frameAnimation.nLength = curSprites.Length;
            frameAnimation.Play();
        }

        public void PlayClamp(int beginFrame, int endFrame)
        {
            frameAnimation.iFrameUpdater = this;
            frameAnimation.Stop();
            frameAnimation.nLength = curSprites.Length;
            frameAnimation.PlayClamp(beginFrame, endFrame);
        }

        public abstract void OnFrame(int nCurFrame);

        public void OnComplete()
        {
            switch (endMode)
            {
                case EndMode.Hide:
                    gameObject.SetActive(false);
                    break;
                case EndMode.Destory:
                    Destroy(gameObject);
                    break;
                case EndMode.DisplayFirstFrame:
                    OnFrame(frameAnimation.nStartFrame);
                    break;
                case EndMode.DoNothing:
                default:
                    break;
            }

            if (onComplete != null)
            {
                onComplete();
            }
        }

        private void OnDestroy()
        {
            Stop();
        }
    }
}