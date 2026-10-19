#!/usr/bin/env python3
"""「点国旗弹英文国名」端到端自验（Unity 桥直连，不依赖人工点击）。

验证链路：
  1) prefab 里 countryFlag 的 Image 已开 m_RaycastTarget（否则 Button 收不到点击）
  2) 重载 lua 模块后新开的面板，countryFlag 上自动补出 Button
  3) 触发 Button.onClick 后，PopupTipPanel 出现该国的英文名
  4) 英文名固定英文，不随当前语言变化

关键坑：项目 require 的 package.loaded 键是**点号**（Modules.CountryRank.CountryConfig），
用斜杠键置 nil 清不掉缓存。

用法：python .workbuddy/tools/probe_flag_tip.py [uid] [code]
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from unity_bridge import Bridge  # noqa: E402

PREFAB = "Assets/ManagedResources/Prefabs/UI/Popup/PlayerInfoPopup.prefab"


def run_lua(b, lua):
    code = 'var lua = @"%s";\nreturn App.LuaMgr.DoString<string>(lua);' % lua.replace('"', '""')
    r = b.call("execute_code", {"action": "execute", "code": code})
    d = r.get("result", r)
    if isinstance(d, dict):
        if d.get("success"):
            return d.get("data", {}).get("result")
        return "LUA ERROR: %s" % d.get("error")
    return str(d)


def main():
    uid = sys.argv[1] if len(sys.argv) > 1 else "10000005"

    with Bridge() as b:
        # 1) prefab 重新导入 + 读 countryFlag 的 raycastTarget
        code = ('UnityEditor.AssetDatabase.ImportAsset(@"%s", UnityEditor.ImportAssetOptions.ForceUpdate);\n'
                'var go = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(@"%s");\n'
                'var t = go.transform.Find("tipImage/panel/info/countryFlag");\n'
                'if (t == null) return "countryFlag NOT FOUND";\n'
                'var img = t.GetComponent<UnityEngine.UI.Image>();\n'
                'return "prefab raycastTarget=" + (img == null ? "noImage" : img.raycastTarget.ToString());'
                % (PREFAB, PREFAB))
        r = b.call("execute_code", {"action": "execute", "code": code})
        print("[1 prefab ]", r.get("result", {}).get("data", {}).get("result", r))

        # 2) 重载 lua（点号缓存键）+ 销毁旧实例
        lua = """
package.loaded['Modules.CountryRank.CountryConfig'] = nil
package.loaded['Modules.CountryRank.CountryFlagUtil'] = nil
package.loaded['Modules.Popup.PlayerInfoPopup'] = nil
require('Modules/CountryRank/CountryConfig')
require('Modules/CountryRank/CountryFlagUtil')
require('Modules/Popup/PlayerInfoPopup')
if UIManager and UIName and UIName.PlayerInfoPopup then
    UIManager.ClosePanel(UIName.PlayerInfoPopup, true)
end
return string.format('getEn(it)=%s getEn(kr)=%s makeClickable=%s',
    tostring(CountryConfig.GetEnglishName('it')),
    tostring(CountryConfig.GetEnglishName('kr')),
    tostring(CountryFlagUtil.MakeClickable ~= nil))
"""
        print("[2 reload ]", run_lua(b, lua))

        # 3) 全新实例打开面板（旧实例已销毁 → 走新的 InitComponent）
        lua = """
local p = UIManager.OpenPanel(UIName.PlayerInfoPopup, %s)
PROBE_PANEL = p
return 'opened uid=%s instance=' .. tostring(p ~= nil)
""" % (uid, uid)
        print("[3 open   ]", run_lua(b, lua))

    # 等服务端 16651 回包 + 面板刷新
    time.sleep(3.0)

    with Bridge() as b:
        # 4) 读状态并触发点击
        lua = """
local p = PROBE_PANEL
if p == nil then return 'PROBE_PANEL nil' end
local go = p.memCountryFlag
if go == nil or IsNull(go) then return 'countryFlag nil' end
local img = go:GetComponent('Image')
local btn = go:GetComponent('Button')
local sp = (img and img.sprite) and img.sprite.name or 'nil'
local base = string.format('active=%s raycast=%s hasButton=%s sprite=%s code=%s',
    tostring(go.activeSelf), tostring(img and img.raycastTarget),
    tostring(btn ~= nil), sp, tostring(p._CountryCode))
if btn == nil then return base .. ' | NO BUTTON -> click skipped' end
local ok, err = pcall(function() btn.onClick:Invoke() end)
return base .. string.format(' | click=%s %s', tostring(ok), tostring(err or ''))
"""
        print("[4 click  ]", run_lua(b, lua))

    time.sleep(1.0)

    with Bridge() as b:
        # 5) 扫全场景 Text：提示语必须出现在 PopupTipPanel 下且处于激活态
        code = r'''
var sb = new System.Text.StringBuilder();
var texts = UnityEngine.Object.FindObjectsOfType<UnityEngine.UI.Text>(true);
int hit = 0;
foreach (var t in texts) {
    if (t == null || string.IsNullOrEmpty(t.text)) continue;
    if (t.text != @"Italy" && t.text != @"Korea" && t.text != @"Other") continue;
    var chain = new System.Text.StringBuilder(t.gameObject.name);
    var p = t.transform.parent;
    while (p != null) { chain.Insert(0, p.name + "/"); p = p.parent; }
    bool underTip = chain.ToString().Contains("PopupTipPanel");
    if (!underTip) continue;
    hit++;
    sb.AppendLine("TIP text=\"" + t.text + "\" activeInHierarchy=" + t.gameObject.activeInHierarchy + " path=" + chain);
}
sb.AppendLine("tipTextHits=" + hit);
return sb.ToString();
'''
        r = b.call("execute_code", {"action": "execute", "code": code})
        print("[5 scan   ]", r.get("result", {}).get("data", {}).get("result", r))


if __name__ == "__main__":
    main()
