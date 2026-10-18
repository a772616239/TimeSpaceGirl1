# -*- coding: utf-8 -*-
"""按生成的 prefab 里真实的 RectTransform 数值渲染预览（所见即所得校验用）。

坐标约定：Unity 里 anchoredPosition 是「相对锚点参考点」的偏移，
pivot 决定自身矩形相对该点的摆放。这里用绝对矩形递推，避免父/子尺寸混乱。
"""
import math
import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
ATLAS = os.path.join(ROOT, 'Assets/ManagedResources/Atlas/CountryRankPanelAtlas')
PREFAB = os.path.join(ROOT, 'Assets/ManagedResources/Prefabs/UI/CountryRank/CountryRankPanel.prefab')


def build_guid_map():
    out = {}
    for fn in os.listdir(ATLAS):
        if not fn.endswith('.png'):
            continue
        meta = os.path.join(ATLAS, fn + '.meta')
        if not os.path.exists(meta):
            continue
        for line in open(meta, encoding='utf-8'):
            if line.startswith('guid:'):
                out[line.split(':', 1)[1].strip()] = os.path.join(ATLAS, fn)
    return out


GUID2PATH = build_guid_map()


def parse_prefab(path):
    txt = open(path, encoding='utf-8').read()
    docs = re.split(r'^--- !u!(\d+) &(\d+)', txt, flags=re.M)
    objs = {}
    i = 1
    while i < len(docs):
        objs[docs[i + 1]] = (int(docs[i]), docs[i + 2] if i + 2 < len(docs) else '')
        i += 3
    gos, rts, comps = {}, {}, {}
    for fid, (cls, body) in objs.items():
        if cls == 1:
            gos[fid] = {
                'name': re.search(r'm_Name: (.*)', body).group(1).strip(),
                'active': 'm_IsActive: 1' in body,
            }
        elif cls == 224:
            def vec(k):
                m = re.search(r'%s: \{x: ([-\d.]+), y: ([-\d.]+)\}' % k, body)
                return (float(m.group(1)), float(m.group(2))) if m else (0.0, 0.0)
            kids = []
            m = re.search(r'm_Children:\n((?:  - \{fileID: \d+\}\n)+)', body)
            if m:
                kids = re.findall(r'\{fileID: (\d+)\}', m.group(1))
            rts[fid] = {
                'go': re.search(r'm_GameObject: \{fileID: (\d+)\}', body).group(1),
                'amin': vec('m_AnchorMin'), 'amax': vec('m_AnchorMax'),
                'pos': vec('m_AnchoredPosition'), 'size': vec('m_SizeDelta'),
                'pivot': vec('m_Pivot'), 'children': kids,
                'father': re.search(r'm_Father: \{fileID: (\d+)\}', body).group(1),
            }
        elif cls == 114:
            g = re.search(r'm_GameObject: \{fileID: (\d+)\}', body)
            if not g:
                continue
            d = comps.setdefault(g.group(1), {})
            sp = re.search(r'm_Sprite: \{fileID: \d+, guid: (\w+)', body)
            co = re.search(r'm_Color: \{r: ([-\d.]+), g: ([-\d.]+), b: ([-\d.]+), a: ([-\d.]+)\}', body)
            tx = re.search(r'm_Text: (.*)', body)
            fs = re.search(r'm_FontSize: (\d+)', body)
            al = re.search(r'm_Alignment: (\d+)', body)
            bg = re.search(r'm_BestFit: (\d+)', body)
            if sp:
                d['sprite'] = sp.group(1)
            if co:
                d['color'] = tuple(float(co.group(k)) for k in (1, 2, 3, 4))
            if tx is not None:
                d['isText'] = True
                d['text'] = tx.group(1).strip()
            if fs:
                d['fontSize'] = int(fs.group(1))
            if al:
                d['align'] = int(al.group(1))
    return gos, rts, comps


def pillow_font(size):
    for p in ('/System/Library/Fonts/Hiragino Sans GB.ttc',
              '/System/Library/Fonts/PingFang.ttc',
              '/System/Library/Fonts/STHeiti Medium.ttc'):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size=size)
            except Exception:
                pass
    return ImageFont.load_default()


def child_rect(parent_abs, rt):
    """返回子节点在父矩形局部坐标系里的 (x, y, w, h)，y 以父中心为原点、向上为正。"""
    px, py, pw, ph = parent_abs
    ax0, ay0 = rt['amin']
    ax1, ay1 = rt['amax']
    posx, posy = rt['pos']
    sw, sh = rt['size']
    # 锚点参考点（父局部、父中心为原点）
    ref_x = -pw / 2 + ax0 * pw
    ref_y = -ph / 2 + ay0 * ph
    w = sw + (ax1 - ax0) * pw
    h = sh + (ay1 - ay0) * ph
    pvx, pvy = rt['pivot']
    left = ref_x + posx - w * pvx
    top_y = ref_y + posy - h * pvy          # 局部坐标下的「底边」y
    return (left, top_y, w, h)


