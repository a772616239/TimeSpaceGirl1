# 付费经济（定价 / 礼包 / 抽卡）红线

> 工具：`scripts/monetization_sim.py`（估值+需求模型）·`monetization_retune.py`（R1–R6）·
> `monetization_firstpay.py`（R7–R9 首充/星级礼）·`monetization_ladder.py`（R10 价值带 / R11 星级梯度）·
> `monetization_monthcard.py`（R11 月卡月限）。

## 🔴 标尺：用「抽等值」，不要用「钻/元」
- 本作钻石在**直充 10 钻/元**、在**月卡 300 钻/元**、基金 ~103 钻/元 —— 同一通货差 30 倍。
  任何"钻/元"的横向比较都会被月卡锚点带偏（R1–R6 就是这么误判"性价比已修好"的）。
- 正确标尺：`抽等值 = 抽卡券张数 + 钻石 / 220`。
  - 单抽 `19#1|16#220`（LotterySetting Id=12）；十连 `19#10|16#2000`（Id=11）；
    普通池十连才是纯券 `20#10`。
  - 免费日产出 380 钻/天 = 1.7 抽/天。
- 券种：`19` 紫晶卡 / `20` 会员招募卡 / `87` 命运招募卡 / `50007` 限定招募卡（均按 1 张=1 抽）。

## 🔴 价格不能直接改
- `ChannelRechargeIdConfig` 的计费点是**按商品 id 绑定**的渠道商品（833 个 SKU 全已配置，
  列是百度/9377/ChiTu/ilod/QuickGame，**没有 Google 列**）。改 `Price` 会让渠道侧金额与
  配置不一致 ⇒ 加档/改价必须走商务建计费点。
- **能改的只有内容**：`BaseReward` / `RewardShow` / `FirstMultiple` / `Limit`。

## 🔴 展示字段口径
- `RewardShow` **只有 `Type=3`（钻石直充）在用**：`BuyGoodsLogic:1216` 的
  `if (type == GiftGoodsType.GEM)`，`GiftGoodsType.GEM = 3`。礼包（Type=5）展示读 `BaseReward`。
- 但两者仍要同步写，否则 `1001/1002/1003/1005/1021/1022/1023/1025` 这 8 个
  "展示=基础一半"的钻石类 SKU 会前后矛盾。
- 礼包 `BaseReward` 存量就有 10 项的包，奖励栅格**是动态的**（追加 1 项安全）。
  与首充不同 —— 首充 `DayRewardItem.lua: kRewardCount = 2` 是**固定 2 格**，加第 3 项会崩。

## 关键锚点数值（2026-10-21 R11 之后）
- 直充 id=1..6（Type=3）：6 元 60 钻 → 648 元 8424 钻，10 → 13 钻/元（**阶梯很窄，故意不扩**）。
- 月卡 id=9：12 元 = 300（立得）+ 120×30（`MonthcardConfig.BaseReward` 手动领）= **3900 钻 = 1.477 抽/元（25x 直充）**。
  R10 文档的 1.364 只算了 3600，漏了立得 300。豪华月卡 id=11：980 + 360×30 = 11780 钻 = 0.546；
  月卡 30 元变体 id=10：750 + 3600 = 0.659 —— **月卡家族自己越贵越不值**（待处理）。
  `MonthcardConfig.Price` 是**激活所需的累计充值门槛**，不是商品价。
- 🔴 **月卡"白送"通道**：全表 830 个 SKU 的 `AccumulativeRecharge=1`，
  `BuyGoodsLogic` 486 行「月累计充值额从 <12 跨到 ≥12 就 `putMonthCard()`」
  ⇒ **买两张 6 元包 = 送一张月卡**，不需要买月卡 SKU。到期时 `getMonthCard()` 把
  `monthSaveAmt` 归零 ⇒ 每 30 天可白拿一次。这条配置改不动（改 `AccumulativeRecharge`
  会连带 `saveAmt`/`maxSingleR`/`changeActivity`），只能动服务端或 `MonthcardConfig.Price`。
