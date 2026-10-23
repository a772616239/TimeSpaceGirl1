#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ASO 关键词周期引擎：挖词 → 打分 → 出策略 → （可选）派生变体 → 记历史账本。

    aso_keyword_cycle.py gate --days 3            # 节流闸门（rc 0 可跑 / rc 3 未到周期）
    aso_keyword_cycle.py plan --baseline A        # 出策略报告（默认不写文案）
    aso_keyword_cycle.py plan --baseline A --emit-variant C --apply-rules
    aso_keyword_cycle.py ledger --tail 8          # 看历史轮次
    aso_keyword_cycle.py record --variant C --element copy --note "..."

为什么单独一个脚本
------------------
`aso_lint` 只判断「有没有病」，`aso_play` 只负责搬运，`aso_experiment` 只管窗口登记。
缺的是「这一轮到底该动哪个词、动完跟历史上比有没有新信息」——那需要把
线上 listing、变体文案、素材快照、实验结论放在一起算。这是本脚本唯一的职责。

三条纪律（写在代码里，不靠人记）
--------------------------------
1. **不自动生成文案**：`rewrite_rules.json` 只执行登记过的替换对。没登记的词
   只进报告当建议，绝不塞进 title —— 机翻式改写会同时毁掉可读性和关键词密度。
2. **不重复测同一个东西**：账本记录每轮的动作与结论；本轮 top 词与上轮重合度
   过高且上轮「无显著差异」时，报告直接标红，不出新变体。
3. **不改基线**：`A` 永远是线上快照。任何派生只写新目录。

退出码：0 正常 / 1 有阻断 / 2 用法错 / 3 未到周期 / 4 无实质改动（不派发变体）
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aso_common as C  # noqa: E402
import aso_lint as LINT  # noqa: E402  （复用夸大词表与简繁表，不写第二份）

KEY_DIR = C.ASO_ROOT / "keywords"
STATE_FILE = KEY_DIR / ".state.json"
LEDGER_FILE = KEY_DIR / "ledger.jsonl"
SEED_FILE = KEY_DIR / "seed_terms.json"
RULES_FILE = KEY_DIR / "rewrite_rules.json"

# 一轮实验最短可读窗口。Play 官方建议覆盖完整周周期；3 天只够推进节奏，不够下结论。
MIN_READ_DAYS = 7
MIN_VISITORS = 1000

FIELD_WEIGHT = {"title": 3.0, "shortDescription": 2.0, "fullDescription": 1.0}
# 语料来源的可信度：线上现状 > 待发变体 > 历史快照（越旧越可能已失效）
SOURCE_WEIGHT = {"online": 1.0, "variant": 0.8, "snapshot": 0.4}

LATIN_STOP = set("""
a an the and or but if then than that this these those you your yours we our ours
it its it's is are was were be been being do does did doing have has had having
to of in on at by for from with without into out up down over under again more most
no not only own same so too very can will just don should now i me my he she they
them his her their there here what which who whom when where why how all any both
each few other some such nor as until while about after before during through
game games app play player players free new get gets got make makes made like one
two three your can't don't ever even still yet because every those through about
after before during while where which what whose whom
""".split())

# 中日繁的高频虚词/构词碎片：单字级黑名单，命中即丢弃该 n-gram。
# 注意：只放「单独成词无意义」的字，避免把「卡牌」这种真词砍掉。
CJK_STOP = set("""
の は を に で と が た し て す る な い か も へ や だ ら れ り さ せ ず ね よ を
ます です でした する した して から まで より こと もの ため よう そう たち
我 你 他 她 它們 的 了 是 在 有 和 就 都 而 及 與 这 那 个 個 上 下 不 也 很 更 最
會 会 能 可 以 為 为 對 对 到 从 從 把 被 讓 让 給 给 用 中 内 內 外 前 後 后 时 時
分 秒 些 什 麼 么 怎 樣 样 嗎 吗 呢 吧 啊 呀 哦 嗯 一 二 三 四 五 六 七 八 九 十
等 又 再 才 但 並 并 而 且 或 若 則 则 即 使 被 將 将 已 未 曾 尚 均 皆 各 每 与
""".split())


# --------------------------------------------------------------------------- #
# 基础 IO
# --------------------------------------------------------------------------- #
def _load_json(p: Path, default: dict | None = None) -> dict:
    if not p.is_file():
        return default or {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"🔴 JSON 语法错误 {p}:{exc.lineno}:{exc.colno} — {exc.msg}")


def _write_json(p: Path, data) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_seed() -> dict:
    seed = _load_json(SEED_FILE)
    if not seed:
        raise SystemExit(f"缺少种子词表：{SEED_FILE}")
    return seed.get("locales", {})


def load_rules() -> dict:
    return _load_json(RULES_FILE, {"enabled": False, "rules": {}})


