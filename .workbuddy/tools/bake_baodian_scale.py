#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 UI_effect_GuaJi_Box_BaoDian（挂机宝箱开箱打击特效）整体缩到 SCALE 倍。

结构（探针实测）：
  UI_effect_GuaJi_Box_BaoDian            <- 容器，保持 1（自身世界坐标被当 DOMove 目标）
    partical_click1..5   PS scale=0.2513  ScalingMode=Local  <- 只认自己 transform
      lizi slow / fast / JB / guangbo     ScalingMode=Shape  <- 只缩发射形状，粒子尺寸只认 startSize

所以：
  * partical_clickX 的 localScale *= SCALE   -> Local 那颗的尺寸/速度/形状全跟着缩
  * 子节点 Shape 颗的 startSize / startSpeed / ClampVelocity.magnitude *= SCALE
    （发射形状由父级 transform 自动缩，不再动 shape radius，否则会缩两次）
  * 容器本身保持 1：① FightPointMapOnHook.SetEffect 里 boxEffectParent.transform.position
    直接当战利品线的 DOMove 终点；② 5 个 click 是 ScalingMode=Local（忽略父级 transform），
    所以改容器的 transform 缩放对粒子完全没反应 —— 这就是"改 transform 没生效"的原因。

FROM_SCALE = 当前已烘焙的倍率（0.6），SCALE = 目标倍率。脚本按 SCALE/FROM_SCALE 增量乘，
重复跑会被期望值断言拦住（改完把 FROM_SCALE 一起改掉才能再跑）。
"""
import re
import sys

FROM_SCALE = 0.6   # 当前资源里的倍率（上次烘焙的结果）
SCALE = 0.7        # 目标倍率
PANEL = "Assets/ManagedResources/Prefabs/UI/Fight/FightPointPassMainPanel.prefab"

# 原始（1.0 倍）基准值；期望值 = 原始 * FROM_SCALE，用来防止重复执行
ORIG_ROOT_SCALE = 0.25133514
ORIG_SIZE = {"lizi slow": (3.0, 1.0), "lizi fast": (0.5, 0.1),
             "lizi JB": (0.1, 0.2), "guangbo": (1.5, 0.0)}
ORIG_SPEED = {"lizi slow": (15.0, 5.0), "lizi fast": (50.0, 10.0),
              "lizi JB": (2.0, 1.0), "guangbo": (0.0, 0.0)}

FACTOR = SCALE / FROM_SCALE
EXPECT_ROOT_SCALE = ORIG_ROOT_SCALE * FROM_SCALE
EXPECT_SIZE = {k: (v[0] * FROM_SCALE, v[1] * FROM_SCALE) for k, v in ORIG_SIZE.items()}
EXPECT_SPEED = {k: (v[0] * FROM_SCALE, v[1] * FROM_SCALE) for k, v in ORIG_SPEED.items()}


def fmt(v):
    s = ("%.7f" % v).rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def doc_spans(txt):
    out = {}
    marks = [(m.start(), m.group(1), m.group(2)) for m in
             re.finditer(r"^--- !u!(\d+) &(\d+)\n", txt, re.M)]
    for i, (pos, cls, fid) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(txt)
        out[fid] = (cls, pos, end)
    return out


def go_names(txt, spans):
    names = {}
    for fid, (cls, s, e) in spans.items():
        if cls != "1":
            continue
        m = re.search(r"^  m_Name: (.*)$", txt[s:e], re.M)
        names[fid] = m.group(1) if m else ""
    return names


def subtree_transforms(txt, spans, names, root_name):
    """返回 (根 RT/Transform fid, [(go_fid, name, rt_fid)])，按层级顺序。"""
    rt_of_go = {}
    kids = {}
    go_of_rt = {}
    for fid, (cls, s, e) in spans.items():
        if cls not in ("4", "224"):
            continue
        block = txt[s:e]
        g = re.search(r"\n  m_GameObject: \{fileID: (\d+)\}", block)
        if not g:
            continue
        go_of_rt[fid] = g.group(1)
        rt_of_go[g.group(1)] = fid
        seg = block.split("m_Children:")[1].split("m_Father:")[0] if "m_Children:" in block else ""
        kids[fid] = re.findall(r"- \{fileID: (\d+)\}", seg)

    root_go = next((k for k, v in names.items() if v == root_name), None)
    if root_go is None:
        raise SystemExit("未找到节点 %s" % root_name)
    root_rt = rt_of_go[root_go]
    out = [(root_go, root_name, root_rt)]
    stack = [root_rt]
    while stack:
        rt = stack.pop(0)
        for child_rt in kids.get(rt, []):
            if child_rt not in go_of_rt:
                continue
            g = go_of_rt[child_rt]
            out.append((g, names.get(g, "?"), child_rt))
            stack.append(child_rt)
    return root_rt, out


def mul_local_scale(txt, spans, rt_fid, factor):
    cls, s, e = spans[rt_fid]
    block = txt[s:e]
    m = re.search(r"(\n  m_LocalScale: \{x: )([-\d.eE]+)(, y: )([-\d.eE]+)(, z: )([-\d.eE]+)(\})", block)
    if not m:
        raise SystemExit("localScale 缺失 %s" % rt_fid)
    old = float(m.group(2))
    if abs(old - EXPECT_ROOT_SCALE) > 1e-5:
        raise SystemExit("%s 的 scale 已经是 %s，疑似重复执行" % (rt_fid, old))
    new = fmt(old * factor)
    block = (block[:m.start()] + m.group(1) + new + m.group(3) + new
             + m.group(5) + new + m.group(7) + block[m.end():])
    return txt[:s] + block + txt[e:]


def mul_subvalue(txt, spans, ps_fid, key, factor, expect):
    """把 InitialModule 里某个 MinMaxCurve 的 scalar/minScalar 同乘。"""
    cls, s, e = spans[ps_fid]
    block = txt[s:e]
    hdr = "\n    %s:\n" % key
    i = block.find(hdr)
    if i < 0:
        raise SystemExit("%s 没有 %s" % (ps_fid, key))
    start = i + len(hdr)
    nxt = re.search(r"\n    [A-Za-z]", block[start:])
    end = start + (nxt.start() if nxt else len(block) - start)
    sub = block[start:end]

    cur = re.search(r"\n      scalar: ([-\d.eE]+)", sub)
    curmin = re.search(r"\n      minScalar: ([-\d.eE]+)", sub)
    if not cur:
        raise SystemExit("%s.%s 无 scalar" % (ps_fid, key))
    if expect is not None:
        got = (float(cur.group(1)), float(curmin.group(1)) if curmin else 0.0)
        if abs(got[0] - expect[0]) > 1e-5 or abs(got[1] - expect[1]) > 1e-5:
            raise SystemExit("%s.%s 当前 %s != 期望 %s，疑似重复执行" % (ps_fid, key, got, expect))

    def rep(mm):
        return mm.group(1) + fmt(float(mm.group(2)) * factor)

    sub2 = re.subn(r"(\n      scalar: )([-\d.eE]+)", rep, sub, count=1)[0]
    sub2 = re.subn(r"(\n      minScalar: )([-\d.eE]+)", rep, sub2, count=1)[0]
    return txt[:s] + block[:start] + sub2 + block[end:] + txt[e:]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else PANEL
    txt = open(path, encoding="utf-8").read()
    spans = doc_spans(txt)
    names = go_names(txt, spans)
    _, nodes = subtree_transforms(txt, spans, names, "UI_effect_GuaJi_Box_BaoDian")

    # 1) 5 个 partical_clickN：Local 模式，缩自己的 transform
    click_roots = [(g, n, rt) for g, n, rt in nodes if re.match(r"^partical_click\d$", n)]
    if len(click_roots) != 5:
        raise SystemExit("partical_click 数量异常: %d" % len(click_roots))
    for g, n, rt in click_roots:
        txt = mul_local_scale(txt, spans, rt, FACTOR)
        spans = doc_spans(txt)
        print("scale  %-14s %s -> %s" % (n, fmt(EXPECT_ROOT_SCALE), fmt(EXPECT_ROOT_SCALE * FACTOR)))

    # 2) Shape 模式的子粒子：startSize / startSpeed / clamp magnitude
    spans = doc_spans(txt)
    names = go_names(txt, spans)
    _, nodes = subtree_transforms(txt, spans, names, "UI_effect_GuaJi_Box_BaoDian")
    counted = 0
    for g, n, rt in nodes:
        if n not in EXPECT_SIZE:
            continue
        ps_fid = None
        for c in re.findall(r"component: \{fileID: (\d+)\}",
                            txt[spans[g][1]:spans[g][2]] if g in spans else ""):
            if c in spans and spans[c][0] == "198":
                ps_fid = c
                break
        if ps_fid is None:
            continue
        mode = re.search(r"\n  scalingMode: (\d+)", txt[spans[ps_fid][1]:spans[ps_fid][2]])
        if not mode or mode.group(1) != "2":
            raise SystemExit("%s 不是 Shape 模式（%s）" % (n, mode.group(1) if mode else "?"))
        txt = mul_subvalue(txt, spans, ps_fid, "startSize", FACTOR, EXPECT_SIZE[n])
        spans = doc_spans(txt)
        txt = mul_subvalue(txt, spans, ps_fid, "startSpeed", FACTOR, EXPECT_SPEED[n])
        spans = doc_spans(txt)
        # 限速模块启用时它的上限是绝对速度，也要一起缩，否则位移不变
        block = txt[spans[ps_fid][1]:spans[ps_fid][2]]
        seg = re.search(r"\n  ClampVelocityModule:\n(.*?)(?=\n  \w+:|\Z)", block, re.S)
        if seg and re.search(r"(?:^|\n)\s*enabled: 1", seg.group(1)):
            txt = mul_subvalue(txt, spans, ps_fid, "magnitude", FACTOR, None)
            spans = doc_spans(txt)
        counted += 1
        print("ps     %-14s startSize %s->%s  speed %s->%s" % (
            n, EXPECT_SIZE[n], (EXPECT_SIZE[n][0] * FACTOR, EXPECT_SIZE[n][1] * FACTOR),
            EXPECT_SPEED[n], (EXPECT_SPEED[n][0] * FACTOR, EXPECT_SPEED[n][1] * FACTOR)))

    if counted != 20:
        raise SystemExit("Shape 粒子数异常: %d（应为 20）" % counted)
    open(path, "w", encoding="utf-8").write(txt)
    print("done: 5 组 × 5 粒子")


if __name__ == "__main__":
    sys.exit(main())
