var sb = new System.Text.StringBuilder();
var guids = UnityEditor.AssetDatabase.FindAssets("t:AnimationClip", new[] { "Assets/Art/effectAni" });
int hit = 0, total = 0;
foreach (var g in guids) {
    var p = UnityEditor.AssetDatabase.GUIDToAssetPath(g);
    var clip = UnityEditor.AssetDatabase.LoadAssetAtPath<AnimationClip>(p);
    if (clip == null) continue;
    total++;
    foreach (var b in UnityEditor.AnimationUtility.GetCurveBindings(clip)) {
        if (!b.propertyName.Contains("_Alpha")) continue;
        var c = UnityEditor.AnimationUtility.GetEditorCurve(clip, b);
        if (c == null) continue;
        float mx = 0f;
        foreach (var k in c.keys) mx = Mathf.Max(mx, k.value);
        if (mx <= 0.001f) continue;
        hit++;
        sb.AppendLine(p.Replace("Assets/Art/effectAni/", "") + "  maxAlpha=" + mx.ToString("0.000") + "  path=" + b.path);
    }
}
sb.AppendLine("clips=" + total + " hits=" + hit);
return sb.ToString();
