# 中文美术字「中文 → 英文版」流水线

> 适用范围：`Assets/ManagedResources/ArtFont_zh/` 下三族资源
> ① 战令横幅 `OperatingPanelAtlas/*_bg_zh.png`（迷雾/爬塔/深渊/魔塔/异端，统一 884×544）
> ② 图集大图 `Assets/ManagedResources/Atlas/**`（标题烘在一块纯色黑板上）
> ③ **美术字块 `ArtFont_zh/**` 里的小型单色图**（页签/竖排标题，如 180×96 的「原料收集」）
> 更新时间：2026-10-22（新增 `provider=chatgpt_web` + `glyph` 族）
>
> 关联文档：**`docs/jenkins_ci.md`**（job 定义与验收口径）、**`docs/art_restyle_pipeline.md`**（换节日皮，同一条出图链）
> 执行口：`scripts/image/banner_translate.py` ｜ Jenkins job：**`TS-Art-Translate`**

---

## 0. 一句话

这批图的文字是**烘进图里**的（中文艺术字，不是 TMP 文本），英文版只能重出一张图。流水线把
「出图」和「其余九件事」切开 —— 和图集换风格那条链（`TS-Art-Restyle`）同一套切法：

```
provider（谁画的）  →  归位（尺寸/alpha/字块 bbox）  →  像素级验收  →  写回 ArtFont_en + .meta
```

provider 有三档：`chatgpt_web`（默认，开 Chrome/AdsPower 用 GPT 重绘）、`local`（纯 OpenCV+PIL，
可复现）、`manual`（人交图）。**出图不可复现、要花额度、会因为登录态/网络失败**，所以它单独摘出去：
provider 挂了只黄一个环节，不污染其余证据。

```bash
python scripts/image/banner_translate.py scan                       # 盘点：哪几张还缺英文版
python scripts/image/banner_translate.py batch --stage run     --provider chatgpt_web
python scripts/image/banner_translate.py batch --stage verify
python scripts/image/banner_translate.py batch --stage publish
```

Jenkins 里点 **`TS-Art-Translate`**（`MODE=batch` 即可，缺哪张补哪张）。

---

## 1. 什么时候用 / 不用

| 用 | 不用 |
|---|---|
| `*_bg_zh.png` 战令横幅（884×544，三段文字同一套版面） | `*_peitu_zh.png` **纯插画**配图（确实一个字都没有）—— 但别按文件名判，见下方红字 |
| 图集大图（`Atlas/**`，标题压在纯色板上） | 想换节日/换风格（走 `docs/art_restyle_pipeline.md`） |
| 小型单色美术字块（`ArtFont_zh/**`，≤700×500 且只有 1~8 种颜色，如页签） | 只想改 TMP 文本（改语言表就行，别动图） |
| 全幅活动海报（`DynamicActivityPanelAtlas/banner/*_zh.png`，884×856 不透明，插画+彩带+两行字） | 纯图标（彩色、alpha 是轮廓不是字）—— `_is_glyph` 会判掉，别硬塞 |
| **会员特权卡**（`OperatingPanelAtlas/*_huiyuan_peitu_zh.png`：820×860 / 884×1480 竖版异形卡，彩带+巨型美术字，**与 poster 同结构**） | —— |
| 已有中文版、缺英文版 | —— |

🔴 **`_peitu_zh` 不等于「没字」（2026-10-22 实测）**：`BANNER_GLOB = "*_bg_zh.png"` 只圈**战令横幅族**的候选，
不代表这一类文件无字。`cn2-X1_zhongshenhuiyuan_peitu_zh.png`（884×1480）与
`cn2-X1_zhizunhuiyuan_peitu_zh.png`（820×860）都是会员特权卡，三条中文美术字烘在彩带上，
`family_of` 按尺寸（宽 ≥800 且高 ≥700）判成 **poster 族**，走整幅重绘。
判族只看**源图自身特征**，永远不要按文件名猜。

分派规则（`family_of`，按**源图自身特征**判，不看目录名）：

