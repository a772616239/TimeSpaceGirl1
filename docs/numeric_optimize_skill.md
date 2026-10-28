# 数值迭代优化（货币化价值带）· 使用与设计说明

> 工具：`scripts/numeric_optimize.py`（引擎）
> 入口：Jenkins `TS-Numeric-Optimize`（`.jenkins/jobs/TS-Numeric-Optimize.groovy`）
> 度量口径复用：`scripts/monetization_audit.py` + `scripts/monetization_backtest.py`（同一份代码，不另起一套）
> 奖励串工具复用：`scripts/monetization_ladder.py`（`parse_pairs / add_items / pick_ticket`）
> 账本：`data_execl/numeric_opt/{ledger.jsonl,state.json}`（入库）　产物：`_output/numeric_opt/<run>/`（不入库）

---

## 0. 一句话

**把 R7→R16 那套「改表 → 手跑回测 → 肉眼看 8 个目标 → 再改」变成一次可复跑的坐标下降**，
并且给这个循环一个**能执行的设计判据**：在固定的通胀预算内，价值带能推多陡、倒挂能压到多浅。

它**不是**「全表再 +20%」那种放水工具，恰恰相反：通胀是硬约束，超预算的候选直接判不可行。

---

## 1. 为什么需要它（人工轮次的四个代价）

| 人工做法 | 代价 |
|---|---|
| 从一堆指标里判断「这轮该动哪里」 | 每轮都要重新解释口径（抽等值 / 可售 / 档中位），烧掉大量 token |
| 算每个 SKU 该补几张券 | 除不尽、一张券在 6 元档 = +65%，靠手算必然踩粗粒度坑 |
| 改完重跑回测看目标 | 「看着差不多」不是判据；G3 只数 >10% 的倒挂，达标后还会剩一堆浅倒挂 |
| 记住旧值 | 没有账本就不可比、不可回退 |

---

## 2. 全程只读，只有一条写入路径

```
measure / search  ──只读──►  _output/numeric_opt/<run>/{report.md, metrics.json, best/}
                                    │
                          promote --apply（唯一写 base_data 的入口）
                                    ▼
                    备份(工程外) → 写表 → 重新度量 → 未达标变多则自动回滚
```

- `search` **绝不写** `data_execl/base_data`；
- `promote` 不带 `--apply` 只做体检（不变式校验），带 `--apply` 才写，且**写后自动复核**；
- Jenkins 里 `PROMOTE=false`（默认）时整轮构建对配置表零改动。

---

## 3. 红线（写死在生成器与校验器里）

| 允许改 | 禁止改 |
|---|---|
| `BaseReward` / `RewardShow` 里的**券**（19 / 20 / 87 / 50007 的数量） | `Price`（计费点按 SKU id 绑定渠道商品，改价 = 渠道金额与配置不符） |
| 削峰时**只扣券** | 钻石 `16` 数量（全局通货，加钻会同时通胀抽卡以外的一切系统） |
| — | `Type` / `ShowType` / `OnSaleRule` / 限购 / 计费点 / 其它任何道具的数量 |

`promote` 的 `diff_check()` 逐行逐列比对，违反任一条直接拒绝落表（并列出前 20 条越界项）。

---

## 4. 口径（必须随结论一起引用）

- **抽等值** = 券张数 + 钻石 / 220（220 = 单抽直耗钻，十连 2000 钻 = 200/抽）；
- **可售** = 有计费点 + 未 `1#999#999` 门控 + `Price > 0`（当前 502 个，其中 Type=5 礼包 473 个）；
- **加权抽/元** = Σ抽 / Σ价（全表可售，通胀的粗口径，比「人均发钻」稳，不引入第二套玩家行为假设）；
- **档中位** = 同一价格档内 `抽/元` 的中位数（正常玩家视角，对离群行不敏感）。

⚠️ 生产库只有 209 个玩家、**无充值流水** ⇒ 全部是**同一口径下的相对比较**，
不产出「预计月流水」这类绝对数字（同 `monetization_sim.py` 顶部声明）。

---

## 5. 目标函数

```
J = -1000×实际陡度 + 100×未达标目标数 + 20×价值带误差 + 60×倒挂深度
    + 40×离散超标 + 1000×新手带跌幅 + 1e4×通胀超限
```

