var sb = new System.Text.StringBuilder();
sb.AppendLine("isPlaying=" + Application.isPlaying + " scenes=" + UnityEngine.SceneManagement.SceneManager.sceneCount);
for (int i = 0; i < UnityEngine.SceneManagement.SceneManager.sceneCount; i++) {
    var sc = UnityEngine.SceneManagement.SceneManager.GetSceneAt(i);
    sb.AppendLine("  scene[" + i + "] " + sc.name + " path=" + sc.path + " roots=" + sc.GetRootGameObjects().Length);
}
var all = Resources.FindObjectsOfTypeAll<Transform>();
int hits = 0;
foreach (var tr in all) {
    if (tr == null || tr.name == null) continue;
    if (!tr.name.StartsWith("cn2-x1_badun_skill02_self")) continue;
    hits++;
    sb.AppendLine("INSTANCE: " + tr.name + " scene=" + tr.gameObject.scene.name + " activeInHierarchy=" + tr.gameObject.activeInHierarchy);
    foreach (var c in tr.GetComponentsInChildren<Transform>(true)) {
        if (c.name != "effect") continue;
        var mr = c.GetComponent<MeshRenderer>();
        var m = mr.sharedMaterial;
        sb.AppendLine("   effect activeInHierarchy=" + c.gameObject.activeInHierarchy + " activeSelf=" + c.gameObject.activeSelf);
        sb.AppendLine("   mat=" + (m == null ? "NULL" : m.name) + " _Alpha=" + (m == null ? -1 : m.GetFloat("_Alpha"))
            + " _Color=" + (m == null ? Color.clear : m.GetColor("_Color"))
            + " Main=" + (m == null || m.GetTexture("_MainTex") == null ? "NULL" : m.GetTexture("_MainTex").name));
        sb.AppendLine("   renderer.enabled=" + mr.enabled + " sortingOrder=" + mr.sortingOrder + " isVisible=" + mr.isVisible);
    }
}
sb.AppendLine("instances=" + hits);
return sb.ToString();
