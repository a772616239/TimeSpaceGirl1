// 探查 cn2-x1_badun_skill02_self 预制里的 effect 节点
var path = "Assets/ManagedResources/Prefabs/X1Effect/Battle/cn2-x1_badun_skill02_self.prefab";
var go = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
if (go == null) return "PREFAB NOT FOUND";

var sb = new System.Text.StringBuilder();
var t = go.transform;
System.Action<Transform, int> walk = null;
walk = (tr, depth) => {
    var mr = tr.GetComponent<MeshRenderer>();
    var ps = tr.GetComponent<ParticleSystemRenderer>();
    if (tr.name == "effect" || (mr != null && tr.name != "effect")) {
        sb.AppendLine(new string(' ', depth * 2) + tr.name + "  layer=" + tr.gameObject.layer
            + " active=" + tr.gameObject.activeInHierarchy
            + " pos=" + tr.localPosition + " scale=" + tr.localScale
            + " rot=" + tr.localEulerAngles);
        if (mr != null) {
            foreach (var m in mr.sharedMaterials) {
                if (m == null) { sb.AppendLine("    material=null"); continue; }
                sb.AppendLine("    mat=" + m.name + " shader=" + m.shader.name + " queue=" + m.renderQueue
                    + " keywords=" + string.Join(",", m.shaderKeywords));
                sb.AppendLine("    _Alpha=" + m.GetFloat("_Alpha") + " _Color=" + m.GetColor("_Color")
                    + " _ISsmoke=" + m.GetFloat("_ISsmoke") + " _Luminance=" + m.GetFloat("_Luminance"));
                var mt = m.GetTexture("_MainTex"); var nt = m.GetTexture("_NoiseTex"); var kt = m.GetTexture("_MaskTex");
                sb.AppendLine("    MainTex=" + (mt == null ? "NULL" : mt.name)
                    + " NoiseTex=" + (nt == null ? "NULL" : nt.name)
                    + " MaskTex=" + (kt == null ? "NULL" : kt.name));
                sb.AppendLine("    Main_Tiling_Offset=" + m.GetVector("_Main_Tiling_Offset")
                    + " path=" + UnityEditor.AssetDatabase.GetAssetPath(m));
            }
            sb.AppendLine("    sortingOrder=" + mr.sortingOrder + " castShadows=" + mr.shadowCastingMode
                + " receiveShadows=" + mr.receiveShadows);
        }
        if (ps != null) {
            sb.AppendLine("    PS renderMode=" + ps.renderMode + " mesh=" + (ps.mesh == null ? "NULL" : ps.mesh.name));
            foreach (var m in ps.sharedMaterials) {
                if (m != null) sb.AppendLine("    PSmat=" + m.name + " shader=" + m.shader.name);
            }
        }
    }
    foreach (Transform c in tr) walk(c, depth + 1);
};
walk(t, 0);
return sb.ToString();
