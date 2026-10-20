---
name: art-restyle
description: TimeSpaceGirl1 美术 UI 资源换节日风格 / 换皮肤 / 给整幅底板加边框，以及验收「框在深色面板上为什么看不见」这类观感问题。当用户说"给这张图换个圣诞风格""换个皮肤""套个边框""这个边框不好看""黑底上看不见""写回资源/回滚"时使用。内含五段式确定性流水线（prepare→generate→postprocess→verify→publish）、边框三定律（暗带+亮边剖面、亮度差≥100、inset 不压字）、真机尺寸预览脚本，以及 7 条踩过的红线。
---

# 美术资源换节日风格 / 边框设计

> 深水区原理与逐条复盘：**`docs/art_restyle_pipeline.md`**
> （provider=chatgpt_web 的登录态驱动、HERO_BAND 卡体、去水印判据、写回台账）。
> 🎨 主题生产卡：**`docs/art_restyle_themes.md`** —— 8 个主题（圣诞/新年/万圣/情人节/夏日冲浪/
> 普罗旺斯/感恩节/赛博）的设计意图与禁忌、四类图的参数配方、新主题接入 7 步、批量与额度纪律。
> 工具：`scripts/image/restyle_pipeline.py`、`scripts/image/batch_restyle.py`（批量）、
> `scripts/image/preview_ingame.py`、`scripts/image/gen_chatgpt_web.py`、Jenkins `TS-Art-Restyle`。
> 出图前必跑 `restyle_pipeline.py themes --check`（预设自检，能拦下「写死一条抱礼物的姿势」这类错）。

## 什么时候用

| 用户说 | 走哪条 |
|---|---|
| 「这张图换成圣诞/春节风格」 | §1 五段式，主题取 `themes` 里的 key |
| 「这批图都换」「三语一起换」「一次出好几个主题」 | §1.4 `batch_restyle.py`（先 `--dry-run` 数组数） |
| 「加个夏日冲浪/普罗旺斯/万圣/感恩/赛博主题」 | 改 `theme_presets.json` → `themes --check` → `docs/art_restyle_themes.md` §4 |
| 「换皮肤但人物姿势也重设计」 | `--composition free`，必配 `--alpha-mode keep` + `--frame auto` |
| 「套个边框」「边框不好看」 | §2 边框三定律，**先做真机预览再给用户看** |
| 「黑底上看不见框」 | §2.2 亮边，一条 `--frame-rim` 解决 |
| 「把紫色/金色再深一点」 | 改 `CARD_RIMS` 里那一档色板（亮边/斜面/带色三值一起动） |
| 「写回资源 / 回滚」 | §4 publish / restore |

## 1. 五段式（确定性部分）

```bash
PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python
W=_output/art_restyle/<asset-stem>/<theme>

$PY scripts/image/restyle_pipeline.py prepare --asset Assets/.../xxx.png --theme christmas \
    [--composition free]                      # 建工作区、拍源快照、量 alpha 覆盖率
$PY scripts/image/gen_chatgpt_web.py ...      # 出图 → $W/inbox/gen_web.png（详见主文档）
$PY scripts/image/restyle_pipeline.py postprocess --work "$W" --gen "$W/inbox/gen_web.png" \
    --alpha-mode keep --frame card --frame-rim violet [--hero-band 930 --body-mode source]
$PY scripts/image/restyle_pipeline.py verify  --work "$W"          # 硬项全过才允许写回
$PY scripts/image/restyle_pipeline.py publish --work "$W" --variant alpha --yes   # 直接替换源图（原图进备份）
```

- 超长条底板（856×2048）= `--hero-band 930 --body-mode source`（**不能整幅 cover**，会横切 37%）。
- `--composition free` 时源 alpha 是按老姿势抠的，会切掉新画的脸/帽子 ⇒ 自动降级 `keep`。
- 写回成功 ≠ 进包：还要在 Unity 里重打该资源所在 AssetBundle（`FrameTool.BuildGameAssetBundles`）。

### 1.0 两条定稿口径（用户 2026-10-20 明确，别再问）

