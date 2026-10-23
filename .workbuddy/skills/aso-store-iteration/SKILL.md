---
name: aso-store-iteration
description: TimeSpaceGirl1 的 Play 商店页运营（ASO）——四语文案闸门、竖版截图派生、**拼装式置顶图（左右角色由 TS-Art-Restyle 按特征卡重绘 + 中间压实机画面框 + 本地压字）**、Play 规格体检、A/B 登记与读数、推送 Play。当用户说"改商店页""换置顶图/宣传图/featureGraphic""做店面图""商店页 A/B""上线截图""推 Play listing"时使用。含三层拆分原则、promote 落盘口径、五条红线（禁止贴立绘、band 避按钮、--wait 串行、DRESS CODE 合规、API 不能送审）。
---

# Play 商店页迭代（ASO）

> 详细 runbook：**`docs/play_store_iteration_aso.md`**（闸门规则、踩坑复盘、A/B 纪律全在里面）
> 入口：Jenkins **`TS-Store-Iteration`**（`.jenkins/jobs/TS-Store-Iteration.groovy`）
> 出图管线：skill `art-restyle` + Jenkins `TS-Art-Restyle`
> 出包发版：skill `play-aab-release`（与本 skill 无关，别混）

## 什么时候用

| 用户说 | 走哪条 |
|---|---|
| 「改标题/短描述/长描述」「推文案」 | §3 `aso_play.py push --text-only`，先 `aso_lint.py` |
| 「换截图」「截图不好看」 | §2 `aso_assets.py build` → `check` |
| 「换置顶图」「做店面图/宣传图」「featureGraphic」 | §1 拼装式（**不要贴立绘**） |
| 「换掉左右两个角色」「换成 XX 和 YY」 | §1 `--pair` 改 id + `fusion.json` 的 `bg` |
| 「商店页 A/B 怎么读数」 | §4 `aso_experiment.py report/close` |
| 「上线/推 Play」 | §3，且牢记**送审只能人工点** |

## 1. 拼装置顶图（featureGraphic 1024×500）——三层拆分

店面图**只有一种造法**：三层各自用最可靠的手段，不许让 AI「一次画完整张」。

| 层 | 来源 | 为什么必须是它 |
|---|---|---|
| 左右角色 | `hero_keyart.py duo` → `TS-Art-Restyle` 按**特征卡**重绘 | 画风/光源要和背景统一；立绘直接贴＝剪贴画 |
| 中间画面 | 真实机截图（`shots.json` 的 `band` 取战斗横条） | 「这是真游戏」只能靠真图 |
| 文字 | 本地真字体（`aso_fusion.py`） | 模型画中/日/繁必错；改文案不该重出图 |

```bash
PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python

# ① 出双人底图 1920x1080（前一个 id 在左、后一个在右）——耗额度，~90s/张
$PY scripts/aso/hero_keyart.py duo --pair 01,02 --theme cyber --dry-run   # 先看提示词
$PY scripts/aso/hero_keyart.py duo --pair 01,02 --theme cyber --wait
#    → data_aso/assets/gen/fusion/bg_0102.png

# ② 拼装 + 压四语标题（零额度，~1s/张）
$PY scripts/aso/aso_fusion.py build --layout duo --variant B \
    --locales en-US,ja-JP,zh-CN,zh-TW --promote

# ③ 复检（置顶图必须 1024x500）
$PY scripts/aso/aso_assets.py check --variant B
```

- **`--promote`** = 写成 `derived/<变体>/<语言>/feature_01.png`（`aso_assets build` 用的同一文件名），
  顺手清掉该目录其它 `feature_*`、把真实 size/bytes/sha1 刷回 `index.json` ⇒
  `preview.html` / `index.json` / `aso_play.py push` 全不用改，也不会出现两张置顶图。
- **多组候选走 `--pair <tag>`**：一次带出 `bg_<tag>.png` + 该组的框内取景（`fusion_pairs.json` 的
  `screen`）+ 输出后缀，不写 `--promote`。🔴 10 组**不能** promote（会互相覆盖成一张）。
- 🔴 **画面框里别全用同一段截图**：`shots.json` 只有 3 张干净合规图，10 组若共用同一 `band`
  就是「一个画面重复十遍」。每组在 `fusion_pairs.json` 里配 `shot/band/zoom/focus_x` 拉开景别；
  `band` 起点 0.30 起（再往上吃空景）、上限 0.90（再往下吃中文按钮行）。
- 换图后验收页数字要刷：`$PY scripts/aso/aso_assets.py preview --variant B`（只重画 html，不动图）。
- 版面全在 `data_aso/assets/fusion.json`（`frame`/`screen`/`title`/`copy`），改构图不改代码；
  `aso_fusion.py list` 看当前版面。

### 为什么不需要抠图
管线只出整幅不透明图，chroma key 抠头发发毛。做法是让底图中段 **60% 被要求留空**，
这块随后被画面框整块盖住 ⇒「角色由管线重绘」与「中间是真游戏画面」同时成立，alpha 根本用不上。

## 2. 截图：派生 + 卡片版式

```bash
$PY scripts/aso/aso_assets.py build --variant B          # 竖版 1080x1920 + 置顶图
$PY scripts/aso/aso_assets.py check --variant B          # Play 规格体检
$PY scripts/aso/aso_assets.py preview --variant B        # 只重画验收页
```

