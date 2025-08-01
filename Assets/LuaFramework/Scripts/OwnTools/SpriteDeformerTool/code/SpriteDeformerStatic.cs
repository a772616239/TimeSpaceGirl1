﻿using UnityEngine;
using System.Collections;
namespace Game.SpriteDeformerTools
{

    [ExecuteInEditMode]
    [AddComponentMenu("Sprite Deformer/Sprite deformer Static")]
    public class SpriteDeformerStatic : SpriteDeformerWithBaseOfMaterial
    {
        protected override void Awake()
        {
            base.Awake();
        }
        protected override void OnDestroy()
        {
            base.OnDestroy();
        }
        protected override void OnEnable()
        {
            base.OnEnable();
        }
        protected override void OnDisable()
        {
            base.OnDisable();
        }
        protected override void Update()
        {
            base.Update();
        }
    }
}
