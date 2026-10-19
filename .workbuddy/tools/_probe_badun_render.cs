// 运行时实拍：把 effect 方块的 _Alpha 设成动画峰值 0.42，看它到底在画面上占多大一块
var prefabPath = "Assets/ManagedResources/Prefabs/X1Effect/Battle/cn2-x1_badun_skill02_self.prefab";
var outPath = System.IO.Path.GetFullPath("_output/badun_effect_probe.png");
System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(outPath));

var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
var inst = UnityEngine.Object.Instantiate(prefab);

Transform myCam = null, eff = null;
foreach (var tr in inst.GetComponentsInChildren<Transform>(true)) {
    if (tr.name == "MyCamera") myCam = tr;
    if (tr.name == "effect") eff = tr;
}
if (myCam == null || eff == null) { UnityEngine.Object.DestroyImmediate(inst); return "nodes missing"; }

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

var mr = eff.GetComponent<MeshRenderer>();
var mat = mr.material;
mat.SetFloat("_Alpha", 0.42f);

int W = 960, H = 540;
var rt = new RenderTexture(W, H, 24, RenderTextureFormat.ARGB32);
cam.targetTexture = rt;
cam.Render();
RenderTexture.active = rt;
var tex = new Texture2D(W, H, TextureFormat.RGB24, false);
tex.ReadPixels(new Rect(0, 0, W, H), 0, 0);
tex.Apply();
RenderTexture.active = null;
cam.targetTexture = null;
System.IO.File.WriteAllBytes(outPath, tex.EncodeToPNG());

float minX = 9, maxX = -9, minY = 9, maxY = -9;
for (int i = 0; i < 4; i++) {
    float sx = (i == 0 || i == 3) ? -0.5f : 0.5f;
    float sy = (i < 2) ? 0.5f : -0.5f;
    var vp = cam.WorldToViewportPoint(eff.TransformPoint(new Vector3(sx, sy, 0)));
    minX = Mathf.Min(minX, vp.x); maxX = Mathf.Max(maxX, vp.x);
    minY = Mathf.Min(minY, vp.y); maxY = Mathf.Max(maxY, vp.y);
}

UnityEngine.Object.DestroyImmediate(inst);
UnityEngine.Object.DestroyImmediate(camGO);
UnityEngine.Object.DestroyImmediate(rt);
UnityEngine.Object.DestroyImmediate(tex);

return "png=" + outPath
    + "\nviewport x " + minX.ToString("0.00") + ".." + maxX.ToString("0.00")
    + "  y " + minY.ToString("0.00") + ".." + maxY.ToString("0.00")
    + "\ncoverage W=" + ((maxX - minX) * 100).ToString("0") + "%  H=" + ((maxY - minY) * 100).ToString("0") + "%";
