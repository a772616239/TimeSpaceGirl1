---
name: cheat-forensics
description: TimeSpaceGirl1 作弊取证 / 判定 / 处置。当用户说"这个号是不是开挂""查一下 XXX 的异常数据""帮我找漏洞""一键删掉作弊账号""清掉他的排行榜""封了这个号"时使用。内含三层工具（scripts/cheat/ 的 remote/detect/purge）+ 六条判据（含 BI 文件流水 reason=28 这种 Mongo 看不到的证据）+ 处置四步（备份→删产物→清榜→封号）+ 三条会导致线上崩榜的红线。
---

# 作弊取证 / 处置

> 深水区原理与逐条复盘：**`docs/cheat_detection_skill.md`**（判据）、
> **`docs/gm_abuse_incident_playbook.md`**（封禁/清榜/重启）、
> **`docs/cheat_incident_10000224_20261020.md`**（2026-10-10 GM 通道事故全链）。
> 工具：**`scripts/cheatctl.py`**（薄封装）→ `scripts/cheat/{remote,detect,purge}.py`。

## 什么时候用

| 用户说 | 走哪条 |
|---|---|
| 「这个号是不是挂」「帮我查 XXX」 | `scan`（只读，~25s） |
| 「全服扫一遍谁开挂」 | `hunt`（只读，英雄维度候选） |
| 「帮我找漏洞」 | `scan` 出结论后按 §4 定位入口 |
| 「删掉他的作弊数据」「清排行榜」 | `purge`（**默认 dry-run**） |
| 「封了他」「解封」 | `ban` / `unban` / `banlist` |

```bash
python3 scripts/cheatctl.py scan --uid 10000224            # 裁决
python3 scripts/cheatctl.py scan --uid 10000224 --json     # 机器可读
python3 scripts/cheatctl.py hunt                           # 全服候选
python3 scripts/cheatctl.py purge --uid 10000224           # 先看计划
python3 scripts/cheatctl.py purge --uid 10000224 --apply   # 再执行
python3 scripts/cheatctl.py purge --uid 10000224 --apply --ban
python3 scripts/cheatctl.py purge --uid 10000224 --account --confirm 10000224 --apply
```

## 1. 判据（改阈值改 `detect.TH`，文档必须同步）

**hard（命中即 CHEAT）**

| code | 含义 | 出处 |
|---|---|---|
| `bi_gm_reward` | BI 流水出现 `reason=28`（`BIReason.GM_REWARD`） | `assets/log/jl_item/<date>/item0.log` |
| `gm_reward_db` | Mongo `itemLog` 有 `reason=28` | 只在日志没断档时才有 |
| `hero_peer_outlier` | 最高英雄等级 > 同级(±5) P99 × 3 | 6 级号 340 级 vs 同级 30 级 |
| `hero_burst` | 120s 内出现 ≥8 个「异常英雄」（≥100 级或 ≥10 星） | 脚本按模板 ID 顺序发 |

**soft（两条以上才 SUSPECT）**：`hero_progress_skew`（养成总量 vs 账号等级）、`gm_request_burst`（>12 条 GM_REQUEST）、`gold_outlier`（金币 > 活跃号 P90×3）。

**info（只打印）**：`hero_high_level`、`rank_presence`、`gm_rejected_seen`。

## 2. 三条判据陷阱（都踩过）

1. **Mongo `itemLog` 会整段断档**。10000221–10000225 全是 0 条，空表上的「收支对账」恒闭合 ⇒ 必须查 BI 文件流水（保留期 30 天以上，而 `/data/srvlog/gameserver.log` 只留 2~3 天）。
2. **GM 改星级/等级不写 `heroLog`**（只有 `upHeroLevel`/`upHeroStar` 写）⇒ 「heroLog 干净」证明不了没作弊。
3. **「英雄等级高」本身不是证据**，正常十连抽也会 1 秒创建 10 个英雄（只是 1 级）。硬信号必须是「创建即满配 + 同级分位离群」。

## 3. 处置四步（`purge` 已固化，不要手工重来）

1. **备份**（自动）：`/root/incident_<tag>_<uid>/user_<uid>_<tag>.json` + 命中榜单的 `ZREVRANGE WITHSCORES` 快照；本地写 `scripts/cheat/reports/<uid>_<tag>.json`（含回滚命令）。
2. **删作弊产物**：`$unset heroManager.heroMap.<id>`（默认判据 `level>=100`，可 `--hero-level/--hero-star`）。
3. **清榜**：`ZREM` 每一名成员（含 `uid:heroId` 复合成员）、`RANKING_DATA` 的 JSON 里剔除该 uid、`supremacyInfo.uid=0`、`guildInfo.members` `$pull`。
4. **封号（可选）**：`HSET "10001:FORBID_LOGIN:" <uid> 0`。

## 4. 🔴 四条红线（违反会导致线上崩榜 / 数据不可恢复）

1. **只删本人成员，绝不清整榜**：db0 有 6200+ key、近 5000 个是排行，清空不可恢复。
2. **删英雄必须同步清 `heroForceSort`**：它只排「≥100 级前 5 名」，且 `refreshHeroForceSort` 在结果为空时**不回写**（`HeroForceRank.java:168`）⇒ 不清会留下指向已删英雄的引用，`getMyInfo` 取空。
3. **排行榜成员要在删数据的同时清**：`HeroForceRank.getOptional` 里 `getHero(heroId)` 为 null 时直接 NPE（`HeroForceRank.java:88-89`），全服点排行榜都会报错。
4. **删号 ≠ 封号**：本服「查不到 user 就自动建档」，删号只是重置。必须写 `FORBID_LOGIN`。

## 5. 生效条件

- 英雄/物品数据在 Mongo，**玩家离线时下次登录即生效**；在线则必须踢下线或重启（会覆盖内存态）。
- `FORBID_LOGIN` 由 `MinuteTask` 每分钟重载，1 分钟内生效，重启不丢。
- `RANKING_DATA`（`RankingRewardLogic.rankingDataMap`）与 `guildInfo`（`GuilidManager`）是启动加载 ⇒ 改完**必须重启**才对内存里的排行奖励逻辑生效。
- 校验口径：`purge` 结束自动打印「英雄数 / ≥100 级数 / heroForceSort / 榜残留 / 封禁」，全服复扫用 `hunt`（应为空）。

## 6. 定位「漏洞在哪」的固定套路

1. `grep -B3 "In a formal setting" /data/srvlog/gameserver.log` → 抓到正在打 `GM_REQUEST` 的 uid；
2. `GMRequestHandler.getMessageCode()` 绑的是公网协议 `GM_REQUEST`(10606)，唯一闸门 `ServerProperties.isDebug()`；
3. 查 `config/application.properties` 与 **jar 内置** `application*.properties`（profile 11/12），必须用运行时日志 `ServerProperties ->` 验证，不能只 grep 文件；
4. 指令编号查 `globals/GlobalGm.java`：`HERO_STAR=4`（`4#heroId#star`）、`ONE_KEY_ITEM_OR_HERO`、`FULL_OF`、`GM_LOGIN_BY_UID=40`（可顶号）。
