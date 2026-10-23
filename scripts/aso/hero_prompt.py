"""把 hero_specs.json 渲染成文生图提示词（纯文本，不引用任何立绘）。"""
import json
import sys
from pathlib import Path

ROOT = Path("/Users/wangxufeng/Documents/TimeSpaceGirl1")
SPEC = ROOT / "data_aso/assets/hero_specs.json"

HEAD = """{orient} mobile-game character key art, ONE female character, full colour, no text.

CHARACTER — build her ONLY from this description; do not copy any existing artwork or reference:
- hair: {hair}
- eyes: {eyes}
- outfit: {outfit}
- weapon: {weapon}
- extras: {props}
- mood: {vibe}
"""

ORIENT = {
    "port": "Vertical 9:16",
    "land": "Horizontal 16:9 (landscape)",
}

# 🔴 走 Jenkins 管线时必须带这一段：provider 会把 ASSET 当参考图上传，模型默认「照着改」。
#    商业立绘当种子会锁死姿势/服装（实测 05 被换成白发机甲、06 被换成金发），
#    所以 ASSET 换成**不含人物的空舞台板**，并在提示词里点明「它只是画布」。
PLATE_NOTE = """INPUT PLATE — the attached image is an EMPTY STAGE PLATE, not a reference:
- It contains NO character, NO props and NO text. It only fixes the canvas size, the horizon line, a faint light pool and the reserved empty band.
- Do NOT trace its blocks, buildings or gradient literally, and do not keep it as a background: repaint the whole frame as the STAGE described below, keeping only the horizon height and the reserved empty band.
- Everything about the character comes from the description above — nothing about her comes from the plate.
"""

TAIL = """
STAGE: {stage}
CAMERA: {camera}

COMPOSITION RULES (hard):
{layout_rules}
- She is the only subject; keep her sharply separated from the background by a rim light along her silhouette.

TEXT: absolutely NO lettering, numerals, captions, headlines, labels, logos, watermarks or signatures anywhere in the image. Any sign, banner or panel stays blank.

DRESS CODE (hard, store-compliance — a rejected build costs a whole review cycle):
- Every character is FULLY CLOTHED from neck to ankles. Chest, groin and buttocks are always covered by opaque fabric.
- No visible underwear, no exposed groin, no see-through or wet-look fabric, no high-cut leotard bottom, no V-line or hip-bone exposure.
- Skirt hems and slits stay at or below mid-thigh; a slit may never open above the knee. Bare skin is allowed only on arms, shoulders, and legs below mid-thigh.
- No sexualised posing: no spreading or lifting of legs, no crotch-centred framing, no emphasis on the chest.
- FORBIDDEN in this image: nudity, nipples, genitalia, exposed groin, panty shots, camel toe, lingerie-only outfit.

STYLE (must read as hand-drawn 2D anime, not CG):
- thick clean black outlines of consistent weight around every shape, including the hair strands and the weapon
- FLAT anime cel colour fills; hard-edged two-tone shading (one shadow tone + one highlight), shadows with a visible hard border
- vivid, saturated, high-contrast palette — bright where she is, only the extreme corners fall to dark
- she is clearly separated from the background by a crisp bright rim light on her silhouette
- like a mobile gacha game character splash art: confident lineart, clean colour blocking, no texture noise

FORBIDDEN: 3D render, CGI, octane, painterly brushwork, airbrushed gradients, soft-focus bloom, photoreal skin, muted/desaturated grey palette, film grain.

PALETTE: dominant {dominant}, accent {accent}; deep navy-black shadows.
"""

# 竖版 = 底部留给文案（Play 手机轮播）；横版 = 左侧留给文案（线上现网 1920×1080 那套）。
LAYOUT_RULES = {
    "port": """- Full body inside the frame, nothing cut off; her lowest point (feet, or the tip of her trailing hair/cloth if she floats) sits at about 74% of the canvas height.
- The BOTTOM 24 PERCENT of the canvas must stay dark and visually empty: no face, no props, no bright light source, no busy detail. A headline is composited there afterwards.""",
    "land": """- Landscape framing: full body inside the frame, nothing cut off; her feet (or the tip of her trailing hair/cloth if she floats) sit at about 90% of the canvas height.
- Put her in the RIGHT-HAND HALF: her whole silhouette, weapon and floating props stay right of the 46% mark, leaving a clean column on the left.
- The LEFT 42 PERCENT of the canvas must stay dark and visually empty: no character, no weapon, no props, no bright light source, no busy detail. A headline block is composited there afterwards.
- The BOTTOM 10 PERCENT must stay dark and empty as well.""",
}


def render(h: dict, plate: bool = False, orient: str = "port") -> str:
    pal = h.get("palette_src") or []
    dominant = ", ".join(pal[:3]) if pal else "per the character description"
    head = HEAD.format(
        orient=ORIENT[orient],
        hair=h["hair"], eyes=h["eyes"],
        outfit="; ".join(h["outfit"]),
        weapon=h["weapon"], props="; ".join(h["props"]), vibe=h["vibe"],
    )
    if plate:
        head += "\n" + PLATE_NOTE
    return head + TAIL.format(stage=h["stage"], camera=h["camera"],
                              layout_rules=LAYOUT_RULES[orient],
                              dominant=dominant, accent=h.get("accent", ""))


