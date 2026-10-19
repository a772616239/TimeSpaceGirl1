var path = "Assets/ManagedResources/Prefabs/X1Effect/Battle/cn2-x1_badun_skill02_self.prefab";
var go = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
var sb = new System.Text.StringBuilder();
foreach (var anim in go.GetComponentsInChildren<Animator>(true)) {
    sb.AppendLine("Animator on " + anim.gameObject.name + " controller=" + (anim.runtimeAnimatorController == null ? "NULL" : anim.runtimeAnimatorController.name));
    var ac = anim.runtimeAnimatorController as UnityEditor.Animations.AnimatorController;
    if (ac == null) continue;
    sb.AppendLine("  assetPath=" + UnityEditor.AssetDatabase.GetAssetPath(ac));
    foreach (var c in ac.animationClips) {
        if (c == null) continue;
        sb.AppendLine("  clip=" + c.name + " len=" + c.length.ToString("0.00") + " path=" + UnityEditor.AssetDatabase.GetAssetPath(c));
        var bindings = UnityEditor.AnimationUtility.GetCurveBindings(c);
        foreach (var b in bindings) {
            if (b.path.Contains("effect") || b.propertyName.Contains("Material") || b.type == typeof(MeshRenderer) || b.type == typeof(Material)) {
                sb.AppendLine("    [" + b.path + "] " + b.type.Name + "." + b.propertyName);
            }
        }
        // 对象引用（材质/贴图替换）也算
        var objs = UnityEditor.AnimationUtility.GetObjectReferenceCurveBindings(c);
        foreach (var b in objs) {
            sb.AppendLine("    OBJREF [" + b.path + "] " + b.type.Name + "." + b.propertyName);
        }
    }
}
return sb.ToString();
