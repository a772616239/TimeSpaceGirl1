# 《Time-Space Girl》30 秒竖版买量广告 · 创意与分镜

> 版本：v1 · 2026-10-23
> 交付物：`TimeSpaceGirl_promo_30s_9x16.mp4`（1080×1920 / 30fps / 30s）+ 本文档 + `storyboard.html`
> 素材来源：全部取自本仓库真实游戏资源（立绘铭牌、主城、棋盘、骰子、音效、英文 CV），无外部素材

---

## 0. 一句话创意

**历史最强的人，全都被拉进了这座赛博废都 —— 而你，是唯一的指挥官。**

英文主 slogan：**EVERY LEGEND, REBORN.**

---

## 1. 产品事实（本片每个卖点都能在仓库里找到出处）

| 卖点 | 事实 | 出处 |
|---|---|---|
| 108 位英雄，全员历史/神话人物二次元化 | 关羽、赵云、凯撒、贞德、莫扎特、特斯拉、居里夫人、织田信长、卑弥呼…（5 星 74 位） | `data_execl/base_data/HeroConfig.xlsx` |
| 赛博废都世界观 | 落日废墟都市主城 | `Atlas/LoginPanelAtlas/cn2-x1_zhujiemian_beijing.png` |
| 5v5 回合制，九宫格布阵取 5 位 | 阵型位 `1#3#4#6#8` | `FormationConfig.xlsx` |
| 硬控状态：沉默 / 燃烧 / 冰冻 / 封印 / 混乱 | buff 图标全集 | `Atlas/BattleAtlas/cn2-X1_buff_*` |
| 掷骰走格探索：迷雾、宝箱、精英、通缉怪 | 战棋推演地图、骰子道具 | `FreeTravel.xlsx`、`ExploreFunctionConfig.xlsx`、`TrailMapAtlas/..._wupinshaizi.png` |
| 离线挂机收益 | 挂机收益刷新 + 挂机掉落 | `GameSetting.xlsx`、`FightAreaRewardReminderPopup` |
| 招募/十连 | 猎头公司招募、千抽面板 | `Modules/Recruit`、`Modules/ThousandDraw` |
| 公会战 / 地下竞技场 / 跨服 | — | `Modules/GuildWar`、`Modules/Arena`、`Modules/ArenaTopMatch` |
| 官方承诺：Zero Paywalls（主线与 PvP 免费）、8 日登录保底 SSR | 游戏内公告原文 | 冒烟截图 `.jenkins/run/.../screenshot.png` |

> 因此本片**不使用**任何未经证实的数字（如"送 100 连""上线送 SSR"），只用公告里已经对玩家承诺过的两句。

---

## 2. 受众与洞察

- **受众**：18–34 岁、男性向二次元卡牌 / 放置 RPG 玩家；投放主战场是 Google Play 与 Meta / TikTok 的英文市场（产品名 `Neon Valkyries`，包内名 `Time-Space Girl`）。
- **同质化困境**：这个品类的买量素材几乎都是"大胸立绘 + 十连爆金光 + 数值"。玩家对"美少女"三个字已经免疫，前 3 秒划走。
- **我们的差异点**：**不是"又一个美少女"，而是"你认识的那个名字被重新演绎"**。关羽是个沉默寡言的刀客，莫扎特是个浮夸的天才，贞德是举旗的圣女 —— 这种"认得出 + 认不出"的反差，才是可传播、可二创的钩子。
- **洞察**：玩家点进来不是因为想看更多妹子，是因为想确认"他们把我认识的谁画成了什么样"。

---

## 3. 大创意：THE TERMINAL（终端召唤）

把"抽卡"重新包装成一件有仪式感的事：**你不是在抽卡，你是在用一台终端，把历史最强的人从时间里拉出来。**

