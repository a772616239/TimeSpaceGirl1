# 主题生产卡：夏日冲浪 / 普罗旺斯 / 万圣节 / 感恩节 / 赛博 / 探索（以及已有的圣诞·新年·情人节）

> 落地时间：2026-10-20 晚（四个新主题 + 批量管线 + 预设自检）  
> 这份文档回答的是「**这个主题该怎么画、哪些参数必须配、批量怎么排**」；  
> 一线操作（什么时候用哪条命令、边框三定律、验收清单）看 `.workbuddy/skills/art-restyle/SKILL.md`，  
> 原理与踩坑复盘看 `docs/art_restyle_pipeline.md`。三份分工不重叠。
>
> 相关脚本：
> - `scripts/image/restyle_pipeline.py` —— 确定性九步（prepare/postprocess/verify/publish…），`themes --check` 自检
> - `scripts/image/gen_chatgpt_web.py` —— 浏览器登录态出图（本机 Chrome / AdsPower SunBrowser）
> - `scripts/image/batch_restyle.py` —— 批量编排（资源 × 主题），清单见 `scripts/image/batch_example.json`
> - `scripts/image/refit_band.py` —— free 构图时模型画棋盘格留白的重贴脚本
> - `scripts/image/preview_ingame.py` —— 567px 真机观感预览

---

## 0. 一句话

主题 = `theme_presets.json` 里的一组字段。**换主题不改代码**，只改预设；能不能直接出图由 `themes --check` 判定。  
🔴 **画风锁（`style_lock`）**：`PROMPT_TEMPLATE` 里有一整段 `STYLE LOCK`，排在构图锁之前，用最高优先级要求
「复刻源图的画法」——平涂赛璐璐就还是平涂，不许换成厚涂/3D/柔光。它不属于任何主题，对所有主题生效；
预设里写 `"style_lock": ""` 可以关掉（资源本来就要换渲染方式时）。**没有它，模型会把「换风格」理解成「重画一遍」，
单张看都不丑，放进游戏里就跟别的 UI 不是一套。**
一张图的完整链路：`prepare → prompt →（provider 出图）→ postprocess → verify →（preview）→（publish）`，  
其中只有「provider 出图」不可复现，其余每一步都可断言——所以批量也把出图当外部失败处理，不重试到天荒地老。

---

## 1. 现役主题矩阵

| key | 中文 | 文件名后缀 `suffix` | 主色 | 最适合的图 | 必须特别处理的点 |
|---|---|---|---|---|---|
| `christmas` | 圣诞 | `christmas` | 深红 `#8c1f28` / 松绿 `#1f6b45` / 暖金 | 全类型 | 右下自带亮装饰带的图要 `--watermark off` |
| `newyear` | 新年 | `newyear` | 中国红 / 金 | 全类型 | 金色高光容易过曝，验收别当水印 |
| `halloween` | 万圣节 | `halloween` | 深紫 / 橙 / 冷月白 | 人物向（拍脸、弹窗） | 橙紫撞色，文案描边要单独锁 |
| `valentine` | 情人节 | `valentine` | 玫红 / 粉 / 奶油 | 人物向 | 粉底 + 紫框容易糊，必要时 `FRAME_RIM=ivory` |
| `summer_surf` | 夏日冲浪 | `summer_surf` | 海蓝 `#0aa3c2` / 沙金 `#ffd166` | 全类型 | 太阳光斑吃对比度；白浪泡沫容易被「过曝」误判 |
| `provence` | 普罗旺斯 | `provence` | 薰衣草 `#6f5aa8` / 麦金 `#e8d6a8` | 全类型（偏女性向） | 整体低饱和，深色面板上发灰 ⇒ `FRAME_RIM=ivory` 提亮 |
| `thanksgiving` | 感恩节 | `thanksgiving` | 南瓜橙 `#c9752f` / 枫棕 / 麦金 | 全类型 | 与圣诞同属暖色 ⇒ 别混用红绿；厚衣料容易画胖，保腰线 |
| `cyber` | 赛博朋克 | `cyber` | 深蓝黑 `#0a0f1e` / 青 `#00e5ff` / 品红 `#ff2d95` | 全类型（最吃「重设计」） | 霓虹描边与文案抢注意力；深底 + 紫框会糊 ⇒ `FRAME_RIM=ivory` |
| `explore` | 探索 | `explore` | 石绿 `#16281c` / 黄铜 `#c98a3c` / 火把琥珀 `#f0b64b` | 场景插画、寻宝/巡逻面板 | 场景题材非节日：靠 `decor_sentence` 换世界；模型爱加地图标记与字母 ⇒ LAYOUT 必须锁「无文字」 |

