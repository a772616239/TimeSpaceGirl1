# REF：客户端杂项（从 MEMORY.md 拆出，2026-10-20）

> 为控制 MEMORY.md 体积（超限会被注入截断），把低频但仍有用的细节挪到这里。
> 主文件只留一行指针。

## 挂机气泡（→ `.workbuddy/skills/afk-dialogue-authoring/SKILL.md`）

- 唯一消费点 `Modules/Fight/View/FightPointMapOnHook.lua`；池看 `AfkSpeak.Type`：0 通用 / 英雄 id / 9900+n 地图 / 40000+英雄 id 大招 / 9998 通用大招，台词本体在 `Language`（D 列是语言 id）。
- 🔴 气泡 280×78、28 号字 ⇒ 最多两行（中≤16 字 / 英≤34 字符 / 日≤20）。不要数字符，用 Unity `TextGenerator.GetPreferredHeight` 实测（h≤74.5）。
- 🔴 加行只能 XML 层追加（`append_afk_ult_talk.py` 模板），**禁止 openpyxl 存盘**（空串变空单元格、整表重写）；导出必须走官方 `DataToOptimizeLuaExporter`；配置 lua 也要 `lua-bytes-sync.sh`。
- 大招＝槽位最高 `SkillType==2`；🔴 挂机演出**不卡 UnlockSkill**（槽位 3 要 Rank≥3，卡了全退化成槽位 1）；每场 55% 抽 1 人、多段压到 3 段；`ShowTalk` 是唯一冒泡入口（同位置定时器先 Stop）。

## UI 布局 / Unity 桥（→ docs/unity_mcp_control.md）

- 🔴 `StdioBridgeHost` 127.0.0.1:6400（未配 mcp），`.workbuddy/tools/unity_bridge.py` 直连；新连接踢旧；端口没监听＝没起来；探测端口不能先开试探连接再关。`execute_code` 结尾必须 `return <expr>;`；UI 实拍开临时 additive 场景。
- 🔴 `CanvasScalerAdapter` 宽高比<16:9 时 match=0 ⇒ 画布宽恒 1080、高随屏；网格用 `(0.5,1)`+`-(row*H+H/2)`；图元跟不跟画布中心按需求定（`BattleUltCard` 在画面中部，`a0408226a`）——改位置前先问口径。
- 🔴 战场相机根高度唯一收口 `BattleManager.SetCameraRootY`：战斗 `-1.57`、挂机 `0`；`BattleScene.prefab` 的 `CameraRoot` 留 0。

## 内购 / IAP

- 🔴 购买入口唯一收口 `Assets/Scripts/IAP/IAPManager.cs`（`BuyItem1`/`BuyItem`）：单飞锁（120s 兜底）+ 全套空判 + `IDetailedStoreListener`；Lua 侧 `PayManager.Pay` 只调 `iapMgr:BuyItem1`。
- 🔴 `ProcessPurchase` 分「本次在途（pid 匹配）」与「Google 重投历史单」：后者落盘 `PlayerPrefs["iap_pending_purchases_v1"]`（`\u001E`/`\u001F` 分隔）再 `Complete`，用 `TakePendingPurchases()` 取补发（格式 `productId#transactionId#receipt`）。真正的补发必须等服务端按 receipt 幂等校验，客户端直接发 `RequestBuyGiftGoods` 会重复发。
- 🔴 `ProxyBillingActivity getIntentSender() NPE` 是 Google 侧缺陷（billing 9.0.0/9.1.0 同款），升级无效、app 侧改不了 ⇒ 只做 Crashlytics 静音，勿重复排查。

## 诱导评分（→ daily log 2026-10-19）

- 底层＝`Assets/Scripts/Review/ReviewMgr.cs`（Google Play 内评价），Lua 唯一入口 `ReviewMgr:AllInOneFlowClick()`；`BattleBestPopup` 那套 PassTimes1 计数不要动。
- 🔴 新入口唯一闸门 `AppReview_TryShowOnKeyLevel(key)`（`Common/functions.lua` 末尾）：同 key 只弹一次 + 24h 冷却（取 `PlayerManager.serverTime`）+ 账号 3 次，计数 `AppReview_<uid>_*`。
- 口径：爬塔＝`VirtualTargetReward.Condition` 里程碑层；日常副本＝该 Type `Id` 最大末关**首通**，判首通必须在 `AddDailyChallengeInfo` 之前。
