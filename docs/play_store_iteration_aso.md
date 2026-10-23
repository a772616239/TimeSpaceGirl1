# 店面迭代（ASO）—— Jenkins `TS-Store-Iteration`

> 建立：2026-10-23
> 配套：`google_play_upload_setup.md`（凭证与发版 API）、`android_release_runbook.md`（出包）、
> `.workbuddy/skills/play-aab-release/SKILL.md`（打包发版）
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
| **点「送审 / 开始发布」** | ❌ 不能 | 账号是托管式发布，API 无权送审（`changesNotSentForReview` 已证实） |
| 回复评论、应用内容问卷、测试人员名单 | ❌ 不能 | 网页 |

⇒ 所以本 job 的定位是：**把 90% 的准备与巡检自动化，把必须人点的那几下（送审 / 建实验 / 看结论）留给人**，
并且每次构建都告诉你「现在轮到你点哪一下」。

---

## 1. 一键入口

Jenkins → `TS-Store-Iteration`（视图「时空美少女 · 全流程」）

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1
P=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python

# 只读体检（默认）：文案闸门 + 素材派生 + 规格体检 + 验收页 + A/B 登记
#   → 不碰 Play，只打印 diff
（在 Jenkins 里点构建，MODE 保持 dry-run）

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

## 4. 素材：为什么是「派生」不是「重画」

`aso_assets.py build` 做的事：竖版源图 → 裁掉底部世界聊天 → 归一到 9:16 → 下方预留一条卖点条。

两个设计决定，都是踩出来的：

1. **卖点条是「预留」不是「叠加」**。最初把文字压渐变叠在画面上，实测很脏：
   这游戏的截图底部 1/3 挂世界聊天，遮罩压不住，文字和聊天行糊在一起。
   现在内容区按 `1080×1500` 归一，下面 420px 是实心条。
2. **`crop_bottom` 必须按图配**。不同截图聊天区高度不同（0～35%），
   清单里逐张写，别指望一刀切。

产物与体检：
- 手机截图 `1080×1920`（9:16），Play 规定最短边 ≥320、最长边 ≤3840、长宽比 ≤2:1、单张 ≤8MB
- 置顶图 `1024×500`
- `preview.html` 四语并排的人眼验收页（job 会自动归档到证据目录）

**源图分辨率是要盯的**：现有竖版源图只有 597～720px 宽，放大到 1080 是 1.8×，
`build` 会把超过 1.6× 的逐条标黄。真正的解法是真机/模拟器直接出 1080×1920 截图。

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
