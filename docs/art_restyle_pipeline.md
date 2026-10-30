# UI 美术资源「换节日风格」流水线（skill）

> 落地时间：2026-10-20（管线初版）／2026-10-20 晚（补「替换原图 + 原图搬出工程 + 超长条底板」）  
> 入口：Jenkins job **`TS-Art-Restyle`** ／ 命令行 `scripts/image/restyle_pipeline.py`  
> 🎯 一线操作手册（什么时候用哪条命令、边框三定律、验收清单、7 条红线）：  
> **`.workbuddy/skills/art-restyle/SKILL.md`** —— 先读它，本文只留原理与复盘。  
> 🎨 主题生产卡（9 个主题的设计意图/禁忌、四类图的参数配方、新主题接入 7 步、批量管线与额度纪律）：  
> **`docs/art_restyle_themes.md`**  
> 真机观感预览：`scripts/image/preview_ingame.py`（按 567px 显示宽贴回面板底 + 叠占位卡 + 边角特写）  
> 已实战：`EightDayGiftPanelAtlas/cn2-X1_baridenglu_diban_en.png`（1080×1644 登录底板 → 圣诞版）  
> 已实战：`OperatingPanelAtlas/cn2-X1_chaozhijj_diban_en.png`（856×2048 超值底板 → 圣诞版）

---

## 一句话

**出图那一步交给 provider（人 / Agent / 浏览器登录态），其余每一步都可断言**：去水印 → 尺寸归位（绝不拉伸）  
→ 出「不透明版 + 沿用原 alpha 的浮层版」→ 像素级验收 → 可选写回（原图搬出工程到 `ResBackpack/备份`）。

为什么要这样切：出图不可复现、有随机性、还会因为网络/额度失败。把它单独摘出去，Jenkins 才能对  
后面九步做红绿判定；provider 挂了只红一个节点，不污染其余证据。

---

## 构图三档：lock / free / design（2026-10-21 加 design）

| 档 | 提示词动词 | 放开 | 护栏在哪 |
|---|---|---|---|
| `lock` | Restyle | 只换衣服/配色/材质 | `layout_default` |
| `free` | Restyle | 人物姿势、镜头、裁切 | `layout_free` |
| `design` | **Redesign** | 版面、场景、镜头、道具、装饰全部重排 | `layout_design`（画风/画布/文案/UI 空区四条硬边界） |

`design` 的由来（用户 2026-10-21 要求「让 AI 自主设计，只要符合整体画风、更吸引人」）：

- **动词必须换掉**：写 `Restyle` 时模型会老老实实沿用原版面 —— 它把任务理解成「换材质」。
  `design` 用 `Redesign` + `DESIGN_BRIEF`，第一句就是「你是美术指导，不要照抄原版面」。
- **画风锁不能顺手锁构图**：`DEFAULT_STYLE_LOCK` 原来结尾是「只有配色/材质/服装/布景变」，
  放进 design 档跟「你可以重排版面」自相矛盾，模型会挑一句听。现在「可变范围」拆到
  `COMPOSITIONS[x]["style_scope"]`，按档给不同的一句。
- **UI 契约一条不放**：design 只是「美术层自由」，文案策略、UI 空区位置、画布比例与安全边
  仍然是硬的。`themes --check` 按关键词卡 `layout_design` 的四项，缺一项直接红。
- **alpha**：整幅重绘 ⇒ `keep`（`source` 会被自动改写并打提示）；源是 RGB 就 `--variant opaque`。
- **姿势**：design 默认不注入 `pose_hints`（姿势也归模型），显式 `--pose` 才生效。

---

## 命令速查

```bash
PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python
W=_output/art_restyle/<资源名>/<主题>

$PY scripts/image/restyle_pipeline.py themes                     # 列内置主题
$PY scripts/image/restyle_pipeline.py prompt --theme christmas   # 打印完整提示词（含参数）
$PY scripts/image/restyle_pipeline.py prompt --theme christmas --composition free   # 自由构图（人物可重设计）
$PY scripts/image/restyle_pipeline.py prompt --theme christmas --composition design # AI 自主设计整张图（2026-10-21）
$PY scripts/image/restyle_pipeline.py prepare   --asset Assets/.../x.png --theme christmas [--layout F] [--composition free]
$PY scripts/image/restyle_pipeline.py postprocess --work "$W" --gen "$W/inbox/gen.png" [--hero-band 930] [--watermark off]
$PY scripts/image/restyle_pipeline.py verify    --work "$W"
$PY scripts/image/restyle_pipeline.py graph     --work "$W" --out "$W/graph.md"
$PY scripts/image/restyle_pipeline.py publish   --work "$W" --variant alpha --yes [--note "job#n"]
$PY scripts/image/restyle_pipeline.py restore   --asset Assets/.../x.png [--list] [--version 20261020]

# 不走 job，单跑 ChatGPT 出图通道（用你 Chrome 的登录态）
$PY scripts/image/gen_chatgpt_web.py --image "$W/src/source.png" --prompt-file "$W/prompt.txt" \
    --out "$W/inbox/gen_web.png" --crop-height 930 [--check-only]

# 额度用尽 / 换号：接上 AdsPower 里已登录的 SunBrowser（不搬 cookie、不关窗口）
$PY scripts/image/find_browser_cdp.py                     # 反查 CDP 端口
$PY scripts/image/gen_chatgpt_web.py --image "$W/src/source.png" --prompt-file "$W/prompt.txt" \
    --out "$W/inbox/gen_web.png" --crop-height 930 --reuse-cdp --port <端口>
```

退出码：`0` 通过 / `1` 失败 / `2` 用法错误 / `3` 需要人看一眼（Jenkins 里 `--warn-rc 3` → 黄，不阻断）/
`4` **出图额度用尽**（driver 内部码，`gen_chatgpt_web.py` 会转成「自动换号」或 `3`）。

---

## Jenkins `TS-Art-Restyle` 参数

