#!/usr/bin/env python3
"""把一张地图（prefab）拆成分层素材：每个 Quad 图层单独导出成 PNG，附 layers.json。

为什么不直接改图集：地图是若干 Quad 从同一张图集里按 `_Offset_WH` 取子矩形拼出来的
（`X1_backgroud_UV.shader`），改一个图层要写回图集，牵动同图集里其它层。拆成独立文件
后就能「单层改、单独看、最后一次性打包回图集」。

产出目录结构：
  <out>/layers/01_天空.png ...      每个图层按原始 UV 矩形裁出的 RGBA（原像素，不缩放）
  <out>/layers.json                 图层元数据：变换 / 排序 / 材质 / shader 参数 / UV 矩形
  <out>/preview_layers.png          联系表（所有图层按排序叠名字，方便一眼看全）

用法：
  python scripts/image/scene_unpack.py --prefab Assets/ManagedResources/Prefabs/Battle/Map1.prefab
  python scripts/image/scene_unpack.py --prefab ... --out _output/scene/Map1_test
"""
from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

# Unity 内置 Quad：1x1，pivot 居中（fileID 10210 / guid 0000...e000）
BUILTIN_QUAD = "10210"


# ---------------------------------------------------------------- prefab 解析
def split_docs(text: str) -> dict[str, tuple[str, str]]:
    """把 YAML 文档切成 {fileID: (classId, body)}。"""
    parts = re.split(r"^--- !u!(\d+) &(\d+)", text, flags=re.M)[1:]
    return {parts[i + 1]: (parts[i], parts[i + 2]) for i in range(0, len(parts), 3)}


def _get(pat: str, body: str, default=None):
    m = re.search(pat, body, re.M)
    return m.group(1) if m else default


def _vec(s: str | None):
    if not s:
        return None
    out = []
    for item in s.split(","):
        out.append(float(item.split(":")[1]))
    return out


def _uname(raw: str) -> str:
    raw = raw.strip().strip('"')
    if "\\u" in raw:
        raw = raw.encode().decode("unicode_escape")
    return raw


def parse_prefab(path: Path) -> list[dict]:
    docs = split_docs(path.read_text(encoding="utf-8", errors="ignore"))

    go_name: dict[str, str] = {}
    for fid, (cls, body) in docs.items():
        if cls == "1":
            go_name[fid] = _uname(_get(r"m_Name: (.*)$", body, "?"))

    # Transform（4）与 RectTransform（224）同构；记 parent 以便累加世界坐标
    trs: dict[str, dict] = {}
    for fid, (cls, body) in docs.items():
        if cls not in ("4", "224"):
            continue
        go = _get(r"m_GameObject: \{fileID: (\d+)\}", body)
        trs[fid] = {
            "go": go,
            "pos": _vec(_get(r"m_LocalPosition: \{([^}]*)\}", body)) or [0, 0, 0],
            "scale": _vec(_get(r"m_LocalScale: \{([^}]*)\}", body)) or [1, 1, 1],
            "quat": _vec(_get(r"m_LocalRotation: \{([^}]*)\}", body)) or [0, 0, 0, 1],
            "father": _get(r"m_Father: \{fileID: (\d+)\}", body),
        }
    owner = {t["go"]: fid for fid, t in trs.items() if t["go"]}

    def world(go: str) -> tuple[list[float], list[float], list[float]]:
        """沿父链累加位置、连乘缩放（地图 prefab 都是纯平移+缩放，未含旋转）。"""
        pos = [0.0, 0.0, 0.0]
        scl = [1.0, 1.0, 1.0]
        quat = [0.0, 0.0, 0.0, 1.0]
        fid = owner.get(go)
        leaf = True
        while fid and fid in trs:
            t = trs[fid]
            for i in range(3):
                pos[i] = pos[i] * t["scale"][i] + t["pos"][i]
                scl[i] *= t["scale"][i]
            if leaf:  # 只取自身旋转：父级（根节点）都是单位旋转
                quat = t["quat"]
                leaf = False
            fid = t["father"] if t["father"] not in (None, "0") else None
        return pos, scl, quat

    renderers: dict[str, dict] = {}
    for fid, (cls, body) in docs.items():
        if cls != "23":
            continue
        go = _get(r"m_GameObject: \{fileID: (\d+)\}", body)
        if not go:
            continue
        renderers[go] = {
            "mats": re.findall(r"- \{fileID: \d+, guid: (\w+), type: 2\}", body),
            "order": int(_get(r"m_SortingOrder: (-?\d+)", body, "0")),
            "layer": _get(r"m_SortingLayer: (-?\d+)", body, "0"),
        }

    meshes: dict[str, str] = {}
    for fid, (cls, body) in docs.items():
        if cls != "33":
            continue
        go = _get(r"m_GameObject: \{fileID: (\d+)\}", body)
        if go:
            meshes[go] = _get(r"m_Mesh: \{fileID: (\d+)", body, "")

    layers = []
    for go, rend in renderers.items():
        pos, scl, quat = world(go)
        # 绕 X 的倾角：quat=(x,0,0,w) 时 angle = 2·acos(w)。90° 表示平躺的地面（不是 billboard）
        tilt = 2.0 * math.degrees(math.acos(max(-1.0, min(1.0, quat[3]))))
        layers.append(
            {
                "object": go_name.get(go, go),
                "gameObject": go,
                "sortingOrder": rend["order"],
                "sortingLayer": rend["layer"],
                "materialGuids": rend["mats"],
                "meshFileID": meshes.get(go, ""),
                "position": pos,
                "scale": scl,
                "quat": quat,
                "tiltX": round(tilt, 2),
                "isFlat": tilt > 45.0,
            }
        )
    # 绘制顺序：sortingOrder 升序；同序则 z 大的（更远）先画
    layers.sort(key=lambda L: (L["sortingOrder"], -L["position"][2]))
    return layers