| 条件 | 族 | 出图 | 版面 |
|---|---|---|---|
| 在 `Atlas/` 下 | `atlas` | local 或 chatgpt_web | 白字核 + 纯色板自动定位 |
| `ArtFont_zh` 下、≤700×500 且单色 | `glyph` | **只能 chatgpt_web** | 模型重绘 → 归位到源图字块 bbox |
| 宽 ≥800 且高 ≥700（884×856 那一档） | `poster` | **只能 chatgpt_web** | 模型整幅重绘 → 等比 cover 回原尺寸 |
| 其余 | `artfont` | local 或 chatgpt_web | 三段版面锚点写死（884×544） |

三条尺寸带互不重叠（字块 ≤700×500 / 战令横幅 884×544 / 海报 884×856），所以用尺寸判就够，
不必看目录名 —— 以后 `banner/` 里换了别的尺寸也不会被误当成 884×544 的战令横幅去套锚点。

`BANNER_GLOB = "*_bg_zh.png"` 仍是 artfont 族的筛选口径；atlas / glyph / poster **走译名表白名单**
（`banner_translate_map.json` 里有 `lines` 的才做），因为这几个目录里绝大多数图没有中文要翻。

---

## 2. 译名从哪来（不要自己造）

单一真源：`scripts/image/banner_translate_map.json`。key 是 zh 文件名，值含 `title` / `lines`。

| 中文 | 英文 | 依据 |
|---|---|---|
| 迷雾计划 | The Mist Plan | 语言表 `~Lua/Config/Data/Language.lua` |
| 魔塔计划 | Magic Tower Plan | 同上 |
| 异端计划 | Heresy Project | 同上 |
| 深渊计划 | Abyss Project | 已上线英文图 `shenyuan_bg_en` |
| 爬塔计划 | Tower Plan | 已上线英文图 `pata_bg_en` |
| 解锁高级战令 | UNLOCK / ADVANCED / BATTLE PASS | 已上线英文图（三行） |
| 累计返利 __ 倍 | ——（**不排**） | `pata_bg_en` / `shenyuan_bg_en` 都把它删了，留给 UI 动态数字 |

🔴 **已上线英文图的用词与语言表不一致时，以已上线图为准**（深渊/爬塔就是这种情况）。
改译名只改 JSON，不要改代码里的字符串。

---

## 3. 配方：三个环节各自的判断规则

### 3.1 擦字 —— 为什么不能按矩形硬切

横幅左侧暗板上叠着一块**斜的深色装饰板**（在标题右端 x≈345 之后）。
按矩形框整片擦，会把这块装饰切出一条垂直直边；放大看就是「贴了张灰纸」。

所以污染区是**内容驱动**圈出来的（`contaminated_mask`）：

```
污染 = (max(R,G,B) > 110)  OR  (B - max(R,G) > 60)
```

- 第一项抓白/黄/粉的字（原标题是粉白渐变，第二行是黄色，第三行是白色）
- 第二项抓**蓝色光带与蓝色斜杠**（它们和暗板的区别在「蓝得发亮」，不在亮度）
- 圈完 `dilate 15` + `close 25`，把发光和立体阴影一起吞掉

重建区横向硬界 `ZONE_RIGHT = 342`：中文标题最右到 x≈336，再往右是装饰板，**一个像素都不能碰**。

### 3.2 补底板 —— 逐行中位色 + 六边形纹理

暗板是「竖向渐变 + 六边形网格」，不能用 cv2.inpaint 硬填（实测会糊成一团、还带粉色残影）。

1. **逐行底色**：对每一行，取「不在污染区且 `max(R,G,B) < 110`」的像素的中位色。
   整行都被污染的（蓝色光带那几十行）用上下相邻行线性插值。
2. **纵向平滑**：对每通道 `GaussianBlur(σ=8)`，去掉逐行跳变。
3. **六边形纹理**：从重建区**下方**的干净带（`y1+8` 起 60px 高）取高频
   （原图 − `Blur(σ=6)`），**镜像平铺**（`mirror_tile`，不是 `np.tile` —— 直接 tile 每 60px 一道横缝）后按 `0.75` 叠回。
4. **羽化**：污染遮罩 `Blur(σ=5)`，上下各收 8px，右界 332→342 渐隐。

### 3.3 排字 —— 跟已上线英文图对齐

| 元素 | y | 字号 | 颜色 |
|---|---|---|---|
| 小标题（`title`） | 124 | 34 | 白 |
| 第 1 行 | 166 | 54 | 白 + 蓝辉光 |
| 第 2 行 | 217 | 54 | 白 + 蓝辉光 |
| 第 3 行 | 268 | 52 | 白 + 蓝辉光 |
| 第 4 行（备位） | 316 | 46 | 白 + 蓝辉光 |

