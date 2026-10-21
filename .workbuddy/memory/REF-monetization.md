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

## 关键锚点数值（2026-10-21 R13 之后）
- 直充 id=1..6（Type=3）：6 元 60 钻 → 648 元 8424 钻，10 → 13 钻/元（**阶梯很窄，故意不扩**）。
- 月卡：**1.364 抽/元**（月激活 3600 钻 = 120×30，**不含 300 立得** —— 那 300 在已关停的
  SKU 9 里，`putMonthCard()` 只写激活时间、不发任何道具，R11 记的 1.477 是错的）。
  豪华月卡 980+360×30 = 0.501；30 元变体 0.659 —— **月卡家族自己越贵越不值**（待处理）。
  `MonthcardConfig.Price` 是**激活所需的累计充值门槛**，不是商品价。
- 🔴 **月卡"白送"通道**：全表 830 个 SKU 的 `AccumulativeRecharge=1`，
  `BuyGoodsLogic` 486 行「月累计充值额从 <12 跨到 ≥12 就 `putMonthCard()`」
  ⇒ **买两张 6 元包 = 送一张月卡**，不需要买月卡 SKU。到期时 `getMonthCard()` 把
  `monthSaveAmt` 归零 ⇒ 每 30 天可白拿一次。这条配置改不动（改 `AccumulativeRecharge`
  会连带 `saveAmt`/`maxSingleR`/`changeActivity`），只能动服务端或 `MonthcardConfig.Price`。
- 月卡限购的正确落点（配置层）：`Time=8`（自然月刷新）+ `DailyUpdate=30` + `Limit=1`
  + `LimitShow=1`。依据 `AbstractWelfareBag.refresh()` 的 `timeType==8` 分支与
  `PerpetualWelfareBag` 构造器；`DailyUpdate>0` 才会进 `refreshItemInfo`。
- 基金 LuxuryFund：Type 78=13200 钻、79=**43180**（R13 起，原 35360）、7801/7802=6600、
  7901/7902=13600（30 天）。🔴 7801/7802/7901/7902 全是 `1#999#999` 关着的未来季，
  **开季前必须一起拉平**（7901 只有 0.417 抽/元）。基金总价值 = SKU 行 BaseReward + 本表日领。
- 战令 `BattlePassConfig.BuyId = 72001`（198 元，单档，无 30–68 元入门档）。
- 首充活动 = `GlobalActivity Id=5`（Type=5 RechargeTotal），`ActivityRewardConfig ActivityId=5`。

## 🔴 价值口径必须三源合并（R12）
一个 SKU 的抽等值 = SKU 行 `BaseReward`/`ExtraReward` + `LuxuryFund` 日领
+ `ActivityRewardConfig` 轨道（经 `GlobalActivity.CanBuyRechargeId` 挂到 SKU）。
只看 SKU 行会把成长基金判成空包。成长基金（活动 6/601–604）的 10 个节点就是它的全部产出。

全表真实阶梯（抽/元，2026-10-21 **R13 之后**）：
成长基金 98 元 **1.000**（原 1.399）＞ 月卡（累充 12 元白送）1.364 ＞ 首充 6 元 0.879 ＞
豪华基金 128 元 0.827 ／ 328 元 **0.827**（原 0.718 倒挂已拉平）＞ 战令 198 元 0.339 ＞
礼包带 0.234–0.353（原 0.194–0.292，整体 ×1.21）＞ 直充 0.046–0.059（首购 0.118）。
**落差 648 档 2.83x / 全带中位 3.35x**（原 4.8x / 5.6x）。
`LuckyCatConfig` 901–904 满次数 22,704 钻 → **24,068 钻（1.06x 期望 / 1.12x 上限）**，
R14 之前是 37,990（1.67x / 期望 1.50x）—— 是钻石产出口不是回收口，已收。
`OnSaleRule=1#999#999` = 永久关停，占 283/833 行；`Android_ilod_OneStoreCB` 计费点 0/833。
工具：`scripts/monetization_audit.py`（只读，7 项检查）·
`monetization_rebalance.py`（R13 四项 + R14 两项落表，`--only fund,pack,store,lux328,cap,cat`，
**pack 是乘法项，连跑两次会乘成 1.21²，已加 `_applied.json` 幂等锁**；其余项幂等只提示）。

