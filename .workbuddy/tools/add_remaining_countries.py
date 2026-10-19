#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
补齐「国家排行榜」图集里缺失的国家旗帜 + 生成 CountryConfig.List 的 Lua 片段。

背景（2026-10-19）：
  图集原先只有 73 面手绘旗（主要市场 + 欧洲逐国），ISO 3166-1 剩余国家一律落到
  xx 问号旗 —— 玩家没法表达自己是哪国人。这里把剩下的一次性补齐到 ISO 全量 249。

做法：
  1. 旗帜原图从 flagcdn（公有领域，源自 Wikimedia）取 w320 的 4:3 PNG；
  2. 套用 gen_country_rank_art.compose_flag 的既有画框（圆角小旗 + 斜切金边 + 高光），
     与手绘的 73 面保持同一视觉语言；
  3. 只补缺失的 code，已存在的 73 面**绝不覆盖**（它们是手绘的，风格更贴 UI）。

产物：
  Assets/ManagedResources/Atlas/CountryRankPanelAtlas/cn2-guoqi_<code>.png
  _output/country_config_new_block.lua   —— 待插入 CountryConfig.List 的条目

用法： python3 .workbuddy/tools/add_remaining_countries.py [--force] [--dry]
"""
import os
import sys
import time
import urllib.request

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import gen_country_rank_art as art  # noqa: E402

OUT_DIR = os.path.join(ROOT, "Assets/ManagedResources/Atlas/CountryRankPanelAtlas")
CACHE_DIR = "/tmp/flagcdn_cache"
LUA_BLOCK = os.path.join(ROOT, "_output/country_config_new_block.lua")
CDN = "https://flagcdn.com/w320/%s.png"

# 个别地区 CDN 上只有「带文字的徽章图」或非官方怪图，132x88 下不可辨 ⇒ 借主国旗
#   yt（马约特）：CDN 给的是印着 "MAYOTTE" 字样的徽章，缩图后是一团糊，用法兰西三色
SOURCE_OVERRIDE = {"yt": "fr"}

# ---------------------------------------------------------------- 新增国家（ISO 3166-1
# 未包含在现有 73 面里的全部条目）
# 字段：code, zh, en, jp, kr
#   - zh/en 必填；en 受格子宽度限制（nameText 180 宽 / 22 号字，≈16 字符），长名用短名
#   - jp/kr 缺失（""）时由 CountryConfig.GetName 回落到 en（拉丁字母比简体中文更易读）
NEW_COUNTRIES = [
    ("af", "阿富汗",       "Afghanistan",    "アフガニスタン",   "아프가니스탄"),
    ("ad", "安道尔",       "Andorra",        "アンドラ",         "안도라"),
    ("ag", "安提瓜和巴布达", "Antigua & Barb.", "アンティグア",  "앤티가바부다"),
    ("ai", "安圭拉",       "Anguilla",       "アンギラ",         "앵귈라"),
    ("ao", "安哥拉",       "Angola",         "アンゴラ",         "앙골라"),
    ("aq", "南极洲",       "Antarctica",     "南極",             "남극"),
    ("as", "美属萨摩亚",   "American Samoa", "米領サモア",       "미국령사모아"),
    ("aw", "阿鲁巴",       "Aruba",          "アルバ",           "아루바"),
    ("ax", "奥兰群岛",     "Åland",          "オーランド",       "올란드"),
    ("bb", "巴巴多斯",     "Barbados",       "バルバドス",       "바베이도스"),
    ("bd", "孟加拉国",     "Bangladesh",     "バングラデシュ",   "방글라데시"),
    ("bf", "布基纳法索",   "Burkina Faso",   "ブルキナファソ",   "부르키나파소"),
    ("bh", "巴林",         "Bahrain",        "バーレーン",       "바레인"),
    ("bi", "布隆迪",       "Burundi",        "ブルンジ",         "부룬디"),
    ("bj", "贝宁",         "Benin",          "ベナン",           "베냉"),
    ("bl", "圣巴泰勒米",   "St. Barthélemy", "",                 ""),
    ("bm", "百慕大",       "Bermuda",        "バミューダ",       "버뮤다"),
    ("bn", "文莱",         "Brunei",         "ブルネイ",         "브루나이"),
    ("bo", "玻利维亚",     "Bolivia",        "ボリビア",         "볼리비아"),
    ("bq", "加勒比荷兰",   "Caribbean NL",   "カリブ・オランダ", "카리브네덜란드"),
    ("bs", "巴哈马",       "Bahamas",        "バハマ",           "바하마"),
    ("bt", "不丹",         "Bhutan",         "ブータン",         "부탄"),
    ("bv", "布韦岛",       "Bouvet Island",  "ブーベ島",         "부베섬"),
    ("bw", "博茨瓦纳",     "Botswana",       "ボツワナ",         "보츠와나"),
    ("bz", "伯利兹",       "Belize",         "ベリーズ",         "벨리즈"),
    ("cc", "科科斯群岛",   "Cocos Islands",  "ココス諸島",       "코코스제도"),
    ("cd", "刚果民主共和国", "DR Congo",      "コンゴ民主",       "콩고민주"),
    ("cf", "中非共和国",   "C. African Rep.", "中央アフリカ",    "중앙아프리카"),
    ("cg", "刚果共和国",   "Congo",          "コンゴ共和国",     "콩고"),
    ("ci", "科特迪瓦",     "Côte d'Ivoire",  "コートジボワール", "코트디부아르"),
    ("ck", "库克群岛",     "Cook Islands",   "クック諸島",       "쿡제도"),
    ("cm", "喀麦隆",       "Cameroon",       "カメルーン",       "카메룬"),
    ("cr", "哥斯达黎加",   "Costa Rica",     "コスタリカ",       "코스타리카"),
    ("cu", "古巴",         "Cuba",           "キューバ",         "쿠바"),
    ("cv", "佛得角",       "Cabo Verde",     "カーボベルデ",     "카보베르데"),
    ("cw", "库拉索",       "Curaçao",        "キュラソー",       "퀴라소"),
    ("cx", "圣诞岛",       "Christmas Is.",  "クリスマス島",     "크리스마스섬"),
    ("dj", "吉布提",       "Djibouti",       "ジブチ",           "지부티"),
    ("dm", "多米尼克",     "Dominica",       "ドミニカ",         "도미니카"),
    ("do", "多米尼加",     "Dominican Rep.", "ドミニカ共和国",   "도미니카공화국"),
    ("dz", "阿尔及利亚",   "Algeria",        "アルジェリア",     "알제리"),
    ("ec", "厄瓜多尔",     "Ecuador",        "エクアドル",       "에콰도르"),
    ("eh", "西撒哈拉",     "Western Sahara", "西サハラ",         "서사하라"),
    ("er", "厄立特里亚",   "Eritrea",        "エリトリア",       "에리트레아"),
    ("et", "埃塞俄比亚",   "Ethiopia",       "エチオピア",       "에티오피아"),
    ("fj", "斐济",         "Fiji",           "フィジー",         "피지"),
    ("fk", "福克兰群岛",   "Falkland Is.",   "フォークランド",   "포클랜드"),
    ("fm", "密克罗尼西亚", "Micronesia",     "ミクロネシア",     "미크로네시아"),
    ("fo", "法罗群岛",     "Faroe Islands",  "フェロー諸島",     "페로제도"),
    ("ga", "加蓬",         "Gabon",          "ガボン",           "가봉"),
    ("gd", "格林纳达",     "Grenada",        "グレナダ",         "그레나다"),
    ("gf", "法属圭亚那",   "French Guiana",  "仏領ギアナ",       "프랑스령기아나"),
    ("gg", "根西岛",       "Guernsey",       "ガーンジー",       "건지"),
    ("gh", "加纳",         "Ghana",          "ガーナ",           "가나"),
    ("gi", "直布罗陀",     "Gibraltar",      "ジブラルタル",     "지브롤터"),
    ("gl", "格陵兰",       "Greenland",      "グリーンランド",   "그린란드"),
    ("gm", "冈比亚",       "Gambia",         "ガンビア",         "감비아"),
    ("gn", "几内亚",       "Guinea",         "ギニア",           "기니"),
    ("gp", "瓜德罗普",     "Guadeloupe",     "グアドループ",     "과들루프"),
    ("gq", "赤道几内亚",   "Eq. Guinea",     "赤道ギニア",       "적도기니"),
    ("gs", "南乔治亚",     "South Georgia",  "南ジョージア",     "사우스조지아"),
    ("gt", "危地马拉",     "Guatemala",      "グアテマラ",       "과테말라"),
    ("gu", "关岛",         "Guam",           "グアム",           "괌"),
    ("gw", "几内亚比绍",   "Guinea-Bissau",  "ギニアビサウ",     "기니비사우"),
    ("gy", "圭亚那",       "Guyana",         "ガイアナ",         "가이아나"),
    ("hm", "赫德岛",       "Heard Island",   "ハード島",         "하드섬"),
    ("hn", "洪都拉斯",     "Honduras",       "ホンジュラス",     "온두라스"),
    ("ht", "海地",         "Haiti",          "ハイチ",           "아이티"),
    ("im", "马恩岛",       "Isle of Man",    "マン島",           "맨섬"),
    ("io", "英属印度洋领地", "Chagos Is.",    "英領インド洋",     "차고스제도"),
    ("iq", "伊拉克",       "Iraq",           "イラク",           "이라크"),
    ("ir", "伊朗",         "Iran",           "イラン",           "이란"),
    ("je", "泽西岛",       "Jersey",         "ジャージー",       "저지"),
    ("jm", "牙买加",       "Jamaica",        "ジャマイカ",       "자메이카"),
    ("jo", "约旦",         "Jordan",         "ヨルダン",         "요르단"),
    ("ke", "肯尼亚",       "Kenya",          "ケニア",           "케냐"),
    ("kg", "吉尔吉斯斯坦", "Kyrgyzstan",     "キルギス",         "키르기스스탄"),
    ("kh", "柬埔寨",       "Cambodia",       "カンボジア",       "캄보디아"),
    ("ki", "基里巴斯",     "Kiribati",       "キリバス",         "키리바시"),
    ("km", "科摩罗",       "Comoros",        "コモロ",           "코모로"),
    ("kn", "圣基茨和尼维斯", "St. Kitts",     "セントキッツ",     "세인트키츠"),
    ("kp", "朝鲜",         "North Korea",    "北朝鮮",           "북한"),
    ("kw", "科威特",       "Kuwait",         "クウェート",       "쿠웨이트"),
    ("ky", "开曼群岛",     "Cayman Is.",     "ケイマン諸島",     "케이맨제도"),
    ("kz", "哈萨克斯坦",   "Kazakhstan",     "カザフスタン",     "카자흐스탄"),
    ("la", "老挝",         "Laos",           "ラオス",           "라오스"),
    ("lb", "黎巴嫩",       "Lebanon",        "レバノン",         "레바논"),
    ("lc", "圣卢西亚",     "St. Lucia",      "セントルシア",     "세인트루시아"),
    ("li", "列支敦士登",   "Liechtenstein",  "リヒテン",         "리히텐슈타인"),
    ("lk", "斯里兰卡",     "Sri Lanka",      "スリランカ",       "스리랑카"),
    ("lr", "利比里亚",     "Liberia",        "リベリア",         "라이베리아"),
    ("ls", "莱索托",       "Lesotho",        "レソト",           "레소토"),
    ("ly", "利比亚",       "Libya",          "リビア",           "리비아"),
    ("ma", "摩洛哥",       "Morocco",        "モロッコ",         "모로코"),
    ("mc", "摩纳哥",       "Monaco",         "モナコ",           "모나코"),
    ("me", "黑山",         "Montenegro",     "モンテネグロ",     "몬테네그로"),
    ("mf", "圣马丁",       "St. Martin",     "サンマルタン",     "세인트마틴"),
    ("mg", "马达加斯加",   "Madagascar",     "マダガスカル",     "마다가스카르"),
    ("mh", "马绍尔群岛",   "Marshall Is.",   "マーシャル諸島",   "마셜제도"),
    ("ml", "马里",         "Mali",           "マリ",             "말리"),
    ("mm", "缅甸",         "Myanmar",        "ミャンマー",       "미얀마"),
    ("mn", "蒙古",         "Mongolia",       "モンゴル",         "몽골"),
    ("mp", "北马里亚纳",   "N. Mariana Is.", "北マリアナ",       "북마리아나"),
    ("mq", "马提尼克",     "Martinique",     "マルティニーク",   "마르티니크"),
    ("mr", "毛里塔尼亚",   "Mauritania",     "モーリタニア",     "모리타니"),
    ("ms", "蒙特塞拉特",   "Montserrat",     "モントセラト",     "몬트세랫"),
    ("mu", "毛里求斯",     "Mauritius",      "モーリシャス",     "모리셔스"),
    ("mv", "马尔代夫",     "Maldives",       "モルディブ",       "몰디브"),
    ("mw", "马拉维",       "Malawi",         "マラウイ",         "말라위"),
    ("mz", "莫桑比克",     "Mozambique",     "モザンビーク",     "모잠비크"),
    ("na", "纳米比亚",     "Namibia",        "ナミビア",         "나미비아"),
    ("nc", "新喀里多尼亚", "New Caledonia",  "ニューカレドニア", "뉴칼레도니아"),
    ("ne", "尼日尔",       "Niger",          "ニジェール",       "니제르"),
    ("nf", "诺福克岛",     "Norfolk Island", "ノーフォーク島",   "노퍽섬"),
    ("ng", "尼日利亚",     "Nigeria",        "ナイジェリア",     "나이지리아"),
    ("ni", "尼加拉瓜",     "Nicaragua",      "ニカラグア",       "니카라과"),
    ("np", "尼泊尔",       "Nepal",          "ネパール",         "네팔"),
    ("nr", "瑙鲁",         "Nauru",          "ナウル",           "나우루"),
    ("nu", "纽埃",         "Niue",           "ニウエ",           "니우에"),
    ("om", "阿曼",         "Oman",           "オマーン",         "오만"),
    ("pa", "巴拿马",       "Panama",         "パナマ",           "파나마"),
    ("pf", "法属波利尼西亚", "French Polynesia", "仏領ポリネシア", "폴리네시아"),
    ("pg", "巴布亚新几内亚", "Papua New Guinea", "パプア",       "파푸아뉴기니"),
    ("pm", "圣皮埃尔",     "St. Pierre",     "サンピエール",     "생피에르"),
    ("pn", "皮特凯恩",     "Pitcairn",       "ピトケアン",       "핏케언"),
    ("pr", "波多黎各",     "Puerto Rico",    "プエルトリコ",     "푸에르토리코"),
    ("ps", "巴勒斯坦",     "Palestine",      "パレスチナ",       "팔레스타인"),
    ("pw", "帕劳",         "Palau",          "パラオ",           "팔라우"),
    ("py", "巴拉圭",       "Paraguay",       "パラグアイ",       "파라과이"),
    ("qa", "卡塔尔",       "Qatar",          "カタール",         "카타르"),
    ("re", "留尼汪",       "Réunion",        "レユニオン",       "레위니옹"),
    ("rw", "卢旺达",       "Rwanda",         "ルワンダ",         "르완다"),
    ("sb", "所罗门群岛",   "Solomon Is.",    "ソロモン諸島",     "솔로몬제도"),
    ("sc", "塞舌尔",       "Seychelles",     "セーシェル",       "세이셸"),
    ("sd", "苏丹",         "Sudan",          "スーダン",         "수단"),
    ("sh", "圣赫勒拿",     "St. Helena",     "セントヘレナ",     "세인트헬레나"),
    ("sj", "斯瓦尔巴群岛", "Svalbard",       "スバールバル",     "스발바르"),
    ("sl", "塞拉利昂",     "Sierra Leone",   "シエラレオネ",     "시에라리온"),
    ("sm", "圣马力诺",     "San Marino",     "サンマリノ",       "산마리노"),
    ("sn", "塞内加尔",     "Senegal",        "セネガル",         "세네갈"),
    ("so", "索马里",       "Somalia",        "ソマリア",         "소말리아"),
    ("sr", "苏里南",       "Suriname",       "スリナム",         "수리남"),
    ("ss", "南苏丹",       "South Sudan",    "南スーダン",       "남수단"),
    ("st", "圣多美和普林西比", "São Tomé",    "サントメ",         "상투메"),
    ("sv", "萨尔瓦多",     "El Salvador",    "エルサルバドル",   "엘살바도르"),
    ("sx", "荷属圣马丁",   "Sint Maarten",   "シントマールテン", "신트마르턴"),
    ("sy", "叙利亚",       "Syria",          "シリア",           "시리아"),
    ("sz", "斯威士兰",     "Eswatini",       "エスワティニ",     "에스와티니"),
    ("tc", "特克斯群岛",   "Turks & Caicos", "タークス",         "터크스"),
    ("td", "乍得",         "Chad",           "チャド",           "차드"),
    ("tf", "法属南部领地", "French S. Terr.", "仏領南方領土",    "프랑스령남부"),
    ("tg", "多哥",         "Togo",           "トーゴ",           "토고"),
    ("tj", "塔吉克斯坦",   "Tajikistan",     "タジキスタン",     "타지키스탄"),
    ("tk", "托克劳",       "Tokelau",        "トケラウ",         "토켈라우"),
    ("tl", "东帝汶",       "Timor-Leste",    "東ティモール",     "동티모르"),
    ("tm", "土库曼斯坦",   "Turkmenistan",   "トルクメニスタン", "투르크메니스탄"),
    ("tn", "突尼斯",       "Tunisia",        "チュニジア",       "튀니지"),
    ("to", "汤加",         "Tonga",          "トンガ",           "통가"),
    ("tt", "特立尼达和多巴哥", "Trinidad",    "トリニダード",     "트리니다드"),
    ("tv", "图瓦卢",       "Tuvalu",         "ツバル",           "투발루"),
    ("tz", "坦桑尼亚",     "Tanzania",       "タンザニア",       "탄자니아"),
    ("ug", "乌干达",       "Uganda",         "ウガンダ",         "우간다"),
    ("um", "美国本土外小岛", "U.S. Minor Is.", "米領小島",        "미국령군소제도"),
    ("uy", "乌拉圭",       "Uruguay",        "ウルグアイ",       "우루과이"),
    ("uz", "乌兹别克斯坦", "Uzbekistan",     "ウズベキスタン",   "우즈베키스탄"),
    ("va", "梵蒂冈",       "Vatican",        "バチカン",         "바티칸"),
    ("vc", "圣文森特",     "St. Vincent",    "セントビンセント", "세인트빈센트"),
    ("ve", "委内瑞拉",     "Venezuela",      "ベネズエラ",       "베네수엘라"),
    ("vg", "英属维尔京群岛", "British Virgin", "英領バージン",    "영령버진"),
    ("vi", "美属维尔京群岛", "U.S. Virgin",   "米領バージン",     "미령버진"),
    ("vu", "瓦努阿图",     "Vanuatu",        "バヌアツ",         "바누아투"),
    ("wf", "瓦利斯和富图纳", "Wallis & Futuna", "ウォリス",       "왈리스"),
    ("ws", "萨摩亚",       "Samoa",          "サモア",           "사모아"),
    ("ye", "也门",         "Yemen",          "イエメン",         "예멘"),
    ("yt", "马约特",       "Mayotte",        "マヨット",         "마요트"),
    ("zm", "赞比亚",       "Zambia",         "ザンビア",         "잠비아"),
    ("zw", "津巴布韦",     "Zimbabwe",       "ジンバブエ",       "짐바브웨"),
]


def fetch(code, attempts=4):
    """取旗帜原图（带本地缓存），失败返回 None。CDN 偶发限流，退避重试。"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, code + ".png")
    if os.path.exists(path) and os.path.getsize(path) > 512:
        return path
    last = ""
    for i in range(attempts):
        try:
            req = urllib.request.Request(CDN % code, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=25) as r:
                data = r.read()
            if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                last = "非 PNG 响应"
                continue
            if len(data) < 100:
                last = "响应过短"
                continue
            with open(path, "wb") as f:
                f.write(data)
            return path
        except Exception as e:
            last = str(e)
            time.sleep(0.5 + i * 0.7)
    print("  !! %s 下载失败: %s" % (code, last))
    return None


