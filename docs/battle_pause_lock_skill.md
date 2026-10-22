# 战斗暂停锁 Skill（多源暂停 / 反复切暂停 / 卡在暂停）

> 更新时间：2026-10-23
> 一句话定位：**战斗里所有「暂停/恢复」都必须走 owner 锁，谁停的谁放；排查「战斗不动了」先看持锁清单。**
>
> 适用范围：`Modules/Battle/**`、`Modules/Guide/**` 里任何会 `BattleManager.PauseBattle/ResumeBattle` 的地方。
> 关联文件：
> - 锁本体：`Assets/ManagedResources/~Lua/Modules/Battle/BattlePauseLock.lua`（纯逻辑，可离线单测）
> - 门面：`Assets/ManagedResources/~Lua/Modules/Battle/BattleManager.lua`（`IsPlay` / `PAUSE_OWNER` / 看门狗）
> - 回归：`scripts/lua-tests/test_battle_pause_owners.lua`（A 段锁本体 13 例 + B 段门面 7 例）
> - 字节码：`scripts/lua-bytes-sync.sh`；打包：`scripts/check_lua_bundle_fresh.sh`

---

## 0. 🔴 三条最容易踩的坑

### 坑 1：`PauseBattle()` 在 `IsPlay == 0` 时**什么也不做**（连记账都不记）

这是历史行为，故意保留：回合切换（`BattleOrderChange`）在开战前就调 `PauseBattle`，
如果那时记了账，`StartBattle` 之后就会永久暂停。

⇒ **想在「还没开战」时挂起战斗是做不到的**，只能在 `StartBattle` 之后暂停。
⇒ 反过来，`ResumeBattle` 在停战态是空操作，不会把 `IsPlay` 拉成 1。

### 坑 2：`tween:Kill()` / `ClearDelayFunc()` / 单位 `Dispose` ⇒ 配对的 Resume **永远不会执行**

`ResumeBattle` 大量挂在 `DOTween` 的 `OnComplete` 和 `DelayFunc` 上。这些回调被取消时，
旧实现没有任何兜底 ⇒ 那个暂停源永久持锁 ⇒ **战斗永久暂停，只能重开**。

现口径：
- `RoleView:DoFightMove` 里 Kill 掉上一个位移 tween 前，**先手动 `ResumeBattle(pauseOwner)`**；
- `RoleView:Dispose` 开头 `self:ReleasePauseOwners()`（本单位的位移/特写/PV 三把锁一次清）；
- 任何「回调确定不会再来了」的路径，用 `BattleManager.ReleasePauseOwner(owner)` 强放，
  不要指望配对的 `ResumeBattle`。

### 坑 3：owner 写错 = 静默泄漏

`ResumeBattle` 释放一个没持有的 owner 只返回 `false`（不报错）。**同一个暂停点，
Pause 和 Resume 必须用同一个 owner 常量**，否则锁永远不释放。
跨函数配对的（如引导：`GuideManager` 暂停、`GuidePanel` 恢复）统一用 `PAUSE_OWNER.GUIDE`。

---

## 1. 旧实现到底错在哪（实测对照）

旧口径：`IsPlay` 三态（0 停战 / 1 播放 / 2 暂停），`PauseBattle` 只在 `==1` 时置 2，
`ResumeBattle` 只在 `==2` 时置 1 —— **两个都是幂等置位，谁都能放掉别人的暂停，谁都能被后来者吞掉**。

| 场景 | 期望 | 旧实现实际 |
|---|---|---|
| 引导暂停中，剧情也暂停；剧情先结束 | 暂停 | **播放中**（引导遮罩下战斗继续跑） |
| 位移暂停中单位阵亡，tween 被 Kill | 恢复 | **永久暂停**（没人再 Resume） |
| 位移 + 特写两个源，特写先结束 | 暂停 | **播放中**（位移还没跑完） |
| 反复点退出，同源上锁两次只走一次 cancel | 暂停 | **播放中**（弹窗还开着，战斗已开跑） |
| 连放两次大招特写，第一次收尾 | 暂停 | **播放中**（第二次特写还在播） |

