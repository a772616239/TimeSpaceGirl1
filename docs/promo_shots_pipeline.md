# 宣传图 → 商店截图 管线（通用版 · 可复用到其它项目）

> 这套管线最初只服务《时空美少女》，现在抽象成「换项目只改配置、不改代码」。
> 具体到本工程的参数、历史踩坑、A/B 读数，见 `docs/play_store_iteration_aso.md`（工程版）。
> 本文只讲**怎么把它搬到下一个项目**。

---

## 0. 一句话

把**一张宣传大图**变成**一套能上架的商店截图**，且保证「画面不重复、文案不重复、比例合法、文字字形正确」。

产出物（每个语言一套）：

| 产物 | 尺寸 | 用途 |
|---|---|---|
| `feature_01.png` | 1024×500 | Play 置顶大图（featureGraphic，每语只准 1 张） |
| `shot_00.png` … `shot_NN.png` | 1024×520（横）/ 1080×1920（竖） | Play 手机截图（phoneScreenshots，每语 2~8 张） |
| `shots169/NN_<tag>.png` | 1280×720（16:9） | 同上，但走「不许放大 / 不许黑边」那条路线（见 §3.7，2026-10-29 未过审后新增） |
| `index.json` | — | 尺寸/体积/sha1/文案 台账，验收页与推送都读它 |
| `preview.html` | — | 人眼验收台（真机模拟 + 合规检查 + 灯箱） |

---

## 1. 五段结构

```
① 底图        hero_keyart.py duo    AI 只画角色与背景，中段 60% + 底部 26% 必须留空
                                   ↓  data_aso/assets/gen/fusion/bg_<tag>.png
② 拼装        aso_fusion.py         底图 + 真实机截图框 + 本地真字体压标题（零额度）
                                   ↓  feature_duo_<tag>.png  1024×500
③ 合规化      fusion_shots.py      补边到 1024×520，比例 2.048 → 1.969 过 Play 的 2:1 上限
                                   ↓  shot_<NN>.png
④ 台账        fusion_shots.py      顺手回写 index.json（size/bytes/sha1/caption）
⑤ 推送        aso_play.py          deleteall + upload，替换语义；sha1 核验
```

**为什么拆这么细**：让 AI 直接画「角色 + 游戏画面 + 标题」，三件事全失控 —— 角色漂移、游戏画面是编的（一眼假）、中/日/繁字形必错。拆开后每层用最可靠的手段：

| 层 | 手段 | 因为 |
|---|---|---|
| 角色/背景 | AI 按**特征卡**重绘 | 统一光源与画风；**禁止贴现成立绘**（不同光源，一眼剪贴画） |
| 中间画面 | 真实机截图 | 「这是真游戏」只能靠真图 |
| 文字 | 本地真字体渲染 | 模型画 CJK 必错；改文案不该重出图 |

**整个方案成立的取巧点**：底图中段 60% 被要求留空，随后被截图框**整块盖住** ⇒ 「角色由管线重绘」和「中间是真游戏画面」同时成立，而**不需要抠图**（管线只出整幅不透明图，chroma key 抠不干净）。

---

## 2. 红旗线（踩过就返工）

| # | 红线 | 为什么 |
|---|---|---|
| 1 | **画面框两两不同** | 8 张里 3 张同一场战斗，商店页像刷了 8 遍同一张图。靠肉眼看缩略图查不出来，必须程序拦（`fusion_shots.py` 撞号直接 exit 2） |
| 2 | **文案两两不同** | 同上。每组写独立 `copy`，不要只按 `category` 分 4 类 |
| 3 | **文字一律本地压** | 模型画中/日/繁必错，四语排版也不可能统一 |
| 4 | **不许贴现成立绘** | 立绘只用来**抽特征**（`hero_features.py`），不参与成像 |
| 5 | **衣服必须是及踝长裙/高腰不透明衬裙** | 特征卡里写 `bare legs` 会画出高开叉露胯，Play 必拒。`hero_prompt.py` 有 `DRESS CODE` 硬约束段 |
| 6 | **横版比例 ≤2.0** | Play 硬上限。1024×500 = 2.048 **超了**，必须补到 520 |
| 7 | **传图 = 上线** | 本类账号是「提交即自动送审」，`edits.commit` 带 `changesNotSentForReview` 直接 400。推送前必须确认 |
| 8 | **核验看 sha1，不看张数** | 日志「已传 1 张」只是 upload、不含 commit |

---

## 3. 换项目：只改 6 处

### 3.1 目录骨架

