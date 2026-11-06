#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Play 数据记分卡：把「商店页访问 / 安装 / 转化率 / 活跃」按窗口拉出来，顺带测搜索可见性。

为什么要有它
------------
`TS-ASO-Cycle` 只记关键词账本、`TS-Play-Watch` 只查轨道与 16KB 合规，
**没有任何东西在量「改版之后到底好不好」**。2026-11-06 复盘发现：
改名把访问量砍半这件事，靠人工翻 CSV 才看出来，而且当时已经错过 10 天。

口径（务必按这个读）
--------------------
- 数据源：Play 批量报告桶 `pubsite_prod_…`，CSV 是 UTF-16，**滞后 5~6 天**。
- `Store listing visitors` = 商店页访问人数；`acquisitions` = 商店页带来的安装；
  转化率 = acquisitions / visitors（**比值不受绝对量影响，小样本下唯一可读的指标**）。
- 维度（国家 / 来源 / 搜索词）在这个体量下会被隐私阈值全部聚合成 `Other`，别指望它做归因。
- 🔴 httplib2 不吃 `http_proxy` 环境变量，`google_auth_httplib2` 走直连必超时
  ⇒ 这里用 requests.Session + google.auth.transport.requests.Request(session=…)。

用法
----
    aso_scorecard.py                      # 最近 30 天 + 搜索可见性
    aso_scorecard.py --days 60 --json     # 出 JSON（给 Jenkins 存档）
    aso_scorecard.py --no-search          # 只看报表，不抓搜索页
    PLAY_PROXY=http://127.0.0.1:7890 …    # 代理默认就是这个
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import urllib.parse
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402

BUCKET = "pubsite_prod_5257525457215457095"
CACHE = Path("/tmp") / "aso_scorecard"
PROXY = __import__("os").environ.get("PLAY_PROXY", "http://127.0.0.1:7890")

# 登录态搜索页要按语言面测：品牌词（必须命中）+ 品类词（必须知道命中不命中）
TERMS = [
    ("zh-CN", "HK", ["群星列阵", "群星", "放置", "放置卡牌", "二次元放置", "美少女", "少女"]),
    ("zh-TW", "TW", ["群星列陣", "群星列阵", "放置", "放置掛機", "美少女"]),
    ("ja-JP", "JP", ["群星の陣", "放置", "放置カードRPG", "美少女", "美少女ゲーム"]),
    ("en-US", "US", ["Starhost", "idle card rpg", "afk idle", "anime idle rpg", "gacha"]),
]


def _session():
    import requests
    s = requests.Session()
    if PROXY:
        s.proxies = {"http": PROXY, "https": PROXY}
    s.trust_env = False
    return s


def _token(sess):
    from google.auth.transport.requests import Request
    from google.oauth2 import service_account
    sa = C.ROOT / ".secrets" / "service-account.json"
    if not sa.is_file():
        raise SystemExit(f"缺服务账号密钥：{sa}")
    creds = service_account.Credentials.from_service_account_file(
        str(sa), scopes=["https://www.googleapis.com/auth/devstorage.read_only"])
    creds.refresh(Request(session=sess))
    return creds.token


def fetch(sess, tok, name: str) -> bytes:
    CACHE.mkdir(parents=True, exist_ok=True)
    p = CACHE / name.replace("/", "__")
    if p.is_file() and p.stat().st_size:
        return p.read_bytes()
    url = ("https://storage.googleapis.com/storage/v1/b/{}/o/{}?alt=media"
           .format(BUCKET, urllib.parse.quote(name, safe="")))
    r = sess.get(url, headers={"Authorization": f"Bearer {tok}"}, timeout=120)
    if r.status_code != 200:
        return b""
    p.write_bytes(r.content)
    return r.content


def rows(sess, tok, name: str):
    raw = fetch(sess, tok, name)
    if not raw:
        return []
    for enc in ("utf-16", "utf-8-sig", "utf-8"):
        try:
            import csv
            import io
            text = raw.decode(enc)
            if "Date" in text.split("\n")[0]:
                return list(csv.DictReader(io.StringIO(text)))
        except Exception:  # noqa: BLE001
            continue
    return []


def months_back(days: int):
    today = date.today()
    start = today - timedelta(days=days)
    out, cur = [], date(start.year, start.month, 1)
    while cur <= today:
        out.append(cur.strftime("%Y%m"))
        cur = date(cur.year + (cur.month == 12), cur.month % 12 + 1, 1)
    return out


