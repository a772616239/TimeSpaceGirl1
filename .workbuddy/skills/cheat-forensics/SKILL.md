---
name: cheat-forensics
description: TimeSpaceGirl1 作弊取证 / 判定 / 处置。当用户说"这个号是不是开挂""查一下 XXX 的异常数据""帮我找漏洞""一键删掉作弊账号""清掉他的排行榜""封了这个号"时使用。内含三层工具（scripts/cheat/ 的 remote/detect/purge/rankint）+ 六条判据（含 BI 文件流水 reason=28 这种 Mongo 看不到的证据）+ 处置五步（备份→清榜→删产物→封号→全榜体检）+ 五条会导致线上崩榜的红线。
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

## 3. 处置五步（`purge` 已固化，不要手工重来）

1. **备份**（自动）：`/root/incident_<tag>_<uid>/user_<uid>_<tag>.json` + 命中榜单的 `ZREVRANGE WITHSCORES` 快照；本地写 `scripts/cheat/reports/<uid>_<tag>.json`（含回滚命令）。
2. **清榜**（删号路径也一定会执行，见红线 5）：`ZREM` 每一名成员（含 `uid:heroId` 复合成员）、`RANKING_DATA` 的 JSON 里剔除该 uid、`supremacyInfo.uid=0`、`guildInfo.members` `$pull`。
3. **删作弊产物**：`$unset heroManager.heroMap.<id>`（默认判据 `level>=100`，可 `--hero-level/--hero-star`）。
4. **封号（可选）**：`HSET "10001:FORBID_LOGIN:" <uid> 0`。
5. **全榜体检**（自动，`--no-rank-integrity` 可关）：`RankIntegrity` 扫全部 zset，挑出「账号已消失 / 英雄已消失」的成员并 `ZREM`。手工只需 `python3 scripts/cheatctl.py rank-audit [--repair]`。

## 4. 🔴 五条红线（违反会导致线上崩榜 / 数据不可恢复）

1. **只删本人成员，绝不清整榜**：db0 有 6200+ key、近 5000 个是排行，清空不可恢复。
2. **删英雄必须同步清 `heroForceSort`**：它只排「≥100 级前 5 名」，且 `refreshHeroForceSort` 在结果为空时**不回写**（`HeroForceRank.java:168`）⇒ 不清会留下指向已删英雄的引用，`getMyInfo` 取空。
3. **删号 / 删英雄之后必须跑 `rank-audit`**（2026-10-20 事故）：`HeroForceRank.getFirst()` 取榜一后直接 `hero.getTemplateId()`，**没有判空**；而 `RankFirstHandler`→`RankLogic.getRankFirstInfo` 是**遍历所有榜**的，任意一个榜的第 1 名失效（账号被删、英雄被删）就抛 NPE，整个排行榜打不开。
   - 复现路径：10-18 处置的那批号只删了 `user` 文档，`uid:heroId` 复合成员留在 `10001:HERO_FORCE_RANK:` 里；10-20 把作弊号的成员清掉后，榜一正好落到幽灵号 `10000194` 头上，立刻 NPE（`HeroForceRank.java:69`）。
   - 只有**英雄战力榜**会崩：`AbstractRank.getOneUserRank()` 对 `everyUser == null` 有判空，其它榜返回空行不抛错。
   - 代码侧已加判空（`getFirst` 会顺延到下一个有效成员、`getOptional` 跳过失效行、`getMyInfo` 判 `zSetScore` 空），但**未发版前线上仍是旧逻辑**，数据层必须自己清干净。
4. **`--account` 删号必须先清榜再删号**：早期 `run()` 在 `delete_account=True` 分支里根本不调 `clean_ranks()`，导致复合成员永久残留 —— 这是幽灵榜一的唯一来源。现已改成「clean_ranks → clean_mongo_refs → delete_account」。
5. **删号 ≠ 封号**：本服「查不到 user 就自动建档」，删号只是重置。必须写 `FORBID_LOGIN`。


## 5. 生效条件

- 英雄/物品数据在 Mongo，**玩家离线时下次登录即生效**；在线则必须踢下线或重启（会覆盖内存态）。
- `FORBID_LOGIN` 由 `MinuteTask` 每分钟重载，1 分钟内生效，重启不丢。
- `RANKING_DATA`（`RankingRewardLogic.rankingDataMap`）与 `guildInfo`（`GuilidManager`）是启动加载 ⇒ 改完**必须重启**才对内存里的排行奖励逻辑生效。
- 校验口径：`purge` 结束自动打印「英雄数 / ≥100 级数 / heroForceSort / 榜残留 / 封禁 / 全榜失效成员」，全服复扫用 `hunt`（应为空）。
- **排行榜打不开先跑 `rank-audit`**：`python3 scripts/cheatctl.py rank-audit`（应为 0 条失效）；有则 `--repair`。日志特征：`protoID=11756` + `HeroForceRank.getFirst(HeroForceRank.java:69)` NPE。

## 6. 定位「漏洞在哪」的固定套路

1. `grep -B3 "In a formal setting" /data/srvlog/gameserver.log` → 抓到正在打 `GM_REQUEST` 的 uid；
2. `GMRequestHandler.getMessageCode()` 绑的是公网协议 `GM_REQUEST`(10606)，唯一闸门 `ServerProperties.isDebug()`；
3. 查 `config/application.properties` 与 **jar 内置** `application*.properties`（profile 11/12），必须用运行时日志 `ServerProperties ->` 验证，不能只 grep 文件；
4. 指令编号查 `globals/GlobalGm.java`：`HERO_STAR=4`（`4#heroId#star`）、`ONE_KEY_ITEM_OR_HERO`、`FULL_OF`、`GM_LOGIN_BY_UID=40`（可顶号）。
