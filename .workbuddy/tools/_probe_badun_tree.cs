var path = "Assets/ManagedResources/Prefabs/X1Effect/Battle/cn2-x1_badun_skill02_self.prefab";
var go = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
if (go == null) return "NOT FOUND";
var sb = new System.Text.StringBuilder();
System.Action<Transform, int> walk = null;
walk = (tr, d) => {
    var comps = new System.Collections.Generic.List<string>();
    foreach (var c in tr.GetComponents<Component>()) {
        if (c == null) { comps.Add("<MISSING>"); continue; }
        var nm = c.GetType().Name;
        var psr = c as ParticleSystemRenderer;
        if (psr != null) {
            var pss = tr.GetComponent<ParticleSystem>();
            var m = psr.sharedMaterial;
            nm += "[" + (m == null ? "noMat" : m.name + "/" + m.shader.name) + "]";
        }
        comps.Add(nm);
    }
    sb.AppendLine(new string(' ', d * 2) + tr.name + (tr.gameObject.activeSelf ? "" : " (INACTIVE)")
        + "  L" + tr.gameObject.layer + " {" + string.Join(", ", comps) + "}");
    foreach (Transform c in tr) walk(c, d + 1);
};
walk(go.transform, 0);
return sb.ToString();