复现脚本（不进库，纯演示）：三态置位的 5 个场景全部与期望相反。

「反复切暂停」的典型链路 = 第 4 行：`BattlePanel` 的 `btnExit` 每点一次就
`PauseBattle` + `MsgPanel.ShowTwo`。第二次点击把上一次的 `cancelFunc` 顶掉，
它那把锁再也放不掉；同时**旧倒计时 timer 还在跑**，31s 后 `MsgPanel.OnRightBtnClick()` ⇒ 自动退出战斗。

---

## 2. 现口径：按 owner 记的引用计数锁

```
PauseBattle(owner)          上锁（同一 owner 可叠计数）
ResumeBattle(owner)         释放一次；全部 owner 都空了才真的置回播放
ReleasePauseOwner(owner)    强放某个 owner 的全部计数（回调不会再来的路径）
ReleasePauseOwnerPrefix(p)  按前缀强放（单位 Dispose 用 role:<实例>:*）
ReleaseTransientPauseOwners 强放所有「演出型」锁（切后台/切场景用，见 §2.2）
StopBattle()                状态归 0 并清空所有锁（每场开始/结束都干净）
IsBattlePlaying()           == 播放中
IsBattlePaused()            == 暂停（至少一个源持锁）
IsCanOperate()              != 停战（暂停时按钮仍可点，与旧一致）
GetPauseOwnersStr()         调试用："story, guide x2"
```

`BattleManager.IsPlay` 保留为**只读镜像**（`SyncPauseState()` 每次操作后刷新），
日志/旧代码仍可观察，但不要再直接赋值。

### owner 分配表（改代码前先查这张表）

| owner | 位置 | 说明 |
|---|---|---|
| `STORY` | `BattleView.RoundBeginDialogue` 暂停 / `StoryManager.EventTrigger` 回调释放 | 回合剧情对话框 |
| `ORDER_CHANGE` | `BattleView.BattleOrderChange` 暂停 / `EnemyAppear` 收尾释放 | 回合切换（首回合在停战态，自动忽略） |
| `HELP_HERO` | `BattleView.OnAddRole(isHelp)` / `ShowHelpHeroFrame` 3.5s 释放 | 助战英雄入场 |
| `TIBU` | `BattleView.OnAddTibuRoleShow` / 2s 定时释放 | 替补上阵 |
| `POKEMON` | `BattleView.OnSkillCast`（宠物/合体技） | 演出结束释放 |
| `EXIT_CONFIRM` | `BattlePanel.btnExit` | 退出/跳过确认，31s 倒计时 |
| `BATTLE_END` | `BattlePanel.BattleEnd`、`GuideBattlePanel.BattleEnd`、`BattleTestPanel.BattleEnd` | 结算冻结 |
| `UNIT_SKILL` | `FightUnitView.OnSkillCast` / `SceneCardAniProcess` | 支援/副官/航母演出 |
| `GUIDE` | `GuideManager`(5 处) / `GuidePanel`(5 处) / `GuideBattlePanel` | 新手引导 |
| `FIGHT_MOVE` / `CLOSEUP` / `PV` | `RoleView`，key = `role:<实例>:<kind>` | **每单位独立**，互不干扰 |
| `DEFAULT` | 未指定 owner 的老调用 | 一把共享锁，只用于真正全局的临时暂停 |

### 2.2 切后台（`btnFightBack`）必须强放演出型锁

复现路径：`UIRoot/UIRoot/UINode/BattlePanel/DownRoot/option/btnFightBack` 反复点（退出→重进）。
切后台会把 `battleSceneLogicGameObject` / `battleSceneGameObject` 整块 `SetActive(false)`，
并把所有 Spine 复位成待机；此时正在播的特写 / PV / 位移 / 支援技 / 宠物技 / 助战入场
**再也走不到 `OnComplete`**，配对的 `ResumeBattle` 永远不会来 ⇒ 回到战斗时战斗是暂停的。
反复切 = 反复漏，最后表现为「怎么都动不了」。

