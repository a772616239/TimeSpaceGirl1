#!/usr/bin/env python3
"""把 .anim / .controller 读成「分镜表」—— 参考动画复刻流程 S0 的工具。

为什么单独做一个：手工 grep 往往只查 m_ScaleCurves，而 UI 上看得见的位移（anchoredPosition）、
展开收起（sizeDelta）、淡入淡出（m_Color.a）全在 m_FloatCurves 里。只读一段 = 交付后被打回。

用法:
    python3 dump_clip.py <clip.anim> [clip2.anim ...]          # 每条曲线的 path/通道/首末值/时长
    python3 dump_clip.py <clip.anim> --keys                    # 附带全部关键帧
    python3 dump_clip.py <controller.controller>               # 状态机里有哪几个 state、各绑哪个 clip
    python3 dump_clip.py <clip.anim> --json                    # 机器可读

输出每行: [段] path | 通道 | k0 → kN | 0 → 0.3667s | loop=1
  「段」= m_PositionCurves / m_EulerCurves / m_RotationCurves / m_ScaleCurves / m_FloatCurves
  末尾会打一行自检: 各段条数 + m_EditorCurves 镜像条数（不等 ⇒ 还有段没读到）
"""
import json
import re
import sys

SECTIONS = [
    ("m_PositionCurves", "position"),
    ("m_EulerCurves", "euler"),
    ("m_RotationCurves", "rotation"),
    ("m_ScaleCurves", "scale"),
    ("m_FloatCurves", "float"),
]

# 段名 -> 通道名（m_FloatCurves 的 attribute 本来就只有通道名）
VEC_ATTR = {
    "position": "m_LocalPosition",
    "euler": "m_LocalEulerAngles",
    "rotation": "m_LocalRotation",
    "scale": "m_LocalScale",
}


def _scalar(v):
    """把 YAML 里的标量/向量写法转成可比较的元组或数字。"""
    v = v.strip()
    if v.startswith("{"):
        d = {}
        for k, val in re.findall(r"(\w+):\s*(-?[\d.eE+-]+)", v):
            d[k] = float(val)
        return d
    try:
        return float(v)
    except ValueError:
        return v


def _fmt(v):
    if isinstance(v, dict):
        # 只打有变化的轴向，省得噪声
        return "(" + ", ".join(f"{k}={v[k]:g}" for k in ("x", "y", "z", "w") if k in v) + ")"
    if isinstance(v, float):
        return f"{v:g}"
    return str(v)


def _body_of_section(text, name):
    """取 `  <name>:` 到下一个同级键之间的文本。"""
    m = re.search(r"^  " + re.escape(name) + r":[^\n]*\n", text, re.M)
    if not m:
        return None
    start = m.end()
    nxt = re.search(r"^  [A-Za-z_]+", text[start:], re.M)
    return text[start:start + nxt.start()] if nxt else text[start:]


def _entries(body):
    """按 `  - curve:` 切条目。"""
    if body is None:
        return []
    if body.strip() in ("[]", ""):
        return []
    parts = re.split(r"^  - curve:", body, flags=re.M)
    return [p for p in parts[1:] if p.strip()]


def _keys(entry):
    out = []
    for km in re.finditer(
        r"^\s*- serializedVersion: \d+\n\s*time: (-?[\d.eE+]+)\n\s*value: (.+)\n", entry, re.M
    ):
        out.append((float(km.group(1)), _scalar(km.group(2))))
    return out


