"""把 hero_specs.json 渲染成文生图提示词（纯文本，不引用任何立绘）。"""
import json
import sys
from pathlib import Path

ROOT = Path("/Users/wangxufeng/Documents/TimeSpaceGirl1")
SPEC = ROOT / "data_aso/assets/hero_specs.json"

HEAD = """Vertical 9:16 mobile-game character key art, ONE female character, full colour, no text.

CHARACTER — build her ONLY from this description; do not copy any existing artwork or reference:
- hair: {hair}
- eyes: {eyes}
- outfit: {outfit}
- weapon: {weapon}
- extras: {props}
- mood: {vibe}
"""

# 🔴 走 Jenkins 管线时必须带这一段：provider 会把 ASSET 当参考图上传，模型默认「照着改」。
#    商业立绘当种子会锁死姿势/服装（实测 05 被换成白发机甲、06 被换成金发），
#    所以 ASSET 换成**不含人物的空舞台板**，并在提示词里点明「它只是画布」。
PLATE_NOTE = """INPUT PLATE — the attached image is an EMPTY STAGE PLATE, not a reference:
- It contains NO character, NO props and NO text. It only fixes the canvas size, the horizon line, a faint light pool and the reserved empty band at the bottom.
- Do NOT trace its blocks, buildings or gradient literally, and do not keep it as a background: repaint the whole frame as the STAGE described below, keeping only the horizon height and the empty bottom band.
- Everything about the character comes from the description above — nothing about her comes from the plate.
"""

TAIL = """
STAGE: {stage}
CAMERA: {camera}

COMPOSITION RULES (hard):
- Full body inside the frame, nothing cut off; her lowest point (feet, or the tip of her trailing hair/cloth if she floats) sits at about 74% of the canvas height.
- The BOTTOM 24 PERCENT of the canvas must stay dark and visually empty: no face, no props, no bright light source, no busy detail. A headline is composited there afterwards.
- She is the only subject; keep her sharply separated from the background by a rim light along her silhouette.

TEXT: absolutely NO lettering, numerals, captions, headlines, labels, logos, watermarks or signatures anywhere in the image. Any sign, banner or panel stays blank.

STYLE (must read as hand-drawn 2D anime, not CG):
- thick clean black outlines of consistent weight around every shape, including the hair strands and the weapon
- FLAT anime cel colour fills; hard-edged two-tone shading (one shadow tone + one highlight), shadows with a visible hard border
- vivid, saturated, high-contrast palette — bright where she is, only the extreme corners fall to dark
- she is clearly separated from the background by a crisp bright rim light on her silhouette
- like a mobile gacha game character splash art: confident lineart, clean colour blocking, no texture noise

FORBIDDEN: 3D render, CGI, octane, painterly brushwork, airbrushed gradients, soft-focus bloom, photoreal skin, muted/desaturated grey palette, film grain.

PALETTE: dominant {dominant}, accent {accent}; deep navy-black shadows.
"""


def render(h: dict, plate: bool = False) -> str:
    pal = h.get("palette_src") or []
    dominant = ", ".join(pal[:3]) if pal else "per the character description"
    head = HEAD.format(
        hair=h["hair"], eyes=h["eyes"],
        outfit="; ".join(h["outfit"]),
        weapon=h["weapon"], props="; ".join(h["props"]), vibe=h["vibe"],
    )
    if plate:
        head += "\n" + PLATE_NOTE
    return head + TAIL.format(stage=h["stage"], camera=h["camera"],
                              dominant=dominant, accent=h.get("accent", ""))


def main() -> int:
    d = json.load(open(SPEC))
    plate = "--plate" in sys.argv
    want = [a for a in sys.argv[1:] if not a.startswith("--")] or [h["id"] for h in d["heroes"]]
    for h in d["heroes"]:
        if h["id"] in want:
            print(f"########## {h['id']} {h['name']} ({h['role']}) ##########")
            print(render(h, plate=plate))
            print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
