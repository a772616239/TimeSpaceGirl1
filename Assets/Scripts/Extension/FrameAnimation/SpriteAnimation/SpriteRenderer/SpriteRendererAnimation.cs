using UnityEngine;

namespace UnrealM
{
    public class SpriteRendererAnimation : SpriteAnimation
    {
        public SpriteRenderer spriteRenderer;

        private void Awake()
        {
            spriteRenderer = GetComponent<SpriteRenderer>();
            spriteRenderer.enabled = !isHiddenAtAwake;
        }

        public override void OnFrame(int nCurFrame)
        {
            spriteRenderer.sprite = curSprites[nCurFrame];
        }
    }
}