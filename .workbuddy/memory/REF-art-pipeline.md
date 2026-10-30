# REF-art-pipeline —— 美术管线分派/并行/合规红线

> 2026-10-23 从 `MEMORY.md` 迁出，内容为原文，未删减。
> 翻译链路细节见 `REF-art-translate.md`，换皮见 `REF-art-restyle.md`。

- 四族按源图特征自动分派（尺寸带互不重叠）：`ArtFont_zh/**` 884x544→artfont（锚点写死）；`Atlas/**`→atlas；≤700x500 且 ≤8 色→glyph；≥800x700→poster。**glyph / poster / 512x256 texie 只能 provider=chatgpt_web**（local 会 rc=3）。884x336 彩带满幅（`ExpertPanelAtlas/banner/`）落在 artfont 尺寸带但版面不同 ⇒ 显式 `--family poster`。
- `MODE=one` 传 `--asset` 必指**真实存在的源文件名**（多数带 `_zh`，Atlas 图无后缀；口述名字常漏 `_zh`，先 `ls` 核）；用 `--only` 会让 ②③④「目标 0 张」全绿＝假绿球。
- 🔴 **出图已可并行（2026-10-22 起），正确性靠「浏览器租约」不靠串行**：`TS-Art-Translate` 去掉了 `disableConcurrentBuilds()`，改成开画前抢 `provider_ledger.lease_claim`（kind=`adspower:<uid>`/`cdp:<port>`/`chrome:<profile>`/`asset:<源图>`）。抢不到就换下一个号（并行路数 = 没封锁的号数）；额度用尽**立刻 `adspower_stop` + 记 `blocked_until` + 放租约**再换下一个。`TSG_LEASE_OWNER=$JOB_NAME-$BUILD_NUMBER` 必须传（一轮 batch 里每张图是独立进程，用 pid 认不出自己人）。同一张图被另一轮占着 ⇒ skip（不是失败）。详见 `REF-art-translate.md` §7。
- 额度看 `banner_translate.py quota`（会报「可并行 N 路 / 占用中 / 封锁中」）；手工查占用 `provider_ledger.py lease-list`、审计流水 `provider_ledger.py events`。复用已登录浏览器用 `find_browser_cdp.py` 反查端口传 `CDP_PORT`（该端口也会被租约占住，两轮指同一端口必有一轮被拒）。
- 🔴 `gpt_layout` 开头必写 `TARGET TEXT IS FIXED — copy it verbatim, do NOT translate anything yourself` + IDENTITY LOCK（禁止新增人物/插画/装饰，底板与 HERO-SKILL 小标不动）——模型会自造译名（mozhate 要 Ave Verum Corpus 出图是 DIVINE JUDGMENT；zhende #16 整幅画成角色插画）。硬参数（行数/字数/字面/宽度像素区间）它听，**行距/内缩不听**。
- 🔴 字被切只有一个修法：**lock 之前 refit**（`putalpha` 才啃笔画）；判定量 `ink & (alpha<=8)`，只压有笔画越界的那几行字带，腾出列填底板背景中位数。别拿「越界比例」当闸门（零判别力）。详见 REF。
- 🔴 透明图统计一律走 alpha 掩膜（`_visible_mask`），异形卡四边不是背景（`POSTER_EDGE_MIN_OPAQUE=0.50` 量边圈占比，低于判不适用）；OCR 闸门 `text_fit.py`（tesseract 三坑见 REF），**跑不起来降黄 + 说明原因，不许静默算 0**（本机未装 tesseract，当前必跳过）。
- 🔴 en 图**平铺族目录根**（`ArtFont_en/<族目录>/<名>_en.png`，zh 侧 `tab/`/`banner/` 压平）；目录不在 `resPathList` 白名单 ⇒ 重扫跳过 ⇒ 真机白图。写回 ≠ 进包（要重打 AB）；`_en` 缺失客户端**静默回退 `_zh`**，判断写没写看 resName 是否进 `resInfoList`。
- 🔴 换皮 = 换色不是换结构；重装/机械角色必须 `--outfit` 逐件点名装备（「保留分节与铆钉只换色，不许变 gift box / 丝带 / 包裹，双手原姿势可见」）。换风格出图**禁用内置 ImageGen**（10-21 用户明确），只走 AdsPower；号池 6 个但换号链默认只试 3 个 ⇒ 显式 `ADSPOWER_PROFILES` + 看过期台账 `_output/art_restyle/provider_state.json`。
- 🔴 异形透明 + 要套框 ⇒ `--alpha-mode keep --frame card --frame-rim violet`（源 alpha 按老构图抠的，套到重画图上会硬斜切）。
