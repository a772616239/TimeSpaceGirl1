// 候选贴图实拍（中性浅灰底，方块形状一眼可辨）
var prefabPath = "Assets/ManagedResources/Prefabs/X1Effect/Battle/cn2-x1_badun_skill02_self.prefab";
var outDir = System.IO.Path.GetFullPath("_output/badun_tex_try");
System.IO.Directory.CreateDirectory(outDir);

string[] texPaths = {
    "",
    "Assets/Art/effectTexture/cn2-x1_normal_py_a00192.png",
    "Assets/Art/EffectsOld/Textures/cn2-tex_Aglow_z_01.png",
    "Assets/Art/EffectsOld/Textures/cn2-tex_lizi_002.png",
    "Assets/Art/effectTexture/cn2-D_lm_tex_275.png",
    "Assets/Art/EffectsOld/Textures/cn2-tex_UI_effect_jiefeng_jieyin.png"
};

var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
var sb = new System.Text.StringBuilder();
int W = 480, H = 270;
var rt = new RenderTexture(W, H, 24, RenderTextureFormat.ARGB32);
var tex = new Texture2D(W, H, TextureFormat.RGB24, false);

for (int i = 0; i < texPaths.Length; i++) {
    var inst = UnityEngine.Object.Instantiate(prefab);
    Transform myCam = null, eff = null;
    foreach (var tr in inst.GetComponentsInChildren<Transform>(true)) {
        if (tr.name == "MyCamera") myCam = tr;
        if (tr.name == "effect") eff = tr;
    }
    // 关掉 Animator，避免它把 _Alpha 拉回 0
    foreach (var an in inst.GetComponentsInChildren<Animator>(true)) an.enabled = false;

    var camGO = new GameObject("ProbeCam");
    camGO.transform.position = myCam.position;
    camGO.transform.rotation = myCam.rotation;
    var cam = camGO.AddComponent<Camera>();
    cam.cullingMask = ~0;
    cam.clearFlags = CameraClearFlags.SolidColor;
    cam.backgroundColor = new Color(0.80f, 0.80f, 0.82f, 1f);
    cam.nearClipPlane = 0.1f;
    cam.farClipPlane = 300f;
    cam.fieldOfView = 45f;

    var mat = eff.GetComponent<MeshRenderer>().material;
    mat.SetFloat("_Alpha", 0.42f);
    if (texPaths[i] != "") mat.SetTexture("_MainTex", UnityEditor.AssetDatabase.LoadAssetAtPath<Texture2D>(texPaths[i]));

    cam.targetTexture = rt;
    cam.Render();
    RenderTexture.active = rt;
    tex.ReadPixels(new Rect(0, 0, W, H), 0, 0);
    tex.Apply();
    RenderTexture.active = null;
    cam.targetTexture = null;
    System.IO.File.WriteAllBytes(System.IO.Path.Combine(outDir, "g" + i + ".png"), tex.EncodeToPNG());

    UnityEngine.Object.DestroyImmediate(inst);
    UnityEngine.Object.DestroyImmediate(camGO);
}
UnityEngine.Object.DestroyImmediate(rt);
UnityEngine.Object.DestroyImmediate(tex);
return "done";