| 参数                           | 作用                                                                                                  |
| ---------------------------- | --------------------------------------------------------------------------------------------------- |
| `ASSET`                      | 目标资源（相对工程根）。**目标尺寸取该图自身尺寸**，不填尺寸                                                                    |
| `THEME`                      | 见 `restyle_pipeline.py themes`（现有 9 个：圣诞/新年/万圣/情人/夏日冲浪/普罗旺斯/感恩/赛博/探索）。风格全在 `scripts/image/theme_presets.json`；**新增主题要把 key 同步进 job 的 choices 再 `apply-jobs.sh`**，否则下拉选不到 |
| `PROVIDER`                   | `chatgpt_web`（**默认**，用本机 Chrome 登录态驱动 chatgpt.com）／`manual`（图由人/Agent 出，放进 inbox 或用 `GEN_IMAGE` 指定） |
| `GEN_IMAGE`                  | manual 时显式指定生成图；留空取 inbox 里最新的                                                                      |
| `CDP_PORT`                   | 复用外部已登录浏览器（AdsPower/SunBrowser）的调试端口，`find_browser_cdp.py` 反查。留空=用本机 Chrome                         |
| `LAYOUT`                     | 构图锁文本。**每张图的文案不同，所以文案一定写这里，不要写进主题预设**                                                               |
| `OUTFIT`                     | 按图覆盖主题的服装句（只改「穿什么」，配色/装饰仍走主题）。**角色的剪裁/露肤度属于设计的一部分时必填**——主题默认大衣会把舞娘/泳装/战甲角色裹住，等于偷偷改了构图 |
| `COMPOSITION`                | `lock`（默认，人物姿势/位置/缩放全锁，只换衣服与配色）／`free`（允许重设计人物姿势与镜头换吸引力）。见下节                                        |
| `PROMPT_OVERRIDE`            | 整段覆盖提示词（LAYOUT 不够用时才用）                                                                              |
| `HERO_BAND`                  | 超长条底板专用：英雄带像素高度（如 `930`）或 `auto`。留空=整幅等比 cover                                                      |
| `BODY_MODE`                  | `auto`（默认）/ `source` / `synthetic`，见下                                                               |
| `ALPHA_MODE`                 | `source`（默认，只对 lock 成立）/ `keep` / `free`。**`COMPOSITION=free` 时 `source` 会把人脸裁掉**，会被自动改成 `keep`，见上节 |
| `FRAME`                      | `auto`（默认：free 套游戏卡框、lock 不套）/ `card` / `gold`（旧红金，兜底）/ `none`，见上节                                  |
| `FRAME_RIM`                  | 卡框最外的亮边：`warm`（默认暖金）/ `ivory` / `violet` / `none`。**深色面板上不画亮边 = 框看不见**，见上节                          |
| `ALPHA_FROM` / `SOURCE_FROM` | 资源已被换过、工作区里没原版时，用 `git:HEAD:<path>` 取回参照                                                            |
| `WRITE_BACK`                 | **替换原图（默认开）**：验收通过后把成品写回资源，**原图先搬进 `BACKUP_ROOT`** 再覆盖，`.meta` 不动。传 `false` 只出图不改资源                                                              |
| `BACKUP_ROOT`                | 备份根，留空 = `ResBackpack/备份`                                                                           |
| `COMPRESS`                   | 交付前压体积（写回**之前**跑，阶段 ⑤b）：`auto`（默认）/ `lossless` / `off`。目标体积默认取资源当前体积 = 「别比之前那张大」 |
| `COMPRESS_MAX_DIFF`          | 降位深允许的最大通道差（默认 8，只在不透明区算）。调小更保画质、可能压不到目标；调大更小、渐变处可能出台阶 |

构建页能看到：环节表（JUnit）+ `summary.md` + 构建描述 + `artifacts/`（改前改后对比图、graph.md、  
prompt.txt、state.json、published.json）。节点图由 `graph` 生成，链路  
`prepare → generate → postprocess → verify → publish`，绿/红/灰三色。

---

## 构图自由度：`COMPOSITION=lock|free`

换节日风格时会长出来的两种诉求，用一档参数切：

| 档位         | 人物                               | 文案 / 空白区 / 画布 | 适用                               |
| ---------- | -------------------------------- | ------------- | -------------------------------- |
| `lock`（默认） | 姿势、位置、缩放、轮廓全锁，只换服装与配色            | 全锁            | 只换皮的批量活；出图可预期，返工率最低              |
| `free`     | **可完全重设计**：新姿势、新镜头角度、位置/裁切/缩放都能动 | 仍锁死           | 要「一眼更吸引人」的运营位（登录底板、充值/活动 banner） |

`free` 放开的是**美术**，不是 UI 契约。三条硬约束照旧（写死在 `layout_free` 里）：

1. **文案逐字不变**且完整可读、不被人物挡住、不出血；允许重排位置来换构图；
2. **底部 UI 空白区**形状与边距不变 —— 那里要盖按钮和列表，画了东西就废；
3. **画布尺寸、出血、底部卡体位置**不变。⚠️ 但**透明轮廓不能沿用源 alpha** —— 见下一节，这条踩过。

主题可用 `pose_hint` 给 `free` 一个推荐姿势（人话描述，不写文案），例如圣诞：  
「playful leaning-forward pose presenting a small gift box toward the viewer…」。没有 `pose_hint` 也能跑，模型自己发挥。

```bash
$PY scripts/image/restyle_pipeline.py prompt --theme christmas --composition free   # 先看提示词再出图
$PY scripts/image/restyle_pipeline.py prepare --asset Assets/... --theme christmas --composition free
```

🔴 工作目录必须分桶：`lock` 落 `_output/art_restyle/<资源>/<主题>`，`free` 落 `<主题>_free`  
（Jenkins 里自动加后缀）。同一张图的「锁姿势版」和「重设计版」要能同时留在磁盘上对比，  
混在一个目录里 `prepare` 会覆盖 `src/source.png`，对比图就变成「新版 vs 新版」。

🔴 `free` 出图**必须人眼看**：模型重排文案时可能出现错字、缺字、字被人物压住。`verify` 只能量尺寸/alpha/  
水印残留，量不出「字错了」——这一步没有自动闸门，别开 `WRITE_BACK` 就撒手。

---

## `free` 的收尾：`ALPHA_MODE`（别裁人物）+ `FRAME`（画框把硬边装裱）

`free` 让模型重画了姿势和镜头，于是有两个**只有 free 才会犯**的错，lock 版根本看不到：

### 1）`ALPHA_MODE=source|keep|free`

| 值            | 含义                                | 什么时候用                           |
| ------------ | --------------------------------- | ------------------------------- |
| `source`（默认） | 沿用源资源掩膜                           | **只对 `lock` 成立**：轮廓没动，掩膜自然贴合    |
| `keep`       | 整幅不透明                             | `free` 的真实语义：人物换位置/变大了，源掩膜已经不贴合 |
| `free`       | 整幅不透明 + 顶边渐隐 `--feather-top N` px | 想让上沿虚进面板背景时用（顶边贴人物时不建议，会糊掉帽子）   |

🔴 **`free` 构图 + `source` alpha = 用一把老剪刀裁新人物。** 2026-10-20 登录底板就这么翻的车：  
源掩膜是按老的「站桩」姿势抠的，新版人物头更高、身体更宽，掩膜把**左脸、头发、帽子**整块切掉，  
图上看着就是「脸没了」。现在 `postprocess` 在 `composition=free` 且 `alpha-mode=source` 时  
**自动降级成 `keep`** 并打日志；真要沿用源掩膜必须显式写 `--alpha-mode source`。

`verify` 也跟着改了口径：`keep/free` 模式不再要求「覆盖率等于源」（必然更高），  
改为两条硬校验 —— 覆盖率**不低于**源 + 生成图里的彩色高光（人物肤色/文案金边）**没有被压成透明**。

### 2）`FRAME=auto|card|gold|none`

`free` 的成品是**整幅矩形**（模型不会给你抠好的透明轮廓），于是四边是硬切、上半截与下半截卡体的  
接缝也像没画完 —— 这种情况要「装裱」。

🔴 **框必须说游戏自己的语言，别拿相框套海报。** 2026-10-20 首版做了「红金双层 + 四角八角星徽章」，  
被否了：游戏里**一个鎏金圆徽章都找不到**，贴上去像给海报装了个相框。回头看游戏自己的边框只有三种：

| 出处                                                          | 语言                      |
| ----------------------------------------------------------- | ----------------------- |
| `X1PublicAtlas/cn2-X1_tongyong_daojukuang_01~07`（道具槽）       | 深色渐变 + **菱形网格纹** + 细亮描边 |
| `cn2-X1_tongyong_yingxiongkuang_01~06`（英雄卡）                 | 实心色块 + **大斜切角** + 六边形   |
| `StoryDialoguePanelAtlas/cn2-X1_yindao_duihuakuang_02`（对话框） | 紫色色块 + **硬投影**          |

`card` 就是照这三条拼的：**亮边 + 墨色细带（菱形纹）+ 四周切角 + 内侧柔影**。

