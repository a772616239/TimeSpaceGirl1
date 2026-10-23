#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Play 商店页文案与素材的读写。

    aso_play.py list                    # 只读：导出线上四语 listing + 图片清单（默认）
    aso_play.py push --variant B --text-only --allow-write --yes
    aso_play.py push --variant B --with-images --allow-write --yes
    aso_play.py images --variant B --locale en-US      # 只传图片

三道闸门
--------
1. `--allow-write`  没它一律只打印 diff，不 commit（edit 会被删掉）。
2. `--yes`          跳过交互确认（CI 用；本地跑会问一次）。
3. commit 一律带 `changesNotSentForReview=true` —— 本账号是托管式发布，
   带了这个参数 commit 才不会被 400 打回；**改动仍要人去 Console 点「送审」**。

退出码：0 成功 / 1 有阻断 / 2 用法错 / 3 认证失败 / 4 API 业务错 / 5 权限不足
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aso_common as C  # noqa: E402

IMAGE_TYPES = ["phoneScreenshots", "featureGraphic"]


# --------------------------------------------------------------------------- #
# edit 生命周期
# --------------------------------------------------------------------------- #
class Edit:
    """一个 Play edit 会话。退出时若未 commit 就删掉，避免留下脏 edit。"""

    def __init__(self, service, package: str, dry_run: bool, auto_review: bool = False):
        self.service = service
        self.package = package
        self.dry_run = dry_run
        self.auto_review = auto_review
        self.id = None
        self.committed = False

    def __enter__(self):
        C.load_pu().log("[edit] 开一个变更会话…")
        self.id = (self.service.edits()
                   .insert(packageName=self.package, body={})
                   .execute()["id"])
        C.load_pu().log(f"[edit] editId = {self.id}")
        return self

    def commit(self) -> None:
        if self.dry_run:
            C.load_pu().log("[edit] dry-run：不 commit")
            return
        kwargs = {"packageName": self.package, "editId": self.id}
        if self.auto_review:
            # 该包是「提交即自动送审」模式：**不能**带 changesNotSentForReview，
            # 带了会 400。commit 一发出就进审核队列 ⇒ 必须先拿到用户明确同意。
            pass
        else:
            kwargs["changesNotSentForReview"] = True
        try:
            self.service.edits().commit(**kwargs).execute()
        except Exception as e:  # noqa: BLE001
            msg = str(e)
            if "sent for review automatically" in msg:
                C.load_pu().log(
                    "🔴 这个包是「提交即自动送审」模式，不能带 changesNotSentForReview。\n"
                    "   本次改动未提交（edit 已作废，线上没有变化）。\n"
                    "   确认要直接进审核队列，重跑并加 --auto-review。")
                raise SystemExit(4) from None
            raise
        self.committed = True
        if self.auto_review:
            C.load_pu().log("[edit] 已 commit（自动送审 ⇒ 已进审核队列）")
        else:
            C.load_pu().log("[edit] 已 commit（changesNotSentForReview=true ⇒ 仍待人工送审）")

    def __exit__(self, exc_type, exc, tb):
        if self.committed:
            return False
        try:
            self.service.edits().delete(packageName=self.package, editId=self.id).execute()
            C.load_pu().log("[edit] 已删除未提交的 edit")
        except Exception as e:  # noqa: BLE001
            C.load_pu().log(f"[edit] 删除 edit 失败（无妨，会自动过期）：{e}")
        return False