左边界 24、`MAX_WIDTH = 306`（放不下就自动降字号，`fit_font`）。

🔴 **辉光必须裁在重建区内**（`ImageChops.multiply` 乘一个矩形蒙版）。
模糊半径 9，不裁会溢到 x>342 的装饰板上，直接破坏「重建区外零改动」那条断言。

### 3.5 provider = `chatgpt_web`（绘图管线，2026-10-22 加）

`local` 那套是本地像素工序，可复现、可回归，但**画不出原图的笔势**。所以小型单色字块
（`glyph` 族）必须让模型重绘 —— 这里直接复用图集换风格那条链的出图通道：

```
banner_translate.py --provider chatgpt_web
  ├─ build_prompt()      → work/prompt.txt（只描述「怎么翻」，不写死像素坐标）
  ├─ _flat_ref()         → work/inbox/ref_flat.png（白底黑字，放大 4 倍）
  ├─ gen_chatgpt_web.py  → Chrome 登录态 / 同号换 gemini / AdsPower 换号链 / 额度台账（全在这支脚本里）
  └─ postprocess_glyph() → 抠墨迹 → 纯白 RGB + alpha → 归位到源图字块 bbox
```

🔴 **不要在 banner_translate.py 里再写一套换号/额度逻辑**：同一件事写两遍，两边必然漂移。
额度、登录态、台账、`--reuse-cdp` 全部交给 `gen_chatgpt_web.py`，这里只认 rc：
`0` 拿到图 / `3` 环境不可用（黄）/ `1` 硬失败。

🔴 **第二通道（2026-10-26 起默认开）**：GPT 额度用尽时**先不换号**，在同一个浏览器上换
gemini 再画一次（参考图/提示词沿用本张的 `ref_flat.png` + `prompt.txt`），两条都空才换号。
本脚本只负责转达开关：`--second-provider gemini|none`（默认取环境变量 `SECOND_PROVIDER`，
库里默认就是 `gemini`）。job 侧是 `TS-Art-Translate` 的 `SECOND_PROVIDER` / `GEM_TIMEOUT`。

🔴 **出图节奏（2026-10-30 起）**：Google 号因「46 秒一张、峰值 32 张/小时」被封之后，
`gen_chatgpt_web.py` / `gen_gemini.py` 每次生成前都过 `scripts/image/gen_pace.py` 的闸门
（同号 ≥180s ±抖动、≤10 张/小时、≤50 张/天），并每 40 分钟发一条纯文本请求保活会话。
本脚本不用管（限速在收口层），但要知道**batch 补图会慢 3~4 倍**、超时已从 75 抬到 150 分钟；
口径与调参见 `docs/art_restyle_pipeline.md` 的「出图节奏闸门」一节。

| provider | 相关参数 | 什么时候用 |
|---|---|---|
| `chatgpt_web`（job 默认） | `CDP_PORT` / `ADSPOWER_PROFILES` / `GEN_IMAGE` | 字块 / 海报（必需）；想把横幅/图集也交给模型重绘 |
| `local`（脚本默认） | —— | 884×544 横幅、纯色板图集；要可复现的回归 |
| `manual` | `GEN_IMAGE`（留空则只出参考图+提示词） | 额度空了、或要人挑一张 |

### 3.6 glyph 归位 —— 模型只负责「画」，位置/尺寸/alpha 全是本地的

模型给的是**新画布**（实测 1717×916、1024×1024 都有），字块在里面的位置与大小跟原图无关。
游戏是拿这张图当 sprite 摆在固定锚点上的，位置一偏页签就错开。所以：

1. **抠墨迹**：`ink = |px − 全幅中位色|`，按 `28..110` 线性映射成 alpha（保留抗锯齿边；
   二值化会把笔画啃出锯齿）。
2. **归位**：裁到墨迹 bbox → **等比 contain** 缩进源图字块 bbox → 居中贴上。
   🔴 不拉伸（模型改了比例时宁可小一圈），也不整幅 cover（会把字放大到出框）。
3. **染白**：RGB 一律 `(255,255,255)`。游戏侧靠 tint 上色，图里带颜色反而串色。

