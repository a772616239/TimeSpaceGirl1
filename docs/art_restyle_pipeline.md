# UI 美术资源「换节日风格」流水线（skill）

> 落地时间：2026-10-20（管线初版）／2026-10-20 晚（补「替换原图 + 原图搬出工程 + 超长条底板」）
> 入口：Jenkins job **`TS-Art-Restyle`** ／ 命令行 `scripts/image/restyle_pipeline.py`
> 已实战：`EightDayGiftPanelAtlas/cn2-X1_baridenglu_diban_en.png`（1080×1644 登录底板 → 圣诞版）
> 已实战：`OperatingPanelAtlas/cn2-X1_chaozhijj_diban_en.png`（856×2048 超值底板 → 圣诞版）

---

## 一句话

**出图那一步交给 provider（人 / Agent / 浏览器登录态），其余每一步都可断言**：去水印 → 尺寸归位（绝不拉伸）
→ 出「不透明版 + 沿用原 alpha 的浮层版」→ 像素级验收 → 可选写回（原图搬出工程到 `ResBackpack/备份`）。

为什么要这样切：出图不可复现、有随机性、还会因为网络/额度失败。把它单独摘出去，Jenkins 才能对
后面九步做红绿判定；provider 挂了只红一个节点，不污染其余证据。

---

## 命令速查