后缀进文件名（`<原图名>_<suffix>_<w>x<h>[_alpha].png`），所以 `suffix` **只能小写字母/数字/下划线且全局唯一**，  
`themes --check` 会拦下大写、重名和非法字符。

---

## 2. 每个主题怎么画（设计意图 + 禁忌）

讨论每个主题时只看四件事：**换什么色 / 加什么装饰 / 穿什么 / 手里有没有东西**。  
姿势池（`pose_hints`）一律偏「空手 + 动作感」，道具只在**明确标了 `(opt-in prop)`** 的条目里出现——
这是「每张 free 图都抱礼物」那次事故之后定下的规矩（见 §5）。

### 2.1 夏日冲浪 `summer_surf`
- **意图**：明亮、有风、有运动感，跟「圣诞/新年」的厚重形成反差；适合暑期档、泳装/运动皮肤活动。
- **配色**：海蓝主调 + 沙金高光 + 珊瑚橙点缀；白浪泡沫做质感层。
- **服装**：短款防晒冲浪服（木槿印花）＋贝壳脚链＋耳上别热带花；不要画成泳装暴露度高的版本（真机是 15+ 向 UI）。
- **装饰**：椰树叶、浪花泡沫、贝壳、海星、沙滩球、太阳光斑。
- **姿势偏好**：遮阳远眺、迎风回身、双手叉腰、蹲身看向镜头；允许俯视/仰视镜头变化。
- **禁忌**：
  - 大太阳光斑压在主文案上 ⇒ 带文案的图把光斑推到角落；
  - 白浪泡沫密集，`verify` 的「过曝/水印」判据容易假报 ⇒ 这类图直接 `--watermark off`；
  - 蓝底 + 紫框偏冷，深色面板上偏闷 ⇒ 需要时 `FRAME_RIM=ivory`。

### 2.2 普罗旺斯 `provence`
- **意图**：柔和、浪漫、慢节奏；薰衣草田 + 午后暖光的「法式田园」。适合轻社交/女性向活动、皮肤礼包。
- **配色**：薰衣草紫 + 奶油白 + 麦金 + 橄榄绿；整体低饱和、低对比。
- **服装**：露肩薰衣草印花连衣裙（奶油蕾丝边）＋草编帽（挂在肩后）＋珍珠耳饰。
- **装饰**：薰衣草穗、麦穗、橄榄枝、亚麻布褶、暖阳斜光、陶罐。
- **姿势偏好**：把头发别到耳后、双手轻握在身前、慢步走来、半侧身静立。
- **禁忌**：
  - **这是最容易被「验收误判」的主题**：低饱和 + 大面积浅色，`verify` 的对比度类判据阈值要放宽，或直接看人眼预览；
  - 深色面板（17,17,25）上低饱和版本会显得脏 ⇒ `FRAME_RIM=ivory` 而不是 violet；
  - 别加霓虹/强反光装饰，会毁掉整体调性。