# ---------------------------------------------------------------- 双人店面底图
# 用途：Play 置顶图 / 横幅。左右各一个角色、中间留空、底部留暗带，
# 中间那块之后会被实机截图完全盖住（所以中间画什么都不重要，重要的是别画人），
# 这样「角色由管线按特征卡重绘」和「中间是真实游戏画面」两件事同时成立。
HEAD_DUO = """Horizontal 2:1 ultra-wide mobile-game store banner key art, TWO DIFFERENT female characters, full colour, no text.

LEFT CHARACTER — build her ONLY from this description; do not copy any existing artwork or reference:
- hair: {a_hair}
- eyes: {a_eyes}
- outfit: {a_outfit}
- weapon: {a_weapon}
- extras: {a_props}
- mood: {a_vibe}

RIGHT CHARACTER — a completely different person from the left one; build her ONLY from this description:
- hair: {b_hair}
- eyes: {b_eyes}
- outfit: {b_outfit}
- weapon: {b_weapon}
- extras: {b_props}
- mood: {b_vibe}
"""

TAIL_DUO = """
STAGE (shared by both): {stage}

COMPOSITION RULES (hard, this is a store banner not a splash art):
- WIDE LANDSCAPE layout. The two heroines stand at the FAR LEFT and FAR RIGHT edges, facing slightly inward toward each other.
- LEFT heroine: her body is CUT BY THE LEFT EDGE of the canvas. Only her head, shoulders, chest and one raised arm are inside the frame — her waist and legs are outside the canvas. Her face sits high, centred around x = 8% of the width and y = 24% of the height, with the top of her head almost touching the top edge. She is large: her head is about 26% of the canvas height.
- RIGHT heroine mirrors her: cut by the RIGHT edge, head/shoulders/chest only, face centred around x = 92% and y = 26%, same head size.
- The MIDDLE 60 PERCENT of the canvas (x from 20% to 80%) must contain NO character, NO face, NO weapon, NO bright light source, NO busy detail — only a low, dim, out-of-focus stage. A gameplay screenshot is composited over that whole area afterwards.
- The BOTTOM 26 PERCENT must stay dark and visually empty: no face, no props, no bright light source. A headline is composited there afterwards.
- Each heroine is separated from the background by a crisp bright rim light along her silhouette.

TEXT: absolutely NO lettering, numerals, captions, headlines, labels, logos, watermarks or signatures anywhere in the image. Any sign, banner or panel stays blank.

DRESS CODE (hard, store-compliance — a rejected build costs a whole review cycle):
- Every character is FULLY CLOTHED from neck to ankles. Chest, groin and buttocks are always covered by opaque fabric.
- No visible underwear, no exposed groin, no see-through or wet-look fabric, no high-cut leotard bottom, no V-line or hip-bone exposure.
- Skirt hems and slits stay at or below mid-thigh; a slit may never open above the knee. Bare skin is allowed only on arms, shoulders, and legs below mid-thigh.
- No sexualised posing: no spreading or lifting of legs, no crotch-centred framing, no emphasis on the chest.
- FORBIDDEN in this image: nudity, nipples, genitalia, exposed groin, panty shots, camel toe, lingerie-only outfit.

STYLE (must read as hand-drawn 2D anime, not CG):
- thick clean black outlines of consistent weight around every shape, including hair strands and weapons
- FLAT anime cel colour fills; hard-edged two-tone shading (one shadow tone + one highlight), shadows with a visible hard border
- vivid, saturated, high-contrast palette — bright where the heroines are, only the extreme corners fall to dark
- like a mobile gacha game store banner: confident lineart, clean colour blocking, no texture noise

FORBIDDEN: 3D render, CGI, octane, painterly brushwork, airbrushed gradients, soft-focus bloom, photoreal skin, muted/desaturated grey palette, film grain.

PALETTE: left heroine {a_dominant} (accent {a_accent}); right heroine {b_dominant} (accent {b_accent}); deep navy-black night stage behind them.
"""

PLATE_NOTE_DUO = """INPUT PLATE — the attached image is an EMPTY STAGE PLATE, not a reference:
- It contains NO character, NO props and NO text. It only fixes the canvas size, the horizon line, two faint light pools and the reserved empty areas (middle + bottom).
- Do NOT trace its gradient or blocks literally, and do not keep it as a background: repaint the whole frame as the STAGE described below, keeping only the horizon height and the empty areas.
- Both heroines come entirely from the two descriptions above — nothing about them comes from the plate.
"""


def render_duo(a: dict, b: dict, plate: bool = True) -> str:
    """左右双角色横版底图。中间的空白区会被实机截图整块盖掉。"""
    def pal_of(h):
        p = h.get("palette_src") or []
        return ", ".join(p[:3]) if p else "per the description"

    head = HEAD_DUO.format(
        a_hair=a["hair"], a_eyes=a["eyes"], a_outfit="; ".join(a["outfit"]),
        a_weapon=a["weapon"], a_props="; ".join(a["props"]), a_vibe=a["vibe"],
        b_hair=b["hair"], b_eyes=b["eyes"], b_outfit="; ".join(b["outfit"]),
        b_weapon=b["weapon"], b_props="; ".join(b["props"]), b_vibe=b["vibe"],
    )
    if plate:
        head += "\n" + PLATE_NOTE_DUO
    stage = f"{a.get('stage', '')}; on the other side, {b.get('stage', '')}"
    return head + TAIL_DUO.format(stage=stage,
                                  a_dominant=pal_of(a), a_accent=a.get("accent", ""),
                                  b_dominant=pal_of(b), b_accent=b.get("accent", ""))


def main() -> int:
    d = json.load(open(SPEC))
    plate = "--plate" in sys.argv
    orient = "land" if "--land" in sys.argv else "port"
    want = [a for a in sys.argv[1:] if not a.startswith("--")] or [h["id"] for h in d["heroes"]]
    for h in d["heroes"]:
        if h["id"] in want:
            print(f"########## {h['id']} {h['name']} ({h['role']}) [{orient}] ##########")
            print(render(h, plate=plate, orient=orient))
            print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