def load_series(sess, tok, days: int):
    perf, inst = {}, {}
    for m in months_back(days):
        for r in rows(sess, tok,
                      f"stats/store_performance/store_performance_{C.PACKAGE}_{m}_country.csv"):
            perf[r["Date"]] = (int(r["Store listing visitors"] or 0),
                               int(r["Store listing acquisitions"] or 0))
        for r in rows(sess, tok, f"stats/installs/installs_{C.PACKAGE}_{m}_overview.csv"):
            inst[r["Date"]] = (int(r["Daily Device Installs"] or 0),
                               int(r["Active Device Installs"] or 0))
    return perf, inst


def window(perf, start: str, end: str):
    v = a = 0
    n = 0
    for d, (vv, aa) in perf.items():
        if start <= d <= end:
            v += vv
            a += aa
            n += 1
    return n, v, a, (a / v if v else 0.0)


def poisson_z(obs: int, rate: float, days: int):
    exp = rate * days
    return (obs - exp) / math.sqrt(exp) if exp else 0.0


def search_matrix():
    import re
    sess = _session()
    ua = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")
    out = []
    for hl, gl, terms in TERMS:
        for t in terms:
            url = ("https://play.google.com/store/search?q=" + urllib.parse.quote(t)
                   + f"&c=apps&hl={hl.replace('-', '_')}&gl={gl}")
            try:
                body = sess.get(url, headers={"User-Agent": ua}, timeout=40).text
            except Exception as e:  # noqa: BLE001
                out.append((hl, gl, t, None, f"抓取失败 {e}"))
                continue
            ids, seen = [], set()
            for i in re.findall(r"details\?id=([A-Za-z0-9_.]+)", body):
                if i not in seen:
                    seen.add(i)
                    ids.append(i)
            pos = ids.index(C.PACKAGE) + 1 if C.PACKAGE in ids else None
            out.append((hl, gl, t, pos, f"{len(ids)} 条"))
    return out


