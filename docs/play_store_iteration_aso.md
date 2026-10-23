# 店面迭代（ASO）—— Jenkins `TS-Store-Iteration`

> 建立：2026-10-23
> 配套：`google_play_upload_setup.md`（凭证与发版 API）、`android_release_runbook.md`（出包）、
> `.workbuddy/skills/play-aab-release/SKILL.md`（打包发版）
> 操作卡：**`.workbuddy/skills/aso-store-iteration/SKILL.md`**（简明版，含红线与 Jenkins 参数）
> 本文件管的是**商店页本身**：文案、截图、置顶图、A/B。

---

## 0. 先说清楚：哪些能自动，哪些不能

2026-10-23 逐条核对官方 API 文档后的结论，别按印象做事：

| 动作 | 能不能自动 | 手段 |
|---|---|---|
| 改标题/短描述/长描述/视频 | ✅ 能 | `edits.listings.update`（`scripts/aso/aso_play.py push`） |
| 传截图 / 置顶图 / 图标 | ✅ 能 | `edits.images.upload`（imageType = `phoneScreenshots` / `featureGraphic` / `icon` …） |
| 读线上现有文案与图片 | ✅ 能 | `edits.listings.get` / `edits.images.list` |
| **建商店页 A/B 实验、看实验结论** | ❌ **不能** | 没有公开 API，只能在 Console 网页做 |
| **点「送审 / 开始发布」** | ⚠️ 会**被动**触发 | 本包是「提交即自动送审」模式：`edits.commit` 一成功就进审核队列，**不能**带 `changesNotSentForReview`（带了 400，见下） |
| 回复评论、应用内容问卷、测试人员名单 | ❌ 不能 | 网页 |

⇒ 所以本 job 的定位是：**把 90% 的准备与巡检自动化，把必须人点的那几下（送审 / 建实验 / 看结论）留给人**，
并且每次构建都告诉你「现在轮到你点哪一下」。

### 🔴 送审模式实测（2026-10-23 更正）

早先文档写「托管式发布，API 无权送审」——**实测反了**。第一次真传图时 `commit` 直接 400：

```
Changes are sent for review automatically. The query parameter changesNotSentForReview must not be set.
```

含义：`com.warera.timespace` 是**自动送审**模式，`edits.commit` 一成功，改动**立刻进审核队列**，
没有「先存草稿、人工再点送审」这个中间态。所以：

- `aso_play.py` 默认仍带 `changesNotSentForReview=True`（对托管式发布的包才正确），
  对本包会被 400 打回，**此时线上没有任何变化**（edit 自动作废，可用 sha1 对比确认）。
- 要真提交必须显式加 `--auto-review`：一提交就进审核 ⇒ **上线类操作，先问用户**。
- 上传前先 `aso_play.py list` 导出线上 sha1，对比 `derived/<变体>/<locale>/feature_01.png`
  的本地 sha1 —— 一致才算生效，别只看日志「已传 1 张」（那只是 upload，不含 commit）。

---

## 1. 一键入口

Jenkins → `TS-Store-Iteration`（视图「时空美少女 · 全流程」）

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1
P=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python

# 只读体检（默认）：文案闸门 + 素材派生 + 规格体检 + 验收页 + A/B 登记
#   → 不碰 Play，只打印 diff
（在 Jenkins 里点构建，MODE 保持 dry-run）

# 要换置顶图为「左右角色 + 实机画面框」拼装版：额外勾 FUSION
#   底图已出过 ⇒ 不勾 FUSION_RENDER（零额度，只重排版面 + 压字）
#   要换角色/重画 ⇒ 勾 FUSION_RENDER，并填 FUSION_PAIR（如 04,06）