🔴 **最外圈必须有亮边（`--frame-rim`）**：2026-10-20 第二版只有墨带，贴在八日礼包面板上  
**框直接消失**（用户原话「遇到黑色的时候不明显」）。实测面板底 `(17,17,25)`，墨带 `(18,16,24)`  
—— 同亮度，等于没画。游戏自己的槽位框正是这么解决的，剖面只有三档：

| 资源                          | 剖面（从外到内）                                                  |
| --------------------------- | --------------------------------------------------------- |
| `tongyong_daojukuang_01`    | `57,61,74`×3px → **`238,240,243`×5px** → 槽内 `119,133,158` |
| `tongyong_daojukuang_04`    | `59,26,75`×3px → **`222,182,255`×5px** → 槽内 `105,57,136`  |
| `tongyong_daojukuang_05/06` | `75,38,26`×3px → **`255,227,182`×5px** → 槽内               |

即「暗带 3px + 亮边 5px」。所以 `card` 现在的结构是 **1px 暗描边 → 亮边（外侧最亮、内侧压一档，  
模拟斜面受光）→ 1px 暗切 → 墨带 + 菱纹 → 3px 暗槽 → 画面**。判据：亮边跟面板底的亮度差 **≥100**。

🔴 这个判据要**按真机显示尺寸**验（`python3 scripts/image/preview_ingame.py <png> --cards 2x4`）：  
1080 宽的资源进游戏只有 567px，1:1 看着清楚的线缩完可能只剩 1px。

| `--frame-rim` | 用在哪                                                                  |
| ------------- | -------------------------------------------------------------------- |
| `warm`（默认）    | 暖金 `255,238,200`。圣诞/新年这类暖色主题                                         |
| `ivory`       | 银白 `244,246,250`。冷色/金属主题                                             |
| `violet`      | 紫白 `206,158,246`。跟紫色面板同色系，最"服帖"（首版 `230,196,255` 偏灰白，用户要求「紫变深一档」后压深） |
| `none`        | 不画亮边 —— 🔴 只在浅色底上用，深色面板上框会看不见                                        |

| 值          | 效果                                                 |
| ---------- | -------------------------------------------------- |
| `auto`（推荐） | `free` 自动套 `card`，`lock` 不套（lock 本来就有透明轮廓，不需要）     |
| `card`     | 强制套游戏卡框。**画面等比缩进框内**（cover 到内框，最多裁 1~2% 边），框压在画布边界 |
| `gold`     | 旧红金雕花框，仅兜底（游戏里没有这种语言，别再当默认）                        |
| `none`     | 不套                                                 |

框宽 = **短边** × `--frame-ratio`（`card` 默认 `0.022`，1080 宽 ≈ 24px；`gold` 默认 `0.041`）。  
🔴 用短边不用宽边：`856×2048` 这种长条按宽算会得到一条比例失衡的粗框。  
资源尺寸不变，框只画在画布内侧。

```bash
$PY scripts/image/restyle_pipeline.py postprocess --work "$W" --gen "$W/inbox/gen_web.png" \
    --alpha-mode keep --frame card --frame-rim warm      # free 构图的定稿姿势
```

🔴 做框的坑（都踩过）：

- **别用「错位硬投影」**：切角处矩形对不齐，会漏出一块黑三角，像磕坏了。改成沿切角多边形的  
  高斯柔影（`GaussianBlur(bw//3)` + `1.6` 次幂），画面才像「沉」进带里。
- **窄带里别塞两条线**：亮边之外再加一道内细线，会变成相框式双线（`--frame-hairline` 默认关）。
- **别用 `ImageDraw.line(width=…)` 画框**：line 以路径为中线、拐角用 round join，45° 切角会被磨圆，  
  相邻两条线还会互相盖住（亮边只剩半宽）。改用多边形掩膜 `_ring_paste`，切角始终是硬 45°。

---

## provider = `chatgpt_web`：用你自己的 ChatGPT 登录态出图

走的是**包月订阅额度**，不是 API（刻意不读 `OPENAI_API_KEY`）。链路：

```
gen_chatgpt_web.py
  ├─ 1. 连通性预检：先直连、再显式代理，都要做完 TLS 握手才算通（HTTP 200 不算）
  ├─ 2. 复制最小 profile（Cookies / Local State / Preferences）到临时目录
  ├─ 3. 起 Chrome（--remote-debugging-port，必须 --no-sandbox --disable-gpu）
  ├─ 4. 交给 chatgpt_web_driver.mjs（playwright-core connectOverCDP）
  │     上传参考图 → 填提示词 → 等「不在生成中 + 连续两轮尺寸稳定」→ 取 blob
  └─ 5. 无论成败都杀 Chrome、删临时 profile（🔴 里面是可解密的登录态）
```

参数：`--image` 参考图 / `--prompt-file` / `--out` / `--crop-height N`（超长条只喂顶部英雄带）/  
`--reuse-cdp`（复用已在跑的调试端口）/ `--check-only`（只验连通性与登录态）。

退出码 `3` = 环境问题（不可达 / 未登录 / 人机验证 / 额度用尽），job 里标黄不阻断。

### 额度用尽：**自动换号到 SunBrowser**（2026-10-21 起，不再是哑失败）

额度是**按账号**算的，所以「今天出完了」这件事一定会发生。以前的表现是：driver 傻等到
`--timeout`（实测 394 秒），再从页面尾部里嗅一句「⚠ 可能是额度用尽」，还归到 `rc=3` ——
Jenkins 上跟网络抖动长得一模一样，人得自己翻控制台才知道该换号。

现在分三层（2026-10-26 起中间多了一层「同号换通道」）：

| 层 | 行为 |
|---|---|
| driver | 每轮轮询都扫页面文案（中/英/日/韩）。命中「额度已用完 / 已达到 Free 套餐上限 / 无法调用图像生成工具 / reached your limit / limit will reset」等判据 → **立刻退出 `rc=4`**，并把站点原文 + 重置时间写进 `<out>.fail.json` |
| `gen_chatgpt_web.py` | 收到 `rc=4` → 先**同一个号换通道**（gemini，见下节），两条都空才走**换号链** |

### 额度用尽 ①：同一个号换通道 gemini（2026-10-26 起，**先于**换号）

用户定的顺序：**「gpt 额度用完了，就用 gemini 画；两个都画完了，再进下一个账号」**。
gemini 的额度按 **Google 账号**算，通常比 ChatGPT 那份大得多 —— 直接换号等于白扔这一份。

| 环节 | 实现 |
|---|---|
| 通道 | `gen_gemini.py`（+ `gemini_web_driver.mjs`），接口/退出码与 `gen_chatgpt_web.py` 完全一致 |
| 在哪台浏览器 | **同一个 CDP 端口**，绝不换浏览器（换浏览器 = 换号） |
| 参考图 | 默认沿用本次喂给 GPT 的那张（`--second-image`，超长条时是裁出的英雄带）⇒ i2i 锁构图 |
| 提示词 | 默认沿用 `--prompt-file`（`--second-prompt-file` 可单独给，xiuxian 那边会加构图锁前缀） |
| 本机 Chrome | 临时实例的端口在 `finally` 之前还活着 ⇒ 也在**同一台**上换通道；且「今天 GPT 空过」的 profile 下一张直接走 gemini，不再空跑一次 GPT |
| 记账 | 只有**两条通道都空**才 `mark_exhausted` 封号；GPT 单独空记在 `provider_state.json: gpt_spent["<kind>:<ident>"]` |
| 默认 | `--second-provider gemini`（**默认开**）。关：`--second-provider none` 或 `SECOND_PROVIDER=none` |

