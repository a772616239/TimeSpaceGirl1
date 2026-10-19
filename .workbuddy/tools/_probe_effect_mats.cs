var sb = new System.Text.StringBuilder();
string[] names = {
  "cn2-x1_badun_skill01_self","cn2-x1_badun_skill02_self",
  "cn2-x1_qiaodan_skill01_self","cn2-x1_yingzheng_skill01_self",
  "cn2-x1_dandin_skill01_self","cn2-x1_kaisa_skill01_self",
  "cn2-x1_lafeier_skill01_self","cn2-x1_zhentianxingcun_skill01_self",
  "cn2-x1_longlv_skill01_self","cn2-x1_waerjili_skill01_self","cn2-x1_mozhate_skill01_self"
};
foreach (var n in names) {
    var p = "Assets/ManagedResources/Prefabs/X1Effect/Battle/" + n + ".prefab";
    var go = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(p);
    if (go == null) { sb.AppendLine(n + "  <no prefab>"); continue; }
    bool found = false;
    foreach (var tr in go.GetComponentsInChildren<Transform>(true)) {
        if (tr.name != "effect") continue;
        var mr = tr.GetComponent<MeshRenderer>();
        if (mr == null) continue;
        foreach (var m in mr.sharedMaterials) {
            found = true;
            if (m == null) { sb.AppendLine(n + "  mat=NULL"); continue; }
            var mt = m.GetTexture("_MainTex"); var nt = m.GetTexture("_NoiseTex"); var kt = m.GetTexture("_MaskTex");
            sb.AppendLine(n + "  mat=" + m.name + " shader=" + m.shader.name + " _Alpha=" + m.GetFloat("_Alpha")
                + " _Color=" + m.GetColor("_Color")
                + " Main=" + (mt == null ? "NULL" : mt.name)
                + " Noise=" + (nt == null ? "NULL" : nt.name)
                + " Mask=" + (kt == null ? "NULL" : kt.name));
        }
    }
    if (!found) sb.AppendLine(n + "  <no effect node>");
}
return sb.ToString();
