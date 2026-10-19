#!/usr/bin/env python3
"""大招小卡（HelpHeroMiniCard_*）摆位复现 + 多分辨率自验。

在运行中的 Editor 里：建一块指定尺寸的「假画布」→ 放 BattlePanel 副本 →
用假 view 调 BattleUltCard.Show（营 0 / 营 1）→ 读回 Image1 相对假画布的归一化位置。

🔴 判定口径：卡片锚点若在顶部，归一化「顶距」必须与画布高度无关；
旧实现跟技能栏（锚在画布垂直中心）走，画布越高卡片越靠下 —— 分辨率一换就跑到画面中部。

用法：
  python .workbuddy/tools/probe_ult_card.py
  python .workbuddy/tools/probe_ult_card.py 1080x1920 1080x2220 1440x2960
  python .workbuddy/tools/probe_ult_card.py 1080x2220 --shot
"""
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from unity_bridge import Bridge  # noqa: E402

PREFAB = "Assets/ManagedResources/Prefabs/UI/Battle/BattlePanel.prefab"
SHOT = os.path.join(HERE, "probe", "ult_card_shot.png")


def run_code(b, code):
    r = b.call("execute_code", {"action": "execute", "code": code})
    d = r.get("result", r)
    if isinstance(d, dict) and d.get("success"):
        return d.get("data", {}).get("result")
    return "ERR: %s" % json.dumps(d, ensure_ascii=False)[:900]


def run_lua(b, lua):
    return run_code(b, 'var lua = @"%s";\nreturn App.LuaMgr.DoString<string>(lua);'
                    % lua.replace('"', '""'))


CLEAN = r'''
string[] gone = new string[]{"UltProbeHost", "UIRoot/FixedNode/UltProbePanel"};
foreach (var nm in gone) {
    var old = UnityEngine.GameObject.Find(nm);
    if (old != null) UnityEngine.Object.DestroyImmediate(old);
}
return "cleaned";
'''

RELOAD_LUA = r"""
package.loaded['Modules.Battle.View.BattleUltCard'] = nil
local B = require('Modules.Battle.View.BattleUltCard')
B.Destroy()
return 'reloaded'
"""


def spawn(w, h):
    return r'''
var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(@"__PREFAB__");
if (prefab == null) return "prefab load failed";
var uiRoot = UnityEngine.GameObject.Find("UIRoot");
if (uiRoot == null) return "UIRoot not found";
var host = new GameObject("UltProbeHost", typeof(Canvas), typeof(UnityEngine.UI.GraphicRaycaster));
var hc = host.GetComponent<Canvas>();
hc.renderMode = RenderMode.ScreenSpaceCamera;
hc.worldCamera = uiRoot.GetComponent<Canvas>().worldCamera;
hc.planeDistance = 50f;
hc.sortingOrder = 32000;
var box = new GameObject("UltProbeCanvas", typeof(RectTransform));
box.transform.SetParent(host.transform, false);
var brt = (RectTransform)box.transform;
brt.anchorMin = new Vector2(0, 1); brt.anchorMax = new Vector2(0, 1);
brt.pivot = new Vector2(0, 1); brt.anchoredPosition = Vector2.zero;
brt.sizeDelta = new Vector2(__W__, __H__);
var go = (GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(prefab, box.transform);
go.name = "UltProbePanel";
go.SetActive(true);
var prt = go.GetComponent<RectTransform>();
prt.anchorMin = Vector2.zero; prt.anchorMax = Vector2.one;
prt.anchoredPosition = Vector2.zero; prt.sizeDelta = Vector2.zero;
prt.localScale = Vector3.one;
var bar = go.transform.Find("myRect_Skill");
var ebar = go.transform.Find("enemyRect_Skill");
if (bar != null) bar.gameObject.SetActive(true);
if (ebar != null) ebar.gameObject.SetActive(true);
UnityEngine.Canvas.ForceUpdateCanvases();
return "fake canvas __W__x__H__ panel=" + prt.rect.ToString();
'''.replace("__W__", str(w)).replace("__H__", str(h)).replace("__PREFAB__", PREFAB)


SHOW_LUA = r"""
local panel = UnityEngine.GameObject.Find('UltProbeHost/UltProbeCanvas/UltProbePanel')
if panel == nil then return 'panel nil' end
local B = require('Modules.Battle.View.BattleUltCard')
local fake = { transform = panel.transform, gameObject = panel,
               HelpHeroShow = Util.GetGameObject(panel, 'HelpHeroShow') }
local ids = {}
for id = 10001, 10110 do
    local cfg = G_HeroConfig[id]
    if type(cfg) == 'table' and cfg.RoleImage ~= nil and cfg.RoleImage ~= 0 then
        ids[#ids + 1] = id
        if #ids >= 2 then break end
    end
end
if #ids < 2 then return 'no hero with RoleImage' end
local tag = tostring(os.time()) .. '-' .. tostring(math.floor(os.clock() * 1000))
B.Show(fake, G_HeroConfig[ids[1]], 0, 'probeMine-' .. tag)
B.Show(fake, G_HeroConfig[ids[2]], 1, 'probeEnemy-' .. tag)
for _, c in pairs({0, 1}) do
    local s = B.slots[c]
    if s then
        if s.timer then s.timer:Stop() end
        if s.followTimer then s.followTimer:Stop() end
    end
end
return string.format('shown mine=%s enemy=%s', tostring(ids[1]), tostring(ids[2]))
"""

