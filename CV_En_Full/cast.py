#!/usr/bin/env python3
"""按原声基频给每个角色分配英文音色（edge-tts），并给出音高微调值。"""
import json, os, hashlib

MALE = {
    "very_deep": ["en-US-ChristopherNeural", "en-US-AndrewNeural"],
    "deep":      ["en-US-AndrewNeural", "en-GB-ThomasNeural", "en-US-SteffanNeural"],
    "mid":       ["en-US-BrianNeural", "en-GB-RyanNeural", "en-US-EricNeural"],
    "light":     ["en-US-GuyNeural", "en-US-RogerNeural", "en-IE-ConnorNeural"],
}
FEMALE = {
    "mid":    ["en-US-AriaNeural", "en-US-JennyNeural", "en-GB-SoniaNeural"],
    "bright": ["en-US-EmmaNeural", "en-US-MichelleNeural", "en-GB-LibbyNeural"],
    "high":   ["en-US-AvaNeural", "en-US-AriaNeural", "en-GB-LibbyNeural"],
}
CHILD = ["en-US-AnaNeural", "en-GB-MaisieNeural"]   # 仅给明确的幼态角色用（走 OVERRIDE）
BASE = {"M": 120.0, "F": 210.0}

# 明确指定（人设优先于基频）：key -> (voice, pitch_offset_Hz)
OVERRIDE = {
    "badun":        ("en-US-ChristopherNeural", -8),   # 老练军官
    "zhaoyun":      ("en-US-AndrewNeural", -6),        # 沉稳武将
    "guanyu":       ("en-US-ChristopherNeural", -4),   # 威严
    "yingzheng":    ("en-US-ChristopherNeural", 0),    # 帝王
    "baiqi":        ("en-US-AndrewNeural", 4),         # 杀伐
    "mozhate":      ("en-GB-ThomasNeural", 6),         # 优雅艺术家
    "beimihu":      ("en-US-AvaNeural", 8),            # 神秘巫女
    "kaitangshoujieke": ("en-US-EricNeural", -2),      # 阴冷
    "qiao":         ("en-IE-ConnorNeural", 0),         # 狡黠
    "huamulan":     ("en-US-AriaNeural", 6),           # 英气女将
    "zhende":       ("en-US-AriaNeural", 10),          # 圣女
    "yadianna":     ("en-GB-SoniaNeural", 4),          # 女神
    "yilishabai":   ("en-GB-SoniaNeural", 8),
    "xuexingmali":  ("en-US-AvaNeural", 0),            # 病态
    "nilu":         ("en-US-EmmaNeural", 6),
    "keloupatela":  ("en-US-MichelleNeural", 0),
    "julifuren":    ("en-US-MichelleNeural", 4),       # 学者
    "aiyinsitan":   ("en-US-EricNeural", 12),
    "aidisheng":    ("en-US-BrianNeural", 14),
    "tesila":       ("en-US-EricNeural", 8),
    "nuobeier":     ("en-US-SteffanNeural", 6),
    "xuedinge":     ("en-US-EricNeural", 10),
    "gebaini":      ("en-GB-ThomasNeural", 6),
    "bidagelasi":   ("en-US-SteffanNeural", 4),
    "libai":        ("en-GB-RyanNeural", 4),           # 诗人剑客
    "suoluomen":    ("en-US-ChristopherNeural", -2),   # 王
    "kaisa":        ("en-US-ChristopherNeural", -2),
    "napolun":      ("en-GB-RyanNeural", -4),
    "chengjisihan": ("en-US-ChristopherNeural", -10),  # 草原霸主
    "ximenghaiye":  ("en-US-AndrewNeural", -12),
    "heketuoer":    ("en-US-AndrewNeural", -6),
    "sibada":       ("en-US-GuyNeural", -8),
    "akaliusi":     ("en-US-GuyNeural", 0),
    "hanxin":       ("en-US-BrianNeural", 0),
    "lishuncheng":  ("en-US-AndrewNeural", -4),
    "yase":         ("en-GB-RyanNeural", -2),
    "fulankensitan":("en-US-EricNeural", -6),
    "fulade":       ("en-US-EricNeural", -4),
    "shijunzhezhanmu": ("en-GB-ThomasNeural", -2),
    "yasenluobin":  ("en-IE-ConnorNeural", 4),
    "zuoluo":       ("en-IE-ConnorNeural", 0),
    "weilianjide":  ("en-AU-WilliamMultilingualNeural", 0),
    "bulutusi":     ("en-US-EmmaNeural", 4),
    "dannilisi":    ("en-GB-SoniaNeural", 6),
    "xixigongzhu":  ("en-GB-LibbyNeural", 4),
    "hailun":       ("en-US-AvaNeural", 6),
    "nandinggeer":  ("en-GB-SoniaNeural", 2),
    "maliya":       ("en-US-MichelleNeural", 8),
    "shibanvwang":  ("en-GB-SoniaNeural", -2),
    "waerjili":     ("en-US-AriaNeural", 2),
    "dechuanjiakang":("en-US-EmmaNeural", 10),
    "xiaobang":     ("en-GB-ThomasNeural", 10),
    "danding":      ("en-GB-RyanNeural", 6),
    "yuguo":        ("en-US-AndrewNeural", -14),
    "hema":         ("en-US-AndrewNeural", 2),
    "fuluoyide":    ("en-GB-ThomasNeural", 2),
    "gelin":        ("en-GB-RyanNeural", 8),
    "tangjikede":   ("en-US-GuyNeural", 8),
    "palisi":       ("en-US-BrianNeural", 10),
    "hema":         ("en-US-AndrewNeural", 2),
    "yalishanda":   ("en-US-GuyNeural", 2),
    "bisimai":      ("en-US-ChristopherNeural", -4),
    "zhitianxinchang":("en-US-EricNeural", 2),
    "mingzhiguangxiu":("en-GB-RyanNeural", 2),
    "tufangsuisan": ("en-US-BrianNeural", 4),
    "zhentianxingcun":("en-US-GuyNeural", 4),
    "beiaowufu":    ("en-US-GuyNeural", -6),
    "helakelesi":   ("en-US-GuyNeural", -4),
    "bulunxieerde": ("en-US-AriaNeural", 0),
    "lafeier":      ("en-GB-ThomasNeural", 4),
    "hasang":       ("en-US-EricNeural", -2),
    "beimihu":      ("en-US-AvaNeural", 8),
    "xuexingmali":  ("en-US-AvaNeural", 0),
    "baiqi":        ("en-US-AndrewNeural", 4),
}

def register(gender, f0):
    if gender == "M":
        if f0 < 105: return "very_deep"
        if f0 < 150: return "deep"
        if f0 < 185: return "mid"
        return "light"
    if f0 < 230: return "mid"
    if f0 < 285: return "bright"
    return "high"

MALE_ALL = {v for pool in MALE.values() for v in pool}
FEMALE_ALL = {v for pool in FEMALE.values() for v in pool}

def pick(key, gender, f0):
    # 人工指定优先，但必须与基频推断的性别一致，否则以基频为准
    if key in OVERRIDE:
        v, p = OVERRIDE[key]
        if (gender == "M" and v in MALE_ALL) or (gender == "F" and v in FEMALE_ALL):
            return v, p
    pool = (MALE if gender == "M" else FEMALE)[register(gender, f0)]
    idx = int(hashlib.md5(key.encode()).hexdigest(), 16) % len(pool)
    pitch = max(-25, min(25, round(f0 - BASE[gender])))
    return pool[idx], pitch