## 🔴 「补券」的最小粒度是 1 张 ⇒ 低价档乘不动（R13）
6 元档中位 1.55 抽，补 1 张 = **+65%**；12 元 +32%、18 元 +26%、30 元 +15%。
所以 `×1.21` 这类乘法调整**只能在 30 元及以上做**：6/12/18 元整档不动，
否则 6 元包会顶到 0.42 抽/元、比 648 元档还甜 —— 正好造出要消灭的反向阶梯。
要动低价档只能换杠杆（加钻石 / 改内容结构），不能靠补券。

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

## 🔴 削峰的基准只能是「本档实测中位」，不是 R10 目标曲线（R14）
- R13 只补地板不削峰，把各档中位抬了 2~17%；拿目标曲线当上限会把 30 元档**一半**判成超标。
  正确做法：上限 = 本档（`ShowType`+`Name` 组）**中位 ×1.20**，地板 = 中位 ×0.80。
- `ShowType` 是货架页签、`Name` 是产品线，单调性按**组中位**比，不能按 SKU 逐个升序比（R11 教训）。
- Type=10 钻石大包**不参与档内削峰**：它走直充线（~0.05 抽/元），混进 98/648 档会把中位拉歪
  （曾出现过 12 元档 5.67x、648 档 6.53x 的假象）。`_tier_center()` 只取 `Type=5`。
  但 Type=10 仍要进**同族单调**检查（id=43 就是这样把 −57% 收到 −13.3%）。
- 削的优先顺序：**先削券（大叠优先），余量折钻石取整到 10**。券粒度 1 张 = 6 元档 16.7%，
  所以允许「多削 1 张」，条件是不得击穿地板。
- 规划必须**迭代到收敛**（每轮按累计削减重算中位）；单遍规划跑完还剩 9 个未削。
- 地板自检只校验「本次真削过的、且削前在地板之上」的行，否则存量低点会误报。
- R14 结果：82 行（券 −502 / 钻石 −2250，价格 0 漂移、非券非钻 0 漂移）。
  30 元档 4.18x→1.32x；最差档（12 元）2.91x→1.48x；无档 ≥2x；同族倒挂 17→14 处、最重 −64%→−13.3%。
  6~30 元档故意留 ≤15% 的「新手带溢价」（限购 1 的拉新锚点），不强行抹平。

## 🔴 LuckyCatConfig 有公式单元格，openpyxl 存盘会毁表（R14）
- `C24:C39` 是 `=C16+1` 这类公式。`load_workbook()` 不带 `data_only` 读到的是公式串
  ⇒ `ActivityId` 匹配不到 903/904，规划**静默只覆盖 16/32 行**。
- 带 `data_only=True` 读能拿到缓存值，但一旦用 openpyxl `save()`，**缓存值被丢弃**，
  下次 `data_only` 读回 `None`，导表也拿不到 ActivityId ⇒ 活动直接打不开。
- 正确姿势：`data_only=True` 读 + **直接改写 `xl/worksheets/sheet1.xml` 里 `<c r="G12">` 的 `<v>`**，
  并加自检「ActivityId 仍读得到」。任何 `LuckyCatConfig` 的改动都要跑这条自检。
- 服务端 `LuckyCatActivity` 用 `MathUtils.random(ValueDown, ValueUp)` ⇒ 期望 = (down+up)/2。
  改期望别动保底：`ValueDown < ConsumeValue` 会让最后几轮变负收益。
  上限 `ValueUp` 同时写 `ShowMax`（界面展示值）。

## 反面清单（已踩）
- 只补"钻/元"不看限购 ⇒ 得出"复制粘贴越多收入越高"或"大额不用管"的错误结论。
  128/328/648 大量 `Limit=6/9/10/15`（可复购），小额多是 `Limit=1` —— 阶梯必须按限购分带。
- 自检阈值别用存量数据的上界（如"道具数量 ≤999999"会被 1500 万金钱打回）。
  **只校验本次新增的量级**。
- 改完必须跑 `--apply` 的自动回滚路径；md5 对不上就说明回滚没生效。