def seed_sets(locale: str) -> tuple[set, set, set, set]:
    """返回 (core, modifier, banned, brand)。brand=品牌词，权重最高、且参与遮蔽。"""
    d = load_seed().get(locale, {})
    norm = lambda xs: {str(x).strip().lower() for x in (xs or []) if str(x).strip()}
    return norm(d.get("core")), norm(d.get("modifier")), norm(d.get("banned")), \
        norm(d.get("brand"))


# --------------------------------------------------------------------------- #
# 语料汇集
# --------------------------------------------------------------------------- #
def latest_online() -> tuple[Path | None, dict]:
    """最近一次 aso_play.py list 导出的线上 listing。"""
    if not C.ONLINE_DIR.is_dir():
        return None, {}
    cands = [p for p in C.ONLINE_DIR.iterdir() if (p / "listings.json").is_file()]
    if not cands:
        return None, {}
    newest = max(cands, key=lambda p: p.stat().st_mtime)
    return newest, _load_json(newest / "listings.json")


def iter_snapshots(limit: int = 12):
    d = C.ASO_ROOT / "snapshots"
    if not d.is_dir():
        return []
    files = sorted(d.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:limit]
    out = []
    for f in files:
        snap = _load_json(f)
        if snap.get("listings"):
            out.append(snap)
    return out


def load_experiments() -> list[dict]:
    d = C.EXPERIMENTS_DIR
    if not d.is_dir():
        return []
    rows = []
    for f in sorted(d.glob("*.json")):
        e = _load_json(f)
        if e.get("id"):
            rows.append(e)
    return rows


def verdict_map(exps: list[dict]) -> dict[str, str]:
    """变体 → win/loss。只认已经落盘的 readout.verdict，没读数的一律不猜。"""
    out = {}
    for e in exps:
        rd = e.get("readout") or {}
        v = str(rd.get("verdict") or "")
        if "胜出" not in v:
            if v:
                out[e.get("variant", "")] = "flat"
            continue
        # 「B 胜出 +12%」⇒ 变体 win；「A 胜出」⇒ 变体 loss
        out[e.get("variant", "")] = "win" if v.strip().startswith(str(e.get("variant"))) else "loss"
    return out


def collect(locales: list[str]) -> dict:
    """把四类证据压成一个扁平结构，后面的打分只看这一份。"""
    online_dir, online = latest_online()
    ev = {
        "at": datetime.now().isoformat(timespec="seconds"),
        "online_dir": str(online_dir) if online_dir else None,
        "online": {},
        "variants": {},
        "snapshots": [],
        "experiments": load_experiments(),
    }
    for loc in locales:
        d = online.get(loc) or {}
        if d and not d.get("error"):
            ev["online"][loc] = C.text_fields(d)

    for v in C.list_variants():
        per = {}
        for loc, listing in C.iter_listings(v, locales):
            per[loc] = C.text_fields(listing)
        if per:
            ev["variants"][v] = per

    for snap in iter_snapshots():
        per = {}
        for loc in locales:
            d = (snap.get("listings") or {}).get(loc)
            if d:
                per[loc] = C.text_fields(d)
        if per:
            ev["snapshots"].append({"at": snap.get("at"), "variant": snap.get("variant"),
                                    "listings": per})
    return ev


# --------------------------------------------------------------------------- #
# 分词
# --------------------------------------------------------------------------- #
LATIN_RE = re.compile(r"[a-z][a-z0-9']*")


def _char_class(ch: str) -> str:
    o = ord(ch)
    if 0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF:
        return "han"
    if 0x30A0 <= o <= 0x30FF:
        return "kata"
    if 0x3040 <= o <= 0x309F:
        return "hira"
    return "other"


def latin_terms(text: str, known_phrases: set[str]) -> list[str]:
    """拉丁语种：单词 unigram + 词表里登记过的短语。

    🔴 不生成任意 bigram。第一版做了 `zip(words, words[1:])`，结果「valkyries anime」
    「anime idle」这类跨词垃圾占满前 10 名 —— 英文短语必须来自词表，不能靠相邻猜测。
    """
    low = text.lower()
    words = [w for w in LATIN_RE.findall(low)
             if w not in LATIN_STOP and len(w) >= 3]
    grams = list(words)
    for p in sorted(known_phrases, key=len, reverse=True):
        if " " in p and p in low:
            grams.append(p)
    return grams


