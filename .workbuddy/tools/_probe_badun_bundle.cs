// 检查 StreamingAssets 里已打好的 bundle，看 effect 节点在包内是什么材质状态
var bundlePath = System.IO.Path.GetFullPath("Assets/StreamingAssets/Android/lz4|prefabs|x1effect|battle|cn2-x1_badun_skill02_self.unity3d");
var sb = new System.Text.StringBuilder();
if (!System.IO.File.Exists(bundlePath)) return "BUNDLE NOT FOUND: " + bundlePath;
var ab = AssetBundle.LoadFromFile(bundlePath);
if (ab == null) { return "LOAD FAILED"; }
sb.AppendLine("bundle loaded, assets:");
foreach (var n in ab.GetAllAssetNames()) sb.AppendLine("  " + n);
var all = ab.LoadAllAssets<GameObject>();
foreach (var g in all) {
    sb.AppendLine("GO: " + g.name);
    foreach (var tr in g.GetComponentsInChildren<Transform>(true)) {
        if (tr.name != "effect") continue;
        var mr = tr.GetComponent<MeshRenderer>();
        sb.AppendLine("  effect found, active=" + tr.gameObject.activeSelf);
        foreach (var m in mr.sharedMaterials) {
            if (m == null) { sb.AppendLine("  mat=null"); continue; }
            sb.AppendLine("  mat=" + m.name + " shader=" + (m.shader == null ? "NULL" : m.shader.name));
            sb.AppendLine("  _Alpha=" + m.GetFloat("_Alpha") + " _Color=" + m.GetColor("_Color") + " keywords=" + string.Join(",", m.shaderKeywords));
            var mt = m.GetTexture("_MainTex");
            sb.AppendLine("  MainTex=" + (mt == null ? "NULL" : mt.name));
        }
    }
}
ab.Unload(true);
return sb.ToString();