所以两个点都强放（幂等，没锁就是 0）：
- `BattlePanel.btnFightBack` → `BattleManager.ReleaseTransientPauseOwners("btnFightBack")`
  （在 `ResetAllRoleAnimation()` 之前）
- `BattleView:OnOpenCustom()`（重进战斗）→ 再兜底放一次，覆盖「没走按钮就回到主界面」的路径

强放范围 = `BattleManager.TRANSIENT_PAUSE_OWNERS`（`role:*` + CLOSEUP/PV/FIGHT_MOVE/
UNIT_SKILL/POKEMON/HELP_HERO/TIBU），**不含**引导 / 剧情 / 退出确认 / 结算这些逻辑态锁。

### 新增一个暂停源的正确姿势（checklist）

1. 在 `BattleManager.PAUSE_OWNER` 加常量（别手写字符串）。
2. Pause 与 Resume **用同一个常量**；跨函数的把常量传下去，别在两处各写一遍。
3. 如果 Resume 挂在 tween / DelayFunc / 网络回调上 ⇒ 必须同时准备一条强放路径
   （Kill 之前 Resume、或 `ReleasePauseOwner`）。
4. 如果是「每个实例各一次」的演出（位移/特写/PV）⇒ 用 `RoleView:GetPauseOwner(kind)`
   生成实例级 key，并在 `Dispose` 里 `ReleasePauseOwners()`。
5. 同一入口可能被用户连点（弹窗、按钮）⇒ 加**重入保护**（见 `BattlePanel.btnExit` 的
   `exitDialogOpen` + 「弹窗已被别处关掉」兜底）。
6. 跑 `scripts/lua-tests/test_battle_pause_owners.lua`，并补一条你这条链路的用例。

---

## 3. 排查「战斗卡在暂停 / 战斗莫名在跑」

**卡在暂停**：等 45s 看红字日志，会打出所有未释放的源：

```
[BattlePause] 已暂停 46s 未恢复，持有锁的源：guide, help_hero
```

看到 `guide` ⇒ 引导的 `NextTrigger` 事件没派发（引导卡住了，不是战斗问题）；
看到 `role:0x...:fight_move` ⇒ 某个单位位移没走完就被移除（查 `Dispose` 是否漏了强放）；
看到 `closeup` / `pv` / `unit_skill` 且刚点过 `btnFightBack` ⇒ 切出战斗时没走 §2.2 的强放
（2026-10-23 之前的版本就是这个症状：反复切后台 → 回战斗画面完全不动）。

**莫名在跑**：说明某个源提前 `Resume` 了。按 owner 表逐条核对 Pause/Resume 是否**成对**，
重点看「同源重复上锁但只释放一次」和「跨源共用了一个 owner」。

GM 侧可随时 `BattleManager.DumpPauseOwners("手动查")` 打一行当前持锁清单。

---

## 4. 回归测试

```bash
# 不依赖 Unity
TS_ROOT=. LuaEncoder/luajit_mac/64/luajit scripts/lua-tests/test_battle_pause_owners.lua
# → ALL PASS
```

覆盖：嵌套不提前恢复、同源计数、未知源释放、强放、前缀强放、Stop 清场、
反复切 200 次收敛、三源交错 100 轮、漏 Resume 的泄漏、`OwnersStr` 顺序、
门面 `IsPlay` 镜像、反复点退出、`StopBattle` 清锁、看门狗红字内容。

改动锁本体后**必须先跑这个**，再谈真机。

---

## 5. 生效链路（别只改源码）

1. `scripts/lua-bytes-sync.sh` 重编 `LuaBytes/*_64.bytes`（本次 10 个文件，含新增
   `Modules_Battle_BattlePauseLock_64.bytes`）。
2. `BattlePauseLock.lua` 是**新文件**，必须重打 Lua AB（`lzma|luabytes.unity3d`）才会进包；
   `scripts/check_lua_bundle_fresh.sh` 退出码 0 才算 bundle 不早于字节码。
3. Editor 直接读 `~Lua/*.lua`，改完即可验；真机必须走 1+2。
