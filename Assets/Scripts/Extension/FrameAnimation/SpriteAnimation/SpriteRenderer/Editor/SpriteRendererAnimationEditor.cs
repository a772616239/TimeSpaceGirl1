using UnityEditor;
using UnityEngine;

namespace UnrealM
{
    [CustomEditor(typeof(SpriteRendererAnimation), true)]
    [CanEditMultipleObjects]
    public class SpriteRendererAnimationEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            if (targets.Length == 1)
            {
                if (GUILayout.Button("Find/Create Clip By SpriteRenderer.sprite"))
                {
                    SpriteRendererAnimation s = target as SpriteRendererAnimation;
                    SpriteRenderer spriteRenderer = s.GetComponent<SpriteRenderer>();
                    s.spriteRenderer = spriteRenderer;
                    if (!spriteRenderer)
                    {
                        Debug.LogWarning("SpriteRenderer if null");
                        return;
                    }

                    if (!spriteRenderer.sprite)
                    {
                        Debug.LogWarning("SpriteRenderer.sprite if null");
                        return;
                    }

                    SpriteAnimationClip.CreateSpriteAnimationClip(s, spriteRenderer.sprite);
                }
            }

            if (GUILayout.Button("Setup First Frame"))
            {
                for (int i = 0; i < targets.Length; i++)
                {
                    SpriteRendererAnimation s = targets[i] as SpriteRendererAnimation;
                    s.spriteRenderer = s.GetComponent<SpriteRenderer>();
                    if (s.spriteRenderer)
                    {
                        s.spriteRenderer.sprite = s.clips[0].sprites[0];
                    }
                }
            }

            base.OnInspectorGUI();
        }
    }
}