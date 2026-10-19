var sb = new System.Text.StringBuilder();
string[] names = { "cn2-x1_beimihu_skill01_self", "cn2-x1_zhitianxingchang_skill01_self" };
foreach (var n in names) {
    var p = "Assets/ManagedResources/Prefabs/X1Effect/Battle/" + n + ".prefab";
    var go = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(p);
    if (go == null) { sb.AppendLine(n + " <none>"); continue; }
    foreach (var tr in go.GetComponentsInChildren<Transform>(true)) {
        if (tr.name != "effect" && tr.name != "senceback") continue;
        var mr = tr.GetComponent<MeshRenderer>();
        if (mr == null) continue;
        foreach (var m in mr.sharedMaterials) {
            if (m == null) { sb.AppendLine(n + " " + tr.name + " mat=NULL"); continue; }
            var mt = m.GetTexture("_MainTex");
            var kt = m.GetTexture("_MaskTex");
            var nt = m.GetTexture("_NoiseTex");
            sb.AppendLine(n + " [" + tr.name + "] mat=" + m.name + " shader=" + m.shader.name
                + " _Color=" + m.GetColor("_Color")
                + " Main=" + (mt == null ? "NULL" : mt.name)
                + " Noise=" + (nt == null ? "NULL" : nt.name)
                + " Mask=" + (kt == null ? "NULL" : kt.name)
                + " mesh=" + (tr.GetComponent<MeshFilter>() == null || tr.GetComponent<MeshFilter>().sharedMesh == null ? "NULL" : tr.GetComponent<MeshFilter>().sharedMesh.name)
                + " scale=" + tr.localScale + " pos=" + tr.localPosition);
        }
    }
}
return sb.ToString();