🔴 **默认开在库里**，不是「哪个 job 记得传参数才有」——否则新加的管线会悄悄漏掉 gemini 那份额度。
已接上的入口：`XZ-Art-Restyle`（`GEN_PROVIDER=auto`）、`TS-Art-Restyle`（`SECOND_PROVIDER`）、
`TS-Art-Translate`（`banner_translate.py --second-provider`）、`batch_restyle.py`（跟默认走）。
`TS-Art-Frame` / `TS-Art-BottomFade` 是纯确定性像素工序（不调 AI），不涉及。

退出码翻译（两套不一样，必须换）：`gen_gemini` 0/4/5/3 → 本模块 `RC_OK/RC_QUOTA/RC_REFUSED/RC_WARN`。

### 出图节奏闸门 + 会话保活心跳（2026-10-30 起，Google 账号被封之后加的）

2026-10-29 有一个 Google 号被停用。复盘 `_output/**/inbox/*.meta.json` 的 269 次出图时间戳：

| 指标 | 实测 | 现在（默认） |
|---|---|---|
| 相邻两张间隔中位数 | **46 秒** | ≥180 秒（±30% 抖动） |
| 间隔 < 60 秒占比 | **79%** | 0 |
| 单小时峰值 | **32 张**（10-27 13:00） | ≤10 张 |

所以加了两道东西，都在 `scripts/image/gen_pace.py`：

1. **节奏闸门 `gate()`** —— 按**账号**记账（不是按 job），flock 跨进程共享
   `_output/art_restyle/gen_pace.json`。判定与记账在同一把锁里完成 ⇒ 并行的几条构建会自己排队，
   「多开两条构建就能多画」这条捷径**自动失效**。要提吞吐只能加号（每个号各自限额）。
   - 最小间隔 / 每小时上限 / 每天上限 / 连画 N 张强制长休，四个维度都带环境变量与 Jenkins 参数。
   - 撞**日上限** ⇒ 把这个号在额度台账里标「明天再来」（`pace-day-cap`），换号链自然换下一个号。
     撞**小时上限**只等，不换号 —— 为几分钟的间隔去换号，等于把好号的额度摊薄。
2. **保活心跳 `maybe_heartbeat()`** —— 出图期间每 40 分钟（±15% 抖动）在**同一个浏览器**里
   发一条**纯文本**请求（`gen_gemini.py --text-ping`）。两个作用：
   - 会话保活：长时间「只建图、不说话」的会话更容易被判成自动化；
   - 早发现：登录态掉了 / 号被停了，在心跳这步就报出来，而不是等下一次出图白等 5 分钟。
   - 🔴 失败**不写台账封号**：很多 profile 只登录了 ChatGPT 没登录 Google，一次「没 Google」
     就把号封掉会把好号全封完。心跳只在本地记 `no_google`，24 小时内不再戳。
   - 🔴 例外是 `account-restricted`（落在 `myaccount.google.com/restrictions` 页，正文出现
     「账号已被停用」）：这是号没了，直接台账封 7 天 + 换号，别再试。

接入点是**唯一收口**，所以 `restyle_pipeline` / `batch_restyle` / `banner_translate` / `aso_art`
四条路都不需要单独改：

| 位置 | 做什么 |
|---|---|
| `gen_chatgpt_web.run_once()` | 浏览器连上之后、发提示词之前：先心跳（用这个端口），再过闸（`chatgpt` 账，默认 30s） |
| `gen_gemini.main()` | 同上，`gemini` 账（默认 180s）；`--account` 由 `gen_chatgpt_web` 透传，保证按**账号**而不是按端口记 |
| Jenkins | `GEN_PACE` / `GEN_MIN_GAP` / `GEN_MAX_PER_HOUR` / `GEN_MAX_PER_DAY` / `GEN_MAX_WAIT` / `HEARTBEAT_MIN` 六个节奏参数 + `QUOTA_FALLBACK_H` / `ALLOW_GAMBLE` 两个封锁参数，出图阶段 export 成 `TSG_*` |

```bash
# 现在各账号的节奏、下次什么时候能画
$PY scripts/image/gen_pace.py status
# 人工验证一次：跳过闸门（只这一次）
$PY scripts/image/gen_chatgpt_web.py ... --no-pace
# 全程关闸（不建议；等于回到被封那个节奏）
TSG_GEN_PACE=off $PY scripts/image/gen_gemini.py ...
# 清限速账（不动额度台账）
$PY scripts/image/gen_pace.py reset --all
```

⚠ 代价要认：`TS-Art-Restyle` 的单张从 ~5 分钟变成 >6 分钟（多等一个 3 分钟间隔），
`TS-Art-Translate` 的 batch 补图慢 3~4 倍，两个 job 的超时已从 75 → 120 / 150 分钟。
等超过 `GEN_MAX_WAIT`（默认 30 分钟）就把这一步标黄收工 —— 比硬等两小时撞 job 超时好，
下一轮自然接上（`--only` 或清单里删掉已完成的）。

### 额度封锁的判定口径（2026-10-30 二次收紧：判罚是「绕过用量限制」，不是「画得太快」）

被封的那个号（992694856@qq.com，AdsPower `kvrvx5h`）的判罚原文是
**「tried to override or circumvent abuse protections or safety filters」**，
Gemini 整项服务停用。复盘它的行为：87 个新对话只出 48 张图，撞上限后不停手、
换个对话再要一次 —— 在 Google 眼里就是「被拒绝后绕开入口」。所以封锁口径改成两层：

| 层 | 规则 | 落在哪 |
|---|---|---|
| 恢复时刻 | 站点给的时刻**优先**（`22:54まで` / `until 22:54` / `明日の 16:54` / `2 時間後` / `12 分後` 全认）；解析不到才按 `QUOTA_FALLBACK_H`（默认 **6 小时**）兜底 | `provider_ledger.parse_reset()` |
| 冷却期禁画 | 台账里 `blocked_until` 未到期的号**一律不新建对话**：不排队、不接已有端口、不硬试。全部号都被封 ⇒ 这一轮不出图 | `pick()` / 换号链 ① ② / `gen_gemini` 入口 |

三条别搞混（都踩过）：

- 🔴 **6 小时 ≠ 120 分钟**。`DEFAULT_BLOCK_HOURS=6` 是「额度用尽」的兜底；
  `DEFAULT_UNUSABLE_MINUTES=120` 是 rc=1/3（页面没出图 / 登录态可疑）的短冷却，
  2026-10-30 起 rc=3 也改成 6 小时 —— 「撞墙两小时后又是一条好汉」正是加压的来源。
- 🔴 **端口不是账号**。换号链 ① 手里只有 CDP 端口，旧实现把台账记成 `cdp:<端口>`，
  于是同一个号换个端口就成了「新号」，它自己的封锁标记全失效（封号那天就这样多画了 12 张）。
  现在用 `find_browser_cdp.adspower_uid_for_port()`（lsof 认 pid / `DevToolsActivePort`）
  归一成 `adspower:<user_id>`，限制速和封锁都按账号记。
- 🔴 **「全被封就赌一把」默认关掉了**。旧逻辑觉得「台账可能是错的」，代价是这个后门
  成了唯一的加压通道。要赌得人工开口：`--allow-gamble` / `ALLOW_GAMBLE=true` /
  `provider_ledger.py pick --allow-gamble`。