### 2.3 万圣节 `halloween`
- **意图**：俏皮而不是恐怖；紫 + 橙的撞色，冷月光打底。
- **配色**：深紫 `#4b2a6b` + 南瓜橙 + 冷月白；允许一点荧光绿点缀（仅特效）。
- **服装**：深紫小魔女裙（橙边）＋尖顶帽＋条纹袜＋领口小蝙蝠挂饰。
- **装饰**：南瓜灯、蝙蝠、蜘蛛网、墓碑、悬浮糖果、枯枝、冷月光。
- **姿势偏好**：歪头坏笑、单手压帽檐、蹲身前倾、回身抬眼；**唯一允许的道具**是「举着小南瓜灯」那条（1/4 概率，opt-in）。
- **禁忌**：
  - 恐怖元素（血、骷髅、尖牙特写）一律不要——这是全年龄向活动图；
  - 橙紫互补色对比极强，**带文案的图必须单独锁字的材质**（LAYOUT 里写死），否则字会被背景吃掉。

### 2.4 感恩节 `thanksgiving`
- **意图**：温暖、丰盛、秋冬家庭感；和圣诞区分开——圣诞是「红绿 + 雪 + 金」，感恩是「南瓜橙 + 枫棕 + 麦金」。
- **配色**：烧橙 `#c9752f` / 深枫棕 `#8a3b1f` / 麦金 `#e8b64c` / 橄榄绿。
- **服装**：焦糖色粗针开衫（奶油麻花边）＋亚麻衬衫＋枫叶胸针＋格纹围巾搭肩。
- **装饰**：南瓜、枫叶、橡果、玉米、麦穗捆、暖灯串。
- **姿势偏好**：双手插进开衫口袋、回头撩围巾、单手扶腰、双臂张开迎接。
- **禁忌**：
  - 厚衣料 + 前倾姿势容易显胖 ⇒ 提示词里保留腰线、少用正面直立；
  - 别画火鸡/餐桌全席（会被误读成「感恩节大餐活动」而不是皮肤图）；
  - 暖橙和圣诞的暖金相邻，**同批出图时不要混着看**，容易挑错色。

### 2.5 赛博朋克 `cyber`
- **意图**：最吃「重设计」的主题——霓虹、扫描线、全息面板，允许镜头/构图大改（建议直接 `COMPOSITION=free`）。
- **配色**：深蓝黑打底 + 青 `#00e5ff` / 品红 `#ff2d95` / 紫 `#7b2cff` 三色霓虹。
- **服装**：黑色机能外套（霓虹走线 + 全息饰边）＋推在额头的透明面罩＋电路纹袖子＋束带。
- **装饰**：霓虹管、全息面板、数字雨、扫描线、电路纹、故障色块。
- **姿势偏好**：低角仰视调面罩、转身夹克飞扬、双手插兜回望、抬手「停下」手势。
- **禁忌**：
  - **霓虹描边会和字抢**：中文文案必须单独锁材质并事后 1:1 看字；
  - 深蓝底 + 紫框 = 框看不见 ⇒ `FRAME_RIM=ivory`（MEMORY.md 里那条「深色面板上墨带跟底同亮度」的坑）；
  - 数字雨/扫描线是高频纹理，PNG 压缩后容易出摩尔纹，出图后看 1:1 而不是缩略图。

### 2.6 探索 `explore`（2026-10-21 新增）

- **意图**：这是**场景题材**，不是节日。它换的是「世界」——把现代/霓虹/工业基地整块换成古遗迹与丛林，靠 `decor_sentence` 描述「replace 掉什么」，**不要**靠堆节日装饰。
- **配色**：石绿 `#16281c` / 苔绿 `#2b3b32` / 黄铜 `#c98a3c` / 火把琥珀 `#f0b64b` / 羊皮纸 `#f6ecd6`。
- **服装**：做旧皮马甲＋奶油亚麻衬衫（卷袖）＋黄铜扣宽腰带＋斜挎包带＋露指皮手套＋黄铜罗盘吊坠＋短披风。
- **装饰**：垂落藤蔓、火把暖光、黄铜罗盘、古金币、石雕浮雕、浮尘光斑、藏宝图卷角。
- **姿势偏好**：蹲姿手搭凉棚远眺、拨开藤蔓前倾、穿过高草大步走、坐在断柱上俯视。
- **实跑配方（`cn2-X1_xunluo_peitu.png` 1080×436 巡逻配图，2026-10-21 #14）**：
  `THEME=explore COMPOSITION=lock ALPHA_MODE=source WATERMARK=auto`，出图 1974×797（与原图比例 2.477 **完全一致，零 cover 裁切**），
  alpha 掩膜与源 100% 一致、上沿异形轮廓 0px 偏差，verify 8/8。