`ink_mask.png` 落盘当证据；`state.json` 记 `gen / gen_bbox / src_bbox / scale / iou / ink_px`。

### 3.7 poster 族（884×856 全幅海报，2026-10-22 加）

`DynamicActivityPanelAtlas/banner/` 下那 18 张活动海报：**插画打底 + 斜切彩带 + 两行美术字**，
没有 alpha、没有纯色底板、也没有可写死的版面锚点 —— `local` 那套在这里一件也用不上
（排字能排，但彩带的角度、渐变、描边、辉光全都复刻不出来）。所以：

```
build_prompt(poster)   → POSTER_PROMPT（点名「彩带的形状/位置/角度/描边/阴影都不许动」）
gen_chatgpt_web.py     → 同一条 Chrome/AdsPower 链
postprocess_photo()    → 等比 cover 回 884×856（🔴 不能 contain：海报是满幅的，留边会露底）
```

`postprocess_photo` 只做尺寸和 alpha 两件事：`cover` 缩放 + 居中裁 + 把源图的 alpha 通道贴回去
（源图是 RGBA 时这样做，等价于「透明轮廓 lock」；CIYUANYINQING 这张是 RGB，直接原样 cover）。

口径参考：同族已上线的 `cn2-X1_zhutihuodong_liutianmowang_en.png` 也是「整幅重绘 + 贴回 alpha」，
与中文版逐像素比是 **73.6% 改动 / 平均差 128**（插画和彩带都是模型重画的）。这说明这条链的
预期就是「重画一张同构的图」，而不是「只在原图上换字」—— 断言口径必须按这个来定（见 4.3）。

---

## 4. 像素断言（`verify`）

口径按「provider × family」两维选：本地工序一套（下面六条），模型出图一套（4.2）。

### 4.1 本地工序（`local`）的六条断言

| # | 断言 | 为什么是硬项 |
|---|---|---|
| 1 | 尺寸与源图一致 | 九宫格/布局按原尺寸摆，差一像素就错位 |
| 2 | alpha 与源图**逐像素**一致 | 原图带透明边；丢了在 Unity 里边缘露底 |
| 3 | **重建区外零改动** | 证明只动了该动的地方，装饰板/背景/底部电路图都没被碰 |
| 4 | 粉色像素 < 200 | 原标题是粉白渐变（`R-B>40`），英文是纯白 —— 有残留就说明没擦干净 |
| 5 | 黄色像素 < 200 | 原第二行是黄色（`R,G>200 且 B<150`） |
| 6 | 纯白像素 > 2000 | 反过来防「擦干净了但字没画上」 |

4/5 两条比「中文识别」靠谱得多：中文残留的颜色特征是确定的，而 OCR 在艺术字上不可靠。

### 4.2 出图族（`chatgpt_web`）的断言

模型重绘之后，「重建区外零改动」这条不再成立（整幅都是新画的），所以换成这五条硬项：

| # | glyph 族（美术字块） | 为什么是硬项 |
|---|---|---|
| 1 | 尺寸与源图一致 | 页签按原图尺寸摆，差一像素就错位 |
| 2 | **四角仍是透明的** | 模型若把底/框画进来，四角会变实 —— 这条专抓「带背景交图」 |
| 3 | 墨迹量在源图的 35%~200% | 太少＝只画了个小标记；太多＝抠成了一片糊 |
| 4 | 字色为纯白 RGB255 | 游戏侧靠 tint 上色，图里带颜色会串色 |
| 5 | 出图主体占画布 ≥ 5% | 太小说明模型只画了个角标，放大满 bbox 后就是一团糊 |

| # | 整幅图（artfont / atlas 走模型） | 为什么是硬项 |
|---|---|---|
| 1 | 尺寸一致 / alpha 与源逐像素一致 | 透明轮廓沿用源图（lock 语义） |
| 2 | 改动像素 ≥ 2% | 防「模型把原图原样返回」 |
| 3 | 改动像素 ≤ 75% / 平均通道差 ≤ 45 | 翻译不该把背景重画 |

🔴 **「译文对不对」没有自动闸门**：手写美术字上 OCR 不可靠，拿它判红绿只会假红。
所以出图族的验收会登记 `warn`（构建标黄），**必须人眼看 `compare.png`**。
字形 IoU（译文 vs 原文）只记录不当红 —— 两批字本来就不是同一批字形，实测 0.15~0.47 都正常。

