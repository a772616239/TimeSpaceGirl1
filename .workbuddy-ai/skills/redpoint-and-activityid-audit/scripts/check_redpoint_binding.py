#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
红点 / 活动档位 审计器（TimeSpaceGirl1 专用）

扫 Assets/ManagedResources/~Lua/**/*.lua，找四类反复出问题的模式。规则全部来自
Framework/Manager/UIManager.lua + Base/BasePanel.lua + Framework/Manager/SubUIManager.lua
的真实生命周期，不要凭直觉改：

  UIManager.OpenPanel  → 命中 openedList 缓存就复用，只走 AddListener→OnOpen→OnShow；
                         没命中才 reimport + CreateUI(Awake→InitComponent→BindEvent)。
  BasePanel.CloseUI    → RemoveListener→OnClose，**面板对象仍留在 openedList 里**，
                         所以下次打开不会再跑 InitComponent/BindEvent。
  BasePanel.DestroyUI  → OnDestroy，对象真销毁，下次打开重新 CreateUI。
  SubUIManager.Open    → 每次都 Instantiate 新 GameObject 并重新 New/Awake/InitComponent/
                         BindEvent/AddListener/OnOpen（**不走 OnShow**）。
  SubUIManager.Close   → RemoveListener + OnClose，**不销毁 GameObject**。
  RedpotManager.BindObject → table.insert，**不幂等**：同一物体重复绑 N 次，
                         RefreshRedObjectStatus 就会 SetActive N 遍。

由此得到判定表：

  A  绑定只在「一次性」函数里（InitComponent/BindEvent/Awake/ctor），清理却在
     OnClose/OnHide（可重复发生）⇒ 第一次关闭后 BindObjs 被清空且再也不会补回，
     红点值怎么变都刷不到 UI。**这是 OperatingPanel page_3 的原始 bug。**
     清理只写在 OnDestroy 里是安全的（销毁后下次打开会重跑 BindEvent，两者配平）。
     子视图（SubUIManager / contents 表驱动）只在「宿主把它关掉是可重复动作」时才报。

  A2 宿主（host）对子视图的 InitComponent 只调一次、却在切页/关闭时反复调 OnClose
     ⇒ 子视图里的「InitComponent 绑红点 + OnClose 清红点」同样会断。
     **ArenaTypePanel_TopMatch 就是这一类。** 只报「子视图真的绑了红点」的宿主。

  B  列表按 configInfo.ActivityId 过滤，但读状态/领奖却拿 IsActivityTypeOpen() 的
     返回值当 activityId。同一 ActivityType 下有多档（成长礼金 6/601/602/603/604）时
     两者不一致：GetActivityInfo 取到 nil，服务器 AbstractActivity.takeReward 校验
     config.ActivityId == 请求 activityId 不过会抛 CFG_NULL ⇒ 奖励不发、状态不变、
     红点留着、按钮还能再点。

  C  每次打开都绑、却从不清理 ⇒ BindObjs 线性增长，同一物体被 SetActive N 遍。

  D  ClearRedPointObject(type) 只传 type 不传 obj ⇒ 清掉**全局**该类型的所有绑定。
     若同一 rpType 还有别的活着的界面在绑，它的红点会被顺手清死。

用法：
  python3 check_redpoint_binding.py                 # 默认扫仓库根下的 ~Lua
  python3 check_redpoint_binding.py <lua_root>      # 指定 ~Lua 目录
  python3 check_redpoint_binding.py --json          # 机器可读输出
  python3 check_redpoint_binding.py --all           # 附 JSON 明细