def raster_builder(path):
    """把真实旗帜图铺进 compose_flag 的画框（cover 裁切，不拉伸）。"""
    def build(w, h, img):
        src = Image.open(path).convert("RGB")
        scale = max(w / float(src.width), h / float(src.height))
        nw, nh = max(w, int(round(src.width * scale))), max(h, int(round(src.height * scale)))
        src = src.resize((nw, nh), Image.LANCZOS)
        left, top = (nw - w) // 2, (nh - h) // 2
        img.paste(src.crop((left, top, left + w, top + h)), (0, 0))
        # paste 会盖掉原本的圆角，重新裁一次
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=6, fill=255)
        img.putalpha(mask)
        return img
    return build


def lua_line(code, zh, en, jp, kr):
    """按 CountryConfig.List 的排版生成一行（列宽用全角空格对齐）。"""
    def q(s):
        return '"%s"' % s if s else "nil"

    def pad(s, width):
        # 按显示宽度补空格（全角算 2），保证列对齐
        w = sum(2 if ord(c) > 127 else 1 for c in s)
        return s + " " * max(1, width - w)

    return '    { code = "%s", zh = %s, en = %s, jp = %s, kr = %s },' % (
        code, pad(q(zh), 20), pad(q(en), 22), pad(q(jp), 22), q(kr))