```bash
# 谁被封锁、封到几点（默认折叠历史垃圾行）
$PY scripts/image/provider_ledger.py list
# 连 8 月底那种 cdp:<端口> 老记录一起看
$PY scripts/image/provider_ledger.py list --all
# 确认台账记错了，硬试一次（只这一次，不写台账）
$PY scripts/image/gen_chatgpt_web.py ... --ignore-ledger
# 解封（人工核实恢复之后）
$PY scripts/image/provider_ledger.py reset --id kvrvx5h
```

⚠ **`list` 默认折叠两类垃圾行**（`--all` 展开）：`cdp:<端口>` 是归一前的旧口径；
`adspower:<纯数字>` 是端口被当成 uid 写进去的空壳（AdsPower uid 一定是字母数字混排）。
它们不参与选号，但会把「可并行绘制 N 路」顶高 —— 看着号很多，实际一个都开不起来。
仍被封 / 正被占用的旧条目**照旧显示**，免得「明明在封锁却看不见」。

⚠ 直接命令行 `--port 11451` 跑 `gen_gemini` 时没有账号标识，现在会**按端口反查**
是哪个 AdsPower 号再过封锁检查 —— 不然手动跑就成了绕过封锁的旁路。

### 换号链：已开着的 → 让 AdsPower 现开一个（2026-10-21 起）

用户的要求很直接：**「一个 SunBrowser 额度用尽的时候，调用 AdsPower 开另一个，继续绘制」**。
所以换号不再只是「接入已经开着的窗口」，而是自己会去开号：

| 段 | 做什么 | 起/停 |
|---|---|---|
| ① | 接入**已经开着**的另一个 SunBrowser（用户在 AdsPower 里手动开的号） | 只连不断，不启动也不关闭 |
| ② | 调 AdsPower 本地 API `api/v1/browser/start?user_id=…` **现开一个 profile** | 本进程起；失败立刻 `stop` 收掉，成功默认**留着**（下次跑直接走①，不用再等启动） |

- 号怎么排（`pick_profiles`）：`--adspower-profiles` 显式指定 > 上次成功的（台账
  `_output/art_restyle/provider_state.json`）> 今天没空过的 > chatgpt cookie 多的。
  「今天空过」只**降权不排除**——额度会中途重置，记录也可能是别的任务留下的。
- 🔴 **免费版调不了 `user/list`**（`This feature is only available in paid subscriptions`），
  但 `browser/active|start|stop` 免费可用 ⇒ profile 的 `user_id` 从本地缓存目录反推：
  `~/Library/Application Support/adspower_global/cwd_global/source/cache/<user_id>_<hash>/`。
  这个目录**只有被启动过**的 profile 才有，正好是候选集；挑之前数一遍该 profile 的 chatgpt
  cookie 条数（只读 sqlite、不解密），=0 的排最后，免得拉起一个还得手动登录的空号。
- 🔴 本地 API **按秒限流**，超了不是 HTTP 429，而是 `200 + {"code":-1,"msg":"Too many request..."}`
  ⇒ `api_get()` 既限速（1.15s/次）又按文案重试。别在循环里裸调 `curl`。
- 🔴 API 会自相矛盾：`active` 说 `Inactive`、`start` 说 `Profile does not exist`（实测 `kuh8m7e`，
  缓存目录还在、账号里已没有这个 profile）。这种 id 记进台账 `note=ads_missing` 排最后。
- 现开的号如果 `rc=3`（未登录 / 人机验证 / 非空对话）或 `rc=1`（没出图），**不原地折腾**，直接换下一个号；
  `rc=5`（模型拒画）与账号无关，立刻收工，别把剩下的号也白开一遍。
- 换号**不搬 cookie**：只换「连哪个浏览器」，登录态留在指纹浏览器里（Chrome 155 的分片 cookie 重建后不认，见红线 14）。
- `--reuse-cdp` = 只连不断：不启动、不关闭用户手上的窗口；driver 优先复用已开的 chatgpt 标签，不抢 tab。
- 全部号都空 / AdsPower 没开 / 预算用完，才回落到 `rc=3`，并打印站点原文（含「几点重置」）。
- 时间护栏：`--fallback-budget`（默认 960s）是整条链的总预算，用完即停；Jenkins 侧出图阶段给了 2400s。
- 关掉自动换号：`--no-auto-fallback`（Jenkins 里是 `ADSPOWER_FALLBACK=false`，只在「就是要验某个号的额度」时用）。
- 证据：`_output/.../inbox/gen_web.png.fail.json` 会被 job 复制成
  `artifacts/provider_fail.json`，构建页直接看得到，不用翻日志。

```bash
# 看有哪些号可换 / 手动开一个 / 收掉自己开的
$PY scripts/image/find_browser_cdp.py --profiles
$PY scripts/image/find_browser_cdp.py --launch k1hiv2p8
$PY scripts/image/find_browser_cdp.py --stop   k1hiv2p8

# 指定换号顺序（排最前，不受自动排序影响）
$PY scripts/image/gen_chatgpt_web.py --image ... --prompt-file ... --out ... \
    --adspower-profiles "k1hiv2p8,k12w7kmd" --adspower-max-profiles 3

# 手工复现/排查
$PY scripts/image/find_browser_cdp.py --json --all
$PY scripts/image/gen_chatgpt_web.py --image ... --prompt-file ... --out ... --reuse-cdp --port 64757
```


### 额度台账 `provider_ledger.py`（2026-10-21 起，换号的记忆）

换号链以前是「失忆」的：只记 `quota_date`（哪一天空过），而且**只降权不排除**。后果很具体 ——
2026-10-21 一轮实测：本机 Chrome 空 → k1hiv2p8 空 → k12w7kmd 打不开，三个号轮流「额度已用尽」，
**光等失败就烧掉 9 分钟**；而这三件事上一轮就知道。

现在额度这件事由 `scripts/image/provider_ledger.py` 管，台账落
`_output/art_restyle/quota_ledger.json`（跟钥匙缓存同目录，gitignore）：

| 旧口径 | 新口径 |
|---|---|
| `quota_date = 今天` | `blocked_until = 什么时候恢复`（绝对时间） |
| 只降权，照样排队试 | 没到恢复时间**直接不排队**（省掉每次 3~9 分钟的撞墙） |
| 无解封动作 | 出图成功即 `mark-ok` 解封并提到最前（钥匙缓存同时记住端口） |
| 站点只给一句话 | 解析成时间：`21 小时后` / `22 時間後` / `明日の 16:54` / `明天 08:30` / `about 16:54` |
| 站点什么都不给 | 兜底 `now + 6h`（标 `estimated`），刻意不用 24h 把一个其实已恢复的号堵一整天 |

🔴 **台账只能是优先级，不能是一票否决。** 同一天实测过反例：`provider_state.json` 里
`ktmrjhu` 明明标着 `quota_date=2026-10-21`，显式排进去却一次过。所以「**所有号都被封锁**」时
仍按**最快恢复**的那个赌一把（日志会写「台账可能已过期」），赌到就自动解封。

```bash
$PY scripts/image/provider_ledger.py list --live     # 台账 + AdsPower 实时状态（只读，6 个号约 7s）
$PY scripts/image/provider_ledger.py pick --max 3    # 只看候选顺序，不启动浏览器
$PY scripts/image/provider_ledger.py switch --max 1  # 真的接/开下一个号，打印 CDP_PORT
$PY scripts/image/provider_ledger.py mark-exhausted --id k1hiv2p8 --raw "上限将在 21 小时后重置"
$PY scripts/image/provider_ledger.py mark-ok --id ktmrjhu
$PY scripts/image/provider_ledger.py reset --id k1hiv2p8 | --all
$PY scripts/image/provider_ledger.py check           # 自检：解析器 5 例 + 排序/挑选 4 例
```

