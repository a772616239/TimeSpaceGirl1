var sb = new System.Text.StringBuilder();
var guids = UnityEditor.AssetDatabase.FindAssets("t:Material", new[] { "Assets/Art/effectMaterials" });
int n = 0;
foreach (var g in guids) {
    var p = UnityEditor.AssetDatabase.GUIDToAssetPath(g);
    var m = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(p);
    if (m == null || m.shader == null) continue;
    if (m.shader.name != "MS/effect_alpha") continue;
    var c = m.GetColor("_Color");
    if (c.r > 0.05f || c.g > 0.05f || c.b > 0.05f) continue;   // 只要偏黑的
    var mt = m.GetTexture("_MainTex");
    var nt = m.GetTexture("_NoiseTex");
    var kt = m.GetTexture("_MaskTex");
    n++;
    sb.AppendLine(m.name + "  a=" + c.a.ToString("0.00")
        + " Main=" + (mt == null ? "NULL" : mt.name)
        + " Noise=" + (nt == null ? "NULL" : nt.name)
        + " Mask=" + (kt == null ? "NULL" : kt.name));
}
sb.AppendLine("black-ish effect_alpha mats = " + n);
return sb.ToString();
