#!/usr/bin/env python3
"""生成并执行「国家旗帜选择面板」布局探针（Unity execute_code 源）。

读 CountryConfig.lua 取 73 条 (code, zh)，在 Unity 里用 preview scene 复刻
CountryFlagSelectPopup.lua:BuildCells 的摆放逻辑，量化每格是否落在 viewport 内，
并渲染顶部/底部两张实拍图。

用法：python probe_country_popup.py [--fix]
  --fix  用「修正后」的摆放公式（anchor 顶部 + 从上往下排）再跑一遍，便于对比
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LUA = os.path.join(ROOT, "Assets/ManagedResources/~Lua/Modules/CountryRank/CountryConfig.lua")
OUT = os.path.join(ROOT, "_output")


def load_items():
    body = open(LUA, encoding="utf-8").read().split("CountryConfig.List = {", 1)[1].split("\n}", 1)[0]
    return re.findall(r'code = "(\w+)".*?zh = "([^"]*)"', body)


def cs_array(values):
    return "new string[]{" + ",".join('@"%s"' % v.replace('"', '""') for v in values) + "}"


def build_cs(items, fixed):
    codes = cs_array([c for c, _ in items])
    names = cs_array([z for _, z in items])
    return r'''
var codes = %(codes)s;
var names = %(names)s;
int COL = 4, CW = 190, CH = 176;
bool fixedLayout = %(fixed)s;
var sb = new System.Text.StringBuilder();
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewScene(UnityEditor.SceneManagement.NewSceneSetup.EmptyScene, UnityEditor.SceneManagement.NewSceneMode.Additive);
UnityEngine.SceneManagement.Scene previewScene = scene;
GameObject canvasGo = null; Camera cam = null; RenderTexture rt = null;
try {
    var path = "Assets/ManagedResources/Prefabs/UI/CountryRank/CountryFlagSelectPopup.prefab";
    var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
    if (prefab == null) return "prefab not found";
    var panel = (GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(prefab);

    canvasGo = new GameObject("probeCanvas", typeof(Canvas));
    UnityEditor.SceneManagement.EditorSceneManager.MoveGameObjectToScene(canvasGo, scene);
    UnityEditor.SceneManagement.EditorSceneManager.MoveGameObjectToScene(panel, scene);

    var camGo = new GameObject("probeCam", typeof(Camera));
    UnityEditor.SceneManagement.EditorSceneManager.MoveGameObjectToScene(camGo, scene);
    cam = camGo.GetComponent<Camera>();
    cam.orthographic = false;
    cam.fieldOfView = 60f;
    cam.clearFlags = CameraClearFlags.SolidColor;
    cam.backgroundColor = new Color(0.07f, 0.05f, 0.10f, 1f);
    cam.transform.position = new Vector3(0f, 0f, -100f);
    cam.transform.rotation = Quaternion.identity;

    var canvas = canvasGo.GetComponent<Canvas>();
    canvas.renderMode = RenderMode.ScreenSpaceCamera;
    canvas.worldCamera = cam;
    canvas.planeDistance = 100f;

    panel.transform.SetParent(canvasGo.transform, false);
    panel.SetActive(true);
    var prt = panel.GetComponent<RectTransform>();
    if (prt != null) { prt.anchorMin = Vector2.zero; prt.anchorMax = Vector2.one; prt.offsetMin = Vector2.zero; prt.offsetMax = Vector2.zero; }

    var all = panel.GetComponentsInChildren<RectTransform>(true);
    var grid = all.First(r => r.name == "grid");
    var viewport = all.First(r => r.name == "viewport");
    var cellPre = all.First(r => r.name == "cellPre");
    var viewGo = viewport.gameObject;

    int total = codes.Length;
    int rows = (total + COL - 1) / COL;
    float contentH = rows * CH;

    // ---- 复刻 BuildCells ----
    grid.sizeDelta = new Vector2(0f, contentH);
    var created = new System.Collections.Generic.List<RectTransform>();
    for (int i = 0; i < total; i++) {
        var go = UnityEngine.Object.Instantiate(cellPre.gameObject);
        go.name = "cell_" + codes[i];
        go.transform.SetParent(grid.transform, false);
        go.SetActive(true);
        var rt2 = go.GetComponent<RectTransform>();
        if (fixedLayout) {
            rt2.anchorMin = new Vector2(0.5f, 1f);
            rt2.anchorMax = new Vector2(0.5f, 1f);
            rt2.pivot = new Vector2(0.5f, 0.5f);
            int col2 = i %% COL;
            int row2 = i / COL;
            rt2.anchoredPosition = new Vector2((col2 - (COL - 1) / 2f) * CW, -(row2 * CH + CH / 2f));
        } else {
            rt2.anchorMin = new Vector2(0.5f, 0.5f);
            rt2.anchorMax = new Vector2(0.5f, 0.5f);
            rt2.pivot = new Vector2(0.5f, 0.5f);
            float startY = contentH - CH / 2f;
            int col2 = i %% COL;
            int row2 = i / COL;
            rt2.anchoredPosition = new Vector2((col2 - (COL - 1) / 2f) * CW, startY - row2 * CH);
        }
        rt2.sizeDelta = new Vector2(CW, CH);
        var img = rt2.Find("flag").GetComponent<UnityEngine.UI.Image>();
        var sp = UnityEditor.AssetDatabase.LoadAssetAtPath<Sprite>("Assets/ManagedResources/Atlas/CountryRankPanelAtlas/cn2-guoqi_" + codes[i] + ".png");
        if (img != null && sp != null) img.sprite = sp;
        var txt = rt2.Find("nameText").GetComponent<UnityEngine.UI.Text>();
        if (txt != null) txt.text = names[i];
        created.Add(rt2);
    }

    rt = new RenderTexture(1080, 2160, 24);
    cam.targetTexture = rt;
    Canvas.ForceUpdateCanvases();
    if (viewport != null) Canvas.ForceUpdateCanvases();

    // ---- 量化：每格中心是否在 viewport 可见矩形内 ----
    Vector3[] vc = new Vector3[4];
    viewport.GetWorldCorners(vc);
    float vyMin = vc[0].y, vyMax = vc[2].y;
    sb.AppendLine("viewport UI h=" + viewport.rect.height.ToString("F1") + "  world h=" + (vyMax - vyMin).ToString("F1"));
    sb.AppendLine("content h=" + grid.rect.height.ToString("F1") + " rows=" + rows);
    int hiddenTotal = 0;
    for (int i = 0; i < created.Count; i++) {
        if (i %% COL != 0) continue; // 只统计每行第一列，够用
        int row = i / COL;
        float y = created[i].position.y;
        bool visible = y <= vyMax && y >= vyMin;
        if (!visible) hiddenTotal++;
        if (!visible) sb.AppendLine("  row " + row + " (from " + codes[i] + ") y=" + y.ToString("F1") + " OUTSIDE");
    }
    sb.AppendLine("rows fully/partly outside viewport at scrollTop: " + hiddenTotal + " / " + rows);

    System.IO.Directory.CreateDirectory("%(out)s");
    string tag = fixedLayout ? "fixed" : "current";
    UnityEngine.RenderTexture.active = rt;
    cam.Render();
    var tex = new Texture2D(1080, 2160, TextureFormat.RGB24, false);
    tex.ReadPixels(new Rect(0, 0, 1080, 2160), 0, 0);
    tex.Apply();
    System.IO.File.WriteAllBytes("%(out)s/popup_" + tag + "_top.png", tex.EncodeToPNG());
    UnityEngine.Object.DestroyImmediate(tex);

    // 滚到底部
    float viewHUnits = viewport.rect.height;
    float maxScroll = Mathf.Max(0f, contentH - viewHUnits);
    grid.anchoredPosition = new Vector2(0f, maxScroll);
    Canvas.ForceUpdateCanvases();
    cam.Render();
    var tex2 = new Texture2D(1080, 2160, TextureFormat.RGB24, false);
    tex2.ReadPixels(new Rect(0, 0, 1080, 2160), 0, 0);
    tex2.Apply();
    System.IO.File.WriteAllBytes("%(out)s/popup_" + tag + "_bottom.png", tex2.EncodeToPNG());
    UnityEngine.Object.DestroyImmediate(tex2);
    sb.AppendLine("saved popup_" + tag + "_top.png / _bottom.png");
}
finally {
    if (cam != null) cam.targetTexture = null;
    if (rt != null) { rt.Release(); UnityEngine.Object.DestroyImmediate(rt); }
    if (previewScene.IsValid()) UnityEditor.SceneManagement.EditorSceneManager.CloseScene(previewScene, true);
}
return sb.ToString();
''' % {"codes": codes, "names": names, "fixed": "true" if fixed else "false", "out": OUT}


def main():
    fixed = "--fix" in sys.argv
    items = load_items()
    src = build_cs(items, fixed)
    path = "/tmp/probe_country_popup.cs"
    open(path, "w", encoding="utf-8").write(src)
    out = subprocess.run(
        [sys.executable, os.path.join(ROOT, ".workbuddy/tools/unity_bridge.py"), "codef", path],
        capture_output=True, text=True, cwd=ROOT,
    ).stdout
    try:
        data = json.loads(out)
        print(json.dumps(data, ensure_ascii=False, indent=2)[:6000])
    except Exception:
        print(out[:4000])


if __name__ == "__main__":
    main()