1. **统一紫框**：`--frame card --frame-rim violet`（就是登录底板那档紫白，别回 warm/gold）。
2. **默认直接替换源图 + 原图搬备份**：验收过了就 `publish --variant alpha --yes`
   （或 Jenkins `WRITE_BACK=true`）—— 原图进 `ResBackpack/备份/<资源相对路径>`、`_manifest.jsonl` 记台账、
   `.meta` 永不动；回滚 `restyle_pipeline.py restore --asset <资源>`。
   🔴 浮层类资源（顶部/底部有透明轮廓）套框必须配 `ALPHA_MODE=keep`：沿用 `source` 掩膜会把框的顶/底边
   整段切掉，只剩左右两条亮线，看着像"框没画完"。

### 1.1 provider 怎么选：额度按账号算，本机 Chrome 用尽就换 SunBrowser

- 默认 `PROVIDER=chatgpt_web` 走**本机 Chrome 登录态**（profile `Profile 5`）。
- 🔴 **本机 Chrome 一旦报「超时仍未拿到图 / 额度用尽 / 页面被关（page has been closed）/
  `.codex-dialog-overlay` 遮罩挡住发送」——直接换 AdsPower 的 SunBrowser，不要原地重跑烧额度：**

  ```bash
  $PY scripts/image/find_browser_cdp.py      # → best port=64757（Chrome/144，端口不在命令行里，只能反查）
  # Jenkins TS-Art-Restyle 里填 CDP_PORT=64757（= 给 driver 加 --reuse-cdp：只连不断、不关用户窗口）
  ```

  换号 = 在 AdsPower 里开另一个已登录 profile，再反查一次端口。SunBrowser 界面语言可能不是中文，
  `GEN_ALT` 已覆盖中/英/日/韩/西/法/德/葡。
- 右下角**自带亮装饰带**的图（千抽底板那条青/白 V 形带）会把水印判据骗过去 ⇒ 传 `WATERMARK=off`。

### 1.2 浮层图（画布上下有透明留白）走 free 构图时的两件事

1. 🔴 **模型不会真输出透明，它会画棋盘格表示留白。** 直接整幅 `cover` 再套源 alpha，
   棋盘格/留白交界处会漏白边。正确顺序：
   `postprocess --alpha-mode keep`（先拿到整幅 flat）→
   `$PY scripts/image/refit_band.py --work "$W"`（量生成图画区 bbox → 等比 cover 进**源可见带**矩形
   → 再 `putalpha(源 alpha)`）→ 把 `state.json` 的 `alpha_mode` 记成 `source`（实际口径一致）再 `verify`。
2. **这类图不要套紫框。** 源 alpha 常是「矩形画带 + 顶部 100px 柔化渐隐 + 底部硬切」，
   框的顶边正好落在渐隐段里 ⇒ 又变成「框没画完」。左下还常有一块留给引擎写字的空文案板，
   框的 inset 会啃掉它。`--frame none` 就是这一档的正解，别为了统一硬套。

### 1.3 free 构图的「发挥想象力」：姿势走候选池随机，别再硬编码一句

🔴 **历史 bug（用户 2026-10-20 亲自揪出来的）**：`theme_presets.json` 里原来是单条
`pose_hint = "... presenting a small gift box toward the viewer ..."`，被 `build_prompt` 原样注入
free 构图提示词 ⇒ **每张 free 图都是同一个「抱着礼盒递出去」的姿势**。不是模型随机，是配置里就那一句。
（四个主题全中：圣诞=礼盒、新年=红包、万圣=南瓜灯、情人节=心形气球，全都在手里塞道具。）

现在的口径：

```bash
--pose            # 留空=每次从主题 pose_hints 里随机抽一条（推荐：连跑同主题也不重样）
--pose 3          # 指定第 3 条，方便复现/挑喜欢的
--pose none       # 不注入姿势，完全交给模型
--pose "…"        # 自定义一句
```