- **禁忌**：
  - **最容易被加字**：这个题材模型特别爱画地图虚线、「X」宝藏标记、罗盘刻度字母 ⇒ LAYOUT 必须写死「无任何文字/标记」；
  - 石绿背景 + 绿披风会把角色吃掉 ⇒ 角色边缘要暖色轮廓光，必要时 `FRAME_RIM=warm` 拉开明度；
  - **有异形透明上沿的图**（如本张 27.5% 透明、上沿是画的轮廓不是直线）：`ALPHA_MODE=source` + LAYOUT 明写「不许切平轮廓、不许在上沿外补天空、不许画矩形边框」；
  - **无空白 UI 区的整幅插画别套 `--frame card`**：会凭空造出一块空板，且把画缩进框内；
  - 金色时刻高光区可能被水印判据误伤，验收报「疑似水印」时先看 1:1 再决定 `--watermark off`。

---

## 2.9 构图三档：lock / free / design（2026-10-21 新增 design）

同一张图、同一个主题，能放开到什么程度是**另一根轴**（`--composition` / `COMPOSITION=`）。
三档放开的东西严格递增，锁的东西反而越来越少——所以每档的「护栏」必须单独写清楚：

| 档 | 放开什么 | 仍然锁什么 | 什么时候用 |
|---|---|---|---|
| `lock` | 只换衣服、配色、材质 | 姿势/位置/缩放/版式/文案 | 批量换皮，要求「一眼看不出重画过」 |
| `free` | 人物姿势、镜头、裁切 | 文案完整、底部 UI 空区、画布比例与透明边 | 人物图想更好看，但版面不能动 |
| `design` | **整张图的版面**：场景概念、构图、镜头、道具、装饰、前后景层次 | ① 画风一致 ② 画布比例 + 4% 安全边 ③ 文案策略（无字图不许造字） ④ UI 功能空区 | 想让 AI 当美术重做一张「更抓眼」的 key art（节日横幅、活动配图、商店头图） |

**design 档的四条硬边界写在 `layout_design` 里**（`theme_presets.json`，全主题共用）：

1. `DESIGN FREEDOM` —— 明确要求「不要照抄原版面」，目标是「滑到这张图会停下来」的那一版；
2. `HARD LIMIT - ART DIRECTION` —— 必须是**同一个画师**画的：线宽/线色、平涂两档赛璐璐、细节密度、
   脸/眼/发画法、道具与装饰的设计语言全部对齐；禁止厚涂、3D、写实、欧美卡通；
3. `HARD LIMIT - CANVAS` —— 保持原图宽高比（宽横幅还是宽横幅）、重要元素在 4% 安全边内、不加外框/黑边；
4. `HARD LIMIT - TEXT` —— **不画任何字**；只有原图本来有字时才逐字保留；
5. `HARD LIMIT - UI FUNCTION` —— 原图留给 UI 覆盖层的空区，位置/边距不变、保持低对比平静。

🔴 `themes --check` 会按关键词卡这四条（画风/比例/文案/UI），少一条直接红：design 放开了版面，
护栏就是唯一还挡在「好看但进游戏就废」之间的东西。
🔴 **design 档默认不注入 `pose_hints`**（姿势也归模型自主决定），只有显式 `--pose N/文字` 才注入；
`free` 档仍走随机池。同理 `--pose` 对 `lock` 无副作用。

