// 临时预览脚本（用完即删）：把钻石节点 + UIShineSweep 摆进当前场景（用完立刻删掉），
// 用正交相机渲到 RenderTexture，逐帧输出 PNG，用来肉眼验收光带裁剪/强度。
// spec 形如 "a=38;w=0.26;l=3.2;al=0.95"，通过反射改私有字段，方便快速 A/B。
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.UI;

public static class ShinePreviewRunner
{
    const int RT_SIZE = 320;

    static void SetField(object obj, string name, float value)
    {
        var f = obj.GetType().GetField(name, BindingFlags.Instance | BindingFlags.NonPublic);
        if (f != null) f.SetValue(obj, value);
    }

    public static string Run(string outDir, string spec)
    {
        Directory.CreateDirectory(outDir);

        var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(
            "Assets/ManagedResources/Prefabs/UI/Fight/FightPointPassMainPanel.prefab");
        if (prefab == null) return "prefab null";

        var srcNode = prefab.transform.Find("Bg/getBoxReward/Image/Image");
        if (srcNode == null) return "node null";

        GameObject camGo = null, canvasGo = null;
        var rt = new RenderTexture(RT_SIZE, RT_SIZE, 24, RenderTextureFormat.ARGB32);
        rt.antiAliasing = 4;
        var tex = new Texture2D(RT_SIZE, RT_SIZE, TextureFormat.RGBA32, false);
        var prev = RenderTexture.active;
        var report = spec;

        try
        {
            camGo = new GameObject("ShinePreviewCam");
            var cam = camGo.AddComponent<Camera>();
            cam.orthographic = true;
            cam.orthographicSize = RT_SIZE / 2f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.10f, 0.09f, 0.16f, 1f);
            cam.cullingMask = 1 << 5; // 只渲 UI 层，别把场景里别的东西拍进来
            cam.transform.position = new Vector3(0, 0, -10);

            canvasGo = new GameObject("ShinePreviewCanvas", typeof(Canvas), typeof(CanvasScaler));
            canvasGo.layer = 5;
            var canvas = canvasGo.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceCamera;
            canvas.worldCamera = cam;
            canvas.planeDistance = 5f;
            canvas.scaleFactor = 1f;
            canvas.sortingOrder = 30000;

            var node = UnityEngine.Object.Instantiate(srcNode.gameObject);
            node.name = "ShinePreviewDiamond";
            node.layer = 5;
            for (int i = 0; i < node.transform.childCount; i++)
                node.transform.GetChild(i).gameObject.layer = 5;
            node.transform.SetParent(canvasGo.transform, false);
            var nrt = (RectTransform)node.transform;
            nrt.anchoredPosition = Vector2.zero;
            nrt.localScale = Vector3.one;

            var comp = node.GetComponent<GameLogic.UIShineSweep>();
            if (comp == null) comp = node.AddComponent<GameLogic.UIShineSweep>();

            var map = new Dictionary<string, string>();
            foreach (var pair in spec.Split(';'))
            {
                var kv = pair.Split('=');
                if (kv.Length == 2) map[kv[0].Trim()] = kv[1].Trim();
            }
            float V(string k, float d)
            {
                return map.ContainsKey(k) ? float.Parse(map[k], CultureInfo.InvariantCulture) : d;
            }
            if (map.Count > 0)
            {
                SetField(comp, "angle", V("a", 40f));
                SetField(comp, "widthFactor", V("w", 0.30f));
                SetField(comp, "lengthFactor", V("l", 3.2f));
                SetField(comp, "maxAlpha", V("al", 0.92f));
            }

            var build = typeof(GameLogic.UIShineSweep).GetMethod("Build",
                BindingFlags.Instance | BindingFlags.NonPublic);
            if (build != null) build.Invoke(comp, null);

            Canvas.ForceUpdateCanvases();
            cam.targetTexture = rt;

            float[] phases = { 0.10f, 0.25f, 0.40f, 0.50f, 0.60f, 0.75f, 0.85f };
            for (int i = 0; i < phases.Length; i++)
            {
                comp.Evaluate(phases[i]);
                Canvas.ForceUpdateCanvases();
                cam.Render();

                RenderTexture.active = rt;
                tex.ReadPixels(new Rect(0, 0, RT_SIZE, RT_SIZE), 0, 0);
                tex.Apply();
                RenderTexture.active = prev;

                File.WriteAllBytes(Path.Combine(outDir, "u_" + i.ToString("00") + ".png"), tex.EncodeToPNG());
            }

            report += " | clip=" + (nrt.Find("ShineClip") != null)
                      + " mask=" + (nrt.Find("ShineClip") != null && nrt.Find("ShineClip").GetComponent<Mask>() != null)
                      + " shine=" + (nrt.Find("ShineClip/Shine") != null);
            foreach (var name in new[] { "angle", "widthFactor", "lengthFactor", "maxAlpha", "maskWidthFactor" })
            {
                var f = typeof(GameLogic.UIShineSweep).GetField(name, BindingFlags.Instance | BindingFlags.NonPublic);
                report += string.Format(" | {0}={1}", name, f == null ? "?" : f.GetValue(comp).ToString());
            }
        }
        catch (Exception e)
        {
            report += " | EX " + e.GetType().Name + ": " + e.Message;
        }
        finally
        {
            RenderTexture.active = prev;
            if (canvasGo != null) UnityEngine.Object.DestroyImmediate(canvasGo);
            if (camGo != null) UnityEngine.Object.DestroyImmediate(camGo);
            rt.Release();
        }

        return report;
    }
}