```bash
PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python
W=_output/art_restyle/<资源名>/<主题>

$PY scripts/image/restyle_pipeline.py themes                     # 列内置主题
$PY scripts/image/restyle_pipeline.py prompt --theme christmas   # 打印完整提示词（含参数）
$PY scripts/image/restyle_pipeline.py prompt --theme christmas --composition free   # 自由构图（人物可重设计）
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

退出码：`0` 通过 / `1` 失败 / `2` 用法错误 / `3` 需要人看一眼（Jenkins 里 `--warn-rc 3` → 黄，不阻断）。

---

## Jenkins `TS-Art-Restyle` 参数

| 参数 | 作用 |
|---|---|
| `ASSET` | 目标资源（相对工程根）。**目标尺寸取该图自身尺寸**，不填尺寸 |
| `THEME` | `christmas` / `newyear` / `halloween` / `valentine`。新增主题只改 `scripts/image/theme_presets.json` |
| `PROVIDER` | `chatgpt_web`（**默认**，用本机 Chrome 登录态驱动 chatgpt.com）／`manual`（图由人/Agent 出，放进 inbox 或用 `GEN_IMAGE` 指定） |
| `GEN_IMAGE` | manual 时显式指定生成图；留空取 inbox 里最新的 |
| `CDP_PORT` | 复用外部已登录浏览器（AdsPower/SunBrowser）的调试端口，`find_browser_cdp.py` 反查。留空=用本机 Chrome |
| `LAYOUT` | 构图锁文本。**每张图的文案不同，所以文案一定写这里，不要写进主题预设** |
| `COMPOSITION` | `lock`（默认，人物姿势/位置/缩放全锁，只换衣服与配色）／`free`（允许重设计人物姿势与镜头换吸引力）。见下节 |
| `PROMPT_OVERRIDE` | 整段覆盖提示词（LAYOUT 不够用时才用） |
| `HERO_BAND` | 超长条底板专用：英雄带像素高度（如 `930`）或 `auto`。留空=整幅等比 cover |
| `BODY_MODE` | `auto`（默认）/ `source` / `synthetic`，见下 |
| `ALPHA_MODE` | `source`（默认，只对 lock 成立）/ `keep` / `free`。**`COMPOSITION=free` 时 `source` 会把人脸裁掉**，会被自动改成 `keep`，见上节 |
| `FRAME` | `auto`（默认：free 套游戏卡框、lock 不套）/ `card` / `gold`（旧红金，兜底）/ `none`，见上节 |
| `FRAME_RIM` | 卡框最外的亮边：`warm`（默认暖金）/ `ivory` / `violet` / `none`。**深色面板上不画亮边 = 框看不见**，见上节 |
| `ALPHA_FROM` / `SOURCE_FROM` | 资源已被换过、工作区里没原版时，用 `git:HEAD:<path>` 取回参照 |
| `WRITE_BACK` | **替换原图**：验收通过后把 alpha 版写回资源，原图搬出工程。默认关 |
| `BACKUP_ROOT` | 备份根，留空 = `ResBackpack/备份` |

构建页能看到：环节表（JUnit）+ `summary.md` + 构建描述 + `artifacts/`（改前改后对比图、graph.md、
prompt.txt、state.json、published.json）。节点图由 `graph` 生成，链路
`prepare → generate → postprocess → verify → publish`，绿/红/灰三色。

---

## 构图自由度：`COMPOSITION=lock|free`

换节日风格时会长出来的两种诉求，用一档参数切：

| 档位 | 人物 | 文案 / 空白区 / 画布 | 适用 |
|---|---|---|---|
| `lock`（默认） | 姿势、位置、缩放、轮廓全锁，只换服装与配色 | 全锁 | 只换皮的批量活；出图可预期，返工率最低 |
| `free` | **可完全重设计**：新姿势、新镜头角度、位置/裁切/缩放都能动 | 仍锁死 | 要「一眼更吸引人」的运营位（登录底板、充值/活动 banner） |

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

| 值 | 含义 | 什么时候用 |
|---|---|---|
| `source`（默认） | 沿用源资源掩膜 | **只对 `lock` 成立**：轮廓没动，掩膜自然贴合 |
| `keep` | 整幅不透明 | `free` 的真实语义：人物换位置/变大了，源掩膜已经不贴合 |
| `free` | 整幅不透明 + 顶边渐隐 `--feather-top N` px | 想让上沿虚进面板背景时用（顶边贴人物时不建议，会糊掉帽子） |

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

| 出处 | 语言 |
|---|---|
| `X1PublicAtlas/cn2-X1_tongyong_daojukuang_01~07`（道具槽） | 深色渐变 + **菱形网格纹** + 细亮描边 |
| `cn2-X1_tongyong_yingxiongkuang_01~06`（英雄卡） | 实心色块 + **大斜切角** + 六边形 |
| `StoryDialoguePanelAtlas/cn2-X1_yindao_duihuakuang_02`（对话框） | 紫色色块 + **硬投影** |

`card` 就是照这三条拼的：**亮边 + 墨色细带（菱形纹）+ 四周切角 + 内侧柔影**。

🔴 **最外圈必须有亮边（`--frame-rim`）**：2026-10-20 第二版只有墨带，贴在八日礼包面板上
**框直接消失**（用户原话「遇到黑色的时候不明显」）。实测面板底 `(17,17,25)`，墨带 `(18,16,24)`
—— 同亮度，等于没画。游戏自己的槽位框正是这么解决的，剖面只有三档：

| 资源 | 剖面（从外到内） |
|---|---|
| `tongyong_daojukuang_01` | `57,61,74`×3px → **`238,240,243`×5px** → 槽内 `119,133,158` |
| `tongyong_daojukuang_04` | `59,26,75`×3px → **`222,182,255`×5px** → 槽内 `105,57,136` |
| `tongyong_daojukuang_05/06` | `75,38,26`×3px → **`255,227,182`×5px** → 槽内 |

即「暗带 3px + 亮边 5px」。所以 `card` 现在的结构是 **1px 暗描边 → 亮边（外侧最亮、内侧压一档，
模拟斜面受光）→ 1px 暗切 → 墨带 + 菱纹 → 3px 暗槽 → 画面**。判据：亮边跟面板底的亮度差 **≥100**。

| `--frame-rim` | 用在哪 |
|---|---|
| `warm`（默认） | 暖金 `255,238,200`。圣诞/新年这类暖色主题 |
| `ivory` | 银白 `244,246,250`。冷色/金属主题 |
| `violet` | 紫白 `206,158,246`。跟紫色面板同色系，最"服帖"（首版 `230,196,255` 偏灰白，用户要求「紫变深一档」后压深） |
| `none` | 不画亮边 —— 🔴 只在浅色底上用，深色面板上框会看不见 |

| 值 | 效果 |
|---|---|
| `auto`（推荐） | `free` 自动套 `card`，`lock` 不套（lock 本来就有透明轮廓，不需要） |
| `card` | 强制套游戏卡框。**画面等比缩进框内**（cover 到内框，最多裁 1~2% 边），框压在画布边界 |
| `gold` | 旧红金雕花框，仅兜底（游戏里没有这种语言，别再当默认） |
| `none` | 不套 |

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

### 额度用尽 / 换号：直接接上 AdsPower 的 SunBrowser

免费版的出图额度是**按账号**算的，当天的图出完了就得换号。换号**不搬 cookie、不改代码**，
把 driver 接到另一个已经登录好的浏览器上就行：

```bash
$PY scripts/image/find_browser_cdp.py            # 反查 CDP 端口 → best port=64757
$PY scripts/image/gen_chatgpt_web.py --image ... --prompt-file ... --out ... \
    --crop-height 930 --reuse-cdp --port 64757
