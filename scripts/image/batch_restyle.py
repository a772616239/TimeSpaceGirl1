#!/usr/bin/env python3
"""批量换皮编排：一份清单跑完「N 个资源 × M 个主题」的
prepare → prompt → gen → postprocess → verify →（可选）preview →（可选）publish。

为什么要单独一个脚本，而不是在 Jenkins 里写 for 循环：
- ChatGPT web 出图是**单浏览器串行**资源，绝不能并行；批量必须排队，且一次失败不能带崩整批。
- 每个环节的日志要落到 run 目录，「哪张图在哪一步红的」事后必须能查。
- publish 是破坏性动作（原地覆盖资源）：本脚本只在 verify 硬项全绿时才允许写回，
  并沿用 restyle_pipeline 的备份台账（原图搬 ResBackpack/备份 + _manifest.jsonl）。

清单格式见 scripts/image/batch_example.json；生产打法见 docs/art_restyle_themes.md。

用法：
  python scripts/image/batch_restyle.py scripts/image/batch_example.json --dry-run
  python scripts/image/batch_restyle.py my.json --only chaozhilibao --keep-going
  python scripts/image/batch_restyle.py my.json --no-gen      # 用工作区已有的 inbox/gen_web.png
  python scripts/image/batch_restyle.py my.json --publish     # 验收过就写回
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
import traceback
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

import restyle_pipeline as rp  # noqa: E402  （只借它算 work_dir / 预设校验，执行一律走子进程）

PY = sys.executable
PIPE = HERE / "restyle_pipeline.py"
GEN = HERE / "gen_chatgpt_web.py"
PREVIEW = HERE / "preview_ingame.py"

RC_OK, RC_FAIL, RC_USAGE, RC_WARN = 0, 1, 2, 3
# 出图通道「额度/登录」类失败：整批立刻停，换账号比继续跑更有意义
GEN_FATAL = {3}
STEP_ORDER = ("prepare", "prompt", "gen", "postprocess", "verify", "preview", "publish")


def rel(p: Path) -> str:
    """日志里用的短路径：工程外的路径（--work /tmp/...）原样返回，别让 relative_to 抛异常。"""
    try:
        return str(Path(p).relative_to(ROOT))
    except ValueError:
        return str(p)


# ----------------------------------------------------------------------------- 清单
def _deep_merge(a: dict, b: dict) -> dict:
    out = dict(a)
    for k, v in (b or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = _deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def load_manifest(path: Path) -> dict:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise SystemExit(f"🔴 清单不是合法 JSON：{path}\n   {e}")
    defaults = raw.get("defaults") or {}
    if "themes" not in defaults and not raw.get("items"):
        raise SystemExit("🔴 清单缺 defaults.themes 或 items")
    return raw


def resolve_item(defaults: dict, item: dict) -> dict:
    """item 覆盖 defaults（dict 深合并），并补齐 theme 列表。"""
    cfg = _deep_merge(defaults, item)
    themes = cfg.get("themes") or ([cfg["theme"]] if cfg.get("theme") else [])
    if not themes:
        raise SystemExit("🔴 某个 item 没给 themes/theme")
    cfg["themes"] = themes
    return cfg


def expand_item(defaults: dict, item: dict) -> tuple[list[dict], list[str]]:
    """把 item 展开成「一个资产一条 cfg」。

    支持 glob：`"assets": [".../cn2-X1_chongzhi_banner_*.png"]`。
    这不是锦上添花 —— 同一套 UI 有 zh/en/jp 三份，只换一份会变成「中文圣诞、英文原样」的花脸。
    """
    pats = ([item["asset"]] if item.get("asset") else []) + list(item.get("assets") or [])
    base = {k: v for k, v in item.items() if k not in ("asset", "assets")}
    cfg0 = resolve_item(defaults, base)
    files: list[Path] = []
    unmatched: list[str] = []
    seen: set[Path] = set()
    for pat in pats:
        hits: list[Path] = []
        if any(ch in pat for ch in "*?["):
            p = Path(pat)
            hits = sorted((Path("/").glob(pat.lstrip("/")) if p.is_absolute() else ROOT.glob(pat)))
            hits = [h for h in hits if h.suffix.lower() == ".png"]
            if not hits:
                unmatched.append(pat)
        else:
            hits = [Path(pat) if Path(pat).is_absolute() else ROOT / pat]
        for h in hits:
            if h in seen:
                continue
            seen.add(h)
            files.append(h)
    cfgs = []
    for f in files:
        cfg = dict(cfg0)
        cfg["asset"] = str(f.relative_to(ROOT)) if (f.is_absolute() and ROOT in f.parents) else str(f)
        cfgs.append(cfg)
    return cfgs, unmatched


def validate(items: list[tuple[dict, str]], presets: dict) -> list[str]:
    """出图前的静态检查：资产在不在、主题认不认识、layout 在不在。

    这里宁可早退也不能边跑边发现 —— 一次 gen 就是一份额度。
    """
    errs = []
    known = set((presets.get("themes") or {}).keys())
    for cfg, theme in items:
        asset = Path(cfg["asset"])
        full = asset if asset.is_absolute() else (ROOT / asset)
        if not full.is_file():
            errs.append(f"资产不存在：{cfg['asset']}")
        if theme not in known:
            errs.append(f"未知主题 {theme!r}（{cfg['asset']}）可选：{', '.join(sorted(known))}")
        lay = cfg.get("layout")
        if lay:
            lp = Path(lay)
            lp = lp if lp.is_absolute() else (ROOT / lp)
            if not lp.is_file():
                errs.append(f"layout 文件不存在：{lay}（{cfg['asset']} / {theme}）")
        if cfg.get("provider") == "manual" and not cfg.get("gen_image"):
            errs.append(f"provider=manual 但没给 gen_image（{cfg['asset']} / {theme}）")
    return errs


# ----------------------------------------------------------------------------- 步骤
def step_prepare(cfg: dict, theme: str, work: Path) -> list[str]:
    cmd = [PY, str(PIPE), "prepare", "--asset", cfg["asset"], "--theme", theme, "--work", str(work)]
    if cfg.get("layout"):
        cmd += ["--layout", cfg["layout"]]
    cmd += ["--composition", cfg.get("composition") or "lock"]
    if cfg.get("pose"):
        cmd += ["--pose", str(cfg["pose"])]
    return cmd


def step_prompt(cfg: dict, theme: str) -> list[str]:
    cmd = [PY, str(PIPE), "prompt", "--theme", theme,
           "--composition", cfg.get("composition") or "lock"]
    # 必须把资源一起传下去：prompt 要按源图长宽比挑生成画布。
    # 漏传 = 横版 banner 被要求画成 1024x1536 竖图，postprocess cover 之后只剩一块局部。
    if cfg.get("asset"):
        cmd += ["--asset", cfg["asset"]]
    if cfg.get("layout"):
        cmd += ["--layout", cfg["layout"]]
    if cfg.get("pose"):
        cmd += ["--pose", str(cfg["pose"])]
    return cmd


def step_gen(cfg: dict, work: Path) -> list[str] | None:
    provider = (cfg.get("provider") or "chatgpt_web").lower()
    if provider in ("skip", "none", "manual"):
        return None
    if provider != "chatgpt_web":
        raise SystemExit(f"🔴 不认识的 provider：{provider}（chatgpt_web / manual / skip）")
    g = cfg.get("gen") or {}
    cmd = [PY, str(GEN),
           "--image", str(work / "src" / "source.png"),
           "--prompt-file", str(work / "prompt.txt"),
           "--out", str(work / "inbox" / "gen_web.png")]
    if g.get("reuse_cdp", True):
        cmd.append("--reuse-cdp")
    if g.get("headless"):
        # 后台画：自建 Chrome 加 --headless=new（需把 reuse_cdp 设 false，否则连的是别人开的窗口）
        # ⚠ 2026-10-24 实测被 Cloudflare 拦在「请稍候…」，出不了图；要后台请用 background
        cmd.append("--headless")
    if g.get("background"):
        cmd.append("--background")
    if g.get("port"):
        cmd += ["--port", str(g["port"])]
    if g.get("timeout"):
        cmd += ["--timeout", str(g["timeout"])]
    if g.get("attempts"):
        cmd += ["--attempts", str(g["attempts"])]
    if g.get("crop_height"):
        cmd += ["--crop-height", str(g["crop_height"])]
    if g.get("grab_existing"):
        cmd.append("--grab-existing")
    if g.get("profile"):
        cmd += ["--profile", str(g["profile"])]
    if g.get("proxy"):
        cmd += ["--proxy", str(g["proxy"])]
    return cmd


def step_postprocess(cfg: dict, work: Path) -> list[str]:
    pp = cfg.get("postprocess") or {}
    cmd = [PY, str(PIPE), "postprocess", "--work", str(work),
           "--gen", str(work / "inbox" / "gen_web.png")]
    for flag, key in (("--watermark", "watermark"), ("--alpha-mode", "alpha_mode"),
                      ("--frame", "frame"), ("--frame-rim", "frame_rim"),
                      ("--bottom-fade-rim", "bottom_fade_rim"),
                      ("--body-mode", "body_mode")):
        if pp.get(key):
            cmd += [flag, str(pp[key])]
    for flag, key in (("--hero-band", "hero_band"), ("--blend", "blend"),
                      ("--feather-top", "feather_top"), ("--bottom-fade", "bottom_fade")):
        if pp.get(key):
            cmd += [flag, str(pp[key])]
    return cmd


def pick_variant(cfg: dict, work: Path) -> str:
    """源是 RGB 就写 opaque，RGBA 才写 alpha —— 别把资源模式改了（导入/压缩口径会变）。"""
    want = (cfg.get("variant") or "auto").lower()
    if want in ("alpha", "opaque"):
        return want
    # work/src/source.png 是 prepare 的快照；dry-run 或还没 prepare 时退回看资源本体
    cands = [work / "src" / "source.png"]
    a = Path(cfg["asset"])
    cands.append(a if a.is_absolute() else (ROOT / a))
    for p in cands:
        try:
            from PIL import Image
            mode = Image.open(p).mode
        except Exception:
            continue
        return "opaque" if mode == "RGB" else "alpha"
    return "alpha"


def already_done(full: Path, work: Path, theme: str, args) -> str | None:
    """这一组是不是「已经按当前口径交付过」？返回说明 = 该跳过，None = 照常跑。

    判据**只有**两条：① `state.json` 有 published 记录且写回后的哈希 == 资源现在的哈希
    （写完没人再动过）；② 命令行没给 `--force`。

    🔴 口径版本（`edge_ver`）**只记进说明、不作为「该重做」的理由**：老记录里根本没有这一列，
    拿「版本不同」当重做条件等于第一次跑就把所有历史资源全重画一遍 —— 那正是用户抱怨的
    「以前已经改过了为啥还改」。要按新口径重做就 `--force` 或 `--only` 点名，别默认烧额度。
    """
    if getattr(args, "force", False):
        return None
    st_path = work / "state.json"
    if not st_path.is_file():
        return None
    try:
        st = json.loads(st_path.read_text(encoding="utf-8"))
    except Exception:                                        # noqa: BLE001
        return None
    pub = st.get("published") or {}
    if not pub.get("after_sha256") or not full.is_file():
        return None
    if pub["after_sha256"] != rp.sha256(full):
        return None                                          # 写回后又被人改过 ⇒ 该重做
    cur = getattr(rp.edge_polish, "EDGE_VER", None)
    ver = st.get("edge_ver") or "（记账时还没有这一列）"
    extra = "" if ver == cur else f"，按 {ver} 交付而当前口径是 {cur}（要按新口径重做加 --force）"
    return (f"已交付过且资源未再改动（{pub.get('at', '?')} 写回）→ 跳过{extra}")


def step_publish(cfg: dict, work: Path, note: str) -> list[str]:
    return [PY, str(PIPE), "publish", "--work", str(work),
            "--variant", pick_variant(cfg, work), "--yes", "--note", note]


# ----------------------------------------------------------------------------- 执行
class Run:
    def __init__(self, manifest_path: Path, args) -> None:
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.dir = rp.WORK_ROOT / "_batch" / stamp
        (self.dir / "logs").mkdir(parents=True, exist_ok=True)
        self.args = args
        self.manifest_path = manifest_path
        self.rows: list[dict] = []
        self.t0 = time.time()
        self.logf = (self.dir / "batch.log").open("a", encoding="utf-8")

    def log(self, msg: str) -> None:
        line = f"[{datetime.now():%H:%M:%S}] {msg}"
        print(line, flush=True)
        self.logf.write(line + "\n")
        self.logf.flush()

    def run_step(self, tag: str, name: str, cmd: list[str], capture_stdout: Path | None = None,
                 allow: tuple[int, ...] = (RC_OK,)) -> int:
        logpath = self.dir / "logs" / f"{tag}.{name}.log"
        self.log(f"    → {name}: {' '.join(cmd[2:])}")
        with logpath.open("w", encoding="utf-8") as lf:
            lf.write(f"$ {' '.join(cmd)}\n\n")
            lf.flush()
            proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
            lf.write(proc.stdout or "")
            if proc.stderr:
                lf.write("\n--- stderr ---\n" + proc.stderr)
        if capture_stdout is not None and proc.stdout:
            capture_stdout.write_text(proc.stdout, encoding="utf-8")
        rc = proc.returncode
        if rc not in allow:
            tail = (proc.stdout or "").strip().splitlines()[-6:]
            self.log(f"    ✗ {name} rc={rc}（日志 {rel(logpath)}）")
            for line in tail:
                self.log(f"      | {line}")
        return rc


def execute(run: Run, cfg: dict, theme: str, presets: dict) -> dict:
    asset = Path(cfg["asset"])
    full = asset if asset.is_absolute() else (ROOT / asset)
    work = rp.work_dir(full, theme, cfg.get("work"))
    tag = f"{rp.slug_of(full)}__{theme}"
    row = {"asset": cfg["asset"], "theme": theme, "work": str(work),
           "steps": {}, "status": "ok", "variant": None, "note": ""}
    run.log(f"  ▸ {asset.name} × {theme}")
    run.log(f"    工作目录 {rel(work)}")

    # 0) 已经按当前口径交付过的组合默认跳过 —— 见 already_done() 的说明。
    #    🔴 放在 prepare 之前：prepare 会重写 state/src 快照，跑完就分不清「原来什么样」了。
    _skip = already_done(full, work, theme, run.args)
    if _skip:
        row["steps"]["prepare"] = "skipped"
        row["status"] = "skipped"
        row["note"] = _skip
        run.log(f"    ⏭ {_skip}")
        return row

    def fail(step: str, why: str, status: str = "failed") -> dict:
        row["steps"][step] = status
        row["status"] = status
        row["note"] = why
        run.log(f"    🔴 {why}")
        return row

    # 1) prepare
    rc = run.run_step(tag, "prepare", step_prepare(cfg, theme, work))
    row["steps"]["prepare"] = "ok" if rc == RC_OK else "failed"
    if rc != RC_OK:
        return fail("prepare", "prepare 失败（源资源/参数问题，先看日志）")

    # 2) prompt（落成文件，出图与复查都用它）
    rc = run.run_step(tag, "prompt", step_prompt(cfg, theme),
                      capture_stdout=work / "prompt.txt")
    row["steps"]["prompt"] = "ok" if rc == RC_OK else "failed"
    if rc != RC_OK:
        return fail("prompt", "prompt 生成失败")

    # 3) gen
    gcmd = step_gen(cfg, work)
    if run.args.no_gen or gcmd is None:
        gen_png = work / "inbox" / "gen_web.png"
        if not gen_png.is_file():
            return fail("gen", "跳过了出图，但工作区没有 inbox/gen_web.png")
        run.log(f"    - gen 跳过，复用 {rel(gen_png)}")
        row["steps"]["gen"] = "reused"
    else:
        rc = run.run_step(tag, "gen", gcmd)
        row["steps"]["gen"] = "ok" if rc == RC_OK else "failed"
        if rc in GEN_FATAL:
            row["exhausted"] = True
            # rc=3 有三个来源：额度用尽 / 登录态失效 / **节奏闸门说「现在不该画」**。
            # 前两个要换号，第三个只是要等（或今天就到这）—— 别让人一律去换号。
            note = ("出图通道不可用 —— 看 gen 日志：额度/登录态问题就换号；"
                    "若是「节奏闸门」则是按账号限速到顶了，等窗口或明天再来"
                    "（scripts/image/gen_pace.py status 看下次可画时间）")
            return fail("gen", note, status="blocked")
        if rc != RC_OK:
            return fail("gen", "出图失败（看 gen 日志；若图其实已生成用 --no-gen 或 gen.grab_existing）")

    # 4) postprocess
    rc = run.run_step(tag, "postprocess", step_postprocess(cfg, work))
    row["steps"]["postprocess"] = "ok" if rc == RC_OK else "failed"
    if rc != RC_OK:
        return fail("postprocess", "后处理失败")

    # 5) verify（publish 的硬闸门）
    rc = run.run_step(tag, "verify", [PY, str(PIPE), "verify", "--work", str(work)],
                      allow=(RC_OK, RC_WARN))
    row["steps"]["verify"] = "ok" if rc == RC_OK else ("warn" if rc == RC_WARN else "failed")
    verified = rc in (RC_OK, RC_WARN)
    if rc == RC_FAIL:
        row["status"] = "verify-failed"
        row["note"] = "验收有硬失败（尺寸/alpha/水印），不写回"
        run.log("    🔴 验收硬失败，跳过写回")
    elif rc == RC_WARN:
        run.log("    ⚠ 验收有警告（可写回，但建议人眼看一眼）")

    # 6) preview
    if cfg.get("preview", True):
        try:
            state = json.loads((work / "state.json").read_text(encoding="utf-8"))
            outs = state.get("outputs") or {}
            img = Path(outs.get("alpha") or outs.get("opaque") or "")
            if img.is_file():
                run.run_step(tag, "preview",
                             [PY, str(PREVIEW), str(img), "--out", str(work / "out" / "preview_ingame_567px.jpg")])
                row["steps"]["preview"] = "ok"
        except Exception as e:  # 预览只是方便看，失败不影响交付
            row["steps"]["preview"] = f"skipped({type(e).__name__})"

    # 7) publish
    want_publish = bool(cfg.get("publish"))
    if run.args.publish:
        want_publish = True
    if run.args.no_publish:
        want_publish = False
    if not want_publish:
        row["steps"]["publish"] = "off"
        run.log("    - 不写回（清单 publish=false 或没给 --publish）")
        return row
    if not verified:
        row["steps"]["publish"] = "blocked"
        return row

    variant = pick_variant(cfg, work)
    row["variant"] = variant
    note = cfg.get("publish_note") or f"batch {run.dir.name} {theme}"
    rc = run.run_step(tag, "publish", step_publish(cfg, work, note))
    row["steps"]["publish"] = "ok" if rc == RC_OK else "failed"
    if rc == RC_OK:
        run.log(f"    ✅ 已写回（{variant}），原图已进 ResBackpack/备份")
    else:
        row["status"] = "publish-failed"
        row["note"] = "写回失败（看日志；资源未被改动或被自动中止）"
    return row


# ----------------------------------------------------------------------------- 汇总
def write_summary(run: Run, items: list[tuple[dict, str]]) -> None:
    dur = time.time() - run.t0
    ok = [r for r in run.rows if r["status"] == "ok"]
    bad = [r for r in run.rows if r["status"] != "ok"]
    done = [r for r in run.rows if r["steps"].get("publish") == "ok"]

    lines = [
        "# 批量换皮结果",
        "",
        f"- 清单：`{run.manifest_path}`",
        f"- 开始：{datetime.fromtimestamp(run.t0):%Y-%m-%d %H:%M:%S}　耗时：{dur / 60:.1f} min",
        f"- 计划 {len(items)} 组（资源×主题），成功 {len(ok)}，有问题 {len(bad)}，写回 {len(done)}",
        "",
        "| 资源 | 主题 | prepare | prompt | gen | post | verify | preview | publish | 备注 |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in run.rows:
        st = r["steps"]
        cells = [st.get(k, "-") for k in ("prepare", "prompt", "gen", "postprocess",
                                          "verify", "preview", "publish")]
        mark = {"ok": "✅", "warn": "⚠", "reused": "♻", "off": "·", "blocked": "⛔"}
        cells = [mark.get(c, c) for c in cells]
        lines.append("| `{}` | {} | {} | {} |".format(
            Path(r["asset"]).name, r["theme"], " | ".join(cells), r["note"] or ""))
    if bad:
        lines += ["", "## 需要处理", ""]
        for r in bad:
            lines.append(f"- `{Path(r['asset']).name}` × {r['theme']}：{r['status']} —— {r['note']}")
    lines += ["", "## 下一步", "",
              "1. 写回过的资源要在 Unity 里重打 AssetBundle（`FrameTool.BuildGameAssetBundles`）才进包。",
              "2. 回滚单张：`python scripts/image/restyle_pipeline.py restore --asset <path>`（`--list` 先看版本）。",
              "3. 逐组日志在 `logs/<slug>__<theme>.<step>.log`。"]
    (run.dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (run.dir / "summary.json").write_text(
        json.dumps({"manifest": str(run.manifest_path), "dir": str(run.dir),
                    "duration_sec": round(dur, 1), "rows": run.rows}, ensure_ascii=False, indent=2),
        encoding="utf-8")
    print(f"\n汇总 → {rel(run.dir)}/summary.md")


# ----------------------------------------------------------------------------- CLI
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="批量换皮编排（资源 × 主题）")
    ap.add_argument("manifest", help="清单 JSON（结构见 scripts/image/batch_example.json）")
    ap.add_argument("--only", default=None,
                    help="只跑资产名或主题名包含该子串的组合（可逗号分隔多个）")
    ap.add_argument("--dry-run", action="store_true", help="只打印将要执行的命令，不出图不改文件")
    ap.add_argument("--no-gen", action="store_true", help="跳过出图，复用工作区已有 inbox/gen_web.png")
    ap.add_argument("--no-preview", action="store_true", help="不生成 567px 真机预览")
    ap.add_argument("--publish", action="store_true", help="强制写回（仍需 verify 未硬失败）")
    ap.add_argument("--no-publish", action="store_true", help="强制不写回（覆盖清单里的 publish=true）")
    ap.add_argument("--force", action="store_true",
                    help="已交付过（资源哈希未变 + 口径未变）的组合也重做。默认跳过它们："
                         "不做这一步的话，重跑清单会把所有已交付资源再出一次图再覆盖一次")
    ap.add_argument("--keep-going", action="store_true", default=True, help="单组失败继续跑下一组（默认）")
    ap.add_argument("--fail-fast", dest="keep_going", action="store_false", help="任一组失败立即停")
    args = ap.parse_args(argv)

    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        cand = [Path.cwd() / manifest_path, ROOT / manifest_path]
        manifest_path = next((p for p in cand if p.is_file()), cand[-1])
    if not manifest_path.is_file():
        print(f"🔴 找不到清单：{args.manifest}")
        return RC_USAGE

    presets = rp.load_presets()
    if rp.lint_presets(presets) != RC_OK:
        print("🔴 预设自检没过，先修 theme_presets.json（出图阶段才发现会很贵）")
        return RC_USAGE

    raw = load_manifest(manifest_path)
    defaults = raw.get("defaults") or {}
    items: list[tuple[dict, str]] = []
    unmatched_all: list[str] = []
    for it in raw.get("items") or []:
        if not it.get("asset") and not it.get("assets"):
            print("🔴 有 item 缺 asset / assets")
            return RC_USAGE
        cfgs, unmatched = expand_item(defaults, it)
        unmatched_all += unmatched
        for cfg in cfgs:
            for theme in cfg["themes"]:
                items.append((cfg, theme))
    if unmatched_all:
        print("🔴 这些 glob 没匹配到任何 png（路径写错？）：")
        for u in unmatched_all:
            print("   -", u)
        return RC_USAGE
    if not items:
        print("🔴 清单里没有可跑的 item")
        return RC_USAGE

    if args.only:
        keys = [s.strip().lower() for s in args.only.split(",") if s.strip()]
        items = [x for x in items
                 if any(k in (Path(x[0]["asset"]).name + " " + x[1]).lower() for k in keys)]
        if not items:
            print(f"🔴 --only {args.only} 没匹配到任何组合")
            return RC_USAGE

    errs = validate(items, presets)
    if errs:
        print("🔴 清单校验没过：")
        for e in errs:
            print("   -", e)
        return RC_USAGE

    if args.dry_run:
        print(f"清单 {manifest_path.name}：{len(items)} 组（资源×主题）")
        for cfg, theme in items:
            work = rp.work_dir(Path(cfg["asset"]), theme, cfg.get("work"))
            will_publish = bool(cfg.get("publish")) or args.publish
            if args.no_publish:
                will_publish = False
            print(f"\n▸ {cfg['asset']} × {theme}")
            print("  " + " ".join(step_prepare(cfg, theme, work)))
            print("  " + " ".join(step_prompt(cfg, theme)) + f" > {work / 'prompt.txt'}")
            g = step_gen(cfg, work)
            print("  " + (" ".join(g) if g else f"（gen 跳过：provider={cfg.get('provider')}）"))
            print("  " + " ".join(step_postprocess(cfg, work)))
            print("  " + " ".join([PY, str(PIPE), "verify", "--work", str(work)]))
            if will_publish:
                print("  " + " ".join(step_publish(cfg, work, "<note>"))
                      + f"  # variant={pick_variant(cfg, work)}；verify 硬失败会自动拦下")
            else:
                print("  （不写回：publish=false 且没给 --publish）")
        print(f"\n共 {len(items)} 组；每组一次出图 = 一份额度。确认无误后去掉 --dry-run。")
        return RC_OK

    run = Run(manifest_path, args)
    run.log(f"清单 {manifest_path.name}：{len(items)} 组；日志 {rel(run.dir)}")
    rc_final = RC_OK
    for i, (cfg, theme) in enumerate(items, 1):
        run.log(f"[{i}/{len(items)}] {Path(cfg['asset']).name} × {theme}")
        try:
            row = execute(run, cfg, theme, presets)
        except SystemExit as e:
            print(f"🔴 {e}")
            return RC_USAGE
        except Exception:
            row = {"asset": cfg["asset"], "theme": theme, "steps": {}, "status": "exception",
                   "note": traceback.format_exc(limit=2).strip().splitlines()[-1]}
            run.log("    🔴 未捕获异常，已记录并继续")
        run.rows.append(row)
        if row["status"] not in ("ok",):
            rc_final = RC_FAIL
        if row.get("exhausted"):
            run.log("🔴 出图通道停了 —— 整批停止。若是额度/登录态：换 AdsPower 里另一个 profile，"
                    "反查端口后重跑剩下的（--only 或清单里删掉已完成的）；"
                    "若是节奏闸门（按账号限速到顶）：等窗口，或 gen_pace.py status 看下次可画时间")
            break
        if row["status"] != "ok" and not args.keep_going:
            run.log("⛔ --fail-fast：停在第一组失败处")
            break

    write_summary(run, items)
    done = sum(1 for r in run.rows if r["status"] == "ok")
    print(f"完成 {done}/{len(items)} 组（失败 {len(run.rows) - done}）"
          f"{'；有写回，记得重打 AssetBundle' if any(r['steps'].get('publish') == 'ok' for r in run.rows) else ''}")
    return rc_final


if __name__ == "__main__":
    sys.exit(main())