- 视觉母体：**终端打字 + 全息铭牌**（直接复用游戏里那套"竖排大字名 + 红条定位标签 + 一句台词"的加载铭牌，换成英文贴片）。
- 声音母体：**键盘敲击 / 电流 / 一声闷响后进入角色台词**。
- 叙事结构：`终端上线 → 城市已毁 → 传说苏醒 → 逐个点名 → 开打 → 玩法 → 现在就下载`

---

## 4. 30 秒分镜表

| # | 时间 | 画面 | 屏幕文案 | 声音 | 作用 |
|---|---|---|---|---|---|
| 1 | 0.0–3.4 | 关羽立绘全屏推近，红色速度线，底部终端条逐字打出 | `SUMMON` / `THEM.`（红）<br>`> 108 LEGENDS LOCATED // COMMANDER VERIFIED` | 低频撞击 + 关羽 CV："If you bore me, you'll feed my blade." | **前 3 秒钩子**：脸 + 强文案 + 人声 |
| 2 | 3.4–6.2 | 废墟都市日落，缓慢推镜；两行大字砸入；LOGO 故障闪入 | `THE CITY FELL.`<br>`THE LEGENDS WOKE.`<br>**TIME-SPACE GIRL** · `CYBER · LEGENDS · WAR` | 转场冲击 + 上翻音 | 交代世界观，立品牌 |
| 3 | 6.2–8.6 | 6 位英雄脸部快切，每 0.4s 一镜，带白闪与色块 | `LEGEND 01…06` | 6 声快门 + 6 声 UI 点击 | 展示阵容广度（有男有女、古今中外） |
| 4 | 8.6–13.4 | 三张完整铭牌立绘，滑入 + 微推镜，斜切色块 | 铭牌自带：`GUAN YU · PHYSICAL · SILENCE & BURST DAMAGE` / `ZHAO YUN · AOE` / `BRUTUS` | 关羽："Satisfying! Again!" → 哈桑："You can't escape." → 布鲁图斯："Pierce the void!" | 卖"角色 + 定位 + 台词"，这是二次元用户真正看的 |
| 5 | 13.4–18.0 | 对决式构图：左我方关羽 / 右 BOSS 哈桑，VS 砸入；三次斩击、伤害数字、血条掉、屏幕震动 | `5 v 5 TURN-BASED` → `BUILD. BREAK. WIN.`<br>`SILENCE` `BURN` `CHAIN x3` | 战斗开场 + 三次命中 + 暴击；BOSS 哈桑："If I find no offering, I'll sacrifice you." | 证明"有战斗、有策略、有打击感" |
| 6 | 18.0–22.2 | 六边形棋盘，骰子掷出，路径逐格点亮，终点宝箱弹出 | `ROLL.` `RAID.` `REPEAT.`<br>`DICE-DRIVEN RUIN RUNS` | 开箱 + 抽卡音 | 差异化玩法：不是纯挂机 |
| 7 | 22.2–25.8 | 左：收益流水（金币/经验/碎片）上浮；右：十连卡片逐张翻入，最后一张爆金光 | `IDLE 24/7` `LOG OFF. KEEP WINNING.`<br>`SUMMON LEGENDS` `ZERO PAYWALLS · FULL STORY · PVP` | 十连音 + 哈桑："The offering is ready. Begin the rite." | 放置 + 抽卡，覆盖"碎片时间"需求 |
| 8 | 25.8–30.0 | 角色群像虚化背景，LOGO + 白色下载按钮脉冲 + HUD 角标 | `DOWNLOAD FREE`<br>`GUARANTEED SSR ON DAY 8`<br>`▶ GET IT ON GOOGLE PLAY` | 收尾重击 + 淡出 | 明确 CTA，不玩悬念 |

**节奏设计**：每 2–4 秒换一次景，第 6.2s 起进入"每 0.4 秒一刀"的快切区，避免中段流失。

---

## 5. 15 秒剪辑版（同素材，改剪点）