- 月卡限购的正确落点（配置层）：`Time=8`（自然月刷新）+ `DailyUpdate=30` + `Limit=1`
  + `LimitShow=1`。依据 `AbstractWelfareBag.refresh()` 的 `timeType==8` 分支与
  `PerpetualWelfareBag` 构造器；`DailyUpdate>0` 才会进 `refreshItemInfo`。
- 基金 LuxuryFund：Type 78=13200 钻、79=35360、7801/7802=6600、7901/7902=13600（30 天）。
- 战令 `BattlePassConfig.BuyId = 72001`（198 元，单档，无 30–68 元入门档）。
- 首充活动 = `GlobalActivity Id=5`（Type=5 RechargeTotal），`ActivityRewardConfig ActivityId=5`。

## 🔴 价值口径必须三源合并（R12）
一个 SKU 的抽等值 = SKU 行 `BaseReward`/`ExtraReward` + `LuxuryFund` 日领
+ `ActivityRewardConfig` 轨道（经 `GlobalActivity.CanBuyRechargeId` 挂到 SKU）。
只看 SKU 行会把成长基金（98 元、30,160 钻、1.399 抽/元）判成空包。

全表真实阶梯（抽/元，2026-10-21 R12）：
成长基金 98 元 **1.399** ＞ 月卡（累充 12 元白送）1.364 ＞ 首充 6 元 0.879 ＞
豪华基金 128 元 0.827 ＞ 豪华基金 328 元 0.718（**倒挂**）＞ 战令 198 元 0.339 ＞
礼包带 0.194–0.292 ＞ 直充 0.046–0.059（首购 0.118）。
**落差 5.6 倍**：98 元基金 137 抽 vs 648 元礼包 189 抽 ⇒ 礼包线在数值上没有购买理由。
`LuckyCatConfig` 901–904 满次数 22,704 钻 → 37,990 钻（1.67x），是钻石产出口不是回收口。
`OnSaleRule=1#999#999` = 永久关停，占 283/833 行；`Android_ilod_OneStoreCB` 计费点 0/833。
工具：`scripts/monetization_audit.py`（只读，7 项检查）。

## 🔴 星级成长礼的星级从哪来
- `PackPush.ConditionId` 的 `4#N`（条件类型 4 = 妖灵师星级），`Packs` 列 `#` 分割 SKU。
  只覆盖 15 个 SKU；`30702/30802/30902` 这类"低价兄弟包"没被登记 ⇒ 靠 **Name 组内继承**
  （`34010110..34010119` = 4..13 星）。漏了兜底就只认出 15/49。
- 4 星（Name=34010110）是基准，目标 = 基础档 + 0.006×(星-4)；同价相邻星级至少差 0.004 抽/元。
- 阶梯校验/规划必须按**星级组**比（低星组最高 vs 高星组最低）：按 SKU 逐个扫会把同价同星的
  多个变体依次顶高、低星反超（128 档踩过）。

## 🔴 礼包袋 limit 不会跟配置走
- `AbstractWelfareBag` 落库后 `limit` 只来自建袋那一刻；`refreshUnitWF` 只重置 `buyTimes`。
  `AbstractRechargeHandler.rechargeIsInBag()` 命中就不重建 ⇒ **改配置对老玩家无效**。
- 自愈点：`BuyGoodsLogic.refreshUnitWF` 对齐 `Otype=1`（永久礼包）。**不能对齐 `Otype=4`**
  （推送礼包 limit 会被活动 `bag.setLimit(bag.getLimit()+num)` 动态抬高）。

## 反面清单（已踩）
- 只补"钻/元"不看限购 ⇒ 得出"复制粘贴越多收入越高"或"大额不用管"的错误结论。
  128/328/648 大量 `Limit=6/9/10/15`（可复购），小额多是 `Limit=1` —— 阶梯必须按限购分带。
- 自检阈值别用存量数据的上界（如"道具数量 ≤999999"会被 1500 万金钱打回）。
  **只校验本次新增的量级**。
- 改完必须跑 `--apply` 的自动回滚路径；md5 对不上就说明回滚没生效。