- 状态机：`unknown → ok`（出图成功）/ `exhausted`（额度空，带恢复时间）/
  `unusable`（未登录、验证码、页面没出图，短冷却 120 分钟）。
- `gen_chatgpt_web.py` 已内置：本机 Chrome 在封锁期时**直接从换号链起步**（不再先撞一次），
  换号链里封锁的号不进队列，成败都写回台账；`--ignore-ledger` 可临时关掉这套记忆。
- 手工改台账也行（就是 JSON），但改完跑一次 `check`，它会拦「状态是额度空却没写恢复时间」这种自相矛盾。
- Jenkins：**`TS-Art-Provider`**（`ACTION=status|pick|switch|reset|check`）——看台账、算顺序、真切号、
  解封、自检。`switch` 会把 `CDP_PORT=<端口>` 打进 `artifacts/NEXT_STEPS.md`，
  直接填进 `TS-Art-Restyle` 的同名参数即可。`TS-Art-Restyle` 新增 `IGNORE_LEDGER` 开关。

### 手工指定账号（自动换号之外）

自动换号只是「挑第一个能用上的」。要**指定**某个号，把端口写死给 job 的 `CDP_PORT` 即可：

```bash
$PY scripts/image/find_browser_cdp.py            # 反查 CDP 端口 → best port=64757
$PY scripts/image/gen_chatgpt_web.py --image ... --prompt-file ... --out ... \
    --crop-height 930 --reuse-cdp --port 64757
```

- 🔴 AdsPower 的 `--remote-debugging-port` **不在命令行里**（随机高位端口 bind），免费版还调不了
  `/api/v1/user/list` 拿 `debug_port`。所以 `find_browser_cdp.py` 只能从「进程 → lsof 监听端口 →
  逐个试 `/json/version`」反查；`pgrep -fl 9333` 这条思路在这里完全不成立。
- 指纹浏览器自带代理/指纹，**不要**再传 `--proxy`（会把它的网络链路覆盖掉）。
- Reuse 与自起 Chrome 的区别：自起 Chrome（默认）用你本机真实 profile 的副本，**换号就断**；
  reuse 用指纹浏览器里的登录态，**换号只需在 AdsPower 里开另一个 profile**。

实测（2026-10-20，free 计划）：856×930 英雄带 → 出图 1203×1308，`50x` / `Rebate` 文字与构图完整保真。

---

## 🔴 红线（踩过才写进来的）

1. **提示词不能写死文案。** 初版把 `8-DAY` / `Login Premium Gift` 写进主题预设，换第二张图（`50x Rebate`）  
   就会把上一张的字画上去。现在主题只描述风格（配色/服装/空区/装饰），文案由 `LAYOUT` 锁成  
   「逐字保持、只改材质」。
2. **整幅 cover 会横切超长条。** 856×2048 比例 0.42，模型只出 0.67 左右；cover 到 0.42 要横向砍掉 37%，  
   角色和文案全废。这类图必须走 `HERO_BAND`。
3. **`HERO_BAND` 的高度要量，不能猜。** 取「角色 + 文案 + 点阵带」那一块的实际底边：逐行算 `row_std`，  
   掉到 25 以下就是纯渐变区（那张卡在 y≈932）。我第一次按 540 取带，角色被切在 28% 处，白跑一张图。
4. **水印 ROI 别开太大。** 原 ROI 是 `x>0.72W, y>0.90H`，而那张图的标题尾巴正好落在 0.72W 之后，  
   被当成水印硬替换掉，字少了一半（"Rebate" → "Reb"）。实测水印本体在 `0.918~0.986 W / 0.933~0.981 H`，  
   收紧到 `0.88 / 0.92`，膨胀核 21 → 15。


5. **接缝处绝不能把「最后一行」往下广播。** 那一行是角色的身体，逐列颜色纵向拉长就是一条条竖光柱
   （这个坑踩了两次：一次在合成渐变、一次在接缝渐隐）。要渐隐就**原位逐行混合**。
6. **验收判据要抗渐变。** 「角落最亮 − 中位」在平滑渐变上天生 60+，会假报警；改用水印细笔画造成的
   `std`（清理前 45 → 清理后 9），阈值 22。
7. **接缝跳跃跟原图比，不跟绝对值比。** 这类底板本来就是直线切开的（卡体顶边），原图那一刀的
   亮度跳变只有 4；数值大小来自配色差异，只做记录项，>90 才值得人看。
8. **写回必须带闸门**：`publish` 会先读 `verify.json`，有硬失败就拒绝覆盖（`--force` 才能跳过）。
9. **`.meta` 一律不动。** 换图只换 PNG；meta 里的 `guid` / `textureType` / `spriteMode` / `packingTag`
   必须原样。曾出现过写回后被换成新 guid（`3b0b0d5e…` → `042a30ad…`），Unity 侧引用会全断。
10. **写回 ≠ 进包**：还要重打该资源所在 AssetBundle（`FrameTool.BuildGameAssetBundles`）。
11. **去水印只认「一行灰白字」，不能只认「亮」。** ChatGPT 出的圣诞图右下角是礼盒/拐杖糖/灯串，
    亮度 250，被当水印整片抹掉 11763px（ROI 的 78%），画被挖了个洞。现在判据是三条：
    亮（`lum > bg+10`）+ 灰（`max−min < 60`）+ **排成一行**（亮灰像素包围盒高 ≤ ROI 的 55%）。
    实测真水印 41%、装饰 100%，分得开。要关闭/强制用 `postprocess --watermark off|force`。
12. **生成图不是 `<img src="https://...">`，是 `blob:`。** ChatGPT 生成的图挂在
    `[data-testid="generated-image-gallery"]` 下，`alt` 是「已生成图像 N」；上传的参考图也是 blob，
    `alt` 是「用户附件」。**只能靠 alt 区分，按 src 域名过滤一张都匹配不到。**
    blob 只能在同一页面上下文里 `fetch` 后 base64 取出，签名 URL 直接 curl 会 403。
13. **`playwright-core` 是 CJS**：`await import()` 拿到的是 namespace，`chromium` 在 `.default` 上，
    直接解构会报 `Cannot read properties of undefined (reading 'connectOverCDP')`。
    另外 driver 连 `127.0.0.1` 必须设 `NO_PROXY`，否则被 `HTTP_PROXY` 拦成 502。
14. **不要把 cookie 导出来再 `addCookies` 重建登录态。** Chrome 155 的
    `__Secure-next-auth.session-token.0/.1` 分片重建后 Chromium 不认，页面照样是未登录营销页。
    唯一可行的是**整份 profile 交给 Chrome 自己读**（它自己解密）。
15. **生成图的 alt 文案跟着界面语言走。** 只写「已生成图像」时，换一个日文界面的号（SunBrowser）
    就永远认不出来：图早就画好了，driver 还在等，最后超时报错 —— 再重试一次就白烧一张额度。
    现在 `GEN_ALT` 覆盖中/英/日/韩/西/法/德/葡，并用 `[data-testid*="generated-image"]` 做结构兜底，
    同时用 `UPLOAD_ALT` 排除用户上传的参考图。