def render(prefab_path, out_path, canvas_size=(1080, 1920), bg_path=None, root_center_y=None):
    gos, rts, comps = parse_prefab(prefab_path)
    W, H = canvas_size
    if bg_path and os.path.exists(bg_path):
        bg = Image.open(bg_path).convert('RGB')
        s = max(W / bg.width, H / bg.height)
        bg = bg.resize((int(bg.width * s) + 1, int(bg.height * s) + 1), Image.LANCZOS)
        l = (bg.width - W) // 2
        t = (bg.height - H) // 2
        canvas = bg.crop((l, t, l + W, t + H)).convert('RGBA')
    else:
        canvas = Image.new('RGBA', (W, H), (14, 12, 20, 255))

    root_rt = None
    for rtid, rt in rts.items():
        if rt['father'] == '0':
            root_rt = rtid
            break
    root_go = rts[root_rt]['go']
    root_name = gos[root_go]['name']

    # 根按 stretch 铺满画布（UIManager.CreatePanel 会把 sizeDelta 归零）
    root_abs = (0.0, 0.0, float(W), float(H))   # (x0, y0（画布像素，左上为准）, w, h)

    def rect_of(parent_abs, rt):
        """返回子节点在画布像素坐标里的绝对矩形 (x0, y0, w, h)，y 向下。"""
        px0, py0, pw, ph = parent_abs
        ax0, ay0 = rt['amin']
        ax1, ay1 = rt['amax']
        posx, posy = rt['pos']
        sw, sh = rt['size']
        w = sw + (ax1 - ax0) * pw
        h = sh + (ay1 - ay0) * ph
        pvx, pvy = rt['pivot']
        # 锚点参考点（父矩形内的局部坐标，y 向上）
        ref_lx = ax0 * pw
        ref_ly = ay0 * ph
        left_l = ref_lx + posx - w * pvx
        bottom_l = ref_ly + posy - h * pvy
        x0 = px0 + left_l
        y0 = py0 + (ph - bottom_l - h)     # 转成「距父顶」再转画布
        return (x0, y0, w, h)

    def draw(rtid, parent_abs, is_root=False):
        rt = rts[rtid]
        go = rt['go']
        info = gos.get(go, {})
        if not info.get('active', True):
            return
        if is_root:
            cx, cy, w, h = parent_abs
        else:
            cx, cy, w, h = rect_of(parent_abs, rt)
        d = ImageDraw.Draw(canvas)
        ci = comps.get(go, {})
        if 'sprite' in ci and ci['sprite'] in GUID2PATH and w > 0 and h > 0:
            sp = Image.open(GUID2PATH[ci['sprite']]).convert('RGBA')
            sp = sp.resize((max(1, int(round(w))), max(1, int(round(h)))), Image.LANCZOS)
            col = ci.get('color', (1, 1, 1, 1))
            if col != (1, 1, 1, 1):
                r, g, b, a = sp.split()
                r = r.point(lambda v: int(v * col[0]))
                g = g.point(lambda v: int(v * col[1]))
                b = b.point(lambda v: int(v * col[2]))
                a = a.point(lambda v: int(v * col[3]))
                sp = Image.merge('RGBA', (r, g, b, a))
            canvas.alpha_composite(sp, (int(round(cx)), int(round(cy))))
        elif (not ci.get('isText')) and 'color' in ci and ci['color'][3] > 0 and w > 0 and h > 0:
            col = tuple(int(c * 255) for c in ci['color'])
            d.rectangle([cx, cy, cx + w, cy + h], fill=col)
        if ci.get('isText') and ci.get('text'):
            f = pillow_font(ci.get('fontSize', 32))
            al = ci.get('align', 4)
            col = tuple(int(c * 255) for c in ci.get('color', (1, 1, 1, 1)))
            if al in (1, 4, 7):
                tx, anchor = cx + w / 2, 'mm'
            elif al in (0, 3, 6):
                tx, anchor = cx + 4, 'lm'
            else:
                tx, anchor = cx + w - 4, 'rm'
            d.text((tx, cy + h / 2), ci['text'], font=f, fill=col, anchor=anchor)
        for c in rt['children']:
            draw(c, (cx, cy, w, h))

    draw(root_rt, root_abs, is_root=True)
    canvas.convert('RGB').save(out_path, 'JPEG', quality=92)
    print('saved', out_path)


if __name__ == '__main__':
    render(PREFAB,
           '/tmp/prefab_render.jpg',
           bg_path=os.path.join(ROOT, 'Assets/ManagedResources/Atlas/LoginPanelAtlas/cn2-x1_zhujiemian_beijing.png'))