# ---------------------------------------------------------------- guid 定位
# 🔴 不要用 Python 遍历 .meta：这台机器的卷上每次 open 约 7ms，46k 文件要 6 分钟（会被超时杀掉）。
#    `grep -rl` 单进程扫全库只要 ~4s，按「一批 guid 一次扫」用它，结果落缓存，第二次零成本。
_CACHE = ROOT / "_output" / "cache" / "guid_paths.json"


def _load_cache() -> dict[str, str]:
    if _CACHE.exists():
        try:
            # 🔴 只认「找到的」：把空值过滤掉，否则一次没找到的 guid 会被永久判死
            return {k: v for k, v in json.loads(_CACHE.read_text()).items() if v}
        except Exception:
            return {}
    return {}


def resolve_guids(guids: list[str]) -> dict[str, str]:
    """guid → 资源路径。缓存里没有的才去 grep，缺席的记为 "" 以便下次不再重扫。"""
    cache = _load_cache()
    missing = [g for g in {g for g in guids if g} if g not in cache]
    if missing:
        pattern = "guid: (%s)" % "|".join(missing)
        proc = subprocess.run(
            ["grep", "-rlE", "--include=*.meta", pattern, str(ROOT / "Assets")],
            capture_output=True, text=True,
        )
        found = set()
        for line in proc.stdout.splitlines():
            meta = Path(line)
            try:
                head = meta.read_text(encoding="utf-8", errors="ignore")[:220]
            except OSError:
                continue
            m = re.search(r"^guid: (\w+)", head, re.M)
            if not m:
                continue
            g = m.group(1)
            if g in missing:
                cache[g] = str(meta)[:-5]
                found.add(g)
        for g in missing:
            if g not in found:
                cache.setdefault(g, "")
        cache = {k: v for k, v in cache.items() if v}
        _CACHE.parent.mkdir(parents=True, exist_ok=True)
        _CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=0))
        print(f"  · guid 定位 {len(found)}/{len(missing)}（grep 一趟）", file=sys.stderr)
    return {g: cache[g] for g in guids if cache.get(g)}