```

- `--reuse-cdp` = **只连不断**：脚本不启动也不关闭浏览器（driver 里置 `PW_KEEP_BROWSER=1`，
  不走 `browser.close()`），不会把你手上的窗口关掉。
- driver 优先复用**已经开着的 chatgpt.com 标签**，没有才新开一个 —— 绝不导航走你正在看的页面。
- 🔴 AdsPower 的 `--remote-debugging-port` **不在命令行里**（随机高位端口 bind），免费版还调不了
  `/api/v1/user/list` 拿 `debug_port`。所以 `find_browser_cdp.py` 只能从「进程 → lsof 监听端口 →
  逐个试 `/json/version`」反查；`pgrep -fl 9333` 这条思路在这里完全不成立。
- 指纹浏览器自带代理/指纹，**不要**再传 `--proxy`（会把它的网络链路覆盖掉）。

Reuse 与自起 Chrome 的区别：自起 Chrome（默认）用你本机真实 profile 的副本，**换号就断**；
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

---

## 超长条底板：`HERO_BAND` + `BODY_MODE`

这类 UI 底板（如 856×2048）的构成是「英雄带（角色 + 文案 + 点阵带）+ 一大片给 UI 覆盖层用的空卡体」。

- `HERO_BAND=930` → 生成图按 `(宽, 930)` 做 cover（只横向裁一点，纵向一格不裁），贴顶；
- 下半截 `BODY_MODE=source` → **拿原资源下半截的「大尺度明暗」去调制主题渐变**：卡片暗角 / 卡体走向保留，
  棋盘格和点阵噪点被滤掉（见红线 18）。比凭空合成渐变稳得多（合成渐变要跟上半截的明暗节奏对齐，很难）。
- `BODY_MODE=synthetic` 是兜底（源快照缺失/尺寸不符）：接缝色（先横向平滑）→ 主题上色 → 主题下色。
- `--blend N` 可把英雄带最后 N 行原位融进卡体；默认 0，保持原图那种直线切。

出图建议：`HERO_BAND` 模式**用 1:1 或接近带子比例的输入**（如 856×930 → `1024x1024`），
不要拿整张超长图去生成——模型会把角色放大填满画幅，底边反而更难接。

---

## 替换原图 / 回滚

```text
publish 顺序：验收闸门 → 原图搬进 ResBackpack/备份/<资源相对路径> → 校验哈希 → 覆盖资源 → 复核哈希 → 记台账
```

- 备份按**资源相对路径镜像**（`ResBackpack/备份/Assets/ManagedResources/.../x.png`），不同图集的同名文件不会互相覆盖；
- 台账 `ResBackpack/备份/_manifest.jsonl`：一行一次操作（时间 / 资源 / 主题 / 变体 / 备份路径 / 前后 sha256 / 尺寸 / 构建号）；
- 已经有一份更早的原图时**绝不覆盖它**：再换一次会另存 `x__20261020-173000_christmas.png`；
- 回滚：`restore --asset <资源>`（`--list` 看有哪些版本，`--version <时间戳>` 指定），回滚前会把当前文件先留档到
  `ResBackpack/备份/_replaced/`；
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
