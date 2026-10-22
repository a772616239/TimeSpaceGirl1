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
| `*_bg_zh.png` 战令横幅（884×544，三段文字同一套版面） | `*_peitu_zh.png` 无字配图（没文字可翻，`BANNER_GLOB` 已排除） |
| 图集大图（`Atlas/**`，标题压在纯色板上） | 想换节日/换风格（走 `docs/art_restyle_pipeline.md`） |
| 小型单色美术字块（`ArtFont_zh/**`，≤700×500 且只有 1~8 种颜色，如页签） | 只想改 TMP 文本（改语言表就行，别动图） |
| 已有中文版、缺英文版 | 纯图标（彩色、alpha 是轮廓不是字）—— `_is_glyph` 会判掉，别硬塞 |

分派规则（`family_of`，按**源图自身特征**判，不看目录名）：

| 条件 | 族 | 出图 | 版面 |
|---|---|---|---|
| 在 `Atlas/` 下 | `atlas` | local 或 chatgpt_web | 白字核 + 纯色板自动定位 |
| `ArtFont_zh` 下、≤700×500 且单色 | `glyph` | **只能 chatgpt_web** | 模型重绘 → 归位到源图字块 bbox |
| 其余 | `artfont` | local 或 chatgpt_web | 三段版面锚点写死（884×544） |

`BANNER_GLOB = "*_bg_zh.png"` 仍是 artfont 族的筛选口径；atlas / glyph **走译名表白名单**
（`banner_translate_map.json` 里有 `lines` 的才做），因为这两个目录里绝大多数图没有中文要翻。

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
  ├─ gen_chatgpt_web.py  → Chrome 登录态 / AdsPower 换号链 / 额度台账（全在这支脚本里）
  └─ postprocess_glyph() → 抠墨迹 → 纯白 RGB + alpha → 归位到源图字块 bbox
```

🔴 **不要在 banner_translate.py 里再写一套换号/额度逻辑**：同一件事写两遍，两边必然漂移。
额度、登录态、台账、`--reuse-cdp` 全部交给 `gen_chatgpt_web.py`，这里只认 rc：
`0` 拿到图 / `3` 环境不可用（黄）/ `1` 硬失败。

| provider | 相关参数 | 什么时候用 |
|---|---|---|
| `chatgpt_web`（job 默认） | `CDP_PORT` / `ADSPOWER_PROFILES` / `GEN_IMAGE` | 字块（必需）；想把横幅/图集也交给模型重绘 |
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

- 目标：**整条相对路径镜像** `ArtFont_zh → ArtFont_en`（2026-10-22 起）：
  - `ArtFont_zh/OperatingPanelAtlas/x_bg_zh.png` → `ArtFont_en/OperatingPanelAtlas/x_bg_en.png`
  - `ArtFont_zh/DynamicActivityPanelAtlas/tab/y_zh.png` → `ArtFont_en/DynamicActivityPanelAtlas/tab/y_en.png`
  - `Atlas/LaddersTypePanelAtlas/z.png` → `ArtFont_en/LaddersTypePanelAtlas/z_en.png`
  🔴 以前 artfont 把目标目录写死成 `ArtFont_en/OperatingPanelAtlas`，只因为当时那一族恰好全在那儿；
  子目录里的字块会被写进错误的族目录 —— 图就位了客户端也找不到。
- glyph / atlas 的 `.meta` 直接拿**中文源图自己的 `.meta`** 当模板（同一图集、同一导入设置），
  只换 `guid`；artfont 横幅仍按「同族 bg_en → 同族 _en → 任意 _bg_en → zh 同族」挑。
- 已有同名文件时**默认跳过**（rc=3）；要覆盖必须 `FORCE=true`，旧图先进
  `ResBackpack/备份/ManagedResources/ArtFont_en/...`
- 🔴 **写回 ≠ 进包**：真机生效还要重打该资源所在 AssetBundle（`FrameTool.BuildGameAssetBundles`）
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

Jenkins `TS-Art-Translate` 首轮 #1（`WRITE=false`）UNSTABLE（还有 2 张没翻，符合预期），
#2 写回两张 → 因「开工盘点」当时判黄而 UNSTABLE（口径问题，已改），
#4 全绿：`开工盘点 / 生成英文图 / 像素级验收 / 写回 / 收尾清单 / 证据归档` 6 个环节全过。