### 4.3 poster 族：整幅重绘能自动担保什么

海报是整幅重画的，「背景零改动」这条不成立（同族上线品实测 73.6% 改动），所以沿用整幅口径
再加两条，硬项共 6 条：

| # | 断言 | 为什么是硬项 |
|---|---|---|
| 1 | 尺寸与源图一致（884×856） | 面板按原尺寸摆 |
| 2 | alpha 与源图逐像素一致（RGB 源图跳过） | 透明轮廓 lock |
| 3 | 改动像素 ≥ 2% | 防「原图原样返回」 |
| 4 | 改动像素 ≤ 75% | 防「重画成另一张海报」 |
| 5 | **上 45% 区域改动 ≥ 3%** | 彩带就在上半部；这条专抓「模型把字挪走/干脆没画」 |
| 6 | **四边背景未被重绘**（上 40 / 下 30 / 左右 40px，平均差 ≤ 25 且改动 ≤ 20%） | 这一圈里没有文字，只能原样 —— 整幅重渲染最先在这里露馅 |

🔴 **「整体平均通道差 ≤45」在这族里没有判别力，已降级为 warn**（2026-10-22 实测，口径错配）。
彩带 + 美术字占掉大半张画布，只换字也会把整幅均值抬到 60 上下：
`cn2-X1_jingyinghuodong_banner_12`（884×336，几何底 + 黑色斜切彩带）改动 29.9% / 平均差 59.2，
而**四边背景只有平均差 11.3（改动 9.4%）—— 背景一点没动**。拿整幅均值当硬闸门，等于把
「彩带够大」判成「重绘了背景」，把好图全判红。同一张用更严提示词重出的第二版，四边反而退化到
26.5 / 17.1%，所以第 6 条才是这条链真正要守的边界：**换字可以，边框里的背景帧必须原样**。

第 5/6 条是 poster 独有的。它们不能更严 —— 彩带本身也在重画，改动量本来就大；
再严只会把成品全判红，等于没有闸门。

🔴 **第 6 条有个前提：边圈里得真的是「背景」。异形透明卡不成立**（2026-10-22 实测）。
`cn2-X1_zhongshenhuiyuan_peitu_zh.png`（884×1480 竖版会员卡）四边 **79%~92% 是 alpha=0**，
剩下那点可见像素是卡自己的描边 + 辉光带，整幅重绘必然让它整体位移 1~2px——肉眼确认四边内容
一个字没少的成品，第 6 条照样测出 **54.2 / 31.1%**（上限 25 / 20%）。所以现在按
`POSTER_EDGE_MIN_OPAQUE = 0.50` 先量边圈可见像素占比，低于它就直接判**不适用**并打 warn，
不再开红；那张卡的硬项实际是 5 条（尺寸 / alpha / 改过 / 没整幅重画 / 上 45% 动过）。

同一条链上还有两处必须按 alpha 掩膜统计（`_visible_mask`），否则透明图必假红：
透明区 `RGB` 是导出残留（实测 `(0,0,0)`），而参考图是按 `_flatten` 的深底 `(28,30,44)`
合成喂给模型的 ⇒ 出图那圈 RGB 天然差 44 > 24。**改动比例 / 四边背景 / 整幅均值一律只算
`alpha > 8` 的可见像素** —— alpha 本身另有逐像素 lock 硬项，「模型把底画满」跑不掉。

另外，异形卡的宽高比常常很极端（0.597 竖版），英文比中文长 3~4 倍，**提示词必须显式给
「宽度上限」**：写明「每条英文的横向跨度不得超过它替代的中文那句，超了就压字距/降字高，
绝不许把彩带、卡片拉宽」，并逐条点名「右边至少留 30px 金卡 / 离彩带右尖至少 20px」。
只写「condense the letters」实测不够——模型会把整行铺到彩带外面去。

---

## 5. 坑位（都踩过）

1. **`yiduan_bg2_zh.png` 只有 100×100**。工程里它是张占位图，跑起来会在补底板时炸
   `operands could not be broadcast (100,342,3) (100,100,1)`。
   现在 `cmd_run` 有尺寸闸门（宽<600 或高<400 → rc=3 跳过，只标黄）。
