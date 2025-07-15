
using System;
using System.Collections.Generic;

namespace UnityEngine.UI.Extensions
{
    [RequireComponent(typeof(RectTransform), typeof(Graphic)), DisallowMultipleComponent]
    [AddComponentMenu("UI/Effects/Extensions/Flippable")]
    public class UIFlippable : MonoBehaviour, IMeshModifier
    {
        [SerializeField]
        private bool m_Horizontal = false;
        [SerializeField]
        private bool m_Veritical = false;

        /// <summary>
        /// 获取或设置一个值，该值指示是否应水平翻转
        /// </summary>
        /// <value><c>true</c> if horizontal; otherwise, <c>false</c>.</value>
        public bool horizontal
        {
            get { return this.m_Horizontal; }
            set { this.m_Horizontal = value; }
        }

        /// <summary>
        /// 获取或设置一个值，该值指示是否应垂直翻转
        /// </summary>
        /// <value><c>true</c> if vertical; otherwise, <c>false</c>.</value>
        public bool vertical
        {
            get { return this.m_Veritical; }
            set { this.m_Veritical = value; }
        }

        protected void OnValidate()
        {
            this.GetComponent<Graphic>().SetVerticesDirty();
        }

        // 从mesh 得到 顶点集
        public void ModifyMesh(/*List<UIVertex> verts*/ Mesh mesh)
        {
            List<UIVertex> verts = new List<UIVertex>();
            using (VertexHelper vertexHelper = new VertexHelper(mesh))
            {
                vertexHelper.GetUIVertexStream(verts);
            }

            RectTransform rt = this.transform as RectTransform;

            for (int i = 0; i < verts.Count; ++i)
            {
                UIVertex v = verts[i];

                // Modify positions
                v.position = new Vector3(
                    (this.m_Horizontal ? (v.position.x + (rt.rect.center.x - v.position.x) * 2) : v.position.x),
                    (this.m_Veritical ? (v.position.y + (rt.rect.center.y - v.position.y) * 2) : v.position.y),
                    v.position.z
                );

                // Apply
                verts[i] = v;
            }

            // 在合成mesh
            using (VertexHelper vertexHelper2 = new VertexHelper())
            {
                vertexHelper2.AddUIVertexTriangleStream(verts);
                vertexHelper2.FillMesh(mesh);
            }
        }

        public void ModifyMesh(VertexHelper verts)
        {
            throw new NotImplementedException();
        }
    }
}