# --------------------------------------------------------------------------- #
# list
# --------------------------------------------------------------------------- #
def cmd_list(args) -> int:
    service = C.play_service(args.service_account)
    locales = C.parse_locales(args.locales)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    out = Path(args.out).expanduser() if args.out else (C.ONLINE_DIR / stamp)
    out.mkdir(parents=True, exist_ok=True)

    listings: dict[str, dict] = {}
    images: dict[str, dict] = {}
    with Edit(service, args.package, dry_run=True) as ed:
        for loc in locales:
            try:
                body = (service.edits().listings()
                        .get(packageName=args.package, editId=ed.id, language=loc)
                        .execute())
                listings[loc] = {k: body.get(k, "") for k in
                                 ("title", "shortDescription", "fullDescription", "video")}
            except Exception as e:  # noqa: BLE001
                listings[loc] = {"error": str(e)}
            images[loc] = {}
            for it in IMAGE_TYPES:
                try:
                    r = (service.edits().images()
                         .list(packageName=args.package, editId=ed.id,
                               language=loc, imageType=it)
                         .execute())
                    images[loc][it] = [
                        {"id": i.get("id"), "url": i.get("url"), "sha1": i.get("sha1")}
                        for i in r.get("images", [])
                    ]
                except Exception as e:  # noqa: BLE001
                    images[loc][it] = f"ERR {e}"

    (out / "listings.json").write_text(
        json.dumps(listings, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "images.json").write_text(
        json.dumps(images, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    C.load_pu().log(f"[list] 已导出 → {out}")
    rows = []
    for loc in locales:
        d = listings.get(loc, {})
        if "error" in d:
            rows.append([loc, "ERR", "-", "-", "-", d["error"][:40]])
            continue
        rows.append([
            loc, C.LOCALES[loc]["label"],
            f"{C.char_count(d['title'])}/{C.LIMITS['title']}",
            f"{C.char_count(d['shortDescription'])}/{C.LIMITS['shortDescription']}",
            f"{C.char_count(d['fullDescription'])}/{C.LIMITS['fullDescription']}",
            f"图 {images[loc].get('phoneScreenshots') if isinstance(images[loc].get('phoneScreenshots'), str) else len(images[loc].get('phoneScreenshots') or [])}",
        ])
    C.print_table(rows, ["locale", "语言", "标题", "短描述", "长描述", "截图数"])
    print()
    for loc in locales:
        if "error" in listings.get(loc, {}):
            continue
        print(f"--- {loc} title: {listings[loc]['title']}")
        print(f"    short: {listings[loc]['shortDescription']}")
    return 0


# --------------------------------------------------------------------------- #
# push
# --------------------------------------------------------------------------- #
def _diff_line(field: str, old: str, new: str) -> str:
    if old == new:
        return f"  = {field} 未变（{C.char_count(new)} 字）"
    return (f"  ≠ {field}: {C.char_count(old)} 字 → {C.char_count(new)} 字\n"
            f"      旧: {(old or '(空)')[:90]}\n"
            f"      新: {(new or '(空)')[:90]}")


def cmd_push(args) -> int:
    variant = args.variant
    locales = C.parse_locales(args.locales)
    meta = C.load_variant_meta(variant)
    C.load_pu().log(f"[push] 变体 {variant}（{meta.get('label', '')}）语言 {', '.join(locales)}")
    if meta.get("hypothesis"):
        C.load_pu().log(f"[push] 假设：{meta['hypothesis']}")

    service = C.play_service(args.service_account)
    changed = 0
    do_text = not getattr(args, "images_only", False)
    do_images = bool(getattr(args, "with_images", False)) or bool(
        getattr(args, "images_only", False))
    with Edit(service, args.package, dry_run=not args.allow_write,
              auto_review=getattr(args, "auto_review", False)) as ed:
        for loc in locales:
            listing = C.load_listing(variant, loc)
            body = C.text_fields(listing)
            try:
                cur = (service.edits().listings()
                       .get(packageName=args.package, editId=ed.id, language=loc)
                       .execute())
            except Exception as e:  # noqa: BLE001
                print(f"[{loc}] 读线上失败：{e}")
                return 4
            print(f"\n=== {loc} ===")
            if do_text:
                for f in ("title", "shortDescription", "fullDescription"):
                    print(_diff_line(f, (cur.get(f) or "").strip(), body.get(f, "")))
            else:
                print("  （images-only：文案不动）")
            if do_images:
                _push_images(service, ed, args, loc)
            if not do_text:
                continue
            # 文案写入
            payload = {"language": loc, "title": body["title"],
                       "shortDescription": body["shortDescription"],
                       "fullDescription": body["fullDescription"]}
            if body.get("video"):
                payload["video"] = body["video"]
            if args.allow_write:
                try:
                    (service.edits().listings()
                     .update(packageName=args.package, editId=ed.id,
                             language=loc, body=payload)
                     .execute())
                    C.load_pu().log(f"[{loc}] 文案已写入 edit")
                except Exception as e:  # noqa: BLE001
                    txt = str(e)
                    print(f"[{loc}] 写入失败：{txt}")
                    print(C.hint_for_403(txt))
                    return 5 if "403" in txt else 4
            changed += 1

        if args.allow_write and not args.yes:
            ans = input("\n确认 commit 到 Play？（改动仍需人工在 Console 点「送审」）[y/N] ")
            if ans.strip().lower() not in ("y", "yes"):
                C.load_pu().log("[push] 已取消，edit 将回滚")
                return 1
        if args.allow_write:
            ed.commit()
        else:
            C.load_pu().log(f"[push] dry-run：{changed} 个语言只打印 diff，未写入未提交")
    return 0


def _push_images(service, ed, args, loc) -> None:
    """把派生目录里的图片整组替换上去（deleteall + 按文件名顺序 upload）。"""
    base = C.DERIVED_DIR / args.variant / loc
    if not base.is_dir():
        C.load_pu().log(f"[{loc}] 没有派生素材目录（{base}），跳过图片")
        return
    pu = C.load_pu()
    # 只传某一类（例如只换 featureGraphic，不动 16 张截图）：--image-types featureGraphic
    for it in (getattr(args, "image_types", None) or IMAGE_TYPES):
        files = sorted([p for p in base.glob("*.png") if p.name.startswith(_prefix_of(it))])
        if not files:
            continue
        if not args.allow_write:
            pu.log(f"[{loc}] {it}: 将替换为 {len(files)} 张 → {[f.name for f in files][:3]}…")
            continue
        (service.edits().images()
         .deleteall(packageName=args.package, editId=ed.id,
                    language=loc, imageType=it).execute())
        for f in files:
            from googleapiclient.http import MediaFileUpload
            (service.edits().images()
             .upload(packageName=args.package, editId=ed.id, language=loc,
                     imageType=it,
                     media_body=MediaFileUpload(str(f), mimetype="image/png", resumable=False))
             .execute())
        pu.log(f"[{loc}] {it}: 已传 {len(files)} 张")


def _prefix_of(image_type: str) -> str:
    return "shot_" if image_type == "phoneScreenshots" else "feature_"


# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="Play 商店页文案与素材读写")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("list", help="只读导出线上 listing 与图片清单")
    p.add_argument("--locales", default="", help="en,ja,zh-CN,zh-TW（默认全部）")
    p.add_argument("--out", default="", help="导出目录（默认 data_aso/online/<时间戳>）")
    p.add_argument("--package", default=C.PACKAGE)
    p.add_argument("--service-account", default=None)
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("push", help="推送变体文案（可含图片）到 Play")
    p.add_argument("--variant", required=True)
    p.add_argument("--locales", default="")
    p.add_argument("--text-only", action="store_true", help="只推文案，不动图片（默认）")
    p.add_argument("--images-only", action="store_true", help="只换图，文案不动")
    p.add_argument("--with-images", action="store_true", help="文案 + 图片都推")
    p.add_argument("--allow-write", action="store_true", help="🔴 才会写线上")
    p.add_argument("--yes", action="store_true", help="跳过交互确认")
    p.add_argument("--image-types", default="",
                   help="只传指定图片类型（逗号分隔：phoneScreenshots,featureGraphic）；"
                        "缺省全传。只换置顶图务必写 featureGraphic。")
    p.add_argument("--auto-review", action="store_true",
                   help="🔴 自动送审：去掉 changesNotSentForReview 提交。"
                        "只对「提交即自动送审」的包有效，一提交就进审核队列，改不回来。")
    p.add_argument("--package", default=C.PACKAGE)
    p.add_argument("--service-account", default=None)
    p.set_defaults(func=cmd_push)

    p = sub.add_parser("images", help="只替换图片（= push --images-only）")
    p.add_argument("--variant", required=True)
    p.add_argument("--locales", default="")
    p.add_argument("--allow-write", action="store_true")
    p.add_argument("--yes", action="store_true")
    p.add_argument("--image-types", default="",
                   help="只传指定图片类型（phoneScreenshots,featureGraphic）；只换置顶图写 featureGraphic。")
    p.add_argument("--auto-review", action="store_true",
                   help="🔴 自动送审：一提交就进审核队列（该包不允许 changesNotSentForReview）。")
    p.add_argument("--package", default=C.PACKAGE)
    p.add_argument("--service-account", default=None)
    p.set_defaults(func=cmd_push, images_only=True, text_only=False, with_images=False)

    args = ap.parse_args()
    for k in ("text_only", "images_only", "with_images"):
        setattr(args, k, bool(getattr(args, k, False)))
    picks = [x.strip() for x in (getattr(args, "image_types", "") or "").split(",") if x.strip()]
    bad = [x for x in picks if x not in IMAGE_TYPES]
    if bad:
        print(f"🔴 未知 image-type：{bad}（可选 {IMAGE_TYPES}）", file=sys.stderr)
        return 2
    args.image_types = picks or IMAGE_TYPES
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