**实跑配方（`cn2-X1_richang_banner_02.png` 1080×368 RGB，2026-10-21）**：
`THEME=christmas COMPOSITION=design ALPHA_MODE=keep FRAME=none WATERMARK=auto`，
文案策略走「原图无字 ⇒ 输出也不许有字」；出图后 `postprocess` 整幅 cover 归位 1080×368，
源是 RGB 所以写回 `--variant opaque`（别写成 RGBA）。

---

## 3. 四类图的参数配方（按图的形态选，不按主题选）

主题决定「画成什么」，图的形态决定「参数怎么配」。同一主题下这四类图的参数不能互相套用。

| 图类型 | 判据 | 关键参数 | 为什么 |
|---|---|---|---|
| **整幅不透明大底板** | `prepare` 打印「源资源是整幅不透明」/ alpha≈1.0 | `--alpha-mode keep --frame card --frame-rim violet` | 底板铺满面板，alpha 沿用源即可；紫框是项目统一口径 |
| **浮层（带透明轮廓）** | alpha 0.7~0.95、四角透明 | `--alpha-mode keep`（**不要 source**）+ 紫框 | 若沿用 source 掩膜，框的顶/底边会被整段切掉，只剩左右两条亮线（千抽底板第一次就踩了） |
| **超长条底板** | 高宽比 > 2（如 856×2048） | `--hero-band 930 --body-mode source` | 不能整幅 cover，会横切掉 37% 构图；只把「英雄带」喂给模型 |
| **自带亮带/渐隐的浮层** | 顶部柔化渐隐、右下亮装饰带、左下空文案板 | `--frame none --watermark off`（+ `refit_band.py`） | 套框会把渐隐段画成「框没画完」；inset 会啃掉文案板；亮带被水印判据误伤 |

`variant`（写回用哪个变体）**按源的模式自动选**：源是 `RGB` → `opaque`；源是 `RGBA` → `alpha`。  
🔴 把 RGB 资源写成 RGBA 会让纹理导入/压缩口径变化（799KB→1.6MB），肉眼看不出来但确实变了。

---

## 4. 新主题接入：7 步 checklist

```text
1) 改 scripts/image/theme_presets.json    ← 只加字段，不改代码
1b) 把新 key 加进 .jenkins/jobs/TS-Art-Restyle.groovy 的 THEME choices，跑 .jenkins/apply-jobs.sh --only TS-Art-Restyle
    （预设改了但下拉没加，命令行能跑、Jenkins 里选不到；2026-10-21 补 explore 时踩过）
2) python scripts/image/restyle_pipeline.py themes --check   ← 必须先绿
3) python scripts/image/restyle_pipeline.py prompt --theme <新主题> --composition free | head -40   ← 读一遍提示词通不通
4) 选一张「有代表性的图」单跑一组（prepare→gen→postprocess→verify），人眼过一遍
5) 把参数配方写回本文 §3 的表（哪类图要额外参数）
6) 批量：改 / 新建清单 json，先 --dry-run 看命令，再去掉 --dry-run
7) 写回后：Unity 里重打该资源所在 AssetBundle（FrameTool.BuildGameAssetBundles）
```

第 1 步要补的字段（缺一个 `themes --check` 就红）：

```jsonc
"<key>": {
  "zh": "中文名", "en": "english theme name（进 prompt，必须纯英文）",
  "suffix": "小写唯一",                       // 进文件名
  "palette": ["#rrggbb", "…>=3 个"],           // 主色卡
  "body_colors": ["#上色", "#下色"],            // 正好 2 个：合成下半截渐变用
  "decoration": ["人看的元素清单"],              // 不直接进 prompt
  "text_style": "只说字的材质/描边，不说内容，且必须提到 faces",
  "outfit": "服装描述（英文）",
  "body": "卡体/背景基底描述（英文）",
  "banner": "顶部视觉语气（英文）",
  "decor_sentence": "replace the … with …",     // 必须 replace 开头：讲「换掉什么」
  "pose_hints": ["…空手动作…", "…（opt-in prop）"],  // 3 条起，手持道具必须标 opt-in
  "notes": "中文备注：这个主题在哪些图上要额外参数"
}
```

