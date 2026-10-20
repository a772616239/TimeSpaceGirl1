# REF-art-restyle —— 美术换皮（→ skill `art-restyle`、docs/art_restyle_pipeline.md、Jenkins `TS-Art-Restyle`）

> 从 `MEMORY.md` 迁出（2026-10-20），内容为原文。

- 🔴 边框按真机显示宽验（1080 资源进游戏 567px）：`python3 scripts/image/preview_ingame.py old.png new.png --cards 2x4`。
- 🔴 `provider=chatgpt_web` 用本机 Chrome 登录态：整份 profile 交 Chrome 自解密（cookie 重建无效）；`--no-sandbox --disable-gpu`；图是 blob+alt「已生成图像 N」；driver 连 localhost 要 `NO_PROXY`；`playwright-core` 取 `.default`。
- 🔴 **本机 Chrome 额度耗尽 / 连续失败 ⇒ 换 AdsPower 的 SunBrowser（别反复重跑）**：`scripts/image/find_browser_cdp.py` 反查端口（`port=64757`，Chrome/144，调试端口不在命令行里），Jenkins `TS-Art-Restyle` 填 `CDP_PORT=<端口>`（即 provider 侧 `--reuse-cdp`，只连不断、不关用户窗口、优先复用已开的 chatgpt 标签）。额度**按账号**算，换号只在 AdsPower 换个已登录 profile。SunBrowser 界面可能非中文（`GEN_ALT` 已覆盖中英日韩西法德葡）。20:00 实测：本机 Chrome 两连败（`.codex-dialog-overlay` 遮罩吃点击 / 图已出但 page closed），SunBrowser 72s 一把过。
- 🔴 `WATERMARK=off` 的场合：右下角本身有亮装饰带（如千抽底板青/白 V 形带）会被「亮+灰+排成一行」判据误判成水印，硬替换啃掉亮边 ⇒ 该图必须 off（掩码 0 时验收自动跳过该项）。
- 🔴 Jenkins `buildWithParameters` 的布尔参数进 groovy 是**字符串** `"false"`（非空即真）⇒ 闸门一律比 `(params.X ?: 'false').toString() == 'true'`；写过 `WRITE_BACK=false` 却真写回的事故（`47962c69f` 修）。
- 🔴 提示词不许写死文案（文案由 `LAYOUT` 构图锁逐字保持）；超长条底板不能整幅 cover ⇒ `HERO_BAND`（量带高，`row_std<25` 即纯渐变）+ `BODY_MODE=source`；接缝别把末行往下广播。
- 🔴 `WRITE_BACK=true` 是验收闸门：原图搬 `ResBackpack/备份/`（gitignore）→ 校验哈希 → 覆盖 → `_manifest.jsonl`；回滚 `restyle_pipeline.py restore`；`.meta` 永不改（guid 一换引用全断）。写回 ≠ 进包，要重打 AssetBundle。
- 🔴 卡框最外圈必须有亮边（`--frame-rim`，默认暖金）：判据＝亮边与底亮度差 ≥100；框线用多边形掩膜 `_ring_paste`，**不用** `ImageDraw.line(width=…)`（磨圆切角、互相盖住）。
- 🔴 **统一用紫框**：`FRAME=card` + `FRAME_RIM=violet`（登录底板定稿那档紫白），不要再回 warm/gold；`FRAME=card` 走 inset（画面缩进框内）。
- 🔴 **默认直接替换源图 + 原图搬备份**（用户明确要求，不必再问）：`publish --variant alpha --yes`（或 Jenkins `WRITE_BACK=true`）→ 原图进 `ResBackpack/备份/<资源相对路径>`、`_manifest.jsonl` 记台账、`.meta` 不动；回滚 `restyle_pipeline.py restore --asset <资源>`。浮层类资源要用 `ALPHA_MODE=keep` 才能得到完整框（source 掩膜会把顶/底边的框切掉）。