# ---------------------------------------------------------------- 材质 / shader
def read_material(path: Path) -> dict:
    txt = path.read_text(encoding="utf-8", errors="ignore")
    tex = _get(r"_MainTex:\s*\n\s*m_Texture: \{fileID: \d+, guid: (\w+)", txt)
    shader = _get(r"m_Shader: \{fileID: \d+, guid: (\w+)", txt)
    off = _get(r"- _Offset_WH: \{([^}]*)\}", txt)
    speed = _get(r"- _Speed_Tilling: \{([^}]*)\}", txt)
    rect = _vec(off) if off else None
    keywords = _get(r"m_ShaderKeywords: (.*)$", txt, "").strip()
    return {
        "textureGuid": tex,
        "shaderGuid": shader,
        "uvRect": rect,
        "speedTiling": _vec(speed) if speed else None,
        "keywords": keywords,
        "isLoop": "_ISLOOP_ON" in keywords,
    }


def uv_to_box(rect, w: int, h: int) -> tuple[int, int, int, int]:
    """UV 子矩形 (u0,v0,u1,v1) → 像素框 (x0,y0,x1,y1)，y 向下。"""
    u0, v0, u1, v1 = rect
    return (
        int(round(u0 * w)),
        int(round((1 - v1) * h)),
        int(round(u1 * w)),
        int(round((1 - v0) * h)),
    )