def main():
    force = "--force" in sys.argv
    dry = "--dry" in sys.argv
    existing = set()
    for fn in os.listdir(OUT_DIR):
        if fn.startswith("cn2-guoqi_") and fn.endswith(".png"):
            existing.add(fn[len("cn2-guoqi_"):-4])
    print("现有旗帜：%d 面" % len(existing))

    todo = [c for c in NEW_COUNTRIES if c[0] not in existing or force]
    print("待补旗帜：%d 面" % len(todo))

    ok, failed = [], []
    for code, zh, en, jp, kr in todo:
        src = fetch(SOURCE_OVERRIDE.get(code, code))
        if src is None:
            failed.append(code)
            continue
        if dry:
            ok.append(code)
            continue
        img = art.compose_flag(raster_builder(src))
        img.save(os.path.join(OUT_DIR, "cn2-guoqi_%s.png" % code), "PNG", optimize=True)
        ok.append(code)

    print("✅ 生成 %d 面%s" % (len(ok), "（dry-run）" if dry else ""))
    if failed:
        print("❌ 失败 %d 面：%s" % (len(failed), ", ".join(failed)))

    # Lua 片段（按全部新增国家的 code 排序便于 review；以图集里实际存在为准）
    if not dry:
        rows = sorted([c for c in NEW_COUNTRIES
                       if os.path.exists(os.path.join(OUT_DIR, "cn2-guoqi_%s.png" % c[0]))])
        os.makedirs(os.path.dirname(LUA_BLOCK), exist_ok=True)
        with open(LUA_BLOCK, "w", encoding="utf-8", newline="\n") as f:
            for code, zh, en, jp, kr in rows:
                f.write(lua_line(code, zh, en, jp, kr) + "\n")
        print("Lua 片段：%s（%d 行）" % (LUA_BLOCK, len(rows)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