16. **图已经画好但没认出来时，别再发一遍。** `gen_chatgpt_web.py --grab-existing` 直接取当前对话里
    最新的那张生成图（取最后一张，不取最大——同一会话里可能有多张候选）。
17. **免费额度按账号算，换号不要搬 cookie。** 在 AdsPower 里开另一个已登录的 profile，用
    `find_browser_cdp.py` 反查端口 + `--reuse-cdp` 接上去：只连不断（不关用户窗口）、
    优先复用已开的 chatgpt 标签（不抢 tab）。AdsPower 的调试端口不在命令行里，只能
    「进程 → lsof → 试 `/json/version`」反查；免费版还调不了 `/api/v1/user/list`。
18. **`BODY_MODE=source` 只能保留「大尺度」明暗。** 原图透明区的 RGB 底下有烤进去的棋盘格、
    点阵底纹也有高频噪点，逐像素按亮度重映射会放大成蓝色花斑 / 对称竖带（同一天踩了两次）。
    现在先按 alpha 把 RGB 压回不透明区平均色，再降采样 1/40 拿大结构，最后只做 ±10% 调制：
    亮度是**调制**不是**色板**，幅度一大就会在卡体中间留一条横线（原卡体底部本来就有亮度台阶）。
19. **`free` 构图没有自动闸门。** 模型重排文案可能错字/缺字/被人物压住，`verify` 只量尺寸、alpha、
    水印残留。free 出图必须人眼看，看不过就 `restore` 回滚，别开着 `WRITE_BACK` 撒手。
20. **`free` 构图不能沿用源 alpha。** 源掩膜是按**老姿势**抠的；人物变高变宽后，掩膜就是一把剪刀，
    把新画的脸/头发/帽子整块切掉（登录底板实测：左脸 + 帽子没了）。用 `ALPHA_MODE=keep`，
    `postprocess` 在 free + source 时会自动降级并打日志。
21. **`ALPHA_MODE=keep` 之后必须套画框（`FRAME=auto`）。** 透明轮廓一取消，四边就是硬切的矩形，
    上半截和下半截卡体的接缝看着像没画完；一圈切角卡框把「裁切」变成「装裱」。
    框走 **inset**（画面等比缩进框内）：overlay 会压掉贴边的字（`8-DAY` 左边缘正好在 44px 内）。
22. **框必须在深色底上看得见。** 只画墨带（`18,16,24`）时，八日礼包面板底 `17,17,25` 跟它同亮度，
    框等于没画（「遇到黑色的时候不明显」）。最外圈要有亮边（`--frame-rim warm|ivory|violet`），
    亮度差 ≥100；这是游戏道具槽自己的做法（暗带 3px + 亮边 5px），不是加装饰。
23. **`BODY_MODE=source` 会把面板边框一起抹掉。** 卡体只保留 1/40 的大尺度明暗，底边金框
    （点金底板：y=1196~1231，`(255,210,45)`）会被当成噪点滤掉，成品变成「没有下边框」。
    现在 `source_body(keep_lines=True)` 把「高于行中位数 +35 的连续短带（≤60px）」按原色贴回。
    🔴 两个坑：① 必须用**未 alpha 合成**的 RGB 取行亮度（金边是半透明收边，合成后 169→92）；
    ② 不能用滑动窗口中位数——金边贴着画布底边，窗口被边缘 padding 撑满金边，中位数自己变成 168。

---

## 超长条底板：`HERO_BAND` + `BODY_MODE`

这类 UI 底板（如 856×2048）的构成是「英雄带（角色 + 文案 + 点阵带）+ 一大片给 UI 覆盖层用的空卡体」。

- `HERO_BAND=930` → 生成图按 `(宽, 930)` 做 cover（只横向裁一点，纵向一格不裁），贴顶；
- 下半截 `BODY_MODE=source` → **拿原资源下半截的「大尺度明暗」去调制主题渐变**：卡片暗角 / 卡体走向保留，
  棋盘格和点阵噪点被滤掉（见红线 18）。比凭空合成渐变稳得多（合成渐变要跟上半截的明暗节奏对齐，很难）。
- `BODY_MODE=synthetic` 是兜底（源快照缺失/尺寸不符）：接缝色（先横向平滑）→ 主题上色 → 主题下色。
- **结构亮线会单独贴回**（`--no-body-keep-lines` 可关）：`source` 模式先降采样 1/40 再放大，
  5~36px 的**底边金框 / 分割线**会被直接抹平——那正是面板的边框，丢了就是「框没画完」。
  现在的判据是「高于整段行亮度中位数 +35 的**连续短带（≤60px）**」，按原始（未 alpha 合成）
  RGB 取行亮度：金边是半透明收边，合成后 169→92，用合成值永远判不出来。
  实测点金底板底边金框 `(255,210,45)` 从「消失成 (19,62,47)」恢复为 `(219,187,45)`。
- `--blend N` 可把英雄带最后 N 行原位融进卡体；默认 0，保持原图那种直线切。

出图建议：`HERO_BAND` 模式**用 1:1 或接近带子比例的输入**（如 856×930 → `1024x1024`），
不要拿整张超长图去生成——模型会把角色放大填满画幅，底边反而更难接。

---

## 体积压缩（阶段 ⑤b，写回之前）

```text
$PY scripts/image/restyle_pipeline.py compress --work <工作目录> --variant auto   # 目标=原图体积
$PY scripts/image/restyle_pipeline.py compress --file <某个.png> --target-kb 700 --max-diff 8
```

**为什么必须有这一步**：换风格出的图是 32bit 全彩，而生成模型会往画面里塞雪花、灯串、光斑这类高频细节，
**同尺寸下颜色数能从 10 万涨到 34 万**——实测 `cn2-X1_shikongzhanchang_shangdianpeitu.png`
（1080×476）原图 685KB / 10.1 万色，换风格后 1196KB / 34.2 万色，尺寸一模一样，体积 1.75 倍。

档位（`auto` 按顺序试，取第一个够到目标的；每档都实测误差）：

| 档位 | 做法 | 本图实测 | 最大通道差 |
|---|---|---|---|
| 0 | PIL `optimize=True` 重编码（像素完全不变） | 1161 KB | 0 |
| 1 | 每通道降到 7bit（128 级） | 1111 KB | 1 |
| 2 | 6bit（64 级） | 947 KB | 2 |
| 3 | 5bit（32 级） | 749 KB | 4 |
| 4 | 4bit（16 级） | 563 KB | 8 |

- 🔴 **不要用 `Image.quantize` 做这件事**：RGBA 只支持 FASTOCTREE，256 色调色板会把发光/渐变打出明显色块
  （实测平均差 22，肉眼可见）。降位深是「均匀削精度」，对平涂 anime 几乎无损，对渐变只是轻微台阶。
- 误差只在**不透明区**算——透明区的 RGB 是垃圾值，拿它算误差没有意义。
- 每档超过 `COMPRESS_MAX_DIFF` 立刻停，停在上一档；压完反而更大就原样保留（不为了「压过」而变大）。
- 报告写 `<工作目录>/compress.json`，控制台打印「多少 KB → 多少 KB（-x%，档位，最大通道差）」。
- 🔴 **目标体积取「原图」体积（`prepare` 时记的 `source_bytes`），不取「资源当前体积」**。
  取当前体积会**棘轮**：第一次压到 4bit 写完，重跑一次就拿 4bit 的体积当目标，只能继续往更低位深压，越跑越糊。
  实测日常横幅：按当前体积只能到 4bit（266.9KB，误差 8）；按原图 389.6KB 就够 5bit（368.6KB，误差 4）。
