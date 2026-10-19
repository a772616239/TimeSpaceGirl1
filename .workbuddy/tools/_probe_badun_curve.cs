var clipPath = "Assets/Art/effectAni/hero/badun/CAM_badun_sk_02ANI.anim";
var clip = UnityEditor.AssetDatabase.LoadAssetAtPath<AnimationClip>(clipPath);
if (clip == null) return "CLIP NOT FOUND";
var sb = new System.Text.StringBuilder();
foreach (var b in UnityEditor.AnimationUtility.GetCurveBindings(clip)) {
    sb.AppendLine("[" + b.path + "] " + b.type.Name + "." + b.propertyName);
    var curve = UnityEditor.AnimationUtility.GetEditorCurve(clip, b);
    if (curve == null) continue;
    sb.AppendLine("   keys=" + curve.length + " valueRange=" + curve.keys[0].value + " .. " + curve.keys[curve.length - 1].value);
    foreach (var k in curve.keys) sb.AppendLine("     t=" + k.time.ToString("0.00") + " v=" + k.value.ToString("0.000"));
}
return sb.ToString();
