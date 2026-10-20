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
$PY scripts/image/restyle_pipeline.py prepare   --asset Assets/.../x.png --theme christmas [--layout F]
$PY scripts/image/restyle_pipeline.py postprocess --work "$W" --gen "$W/inbox/gen.png" [--hero-band 930] [--watermark off]
$PY scripts/image/restyle_pipeline.py verify    --work "$W"
$PY scripts/image/restyle_pipeline.py graph     --work "$W" --out "$W/graph.md"
$PY scripts/image/restyle_pipeline.py publish   --work "$W" --variant alpha --yes [--note "job#n"]
$PY scripts/image/restyle_pipeline.py restore   --asset Assets/.../x.png [--list] [--version 20261020]

# 不走 job，单跑 ChatGPT 出图通道（用你 Chrome 的登录态）
$PY scripts/image/gen_chatgpt_web.py --image "$W/src/source.png" --prompt-file "$W/prompt.txt" \
    --out "$W/inbox/gen_web.png" --crop-height 930 [--check-only]
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
| `LAYOUT` | 构图锁文本。**每张图的文案不同，所以文案一定写这里，不要写进主题预设** |
| `PROMPT_OVERRIDE` | 整段覆盖提示词（LAYOUT 不够用时才用） |
| `HERO_BAND` | 超长条底板专用：英雄带像素高度（如 `930`）或 `auto`。留空=整幅等比 cover |
| `BODY_MODE` | `auto`（默认）/ `source` / `synthetic`，见下 |
| `ALPHA_FROM` / `SOURCE_FROM` | 资源已被换过、工作区里没原版时，用 `git:HEAD:<path>` 取回参照 |
| `WRITE_BACK` | **替换原图**：验收通过后把 alpha 版写回资源，原图搬出工程。默认关 |
| `BACKUP_ROOT` | 备份根，留空 = `ResBackpack/备份` |

构建页能看到：环节表（JUnit）+ `summary.md` + 构建描述 + `artifacts/`（改前改后对比图、graph.md、
prompt.txt、state.json、published.json）。节点图由 `graph` 生成，链路
`prepare → generate → postprocess → verify → publish`，绿/红/灰三色。

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

---

## 超长条底板：`HERO_BAND` + `BODY_MODE`

这类 UI 底板（如 856×2048）的构成是「英雄带（角色 + 文案 + 点阵带）+ 一大片给 UI 覆盖层用的空卡体」。

- `HERO_BAND=930` → 生成图按 `(宽, 930)` 做 cover（只横向裁一点，纵向一格不裁），贴顶；
- 下半截 `BODY_MODE=source` → **拿原资源下半截的明暗结构按主题色重映射**：几何与原图逐像素对齐，
  卡体的暗角、噪点、透明度剖面全部保留。比凭空合成渐变稳得多（合成渐变要跟上半截的明暗节奏对齐，很难）。
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
