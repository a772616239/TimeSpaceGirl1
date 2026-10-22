# REF-art-translate —— 中文美术字 → 英文版（Jenkins `TS-Art-Translate`、`scripts/image/banner_translate.py`、译名表 `scripts/image/banner_translate_map.json`）

> 从 MEMORY.md 下沉（2026-10-22，MEMORY 超长被截断）。MEMORY 只留触发条件，细节看这里。

## 1. 触发与参数
- job：`TS-Art-Translate`，参数 `MODE=batch|one` / `ASSET` / `PROVIDER=chatgpt_web|local|manual` / `GEN_IMAGE` / `CDP_PORT` / `ADSPOWER_PROFILES` / `PROVIDER_TIMEOUT`(默认240) / `BUDGET` / `FORCE` / `WRITE`。
- `MODE=one` 必须 `ASSET=<真实存在的源图路径>`（stage ① `fileExists` 直接 error）。`_zh` 后缀：`ArtFont_zh/**` 绝大多数带，`Atlas/**` 图集图通常不带 ⇒ 用户口述名字可能漏 `_zh`，先 `ls` 核实。
- 🔴 不要用 `--only <名>` 跑 MODE=one：候选池按特征分派，落不进池的图（如 `ArtFont_zh/font` 512x256 特写横幅）会让 ②③④「目标 0 张」全绿 = 假绿球（#6 实测）。job 里已按此改：有 `ASSET` 就传 `--asset`，`--only` 只在 batch 用。
- 凭据 `~/.jenkins/.qclaw-creds`（`U=a772616239`）；触发必须 `POST /buildWithParameters` + 表单字段，`json=` 传参不生效。
- 复用已登录浏览器：`python scripts/image/find_browser_cdp.py` 反查端口（曾稳定拿到 62081，ChatGPT 标签 2 个）→ `CDP_PORT=62081`。留空则用本机 Chrome 登录态副本。
- 🔴 **`ADSPOWER_PROFILES` 必须显式给**（2026-10-22 #42 实证）：默认换号链只走到 ①②，遇到「Free 套餐出图额度已用尽」就退，rc=3 → 验收因缺 `state.json` 判红（看起来像资产问题，其实是号池）。站点会明确给重置时长（实测 3 个号分别 1h / 7h / 16h），`kuh8m7e` 已是 `ads_missing` 残留在 `_output/art_restyle/provider_state.json`。显式写 4~5 个 id（如 `kvrvx5h,k1hiv2p8,k19wnpan,ktmrjhu,k12w7kmd`）后 50s 就出图。
- 出图耗时可低到 50s（不是每次 3~8 分钟）：快不一定有问题，靠硬项 + OCR + sha256 台账判，不靠耗时。
- 本机 tesseract 实际可用，#49 OCR 相似度 1.00（期望 `DEMONICSHADOW` / OCR `HEROSKILLDEMONICSHADOW`，小标 HERO-SKILL 会一起读进来，滑窗相似度不受影响）。

## 2. 四族自动分派（尺寸带互不重叠）
| 族 | 特征 | 画法 |
|---|---|---|
| artfont | `ArtFont_zh/**` 884x544 | 三段版面锚点写死，本地排字（local 可跑） |
| atlas | `Atlas/**` | 中文压纯色黑板 ⇒ 白字核+纯色板自动定位 |
| glyph | `ArtFont_zh/**` ≤700x500 且 ≤8 色 | 纯白字+alpha 页签/字块，本地排字会换掉笔画风格 ⇒ **只能 chatgpt_web** |
| poster | ≥800x700（`DynamicActivityPanelAtlas/banner/` 884x856） | 插画+彩带整幅重绘后等比 cover 回原尺寸，**只能 chatgpt_web** |

