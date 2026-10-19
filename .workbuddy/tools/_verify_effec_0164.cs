var matPath = "Assets/Art/effectMaterials/effec_M_0164.mat";
UnityEditor.AssetDatabase.ImportAsset(matPath, UnityEditor.ImportAssetOptions.ForceUpdate);
var mat = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(matPath);
var sb = new System.Text.StringBuilder();
var t = mat.GetTexture("_MainTex");
sb.AppendLine("MainTex=" + (t == null ? "NULL" : t.name + " " + t.width + "x" + t.height));
sb.AppendLine("_CullMode1=" + mat.GetFloat("_CullMode1") + " queue=" + mat.renderQueue
    + " _Alpha=" + mat.GetFloat("_Alpha") + " _Color=" + mat.GetColor("_Color")
    + " keywords=" + string.Join(",", mat.shaderKeywords));

// ---- 前后对比实拍（关掉 Animator，_Alpha 固定 0.42）----
var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(
    "Assets/ManagedResources/Prefabs/X1Effect/Battle/cn2-x1_badun_skill02_self.prefab");
var outDir = System.IO.Path.GetFullPath("_output/badun_fix");
System.IO.Directory.CreateDirectory(outDir);
int W = 640, H = 360;
var rt = new RenderTexture(W, H, 24, RenderTextureFormat.ARGB32);
var cap = new Texture2D(W, H, TextureFormat.RGB24, false);

for (int pass = 0; pass < 2; pass++) {
    var inst = UnityEngine.Object.Instantiate(prefab);
    Transform myCam = null, eff = null;
    foreach (var tr in inst.GetComponentsInChildren<Transform>(true)) {
        if (tr.name == "MyCamera") myCam = tr;
        if (tr.name == "effect") eff = tr;
    }
    foreach (var an in inst.GetComponentsInChildren<Animator>(true)) an.enabled = false;
    // 只留 effect 这一个渲染体，避免粒子糊住画面
    foreach (var r in inst.GetComponentsInChildren<Renderer>(true)) {
        if (r.gameObject.name != "effect") r.enabled = false;
    }

    var camGO = new GameObject("ProbeCam");
    camGO.transform.position = myCam.position;
    camGO.transform.rotation = myCam.rotation;
    var cam = camGO.AddComponent<Camera>();
    cam.cullingMask = ~0;
    cam.clearFlags = CameraClearFlags.SolidColor;
    cam.backgroundColor = new Color(0.80f, 0.80f, 0.82f, 1f);
    cam.nearClipPlane = 0.1f; cam.farClipPlane = 300f; cam.fieldOfView = 45f;

    var m = eff.GetComponent<MeshRenderer>().material;
    m.SetFloat("_Alpha", 0.42f);
    if (pass == 0) m.SetTexture("_MainTex", null);   // 修复前

    cam.targetTexture = rt; cam.Render();
    RenderTexture.active = rt; cap.ReadPixels(new Rect(0, 0, W, H), 0, 0); cap.Apply();
    RenderTexture.active = null; cam.targetTexture = null;
    System.IO.File.WriteAllBytes(System.IO.Path.Combine(outDir, pass == 0 ? "before.png" : "after.png"), cap.EncodeToPNG());

    UnityEngine.Object.DestroyImmediate(inst);
    UnityEngine.Object.DestroyImmediate(camGO);
}
UnityEngine.Object.DestroyImmediate(rt);
UnityEngine.Object.DestroyImmediate(cap);
sb.AppendLine("renders -> _output/badun_fix/");
return sb.ToString();