`themes --check` 目前能拦：必填字段缺失、拼错的未知字段、`suffix` 大写/重名、`palette<3`、`body_colors≠2`、
非 `#RRGGBB`、**英文字段里混中文**（会让模型把汉字画上去）、`pose_hints` 出现手持动词但没标 `opt-in`、
`decor_sentence` 不以 replace 开头、`pose_hints` 条数过少。这些错误在出图阶段只会表现为「画得不对」，很难回头定位。

---

## 5. 🔴 姿势池：为什么「发挥想象力」却总是抱礼物

- **根因**：`theme_presets.json` 里原本是**单条** `pose_hint="… presenting a small gift box …"`，被 `build_prompt` 原样注入 free 构图 ⇒ 每张 free 图都是同一句「递出一个礼盒」。四个主题全中（圣诞礼盒 / 新年红包 / 万圣南瓜灯 / 情人节心形气球）。
- **现状**：`pose_hints` 数组，每次 `random.choice` 抽一条；`--pose N` 指定第 N 条，`--pose none` 不注入，其它文字＝自定义；实选的那句记在 `state.json.pose_hint`，Jenkins 同名参数 `POSE`。
- **硬约束**：`COMPOSITIONS["free"]` 里写了 `Hands must stay EMPTY: never invent an object and put it in her hands (the only prop she may hold is one the input artwork already shows)`。
- **约定**：LAYOUT 里**绝不再写「拿着 X」**——layout 是单图专用的一段话，写进去等于把随机池钉死。

---

## 6. 批量管线 `batch_restyle.py`

### 6.1 最小用法

```bash
PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python

$PY scripts/image/batch_restyle.py scripts/image/batch_example.json --dry-run      # 只看命令，不出图
$PY scripts/image/batch_restyle.py my.json --only chaozhilibao                     # 只跑名字含该子串的
$PY scripts/image/batch_restyle.py my.json --no-gen                                # 复用工作区已有 inbox/gen_web.png
$PY scripts/image/batch_restyle.py my.json --publish                               # 验收过就写回
$PY scripts/image/batch_restyle.py my.json --no-publish --fail-fast                # 只出图，第一组失败就停
```

产出：`_output/art_restyle/_batch/<时间戳>/`（`batch.log` / `summary.md` / `summary.json` / `logs/<slug>__<theme>.<step>.log`）。

### 6.2 清单结构

```jsonc
{
  "defaults": {
    "themes": ["christmas"],           // 默认主题列表（item 可覆盖）
    "composition": "lock",             // lock=姿势全锁；free=允许重设计
    "provider": "chatgpt_web",         // chatgpt_web / manual（指定现成图）/ skip（只做后处理）
    "gen": {"reuse_cdp": true, "port": 64757, "timeout": 420, "attempts": 1},
    "postprocess": {"watermark": "off", "alpha_mode": "keep", "frame": "card", "frame_rim": "violet"},
    "variant": "auto",                 // auto：RGB→opaque / RGBA→alpha
    "preview": true,
    "publish": false                   // 安全默认；项目口径是确认后传 --publish
  },
  "items": [
    {"assets": ["Assets/ManagedResources/ArtFont_*/XPanelAtlas/x_banner_*.png"]},   // glob：三语一起换
    {"asset": "…/y.png", "themes": ["christmas", "thanksgiving"]},                  // 一张图多主题
    {"asset": "…/z.png", "composition": "free", "pose": "none"},                    // 单图覆盖
    {"asset": "…/w.png", "provider": "manual", "gen_image": "/tmp/gen_w.png"}       // 用现成的图
  ]
}
```

