# 测试服活动全开（页签批量点亮）

> 更新时间：2026-10-21
> 关联：`server_ops_runbook.md`（区服/表/热更口径）、`测试服导表部署与角标核查-20261021.md`（表落盘路径）、
> `scripts/open_panel_activities.py`（本流程唯一脚本）
> 一句话：**改一张 `GlobalActivity.txt` + 写一个热更 json，1~2 分钟把三块面板的页签全点亮，不重启、不踢线。**

---

## 0. 什么时候用

要给 `OperatingPanel` / `AdjutantActivityPanel` / `ExpertPanel` 逐个页签测动画（翻入、落位、列表逐格），
但活动是「一期一期」开的，页签大部分是隐藏的 —— 一个个去后台开太慢，用本流程一次全开。

---

## 1. 页签可见性是三层叠加，不是「后台一个开关」

```
① 服务端 ActivityLogic.openActivityIds            ← 只由 GlobalActivity 表算出来
        ↓ 登录时 getActivityInfos 下发 mission
② 客户端 ActivityGiftManager.IsActivityTypeOpen(type)
   = 客户端 GlobalActivity 配置里该 Type 的某个 Id ∩ 上面的 mission
        ↓
③ 各面板自己的附加条件
   OperatingPanel : IsQualifiled(type)（OpenRules 等级/关卡）＋ LifetimeIsBuyup / WeekIsEndTime
   AdjutantActivityPanel : IsActivityTypeOpen + IsQualifiled
   ExpertPanel : 基本只看 ②（少数页签是 goods：限定珍藏）
```

⇒ **只有 ① 能靠改表解决**；②的配置是客户端表（导表产物，别手改）；③是玩家状态。

---

## 2. 配方（本地测试服，1~2 分钟生效）

```bash
python3 scripts/open_panel_activities.py --dry-run   # 先看计划
python3 scripts/open_panel_activities.py --apply     # 备份 + 改表 + 写热更 json
python3 scripts/open_panel_activities.py --restore   # 从最早一份备份还原
```

脚本做三件事：

1. 备份 `~/home/java/gameserver/conf/server/GlobalActivity.txt` → `.bak-<时间戳>`；
2. 对 31 个目标 Type **各挑一行**（Id 最小＝基准期）改成
   `Time=1 / StartTime=昨天 / Endtime=20301231 235900 / GapTime=0 / IfOpen=null / IsOpen=1`，
   其余行不动（避免同一活动 30 多期同时开着）；已经开着的（6、14、10021）跳过；
3. 写 `~/home/java/conf/c_database_version.json` = `{"version":1,"tables":"GlobalActivity"}`，
   触发 `MinuteTask` 的 `STableManager.updateTablesWithTableNames(true)` 热更。

改完客户端要**重新登录**（Editor 里 Stop → Play）才会拿到新的 activityInfo。

### 验证

```bash
grep "hotfix tableGlobalActivity" ~/home/java/logs/run-gs-detached.log | tail -1
grep "openActivityIds" ~/home/java/logs/run-gs-detached.log | tail -1
```

2026-10-21 19:22 实测：`openActivityIds` 从 **18 个 → 45 个**，无 `Exception::1`。

---

## 3. 表字段口径（踩过的坑）

| 字段 | 坑 |
|---|---|
| `Time` | 1=绝对时间、2=创角、3=开服、4=解锁、5=循环。**1/5 的 StartTime 是 `yyyyMMdd HHmmss` 字符串，2/3/4 是「秒偏移」**（`SGlobalActivity.init` 分两路解析），改表时别混 |
| `StartTime/Endtime` | 表里绝大多数是 **2029 年**（未来）⇒ 活动永远不开，这就是「后台看着配了、游戏里没有」的主因 |
| `IfOpen` | `2#N` = 开服 N 天后才开（`ActivityLogic.isOpen`）。**只改时间不清它，还是不开**；清成 `null` |
| `Endtime=0` | 表示永不结束（`endTime != 0` 才判结束）。但客户端会显示 1970，所以脚本用 2030 年而不是 0 |
| 两处副本 | `conf/server/` 是真正被读的（`SysUtil.getPath("conf","server",...)`），`assets/conf/server/` 是跟随副本，脚本两个都写 |
| 同 Type 多行 | 一个 Type 常有十几期（腐化侵袭 32 行）。全开会让客户端 `IsActivityTypeOpen` 取到最后一期、数据互相打架 ⇒ **只开基准期一行** |
| 热更 json 路径 | `STableManager.jsonPath = "../conf/"`，相对 `~/home/java/gameserver` ⇒ 实际是 `~/home/java/conf/`。这个目录默认**不存在**，日志每分钟刷 `the c_database_version.json is not exist`，建了就生效 |
| 热更顺序 | `MinuteTask` 先 `dispatchEvent(MinuteTaskEvent)`（查活动）再 `updateTablesWithTableNames` ⇒ **改表后第 1 分钟热更、第 2 分钟才开活动** |
| 无实现类 | `ActivityTypeEnum` 里没注册的 Type 永远进不了 `openActivityIds`（`getActicityType` 返回 null 直接 continue）。例：**Type 26 天宫达人**、Type 23 累计签到 |

---

## 4. 本流程开不出来的页签（要另走）

| 页签 | 卡在哪 |
|---|---|
| 运营-激励 tab7/8（基金128/328） | `OperatingManager.IsBaseOpen` → 礼包 goods 数据（`StoreConfig` / 玩家 goods endTime），不是活动表 |
| 运营-激励 tab15~19（5 个战令） | `GetWarOrderForGlobalSystemId` → 战令 `encouragePlanClassifies` 下发数据 |
| 专家 tab25（限定珍藏） | `IsGiftBuyActive` → `ShowType=20` 直购礼包 goods 的 endTime |
| 专家 tab26（天宫达人） | 服务端没有 Type 26 的实现类，表里怎么配都开不出来 |
| 专家 tab1~6、18、28、29、30 | `ExpertPanel:RefreshActivityShow` 里**硬编码 `SetActive(false)`**，要改代码 |

---

## 5. 回滚

```bash
python3 scripts/open_panel_activities.py --restore   # 还原原表（仍靠热更生效）
```

只想立刻关掉：还原后删掉 `~/home/java/conf/c_database_version.json` 并重启游戏服。