| 项 | 定义 | 为什么这么定 |
|---|---|---|
| **实际陡度** | (最高档中位/父本) ÷ (最低档中位/父本) − 1 | **奖励结果不奖励旋钮**。直接奖励 `slope` 会让「什么都不做」也拿分；这样什么都不做 = 0 |
| 未达标目标数 | `monetization_backtest.goals()` 8 条里 FAIL 的条数（n/a 不计） | 目标就是判据，不再靠肉眼 |
| 价值带误差 | 各档中位 vs 设计目标带的相对偏差，按档内 SKU 数加权 | 偏向「整齐」而不是「越甜越好」 |
| 倒挂深度 | 同族相邻档中位下跌幅度之和 | G3 是布尔且只数 >10% 的，达标后仍可能有一堆浅倒挂 |
| 离散超标 | 同价档 max/min 超出 1.6x 的部分之和 | G1 的连续版 |
| 新手带跌幅 | ≤30 元档中位相对父本的最大跌幅 | 低价档 29/30 是 `Limit=1` 拉新锚点，削它能刷高「陡度」= 拿新玩家换指标 |
| **通胀超限** | 加权抽/元 相对父本涨幅超出 `MAX_INFL` 的部分 | **硬约束**（1e4 惩罚），任何陡度都抵不掉 |
| 累计通胀超限 | 加权抽/元 相对**首次锚点**涨幅超出 `CUM_INFL`(25%) 的部分 | 同上（也是 1e4）。每轮预算都是相对父本算的，没有这一项「每轮 +5%」会复利成「跑十次 +63%」，而每次单看都合规 |

> 🔴 为什么通胀不能当软权重：软权重下「陡度 +20% 换通胀 +9%」会被判成更优（实测过）。
> 那正是 R7 的错误 —— 同样一分钱收入，纯加数值的钻石代价是内容改造的两倍（docs/付费数值回测与礼包改造 第 2 节）。

> 🔴 **锚点粘住，不随落表重置**：`state.json` 的 `anchor_rate` 只在第一次跑时写入，
> 之后 `setdefault` 不再动。落表成功后如果自动重置，等于「每落一次表再送 25% 复利空间」，
> 这道闸就形同没有。要把它当新基准，只能人显式 `promote --apply --reanchor`
> （对着设计复核过的版本才做，别在流水线上顺手勾）。

**权重汇率**：1 个目标 = 100 分 = 10% 陡度；1% 新手带跌幅 = 1% 陡度。

---

## 6. 旋钮（搜索空间）

| 旋钮 | 含义 | 默认 | 搜索步长 |
|---|---|---|---|
| `slope` | 设计目标带斜率：`目标 = 档中位 × (1 + slope × 档位相对位置)` | 0.00 | ±0.10 |
| `band_tol` | 收敛带下沿：低于 `目标×(1-band_tol)` 才算离群低值 | 0.20 | ±0.05 |
| `cap_tol` | 收敛带上沿：高于 `目标×(1+cap_tol)` 才削峰 | 0.20 | ±0.05 |
| `gap` | 每轮吃掉缺口的比例（0.5 = 只走一半） | 1.00 | ±0.25（上限 1.0） |
| `mono` | 目标带是否单调化（PAVA 加权合并凹陷档） | true | 翻转 |
| `cut` | 是否允许削峰（只扣券 + 有地板） | true | 翻转 |

**两种动作必须分开判**（这是本工具最容易写错的一处）：

- **推陡**（目标比现状高 2% 以上）→ 该档所有低于目标的件都补，档中位才会跟着抬；
- **收敛**（目标≈现状）→ 只动 `±band_tol` 之外的离群件，不许动结构。

把两者合成一条「低于中位就补」，实测会把 473 个包全推一遍：档中位被整体抬高、
倒挂深度 0.005→0.256、**J 从 0.31 恶化到 15.43**。那不是优化，是把「收敛」误当「抬全线」。

---

## 7. 算法（坐标下降 + 父本基线）

```
父本 = 工作区当前表 → base_band(PAVA) / ref(档中位) / J_nothing
seed = 账本里的上轮最优旋钮（--reset 可忽略），命令行参数覆盖
第 r 轮：
  对 slope/band_tol/cap_tol/gap 各试 ±1 步，再翻转 mono/cut（约 9 个候选）
  每个候选：生成表 → 写草稿目录 → 全表回测 → 打分
  只有 J 严格更小才接受（并当场固化到 best/）
  本轮无改进 → 全部步长减半；步长到底即收工
收尾：J_best < J_nothing 才算「有改进」，否则**返回 4 = 无可改进**
```

- **父本基线门槛**：候选必须严格优于「什么都不做」。做不到就报「无可改进」并返回 4，
  Jenkins 标黄。一个只会加数值的 job 比没有 job 更危险。