退出码：0 无命中；1 有命中（可直接接 CI）。
"""

import json
import os
import re
import sys

# 只在面板/子视图「创建一次」时执行的函数（UIManager 缓存复用后不会再进来）
ONCE_FUNCS = {
    "InitComponent", "BindEvent", "Awake", "CreateUI", "ctor", "OnCreate",
    "Initialize", "InitData",
}
# 每次打开/切页都会执行到的函数
EVERY_FUNCS = {
    "OnShow", "OnOpen", "AddListener", "Refresh", "RefreshData", "OnTabChanged",
    "OnFocus", "Update", "SwitchView", "ChangeTab", "OnActivityProgress",
    "OnTabChange", "OnPageTabChange", "OnChangeTab", "OpenView", "ShowSShowwitchView",
}
# TabBox 适配器/回调是「每次 TabCtrl:Init / ChangeTab 都会被调」的，名字里带这些字样也算
EVERY_NAME_RE = re.compile(r"(Adapter|Callback|CallBack)")
# 关闭/隐藏（可重复发生，面板对象还在缓存里）
CLOSE_FUNCS = {"OnClose", "OnHide", "ClosePanel"}
# 销毁（一次性，销毁后下次打开会重新 CreateUI）
DESTROY_FUNCS = {"OnDestroy", "OnDestroyPanel", "DestroyUI"}

FUNC_RE = re.compile(r"^\s*(?:local\s+)?function\s+([\w.:]+)\s*\(", re.M)
ASSIGN_RE = re.compile(r"([\w.:]+)\s*=\s*SubUIManager\.Open\(\s*SubUIConfig\.(\w+)")
SUB_CLOSE_RE = re.compile(r"SubUIManager\.Close\(\s*([\w\.\[\]]+)\s*\)")
VIEW_REQ_RE = re.compile(r"view\s*=\s*require\(\s*[\"']([^\"']+)[\"']\s*\)")
SUBCFG_RE = re.compile(r"(\w+)\s*=\s*\{\s*name\s*=\s*\"[^\"]*\"\s*,\s*assetName\s*=\s*\"[^\"]*\"\s*,\s*script\s*=\s*\"([^\"]+)\"")

BIND_TYPE_RE = re.compile(r"BindRedPointObject\s*\(\s*RedPointType\.(\w+)")
CLEAR_TYPE_RE = re.compile(r"ClearRedPointObject\s*\(\s*RedPointType\.(\w+)\s*\)")


def split_functions(src):
    """按顶层 function 定义切块，返回 [(func_name, start, end, body)]。

    用「下一个 function 定义的位置」当块尾，足够应付本项目这种一个函数一屏的写法。
    """
    marks = [(m.start(), m.group(1)) for m in FUNC_RE.finditer(src)]
    blocks = []
    for i, (pos, name) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(src)
        blocks.append((name.split(":")[-1].split(".")[-1], pos, end, src[pos:end]))
    return blocks


def enclosing(blocks, offset):
    for name, start, end, body in blocks:
        if start <= offset < end:
            return name, body
    return None, ""


def call_map(blocks):
    """func -> 它直接调用的本文件内函数名集合。

    必须做这一步：项目里普遍是 OnClose -> ClearRedPoint -> ClearRedPointObject、
    BindEvent -> BindRedPoint -> BindRedPointObject 这种一层封装，
    只看「调用点所在函数」会把 OperatingPanel 这类真问题漏掉。
    """
    names = {b[0] for b in blocks}
    out = {}
    for name, _start, _end, body in blocks:
        called = set(re.findall(r"(?<![\w.:])(\w+)\s*\(", body)) & names
        out[name] = called
    return out


def expand(funcs, calls):
    """把函数集合按「直接调用」扩一层（够用，且不会过度扩散）。"""
    out = set(funcs)
    for f in funcs:
        out |= calls.get(f, set())
    return out


def is_every(names):
    for n in names:
        if n in EVERY_FUNCS or EVERY_NAME_RE.search(n or ""):
            return True
    return False


def tabbox_scope(src, blocks):
    """TabBox 适配器的真实执行频率：取决于 `tabCtrl:Init(...)` 写在哪个函数里。

    项目里 SetTabAdapter 常在 BindEvent 里注册，但 Init 可能在 OnShow（每次打开重建 tab）
    也可能就在 BindEvent（一辈子只建一次）——后者 + OnClose 清红点 = 红点卡死。
    返回 "every" / "once" / None（本文件没有 TabBox）。
    """
    vars_ = re.findall(r"([\w.:]+)\s*=\s*TabBox\.New\(\)", src)
    if not vars_:
        return None
    every = False
    for v in vars_:
        for m in re.finditer(re.escape(v) + r"\s*:\s*Init\s*\(", src):
            name, _ = enclosing(blocks, m.start())
            if name and is_every({name}):
                every = True
    return "every" if every else "once"


def sites(src, blocks, api):
    """返回调用 api 的函数名集合。"""
    out = set()
    for m in re.finditer(api + r"\s*\(", src):
        name, _ = enclosing(blocks, m.start())
        out.add(name or "<module>")
    return out


def profile(src):
    """单个文件的红点绑定画像。"""
    if "BindRedPointObject" not in src and "ClearRedPointObject" not in src:
        return None
    blocks = split_functions(src)
    calls = call_map(blocks)
    bind_funcs = sites(src, blocks, "BindRedPointObject")
    clear_funcs = sites(src, blocks, "ClearRedPointObject")
    bind_all = expand(bind_funcs, calls)
    clear_all = expand(clear_funcs, calls)
    # 同一个函数里先 Clear 再 Bind ⇒ 幂等重绑点，是正确写法
    rebind_site = {f for f in bind_funcs if f in clear_funcs}

    tb_scope = tabbox_scope(src, blocks)

    def eff_every(names):
        for n in names:
            if n in EVERY_FUNCS:
                return True
            if EVERY_NAME_RE.search(n or ""):
                if tb_scope == "once":
                    continue  # 适配器注册在一次性函数里，TabBox:Init 也只跑一次
                return True
        return False

    return {
        "blocks": blocks,
        "bind_funcs": bind_funcs,
        "clear_funcs": clear_funcs,
        "bind_all": bind_all,
        "clear_all": clear_all,
        "rebind_site": rebind_site,
        "binds_once": bool(bind_all) and not eff_every(bind_all),
        "binds_every": eff_every(bind_all),
        "clears_on_close": bool(clear_all & CLOSE_FUNCS) or "<module>" in clear_all,
        "clears_on_destroy": bool(clear_all & DESTROY_FUNCS),
        "has_bind": bool(bind_funcs),
    }


def scan_binding(rel, prof):
    """A / C 类。"""
    if not prof or not prof["has_bind"]:
        return []
    out = []
    if not prof["clear_funcs"] and prof["binds_every"]:
        out.append({
            "kind": "C_bind_never_cleared",
            "file": rel,
            "bind_funcs": sorted(prof["bind_funcs"]),
            "severity": "medium",
            "note": "每次打开都绑但从不清理，BindObjs 会线性增长",
        })
    if prof["binds_once"] and prof["clears_on_close"] and not prof["rebind_site"]:
        out.append({
            "kind": "A_binding_lifecycle",
            "file": rel,
            "bind_funcs": sorted(prof["bind_funcs"]),
            "clear_funcs": sorted(prof["clear_funcs"]),
            "severity": "high",
            "note": "OnDestroy 也清" if prof["clears_on_destroy"] else "",
        })
    return out


def scan_host_pairing(rel, src, profs, sub_of_host):
    """A2 类：宿主对子视图「初始化一次、关闭多次」，且子视图真的绑了红点。"""
    out = []
    prof = profs.get(rel)
    if not prof:
        return out
    blocks = prof["blocks"]

    for sub, open_funcs, close_funcs in sub_of_host.get(rel, []):
        sub_prof = profs.get(sub)
        if not sub_prof or not sub_prof["has_bind"]:
            continue
        if not (sub_prof["binds_once"] and sub_prof["clears_on_close"]):
            continue
        if is_every(open_funcs):
            continue  # 每次打开都重新初始化 ⇒ BindEvent 会重跑，安全
        if not is_every(close_funcs) and not (close_funcs & CLOSE_FUNCS):
            continue
        out.append({
            "kind": "A2_host_pairing",
            "file": rel,
            "sub": sub,
            "open_funcs": sorted(open_funcs),
            "close_funcs": sorted(close_funcs),
            "severity": "high",
            "note": "宿主 InitComponent 只跑一次，切页/关闭却反复调子视图 OnClose",
        })
    return out


ACT_OPEN_RE = re.compile(
    r"local\s+(\w+)\s*=\s*([^\n]*?IsActivityTypeOpen\s*\([^\n]*)")
GET_INFO_RE = re.compile(r"GetActivityInfo\s*\(\s*([\w.\[\]]+)\s*,")
SET_INFO_RE = re.compile(r"SetActivityInfo\s*\(\s*([\w.\[\]]+)\s*,")
REQ_RE = re.compile(r"GetActivityRewardRequest\s*\(\s*[^,]+,\s*([\w.\[\]()]+)")


def scan_activityid(rel, src, prof):
    """B 类：档位错配。"""
    if "IsActivityTypeOpen" not in src:
        return []
    # 只有「按 ActivityId 过滤配置」的页面才可能出现档位错配
    if not re.search(r"ActivityId\s*==|\[\s*\"ActivityId\"\s*\]|,\s*\"ActivityId\"\s*,", src):
        return []

    derived = {}
    for m in ACT_OPEN_RE.finditer(src):
        var, rhs = m.group(1), m.group(2)
        # `data.ActivityId or IsActivityTypeOpen(...)` 是修复后的正确写法：优先用行自带的档位
        if "ActivityId" in rhs:
            continue
        derived[var] = m.start()
    if not derived:
        return []

    blocks = prof["blocks"] if prof else split_functions(src)
    hits = []
    for regex, api in ((GET_INFO_RE, "GetActivityInfo"),
                       (SET_INFO_RE, "SetActivityInfo"),
                       (REQ_RE, "GetActivityRewardRequest")):
        for m in regex.finditer(src):
            arg = m.group(1).strip()
            if arg not in derived:
                continue
            _name, body = enclosing(blocks, m.start())
            # 同一个函数里用 `ActivityId == var` 过滤后再拿 var 查 ⇒ 内部自洽，不算错配
            if re.search(r"ActivityId\s*==\s*" + re.escape(arg) + r"\b", body):
                continue
            # `var == 16` 这类把 var 钉死成具体档位的守卫，也自洽
            if re.search(re.escape(arg) + r"\s*==\s*\d+", body):
                continue
            hits.append({
                "api": api,
                "arg": arg,
                "line": src[:m.start()].count("\n") + 1,
            })
    if hits:
        return [{
            "kind": "B_activityid_mismatch",
            "file": rel,
            "derived": sorted(derived),
            "hits": hits,
            "severity": "high",
        }]
    return []


def as_rel(script):
    """require 路径 / SubUIConfig.script -> ~Lua 下的相对文件名。"""
    script = script.strip()
    if script.endswith(".lua"):
        return script
    return script + ".lua"


def collect_host_refs(rel, src, subcfg):
    """解析宿主对子视图的 open/close 调用，返回 [(sub_rel, open_funcs, close_funcs)]。"""
    blocks = split_functions(src)
    if not blocks:
        return []
    refs = []

    # --- 写法 1：var = SubUIManager.Open(SubUIConfig.X, ...) / SubUIManager.Close(var) ---
    var2sub = {}
    for m in ASSIGN_RE.finditer(src):
        var2sub[m.group(1)] = as_rel(subcfg.get(m.group(2), m.group(2)))
    if var2sub:
        opens, closes = {}, {}
        for m in ASSIGN_RE.finditer(src):
            name, _ = enclosing(blocks, m.start())
            opens.setdefault(as_rel(subcfg.get(m.group(2), m.group(2))), set()).add(name or "<module>")
        for m in SUB_CLOSE_RE.finditer(src):
            sub = var2sub.get(m.group(1))
            if not sub:
                continue
            name, _ = enclosing(blocks, m.start())
            closes.setdefault(sub, set()).add(name or "<module>")
        for sub, cf in closes.items():
            refs.append((sub, opens.get(sub, set()), cf))

    # --- 写法 2：contents 表 + require 的子模块，宿主直接调 view:InitComponent / view:OnClose ---
    subs = VIEW_REQ_RE.findall(src)
    if subs:
        init_funcs, close_funcs = set(), set()
        for m in re.finditer(r":\s*InitComponent\s*\(", src):
            name, _ = enclosing(blocks, m.start())
            init_funcs.add(name or "<module>")
        for m in re.finditer(r":\s*OnClose\s*\(", src):
            name, _ = enclosing(blocks, m.start())
            close_funcs.add(name or "<module>")
        if init_funcs:
            for sub in set(subs):
                refs.append((as_rel(sub), init_funcs, close_funcs))
    return refs


def scan_global_clear(rel, src, bind_owner):
    """D 类：ClearRedPointObject(type) 不带 obj，会清掉全局该类型的所有绑定。"""
    out = []
    for m in CLEAR_TYPE_RE.finditer(src):
        rp = m.group(1)
        owners = bind_owner.get(rp, set())
        if len(owners) < 2 or rel not in owners:
            continue
        out.append({
            "kind": "D_global_clear",
            "file": rel,
            "rp_type": rp,
            "line": src[:m.start()].count("\n") + 1,
            "owners": sorted(owners),
            "severity": "medium",
            "note": "同一 rpType 有 %d 个文件在绑，这里不传 obj 会全部清掉" % len(owners),
        })
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    as_json = "--json" in sys.argv
    show_all = "--all" in sys.argv

    root = args[0] if args else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..",
        "Assets", "ManagedResources", "~Lua")
    root = os.path.abspath(root)
    if not os.path.isdir(root):
        print("找不到 Lua 根目录：%s" % root, file=sys.stderr)
        return 2

    sources, profs = {}, {}
    for dirpath, _dirnames, filenames in os.walk(root):
        for fn in sorted(filenames):
            if not fn.endswith(".lua"):
                continue
            path = os.path.join(dirpath, fn)
            try:
                src = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            rel = os.path.relpath(path, root)
            sources[rel] = src
            p = profile(src)
            if p:
                profs[rel] = p

    # SubUIConfig：名字 -> 脚本路径（相对 ~Lua，去掉 .lua）
    subcfg = {}
    for src in sources.values():
        for name, script in SUBCFG_RE.findall(src):
            subcfg[name] = script

    # 宿主 -> 子视图引用
    host_refs = {}
    for rel, src in sources.items():
        refs = collect_host_refs(rel, src, subcfg)
        if refs:
            host_refs[rel] = refs

    # 哪些文件是「被别人当子视图用」的
    is_subview = set()
    for refs in host_refs.values():
        for sub, _o, _c in refs:
            is_subview.add(sub)

    # 子视图被宿主「可重复关闭」的集合
    sub_closed_repeatably = set()
    for refs in host_refs.values():
        for sub, open_funcs, close_funcs in refs:
            if is_every(open_funcs):
                continue
            if is_every(close_funcs) or (close_funcs & CLOSE_FUNCS):
                sub_closed_repeatably.add(sub)

    # 每个 rpType 被哪些文件绑（D 类用）
    bind_owner = {}
    for rel, src in sources.items():
        for m in BIND_TYPE_RE.finditer(src):
            bind_owner.setdefault(m.group(1), set()).add(rel)

    findings = []
    for rel, src in sources.items():
        prof = profs.get(rel)
        a = scan_binding(rel, prof)
        # 子视图的 A 类只在「宿主真的会重复关它」时才算数（否则 bind/clear 都是实例级，配平）
        if rel in is_subview and rel not in sub_closed_repeatably:
            a = [f for f in a if f["kind"] != "A_binding_lifecycle"]
        findings.extend(a)
        findings.extend(scan_host_pairing(rel, src, profs, host_refs))
        findings.extend(scan_activityid(rel, src, prof))
        findings.extend(scan_global_clear(rel, src, bind_owner))

    if as_json:
        print(json.dumps(findings, ensure_ascii=False, indent=2))
        return 1 if findings else 0

    a = [f for f in findings if f["kind"] == "A_binding_lifecycle"]
    a2 = [f for f in findings if f["kind"] == "A2_host_pairing"]
    b = [f for f in findings if f["kind"] == "B_activityid_mismatch"]
    c = [f for f in findings if f["kind"] == "C_bind_never_cleared"]
    d = [f for f in findings if f["kind"] == "D_global_clear"]

    print("== A. 绑定只在初始化里做、OnClose/OnHide 却清空（重开后红点卡死）==")
    if not a:
        print("   （无）")
    for f in sorted(a, key=lambda x: x["file"]):
        print("   [高危] %-56s bind=%s clear=%s %s" % (
            f["file"], ",".join(f["bind_funcs"]), ",".join(f["clear_funcs"]), f.get("note", "")))

    print("\n== A2. 宿主对子视图「初始化一次、关闭多次」（子视图红点同样会断）==")
    if not a2:
        print("   （无）")
    for f in sorted(a2, key=lambda x: x["file"]):
        print("   [高危] %-56s sub=%s" % (f["file"], f["sub"]))
        print("          open=%s  close=%s" % (",".join(f["open_funcs"]), ",".join(f["close_funcs"])))

    print("\n== B. 领奖/读状态用 IsActivityTypeOpen 的返回值当 activityId（多档位活动会错配）==")
    if not b:
        print("   （无）")
    for f in sorted(b, key=lambda x: x["file"]):
        print("   %s   derived=%s" % (f["file"], ",".join(f["derived"])))
        for h in f["hits"]:
            print("      L%-5s %s(arg=%s)" % (h["line"], h["api"], h["arg"]))

    print("\n== C. 每次打开都绑、却从不清理（BindObjs 无限增长 / 同一物体被绑多次）==")
    if not c:
        print("   （无）")
    for f in sorted(c, key=lambda x: x["file"]):
        print("   %-58s bind=%s" % (f["file"], ",".join(f["bind_funcs"])))

    print("\n== D. ClearRedPointObject(type) 不带 obj，清掉全局同类型绑定 ==")
    if not d:
        print("   （无）")
    for f in sorted(d, key=lambda x: (x["rp_type"], x["file"])):
        print("   %-56s L%-5s %s  同类型绑定方=%d" % (
            f["file"], f["line"], f["rp_type"], len(f["owners"])))

    print("\n共 %d 处命中（A=%d，A2=%d，B=%d，C=%d，D=%d）" % (
        len(findings), len(a), len(a2), len(b), len(c), len(d)))
    if show_all:
        print("\n-- 明细 --")
        print(json.dumps(findings, ensure_ascii=False, indent=2))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
