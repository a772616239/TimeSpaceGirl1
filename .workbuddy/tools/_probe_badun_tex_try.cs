// 把候选贴图挂到真实的 effect 方块上实拍，同一台相机、同一个 _Alpha=0.42
var prefabPath = "Assets/ManagedResources/Prefabs/X1Effect/Battle/cn2-x1_badun_skill02_self.prefab";
var outDir = System.IO.Path.GetFullPath("_output/badun_tex_try");
System.IO.Directory.CreateDirectory(outDir);

string[] texPaths = {
    "",                                                              // 0 = 现状（无图）
    "Assets/Art/effectTexture/cn2-x1_normal_py_a00192.png",
    "Assets/Art/EffectsOld/Textures/cn2-tex_Aglow_z_01.png",
    "Assets/Art/EffectsOld/Textures/cn2-tex_lizi_002.png",
    "Assets/Art/effectTexture/cn2-D_lm_tex_275.png",
    "Assets/Art/EffectsOld/Textures/cn2-tex_UI_effect_jiefeng_jieyin.png"
};

var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
var sb = new System.Text.StringBuilder();

int W = 640, H = 360;
var rt = new RenderTexture(W, H, 24, RenderTextureFormat.ARGB32);
var tex = new Texture2D(W, H, TextureFormat.RGB24, false);

for (int i = 0; i < texPaths.Length; i++) {
    var inst = UnityEngine.Object.Instantiate(prefab);
    Transform myCam = null, eff = null;
    foreach (var tr in inst.GetComponentsInChildren<Transform>(true)) {
        if (tr.name == "MyCamera") myCam = tr;
        if (tr.name == "effect") eff = tr;
    }
    var camGO = new GameObject("ProbeCam");
    camGO.transform.position = myCam.position;
    camGO.transform.rotation = myCam.rotation;
    var cam = camGO.AddComponent<Camera>();
    cam.cullingMask = ~0;
    cam.clearFlags = CameraClearFlags.SolidColor;
    cam.backgroundColor = new Color(0.25f, 0.78f, 0.92f, 1f);
    cam.nearClipPlane = 0.1f;
    cam.farClipPlane = 300f;
    cam.fieldOfView = 45f;

    var mat = eff.GetComponent<MeshRenderer>().material;
    mat.SetFloat("_Alpha", 0.42f);
    if (texPaths[i] != "") {
        var t2 = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture2D>(texPaths[i]);
        if (t2 == null) sb.AppendLine("MISSING TEX " + texPaths[i]);
        mat.SetTexture("_MainTex", t2);
    }

    cam.targetTexture = rt;
    cam.Render();
    RenderTexture.active = rt;
    tex.ReadPixels(new Rect(0, 0, W, H), 0, 0);
    tex.Apply();
    RenderTexture.active = null;
    cam.targetTexture = null;
    var f = System.IO.Path.Combine(outDir, i.ToString("00") + ".png");
    System.IO.File.WriteAllBytes(f, tex.EncodeToPNG());
    sb.AppendLine(f + "  <- " + (texPaths[i] == "" ? "NO TEX" : System.IO.Path.GetFileName(texPaths[i])));

    UnityEngine.Object.DestroyImmediate(inst);
    UnityEngine.Object.DestroyImmediate(camGO);
}
UnityEngine.Object.DestroyImmediate(rt);
UnityEngine.Object.DestroyImmediate(tex);
return sb.ToString();