```
<你的工程>/
├── data_aso/
│   ├── site.json            ← 🔴 项目特异性全在这里（新建项目第一件事）
│   ├── variants/B/          ← 文案真源：<locale>.json（title/shortDescription/fullDescription）+ meta.json
│   ├── assets/
│   │   ├── shots.json       ← 真机截图池：每条 = 一张截图 + 取景参数
│   │   ├── fusion.json      ← 版面：画布、画面框位置、标题带位置、默认四语文案
│   │   ├── fusion_pairs.json← 每组一张：角色配对 + 独占画面 + 独立文案
│   │   ├── fusion_copy.json ← 按 category 的文案池
│   │   ├── hero_specs.json  ← 角色特征卡（只写「她是什么」，不写原图姿势/镜头）
│   │   └── gen/fusion/      ← AI 底图 bg_<tag>.png（进库）
│   └── derived/<变体>/       ← 产物（不进库）
├── scripts/aso/             ← 整套脚本，原样拷过来
└── .jenkins/jobs/<你的 job>.groovy
```

### 3.2 `data_aso/site.json` —— 唯一必改的配置文件

```jsonc
{
  "brand": "你的游戏名",
  "package": "com.yourcompany.yourgame",
  "shot_size": [1080, 1920],      // 竖版路线
  "feature_size": [1024, 500],    // Play 死规定，别动
  "locales": {
    "en-US": { "label": "英语", "material_dirs": ["你的物料/en"], "fonts": ["/path/to/font.ttf"] },
    "ja-JP": { ... }
  }
}
```

- 缺字段自动回落到 `aso_common._DEFAULTS`（=《时空美少女》现状）⇒ 老工程零影响。
- `locales` 可整体替换（只做英/日也行），也可只给部分字段做 merge。
- `fonts` 是**压字用的绝对路径**，macOS 自带的中文字体只有 `STHeiti Medium.ttc` / `Hiragino Sans GB.ttc`（`PingFang.ttc` 从 macOS 15 起没了）。

### 3.3 `shots.json` —— 真机截图池

每条记录 = 一张真实机截图 + 取景。**这是全流程最稀缺的资源**：干净合规、无中文聊天、无按钮行的截图，通常只有 3 张能救，而商店页要 6~8 张。所以：

> **素材不够就减张数，不要用同一张截图换景别凑数。**
> 同一场战斗换 6 种 `zoom`/`focus_x`，缩略图看上去还是一张图 —— 用户第一次就指出来了。

`band` 参数决定「取哪一条横带」。**跨度必须匹配画面框比例**：

```
框 440×243 = 1.81
band 跨度 ≈ (图宽 ÷ 1.81) ÷ 有效图高

跨度 0.30 ⇒ 带子比例 3.4 ⇒ 横向裁掉 47% ⇒「画面不全面」
```

这是「截图不全面、不好看」的唯一根因，绝大多数时候不是素材差，是 `band` 算错了。

### 3.4 `fusion_pairs.json` —— 每组一张

```jsonc
{ "pairs": [
  { "tag": "0102",                      // 4 位：左 id + 右 id 拼接，管线按它取 bg_0102.png
    "left": "01", "right": "02",
    "category": "combat",               // 文案兜底分类
    "screen": { "shot": 0,               // 🔴 每组独占一个 shots.json 序号
                "band": [0.45, 0.96],
                "focus_x": 0.5, "zoom": 1.0 },
    "copy": { "zh-CN": {"kicker":"战术战场","title":"七乘七，站位定生死"}, ... }  // 优先级最高
  }
] }
```

优先级：`pair.copy` > `category` 指向 `fusion_copy.json` > `fusion.json` 默认。

补一句：`tag` 必须是「左 id + 右 id」拼的四位数，否则底图收不到（管线按 `bg_<tag>.png` 找）。

### 3.5 Jenkins job

拷 `.jenkins/jobs/TS-Store-Iteration.groovy`，改三处：

```groovy
PROJ = '/你的/工程/绝对路径'          // 🔴 必须改
PY   = '/你的/python（要装 PIL + numpy）'
// 包名不用改 —— aso_play.py 的默认值读 site.json
```

然后 `.jenkins/apply-jobs.sh --only <job>`。

### 3.6 清单

- [ ] `data_aso/site.json` 写好（包名/品牌/语言/字体）
- [ ] `variants/<变体>/<locale>.json` 四语文案
- [ ] `assets/shots.json` 真机截图池（先数数有几种**互不相同**的画面）
- [ ] `assets/fusion.json` 版面（画布 + 框位置 + 标题带）
- [ ] `assets/hero_specs.json` 角色特征卡（含 `DRESS CODE`）
- [ ] `assets/fusion_pairs.json` 每组独占画面 + 独立文案
- [ ] Jenkins job 的 `PROJ` / `PY`
- [ ] `chmod +x` 别忘（拷过来的脚本可能丢执行位，反正用 `python` 调就不需要）

### 3.7 16:9 手机截图路线（1280×720）—— 2026-10-29 未过审后重做