def cjk_terms(text: str, known: set[str]) -> list[str]:
    """中日文：先用词表做最长优先遮蔽，再在遮蔽区外按「同类字符连续段」抽 2~4 字。

    🔴 两个坑（第一版都踩了）：
      1. 直接对整句抽 n-gram ⇒ 「タク」「クテ」「置タ」这类词内/跨词碎片霸榜。
         修法：汉字段与片假名段分开抽，平假名段整段丢弃（日语关键词几乎不用平假名）。
      2. 纯 n-gram 抓不到品牌名（「超时空美少女」6 字 > 上限 4）。
         修法：词表（含 brand）先命中并遮蔽，命中词本身以高权重计入。
    """
    n = len(text)
    masked = [False] * n
    hits: list[str] = []
    for w in sorted(known, key=len, reverse=True):
        if len(w) < 2:
            continue
        start = 0
        while True:
            i = text.find(w, start)
            if i < 0:
                break
            for k in range(i, i + len(w)):
                masked[k] = True
            hits.append(w)
            start = i + len(w)

    out = list(hits)
    i = 0
    while i < n:
        cls = _char_class(text[i])
        if masked[i] or cls not in ("han", "kata"):
            i += 1
            continue
        j = i
        while j < n and not masked[j] and _char_class(text[j]) == cls:
            j += 1
        seg = text[i:j]
        if len(seg) >= 2:
            for ln in (2, 3, 4):
                for k in range(len(seg) - ln + 1):
                    g = seg[k:k + ln]
                    if any(ch in CJK_STOP for ch in g):
                        continue
                    out.append(g)
        i = j
    return out


def terms_of(text: str, locale: str, known: set[str]) -> list[str]:
    return latin_terms(text, known) if locale == "en-US" else cjk_terms(text, known)


def suppress_substrings(stats: dict[str, dict]) -> dict[str, dict]:
    """去掉「被更长且分数相当的高分词完整包含」的碎片。

    例：`美少`(54.6) 被 `美少女`(57.6) 吃掉；`タクティ`(48.8) 被 `タクティクス` 吃掉。
    但 `战棋`(57.2) 不会被 `放置战棋`(37.6) 吃掉 —— 短词独立价值更高时两者都留。
    """
    kept: dict[str, dict] = {}
    for term in sorted(stats, key=lambda t: (-len(t), -stats[t]["score"])):
        st = stats[term]
        eaten = False
        for h in kept:
            if len(h) > len(term) and term in h and kept[h]["score"] >= st["score"] * 0.9:
                eaten = True
                break
        if not eaten:
            kept[term] = st
    return kept


def _is_hype(term: str) -> bool:
    low = term.lower()
    return any(pat.lower() in low for pat, _ in LINT.HYPE_PATTERNS)


def _smells(locale: str, term: str) -> bool:
    """串味检测：ja/繁 里出现简体专用字 ⇒ 这个词不能用。"""
    if locale == "ja-JP":
        return any(ch in LINT.SIMPLIFIED_ONLY for ch in term)
    if locale == "zh-TW":
        return any(ch in LINT.SIMPLIFIED_MAP for ch in term)
    return False


# --------------------------------------------------------------------------- #
# 打分
# --------------------------------------------------------------------------- #
def build_stats(ev: dict, locales: list[str]) -> dict[str, dict[str, dict]]:
    """返回 stats[locale][term] = {tf, sources, in_title, seed, tested}。"""
    vmaps = verdict_map(ev["experiments"])
    stats: dict[str, dict[str, dict]] = {loc: {} for loc in locales}

    def bump(loc: str, term: str, field: str, src_kind: str, src_key: str,
             variant: str | None):
        if not term:
            return
        st = stats[loc].setdefault(term, {
            "tf": 0.0, "sources": set(), "in_title": 0, "title_seen": 0,
            "variants": set(), "hype": _is_hype(term), "smell": _smells(loc, term),
        })
        st["tf"] += FIELD_WEIGHT.get(field, 1.0) * SOURCE_WEIGHT.get(src_kind, 1.0)
        st["sources"].add(f"{src_kind}:{src_key}")
        if field == "title":
            st["in_title"] += 1
        if variant:
            st["variants"].add(variant)

    for loc in locales:
        core, modifier, banned, brand = seed_sets(loc)
        known = core | modifier | brand
        if loc in ev["online"]:
            for f in ("title", "shortDescription", "fullDescription"):
                for t in terms_of(ev["online"][loc].get(f, ""), loc, known):
                    bump(loc, t, f, "online", "latest", None)
        for variant, per in ev["variants"].items():
            if loc not in per:
                continue
            for f in ("title", "shortDescription", "fullDescription"):
                for t in terms_of(per[loc].get(f, ""), loc, known):
                    bump(loc, t, f, "variant", variant, variant)
        for snap in ev["snapshots"]:
            per = snap.get("listings") or {}
            if loc not in per:
                continue
            key = snap.get("at") or "old"
            for f in ("title", "shortDescription"):
                for t in terms_of(per[loc].get(f, ""), loc, known):
                    bump(loc, t, f, "snapshot", key, snap.get("variant"))

    # 收口：算分、剔禁忌词、去碎片
    for loc, terms in stats.items():
        core, modifier, banned, brand = seed_sets(loc)
        for term, st in list(terms.items()):
            if st["hype"] or st["smell"] or term.lower() in banned:
                del terms[term]
                continue
            score = 0.0
            score += st["tf"]
            # 🔴 「来源种类」不计分：线上/变体/快照三类几乎每个词都命中，是常数偏移，
            #    加进去只是把所有分数整体抬 7.5，不产生任何区分度（排序完全一样）。
            #    第一版按「来源份数」算更糟：快照越攒越多，每个词都变成「来源 10」。
            #    跨版本稳定性已经由 tf 里的 SOURCE_WEIGHT 体现（快照 0.4 / 变体 0.8）。
            kinds = {s.split(":")[0] for s in st["sources"]}
            score += 2.0 * st["in_title"]
            if term.lower() in brand:
                score += 4.0
            elif term.lower() in core:
                score += 3.0
            elif term.lower() in modifier:
                score += 1.5
            # 历史结论：在该变体里唯一出现且该变体输了 ⇒ 降权（不判死刑，只压一档）
            vs = {v for v in st["variants"] if v}
            if vs:
                verdicts = {vmaps.get(v, "") for v in vs}
                if verdicts == {"loss"} and len(vs) == 1:
                    score -= 2.0
                elif "win" in verdicts:
                    score += 2.0
            st["score"] = round(score, 2)
            st["sources"] = sorted(st["sources"])
            st["kinds"] = sorted(kinds)
            st["variants"] = sorted(vs)
            st["brand"] = term.lower() in brand
        stats[loc] = suppress_substrings(terms)
    return stats