# ---------------------------------------------------------------- 联系表
def contact_sheet(layers: list[dict], out: Path, width: int = 1400) -> None:
    from PIL import ImageDraw

    pad, label_h = 8, 16
    cells = []
    for L in layers:
        im = Image.open(out / "layers" / L["file"])
        k = min(1.0, width / im.width)
        cells.append((L, im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)))

    total_h = sum(c[1].height + label_h + pad for c in cells) + pad
    sheet = Image.new("RGB", (width, total_h), (28, 28, 34))
    d = ImageDraw.Draw(sheet)
    y = pad
    for L, im in cells:
        # 透明区用棋盘，方便看 alpha 边界
        cell = Image.new("RGBA", (width, im.height), (0, 0, 0, 0))
        tile = Image.new("RGBA", im.size, (0, 0, 0, 0))
        for yy in range(0, im.height, 12):
            for xx in range(0, im.width, 12):
                c = (58, 58, 66, 255) if (xx // 12 + yy // 12) % 2 else (44, 44, 52, 255)
                ImageDraw.Draw(tile).rectangle([xx, yy, xx + 11, yy + 11], fill=c)
        tile.alpha_composite(im)
        cell.paste(tile, (0, 0))
        sheet.paste(cell.convert("RGB"), (0, y + label_h))
        d.text((4, y + 2),
               f"{L['index']:02d} {L['object']}  order={L['sortingOrder']}  "
               f"rect={tuple(round(v, 3) for v in L['uvRect'])}  {im.width}x{im.height}px",
               fill=(235, 235, 235))
        y += label_h + im.height + pad
    sheet.save(out / "preview_layers.png")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prefab", required=True, help="地图 prefab（如 Map1.prefab）")
    ap.add_argument("--out", default=None, help="输出目录，默认 _output/scene/<prefab名>")
    ap.add_argument("--contact-sheet", action="store_true", default=True)
    ap.add_argument("--no-contact-sheet", dest="contact_sheet", action="store_false")
    args = ap.parse_args()

    prefab = (ROOT / args.prefab).resolve() if not Path(args.prefab).is_absolute() else Path(args.prefab)
    if not prefab.exists():
        print(f"🔴 找不到 prefab：{prefab}")
        return 2
    out = Path(args.out) if args.out else ROOT / "_output" / "scene" / prefab.stem
    out = out if out.is_absolute() else (ROOT / out)
    lay_dir = out / "layers"
    lay_dir.mkdir(parents=True, exist_ok=True)

    layers = parse_prefab(prefab)

    # 两轮定位：先材质，再由材质带出贴图/shader（每轮只 grep 一趟，结果进缓存）
    mat_guids = [L["materialGuids"][0] for L in layers if L["materialGuids"]]
    mat_map = resolve_guids(mat_guids)
    mats = {g: read_material(Path(p)) for g, p in mat_map.items() if Path(p).exists()}
    tex_map = resolve_guids(
        [m["textureGuid"] for m in mats.values()] + [m["shaderGuid"] for m in mats.values()]
    )

    enriched: list[dict] = []
    for i, L in enumerate(layers, 1):
        mat_guid = L["materialGuids"][0] if L["materialGuids"] else None
        mat_path = mat_map.get(mat_guid or "", "")
        if not mat_path or mat_guid not in mats:
            print(f"⚠ {L['object']}: 材质 guid 解不出来（{mat_guid}），跳过")
            continue
        mat = mats[mat_guid]
        tex_path = tex_map.get(mat["textureGuid"] or "", "")
        if not tex_path or not Path(tex_path).exists():
            print(f"⚠ {L['object']}: 贴图缺失（{mat['textureGuid']}），跳过")
            continue

        atlas = Image.open(tex_path).convert("RGBA")
        rect = mat["uvRect"] or [0.0, 0.0, 1.0, 1.0]
        box = uv_to_box(rect, *atlas.size)
        crop = atlas.crop(box)

        safe = re.sub(r'[\\/:*?"<>|]', "_", L["object"])
        fname = f"{i:02d}_{safe}.png"
        crop.save(lay_dir / fname)

        enriched.append(
            {
                "index": i,
                "object": L["object"],
                "file": fname,
                "pngSize": list(crop.size),
                "sortingOrder": L["sortingOrder"],
                "sortingLayer": L["sortingLayer"],
                "position": [round(v, 4) for v in L["position"]],
                "scale": [round(v, 4) for v in L["scale"]],
                "worldSize": [round(L["scale"][0], 4), round(L["scale"][1], 4)],
                "tiltX": L["tiltX"],
                "isFlat": L["isFlat"],
                "material": str(Path(mat_path).relative_to(ROOT)),
                "shader": str(Path(tex_map[mat["shaderGuid"]]).relative_to(ROOT))
                if tex_map.get(mat["shaderGuid"] or "")
                else "",
                "texture": str(Path(tex_path).relative_to(ROOT)),
                "atlasSize": list(atlas.size),
                "uvRect": [round(v, 4) for v in rect],
                "pixelBox": list(box),
                "speedTiling": mat["speedTiling"],
                "isLoop": mat["isLoop"],
                "keywords": mat["keywords"],
            }
        )

    if not enriched:
        print("🔴 一个图层都没拆出来")
        return 3

    manifest = {
        "generatedAt": datetime.now().isoformat(timespec="seconds"),
        "prefab": str(prefab.relative_to(ROOT)),
        "atlas": enriched[0]["texture"],
        "atlasSize": enriched[0]["atlasSize"],
        "note": "每个图层是按 _Offset_WH 从图集裁出的原像素；worldSize 是 Quad 的世界尺寸（内置 Quad 1x1 × scale）",
        "layers": enriched,
    }
    (out / "layers.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))

    print(f"拆出 {len(enriched)} 层 → {out}")
    print("%-4s %-8s %-6s %-6s %-24s %-10s %s"
          % ("#", "图层", "order", "倾角", "UV矩形", "尺寸", "世界尺寸"))
    for L in enriched:
        print(
            "%-4d %-8s %-6d %-6s %-24s %-10s %s"
            % (
                L["index"],
                L["object"],
                L["sortingOrder"],
                f"{L['tiltX']:.0f}°" + ("*" if L["isFlat"] else ""),
                str(tuple(L["uvRect"])),
                "%dx%d" % tuple(L["pngSize"]),
                "%.2f x %.2f" % tuple(L["worldSize"]),
            )
        )
    if any(L["isFlat"] for L in enriched):
        print("  * 倾角 >45° = 平躺的地面（旋转 90°），不是 billboard；2D 叠层预览里默认不画")
    if args.contact_sheet:
        contact_sheet(enriched, out)
        print(f"联系表 → {out / 'preview_layers.png'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