Play 详情页对**横版**截图的建议规格是 **16:9 / ≥1280×720**。老的横版路线
（`fusion_shots.py` 的 1024×520 = 1.969）两条都不满足，所以单独一条 16:9 路线，
脚本是 **`scripts/aso/fusion_shots169.py`**，产物在 `data_aso/derived/B/shots169/`。

第一版做成 1920×1080（`fusion.json` 的 `duo169` 版面），**被驳回**，原文：

> All visual materials such as images and videos must be clear with no obvious blurring,
> stretching, compression, black edges, white edges, etc. Visual materials cannot be made up
> of overly simple patterns such as solid colors and gradients.

三条都踩了，且都能量化：

| 驳回点 | 我们踩在哪 | 量化证据 | 修法 |
|---|---|---|---|
| 模糊 blurring | 1920 画布下画面框要 845px，真机源只有 598~720px ⇒ **1.41× 放大** | 框宽 ÷ 源宽 = 1.41 | 画布降到 **1280×720**，同一个框只要 563px ⇒ **0.94×（缩小）** |
| 黑边 / 纯色渐变 black edges / gradients | 标题压在 `bg_*.png` 底部那块黑上，还叠了一层黑渐变 scrim | 底图底部 22% 局部细节 **0.1~3.0**（其它区域 16~26），均值亮度 10~14 | 画面框从 y=0.40 **压出画布底边**，把中间那块黑整块盖掉；标题挪到顶部，`bar>1` 关掉 scrim |
| 拉伸 stretching | 早期原型用 `crop(0,0,W,0.76H)` 再 `resize` 到满画布 = 纵向拉伸 1.32× | 角色比例肉眼可见变形 | 一律 `_cover` 等比裁切；band 跨度按「框宽 ÷ 框比例」反算 |

```bash
$PY scripts/aso/fusion_shots169.py                    # 出全部（英文，1280×720）
$PY scripts/aso/fusion_shots169.py --tags 0102,2019   # 只出指定组
```

脚本自带三条验收（不达标直接 rc=3，别上传）：

- `scale = 框宽 ÷ 源宽` 必须 **≤1.02**（>1 就是放大 ⇒ 必然被判模糊）
- 底部 20% 的**局部细节**必须 **≥6**（低于这个值肉眼就是一条黑边）
- 画布必须是 16:9

🔴 **「框压底边」只解决中间那块黑，左右两个下角还是纯黑**（实测均值 2.0、局部细节 0.06）。
`extend_floor()` 把底图底部黑区换成「湿地面反射」：取黑区上方**等高**的一条，垂直翻转 +
亮度沿深度 0.95→0.42 衰减 + 2.5px 模糊。等高 ⇒ 不拉伸；内容是真实画面 ⇒ 不是纯色/渐变；
接缝处 0.95 亮度 ⇒ 没有硬线（直接贴 0.48 会在 78% 高度留一条横贯全图的硬边，比黑边还难看）。

🔴 **验收必须分测「底边 / 左下角 / 右下角」三块**，不能只测「底部 20% 的平均值」：
框内画面会把两个角的纯黑平均掉，`detail` 看着有 10+，实际角上是 0.06。
2026-10-29 第一版就是这么漏掉的，用户一眼就指出来了。现在三块都要 ≥4。

🔴 **只出 3 张是素材上限，不是偷懒**：`shots.json` 里 8 张只有 3 张是真机竖版高清图
（598×1296 / 720×1280 / 597×1299），另外 5 张是 334~412px 的场景小图，铺到 563px 就是
1.4~1.7× 放大 —— 正是这次被驳回的毛病。Play 要「3 张及以上」，**宁可 3 张全清晰，
也不要 6 张一半模糊**。要补第 4~6 张，唯一办法是真机重打 1080×1920 截图。

🔴 **画面框里的取景要按「战斗区」切**，不能直接用 `shots.json` 的 `crop_bottom`：
那套值是按 1024×520 的横条调的，底部还会带进技能条和聊天面板（纯色大色块 + 中文 UGC）。
`fusion_shots169.BATTLE_CROP` 里逐张卡死上下界，下界一律停在技能条之上。

🔴 **标题必须折两行**：一行写死「7X7. POSITION WINS.」在 1280 宽下是 648px，
横穿右边角色的脸。折两行后每行 ≤0.44 画布宽（563px），正好塞进两个角色之间的天空缝隙。

---

## 4. 常用命令