- 🔴 例外：`ArtFont_zh/**` 里 **884x336 彩带满幅**横幅（`ExpertPanelAtlas/banner/`）尺寸落在 artfont 带但版面不是 884x544 ⇒ 必须显式 `--family poster`（local 锚点用不上）。
- texie 系列（`ArtFont_zh/font/` 512x256）落在 artfont 带但不是三段版面、也不是单色 glyph（1000+ 色）⇒ `family=auto` 判 artfont，走「整幅重绘 + alpha lock + 可见区改动 2%~75%」，provider 必须 chatgpt_web。
- glyph / poster / texie 都走译名表白名单：`banner_translate_map.json` 里 `zh_text` + `lines` + 可选 `gpt_layout` + `note`（note 记录译名来源与双源核实过程，别删）。

## 3. texie 512x256 特写技能横幅（重点）
- 画面：黑色笔刷横幅底板 + 网点 + 渐变大字，左上 `HERO-SKILL` 小标本来就是英文，**不许动**。alpha 锁死在中文笔画轮廓上。
- 宽度是唯一硬约束：正文实心板各行不同（suoluomen 约 x≈59..433；zhende x≈85..421；shiba/zhitianxinzhang 约 75..417）⇒ 以条目内实测值为准，越界笔画会被 `putalpha` 啃掉。
- 行数判定按字符数：zhende『Divine Judgment』15 字符 347px 宽 / 43px 高单行即已上线合格；14 字符级（`REALM CONQUEST`）单行 44~50px cap 也在区间内（两行在 68px 字带里只剩 30px cap，反而更小）。≳15 字符或长词组（16 字量级）才拆两行。
- 已上线同族译名（语义译，别用罗马字音译）：Divine Judgment / Demonic Shadow / Frost Charge / Echoes of Blood / Devilish Wisdom / Breath of Temptation / Realm Conquest。
- 🔴 译名口径：2026-10-22 用户明确「要英文能看懂」⇒ 语言表 D 列是罗马字音译时（如 38010152 `Tenka Fubu`）改语义译名。

## 4. gpt_layout 提示词要点
- 开头必写：`TARGET TEXT IS FIXED — copy it verbatim, do NOT translate anything yourself`。模型会自造译名（mozhate 要 Ave Verum Corpus，出图却是 DIVINE JUDGMENT）。
- 必带 IDENTITY LOCK：底板/网点/箭头/HERO-SKILL 不动，禁止新增人物/插画/装饰/风景（zhende #16 整幅画成白发角色插画，改动 96.5% 打红）。
- 宽度上限要写成绝对像素区间 + 「先压字距，再降字高，绝不拉宽彩带/底板」+「不要漏掉末字母 W/T」。
- 英文比中文长 3~4 倍时只写 condense 不够：要给「跨度不超过它替代那句 + 金卡右留 30px / 离彩带尖留 20px」。
- 🔴 硬参数（行数/字数/字面/宽度）它听，**软参数（行距/内缩）不听**：要 14px 行间、右界 x365，实测给 5px / 389 ⇒ 别靠加提示词抠 5px，接受或改条目。

## 5. 归位与验收（全部本地硬断言）
- 出图只负责「把图给我」：抠墨迹 → 染纯白 + alpha → 等比 contain 进源 bbox。尺寸/位置/颜色不交给模型。
- 🔴 喂模型的参考图必须**白底黑字**：透明 PNG 按白底预览＝白纸；深底白字会被交回白底白字废图。
- 🔴 整幅重绘族「字被切」的唯一修法是 **lock 之前 refit**：`postprocess_photo` 无条件 `putalpha(源图 A)` 会啃掉越界笔画。判定量 = `ink & (alpha<=8)` 像素数，只能在 lock 前算（`text_fit.refit_covered` 在 `postprocess_photo` 之前）。修法：只压「真有笔画掉在外面」的那几行字带，腾出的列填「该块底板背景色中位数」（拿新文字边缘列横向复制会刷亮条，实测压到 82% 越界像素一个没少）。缩比 <0.8 判红重出。合成用例：字带加宽 18%（8.06% 越界）⇒ 压到 84% → 0.19%，无接缝。
- 🔴 别拿「文字落在实心区外的像素比例」当闸门：6 张人眼合格品 9%~28.6%，被裁的 #30 是 20.8%，零判别力（刷子底板边缘参差 + 半透明接缝）。
- 🔴 **「改动像素 >40% ⇒ 模型顺手改了画面」不能按整幅可见区量**：512x256 特写横幅可见区只有 28.8%、字带占掉 rows 60~206，光换字就是 40~45%（mozhate 44.8% 人眼合格）⇒ 每次都亮＝教人忽略警告。改量**字带以外**的改动（>10% 才亮，`_text_band`）。poster 族保留原绝对值（它本来就该整幅重绘）。
  - 🔴 字带口径 = **源图墨迹行 ∪ `refit.row_band`，±6% 画布高**。**不能只用 `refit.row_band`** —— 它记的是「真越界被压的那几行」而非字带（mozhate `row_band` 66~171，墨迹实际到 row 206），拿它当带内会把 1558 个可见像素全划到带外，噪声就 43%，又一条假警报。
