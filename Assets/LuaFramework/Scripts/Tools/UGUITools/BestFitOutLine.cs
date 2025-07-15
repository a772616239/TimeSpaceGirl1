using System.Collections.Generic;
namespace UnityEngine.UI.Extensions
{
    [AddComponentMenu("UI/Effects/Extensions/BestFit Outline")]
    public class BestFitOutline : Shadow
    {
        protected BestFitOutline()
        {
        }
        public override void ModifyMesh(/*List<UIVertex> verts*/Mesh mesh)
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

            int start = 0;
            int count = verts.Count;
            base.ApplyShadow(verts, base.effectColor, start, verts.Count, base.effectDistance.x * best_fit_adjustment, base.effectDistance.y * best_fit_adjustment);
            start = count;
            count = verts.Count;
            base.ApplyShadow(verts, base.effectColor, start, verts.Count, base.effectDistance.x * best_fit_adjustment, -base.effectDistance.y * best_fit_adjustment);
            start = count;
            count = verts.Count;
            base.ApplyShadow(verts, base.effectColor, start, verts.Count, -base.effectDistance.x * best_fit_adjustment, base.effectDistance.y * best_fit_adjustment);
            start = count;
            count = verts.Count;
            base.ApplyShadow(verts, base.effectColor, start, verts.Count, -base.effectDistance.x * best_fit_adjustment, -base.effectDistance.y * best_fit_adjustment);

            // 在合成mesh
            using (VertexHelper vertexHelper2 = new VertexHelper())
            {
                vertexHelper2.AddUIVertexTriangleStream(verts);
                vertexHelper2.FillMesh(mesh);
            }
        }
    }
}