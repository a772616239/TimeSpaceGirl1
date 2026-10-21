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
- 🔴 **free 构图的「姿势」是主题候选池随机抽，不是模型随机**：曾经 `theme_presets.json` 里写死单条
  `pose_hint="… presenting a small gift box …"`，被 `build_prompt` 原样注入 ⇒ 每张 free 图都是同一个抱礼盒姿势
  （四主题全中：圣诞礼盒 / 新年红包 / 万圣南瓜灯 / 情人节心形气球）。现为 `pose_hints` 数组 + 每次 `random.choice`，
  `--pose N` 指定 / `--pose none` 关闭 / 其它文字自定义；`COMPOSITIONS["free"]` 加硬约束 *Hands must stay EMPTY:
  never invent an object and put it in her hands*。**LAYOUT 里绝不再写「拿着 X」**（等于把随机池钉死）；
  实选的那句记在 `state.json.pose_hint`，Jenkins 侧同名参数 `POSE`。`lock` 构图不注入姿势。
- **8 个主题在册**（`scripts/image/theme_presets.json`）：christmas / newyear / halloween / valentine /
  summer_surf(夏日冲浪) / provence(普罗旺斯) / thanksgiving(感恩节) / cyber(赛博朋克)。**加主题只改预设，不改代码**；
  必填字段见 `docs/art_restyle_themes.md` §4，出图前必须 `restyle_pipeline.py themes --check` 绿。
- 🔴 `themes --check` 的判据（都是踩过的）：必填字段 / 拼错的未知字段 / suffix 小写且唯一 /
  palette≥3、body_colors 正好 2 且 #RRGGBB / **英文字段混中文会让模型画汉字** /
  pose_hints 出现手持动词但没标 `(opt-in prop)` / decor_sentence 需 replace 开头。
- 批量：`scripts/image/batch_restyle.py` + 清单 `batch_example.json`（`--dry-run`/`--only`/`--no-gen`/`--publish`）。
  `assets` 支持 glob ⇒ **同套 UI 的 zh/en/jp 必须一起换**（只换一份＝花脸）。出图单浏览器串行，别抢同一 CDP 端口；
  N 资产 × M 主题 = N×M 份额度；gen rc=3（额度/登录）停整批，去 AdsPower 换 profile + `find_browser_cdp.py` 反查端口。
  `variant=auto`：源 RGB→opaque、RGBA→alpha。汇总 `_output/art_restyle/_batch/<戳>/summary.md`。
- 🔴 **表1 台账（用户 2026-10-21 明确：每次替换完图片必须记录在案）**：`scripts/image/table1.json`（数据）+
  `table1.py`（`list/add/scan/export/check`）。`cmd_publish` 写回成功自动调 `record_publish()`——Jenkins 与
  batch_restyle 两链路都覆盖，登记失败只报警不阻断写回；测试用 `TSG_TABLE1` 指临时表，别污染真表。
  批量换新主题从表导出：`table1.py export --theme provence` → 喂 batch_restyle（defaults 自带紫框口径）。
  近 3 天非标题大图 18 条已种子化（12 条已 christmas、6 条待换）；排除规律集中在
  `EXCLUDE_NAME_PARTS`/`EXCLUDE_PATH_PARTS`（标题 biaoti/文字按钮/页签/图标/CV/_png_backup）。
- 主题参数配方（按图的形态，不按主题选）：整幅不透明底板＝keep+violet 框；浮层＝keep（**不能 source**，否则框上下边被切）；
  超长条＝`--hero-band 930 --body-mode source`；自带亮带/渐隐/空文案板＝`--frame none --watermark off` + `refit_band.py`。
  深底主题（cyber）与低饱和主题（provence）紫框会糊 ⇒ `FRAME_RIM=ivory`。