- 🔴 OCR 闸门（`scripts/image/text_fit.py`）：`ocr_read_all` 把成品 flatten 黑底后按 **polarity{raw,inv} × psm{6,11}** 四种组合各读一遍，返回全部候选；上层用 `text_score` 与 `entry['lines']` 做**滑窗相似度**（PASS≥0.55 / FAIL<0.35）**取最像的那份**。逐词比对会被「HERO-SKILL」小字稀释，别用。
  - **按相似度挑，不能按长度挑**：长度最大的那份未必读得对（`--psm 11` 把 LIFETIME 读成 UFETIME）。
  - **两种极性都要试**：固定「黑底→反相」＝假设白字；海报族深色描边压金色彩带一反相就成白底白字，`jingyinghuodong_banner_12`（人眼清清楚楚 LIFETIME PACK）读 0 字 ⇒ 0.00 ⇒ 假红。
  - **两种 psm 都要试**：`--psm 6`（单块文本）对透视/斜排美术字整块丢掉，同图 `--psm 11`（稀疏文本）才读出 `[UFETIME, Fo)`。
  - 🔴 **artfont 硬项 / poster 只做旁证**：poster 的文字是整幅重绘出来的，同一张人眼合格图实测 0.23（banner_12）~ 1.00（banner_12_b2），**没有分界**，判红＝把「OCR 读不动」当「模型翻错了」。artfont 抗性已验：自造译名（#27 DIVINE JUDGMENT）⇒ `JIVINE JUDGME!` 0.286 判红；合格品 baiqi 0.92 / mozhate 1.00。
  - 🔴 **「读不出字」≠「译文错了」**：读出 <3 个字母时必须降级成「闸门不适用」的 warn 并回显 OCR 原样输出，不许算 0 分判红。glyph 族仍未接（字块小、样本不够标定）。