- **账本续跑**：`state.json` 记住上轮最优旋钮，下一轮从那里继续（跨构建迭代）；
  `ledger.jsonl` 记每轮的 J / 陡度 / 通胀 / 改动 SKU 数，用 `ledger` 子命令看历史。
- **赢家固化**：`best/` **不用拷贝**，而是拿 `changes` 确定性重建一遍（草稿目录是所有候选
  共用的，等搜索结束时它装的是最后一个被评估的候选）。收尾时无条件重建一次，
  所以「种子本身就是最优、全程没有改进事件」也不会缺 `best/`。

---

## 8. 命令速查

```bash
PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python

$PY scripts/numeric_optimize.py measure                     # 8 目标 + 分档中位 + J
$PY scripts/numeric_optimize.py measure --json /tmp/m.json

$PY scripts/numeric_optimize.py search --rounds 4            # 只读寻优
$PY scripts/numeric_optimize.py search --rounds 4 --max-infl 0.03 --slope 0.05
$PY scripts/numeric_optimize.py search --rounds 2 --cut false --mono false
$PY scripts/numeric_optimize.py search --rounds 4 --reset     # 不沿用账本

$PY scripts/numeric_optimize.py promote --run opt-7-1         # 只体检
$PY scripts/numeric_optimize.py promote --run opt-7-1 --apply # 落表（备份+复核+回滚）
$PY scripts/numeric_optimize.py promote --run opt-7-1 --apply --reanchor  # 顺带把当前值立为新锚点
$PY scripts/numeric_optimize.py ledger --n 10
```

退出码：`0` 有改进 / `4` 无可改进 / `2` 越界改动被拒 / `3` 落表后目标变差已回滚。

---

## 9. Jenkins 用法

`TS-Numeric-Optimize`（视图「时空美少女 · 全流程」）

| 参数 | 默认 | 说明 |
|---|---|---|
| `ROUNDS` | 4 | 每轮约 9 个候选，单个候选约 4-5 秒 ⇒ 4 轮约 3-4 分钟 |
| `MAX_INFL` | 0.05 | 通胀预算。**设 0 就是「只重排、不加总量」模式** |
| `SLOPE` | 空 | 起点斜率；空 = 沿用账本上轮最优 |
| `BAND_TOL` | 空 | 收敛带下沿，空 = 0.20 |
| `CUT` / `MONO` | true | 削峰 / 目标带单调化 |
| `PROMOTE` | **false** | 落表（备份到工程外 + 写后复核 + 变差自动回滚） |
| `PUSH` | **false** | 落表后 commit+push（只 `git add` 那一张表） |
| `REANCHOR` | **false** | 落表成功后把当前值立为累计通胀新基准。默认关：累计上限跨轮粘住，不自动重置 |
| `TRIGGER_SYNC` | false | 落表后触发 `TS-Table-Sync`（`MODE=plan` 只体检）。🔴 **必须同时勾 PUSH**，否则 ⑥ 直接判红（导表在独立 clone 里 reset 到 origin，没 push 会导成旧表） |

阶段：① 取证与前提声明 → ② 基线度量 → ③ 迭代寻优（rc=4 标黄）→ ④ 不变式校验
→ ⑤ 落表（可选）→ ⑥ 触发导表体检（可选，需 PROMOTE+PUSH+TRIGGER_SYNC）→ ⑦ 交付指引 + 账本。
产物全部进 `evidence/`，JUnit 有趋势。

**典型三种跑法**

1. **只看结论**（默认）：`ROUNDS=4`，其余不动 → 看 `report.md` 的陡度/通胀/改动清单。
2. **预算扫描**：`MAX_INFL` 分别设 0 / 0.03 / 0.05 / 0.10 各跑一次 → 得到「陡度 vs 通胀」的成本曲线，
   这是产品决策要的那张表，不是某个单点。
3. **落表**：看报告认可后，`PROMOTE=true`；确认 diff 再 `PUSH=true` 重跑；
   然后 `TS-Table-Sync`（EXPORT=true）导表、按需 MODE=apply 推服务端。
   三件一起勾（`PROMOTE+PUSH+TRIGGER_SYNC`）能让 ⑥ 顺手把导表体检也跑掉，但那只到 `MODE=plan`。

---

## 10. 踩过的坑（血泪，别再踩）