def rank(stats: dict[str, dict[str, dict]], locale: str, top: int = 18) -> list[dict]:
    rows = sorted(stats.get(locale, {}).items(), key=lambda kv: -kv[1]["score"])[:top]
    return [{
        "term": term,
        "score": st["score"],
        "tf": round(st["tf"], 2),
        "sources": len(st["sources"]),
        "kinds": len(st.get("kinds") or []),
        "in_title": st["in_title"],
        "brand": bool(st.get("brand")),
        "variants": st["variants"],
    } for term, st in rows]


# --------------------------------------------------------------------------- #
# 文案建议（只建议，不改文件）
# --------------------------------------------------------------------------- #
def apply_rule_pairs(locale: str, text: str, rules: dict, field: str) -> tuple[str, list[dict]]:
    """执行登记过的替换对。返回 (新文本, 命中清单)。"""
    hits: list[dict] = []
    if not rules.get("enabled"):
        return text, hits
    for r in (rules.get("rules", {}).get(locale, {}).get(field) or []):
        src, dst = str(r.get("from") or ""), str(r.get("to") or "")
        if not src or src not in text:
            continue
        new = text.replace(src, dst)
        if new != text:
            hits.append({"field": field, "from": src, "to": dst,
                         "chars": [len(text), len(new)]})
            text = new
    return text, hits


def advise(locale: str, cur: dict, top: list[dict], rules: dict) -> dict:
    """给每语一份「建议动作」：能自动执行的是规则替换，其余只做可插入词提示。"""
    out = {"locale": locale, "rule_hits": [], "title_room": 0,
           "title_candidates": [], "short_candidates": [], "notes": []}
    title = cur.get("title", "")
    short = cur.get("shortDescription", "")
    out["chars"] = {"title": len(title), "short": len(short),
                    "full": len(cur.get("fullDescription", ""))}
    out["title_room"] = C.LIMITS["title"] - len(title)

    new_title, hits = apply_rule_pairs(locale, title, rules, "title")
    new_short, hits2 = apply_rule_pairs(locale, short, rules, "shortDescription")
    out["rule_hits"] = hits + hits2
    out["proposed"] = {"title": new_title, "shortDescription": new_short}

    for h in hits:
        if h["chars"][1] > C.LIMITS["title"]:
            out["notes"].append(
                f"规则把 title 撑到 {h['chars'][1]}/{C.LIMITS['title']}，超限，需先减字")
    # 未在文案里的高分词：只能提示，绝不自动塞（会破坏语义与可读性）
    present = (title + " " + short).lower()
    for r in top:
        if r["term"].lower() in present:
            continue
        need = len(r["term"]) + 1
        if need <= out["title_room"]:
            out["title_candidates"].append(r["term"])
        out["short_candidates"].append(r["term"])
    out["title_candidates"] = out["title_candidates"][:6]
    out["short_candidates"] = out["short_candidates"][:8]
    return out


# --------------------------------------------------------------------------- #
# 发布阻断
# --------------------------------------------------------------------------- #
def open_experiment(exps: list[dict], today: date | None = None) -> dict | None:
    """找仍在读数窗口内的实验。返回 {id, variant, days_total, remaining, ...}。"""
    today = today or date.today()
    alive = [e for e in exps if e.get("status") in ("planned", "running")]
    if not alive:
        return None
    alive.sort(key=lambda e: e.get("created", ""), reverse=True)
    e = alive[0]
    ws = e.get("windows") or []
    start = None
    for w in ws:
        if w.get("variant") == e.get("variant") and w.get("start"):
            start = w["start"]
    if not start:
        start = str(today)
    try:
        s = date.fromisoformat(str(start)[:10])
    except ValueError:
        s = today
    total = int(e.get("window_days") or 14)
    elapsed = (today - s).days
    return {"id": e.get("id"), "variant": e.get("variant"), "element": e.get("element"),
            "start": str(s), "days_total": total, "remaining": max(0, total - elapsed),
            "readable": elapsed >= max(MIN_READ_DAYS, total)}