def parse_clip(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    name = re.search(r"^  m_Name: (.*)$", text, re.M)
    settings = _body_of_section(text, "m_AnimationClipSettings") or ""
    loop = re.search(r"^    m_LoopTime: (\d)", settings, re.M)
    stop = re.search(r"^    m_StopTime: ([\d.eE+-]+)", settings, re.M)
    legacy = re.search(r"^  m_Legacy: (\d)", text, re.M)
    sample = re.search(r"^  m_SampleRate: ([\d.eE+-]+)", text, re.M)

    curves = []
    counts = {}
    for sec, kind in SECTIONS:
        body = _body_of_section(text, sec)
        ents = _entries(body)
        counts[sec] = len(ents)
        for e in ents:
            p = re.search(r"^    path: (.*)$", e, re.M)
            a = re.search(r"^    attribute: (.*)$", e, re.M)
            attr = a.group(1).strip() if a else VEC_ATTR.get(kind, kind)
            curves.append({
                "section": sec,
                "kind": kind,
                "path": p.group(1).strip() if p else "",
                "attr": attr,
                "keys": _keys(e),
            })

    editor = _entries(_body_of_section(text, "m_EditorCurves"))
    consts = _entries(_body_of_section(text, "m_ClipBindingConstant"))
    bindings = []
    for e in consts:
        # genericBindings 的条目形如 - path: 123 / attribute: 3 / typeID: 4
        bm = re.search(r"^      - path: (-?\d+)$", e, re.M) or re.search(r"^\s*- path: (-?\d+)$", e, re.M)
        if bm:
            bindings.append(e)

    return {
        "file": path,
        "name": name.group(1).strip() if name else "",
        "legacy": int(legacy.group(1)) if legacy else None,
        "sampleRate": float(sample.group(1)) if sample else None,
        "loop": int(loop.group(1)) if loop else None,
        "stopTime": float(stop.group(1)) if stop else None,
        "curves": curves,
        "counts": counts,
        "editorCount": len(editor),
        "bindingBlock": len(bindings),
    }


def parse_controller(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    states = []
    # m_AnimationClipSettings 不重要；state 形如 - serializedVersion: 5 ... m_Name: start
    for m in re.finditer(r"^    - serializedVersion: \d+\n((?:      .*\n)+?)(?=^    - serializedVersion:|\Z)", text, re.M):
        blk = m.group(1)
        nm = re.search(r"^      m_Name: (.*)$", blk, re.M)
        clip = re.search(r"^      m_Motion: \{fileID: (\d+), guid: (\w+)", blk, re.M)
        if nm:
            states.append({
                "name": nm.group(1).strip(),
                "clipFileID": clip.group(1) if clip else None,
                "clipGuid": clip.group(2) if clip else None,
            })
    return {"file": path, "states": states}


def report(clip, show_keys=False):
    print(f"== {clip['name']}  legacy={clip['legacy']}  loop={clip['loop']}  "
          f"stop={clip['stopTime']}s  sampleRate={clip['sampleRate']}")
    if not clip["curves"]:
        print("  (没有向量/浮点曲线)")
    for c in clip["curves"]:
        ks = c["keys"]
        if not ks:
            continue
        first, last = ks[0][1], ks[-1][1]
        dur = ks[-1][0] - ks[0][0]
        flag = "" if _fmt(first) == _fmt(last) else "   ← 首尾不同（当循环用会跳；错开入场属正常）"
        print(f"  [{c['kind']:8s}] {c['path'] or '<self>':46s} {c['attr']:22s} "
              f"{_fmt(first)} → {_fmt(last)}   {dur:g}s  n={len(ks)}{flag}")
        if show_keys:
            print("             " + " / ".join(f"{t:g}:{_fmt(v)}" for t, v in ks))
    total = sum(clip["counts"].values())
    # m_EditorCurves 是按轴展开的镜像：向量曲线 3 条（rotation 4 条），float 曲线 1 条
    axis = {"rotation": 4, "float": 1}
    expect = sum(axis.get(c["kind"], 3) for c in clip["curves"])
    print(f"  条数: " + "  ".join(f"{k.replace('m_', '').replace('Curves', '')}={v}"
                                 for k, v in clip["counts"].items() if v)
          + f"  | 合计 {total}  |  m_EditorCurves 镜像 {clip['editorCount']}（按轴折算应为 {expect}）"
          + ("" if expect == clip["editorCount"] or total == 0 else "   ← 不等，可能还有段没读到"))
    if clip["bindingBlock"]:
        print(f"  genericBindings 条目 {clip['bindingBlock']}")
    print()


def main(argv):
    show_keys = "--keys" in argv
    as_json = "--json" in argv
    files = [a for a in argv[1:] if not a.startswith("--")]
    if not files:
        print(__doc__)
        return 2
    out = []
    for f in files:
        if f.endswith(".controller"):
            info = parse_controller(f)
            print(f"== {f}（controller）")
            for s in info["states"]:
                print(f"  state {s['name']:16s} clip={s['clipFileID']} guid={s['clipGuid']}")
            print()
            out.append(info)
        else:
            info = parse_clip(f)
            report(info, show_keys)
            out.append(info)
    if as_json:
        print(json.dumps(out, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