def token_strength(terms=None, locales=(("zh-TW", "TW"), ("zh-CN", "HK"))):
    """词元强度探针：某词前 10 条结果里，有多少条的**标题自带这个词**。

    为什么需要这个指标（2026-11-06 实测建立）：
      Play 没有公开搜索量 API（老联想接口 `market.android.com/suggest/SuggRequest` 已 404），
      也没有关键词难度可读。但搜索结果结构本身带信号：
        - 含词比例高 ⇒ 这个词是开发者公认要卡位的 token，也说明搜索真的按它匹配
        - 含词 0/10    ⇒ 这个词不被当作查询单元（Play 认词元、不认短语）
      实测样本：`少女` 8/10、`放置` 6/10、`二次元` 2/10、`美少女` 1/10、`放置卡牌` 0/10。

    用法：`aso_scorecard.py --tokens 少女 美少女 二次元 放置卡牌`
    """
    import re
    sess = _session()
    ua = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")
    card = re.compile(r'details\?id=([A-Za-z0-9_.]+)(.*?)(?=details\?id=|\Z)', re.S)
    name = re.compile(r'<span class="DdYX5">(.*?)</span>', re.S)
    out = []
    for hl, gl in locales:
        for t in terms:
            url = ("https://play.google.com/store/search?q=" + urllib.parse.quote(t)
                   + f"&c=apps&hl={hl.replace('-', '_')}&gl={gl}")
            try:
                body = sess.get(url, headers={"User-Agent": ua}, timeout=40).text
            except Exception as e:  # noqa: BLE001
                out.append({"locale": hl, "term": t, "error": str(e)})
                continue
            names, seen = [], set()
            for pkg, chunk in card.findall(body):
                if pkg in seen:
                    continue
                seen.add(pkg)
                m = name.search(chunk)
                if m:
                    names.append(re.sub(r"<[^>]+>", "", m.group(1)).strip())
                if len(names) >= 10:
                    break
            hit = sum(1 for n in names if t in n)
            out.append({"locale": hl, "term": t, "n": len(seen),
                        "top": len(names), "hit": hit, "names": names})
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--no-search", action="store_true")
    ap.add_argument("--tokens", nargs="*", metavar="TERM",
                    help="只跑词元强度探针（不读报表）：给若干候选词，看前10条标题自带该词的条数")
    args = ap.parse_args()

    if args.tokens is not None:
        terms = args.tokens or ["少女", "美少女", "二次元", "放置", "放置卡牌", "卡牌RPG"]
        res = token_strength(terms)
        if args.json:
            print(json.dumps(res, ensure_ascii=False, indent=2))
            return
        print(f"{'词':<10}{'语言面':<9}{'结果':>4}{'前10含词':>9}  头部三条")
        for r in res:
            if r.get("error"):
                print(f"{r['term']:<10}{r['locale']:<9}  抓取失败 {r['error']}")
                continue
            print(f"{r['term']:<10}{r['locale']:<9}{r['n']:>4}"
                  f"{str(r['hit']) + '/' + str(r['top']):>9}  "
                  + " / ".join(n[:14] for n in r["names"][:3]))
        print("\n读法：含词比例高 = 真 token（值得进标题）；0/N = 该词不被当作查询单元，"
              "Play 认词元不认短语。")
        return

    sess = _session()
    tok = _token(sess)
    perf, inst = load_series(sess, tok, args.days + 40)
    if not perf:
        raise SystemExit("没拿到 store_performance 报表（检查代理 / 权限 / 报表是否已生成）")

    days = sorted(perf)[-args.days:]
    last = days[-1]
    start = days[0]
    n, v, a, cr = window(perf, start, last)
    # 最近 7 天与其前 7 天（同比窗口，改版前后各一段）
    d7 = (date.fromisoformat(last) - timedelta(days=6)).isoformat()
    d14 = (date.fromisoformat(last) - timedelta(days=13)).isoformat()
    d8 = (date.fromisoformat(last) - timedelta(days=7)).isoformat()
    n7, v7, a7, cr7 = window(perf, d7, last)
    n7p, v7p, a7p, cr7p = window(perf, d14, d8)

    report = {
        "generated": datetime.now().isoformat(timespec="seconds"),
        "package": C.PACKAGE,
        "data_last_day": last,
        "lag_days": (date.today() - date.fromisoformat(last)).days,
        "window": {"from": start, "to": last, "days": n,
                   "visitors": v, "acquisitions": a, "cr": round(cr, 4)},
        "last7": {"from": d7, "to": last, "days": n7,
                  "visitors": v7, "acquisitions": a7, "cr": round(cr7, 4)},
        "prev7": {"from": d14, "to": d8, "days": n7p,
                  "visitors": v7p, "acquisitions": a7p, "cr": round(cr7p, 4)},
        "wow": {
            "visitors_delta": v7 - v7p,
            "visitors_pct": round((v7 - v7p) / v7p, 3) if v7p else None,
            "visitors_z": round(poisson_z(v7, v7p / max(n7p, 1), n7), 2) if v7p else None,
            "cr_delta_pp": round((cr7 - cr7p) * 100, 2),
        },
        "daily": {d: {"visitors": perf[d][0], "acq": perf[d][1]} for d in days},
        "installs": {d: {"new": inst[d][0], "active": inst[d][1]}
                     for d in sorted(inst)[-args.days:] if d in inst},
    }
    if not args.no_search:
        report["search"] = [
            {"hl": hl, "gl": gl, "term": t,
             "rank": pos, "note": note} for hl, gl, t, pos, note in search_matrix()
        ]

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return

    print(f"# ASO 记分卡 · {report['generated']}")
    print(f"包：{C.PACKAGE}   报表末日：{last}（滞后 {report['lag_days']} 天）\n")
    print("| 窗口 | 天数 | 访问 | 安装 | 转化率 |")
    print("|---|---|---|---|---|")
    for label, w in (("最近 7 天", report["last7"]), ("前 7 天", report["prev7"]),
                     (f"最近 {n} 天", report["window"])):
        print(f"| {label} | {w['days']} | {w['visitors']} | {w['acquisitions']} | {w['cr']:.1%} |")
    w = report["wow"]
    print(f"\n周环比：访问 {w['visitors_delta']:+d}（{w['visitors_pct']}）"
          f"  泊松 z={w['visitors_z']}  CR {w['cr_delta_pp']:+} 个百分点")
    if abs(w["visitors_z"] or 0) < 2:
        print("⚠ z 绝对值 < 2 ⇒ 这个量级下算噪声，别当结论。")

    if not args.no_search and report.get("search"):
        print("\n## 搜索可见性（本包名次，None=前 N 条里没有）")
        cur = None
        for row in report["search"]:
            key = f"{row['hl']}/{row['gl']}"
            if key != cur:
                print(f"\n{key}")
                cur = key
            print(f"  {row['term']:<16} {row['rank'] if row['rank'] else '未出现':<6} ({row['note']})")


if __name__ == "__main__":
    main()
