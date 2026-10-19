#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给**聊天消息气泡**的名字旁加国家小旗节点（ChatPanel.prefab）。

  content/chat/leftchat/contentroot/bg/info/name/countryFlag    别人的消息
  content/chat/rightchat/contentroot/bg/info/name/countryFlag   自己的消息（镜像到右侧）

为什么放在 name 容器里而不是 info 下：
  info 这一行是 title | name | pos 紧贴排满的（0..178 / 178..466 / 466..553），
  没有空位塞旗。name 容器宽 288、名字 Text 只有单行且靠一侧对齐（左聊 pivot 左、
  右聊 pivot 右），把旗放进容器并把这侧的名字顶开 50px 即可，既有留白够用。

幂等：已有 countryFlag 就直接跳过（不重复插、不重复挪名字）。
"""
import hashlib
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFAB = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/Chat/ChatPanel.prefab")
NODE_NAME = "countryFlag"

FLAG_W, FLAG_H = 46, 32     # 名字行高 66、字号 26，旗子取 46x32
GAP = 4                     # 旗与名字之间的间隔
SHIFT = FLAG_W + GAP + 2    # 名字要让开的距离

# side -> (锚点/轴心/位置, 名字 Text 的 x 新值)
LAYOUT = {
    "leftchat": dict(anchor=(0, 0.5), pivot=(0, 0.5), pos=(GAP, 0), text_x=SHIFT),
    "rightchat": dict(anchor=(1, 0.5), pivot=(1, 0.5), pos=(-GAP, 0), text_x=-SHIFT),
}


def new_id(seed):
    h = hashlib.md5(("TimeSpaceGirl1/ChatFlag/" + seed).encode()).hexdigest()
    return str(int(h[:15], 16) + 500000000000000000)


def parse(txt):
    docs = re.split(r"^--- !u!(\d+) &(-?\d+)", txt, flags=re.M)
    head = docs[0]
    objs = {}
    order = []
    i = 1
    while i < len(docs):
        oid = docs[i + 1]
        objs[oid] = [int(docs[i]), docs[i + 2] if i + 2 < len(docs) else ""]
        order.append(oid)
        i += 3
    return head, objs, order


def get(objs, oid, key):
    m = re.search(key + r":\s*(.*)", objs[oid][1])
    return m.group(1).strip() if m else None


def children(objs, rt):
    m = re.search(r"m_Children:\n((?:  - \{fileID: -?\d+\}\n)+)", objs[rt][1])
    return re.findall(r"\{fileID: (-?\d+)\}", m.group(1)) if m else []


def go_of(objs, rt):
    return re.search(r"m_GameObject: \{fileID: (-?\d+)\}", objs[rt][1]).group(1)


def find(objs, path):
    roots = [rt for rt, (cls, b) in objs.items() if cls == 224 and "m_Father: {fileID: 0}" in b]
    if not roots:
        return None
    cur = roots[0]
    for seg in path:
        nxt = None
        for ch in children(objs, cur):
            if get(objs, go_of(objs, ch), "m_Name") == seg:
                nxt = ch
                break
        if not nxt:
            return None
        cur = nxt
    return cur


def main():
    txt = open(PREFAB, encoding="utf-8").read()
    head, objs, order = parse(txt)
    added = []

    # 模板：同 prefab 里一个普通 Image 节点（title/title）
    tpl_rt = find(objs, ["content", "chat", "leftchat", "contentroot", "bg", "info", "title", "title"])
    if tpl_rt is None:
        raise SystemExit("模板节点 title/title 没找到，prefab 结构变了？")
    tpl_go = go_of(objs, tpl_rt)
    comp_ids = [c.strip() for c in re.findall(r"- component: \{fileID: (-?\d+)\}", objs[tpl_go][1])]
    tpl_cr = next(c for c in comp_ids if objs[c][0] == 222)
    tpl_img = next(c for c in comp_ids if objs[c][0] == 114)

    for side, cfg in LAYOUT.items():
        name_rt = find(objs, ["content", "chat", side, "contentroot", "bg", "info", "name"])
        if name_rt is None:
            raise SystemExit("找不到 %s 的 name 容器" % side)
        text_rt = None
        for ch in children(objs, name_rt):
            if get(objs, go_of(objs, ch), "m_Name") == "name":
                text_rt = ch
                break
        if text_rt is None:
            raise SystemExit("%s/name 下没有名字 Text 节点" % side)

        # 幂等：已经有 countryFlag 就跳过
        exists = any(get(objs, go_of(objs, ch), "m_Name") == NODE_NAME for ch in children(objs, name_rt))
        if exists:
            print("  = %s 已有 %s，跳过" % (side, NODE_NAME))
            continue

        go_id = new_id(side + "/go")
        rt_id = new_id(side + "/rt")
        cr_id = new_id(side + "/cr")
        img_id = new_id(side + "/img")

        # --- GameObject ---
        go_body = objs[tpl_go][1]
        go_body = re.sub(r"m_Component:\n(?:  - component: \{fileID: -?\d+\}\n)+",
                         "m_Component:\n  - component: {fileID: %s}\n  - component: {fileID: %s}\n  - component: {fileID: %s}\n"
                         % (rt_id, cr_id, img_id), go_body)
        go_body = re.sub(r"m_Name: .*", "m_Name: " + NODE_NAME, go_body, count=1)

        # --- RectTransform ---
        rt_body = objs[tpl_rt][1]
        rt_body = rt_body.replace("{fileID: %s}" % tpl_go, "{fileID: %s}" % go_id)
        rt_body = re.sub(r"m_LocalScale: \{[^}]*\}", "m_LocalScale: {x: 1, y: 1, z: 1}", rt_body, count=1)
        rt_body = re.sub(r"m_Children: \[\]", "m_Children: []", rt_body, count=1)
        rt_body = re.sub(r"m_Father: \{fileID: -?\d+\}", "m_Father: {fileID: %s}" % name_rt, rt_body, count=1)
        rt_body = re.sub(r"m_AnchorMin: \{[^}]*\}",
                         "m_AnchorMin: {x: %s, y: %s}" % cfg["anchor"], rt_body, count=1)
        rt_body = re.sub(r"m_AnchorMax: \{[^}]*\}",
                         "m_AnchorMax: {x: %s, y: %s}" % cfg["anchor"], rt_body, count=1)
        rt_body = re.sub(r"m_AnchoredPosition: \{[^}]*\}",
                         "m_AnchoredPosition: {x: %s, y: %s}" % cfg["pos"], rt_body, count=1)
        rt_body = re.sub(r"m_SizeDelta: \{[^}]*\}",
                         "m_SizeDelta: {x: %s, y: %s}" % (FLAG_W, FLAG_H), rt_body, count=1)
        rt_body = re.sub(r"m_Pivot: \{[^}]*\}",
                         "m_Pivot: {x: %s, y: %s}" % cfg["pivot"], rt_body, count=1)

        # --- CanvasRenderer ---
        cr_body = objs[tpl_cr][1].replace("{fileID: %s}" % tpl_go, "{fileID: %s}" % go_id)

        # --- Image ---
        img_body = objs[tpl_img][1].replace("{fileID: %s}" % tpl_go, "{fileID: %s}" % go_id)
        img_body = re.sub(r"m_Sprite: \{[^}]*\}", "m_Sprite: {fileID: 0}", img_body, count=1)
        img_body = re.sub(r"m_RaycastTarget: \d", "m_RaycastTarget: 0", img_body, count=1)
        img_body = re.sub(r"m_Color: \{[^}]*\}", "m_Color: {r: 1, g: 1, b: 1, a: 1}", img_body, count=1)

        objs[go_id] = [1, go_body]
        objs[rt_id] = [224, rt_body]
        objs[cr_id] = [222, cr_body]
        objs[img_id] = [114, img_body]
        order.extend([go_id, rt_id, cr_id, img_id])

        # 挂到父节点 m_Children 末尾
        parent_body = objs[name_rt][1]
        if "m_Children: []" in parent_body:
            parent_body = parent_body.replace("m_Children: []", "m_Children:\n  - {fileID: %s}" % rt_id, 1)
        else:
            m = re.search(r"m_Children:\n((?:  - \{fileID: -?\d+\}\n)+)", parent_body)
            last = m.group(1)
            parent_body = parent_body.replace(last, last + "  - {fileID: %s}\n" % rt_id, 1)
        objs[name_rt][1] = parent_body

        # 名字让开旗子
        text_body = objs[text_rt][1]
        m = re.search(r"m_AnchoredPosition: \{x: (-?[\d\.]+), y: (-?[\d\.]+)\}", text_body)
        old_x, y = float(m.group(1)), m.group(2)
        text_body = text_body.replace(m.group(0),
                                      "m_AnchoredPosition: {x: %s, y: %s}" % (cfg["text_x"], y), 1)
        objs[text_rt][1] = text_body
        added.append("%s (name.x %s -> %s)" % (side, old_x, cfg["text_x"]))

    if not added:
        print("无需改动（已存在）")
        return

    out = [head]
    for oid in order:
        out.append("--- !u!%d &%s%s" % (objs[oid][0], oid, objs[oid][1]))
    open(PREFAB, "w", encoding="utf-8").write("".join(out))
    print("已添加：")
    for a in added:
        print("  +", a)


if __name__ == "__main__":
    main()
