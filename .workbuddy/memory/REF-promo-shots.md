# REF-promo-shots —— 商店页截图 / 置顶图 / 店面图管线

> 2026-10-24 从 `MEMORY.md` 迁出，内容为原文并补全。MEMORY.md 只留指针。
> 文案侧见 MEMORY.md「店面 / ASO」段；换皮见 `REF-art-restyle.md`。

## 管线总览与可复用性

- 🔴 **管线已工程化，可复用到其它项目**：项目特异性全在 `data_aso/site.json`（包名/品牌/语言/尺寸），换项目只改它 + Jenkins 的 `PROJ`/`PY`；通用 runbook `docs/promo_shots_pipeline.md`。
- 批量出图 `aso_fusion.py --pairs shots|all|<逗号 tag>`（`shots` = `fusion_shots.DEFAULT_ORDER`，与商店页顺序同一真源）；`--promote` 与多组**互斥**（每语只准一张 featureGraphic，脚本 exit 2）。

## Jenkins `SHOT_MODE=landscape` 的 ③ 阶段顺序（顺序不能乱）

```
aso_assets build（产 index.json）
  → aso_fusion --pairs shots --by-locale --out fusion_all
  → fusion_shots
  → 复原拼装置顶图        ← 必需，别省
  → preview
```

- 🔴 `aso_assets.py build` 会**覆盖回竖版**并把 `feature_01.png` 换回拼贴版 ⇒ 跑过 `fusion_shots.py` 后**别再跑 build**；`preview` 可随便跑。
- 竖版路线（纯 `aso_assets build`）仍在 git 历史里可切回。
- 🔴 `aso_fusion.py --locales` 默认**只有 en-US** ⇒ 恢复置顶图必须显式写 `--locales en-US,ja-JP,zh-CN,zh-TW`，否则只 promote 一个语言。

## 选角色（立绘池）

- 🔴 **必须逐张放大看图**：123 张基础图（156 含表情差分），光看名字会挑错——`韩信 / 尼禄 / 霍恩海姆 / 亚瑟 / 帕里斯 / 西巴达 / 法姆贡 / 海明威 / 荣芙 / 运动员` 在游戏里都是**男性**。
- 选人后配色走 `hero_features.py extract --art` 现算；原图暴露的改写成不透明覆盖版。
- 多组候选链路：`fusion_pairs.json`（**tag 必须是 left+right 拼的四位数**，否则底图收不到）→ `hero_keyart.py batch`（串行 / 断点续跑 / `--force`）→ `aso_fusion.py --bg`（覆盖底图，别反复改 fusion.json）→ `fusion_page.py` 验收页。
- 候选目录**禁 `--promote`**（会把 feature_01 覆盖成一张并清掉其它）。
- 一组 89~126s；卡到 8 分钟是踩坏号（日志 `cdp:xxxxx 不可用 → 换下一个号`），**别 kill**。

## 置顶图拼装（定版 2026-10-23）

三层拆分：

1. **两侧角色** `hero_keyart.py duo --pair 01,02 --wait` —— 管线按**特征卡**重绘，立绘只抽特征、**禁止直接贴立绘**（用户否决：光源/画风不同，一眼剪贴画）。双人底图里两人都被左右边缘裁切、中间 60% + 底部 26% 留空。
2. **中间** 压实机截图框。
3. **底部** 本地压字。

- `aso_fusion.py build --promote` 把成品写成 `derived/<变体>/<语言>/feature_01.png`（与 `aso_assets build` 同名），清掉其它 `feature_*`、刷 `index.json` 哈希 ⇒ preview/push 不用改，不会出现两张置顶图。
- **无需抠图**的取巧点：底图中段 60% 留空后被画面框整块盖住（管线不出透明角色，chroma key 抠不干净）。
- Jenkins 位置：`TS-Store-Iteration` ③b 阶段，参数 `FUSION` / `FUSION_PAIR` / `FUSION_RENDER`（**只有 RENDER 才耗额度**）。
- 换图后必须 `aso_assets.py preview` 刷验收页数字。skill `aso-store-iteration`。

## 框内取景

- 🔴 `band` 必须避开截图底部按钮行（取 `[0.40,0.80]`，否则中文「禁止」会挂到英文商店页）。
- 下限 0.30（更低会吃到空景）、上限 0.90（再往上就是中文按钮行）。
- 🔴 **10 组候选不能共用同一段画面**：`fusion.json` 的 `screen.shot/band` 是全局值 ⇒ 所有组都读它 ⇒ 缩略图「同一画面重复十遍」（10-23 用户指出）。每组在 `fusion_pairs.json` 里带 `screen{shot,band,focus_x,zoom}`，`aso_fusion.py --pair <tag>` 一次出齐。
- 干净合规真机截图只有 3 张 ⇒ 只能做「3 场战斗的 10 种景别」；要 10 场不同必须补真机截图。

## 店面图（宣传图）口径

- 🔴 **AI 只画画面，标题一律本地真字体压**（`aso_assets.py headline`）——中/日/繁字形模型会画错、四语排版要统一、改文案不该重出图。
- 宣传图真源 `时空美少女物料/新版本宣传图/*_{1920,1024}/`（专业排版，远超 `1024*500/` 那张拼贴）；配方 `data_aso/assets/promo.json`，AI 底图 `data_aso/assets/gen/`（进库），`seeds/` 不进库。
- 🔴 画店面图三坑：
  - `LAYOUT` 必须写死「NO text + 底部 N% 留空」（否则面板压到底、标题没处放）
  - 主题 `outfit` 句会把角色原服装换掉 ⇒ `OUTFIT` 逐件点名保留
  - design 构图自动套金卡框 ⇒ `postprocess --frame none --alpha-mode keep` 复用生成图重跑
  - 实测出图 ~90s

## 合规

- 🔴 特征卡里写 `bare legs / bare feet` 会画出**高开叉露胯**（Play 必拒）⇒ 一律写及踝长裙 / 高腰不透明衬裙。
- `hero_prompt.py` 有 `DRESS CODE` 硬约束段（groin/buttocks 必须覆盖、开叉不过膝、列 forbidden 词），单人/双人模板都带。

## 验收页

- 🔴 `data_aso/derived/<变体>/preview.html` 是**验收台**（真机模拟 + 合规检查 + 文案计数 + 灯箱），不是缩略图墙。
- **改任何前端都要先无头截图自己看一眼**再交付：Chrome `--headless=new --user-data-dir=/tmp/x --screenshot`（不带 user-data-dir 会静默不出图）。
- ⑤ 归档必须 `cp -R` 整目录，只 cp 那个 html 就是满屏 404。