2. **`.meta` 模板不能随便抓第一份**。`chaozhijj_diban_en` 与 `zhanling_pata_bg_en` 的导入设置差了
   `filterMode` / `spriteMeshType` / `applyGammaDecoding` / 平台 override 四项。
   `ensure_meta` 的挑模板顺序：**同族 bg_en → 同族 _en → 任意 _bg_en → zh 同族 → 兜底**。
   正确结果应该和 `cn2-X1_zhanling_pata_bg_en.png.meta` 只差 `guid`。
3. **Groovy 布尔参数**：`buildWithParameters` 传进来的可能是字符串 `"false"`，
   非空字符串为真 ⇒ 一律 `.toString().toLowerCase() == 'true'`（`TS-Art-Restyle` 踩过）。
4. **`$VAR` 后紧跟全角标点 = unbound variable**（`.jenkins/lint.sh` ① 会查）。
   job 里一律写 `${VAR}` 或加空格。
5. **别在 python 里重复登记环节结论**：`run_stage.sh` 已经登记一行，python 再 `register()` 一次
   会出现两行同名结论（第 2 轮构建就是这个现象）。逐张的细粒度结论才由 python 登记。
6. **构建颜色语义**：`① 开工盘点` 用 `--strict-ok` 永远算通过（有活要干不是缺陷）；
   最终颜色由 `⑤ 收尾清单` 定 —— 还有没翻的就黄，全齐才绿。
   `WRITE=false` 时图只落在 `_output`，收尾必然黄，这是对的。
7. **别把透明 PNG 直接喂给模型**。白字 + 透明底，聊天窗口按白底预览 ⇒ 模型看到白纸。
8. **「深底白字」的参考图也不行**（2026-10-22 实测）。提示词写「忽略深底、输出纯白字」，
   模型仍然交回**白底白字**：整张 1717×916 几乎全白，只剩笔画描边的淡灰轮廓，
   抠出来是一条噪点带 —— 而当时五条断言居然过了（墨迹量 78%）。
   现在参考图是**白底黑字**（`_flat_ref`），并要求输出也黑字白底，回来统一染白。
   同时 `postprocess_glyph` 加了「墨迹 < 1% 直接判死」的闸门。
9. **`--only` 的名字要归一化**：atlas 图没有 `_zh` 后缀，`_name_keys` 三种写法都认；
   glyph 图带 `_zh.png`，写重叠前缀（如 `yuanliaoshouji`）命中两张是**对的**，别当 bug。
10. **`WORK_ROOT` 目录名会撞**：glyph 与 artfont 都用「去掉 `_zh.png` 的名字」当目录。
    同名的两张图（不同图集）会互相覆盖 `src.png`，对比图就变成「新版 vs 新版」。
    `batch --only` 只会命中当前工程里真实存在的路径，手工跑单张时注意别混。
11. 🔴 **复用已登录浏览器时，driver 会把上一张图交回来**（2026-10-22 实测，最贵的一次坑）。
    切完「新对话」页面还短暂渲染着上一轮的生成图，而选图按「面积最大」挑 —— 两张都是
    1717×916 时 `reduce` 保留第一个 ⇒ 拿到**上一张**。两张任务的 `gen.png` 逐字节相同，
    而五条断言**全绿**（尺寸对、墨迹量 65%、纯白也对）。两处已修：
    - driver：发送前记下页面上已有的生成图（按 blob `src`），之后只认「新出现的」，且**取最后一张**；
    - `banner_translate.py`：`check_gen_reuse()` 按 sha256 记台账（`_output/art_translate/_gen_ledger.json`），
      同一张出图落到**另一个资源**上直接拒收（rc=1）。
    🔴 断言量的是「图长什么样」，量不出「这张图是不是这次的」—— 内容哈希这一层不能省。
12. **`--work-dir` 复用会留下旧证据**：`batch --stage verify/publish` 是按 `state.json` 走的，
    重出图但没重跑 `run` 时，`verify` 验的还是上一版。改完口径记得 `--force` 重跑 run。

---

## 6. 写回之后