# --------------------------------------------------------------------------- #
# 变体派生
# --------------------------------------------------------------------------- #
def next_variant_name() -> str:
    used = set(C.list_variants())
    for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
        if ch not in used:
            return ch
    raise SystemExit("变体字母用完了，清一下 variants/ 里过期的目录")


def default_parent(baseline: str) -> str:
    """派生起点：优先「最新的 treatment」，而不是基线 A。

    🔴 为什么要分开：A 是线上历史快照，它**自带已知缺陷**（zh-TW 长描述是简体、
    ja 标题混了简体「时」）。从 A 派生出来的新变体会把这些问题一起继承，
    lint 阶段一片红，看起来像「本轮改动有问题」，实际是父本的锅。
    所以：baseline 只用于实验对照记分，parent 才是真正被改的那一版。
    """
    cands = [v for v in C.list_variants() if v != baseline]
    if not cands:
        return baseline
    treatments = []
    for v in cands:
        meta = C.load_variant_meta(v)
        if meta.get("role") == "treatment":
            treatments.append(v)
    pool = treatments or cands
    return max(pool, key=lambda v: (C.VARIANTS_DIR / v).stat().st_mtime)


def _red_sig(s: str) -> str:
    """把阻断项里的数字抹平，让「同一个问题」在不同文案长度下可以比较。"""
    return re.sub(r"\d+", "#", s)


def cmd_lint_gate(args) -> int:
    """文案闸门（增量口径）：只拦「本轮新引入的红」，父本自带的红只提示。

    为什么不能直接用 aso_lint 的 rc：它的口径是「这份文案有没有病」，用来判
    「这一轮改动合不合格」会把父本的历史债算到本轮头上 —— 于是永远发不出去。
    """
    locales = C.parse_locales(args.locales)
    if not (C.VARIANTS_DIR / args.variant).is_dir():
        print(f"🔴 变体不存在：{args.variant}")
        return 2
    parent = args.parent or ""
    parent_ok = bool(parent) and (C.VARIANTS_DIR / parent).is_dir()
    rows, added = [], 0
    for loc in locales:
        red, yellow, summary = LINT.check_one(args.variant, loc)
        base_red = set()
        if parent_ok:
            base_red = {_red_sig(x) for x in LINT.check_one(parent, loc)[0]}
        fresh = [x for x in red if _red_sig(x) not in base_red]
        inherited = [x for x in red if _red_sig(x) in base_red]
        added += len(fresh)
        c = summary.get("chars", {})
        rows.append([loc, C.LOCALES[loc]["label"],
                     f"{c.get('title', 0)}/{C.LIMITS['title']}",
                     f"{c.get('shortDescription', 0)}/{C.LIMITS['shortDescription']}",
                     f"{c.get('fullDescription', 0)}/{C.LIMITS['fullDescription']}",
                     f"新增红 {len(fresh)}", f"继承红 {len(inherited)}"])
        for x in fresh:
            print(f"  🔴 {loc}: {x}")
        for x in inherited:
            print(f"  🟡 {loc}（继承自 {parent}）: {x}")
    print(f"\n=== 增量闸门：{args.variant}（父本 {parent or '无'}）===")
    C.print_table(rows, ["locale", "语言", "标题", "短描述", "长描述", "问题", "继承"])
    print(f"\n新增阻断 {added} 项" + ("" if parent_ok else "（没指定父本，全部按新增算）"))
    return 0 if added == 0 else 1


def emit_variant(parent: str, target: str, locales: list[str], rules: dict,
                 strategy: dict) -> tuple[bool, list[str]]:
    """从父本派生一个变体目录。返回 (是否落盘, 变更清单)。无实质改动不落盘。"""
    src = C.VARIANTS_DIR / parent
    if not src.is_dir():
        raise SystemExit(f"父本变体不存在：{src}")
    out = C.VARIANTS_DIR / target
    changes: list[str] = []
    payload: dict[str, dict] = {}

    for loc in locales:
        cur = C.load_listing(parent, loc)
        new = dict(cur)
        for f in ("title", "shortDescription"):
            new[f], hits = apply_rule_pairs(loc, cur.get(f, ""), rules, f)
            for h in hits:
                changes.append(f"{loc}/{f}: 「{h['from']}」→「{h['to']}」"
                               f"（{h['chars'][0]}→{h['chars'][1]} 字）")
        for f, lim in (("title", C.LIMITS["title"]),
                       ("shortDescription", C.LIMITS["shortDescription"])):
            if len(new.get(f, "")) > lim:
                raise SystemExit(f"🔴 {loc}/{f} 派生后 {len(new[f])}>{lim} 字，拒绝落盘")
        payload[loc] = new

    if not changes:
        return False, []

    out.mkdir(parents=True, exist_ok=True)
    for loc, d in payload.items():
        _write_json(out / f"{loc}.json", d)
    meta = {
        "label": f"周期 {strategy.get('cycle')} 派生（{parent} 的规则替换版）",
        "role": "treatment",
        "parent": parent,
        "baseline": strategy.get("baseline"),
        "cycle": strategy.get("cycle"),
        "generated_by": "aso_keyword_cycle.py plan --emit-variant",
        "hypothesis": (f"在 {parent} 基础上按关键词策略做受控替换（{'；'.join(changes[:3])}），"
                       f"验证关键词口径对齐搜索意图后商店页转化率是否提升。"),
        "variables": changes,
        "keep": ["icon / featureGraphic / phoneScreenshots 一律不动（图片另开窗口）",
                 "video 链接不动", "fullDescription 不动（长描述重写风险高，单独一轮）"],
        "readout_window_days": MIN_READ_DAYS,
    }
    _write_json(out / "meta.json", meta)
    return True, changes