- 🔴 **压缩必须保住源模式**：`compress_file` 曾经无条件 `.convert("RGBA")`，把 RGB 资源写成 RGBA，
  于是「压完 300KB 却比原图还多一个 alpha 通道」——Unity 的纹理导入/压缩口径跟着变，肉眼看不出来。

---

## 替换原图 / 回滚

```text
publish 顺序：验收闸门 → 原图搬进 ResBackpack/备份/<资源相对路径> → 校验哈希 → 覆盖资源 → 复核哈希 → 记台账
```

- **默认就写回**（2026-10-21 起 job 的 `WRITE_BACK` 默认 `true`）：图出完 → 验收 → 自动替换资源 + 原图入背包，
  不再需要人每次手勾。#7 那轮就是「图出好了、资源没换」，白看一遍对比图。只出图不改工程时才传 `false`。
- **变体按源图模式自动选**（`publish --variant auto`）：源 `RGB` → `opaque`，源 `RGBA` → `alpha`。
  🔴 别在 job 里写死：写死 `alpha` 会让 RGB 资源（本来没有透明区）在写回这步假红；写死 `opaque`
  又会让浮层的透明轮廓被整幅不透明盖住（799KB→1.6MB 的纹理口径变化也是这么来的）。
- 备份按**资源相对路径镜像**（`ResBackpack/备份/Assets/ManagedResources/.../x.png`），不同图集的同名文件不会互相覆盖；
- 台账 `ResBackpack/备份/_manifest.jsonl`：一行一次操作（时间 / 资源 / 主题 / 变体 / 备份路径 / 前后 sha256 / 尺寸 / 构建号）；
- 已经有一份更早的原图时**绝不覆盖它**：再换一次会另存 `x__20261020-173000_christmas.png`；
- 回滚：`restore --asset <资源>`（`--list` 看有哪些版本，`--version <时间戳>` 指定），回滚前会把当前文件先留档到
  `ResBackpack/备份/_replaced/`；
- **写回 ≠ 进包**：真机要重打该资源所在 AssetBundle（`FrameTool.BuildGameAssetBundles`）。job 会在写回后把
  备份路径与回滚命令打进控制台，但**不会**替你重打 AB。
- `ResBackpack/` 已在 `.gitignore`：体积大、纯二进制、远端 PUBLIC 仓库塞不下。

---

## 产出目录

```
_output/art_restyle/<资源名>/<主题>/
├── src/            source.png（改前快照）、source_alpha.png（alpha 参照）
├── inbox/          provider 出图投放处（band_input.png 是英雄带输入）
├── out/            <名>_<主题>_<W>x<H>.png（不透明）、…_alpha.png（可原位替换）、compare_before_after.jpg
├── gen_clean.png   去水印后的生成图（verify 量水印残留用这个，不是成品）
├── prompt.txt      本次定版的完整提示词
├── layout.txt      构图锁（可选）
├── state.json      阶段状态 / 参数 / published 记录（graph 与 summary 都读它）
└── verify.json     验收明细（problems / warns / checks）
```

---

## 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| 图上出现了上一张图的文案 | 提示词写死了文案 → 改 `LAYOUT` |
| 角色被切掉一块 | `HERO_BAND` 取小了；或生成图把角色放大填满画幅 → 量过底边再用 1:1 输入重出 |
| 接缝有明显竖条纹 | 用了「最后一行往下广播」的渐隐 → 改原位混合 |
| 验收报「水印无残留」失败但肉眼看不出 | 在成品上量的（卡体/渐变干扰）→ 确认 veriy 读的是 `gen_clean.png` |
| 生成图有水印残留 | ROI 收紧到 `0.88/0.92`；确认 `DILATE_PX=15` 且硬替换（羽化会让水印渗回来） |
| 写回后游戏里没变化 | 没重打 AssetBundle |
| Unity 里引用丢了 | `.meta` 的 `guid` 被换过 → `git checkout HEAD -- <png>.meta` |
| `chatgpt_web` 报「不可达」 | 出口侧封了 OpenAI（`cdn.oaistatic.com` 可能还通，别被误导）。换节点后重跑；本机下午通、上午不通是常态 |
| `chatgpt_web` 报「页面是未登录营销页」 | cookie 分片没被认 → 别自己重建 cookie，确认 `--profile` 指的是已登录的那个（本机是 `Profile 5`） |
| `chatgpt_web` 报「超时仍未拿到图」 | 先看是不是额度用尽（driver 会打印页面尾部文本）；free 计划额度很小 |
| 右下角装饰被抹掉一块 | 水印判据误判 → 确认用的是新版 `detect_mask`（亮+灰+排成一行三条件），必要时 `--watermark off` |
| driver 报 `connectOverCDP` 是 undefined | `playwright-core` 的 CJS 默认导出没取：`(await import(x)).default ?? ...` |
| **新图里出现上一张图的角色/道具**（如商店配图凭空多出巡逻图的球鞋） | 浏览器标签停在上一个对话，ChatGPT 把上一张参考图一起带进上下文。driver 现在出图前强制确认空对话（`/c/` 或已有消息就切新对话，切不动直接 rc=3 拒发）；**别用 `--grab-existing` 绕过**。防御性写法：`LAYOUT` 里明写「图里没有 X，不许画 X」 |
| **写回的 PNG 模式变了**（RGB 资源变成 RGBA） | `opaque` 变体内部一直是 RGBA，`postprocess` 和 `compress` 都曾直接存出去。现在两处都按 `state.source_mode` 还原：源 RGB 就存 RGB。查 `published.json` 的 `mode` 字段，RGB 资源出现 `RGBA` 就是踩了这个 |
| **重跑一次压缩后图更糊了** | 压缩目标取了「资源当前体积」（已经是压过的），形成棘轮。现在取 `source_bytes`（原图体积）；老 work 目录手动补这个字段 |

## 边缘去污（所有绘制 job 共用一份）

模型出的图在主体轮廓外必然留一圈脏边：白色抗锯齿 + 纯红/纯黄的细弧。二值掩码正好压在这圈上
⇒ 贴回游戏就是「人物边缘一圈杂色」。实现在 `scripts/image/edge_polish.py`，
**不要在任何 job 里另抄一份**（抄一份 = 同一个 bug 要修两次，2026-10-28 就是这么踩的）。

- 接线点：`restyle_pipeline.py postprocess --fit subject` 之后、套框/底边虚化之前。
  `TS-Art-Restyle`、`XZ-Art-Restyle`（仙境图集帧）、`batch_restyle` 全部走这里。
- 口径版本：`edge_polish.EDGE_VER` → 写进 `state.json` 的 `edge_ver/edge_note`，
  以及写回台账 `_manifest.jsonl` 的 `edge_ver/fit_mode`。改判据必须 +1。
- 验收：`verify` 多一条软项「边缘无纯色杂弧」（`edge_polish.fringe_count`，>40 标黄）。
- 「已经交付过的就别再动」：`batch_restyle` 现在会跳过「有 published 记录且资源哈希没变」的组合，
  要重做必须 `--force`（`edge_ver` 只写进说明，**不作为**自动重做的理由 —— 老记录没有这一列，
  拿它当条件等于第一次跑就把所有历史资源重画一遍）。账本缺这一环时，重跑一份清单会把
  所有已交付资源再出一次图再覆盖一次。
- 体检单张：`python3 scripts/image/edge_polish.py out/xxx_alpha.png --alpha out/xxx_subject.png`