- 目标：**平铺在族目录根下，丢掉 zh 侧的一切子目录**：
  - `ArtFont_zh/OperatingPanelAtlas/x_bg_zh.png` → `ArtFont_en/OperatingPanelAtlas/x_bg_en.png`
  - `ArtFont_zh/DynamicActivityPanelAtlas/tab/y_zh.png` → `ArtFont_en/DynamicActivityPanelAtlas/y_en.png`
  - `ArtFont_zh/DynamicActivityPanelAtlas/banner/z_zh.png` → `ArtFont_en/DynamicActivityPanelAtlas/z_en.png`
  - `Atlas/LaddersTypePanelAtlas/z.png` → `ArtFont_en/LaddersTypePanelAtlas/z_en.png`
  （族目录 = `ArtFont_zh/` 或 `Atlas/` 之后的第一段。）

  🔴 **不能按 zh 相对路径把 en 也镜像到子目录**（2026-10-22 第一版就是这么写的，已回退）：工程既有
  60+ 张 en 图**全部平铺在族目录根**（`ArtFont_en/DynamicActivityPanelAtlas/cn2-X1_wmsr_yeqian_01_en.png`
  的 zh 原件在 `tab/` 下）；更硬的理由是 `resPathList` 是**手工维护**的目录白名单
  （868 条，一个目录 = 一个 AB），`ArtFont_en/DynamicActivityPanelAtlas/tab` **不在里面** ⇒
  重扫整目录跳过 ⇒ resName 永不登记 ⇒ 真机白图，而 `verify` 全绿、人眼在工程里也看得见图。
  现在 `publish` 有闸门 `check_target_registered`：目标父目录不在 `resPathList` 里直接 rc=1 拦下。
- glyph / atlas / poster 的 `.meta` 直接拿**中文源图自己的 `.meta`** 当模板（同一图集、同一导入设置），
  换 `guid` **和 `spriteID`**（只换 guid 会让两份资源共用 spriteID，SpriteAtlas 打包变体会互相顶掉）；
  artfont 横幅仍按「同族 bg_en → 同族 _en → 任意 _bg_en → zh 同族」挑。
- 已有同名文件时**默认跳过**（rc=3）；要覆盖必须 `FORCE=true`，旧图先进
  `ResBackpack/备份/ManagedResources/ArtFont_en/...`
- `publish` **不信 `state.json` 里记的 `en` 路径**，按当前规则重算 —— 规则改过之后，旧 state 会把
  人带回老位置，「图写了但目录没登记」这种错只有真机才发现。
- 🔴 **写回 ≠ 进包**：真机生效还要重打该资源所在 AssetBundle（`FrameTool.BuildGameAssetBundles`）。
  `publish` 会顺手查 `resName` 是否已在 `resInfoList` 里，没有就打印 `⏳ 未登记` + 该重打哪个目录的 AB。
- 🔴 **写回 ≠ 生效**：客户端要显示英文还要求调用点走 `GetPictureFont(...)`，且该 `resName` 在
  `ResourcePathConfig.asset` 有登记。glyph 这批源图**名字带 `_zh` 后缀**，正好符合
  `GetPictureFont` 按 `GetLan()` 拼 `_en` 的规则；万一以后遇到**不带后缀**的中文原图，
  那套拼名会拼出不存在的文件（整块变白），必须改用条目上的显式字段 —— 见 `MEMORY.md` 的那条红线。

---

## 7. 已知瑕疵 / 下一步

- 标题右侧那段**蓝色光带压在蓝底上**的部分（x≈340..375），既不能用暗板色补、也不能用背景色补，
  目前保留成一块蓝色装饰块。要彻底干净必须有分层 PSD ——
  `ArtFont_en/.../cn2-X1_zhanling_yiduan_bg_en.psd` 只有 2 个合并图层，帮不上。
- 字号/位置是按这五张横幅调的。**换成别的版面（比如 1024×500 的活动 banner）要重新量 `LINE_TOPS`**，
  不能直接套。
- glyph 的笔画**粗细只能靠模型自己拿**：我们只把字块等比装回原 bbox，粗细比例不强制。
  实测（01）墨迹量 65% 源图、IoU 0.41 —— 笔画比原中文略细，肉眼可接受但要人看。
  想更接近原粗细，改提示词里 "same stroke weight" 那句比改代码有效。

---

## 8. 案例数据

### 8.1 本地工序（2026-10-21）

| 横幅 | 重建区 | 耗时 | 验收 |
|---|---|---|---|
| 迷雾 `miwu_bg` | y 89..329 | 0.54s | 6/6 过 |
| 魔塔 `mota_bg` | y 89..329 | 0.48s | 6/6 过 |
| 异端 `yiduan_bg` | y 102..329 | 0.51s | 6/6 过 |