# --------------------------------------------------------------------------- #
# 账本
# --------------------------------------------------------------------------- #
def read_ledger() -> list[dict]:
    if not LEDGER_FILE.is_file():
        return []
    rows = []
    for line in LEDGER_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def append_ledger(row: dict) -> None:
    LEDGER_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER_FILE.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")


def overlap(a: list[str], b: list[str]) -> float:
    sa, sb = set(a), set(b)
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / len(sa | sb)


def repeat_warning(ledger: list[dict], top_by_locale: dict[str, list[str]]) -> list[str]:
    """本轮 top 词与上一轮高度重合且上轮无显著差异 ⇒ 提示别再测同一组。"""
    if not ledger:
        return []
    last = ledger[-1]
    prev = last.get("top") or {}
    out = []
    for loc, terms in top_by_locale.items():
        ov = overlap(terms, prev.get(loc) or [])
        if ov >= 0.8:
            verdict = (last.get("readout") or {}).get("verdict") or last.get("status") or "-"
            out.append(f"{loc}: 与本轮关键词池重合 {ov:.0%}（上一轮 {last.get('cycle')}，"
                       f"结论 {verdict}）⇒ 换词或换元素，别重复测")
    return out


# --------------------------------------------------------------------------- #
# gate
# --------------------------------------------------------------------------- #
def cmd_gate(args) -> int:
    st = _load_json(STATE_FILE, {})
    last = st.get("last_cycle_at")
    if args.force or not last:
        print(f"[gate] 放行（{'--force' if args.force else '首轮'}），周期 {args.days} 天")
        return 0
    try:
        last_dt = datetime.fromisoformat(last)
    except ValueError:
        print(f"[gate] 状态文件里的时间戳坏了（{last}），按首轮放行")
        return 0
    delta = datetime.now() - last_dt
    if delta >= timedelta(days=args.days):
        print(f"[gate] 放行：距上次 {delta.total_seconds() / 3600:.1f}h ≥ {args.days * 24}h")
        return 0
    left = timedelta(days=args.days) - delta
    print(f"[gate] 跳过：距上次 {delta.total_seconds() / 3600:.1f}h，"
          f"未到 {args.days} 天（还差 {left.total_seconds() / 3600:.1f}h）")
    return 3