- 候选句一律**空手/动作向**（撩发、扶帽檐、回身、甩披风、双臂张开），主题道具最多保留 1 条作 opt-in。
- `COMPOSITIONS["free"]` 里已写死硬约束：`Hands must stay EMPTY: never invent an object and put it in
  her hands`，所以即使候选句没提道具，模型也不会自己塞一个。
- 🔴 **不要在 LAYOUT 里再写「拿着 X」**：layout 是这张图专用的一段，写进去就等于把随机池钉死。
- `state.json` 的 `pose_hint` 记录了本次实际用的那句，出图不理想时按它复现或换一条。
- `lock` 构图不注入姿势（`{pose_hint}` 只出现在 free 分支），`--pose` 对 lock 无副作用。

### 1.4 一次要换一批（多资源 / 多主题）走 batch_restyle.py

```bash
$PY scripts/image/batch_restyle.py scripts/image/batch_example.json --dry-run   # 先数清组数：N×M 组＝N×M 份额度
$PY scripts/image/batch_restyle.py my.json --only chaozhilibao                   # 只跑名字含该子串的
$PY scripts/image/batch_restyle.py my.json --no-gen                              # 复用已有出图，不烧额度
$PY scripts/image/batch_restyle.py my.json --publish                             # verify 过了才写回
```

- **`assets` 支持 glob**：同一套 UI 的 `zh/en/jp` 三份必须一起换，只换一份＝「中文圣诞、英文原样」的花脸。
- 出图是**单浏览器串行**的，别开两个批处理抢同一个 CDP 端口；`rc=3`（额度/登录）会停整批，去 AdsPower 换 profile 再反查端口。
- `variant` 自动：源 `RGB`→`opaque`、源 `RGBA`→`alpha`。🔴 别把 RGB 写成 RGBA（导入/压缩口径会变）。
- 汇总落在 `_output/art_restyle/_batch/<时间戳>/summary.md`，逐组日志在 `logs/<slug>__<theme>.<step>.log`。
- 主题设计意图、每类图该配什么参数、新主题接入步骤：**`docs/art_restyle_themes.md`**。

## 2. 边框三定律

### 2.1 语言必须是游戏自己的，不是相框

先看 `Assets/ManagedResources/Atlas/X1PublicAtlas/cn2-X1_tongyong_daojukuang_01~07`（道具槽）、
`cn2-X1_tongyong_yingxiongkuang_01~06`（英雄卡）、`yindao_duihuakuang_02`（对话框）。

**红金雕花 + 四角圆徽章那套被用户否过**：游戏里一个鎏金徽章都找不到，贴上去像给海报装相框。
能用的只有三种语言：深色渐变+菱纹+细描边、实心色块+大斜切角、紫色块+硬投影。

### 2.2 最外圈必须有亮边 —— 否则黑底上框等于没画

实测：八日礼包面板底 `(17,17,25)`，墨带 `(18,16,24)` —— **同亮度**，真机上完全看不出有框
（用户原话「遇到黑色的时候不明显」）。游戏自己的槽位框正是这么解决的：

| 资源 | 剖面（外→内） |
|---|---|
| `tongyong_daojukuang_01` | `57,61,74`×3px → **`238,240,243`×5px** → 槽内 `119,133,158` |
| `tongyong_daojukuang_04` | `59,26,75`×3px → **`222,182,255`×5px** → 槽内 `105,57,136` |
| `tongyong_daojukuang_05/06` | `75,38,26`×3px → **`255,227,182`×5px** → 槽内 |

即「暗带 3px + 亮边 5px」。`card` 现在的结构：

```
1px 暗描边 → 亮边(外亮内暗, 斜面受光) → 1px 暗切 → 墨带+菱纹 → 3px 暗槽 → 画面(inset)
```

- **判据：亮边与面板底亮度差 ≥ 100**（`255,238,200` vs `17,17,25` = 237，合格）。
- `--frame-rim warm|ivory|violet|none`，默认 `warm`。暖色主题配 `warm`；紫面板配 `violet`。
  `none` 只允许在浅色底上用。
- 带宽 `--frame-ratio`（card 默认 `0.022`，1080 → 24px；亮边 = 带宽 ×0.30 → 7px）。
  加亮边后不要再把带宽往大调，否则变「黑边很厚的相框」。

