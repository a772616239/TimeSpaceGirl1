using System.Collections.Generic;

namespace UnityEngine.UI
{
    /// <summary>
    /// 描边和阴影
    /// 复制的原Outline代码和Shadow,因为目前游戏就是需要这种文字描边,总比分别加描边和加阴影要省一些
    /// </summary>
    public class OutlineAndShadow : BaseMeshEffect
    {
        private static List<UIVertex> tempUIVertexList = new List<UIVertex>(2048);

        [SerializeField]
        private Color m_OutlineColor = new Color32(0, 0, 0, 255);

        [SerializeField]
        private Vector2 m_OutlineDistance = new Vector2(0.5f, .5f);

        [SerializeField]
        private Color m_ShadowColor = new Color32(0, 0, 0, 205);

        [SerializeField]
        private Vector2 m_ShadowDistance = new Vector2(0, -1);

        [SerializeField]
        private bool m_UseGraphicAlpha = true;

        private const float kMaxEffectDistance = 600f;

#if UNITY_EDITOR
        protected override void OnValidate()
        {
            outlineDistance = m_OutlineDistance;
            base.OnValidate();
        }

#endif

        public Color outlineColor
        {
            get { return m_OutlineColor; }
            set
            {
                m_OutlineColor = value;
                if (graphic != null)
                    graphic.SetVerticesDirty();
            }
        }

        public Vector2 outlineDistance
        {
            get { return m_OutlineDistance; }
            set
            {
                if (value.x > kMaxEffectDistance)
                    value.x = kMaxEffectDistance;
                if (value.x < -kMaxEffectDistance)
                    value.x = -kMaxEffectDistance;

                if (value.y > kMaxEffectDistance)
                    value.y = kMaxEffectDistance;
                if (value.y < -kMaxEffectDistance)
                    value.y = -kMaxEffectDistance;

                if (m_OutlineDistance == value)
                    return;

                m_OutlineDistance = value;

                if (graphic != null)
                    graphic.SetVerticesDirty();
            }
        }

        public Color shadowColor
        {
            get { return m_ShadowColor; }
            set
            {
                m_ShadowColor = value;
                if (graphic != null)
                    graphic.SetVerticesDirty();
            }
        }

        public Vector2 shadowDistance
        {
            get { return m_ShadowDistance; }
            set
            {
                if (value.x > kMaxEffectDistance)
                    value.x = kMaxEffectDistance;
                if (value.x < -kMaxEffectDistance)
                    value.x = -kMaxEffectDistance;

                if (value.y > kMaxEffectDistance)
                    value.y = kMaxEffectDistance;
                if (value.y < -kMaxEffectDistance)
                    value.y = -kMaxEffectDistance;

                if (m_ShadowDistance == value)
                    return;

                m_ShadowDistance = value;

                if (graphic != null)
                    graphic.SetVerticesDirty();
            }
        }
        
        public bool useGraphicAlpha
        {
            get { return m_UseGraphicAlpha; }
            set
            {
                m_UseGraphicAlpha = value;
                if (graphic != null)
                    graphic.SetVerticesDirty();
            }
        }

        protected OutlineAndShadow()
        {
        }

        //该继承相当于增加描绘
        public override void ModifyMesh(VertexHelper vh)
        {
            if (!IsActive())
                return;

            var verts = tempUIVertexList;
            vh.GetUIVertexStream(verts);

            var neededCpacity = verts.Count * 6;
            if (verts.Capacity < neededCpacity)
                verts.Capacity = neededCpacity;

            //描边
            var start = 0;
            var end = verts.Count;
            ApplyShadowZeroAlloc(verts, outlineColor, start, verts.Count, outlineDistance.x, outlineDistance.y);

            start = end;
            end = verts.Count;
            ApplyShadowZeroAlloc(verts, outlineColor, start, verts.Count, outlineDistance.x, -outlineDistance.y);

            start = end;
            end = verts.Count;
            ApplyShadowZeroAlloc(verts, outlineColor, start, verts.Count, -outlineDistance.x, outlineDistance.y);

            start = end;
            end = verts.Count;
            ApplyShadowZeroAlloc(verts, outlineColor, start, verts.Count, -outlineDistance.x, -outlineDistance.y);

            //阴影
            start = end;
            end = verts.Count;
            ApplyShadowZeroAlloc(verts, shadowColor, start, verts.Count, shadowDistance.x, shadowDistance.y);

            vh.Clear();
            vh.AddUIVertexTriangleStream(verts);
        }

        #region Shadow类的代码

        protected void ApplyShadowZeroAlloc(List<UIVertex> verts, Color32 color, int start, int end, float x, float y)
        {
            UIVertex vt;

            var neededCpacity = verts.Count * 2;
            if (verts.Capacity < neededCpacity)
                verts.Capacity = neededCpacity;

            for (int i = start; i < end; ++i)
            {
                vt = verts[i];
                verts.Add(vt);

                Vector3 v = vt.position;
                v.x += x;
                v.y += y;
                vt.position = v;
                var newColor = color;
                if (m_UseGraphicAlpha)
                    newColor.a = (byte)((newColor.a * verts[i].color.a) / 255);
                vt.color = newColor;
                verts[i] = vt;
            }
        }

        #endregion
    }
}