# --------------------------------------------------------------------------- #
# plan
# --------------------------------------------------------------------------- #
def cmd_plan(args) -> int:
    locales = C.parse_locales(args.locales)
    base = args.baseline
    if not (C.VARIANTS_DIR / base).is_dir():
        raise SystemExit(f"基线变体不存在：{base}")
    parent = args.parent.strip() or default_parent(base)
    if not (C.VARIANTS_DIR / parent).is_dir():
        raise SystemExit(f"父本变体不存在：{parent}")
    cycle = args.cycle or f"{datetime.now():%Y%m%d}"
    ev = collect(locales)
    stats = build_stats(ev, locales)
    rules = load_rules()

    top = {loc: rank(stats, loc) for loc in locales}
    top_terms = {loc: [r["term"] for r in rows] for loc, rows in top.items()}
    ledger = read_ledger()
    warn = repeat_warning(ledger, top_terms)

    advice = {}
    for loc in locales:
        cur = C.load_listing(parent, loc)
        advice[loc] = advise(loc, cur, top[loc], rules)

    open_exp = open_experiment(ev["experiments"])
    blockers = []
    if args.block_on_open_exp and open_exp and not open_exp["readable"]:
        blockers.append(
            f"实验 {open_exp['id']} 仍在窗口内（{open_exp['variant']}，"
            f"已过 {open_exp['days_total'] - open_exp['remaining']}/"
            f"{open_exp['days_total']} 天，剩 {open_exp['remaining']} 天）"
            f"—— 读数需要 ≥{MIN_READ_DAYS} 天，此时换版会把两个变量混在一起")
    if warn:
        blockers.append("关键词池与上一轮重合过高（见 repeat_warning）")
    if not rules.get("enabled"):
        blockers.append("rewrite_rules.json 未启用：本轮只出策略，不产生可发布变更")

    strategy = {
        "cycle": cycle,
        "at": datetime.now().isoformat(timespec="seconds"),
        "baseline": base,
        "parent": parent,
        "locales": locales,
        "cycle_days": args.days,
        "evidence": {
            "online_dir": ev["online_dir"],
            "online_locales": sorted(ev["online"]),
            "variants": sorted(ev["variants"]),
            "snapshots": len(ev["snapshots"]),
            "experiments": len(ev["experiments"]),
        },
        "top": {loc: top[loc][:12] for loc in locales},
        "advice": advice,
        "open_experiment": open_exp,
        "repeat_warnings": warn,
        "publish_blockers": blockers,
        "emit_variant": None,
    }

    emitted, changes = (False, [])
    if args.emit_variant and not args.no_emit:
        target = args.emit_variant if args.emit_variant != "auto" else next_variant_name()
        if target in (base, parent):
            raise SystemExit(f"目标变体不能等于基线 {base} 或父本 {parent}")
        emitted, changes = emit_variant(parent, target, locales, rules, strategy)
        if emitted:
            strategy["emit_variant"] = target
            strategy["changes"] = changes
            strategy["hypothesis"] = (f"在 {parent} 基础上按关键词策略做受控替换"
                                      f"（{len(changes)} 处），验证关键词口径对齐搜索意图后"
                                      f"商店页转化率是否提升。")

    out_dir = KEY_DIR / cycle
    _write_json(out_dir / "strategy.json", strategy)

    # 人读报告
    md = [f"# ASO 关键词策略 · 周期 {cycle}", "",
          f"- 时间：{strategy['at']}",
          f"- 对照基线：{base}　派生父本：{parent}　语言：{', '.join(locales)}",
          f"- 证据：线上 {ev['online_dir'] or '(未导出)'}；变体 {len(ev['variants'])} 个；"
          f"快照 {len(ev['snapshots'])} 份；实验 {len(ev['experiments'])} 个", ""]
    if blockers:
        md += ["## 本轮阻断（不发布）", ""] + [f"- 🔴 {b}" for b in blockers] + [""]
    if emitted:
        md += [f"## 已派生变体 {strategy['emit_variant']}", ""] + \
              [f"- {c}" for c in changes] + [""]
    else:
        md += ["## 未派生变体", "",
               "- 原因：没有命中任何已启用的改写规则（或规则文件未启用）",
               "- 下面每语的「可插入词」是建议，不是自动改动；填进 "
               "`data_aso/keywords/rewrite_rules.json` 才会被执行", ""]

    for loc in locales:
        a = advice[loc]
        md += [f"## {loc}（{C.LOCALES[loc]['label']}）", "",
               f"字数：title {a['chars']['title']}/{C.LIMITS['title']}　"
               f"short {a['chars']['short']}/{C.LIMITS['shortDescription']}　"
               f"full {a['chars']['full']}/{C.LIMITS['fullDescription']}", ""]
        md += ["| # | 词 | 得分 | 加权TF | 来源类 | 已在标题 | 品牌 |",
               "|---|---|---|---|---|---|---|"]
        for i, r in enumerate(top[loc][:12], 1):
            md.append(f"| {i} | {r['term']} | {r['score']} | {r['tf']} | "
                      f"{r['kinds']}/3 | {'是' if r['in_title'] else '否'} | "
                      f"{'★' if r['brand'] else ''} |")
        md.append("")
        if a["title_candidates"]:
            md.append(f"- title 还有 {a['title_room']} 字空间，可考虑："
                      f"{'、'.join(a['title_candidates'])}")
        if a["short_candidates"]:
            md.append(f"- 短描述未覆盖的高分词：{'、'.join(a['short_candidates'][:6])}")
        for n in a["notes"]:
            md.append(f"- ⚠ {n}")
        md.append("")
    if warn:
        md += ["## 重复风险", ""] + [f"- {w}" for w in warn] + [""]
    md += ["## 历史轮次（最近 8 轮）", ""]
    if ledger:
        md += ["| 周期 | 变体 | 元素 | 状态 | 结论 |", "|---|---|---|---|---|"]
        for r in ledger[-8:]:
            md.append(f"| {r.get('cycle')} | {r.get('variant')} | {r.get('element')} | "
                      f"{r.get('status')} | {(r.get('readout') or {}).get('verdict', '-')} |")
    else:
        md.append("- （账本为空，这是第一轮）")
    md.append("")
    (out_dir / "strategy.md").write_text("\n".join(md), encoding="utf-8")

    print("\n".join(md))
    print(f"[plan] strategy.json → {out_dir / 'strategy.json'}")
    if emitted:
        print(f"[plan] 已派生变体 {strategy['emit_variant']}（{len(changes)} 处改动）")
        return 0
    if args.emit_variant and not args.no_emit:
        print("[plan] 没有命中已启用的改写规则 ⇒ 未派生变体（rc=4，非错误）")
        return 4
    return 0