MEASURE = r'''
var sb = new System.Text.StringBuilder();
var box = UnityEngine.GameObject.Find("UltProbeHost/UltProbeCanvas");
var panel = UnityEngine.GameObject.Find("UltProbeHost/UltProbeCanvas/UltProbePanel");
if (box == null || panel == null) return "probe canvas/panel missing";
var brt = (RectTransform)box.transform;
var bc = new Vector3[4]; brt.GetWorldCorners(bc);
float bw = bc[2].x - bc[0].x, bh = bc[2].y - bc[0].y;
sb.AppendLine(string.Format("fake canvas {0}x{1}", bw, bh));
string[] names = {"HelpHeroMiniCard_Mine", "HelpHeroMiniCard_Enemy"};
foreach (var nm in names) {
    UnityEngine.Transform t = panel.transform.Find(nm);
    if (t == null) { sb.AppendLine(nm + " NOT FOUND"); continue; }
    var r = (RectTransform)t;
    sb.AppendLine(string.Format("{0}: pos={1} anc={2}/{3} scale={4}", nm, r.anchoredPosition, r.anchorMin, r.anchorMax, t.localScale));
    UnityEngine.Transform imag = null;
    foreach (UnityEngine.Transform kid in t) { if (kid.name == "Image1") { imag = kid; break; } }
    if (imag == null) { sb.AppendLine("    Image1 missing"); continue; }
    var iw = new Vector3[4]; ((RectTransform)imag).GetWorldCorners(iw);
    float L = (iw[0].x - bc[0].x) / bw, R = (iw[2].x - bc[0].x) / bw;
    float Bo = (iw[0].y - bc[0].y) / bh, T = (iw[2].y - bc[0].y) / bh;
    sb.AppendLine(string.Format("    Image1 占屏 L={0:F3} R={1:F3} / 顶距={2:F1}% 底距={3:F1}% 高={4:F1}%",
        L, R, (1f - T) * 100f, (1f - Bo) * 100f, (T - Bo) * 100f));
}
return sb.ToString();
'''


def capture():
    with Bridge() as b:
        code = r'''
var host = UnityEngine.GameObject.Find("UltProbeHost");
var cam = host.GetComponent<Canvas>().worldCamera;
var others = new System.Collections.Generic.List<Canvas>();
foreach (var c in UnityEngine.Object.FindObjectsOfType<Canvas>()) {
    if (c.gameObject != host && c.gameObject.activeSelf) { others.Add(c); c.enabled = false; }
}
int w = 1080, h = 2220;
var rt2 = new RenderTexture(w, h, 24, RenderTextureFormat.ARGB32);
var oldT = cam.targetTexture;
cam.targetTexture = rt2;
cam.Render();
RenderTexture.active = rt2;
var tex = new Texture2D(w, h, TextureFormat.RGB24, false);
tex.ReadPixels(new Rect(0, 0, w, h), 0, 0); tex.Apply();
RenderTexture.active = null; cam.targetTexture = oldT;
System.IO.File.WriteAllBytes(@"%s", tex.EncodeToPNG());
UnityEngine.Object.DestroyImmediate(rt2);
UnityEngine.Object.DestroyImmediate(tex);
foreach (var c in others) c.enabled = true;
return "captured %s";
''' % (SHOT, SHOT)
        return run_code(b, code)


def measure_size(w, h, shot=False):
    with Bridge() as b:
        run_code(b, CLEAN)
        print("   spawn :", run_code(b, spawn(w, h)))
    time.sleep(0.35)
    with Bridge() as b:
        print("   show  :", run_lua(b, SHOW_LUA))
    time.sleep(0.45)
    with Bridge() as b:
        out = run_code(b, MEASURE)
    print(out)
    if shot:
        print("   shot  :", capture())


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    shot = "--shot" in sys.argv
    sizes = []
    for a in args:
        w, h = a.lower().split("x")
        sizes.append((int(w), int(h)))
    if not sizes:
        sizes = [(1080, 1920), (1080, 2220), (1440, 2960)]
    with Bridge() as b:
        print("[0 reload]", run_lua(b, RELOAD_LUA))
    for i, (w, h) in enumerate(sizes):
        print("[%d] %dx%d" % (i + 1, w, h))
        measure_size(w, h, shot=shot and (w, h) == sizes[-1])


if __name__ == "__main__":
    main()