```bash
PY=/usr/local/bin/python3          # 或你装了 PIL+numpy 的解释器
V=B

# 出底图（耗 AI 额度，~90s/组，必须串行）
$PY scripts/aso/hero_keyart.py duo --pair 01,02 --theme cyber --wait

# 批量拼装（零额度，~2s/组）：shots = fusion_shots.py 的 DEFAULT_ORDER
$PY scripts/aso/aso_fusion.py build --layout duo --variant $V \
    --pairs shots --by-locale --out data_aso/derived/$V/fusion_all

# 补边成手机截图 + 回写 index.json
$PY scripts/aso/fusion_shots.py --variant $V

# 🔴 想换置顶图就再单独 promote 一组（批量 + --promote 会被拒：每语只准一张）
$PY scripts/aso/aso_fusion.py build --layout duo --variant $V --promote

# 复检 + 刷新验收台
$PY scripts/aso/aso_assets.py check   --variant $V
$PY scripts/aso/aso_assets.py preview --variant $V

# 推送（只换截图 / 只换置顶图，别互相覆盖）
$PY scripts/aso/aso_play.py push --variant $V --image-types phoneScreenshots \
    --shots 0,1,2,3,4,5 --images-only --allow-write --yes --auto-review
```

Jenkins 侧对应 `SHOT_MODE=landscape（横版 1024×520）`，③ 阶段会自动跑完上面 ②③④ 四步（含「复原置顶图」——`aso_assets build` 会把 `feature_01.png` 换回拼贴版，横版路线要拼装版）。

---

## 5. 排错表

| 症状 | 根因 | 修法 |
|---|---|---|
| 截图看着「不全面」，两侧被切 | `band` 跨度 ≠ 框比例 1.81 | 按 §3.3 公式重算 band |
| 8 张图像同一张图刷了 8 遍 | 全组共用 `screen.shot`，只靠 zoom 拉景别 | 每组独占 `screen.shot`；`fusion_shots.py` 会 exit 2 拦 |
| 8 张图文案一样 | 只按 `category` 分了 4 类却出 7 组 | `fusion_pairs.json` 每组写 `copy` |
| Play 返回 400 说比例超限 | 1024×500 = 2.048 > 2.0 | 补边到 1024×520 |
| Play 返回 400 说图太多 | 每语 >8 张（竖版路线常有 9 张） | `--shots 0,...,7` 挑；`MAX_IMAGES` 会兜底告警 |
| Play 返回 400「Changes are sent for review automatically」 | 账号是提交即自动送审 | 去掉 `changesNotSentForReview`，即 `--auto-review` |
| 传完线上没变 | 只 upload 没 commit | 看 sha1；`aso_play.py push` 会打印 commit 结果 |
| 验收页图被裁掉 | CSS 写死 `aspect-ratio:9/16` | 已改 `var(--ar)`，由 `index.json` 的 `canvas` 注入 |
| 验收页数字是旧的 | `index.json` 没回写 | 重跑 `fusion_shots.py` 或 `aso_assets.py preview` |
| 图没生效但也不报错 | 客户端 `_en` 加载不到会静默回退 `_zh` | 这是客户端问题，不是店面图问题 |
| 中文文案出现在英文商店页 | 截图底部 1/3 有游戏内中文聊天 | 用 `crop_bottom` 裁掉，`band` 上界别低于 0.90 |

---

## 6. 什么时候不用这条路

| 场景 | 用什么 |
|---|---|
| 素材是干净的竖版真机截图，且够 6 张 | 竖版路线（`aso_assets.py build`），最省事 |
| 素材只有 3 种画面，但要 6 张截图 | 横版路线（本文），同一画面换景别 + 换文案，靠「宣传图」的气质掩盖素材不足 |
| 游戏本身就是横版 | 横版路线天然合适 |

⚠️ **两条路线会互相覆盖**：`aso_assets.py build` 出 1080×1920 竖版，`fusion_shots.py` 出 1024×520 横版，写的是同一批 `shot_*.png`。
**跑过 `fusion_shots.py` 之后不要再跑 `aso_assets.py build`**（Jenkins 的横版分支已经处理了这个顺序：build 先跑，横版随后整批覆盖）。

---

## 7. 相关文件

| 文件 | 作用 |
|---|---|
| `scripts/aso/aso_common.py` | 站点配置读取、语言、规格上限、Play 客户端 |
| `scripts/aso/hero_keyart.py` | 出双人底图（AI） |
| `scripts/aso/hero_features.py` | 立绘 → 配色特征（供特征卡） |
| `scripts/aso/hero_prompt.py` | 提示词模板（含 `DRESS CODE` 硬约束） |
| `scripts/aso/aso_fusion.py` | 拼装（底图 + 画面框 + 压字），支持 `--pair` / `--pairs` |
| `scripts/aso/fusion_shots.py` | 置顶图 → 手机截图（补边 + 台账 + 查重） |
| `scripts/aso/aso_play.py` | Play 推送（listings / images） |
| `scripts/aso/aso_assets.py` | 竖版派生 + 规格体检 + 验收页 |
| `data_aso/site.json` | 🔴 项目特异性配置 |