# --------------------------------------------------------------------------- #
# ledger / record
# --------------------------------------------------------------------------- #
def cmd_ledger(args) -> int:
    rows = read_ledger()
    if not rows:
        print("账本为空：data_aso/keywords/ledger.jsonl")
        return 0
    table = []
    for r in rows[-args.tail:]:
        rd = r.get("readout") or {}
        table.append([str(r.get("cycle")), str(r.get("variant") or "-"),
                      str(r.get("element") or "-"), str(r.get("status") or "-"),
                      str(rd.get("verdict") or "-"),
                      str(rd.get("uplift_pct") if rd.get("uplift_pct") is not None else "-")])
    C.print_table(table, ["周期", "变体", "元素", "状态", "结论", "uplift%"])
    return 0


def cmd_record(args) -> int:
    strategy = {}
    if args.cycle:
        p = KEY_DIR / args.cycle / "strategy.json"
        if p.is_file():
            strategy = _load_json(p)
    exps = load_experiments()
    exp = None
    if args.experiment:
        exp = next((e for e in exps if e.get("id") == args.experiment), None)
    if exp is None:
        cand = [e for e in exps if e.get("variant") == args.variant]
        if cand:
            cand.sort(key=lambda e: e.get("created", ""), reverse=True)
            exp = cand[0]
    readout = (exp or {}).get("readout") or {}
    row = {
        "cycle": args.cycle or f"{datetime.now():%Y%m%d}",
        "at": datetime.now().isoformat(timespec="seconds"),
        "variant": args.variant,
        "baseline": args.baseline,
        "element": args.element,
        "status": args.status,
        "hypothesis": args.hypothesis or strategy.get("hypothesis") or "",
        "experiment": (exp or {}).get("id"),
        "readout": readout or None,
        "publish": args.publish,
        "changes": strategy.get("changes") or [],
        "top": {loc: [r["term"] for r in rows[:10]]
                for loc, rows in (strategy.get("top") or {}).items()},
        "note": args.note,
    }
    append_ledger(row)

    st = _load_json(STATE_FILE, {})
    st["last_cycle_at"] = row["at"]
    st["last_cycle"] = row["cycle"]
    st["last_variant"] = args.variant
    _write_json(STATE_FILE, st)
    print(f"[record] 已记账本：周期 {row['cycle']} 变体 {args.variant} "
          f"元素 {args.element} 状态 {args.status}")
    print(f"[record] 下次最早可跑：{(datetime.now() + timedelta(days=args.days)):%Y-%m-%d %H:%M}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="ASO 关键词周期引擎")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("gate", help="节流闸门：距上次周期不足 N 天则 rc=3")
    p.add_argument("--days", type=int, default=3)
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=cmd_gate)

    p = sub.add_parser("plan", help="挖词打分出新策略（可选派生变体）")
    p.add_argument("--baseline", default="A", help="实验对照基线（只记分，不被修改）")
    p.add_argument("--parent", default="",
                   help="派生父本（真正被改的那一版）。留空=自动取最新 treatment")
    p.add_argument("--cycle", default="")
    p.add_argument("--locales", default="")
    p.add_argument("--days", type=int, default=3, help="周期天数（仅记录）")
    p.add_argument("--emit-variant", default="", help="派生到这个变体名；auto=自动取下一个字母")
    p.add_argument("--no-emit", action="store_true")
    p.add_argument("--apply-rules", action="store_true",
                   help="（保留）规则是否启用由 rewrite_rules.json 的 enabled 决定")
    p.add_argument("--block-on-open-exp", dest="block_on_open_exp",
                   action="store_true", default=True)
    p.add_argument("--no-block-on-open-exp", dest="block_on_open_exp",
                   action="store_false")
    p.set_defaults(func=cmd_plan)

    p = sub.add_parser("lint-gate", help="增量文案闸门：只拦本轮新引入的红")
    p.add_argument("--variant", required=True)
    p.add_argument("--parent", default="")
    p.add_argument("--locales", default="")
    p.set_defaults(func=cmd_lint_gate)

    p = sub.add_parser("ledger", help="看历史轮次")
    p.add_argument("--tail", type=int, default=10)
    p.set_defaults(func=cmd_ledger)

    p = sub.add_parser("record", help="追加一轮到账本并更新时间戳")
    p.add_argument("--cycle", default="")
    p.add_argument("--variant", required=True)
    p.add_argument("--baseline", default="A")
    p.add_argument("--element", default="copy")
    p.add_argument("--status", default="designed")
    p.add_argument("--experiment", default="")
    p.add_argument("--hypothesis", default="")
    p.add_argument("--publish", default="none")
    p.add_argument("--note", default="")
    p.add_argument("--days", type=int, default=3)
    p.set_defaults(func=cmd_record)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