# 本地单独跑某一段
$P scripts/aso/aso_play.py list                       # 导出线上四语现状
$P scripts/aso/aso_lint.py --all                      # 文案闸门
$P scripts/aso/aso_assets.py build --variant B        # 派生竖版截图 + 置顶图
$P scripts/aso/aso_assets.py check --variant B        # Play 规格体检
$P scripts/aso/aso_experiment.py status               # 实验台账
```

### 参数

| 参数 | 说明 |
|---|---|
| `MODE` | `dry-run（只读体检）` / `text（只推文案）` / `images（只换图）` / `both` / `art（只出美术需求单）` |
| `VARIANT` | 变体目录名，默认 `B` |
| `BASELINE` | 对照变体，默认 `A`（**A 是线上现状快照，别改**） |
| `LOCALES` | `en,ja,zh-CN,zh-TW` 任意子集；留空=四语全做 |
| `FIT` | `cover`（铺满裁切，默认）/ `pad`（整图装入 + 模糊补边） |
| `ALLOW_WRITE` | 🔴 只有勾上才写 Play。不勾=只打印 diff |
| `TRIGGER_ART` | 勾上则按缺图清单触发 `TS-Art-Restyle` |
| `ART_THEME` | `cyber`（保持赛博原味）/ 节日题材 |
| `FUSION` | 置顶图改走「左右角色 + 实机画面框」拼装版（§5.2），默认关 |
| `FUSION_PAIR` | 拼装底图的两位英雄 id，`01,02` = 左 01 / 右 02 |
| `FUSION_RENDER` | 🔴 重新按特征卡出双人底图（耗额度、约 90 秒/张、必须串行）。只重排版面时不要勾 |
| `EXP_DAYS` | A/B 窗口天数，默认 14 |

**三道闸门**：`ALLOW_WRITE`（允许写）→ `--yes`（job 内自动带）→ 上游 `MODE`（决定推哪些字段）。
默认路径永远是只读。

---

## 2. 目录约定

```
data_aso/
  variants/
    A/                 ← 线上现状快照（baseline，禁止改动）
      meta.json        ← label / role / hypothesis / variables
      en-US.json  ja-JP.json  zh-CN.json  zh-TW.json
    B/                 ← 处理组
  assets/shots.json    ← 截图清单：源图 + 裁切比例 + 四语卖点文案
  experiments/         ← 实验台账（进版本库）
  derived/<变体>/<语言>/  ← 构建产物（gitignore）
  online/<时间戳>/        ← 线上导出（gitignore）
  reports/               ← 闸门 JSON、美术需求单（gitignore）
