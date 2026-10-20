# 战令横幅「中文美术字 → 英文版」流水线

> 适用范围：TimeSpaceGirl1 · `Assets/ManagedResources/ArtFont_zh/OperatingPanelAtlas/` 下这批战令横幅
> （迷雾 / 爬塔 / 深渊 / 魔塔 / 异端，统一 884×544）
> 更新时间：2026-10-21
>
> 关联文档：**`docs/jenkins_ci.md`**（job 定义与验收口径）、**`docs/art_restyle_pipeline.md`**（换节日皮，另一条美术链）
> 执行口：`scripts/image/banner_translate.py` ｜ Jenkins job：**`TS-Art-Translate`**

---

## 0. 一句话

这批横幅的标题和文案是**烘进图里的中文艺术字**，不是 TMP 文本 —— 英文版只能重出一张图。
流水线做三件事：**自动圈污染区擦字 → 逐行中位色 + 六边形纹理补底板 → 按已上线英文图的层级排白字**，
最后用六条像素断言验收，再写回 `ArtFont_en` 并补 `.meta`。

```bash
python scripts/image/banner_translate.py scan          # 盘点：哪几张还缺英文版
python scripts/image/banner_translate.py batch --stage run
python scripts/image/banner_translate.py batch --stage verify
python scripts/image/banner_translate.py batch --stage publish
```

Jenkins 里点 **`TS-Art-Translate`**（`MODE=batch` 即可，缺哪张补哪张）。

---

## 1. 什么时候用 / 不用

| 用 | 不用 |
|---|---|
| `*_bg_zh.png` 战令横幅（884×544，三段文字同一套版面） | `*_peitu_zh.png` 无字配图（没文字可翻，`BANNER_GLOB` 已排除） |
| 已有中文版、缺英文版 | 想换节日/换风格（走 `docs/art_restyle_pipeline.md`） |
| 文案要改、图要重出 | 只想改 TMP 文本（改语言表就行，别动图） |

`BANNER_GLOB = "*_bg_zh.png"` 是硬编码的筛选口径。**新加一族横幅要么命名带 `_bg_`，要么改这个常量**。

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

---

## 4. 六条像素断言（`verify`）

| # | 断言 | 为什么是硬项 |
|---|---|---|
| 1 | 尺寸与源图一致 | 九宫格/布局按原尺寸摆，差一像素就错位 |
| 2 | alpha 与源图**逐像素**一致 | 原图带透明边；丢了在 Unity 里边缘露底 |
| 3 | **重建区外零改动** | 证明只动了该动的地方，装饰板/背景/底部电路图都没被碰 |
| 4 | 粉色像素 < 200 | 原标题是粉白渐变（`R-B>40`），英文是纯白 —— 有残留就说明没擦干净 |
| 5 | 黄色像素 < 200 | 原第二行是黄色（`R,G>200 且 B<150`） |
| 6 | 纯白像素 > 2000 | 反过来防「擦干净了但字没画上」 |

4/5 两条比「中文识别」靠谱得多：中文残留的颜色特征是确定的，而 OCR 在艺术字上不可靠。

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

---

## 6. 写回之后

- 目标：`Assets/ManagedResources/ArtFont_en/OperatingPanelAtlas/<名>_en.png` + 同族 `.meta`
- 已有同名文件时**默认跳过**（rc=3）；要覆盖必须 `FORCE=true`，旧图先进
  `ResBackpack/备份/ManagedResources/ArtFont_en/...`
- 🔴 **写回 ≠ 进包**：真机生效还要重打该资源所在 AssetBundle（`FrameTool.BuildGameAssetBundles`）

---

## 7. 已知瑕疵 / 下一步

- 标题右侧那段**蓝色光带压在蓝底上**的部分（x≈340..375），既不能用暗板色补、也不能用背景色补，
  目前保留成一块蓝色装饰块。要彻底干净必须有分层 PSD ——
  `ArtFont_en/.../cn2-X1_zhanling_yiduan_bg_en.psd` 只有 2 个合并图层，帮不上。
- 字号/位置是按这五张横幅调的。**换成别的版面（比如 1024×500 的活动 banner）要重新量 `LINE_TOPS`**，
  不能直接套。

---

## 8. 案例数据（2026-10-21）

| 横幅 | 重建区 | 耗时 | 验收 |
|---|---|---|---|
| 迷雾 `miwu_bg` | y 89..329 | 0.54s | 6/6 过 |
| 魔塔 `mota_bg` | y 89..329 | 0.48s | 6/6 过 |
| 异端 `yiduan_bg` | y 102..329 | 0.51s | 6/6 过 |

Jenkins `TS-Art-Translate` 首轮 #1（`WRITE=false`）UNSTABLE（还有 2 张没翻，符合预期），
#2 写回两张 → 因「开工盘点」当时判黄而 UNSTABLE（口径问题，已改），
#4 全绿：`开工盘点 / 生成英文图 / 像素级验收 / 写回 / 收尾清单 / 证据归档` 6 个环节全过。