`0.0–2.6`（镜 1）→ `2.6–4.4`（镜 2 只留 LOGO）→ `4.4–7.0`（镜 4 只留关羽 + 赵云）→ `7.0–10.6`（镜 5 战斗，压到 3.6s）→ `10.6–12.4`（镜 6 棋盘 2 格点亮）→ `12.4–15.0`（镜 8 CTA）。
15s 版**不放**镜 3 和镜 7，把"十连"压成 CTA 前的一帧金光。

---

## 6. 版式与美术规范（复刻时照这个来）

| 项 | 规范 |
|---|---|
| 尺寸 | 1080×1920（9:16），安全区上 220px / 下 300px 不放关键信息 |
| 主色 | 墨黑 `#08080A`、血红 `#E4002B`、霓虹青 `#22E0FF`、品红 `#FF2D95`、金 `#FFC440` |
| 西文标题 | DIN Condensed Bold（大字距）/ Arial Black（重字重） |
| 中文标题 | 冬青黑体 Hiragino Sans GB |
| 常用字效 | 白闪 2 帧、RGB 分离、横向切片 glitch、斜切光带、半调网点（6%）、扫描线（6%）、暗角、颗粒 |
| 转场 | 硬切 + 白闪为主；场景之间用 1 帧白/黑过渡，不做花哨转场 |
| 镜头运动 | 一律"推近"，不做拉远；角色卡 1.0→1.08 缓动 |

---

## 7. 投放建议

1. **前 3 秒定生死**：镜 1 必须带人脸 + 人声 + 一个能读懂的动词（SUMMON）。不要用 logo 开场。
2. **A/B 三版钩子**（同一支片子只换 0–3.4s）：
   - A（本片）：关羽 + "SUMMON THEM."
   - B：凯撒/莫扎特 + "YOU KNOW THEIR NAMES. NOT LIKE THIS."（认知反差钩）
   - C：战斗直给 + "5v5 · 108 LEGENDS"（玩法钩）
3. **渠道**：Play 商店视频位（静音播放为主，字幕必须自解释）→ TikTok/Reels（前 1s 更激进）→ Meta Feed。
4. **商店文案配套**：标题 `Time-Space Girl: Neon Valkyries`；副标 `Summon 108 legends. 5v5 turn-based. Idle 24/7.`
5. **落地页一致性**：素材里出现的三张铭牌（关羽/赵云/布鲁图斯）应能在商店截图中找到同款，降低"图文不符"的差评。

---

## 8. 合规红线（Google Play 广告政策）

- ❌ 不写未验证的数值承诺（"送 100 连""首抽必 SSR"）。本片只用了公告里已有的 `Zero Paywalls` 与 `Guaranteed SSR on Day 8`。
- ❌ 不使用过度性化的镜头（不做胸部特写、不做挑逗姿势特写）。镜 3/镜 4 一律取**面部到胸上**，画面重心在脸。
- ✅ 战斗画面不出现真实血腥；伤害数字用金色，不用红色血雾。
- ✅ `DOWNLOAD FREE` 必须与实际一致（游戏本体免费）。
- ⚠️ 若投放到要求年龄分级的渠道，片头 0.5s 需加 `In-app purchases` 角标。

---

## 9. 复现与二次修改

```bash
cd promo
python render.py --test 14.3 19.9     # 单帧预览 → frames/test_*.png
python render.py                      # 出 video_noaudio.mp4（约 5 分钟）
python build_audio.py                 # 混音 + 合流 → TimeSpaceGirl_promo_30s_9x16.mp4
```

- 换文案：改 `render.py` 里对应场景的 `txt("...")`。
- 换角色：`card_XX` 对应 `promo/assets/card_XX.png`（= 中文底图 + 官方英文铭牌贴片，由 `LoadingPlateGeom.lua` 的锚点合成）。
- 换语种：铭牌有 `_plate_en` 一套；中文版把 `card_XX.png` 换成 `cn2-X1_loading_0X_zh.png` 原图，再换 `CV_En_Full` 为 `Audio/CV` 中文原声即可。