### 8.2 glyph + `chatgpt_web`（2026-10-22）

| 资源 | 出图 | 归位 | 耗时 | 验收 |
|---|---|---|---|---|
| `yuanliaoshouji_01_zh`（180×96，单行斜排） | 1717×916 | 缩 10.0% → bbox 162×75，墨迹 3351px（65%）、IoU 0.407 | 47s | 5 硬项过 + 2 warn |
| `yuanliaoshouji_02_zh`（152×120，两行+三角） | —— | —— | —— | 见下一轮 |

- 首轮（01）出的是**白底白字**：`gen.png` 整张近全白，只剩笔画描边的淡灰轮廓。
  这就是第 3.5 节「参考图必须白底黑字」那条的由来。
- 换号链真实生效：本机 Chrome `Profile 5` 额度用尽（台账封锁到 18:19）→ 自动接上已开着的
  SunBrowser `64227` → 出图成功。**全程没人工介入**。

### 8.3 poster + `chatgpt_web`（2026-10-22）

| 资源 | 出图 | 归位 | 耗时 | 验收 |
|---|---|---|---|---|
| `ciyuanyinqing_banner_zh`（884×856，插画+彩带+两行字） | 1275×1234 | cover 0.69 → 884×856，改动 26.8%、平均差 37.6 | 74s | 6 硬项过 + 2 warn |

译名 `Complete Tasks / Collect Precious Materials`（沿用「原料收集」页签的 MATERIAL/COLLECT 口径）。
一次成功，没有重出：彩带的形状/角度/描边、三件材料图标、背景插画都保住了，只有字母换了。

对照：同族已上线的 `liutianmowang_en` 改动 **73.6%**、平均差 128（那张是模型重画了整幅），
本张只有 26.8% —— 说明「按同一张图画」时模型能贴着原画面走，不必整幅重绘。
口径参考就摆在这里：**改动比例不是越小越好，而是必须落在 2%~75% 这条带里**。

Jenkins `TS-Art-Translate` 首轮 #1（`WRITE=false`）UNSTABLE（还有 2 张没翻，符合预期），
#2 写回两张 → 因「开工盘点」当时判黄而 UNSTABLE（口径问题，已改），
#4 全绿：`开工盘点 / 生成英文图 / 像素级验收 / 写回 / 收尾清单 / 证据归档` 6 个环节全过。

---

## 9. 会员特权卡（`*_huiyuan_peitu_zh.png`）案例（2026-10-22）

同族两张，都归 poster：`cn2-X1_zhongshenhuiyuan_peitu_zh.png`（884×1480）、`cn2-X1_zhizunhuiyuan_peitu_zh.png`（820×860）。
版面骨架固定：**顶部白色斜切彩带 + 斜卡上的巨型两字美术字（下面已印英文 `PRIVILEGE`）+ 底部横彩带**。

| 项 | 值 |
|---|---|
| 字号顺序 | 彩带小字（大字块级）→ 巨型美术字（整张主角）→ 底部彩带小字 |
| 版面写法 | `gpt_layout` 里逐条点名「哪条彩带 + 像素范围 + 哪个英文不许动」；底部那条要写死**文字右边界**（至尊卡 = 停在钻石图标 x464 之前，右侧 x510~760 是 UI 价格位） |
| 出图耗时 | 98s（`chatgpt_web`，一次成，无重出） |
| 验收 | 8 环节 7 过 + 1 warn（UNSTABLE）—— 那条 warn 是 poster 族常规四项，均为**参考/记录**，不判红 |
| OCR 旁证 | 相似度 0.74，且把 `PRIVILEGE` / `VIP` 也读进来了 ⇒ **别拿 OCR 分数定生死**，poster 族本来就不判红 |

🔴 **poster 的「四边背景未重绘」闸门对会员卡永远不适用**：异形透明卡边圈只有 18% 可见像素
（`POSTER_EDGE_MIN_OPAQUE = 0.50`），实测那圈平均差 127 / 改动 78%，但肉眼一个字没少。
实际硬项只有 5 条（尺寸 / alpha / 改过 / 没整幅重画 / 上 45% 动过）—— 判定时别被这条带偏。
