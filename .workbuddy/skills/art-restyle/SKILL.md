---
name: art-restyle
description: TimeSpaceGirl1 美术 UI 资源换节日风格 / 换皮肤 / 给整幅底板加边框，以及验收「框在深色面板上为什么看不见」这类观感问题。当用户说"给这张图换个圣诞风格""换个皮肤""套个边框""这个边框不好看""黑底上看不见""写回资源/回滚"时使用。内含五段式确定性流水线（prepare→generate→postprocess→verify→publish）、边框三定律（暗带+亮边剖面、亮度差≥100、inset 不压字）、真机尺寸预览脚本，以及 7 条踩过的红线。
---

# 美术资源换节日风格 / 边框设计

> 深水区原理与逐条复盘：**`docs/art_restyle_pipeline.md`**
> （provider=chatgpt_web 的登录态驱动、HERO_BAND 卡体、去水印判据、写回台账）。
> 工具：`scripts/image/restyle_pipeline.py`、`scripts/image/preview_ingame.py`、
> `scripts/image/gen_chatgpt_web.py`、Jenkins `TS-Art-Restyle`。

## 什么时候用

| 用户说 | 走哪条 |
|---|---|
| 「这张图换成圣诞/春节风格」 | §1 五段式，主题取 `themes` 里的 key |
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
