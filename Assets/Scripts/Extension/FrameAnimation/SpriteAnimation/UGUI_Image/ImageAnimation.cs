using System.Diagnostics;
using UnityEngine.UI;
using UnityEngine;

namespace UnrealM
{
    public class ImageAnimation : SpriteAnimation
    {
        public Image image;

        private void Awake()
        {
            image.enabled = !isHiddenAtAwake;
        }

        public override void OnFrame(int nCurFrame)
        {
            image.sprite = curSprites[nCurFrame];
            image.SetNativeSize();
            float pivotX = image.sprite.pivot.x / image.sprite.rect.width;
            float pivotY = image.sprite.pivot.y / image.sprite.rect.height;
            image.rectTransform.pivot = new Vector2(pivotX, pivotY);
            //UnityEngine.Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW OnFrame " + image.sprite.name);
        }

        public void ResetFrame(int nFrame = 6)
        {
            image.sprite = curSprites[nFrame];
            //UnityEngine.Debug.Log("WWWWWWWWWWWWWWWWWWWWWWWWWWW ResetFrame " + image.sprite.name);
        }

#if UNITY_EDITOR
        private void Reset()
        {
            //image = GetComponent<Image>();
            //if (image.sprite)
            //{
            //    SpriteAnimationClip.CreateSpriteAnimationClip(this, image.sprite);
            //    if (clips.Length > 0)
            //    {
            //        if (clips.clips[0].sprites.Length < 3)
            //        {
            //            frameAnimation.FPS = 3;
            //        }
            //    }
            //}
        }
#endif
    }
}