- 🔴 tesseract 三坑（**本机已装 `/usr/local/bin/tesseract`**，别再写「本机没装」）：Jenkins PATH 无 `/usr/local/bin`（绝对路径探测）；LANG 空 → Latin-1 输出（别用 `text=True`，手工 `decode(errors='replace')`）；TMPDIR 未设落 `/tmp` 而 tesseract 打不开（rc=1 + stdout 空 ⇒ 会被算成相似度 0 判红）⇒ 临时文件写 work 目录。**闸门跑不起来必须降级成黄并说明原因，绝不能静默算 0 分**。本地自测注意：沙箱 shell 打不开 `/tmp`，work dir 要用项目内相对路径。
- 🔴 poster 别拿「整幅平均通道差 ≤45」当硬闸门：彩带+美术字占大半画布，只换字也 57~60（合格品实测 69~77）⇒ 降 warn/参考。硬项是「四边背景未被重绘」（上 40 / 下 30 / 左右 40px，均值 ≤25 且改动 ≤20%）。
- 🔴 透明图必须按 **alpha 掩膜**（`_visible_mask`）统计：透明区 RGB 是导出残留 (0,0,0)，参考图是 `_flatten` 深底 (28,30,44) 合成 ⇒ 出图那圈天然差 44>24，改动比例/整幅均值/四边背景全被看不见的像素判红。
- 🔴 异形透明卡（`OperatingPanelAtlas/*_peitu_zh.png` 884x1480）四边不是背景：79%~92% alpha=0，剩一圈是卡自己的描边+辉光，位移 1~2px 就 54/31%（上限 25/20%）⇒ `POSTER_EDGE_MIN_OPAQUE=0.50` 量边圈可见占比，低于判**不适用**打 warn。该卡实际只有 5 条硬项。
- 🔴 **验收前必须先判「这是不是本轮的产物」**（`_stale_state`，2026-10-22 #46）：出图失败时 `cmd_run` 不动 `out.png` 就退出，而 ③ 验收是独立阶段、只认磁盘 ⇒ 会把**上一轮的旧成品**量一遍并给红（与本轮无关的红最坏，人会去修不存在的问题）。两档：`inbox/gen.png.fail.json` 比 `out.png` 新 ⇒ 跳过验收（`status=skip`、退出 0、不产出 checks）；`out.png` 的 sha ≠ `state.json.out_sha256` ⇒ 只加 warn 照常验收（手工补笔后 sha 必然变，是合法流程）。
- 🔴 断言量不出「这张图是不是这次的」：复用浏览器时 driver 曾把上一张交回来（按面积最大选图、同尺寸取第一个）⇒ 靠 sha256 台账 `_output/art_translate/_gen_ledger.json`（`check_gen_reuse`）拒收。
- 🔴 出图串行：只有一份 Chrome/AdsPower 登录态 + 一份包月额度，`disableConcurrentBuilds()` 不可去。额度台账 `banner_translate.py quota`（`adspower:*` 逐个可用/封锁时间）。

## 6. 写回
- 🔴 en 图一律**平铺在族目录根**：`ArtFont_en/<族目录>/<名>_en.png`，族目录 = `ArtFont_zh/`/`Atlas/` 后第一段；zh 侧 `tab/`、`banner/` 子目录必须压平（既有 60+ 张 en 图全这个布局；`resPathList` 868 条白名单里没有 `ArtFont_en/…/tab`）。
- publish 有 `check_target_registered`（父目录**精确**匹配，别用祖先前缀，`ArtFont_en` 前缀会把任意子目录放行）与 `res_name_registered`（没登记就打印 ⏳ + 该重打哪个 AB）。
- 覆盖前备份到 `ResBackpack/备份/ManagedResources/...`。
- 🔴 写回 ≠ 进包：真机生效要重打该资源所在 AssetBundle（`FrameTool.BuildGameAssetBundles`）。客户端 `_en` 加载不到会**静默回退 `_zh`**（`Util.cs:1182-1224`，日志只有一行「回退加载精灵图」）⇒ 判断「写没写」看 resName 是否进 `resInfoList`，别看图。

## 7. 并行绘制与浏览器租约（2026-10-22，用户三项要求）
问题现场：① 额度用完浏览器留着，一排空号浏览器挂着；② 多个任务同时开跑会**挤进同一个 AdsPower profile**（`browser/start` 把同一个 debug 端口交回来）⇒ 互相覆盖提示词、拿回对方的图、**各报一次「额度用尽」**；③ 因此 job 只能 `disableConcurrentBuilds()`，一次画一张。