```

**加一个新变体** = 建 `data_aso/variants/C/` + 写 `meta.json` + 四语 json，然后
`MODE=dry-run VARIANT=C` 跑一遍看闸门。不需要改代码。

文案字段只有四个：`title` / `shortDescription` / `fullDescription` / `video`。
Play 硬上限：**标题 30、短描述 80、长描述 4000**（按 Unicode 字符计）。

---

## 3. 文案闸门在拦什么

`aso_lint.py` 的判定：

- **红（阻断）**：超上限、字段为空、长描述 < 200 字、日文里出现简体专用字、繁体里出现简体形
- **黄（提醒）**：标题顶格（`30/30` 之后任何加字都要先减字）、连续空格、首尾空白、
  夸大措辞（`100%` / `No.1` / `唯一` / `保证中奖` 等，Play 虚假陈述条款常见踩点）、
  与基线无差异（这个语言参与实验没意义）

> 简繁/日文检测是**字符对照表**，不是词典。它只判「简体专用形出现在日文/繁体里」这种硬串味，
> 不判语感。命中要人看一眼再改。
> 🔴 上一版把 `体/数/点/用/特/值` 也塞进简体表，结果日文正文（体・数・点 全是日文正字）红成一片，
> 现在用 `SIMPLIFIED_MAP` 显式映射，并且日文/繁体**用两张不同的表**。

---

## 4. 素材：为什么是「派生 + 卡片版式」

`aso_assets.py build` 做的事：裁掉顶部状态栏与底部聊天/按钮 → 放进圆角霓虹卡片 →
底部独立文案区（小标 / 两行主文案 / 竖色条）。

三条设计决定，全是踩出来的：

1. **不再「截图铺满 + 底部垫黑条」**。源图 55%~62% 是按钮行、65% 以下是世界聊天，
   怎么裁都会切到 UI；切完再把下半截刷成近黑，看着就是「图被裁断了垫块黑纸」。
   换成卡片后，切边变成**卡片边界**（本来就该结束），底色由我们自己画，四张才像一套。
2. **顶部也要裁**（`crop_top` 0.05~0.06）。只裁底部时，卡片顶边正好切进状态栏，
   露出半截图标 —— 和底边切到按钮是同一个毛病。
3. **`crop_bottom` 是「卡片底边落在哪」**，不是「裁掉多少聊天」。落在战斗画面里
   （0.40~0.44）最好看；落在按钮行中间就会露半个按钮。

踩坑记录（都写进代码注释了）：

- 🔴 把 RGB 图带 L 遮罩 `paste` 进 RGBA 画布，PIL 会把**目标 alpha 覆写成遮罩值**，
  之后 `alpha_composite` 按半透明去解 ⇒ 接缝被算成死黑。全程走 RGB + `Image.composite`。
- 🔴 中文别用 `PingFang.ttc`（本机不存在）；`STHeiti Medium.ttc` 的 **0 号面是繁体**，
  简中要用 1 号面，繁中用 0 号面。面序号不写就等于随机拿字重。
- 🔴 全角标点步进 1em 但墨迹只有 11px（97px 字号下），不压就是「网格 ， 站位」散开；
  压到 0.5em 又会让标点贴住下一个字，**0.68em 是实测可用的值**。

产物与体检：
- 手机截图 `1080×1920`（9:16），Play 规定最短边 ≥320、最长边 ≤3840、长宽比 ≤2:1、单张 ≤8MB
- 置顶图 `1024×500`
- `preview.html` 四语并排的人眼验收页（job 会自动归档到证据目录）

🔴 **张数上限与 `--shots`**：Play 硬上限是 `phoneScreenshots` **8 张 / 语**、`featureGraphic` **1 张**。
派生目录里的候选常多于上限（`shots.json` 8 条会派生出 9 张 `shot_*.png`），全推会 400。
上传时用白名单显式挑：

    $P scripts/aso/aso_play.py push --variant B --images-only \
        --image-types phoneScreenshots --shots 0,1,2,5 --allow-write --yes --auto-review

`--shots` 只对 `phoneScreenshots` 生效；不写就走「超上限只传前 N 张」的兜底并在日志里告警。
`deleteall + upload` 是替换语义 ⇒ 推几张线上就剩几张，旧图不会残留。

**源图分辨率是要盯的**：现有竖版源图只有 597～720px 宽，进卡片放大 1.5~1.7×，
`build` 会把超过 1.6× 的逐条标黄，并对放大图补一点 unsharp（`radius=1.5 / 62%`）。
真正的解法是真机/模拟器直接出 1080×1920 截图。

**实测锐度分层（10-24，决定上哪几张）**：

| 文件 | 卖点 | 源图放大 | 是否可上 |
|---|---|---|---|
| `shot_01` | 7x7 网格站桩 | 1.5× | ✅ 最锐 |
| `shot_05` | 霓虹主城 | 1.1× | ✅ 最锐 |
| `shot_00` | 竖屏赛博战斗 | 1.8× | ✅ 可用 |
| `shot_02` | BOSS 战 | 1.8× | ✅ 可用 |
| `shot_03` / `04` | 前后排 / 9 人同屏 | 2.6× | ⚠️ 偏糊 |
| `shot_06` / `07` / `08` | 双排交火 / 建公会 / 世界地图 | 3.2× | ❌ 糊，别上 |

首轮上线的就是 `0,1,2,5` 这 4 张（四语 sha1 全核对过）。


---

## 5. 重画：调用 `TS-Art-Restyle`（2026-10-23 实跑校准）

先说结论：**AI 只画画面，字一律不交给它。** 中/日/繁的字形模型十有八九画错（缺笔画、错字、
字距乱），而且四个语言要同一套排版才像一家人。所以流程是「出无字底图 → 本地用真字体压标题」，
换文案不用重新出图，改一个字也不烧额度。

```bash
# 1) 造构图种子（管线的输出尺寸 = 种子尺寸，所以竖版首图的种子就得是 1080×1920）
$P scripts/aso/aso_art.py seed --kind hero    --locales en-US
$P scripts/aso/aso_art.py seed --kind feature --locales zh-TW

# 2) 触发（表单字段；LAYOUT 是构图锁，OUTFIT 锁服装，WRITE_BACK 写死 false）
$P scripts/aso/aso_art.py trigger \
   --asset "data_aso/assets/seeds/hero_en-US_1080x1920.png" \
   --theme cyber --provider chatgpt_web --composition design --watermark off \
   --layout "$(cat /tmp/asoart/layout_hero2.txt)" --outfit "<逐件点名保留原服装>"
# 实测：90 秒出图，比文档里写的 30～75 分钟快得多（额度够时）

# 3) 管线给 design 构图自动套「游戏卡框」，商店图不要框 ⇒ 复用同一张生成图重跑后处理
$P scripts/image/restyle_pipeline.py postprocess \
   --work _output/art_restyle/<资源名>/cyber_design \
   --gen  _output/art_restyle/<资源名>/cyber_design/inbox/gen_web.png \
   --frame none --alpha-mode keep --watermark off

# 4) 压本地化标题（改文案只跑这一步）
$P scripts/aso/aso_assets.py headline --art <无字底图> --locale ja-JP --kind hero \
   --out data_aso/assets/gen/hero_ja-JP.png
