var path = "Assets/ManagedResources/Prefabs/X1Effect/Battle/cn2-x1_badun_skill02_self.prefab";
var go = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
var sb = new System.Text.StringBuilder();
var seen = new System.Collections.Generic.HashSet<string>();
foreach (var r in go.GetComponentsInChildren<Renderer>(true)) {
    foreach (var m in r.sharedMaterials) {
        if (m == null) continue;
        if (!seen.Add(m.name)) continue;
        var mt = m.GetTexture("_MainTex");
        var nt = m.GetTexture("_NoiseTex");
        var kt = m.GetTexture("_MaskTex");
        sb.AppendLine(m.name + " [" + m.shader.name + "]"
            + " Main=" + (mt == null ? "NULL" : mt.name)
            + " Noise=" + (nt == null ? "NULL" : nt.name)
            + " Mask=" + (kt == null ? "NULL" : kt.name));
    }
}
return sb.ToString();