- `crop_top` / `crop_bottom` 是**卡片边界落在哪**，不是「裁掉多少」；落在战斗画面里最好看。
- 源图分辨率要盯：现有竖版源图仅 597~720px 宽，放大 >1.6× 会标黄；正解是真机出 1080×1920。
- 文字一律本地压（`STHeiti Medium.ttc`：简中=1 号面、繁中=0 号面；全角标点步进 0.68em）。
- 🔴 **Play 张数上限**：`phoneScreenshots` 8 张/语、`featureGraphic` 1 张。`shots.json` 8 条会派生
  9 张 `shot_*.png`，全推必 400 ⇒ 上传用 `--shots 0,1,2,5` 挑。
- 锐度分层（实测）：`shot_01`(1.5×)、`shot_05`(1.1×) 最锐 → `shot_00`/`02`(1.8×) 可用 →
  `shot_03`/`04`(2.6×) 偏糊 → `shot_06`/`07`/`08`(3.2×) 别上。
- 🔴 **置顶图不能兼作手机截图**：1024×500 比例 2.048 > Play 上限 2.0，强行转竖前景只占 27.5%；
  且 fusion 10 组 > 8 张上限。置顶图讲「长什么样」，截图讲「能玩几种玩法」，两者内容不该重复。

## 3. 文案与推送

```bash
$PY scripts/aso/aso_lint.py --variant B --baseline A       # 闸门：长度/串味/夸大
$PY scripts/aso/aso_play.py push --variant B --text-only   # 默认只打印 diff
$PY scripts/aso/aso_play.py push --variant B --with-images --allow-write --yes

# 只换手机截图（四语、指定 4 张）
$PY scripts/aso/aso_play.py push --variant B --images-only \
    --image-types phoneScreenshots --shots 0,1,2,5 --allow-write --yes --auto-review
# 只换置顶图
$PY scripts/aso/aso_play.py push --variant B --images-only \
    --image-types featureGraphic --allow-write --yes --auto-review
```

三道闸门：`ALLOW_WRITE`（允许写）→ `--yes`（job 自动带）→ `MODE`（推哪些字段）。
硬上限：标题 30 / 短描述 80 / 长描述 4000（Unicode 字符）。

🔴 `--auto-review` 必须带：本包是「提交即自动送审」，不带参数会被 400 打回（`changesNotSentForReview must not be set`）。
⇒ **传图 = 上线**，动手前先跟用户确认。

核验口径：**看 sha1，不看张数**。传完再跑一次 `list`，把新导出目录里 `images.json` 的 sha1
与 `derived/B/<locale>/shot_XX.png` 逐张比对（`deleteall+upload` 是替换语义，旧图应 0 残留）。

## 4. A/B：能测什么

- 一次只动一个元素；单窗口 ≥7 天且 ≥1000 次商店页访问才读数，否则脚本直接说「数据不足」，不输出 uplift。
- 顺序窗口对比，**不是随机分流**；结论只当方向。
- `aso_experiment.py start / report --csv / close --winner`。

## 红线（每条都踩过）

1. 🔴 **禁止拿工程立绘直接贴到店面图上**（`Assets/.../Jingtailihui/` 那些自带 alpha 的图）。
   立绘与背景不同光源/画风，一眼剪贴画，用户 2026-10-23 当场否决。
   立绘只用来**抽特征**（`hero_features.py` → `hero_specs.json`）。`--promote` 缺底图时**直接报错**。
2. 🔴 **框内取景 `band` 取 `[0.40,0.80]`**：取到 0.90 会把截图底部的中文「禁止」按钮带上英文商店页。
3. 🔴 **出图必须 `--wait` 串行**：与单人 `render` 共用本机 Chrome 登录态和 `inbox/`，并发必串图
   （#28~#32 里 02/03 的 `gen_web.png` 同一 md5）。Jenkins 2.568 会**静默丢弃**
   `DisableConcurrentBuildsJobProperty`，`options{disableConcurrentBuilds()}` 也拦不住同时入队。
4. 🔴 **DRESS CODE 合规**：提示词里 `hero_prompt.py` 有硬约束段（groin/buttocks 必须覆盖、
   开叉不过膝、禁止性化姿势）。原 `01` 写 `bare legs` 就画出露胯，Play 必拒。
5. 🔴 **Play 能力边界**：`edits.listings` / `edits.images` 能 API 改；但**商店页 A/B 实验没有公开 API**、
   **托管式发布 API 无权送审** ⇒ 建实验、看结论、点送审只能网页人工。

## Jenkins 参数（`TS-Store-Iteration`）

| 参数 | 用途 |
|---|---|
| `MODE` | `dry-run` / `text` / `images` / `both` / `art（只出美术需求单）` |
| `VARIANT` / `BASELINE` | 变体目录，`A` 是线上快照**禁改** |
| `FUSION` | 走 ③b 置顶图拼装阶段 |
| `FUSION_PAIR` | 双人底图的英雄 id，`01,02` |
| `FUSION_RENDER` | 🔴 重出底图（耗额度、必须串行）；只改排版时**不要勾** |
| `ALLOW_WRITE` | 🔴 唯一能写线上的开关，默认关 |

`FUSION=true` + `FUSION_RENDER=false` = 零额度只重排；`MODE=art` + `FUSION_RENDER=true` = 只出图不碰 Play。
