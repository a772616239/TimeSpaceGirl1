﻿using System;
using System.Collections.Generic;
namespace UnityEngine.UI.Extensions
{
    //An outline that looks a bit nicer than the default one. It has less "holes" in the outline by drawing more copies of the effect
    [AddComponentMenu("UI/Effects/Extensions/Nicer Outline")]
    public class NicerOutline : BaseMeshEffect
    {
        [SerializeField]
        private Color m_EffectColor = new Color(0f, 0f, 0f, 0.5f);

        [SerializeField]
        private Vector2 m_EffectDistance = new Vector2(1f, -1f);

        [SerializeField]
        private bool m_UseGraphicAlpha = true;
        //
        // Properties
        //
        public Color effectColor
        {
            get
            {
                return this.m_EffectColor;
            }
            set
            {
                this.m_EffectColor = value;
                if (base.graphic != null)
                {
                    base.graphic.SetVerticesDirty();
                }
            }
        }

        public Vector2 effectDistance
        {
            get
            {
                return this.m_EffectDistance;
            }
            set
            {
                if (value.x > 600f)
                {
                    value.x = 600f;
                }
                if (value.x < -600f)
                {
                    value.x = -600f;
                }
                if (value.y > 600f)
                {
                    value.y = 600f;
                }
                if (value.y < -600f)
                {
                    value.y = -600f;
                }
                if (this.m_EffectDistance == value)
                {
                    return;
                }
                this.m_EffectDistance = value;
                if (base.graphic != null)
                {
                    base.graphic.SetVerticesDirty();
                }
            }
        }

        public bool useGraphicAlpha
        {
            get
            {
                return this.m_UseGraphicAlpha;
            }
            set
            {
                this.m_UseGraphicAlpha = value;
                if (base.graphic != null)
                {
                    base.graphic.SetVerticesDirty();
                }
            }
        }


        //
        // Methods
        //
        protected void ApplyShadow(List<UIVertex> verts, Color32 color, int start, int end, float x, float y)
        {
            //Debug.Log("verts count: "+verts.Count);
            int num = verts.Count * 2;
            if (verts.Capacity < num)
            {
                verts.Capacity = num;
            }
            for (int i = start; i < end; i++)
            {
                UIVertex uIVertex = verts[i];
                verts.Add(uIVertex);

                Vector3 position = uIVertex.position;
                //Debug.Log("vertex pos: "+position);
                position.x += x;
                position.y += y;
                uIVertex.position = position;
                Color32 color2 = color;
                if (this.m_UseGraphicAlpha)
                {
                    color2.a = (byte)(color2.a * verts[i].color.a / 255);
                }
                uIVertex.color = color2;
                //uIVertex.color = (Color32)Color.blue;
                verts[i] = uIVertex;
            }
        }

        public override void ModifyMesh(/*List<UIVertex> verts*/ Mesh mesh)
        {
            if (!this.IsActive())
            {
                return;
            }
            // 从mesh 得到 顶点集
            List<UIVertex> verts = new List<UIVertex>();
            using (VertexHelper vertexHelper = new VertexHelper(mesh))
            {
                vertexHelper.GetUIVertexStream(verts);
            }

            Text foundtext = GetComponent<Text>();

            float best_fit_adjustment = 1f;

            if (foundtext && foundtext.resizeTextForBestFit)
            {
                best_fit_adjustment = (float)foundtext.cachedTextGenerator.fontSizeUsedForBestFit / (foundtext.resizeTextMaxSize - 1); //max size seems to be exclusive 

            }

            float distanceX = this.effectDistance.x * best_fit_adjustment;
            float distanceY = this.effectDistance.y * best_fit_adjustment;

            int start = 0;
            int count = verts.Count;
            this.ApplyShadow(verts, this.effectColor, start, verts.Count, distanceX, distanceY);
            start = count;
            count = verts.Count;
            this.ApplyShadow(verts, this.effectColor, start, verts.Count, distanceX, -distanceY);
            start = count;
            count = verts.Count;
            this.ApplyShadow(verts, this.effectColor, start, verts.Count, -distanceX, distanceY);
            start = count;
            count = verts.Count;
            this.ApplyShadow(verts, this.effectColor, start, verts.Count, -distanceX, -distanceY);

            start = count;
            count = verts.Count;
            this.ApplyShadow(verts, this.effectColor, start, verts.Count, distanceX, 0);
            start = count;
            count = verts.Count;
            this.ApplyShadow(verts, this.effectColor, start, verts.Count, -distanceX, 0);

            start = count;
            count = verts.Count;
            this.ApplyShadow(verts, this.effectColor, start, verts.Count, 0, distanceY);
            start = count;
            count = verts.Count;
            this.ApplyShadow(verts, this.effectColor, start, verts.Count, 0, -distanceY);

            // 在合成mesh
            using (VertexHelper vertexHelper2 = new VertexHelper())
            {
                vertexHelper2.AddUIVertexTriangleStream(verts);
                vertexHelper2.FillMesh(mesh);
            }
        }

        protected override void Awake()
        {
            this.effectDistance = this.m_EffectDistance;
            base.Awake();
        }


        public override void ModifyMesh(VertexHelper vh)
        {
            throw new NotImplementedException();
        }
    }
}