### 6.3 表1：换皮大图台账（批量清单的源头）

`scripts/image/table1.json` + `scripts/image/table1.py`。所有**改过的大图（非标题类）**都在表 1 有一行，
记录 `kind`（diban/banner/peitu/panel）、`themes_done`（已换主题→日期）、`status`。

- **自动登记（主路径）**：`restyle_pipeline.py publish` 写回成功即调 `table1.record_publish()`——
  Jenkins `TS-Art-Restyle` 与 `batch_restyle --publish` 都走这个子命令 ⇒ **每次替换图片自动进表**；
  登记失败只报警，不影响写回结果。
- **批量出图**：`table1.py export --theme provence` 一键生成只含「还欠该主题」条目的批量清单
  （defaults 已带紫框口径），直接喂 `batch_restyle.py`。
- 手工补录/排查：`add` / `scan --since "3 days ago"`（从 git 历史找候选，自动滤标题/文字/图标/CV）、
  `list [--pending]`、`check`。

```bash
$PY scripts/image/table1.py list                     # 全量台账
$PY scripts/image/table1.py export --theme provence  # 导出批量清单 _output/art_restyle/_batch/table1_provence.json
$PY scripts/image/batch_restyle.py _output/art_restyle/_batch/table1_provence.json --dry-run
```

### 6.4 排期与额度纪律（重要）

- **出图是单浏览器串行的**：不要开两个批处理抢同一个 CDP 端口；一批跑完再换主题。
- **每组一次出图 = 一份额度**。`N 资产 × M 主题` 就是 N×M 次。先 `--dry-run` 数清组数。
- 额度/登录态失效时 `gen_chatgpt_web.py` 返回 `rc=3`，批处理会**停整批**并提示换 profile：
  在 AdsPower 里换一个已登录 ChatGPT 的 profile → `scripts/image/find_browser_cdp.py` 反查新端口 → 改清单 `gen.port` → 重跑剩下的（`--only` 或把已完成的从清单删掉）。
- 图其实已经画好、只是 driver 没认出来时，用 `gen.grab_existing: true`（或单跑 `--grab-existing`）**别再烧一次额度**。
- **建议排期**（每阶段先 1 张三语试色，再铺量）：
  1. 夏日冲浪 —— 与现有圣诞/新年反差最大，先验证「亮色 + 白浪泡沫」的验收阈值；
  2. 万圣节 —— 已有素材基础，姿势池最成熟；
  3. 感恩节 —— 与圣诞同档暖色，注意别混挑；
  4. 普罗旺斯 —— 低饱和，验收阈值要单独调；
  5. 赛博 —— 建议直接 `free` + `FRAME_RIM=ivory`，最后做（最吃重设计）。

---

## 7. 门禁与回滚（别跳）

```bash
$PY scripts/image/restyle_pipeline.py themes --check                 # 预设自检，红了别出图
$PY scripts/image/restyle_pipeline.py verify --work "$W"             # 像素级验收（尺寸/alpha/水印/构图未被裁）
$PY scripts/image/restyle_pipeline.py publish --work "$W" --variant auto --yes   # 原地覆盖 + 原图搬 ResBackpack/备份
$PY scripts/image/restyle_pipeline.py restore --asset Assets/.../x.png --list    # 先看有哪些备份版本
$PY scripts/image/restyle_pipeline.py restore --asset Assets/.../x.png           # 回滚
```

- `publish` 自带闸门：没有 `verify.json` 或验收有硬失败就拒绝写回（要跳过得显式 `--force`）。
- **写回 ≠ 进包**：真机要重打该资源所在 AssetBundle（`FrameTool.BuildGameAssetBundles`）。批量写回后，把涉及的图集一次性重打。
- 备份台账：`ResBackpack/备份/_manifest.jsonl`（每次写回/回滚各一条）。