### 2.3 框走 inset，不许压画面

`frame_card` 是「画面等比缩进框内」（cover 到内框，横竖最多裁 1~2%）。
overlay 会盖掉贴边的字：登录底板的 `8-DAY` 左缘离画布边只有 ~27px，overlay 一格就咬掉字角。

## 3. 迭代方法：按真机尺寸看，不按 1:1 原图看

1080 宽的资源在游戏里只显示 567px —— 1:1 看着清楚的细线，缩完就是 1px 甚至消失。
**任何边框/描边/细线改动，先跑预览再给用户看：**

```bash
# 改前/改后并排，底下叠 8 张日卡（复现"左右被内容盖住、只剩上下边露出来"）
$PY scripts/image/preview_ingame.py old.png new.png --cards 2x4 --out /tmp/cmp.jpg
# 左上角 3x 最近邻特写（看切角是否硬 45°、亮边有没有毛刺）
$PY scripts/image/preview_ingame.py new.png --zoom 3 --out /tmp/corner.jpg
```

面板底色不要猜：在截图里取边框外 2~3px 像素的中位数。

给用户看的时候**必须配「改前」**，否则他无法判断改没改（这次就因为一张图标错文件名，
把红金雕花版当成"改前"，用户回了一句「还是刚才的版本好一点」，来回多跑一轮）。

## 4. 坑（都踩过）

1. **`ImageDraw.line(width=…)` 不能用来画框。** 它以路径为中线、拐角用 round join：
   45° 切角被磨成圆角；相邻两条线（亮边 + 斜面）还会互相盖住，亮边只剩半宽。
   ⇒ 用多边形掩膜 `_ring_paste` / `_ring_mask`（外圈多边形减内圈多边形），切角永远硬 45°。
2. **窄带里别塞两条线。** 亮边 + 内细线挤在 20px 里会变成相框式双线 ⇒ `--frame-hairline` 默认关。
3. **内侧投影不能用「错位硬投影」**：切角处对不齐会漏一块黑三角，像磕坏了。改成沿切角多边形
   高斯柔影（`GaussianBlur(bw//3)` + `1.6` 次幂）。
4. **`WRITE_BACK` 的备份目录不能按文件名猜。** `ResBackpack/备份/...__20261020-185927_christmas.png`
   看着像"墨带版"，实际是**红金雕花版**（每次 publish 备份的是"被替换掉的那一版"）。
   要判断版本就量像素（底色/边框色），或者直接看 `_manifest.jsonl` 的 before/after 哈希。
5. **`.meta` 永不改动。** 曾出现 guid 被换（`3b0b0d5e`→`042a30ad`），Unity 引用全断。
6. **写回 ≠ 进包**：`publish` 只改 `Assets/` 里的 png，真机要重打 AssetBundle。
6.1 **源是 RGB（无 alpha）就用 `--variant opaque` 写回**，别用默认的 `alpha`：
    `alpha` 会把资源从 RGB 变成 RGBA（实测 799KB → 1.6MB），alpha 虽全是 255 看不出来，
    但换了纹理导入/压缩口径。`prepare` 打印「源资源是整幅不透明」就是这种情况。
7. **提示词不许写死文案**：文案由 `LAYOUT` 构图锁逐字保持，主题预设只描述风格（初版写死 `8-DAY`，
   换主题就串字）。

## 5. 验收清单

- [ ] `verify` 硬项全过（尺寸 / alpha 覆盖率不低于源 / 彩色高光没被压成透明 / 水印无残留）
- [ ] `preview_ingame.py` 真机比例下，框在**深色底**和**画面亮部**两侧都能看出轮廓（亮度差 ≥100）
- [ ] 左上/右下 3x 特写：切角是硬 45°、亮边无毛刺、画面四边没被压字
- [ ] 文案完整（free 构图必须人眼看，`verify` 不查错字）
- [ ] `publish` 后确认 `.meta` 未变、`_manifest.jsonl` 有台账