| # | 症状 | 根因 | 修法 |
|---|---|---|---|
| 1 | 473 个包的券被扣光，加权抽/元 0.3178→0.0663（-79%） | `monetization_backtest` 的 `m["tier"]` 是**抽/元（rate）**，生成器拿**券张数**去比，量纲不一致 ⇒ 每个包都成了「离群高值」 | 统一在「抽」空间算，只有绝对值乘 `price` 换算 |
| 2 | 「147 个 SKU 改动」的候选与「什么都不做」量出来**一模一样** | 快照缓存键 `_slug(路径)` **截断到 60 字符**且命中即返回 ⇒ 同一 run 的候选全部撞键 | 候选目录自带 9 张表，直接绕过 `materialize()` 的缓存（`_install_materialize_bypass`） |
| 3 | 搜索「跑完第 4 轮就没了」，**没有 traceback** | 沙箱批量删除闸门按**每轮累计文件数**算（阈值 50），40 候选 × 9 表 = 360 个文件，清理阶段把进程干掉 | 改成**单草稿目录 + 零删除**，只固化赢家（换成「每候选一个目录 + 用完删」必然复发） |
| 4 | 落表体检「改动 0 个 SKU」，落表等于没做 | 同一轮所有候选共用草稿目录，而快照在**轮末**才存 ⇒ 存到的是最后一个被评估的候选 | 赢家不拷草稿，按 `changes` **确定性重建**（见 #6） |
| 5 | `J` 从 0.31 恶化到 15.43 | 把「收敛档内离散」写成「低于档中位就补」，等于抬全线 | 分离「推陡」与「收敛」两种动作（第 6 节） |
| 6 | Jenkins 在 ④ 判红：「找不到候选表 …（先跑 search）」 | 种子本身就是最优 ⇒ 全程没有「改进」事件 ⇒ `best/` 从没写过；而 ④ 是 `when OPT_MODE=='RUN'` 无条件跑的 | `save_best()` 改为确定性重建，并在写报告前**无条件**调一次 |
| 7 | 「陡度 +20% / 通胀 +9%」被判成更优 | 通胀写成软权重（当时 2000 分），陡度收益盖得住 | 改成硬约束 `W_INFEASIBLE=1e4`；`gap>1.0` 的候选直接不生成 |
| 8 | 每轮都在预算内，长跑十轮总量却 +63% | 每轮预算都是相对**当前父本**算的，天然复利 | 加跨轮累计上限 `CUM_INFL=25%`；锚点**粘住**，要重置只能人显式 `--reanchor` |

---

## 11. 验收记录（2026-10-28）

- `measure`：8/8 目标 PASS，加权抽/元 **0.3178**，J=0.31；
- `search --rounds 3`（默认预算 +5%）：最优 `slope=0.10 / band=0.20 / cap=0.20 / gap=1.0 / mono / cut`
  → 648 元档中位 **0.3532 → 0.389**（陡度 +10.0%），加权抽/元 **0.3323（+4.6%，在预算内）**，
  8/8 目标仍全 PASS，改动 147 个 SKU（全部只动券）；
- `promote`（不带 --apply）：不变式校验通过（Price/Type/ShowType/OnSaleRule/计费点/非券道具 全未变）；
- `promote --apply` 实测：备份到 `~/Documents/TimeSpaceGirl1-config-bak/_backup_before_numeric_opt/<ts>/`，
  写后复核 8/8 PASS，回滚可用（测完已按备份还原，`git diff` 为空）；
- `promote --apply --reanchor` 实测：`锚点已重置：0.3178 → 0.3323`，`state.json` 的
  `anchor_rate` 同步更新（测完已还原，`md5` 与验收前一致：`d061d0bfd193cb15aa91e81f3c746cc5`）；
- Jenkins `TS-Numeric-Optimize`：语法 lint 三道全过，构建 #1–#5 逐轮收口
  - `#1` FAILURE：暴露并修掉基线度量的 `NameError`；
  - `#2` FAILURE：暴露 `best/` 缺失（坑 #6），④「找不到候选表」；
  - `#3` SUCCESS（`ROUNDS=2`，只读）：② 基线 0.3178 / ③ 最优 J=−100.09（+4.6%）/
    ④ 改动 147 SKU 不变式全过 / ⑦ 交付，JUnit 3 环节失败 0，`evidence/` 含
    `report.md`+`metrics.json`+`baseline.json`+`best/`+`next-steps.txt`；
  - `#4` SUCCESS（`PROMOTE=true`）：补测 ⑤ 落表分支 —— 备份 `…/20261028-140432/`、
    写后复核 8/8、`1 file changed 94459→94477 bytes`，JUnit 4 环节失败 0（测完已还原）；
  - `#5` SUCCESS：`REANCHOR` 参数生效、⑤⑥ 按条件跳过、⑦ 交付正常；
  - `TRIGGER_SYNC` 的「必须先 push」闸门单独验过（`PUSH=false` ⇒ rc=1 并打印原因）。
