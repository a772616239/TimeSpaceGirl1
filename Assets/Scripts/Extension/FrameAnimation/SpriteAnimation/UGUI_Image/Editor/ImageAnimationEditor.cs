using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace UnrealM
{
    [CustomEditor(typeof(ImageAnimation), true)]
    [CanEditMultipleObjects]
    public class ImageAnimationEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            //if (targets.Length == 1)
            //{
            //    if (GUILayout.Button("Find/Create Clip By Image.sprite"))
            //    {
            //        ImageAnimation s = target as ImageAnimation;
            //        Image image = s.GetComponent<Image>();
            //        if (!image)
            //        {
            //            Debug.LogWarning("Image if null");
            //            return;
            //        }

            //        if (!image.sprite)
            //        {
            //            Debug.LogWarning("Image.sprite if null");
            //            return;
            //        }

            //        SpriteAnimationClip.CreateSpriteAnimationClip(s, image.sprite);
            //    }
            //}

            if (GUILayout.Button("Setup First Frame"))
            {
                for (int i = 0; i < targets.Length; i++)
                {
                    ImageAnimation s = targets[i] as ImageAnimation;
                    s.image = s.GetComponent<Image>();
                    if (s.image)
                    {
                        Undo.RecordObject(s.image, "Setup First Frame");
                        s.image.sprite = s.clips[0].sprites[0];
                        s.image.SetNativeSize();
                    }
                }
            }

            base.OnInspectorGUI();
        }
    }
}