改法（唯一防线是租约，不是串行）：
- `provider_ledger` 新增：`locked()`（flock，所有读-改-写串行）、`lease_claim/lease_release/leases/lease_holders`、`note_event`（审计流水 `_output/art_restyle/browser_events.jsonl`）、`set_note`/`set_last_switch`。`pick/order` 会跳过「别人持有的通道」，**被占用的号不参与「全封锁赌一把」**（那是别人的浏览器）。
- 租约种类：`adspower:<uid>` / `cdp:<port>` / `chrome:<profile>` / `asset:<源图相对路径>`。TTL 默认 1200s；带 tag 的 owner（`TSG_LEASE_OWNER`）只按 TTL 判活，无 tag 的按 pid 判活（命令行跑完立刻失效）。
- `gen_chatgpt_web.py`：`--owner/--lease-ttl/--no-pin/--keep-browser-on-exhaust`；换号链改成 ⓪ 本轮钉住的 → ① 已开 SunBrowser（`cdp:<port>`）→ ② AdsPower 现开（`adspower:<uid>`，**先 claim 再 start**）。成功 ⇒ `mark_ok` + 写 pin（`_output/art_translate/_pins/<owner>.json`，第 2 张图直接接着这台上）；额度用尽 ⇒ `mark_exhausted`（解析恢复时间）+ **`adspower_stop` 关掉** + 放租约 + 清 pin，然后继续下一个号。`--cdp-port` 也 claim 端口，两轮指同一端口必有一轮被拒（rc=3）。
- `banner_translate.py`：`_owner()` 读 `TSG_LEASE_OWNER`；`batch` 每张图（run/verify/publish 三阶段都）先抢 `asset:` 租约，抢不到 skip；run 结束 `lease_release(owner=)` 放掉自己全部租约（浏览器**故意留着**，下一轮直接接入）。
- `quota` 现在报「可用 N / 占用中 M / 封锁中 K ⇒ 可并行 N 路」；全被占用返回 3（黄，不是没额度）。
- job：`concurrent: true` + 去掉 `disableConcurrentBuilds()`，`environment { TSG_LEASE_OWNER = "art-translate-${BUILD_NUMBER}" }`，post 里再 `lease-release --owner` 兜底（构建中途红掉不放会占满 TTL）。
- 测试：`scripts/image/tests/test_browser_pool.py`（跨进程互斥 / 换号 / 用完即关 / 8 进程写台账不丢更新 / 按 owner 钉号）、`test_fallback_rotation.py`（换号链离线仿真，打桩 fb+run_on_port，不烧额度）。
- 🔴 沙箱 shell 打不开 `/tmp`、`/var/folders` ⇒ 测试临时目录必须落工程内（`_output/...`），否则 `save()` 静默失败、测试变「全都成功」的假绿。
- 仍未生效的老账：11 个 `_en` 的 resName 不在 `ResourcePathConfig`，要 `TS-Resource-Build`（REBUILD_AB=true）重扫登记。

## 「字看着发灰/透」——先量 alpha，别调 RGB（2026-10-22 zhitianxinzhang 定位）
texie 这族底板是「笔刷 + 网点晕散」，**网点像素本身 alpha≈102**（不是 255）。模型把英文画进这块晕圈，文字像素就继承了底板 alpha ⇒ 交付图里 RGB 明明是 (252,100,107) 的亮红，合成到深底上却是暗红、网点透过来。`putalpha(源图 A)` 的 lock 语义会把这个缺陷**忠实保留**。
判据（一条命令定性）：`sa = 源图 alpha[字块 ink]`，看 `frac<255`——本例 **39.7%**，中位 102。
修法：`scripts/image/letter_alpha_fix.py --asset <zh 路径> --out <composed.png>`：字块（红墨迹膨胀 2px，含描边）alpha 置 255，其余原样；O/Q 的 counter 保持底板 alpha（仍读作洞）；顺带清 <150px 的碎红笔画。产 `{"alpha_band":[x0,y0,x1,y1]}` 边车 ⇒ 管线走「本地确定性合成」验收（**带外逐像素锁死、带内允许重建**）：带内 `alpha>250` 48.5%→73.3%、`alpha<100` 7.0%→5.6%，两条硬项都绿。
🔴 别再走「把字块抹成 per-row 纯色」那条路（试过 5 版）：会把立体斜面和描边一起抹平，反而更差；缺陷在 alpha 不在 RGB。