```

要点与坑：
- `ASSET` 是**相对工程根**的路径，`时空美少女物料/**`、`data_aso/assets/seeds/**` 都能直接喂
- 🔴 **LAYOUT 里必须写死「NO text anywhere + 底部 N% 留空」**，否则模型会自己编标题，
  或者把游戏面板放到最底部、把要压标题的位置占掉（第一版就是这么废的）
- 🔴 主题预设的 `outfit` 句会把她身上的蓝白铠甲换成黑色机能服 ⇒ 必须用 `OUTFIT` 逐件点名保留
- `COMPOSITION=design` 时 `ALPHA_MODE=source` 会被自动改成 `keep`（源掩膜按老构图抠的，会裁掉新人物）
- 首图落在 `data_aso/assets/gen/hero.png`（或 `hero_<locale>.png` 做语言专属）后，
  `aso_assets.py build` 会自动生成 `shot_00.png` 并排在**第一张**
- 置顶图三语直接用 `时空美少女物料/新版本宣传图/*_1024/`（专业排版，比早期 `1024*500` 拼贴强得多），
  只有繁中是重画 + 压字（`data_aso/assets/gen/feature_zh-TW.png`）
- 本 job **不等待**换皮完成；下一轮 `build` 会把新底图自动带上

### 5.1 英雄立绘：只抽特征，不拿立绘当种子（2026-10-23 定版）

`restyle` 本质是「照着种子改」，provider 一定会把 `ASSET` 当参考图上传。拿英雄立绘当种子
⇒ 姿势/服装/发色全被锁死，实测 05 被画成白发机甲、06 被画成金发，等于换了个人；同一批 5 张
构图还都是一个模子。

正确链路：**立绘只贡献特征，画面 100% 由文字重画**。

```bash
# 1) 立绘 → 量化配色（发色/主色/点缀），人工再补语义特征卡
$P scripts/aso/hero_features.py extract --art Assets/ManagedResources/Texture/Jingtailihui/cn2-Jingtailihui_fulade.png
#    语义写进 data_aso/assets/hero_specs.json：只写「她是什么」，不写原图的姿势/镜头

# 2) 造空舞台板：只有画布 1080×1920、地平线、光池、底部 24% 留空，**不含人物**
$P scripts/aso/hero_keyart.py plates --ids 01,02,03,05,06

# 3) 出图：提示词整段走 job 的 PROMPT_OVERRIDE，种子只当画布
$P scripts/aso/hero_keyart.py render --ids 01 --dry-run      # 先看提示词
$P scripts/aso/hero_keyart.py render --ids 01 02 03 04 05 06 --wait

# 4) 成品 → data_aso/assets/gen/herocard_<id>.png → 压四语文案 → 验收页
$P scripts/aso/hero_keyart.py collect
$P scripts/aso/aso_assets.py heroes --variant B
$P scripts/aso/hero_page.py --variant B      # → data_aso/derived/B/heroes.html
$P scripts/aso/aso_assets.py check --variant B
```

实测：单张 ~90 秒（#39~#44）。六张全出、四语 24 张卡、体检 44 张图全绿。
`hero_page.py` 是单独的验收页（一英雄一行、四语并排 + 灯箱），**不要塞进 preview.html**——
那张是商店截图的验收台，混进 24 张 9:16 会把它的节奏打散。

要点与坑：
- 🔴 **必须 `--frame none`**：`COMPOSITION=design` 下 job 的 `FRAME=auto` 会套游戏卡框，
  商店图不要框（第一版就带着金框出图）
- 🔴 **必须 `--wait` 逐张跑**：本 job 的出图阶段独占「本机 Chrome 登录态 + `inbox/`」，
  并发会串图（#28~#32 五个并发构建里 02/03 的 `gen_web.png` 落在同一 md5）。Jenkins 2.568
  会**静默丢弃** `DisableConcurrentBuildsJobProperty`，`options{disableConcurrentBuilds()}`
  也拦不住同时入队 ⇒ 串行只能在调用侧保证
- 🔴 提示词里必须写死「输入是**空舞台板**，不含人物/道具/文字，只锁画布与地平线」，
  否则模型会把它当参考图照着改，白折腾
- 提示词里必须带 `NO lettering`：字一律本地压（`aso_assets.py heroes`），模型画中/日/繁必错
- 成品落 `_output/art_restyle/stage_<id>/cyber_design/out/*.png`，`collect` 拷到
  `data_aso/assets/gen/herocard_<id>.png` 后，`aso_assets.py heroes` 会自动走「铺满成品」分支
  （没有成品时退回「透明立绘 + 品牌底图」的旧版式，两版并排一眼就露馅 ⇒ 六张要一起出）
- 🔴 **底部接缝**：模型会把「留给文案的底带」直接画成纯黑，接缝处一行亮度差十几级，
  缩略图里像一条被裁断的黑条。`compose_hero` 现在走 `_soft_bottom()`——**先渐进高斯糊开、
  再叠长渐变 scrim 压深**；只压深不模糊等于把硬边原样留着（第一版就是这个毛病）
- 卡片高度：脚底在 74%、文案块从 77.5% 起，两者只差 3.5% ⇒ 舞台描述里「全身入画」
  不能省，否则武器/裙摆会压到字上

### 5.2 置顶图：拼装式（左右角色 + 实机画面框）（2026-10-23 定版）

Play 的 `featureGraphic` 是 1024×500 横版，定版结构是**拼装**：左右各一个角色、中间一块
圆角实机画面框、底部居中大标题。三层各用最可靠的手段，不让任何一层交给「AI 一次画完整张」：

| 层 | 来源 | 为什么必须是它 |
|---|---|---|
| 左右角色 | `hero_keyart.py duo` → `TS-Art-Restyle` 按**特征卡**重绘 | 不拿立绘当参考图，画风/光源才能和背景统一 |
| 中间画面 | 真实机截图（`shots.json` 的 `band` 取战斗横条） | 「这是真游戏」只能靠真图，AI 画的游戏画面一眼假 |
| 文字 | 本地真字体（`aso_fusion.py`） | 模型画中/日/繁必错；改文案不该重出图 |

```bash
# 1) 出双人底图 1920×1080（左=前一个 id、右=后一个 id）——耗额度，实测 ~90 秒
$P scripts/aso/hero_keyart.py duo --pair 01,02 --theme cyber --dry-run   # 先看提示词
$P scripts/aso/hero_keyart.py duo --pair 01,02 --theme cyber --wait
#   → data_aso/assets/gen/fusion/bg_0102.png

# 2) 拼装 + 压四语标题（零额度，<1 秒/张）
$P scripts/aso/aso_fusion.py build --layout duo --variant B \
   --locales en-US,ja-JP,zh-CN,zh-TW --promote

# 3) 复检规格（置顶图必须 1024×500）
$P scripts/aso/aso_assets.py check --variant B
```

**`--promote` 是关键一步**：成品写成 `derived/B/<语言>/feature_01.png`——就是 `aso_assets build`
用的那个文件名，同时把该目录下别的 `feature_*` 清掉、把真实 size/bytes/sha1 刷回 `index.json`。
于是 `preview.html` / `index.json` / `aso_play.py push` 全都不用改，也不会出现两张置顶图
（Play 的 featureGraphic 只收一张，目录里留两张会在推送时第二次上传 400）。
`aso_assets.py preview` 可在换图后单独重画验收页（不动图，只刷数字）。

**为什么不需要抠图**：管线只出整幅不透明图，chroma key 抠头发会发毛。改法是让底图中段
**60% 被要求留空**，这块随后被画面框整块盖住 ⇒「角色由管线重绘」与「中间是真游戏画面」
同时成立，alpha 通道完全不需要。

要点与坑：

- 🔴 **不能拿工程立绘直接贴**（`Assets/ManagedResources/Texture/Jingtailihui/` 里 1024~2048 自带
  alpha 的图）。立绘与背景不同光源、不同画风，贴上去一眼剪贴画 —— 2026-10-23 用户当场否决。
  所以 `--promote` 在缺底图时**直接报错**，不允许退回立绘兜底（`heroes` 分支只服务本地预览）。
- 🔴 提示词要写死「两人都被**左右边缘裁切**、只露头肩胸、中间 60% 与底部 26% 留空」，
  否则模型会把两个完整人物摆在正中，画面框没地方放。
- 🔴 框内取景 `band` 取 `[0.40,0.80]`：取到 0.90 会把截图底部的中文「禁止」按钮带出来，
  直接挂到英文商店页上。
- 🔴 双人底图同样**必须 `--wait`**：与单人 `render` 共用本机 Chrome 登录态与 `inbox/`，并发必串图。
- 换角色只改一行：`--pair 04,06` + 把 `fusion.json` 的 `bg` 指过去；`aso_fusion.py list` 看当前版面。
- 版面参数全在 `data_aso/assets/fusion.json`（`frame` / `screen` / `title` / `copy`），改构图不改代码。
- 🔴 **画面框要小**：`frame` 从 `[0.2,0.022,0.8,0.7]`（614×339）两次缩到 `[0.285,0.036,0.715,0.522]`
  （440×243），用户两次要求「再小一点」（10-23）。原因是**角色才是主体，画面框只当「游戏窗口」点缀**；
  框占满中线会让整张图像「一张截图框了边框」。框比例固定 1.81（= 竖版截图 crop 后的宽高比），
  改比例会让 `band` 取景跟着偏。副作用：框内血条数字在 1024 宽下变成小字，只在缩略图里看气质。
- Jenkins 侧：`FUSION=true` 走 `③b 置顶图拼装（双人重绘）` 阶段；`FUSION_RENDER=true` 才会重出底图，
  否则只重排版面 + 压字（零额度）。

---

### 5.3 10 组角色组合候选（2026-10-23）

置顶图真正难的不是排版，是**选哪两位角色**。所以把「选人」独立成一轮：同一版面、同一套
四语文案，只换底图，铺 10 组让眼睛挑。角色组合写在 `data_aso/assets/fusion_pairs.json`：

```json
{"tag":"0715","left":"07","right":"15","note":"东方蛇身创世神 × 赛博机车骑士：神话 vs 未来",
 "screen":{"shot":2,"band":[0.30,0.75],"focus":0.5,"focus_x":0.5,"zoom":1.0}}
```

`tag` 必须是 `left+right` 拼起来的四位数——`cmd_duo` 的工作目录与底图名都按这个规则生成
（`bg_0715.png` / `stage_duo_0715/`）。改 tag 会导致底图收不到。

`screen` 决定**该组画面框里放哪一段实机画面**（见下面「10 组画面必须各不相同」）。

```bash
# 1) 串行出全部 10 组底图（断点续跑：已存在的 bg_<tag>.png 默认跳过）
$P scripts/aso/hero_keyart.py batch
$P scripts/aso/hero_keyart.py batch --only 0715,1217     # 只跑几组
$P scripts/aso/hero_keyart.py batch --force --only 1217  # 重画某一组

# 2) 每组单独拼装：--pair 一次带出底图 + 框内取景 + 输出后缀，不用手写 --bg/--tag
for t in $(jq -r '.pairs[].tag' data_aso/assets/fusion_pairs.json); do
  $P scripts/aso/aso_fusion.py build --layout duo --pair $t \
     --locales en-US,ja-JP,zh-CN,zh-TW --out data_aso/derived/B/fusion10
done

# 3) 验收页：10 组一页平铺，每组四语并排，点图看原图
$P scripts/aso/fusion_page.py --variant B
#   → data_aso/derived/B/fusion10.html
```

#### 10 组画面必须各不相同（2026-10-23 用户指出）

第一版 10 组画面框里全是 `shots.json` 第 3 张、同一段取景 ⇒ 缩略图上「同一个画面重复十遍」，
一眼批量感。根因是 `fusion.json` 的 `screen.shot` 是一个全局值，10 组共用。

现在 `fusion_pairs.json` 每组带一个 `screen`，`build` 逐字段合并（只覆盖 shot/band/zoom，
描边色与圆角仍继承版面默认）：

| 字段 | 作用 | 取值经验 |
|---|---|---|
| `shot` | `shots.json` 第几张截图 | 只有 3 张干净合规的（0=蓝紫工厂 7x7、1=红 BOSS 关、2=青蓝机械关） |
| `band` | 切掉按钮行后，再取哪一段纵向区间 | 起点 **0.05~0.45**、高度 0.45~0.50；🔴 上限别超 0.90，再往下就是中文按钮行 |
| `zoom` | 在 cover 基础上再推近 | 1.0=全景、1.2~1.4=中近景；>1.5 会切头 |
| `focus_x` | 水平取景重心 | 默认 0.5；配合 zoom 用，单独用意义不大 |
| `warm` | 框内色温增益 `[r,g,b]` | 缺省 `[1.04,0.99,0.94]`（把青蓝截图拉回暖色系）。🔴 雪地/城市这类中性偏冷画面必须给 `[1.0,1.0,1.0]`，否则整片发红 —— 10-23 用户给的冬季城市关踩到 |

🔴 **这是「3 场战斗的 10 种取景」，不是 10 场不同战斗。** 干净真机截图只有 3 张，要做到
10 场各不同，必须补截图（要英文/日文包真机重截，中文包会带中文 UI 上商店页）。

选窗口的两条硬经验：

- **能传达玩法的是俯视网格 + 血条数字 + 多个小人**（shot0 b0.30、shot2 b0.30/0.45）。
  只截 BOSS 大特写（shot1 b0.05）画面上看不出是回合制战术，像动画过场——只留 1 组当冲击。
- **窗口别往上抬过头**：`band` 起点 0.10~0.15 会吃到工厂空景，缩略后上半幅是空的。
  shot0/shot2 的上空出现在 band<0.25，务必从 0.30 起。

校验方式（不靠眼看）：同组四语「画面框区域」（y 12~349）像素差必须为 0；跨组两两最小平均
像素差要 >50，否则说明有两组取景撞了。

要点：

- 🔴 **`batch` 必须串行**（内部逐组 `--wait`）。同机 Chrome 登录态与 `inbox/` 不隔离，两路并发必串图。
- 🔴 **候选目录不是线上目录**。10 组写在 `derived/B/fusion10/`，**不要 `--promote`**：
  promote 会把 `feature_01.png` 覆盖成一张并清掉别的 `feature_*`，10 组进去只剩最后一组。
  选定某一组后，再对那一组的 `bg_<tag>.png` 单独跑 `--promote` 上线。
- 一组实测 89~126 秒；若某组卡到 6~8 分钟，是在**踩坏号**（日志里 `cdp:xxxxx 不可用（rc=1）→ 换下一个号`），
  不是模型慢，等它自己换号即可，别手动 kill（kill 掉这张就废了，只能 `--force` 重画）。
- 中途额度耗尽：`batch` 会把失败的 tag 列在汇总里，恢复后原命令重跑即可，成功的组自动跳过。
- 换角色组合就改 `fusion_pairs.json`，不用碰代码。新角色要先在 `hero_specs.json` 加特征卡
  （id 从 `07` 起续编），配色跑 `hero_features.py extract --art <立绘>` 得到，**不要手填**。

#### 交付结构：目录即语言，文案跟画面分类（2026-10-23 用户要求）

```bash
$P scripts/aso/aso_fusion.py build --layout duo --pair 1217 \
   --locales en-US,ja-JP,zh-CN,zh-TW --by-locale --out data_aso/derived/B/fusion_all
#   → fusion_all/en-US/feature_duo_1217.png
#     fusion_all/ja-JP/feature_duo_1217.png …（与 derived/<变体>/<locale>/feature_01.png 同构）
```

🔴 **必须 `--by-locale`**：44 张平铺在一个目录时，`feature_duo_zh-CN_1217.png` 和
`feature_duo_zh-TW_1217.png` 只能靠文件名区分，上传/交图时极易拿错语言（简繁尤其）。目录分语言后
文件名统一成 `feature_duo_<tag>.png`。`fusion_page.py` 两种结构都认。

🔴 **底部文案必须跟画面分类走**（`data_aso/assets/fusion_copy.json`）。画面换成主城/公会/世界地图，
还挂「召唤·布阵·碾压」就是文不对图：

| category | 画面 | 四语 title |
|---|---|---|
| `combat` | 战斗网格 + 血条 | SUMMON. DEPLOY. CRUSH. / 召唤·布阵·碾压 |
| `world` | 主城霓虹 | A CITY BUILT FOR WAR. / 为战斗而生的城市 |
| `guild` | 公会徽章 | BUILD. UNITE. RULE. / 建会·结盟·称王 |
| `map` | 世界关卡地图 | CLEAR EVERY SQUARE. / 一格一格推平地图 |

优先级：`pair.copy`（组内覆盖）> `pair.category` 指到的分类文案 > `fusion.json` 的 `copy` 默认四语。
`draw_caption` 会按 88% 宽自动缩字号，但**不同组字号不一致会显得参差** ⇒ 四语各条控制在同量级
（英文 ~20 字符、中日文 8~10 字）。

---


## 6. A/B：能测什么，怎么读数

### 6.1 纪律

- **一次只动一个元素**（文案 / 截图 / 置顶图 分开测），否则分不清是谁的效果
- 单窗口 **≥7 天**（覆盖完整周周期）且 **≥1000 次商店页访问**才读数
- 不满足 ⇒ 脚本直接说「数据不足」，**不输出 uplift 数字**
- 这是**顺序窗口对比**，不是随机分流：季节性、买量结构、审核变动都会污染。
  结论只当方向。要严格随机分流，去 Console 手建原生实验，本脚本只做记录

### 6.2 流程

```bash
# 登记（job 的 ⑦ 会自动做）
$P scripts/aso/aso_experiment.py start --variant B --baseline A --element copy --days 14 \
   --hypothesis "修正 ja 简体字与 zh-TW 简繁混排"

# 推上去 → 人去 Console 点「送审」→ 生效当天才是窗口起点
# 数据：Console →「商店分析」→ 导出 CSV（覆盖 A 窗口 + B 窗口）
$P scripts/aso/aso_experiment.py report --exp aso-20261023-copy-B \
   --csv ~/Downloads/store_analysis.csv --save

# 定胜负
$P scripts/aso/aso_experiment.py close --exp <id> --winner B
```

`report` 对 CSV 的要求：**日期 + 商店页访问量 + 安装量** 三列（列名启发式匹配，
中英文都认）。缺列直接报错，不会静默算 0。

---

## 7. 2026-10-23 的实测体检结论

以下都是跑出来的，不是推测：

| # | 发现 | 证据 | 处理 |
|---|---|---|---|
| 1 | **竖版游戏配横版截图** | `defaultScreenOrientation=0` 且只允许 Portrait；线上 4 张 `phoneScreenshots` 全是 1920×1080 | 变体 B 派生 1080×1920 竖版 |
| 2 | ja 标题混入简体 | 线上 `放置で时空を旅する美少女：超時空RPG` 里是「时」 | B 改为 `時空を旅する美少女：放置タクティクスRPG` |
| 3 | zh-TW 长描述是简体套繁体 | lint 命中 22 个简体专用字 | B 全量繁体重写 |
| 4 | 截图底部带中文世界聊天 | 源图底部 1/3 是聊天面板 | `crop_bottom` 逐张裁掉 |
| 5 | en/ja 截图 UI 仍是中文 | 源图本身是中文包 | ❗ 需真机英文/日文包重截，脚本解决不了 |
| 6 | ja/zh-TW 无本地化置顶图 | `new1024_500/` 只有 `_en-0` / `_zh-0` | `aso_art.py` 走换皮重绘 |

### 7.1 一个走过弯路的问题：置顶图能不能兼作手机截图？

**不能。** 10-24 试过把 `derived/B/fusion_all/<locale>/feature_duo_*.png` 直接当
`phoneScreenshots`，三重阻塞：

| 阻塞点 | 实测值 | Play 要求 |
|---|---|---|
| 长宽比 | **2.048**（1024×500） | ≤ **2.0** → 硬拒 |
| 竖屏占位 | 铺宽后仅占 **27.5%** 高，上下各 36% 糊边 | 建议铺满 |
| 张数 | 10 组 × 4 语 | 每语 ≤ **8 张** |

外加语义错位：置顶图只有 1 个槽位，这 10 组是**置顶图候选池**，不是截图素材。
正确分工 —— 置顶图讲「这游戏长什么样」（角色 + 画面 + 一句大标题），
手机截图讲「能玩到几种不同玩法」，两者内容不该重复。

对比图见 `data_aso/derived/B/_shot_ratio_demo.png`。

| 7 | en 标题顶格 | `30/30` | 换词必须先减字 |

---

## 8. 常见错误

| 现象 | 根因 | 处理 |
|---|---|---|
| `403 PERMISSION_DENIED` 写 listing | service account 只有「发布」权限，没有「编辑商店信息」 | Console → 用户和权限 → 补勾「应用信息 → 编辑商店信息」，等 5～15 分钟 |
| `400 Changes cannot be sent for review automatically` | 托管式发布 | 脚本已默认带 `changesNotSentForReview=true`；**改动仍需人点「送审」** |
| commit 成功但商店没变 | 挂在「待送审」 | 人去 Console 点送审，别重跑（重跑只是又开一个 edit） |
| `This Edit has been deleted` | 与上传/巡检并发开 edit | job 里已共用 `play` 锁（`lock.sh --name play`） |
| 截图被判不合规 | 长宽比 > 2:1（9:19.5 的原始竖截就是） | 必须归一到 9:16，`build` 已经做 |
| 文字糊在聊天面板上 | 把卖点叠在画面上 | 用预留条（当前实现），别回退到叠加 |
| 派生图发糊 | 源图 597px 放大 1.8× | 真机出 1080×1920；或 `--size 720x1280` |

---

## 9. 日常节奏

| 频率 | 动作 |
|---|---|
| 每次要改商店页 | 跑 job（dry-run）→ 看 `preview.html` → 勾 `ALLOW_WRITE` 跑 → **人去 Console 点送审** |
| 每周 | `aso_play.py list` 存一份快照，对比线上有没有被别人改过 |
| 每个实验窗口结束 | Console 导 CSV → `report --save` → `close --winner` |
| 转正后 | 把胜出变体的文案复制成新的 `A`，否则下一轮没有干净对照 |
