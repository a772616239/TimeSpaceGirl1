# scripts/cheat —— 作弊排查 / 处置工具箱

```
cheat/
  remote.py   远端执行层（SSH → mongo / redis-cli），唯一的 IO 出口
  currency.py 道具 id ↔ 名称（**唯一权威来源 = 服务端 conf 的 ItemConfig+Language**）
  detect.py   取证与判定（hard / soft / info 三级判据）
  purge.py    处置（归档 → 删产物 → 清榜 → 封号 → 校验 → manifest）
  cli.py      argparse 入口
  audit_snapshot_currency.py  只读：从 /root/incident_* 快照重算货币
  audit_bi_currency.py        只读：按 uid×reason 汇总 30 天 jl_item 流水
  audit_adventure_density.py  只读：reason=1 的按天笔数 + 60s 突发密度
  reports/    每次处置的 manifest（含回滚命令），git 忽略
```

入口：`python3 scripts/cheatctl.py <scan|hunt|archive|purge|rank-audit|refs-audit|ban|unban|banlist>`

## 🔴 货币 id 铁律（2026-10-18 误封的根因）

| id | 名称 | 备注 |
|---|---|---|
| **16** | **钻石** | 唯一真货币 |
| **3** | **英雄经验** | ❌ 曾被写死成钻石 |
| **14** | **金钱** | |
| **17** | **经验** | ⚠️ 语义未定（22/209 个号该值≈0），**不能当货币基线** |
| 79 | 情报 | 挂机产出 |

**任何脚本都不许再写死 id→名字**：`currency.load_names()` 每次从 `conf/server/`
现算（本地优先，其次远端），字段常量取 `currency.DIAMOND/GOLD/HERO_EXP/PLAYER_EXP`。
`reason=1`（挂机/探险）**永不产出 item16**；钻石只来自 `reason=2` / 邮件 / GM(`reason=28`)。


## scan —— 判一个号（只读）

```bash
python3 scripts/cheatctl.py scan --uid 10000224
python3 scripts/cheatctl.py scan --uid 10000224 --json > /tmp/rep.json
python3 scripts/cheatctl.py scan --uid 10000224 --fast   # 跳过 BI 流水，快但会漏 itemLog 断档的情况
```

退出码：`0` CLEAN / `1` SUSPECT / `2` CHEAT / `4` 远端错误。

判据（阈值在 `detect.TH`）：

| 级别 | code | 含义 |
|---|---|---|
| hard | `bi_gm_reward` | BI 流水 `assets/log/jl_item/<date>/item0.log` 出现 `reason=28`（GM_REWARD） |
| hard | `gm_reward_db` | Mongo `itemLog` 有 `reason=28` |
| hard | `hero_peer_outlier` | 最高英雄等级 > 同级(±5) P99 × 3 |
| hard | `hero_burst` | 120s 内 ≥8 个异常英雄（≥100 级或 ≥10 星） |
| soft | `hero_progress_skew` / `gm_request_burst` / `gold_outlier` | 需两条以上才 SUSPECT |
| info | `diamond_outlier` | 钻石(item16) > 活跃号 P99 —— **只作线索**；请先查 `reason=28`/邮件，别直接定罪 |

## hunt —— 全服找候选（只读）

```bash
python3 scripts/cheatctl.py hunt            # 列出 maxLv 异常/≥100 级英雄的账号
python3 scripts/cheatctl.py hunt --json
```

只做英雄维度粗筛，**候选必须再过一遍 `scan`**（满配大佬也会进候选）。

## archive —— 只归档不删（删号前必跑）

```bash
python3 scripts/cheatctl.py archive --uid 10000016
```

导出 `user` + **`itemLog`/`heroLog`/`fightLog`/`storeLog` 四个集合** + 命中榜单快照 +
**货币余额快照**（item3/4/7/8/14/16/17/19/20/79）到 `/root/incident_<tag>_<uid>/`，
本地 `reports/<uid>_<tag>.json` 记每份文件的条数与回滚命令。

> 为什么必须：`10000015`/`10000016` 当初只导了 user、没导日志，事后连"他当时有多少钻石"
> 都答不出来，永久失去判据。现在 `purge --account` 把「四个集合都导出成功」当硬闸门，
> **任一失败直接中止删号**。

## purge —— 一键处置（默认 dry-run）

```bash
python3 scripts/cheatctl.py purge --uid 10000224                     # 只看计划
python3 scripts/cheatctl.py purge --uid 10000224 --apply             # 执行
python3 scripts/cheatctl.py purge --uid 10000224 --apply --ban       # 顺带封号
python3 scripts/cheatctl.py purge --uid 10000224 --apply --hero-level 100 --hero-star 10
python3 scripts/cheatctl.py purge --uid 10000224 --no-heroes --apply # 只清榜
python3 scripts/cheatctl.py purge --uid 10000224 --account --confirm 10000224 --apply  # 删整号
```

执行内容（顺序不可换）：

1. 归档 `user` 文档 + `itemLog/heroLog/fightLog/storeLog` 四个集合 + 命中榜单快照 + 货币快照
   → `/root/incident_<tag>_<uid>/`（日志未导出成功 ⇒ 中止，见上）
2. 清榜：`ZREM`（含 `uid:heroId` 复合成员）、`RANKING_DATA` JSON 剔除、`supremacyInfo`、`guildInfo`
   —— **`--account` 删号路径也一定先走这一步**（早期版本漏了，直接导致幽灵榜一）
3. `$unset` 英雄 + `heroForceSort` 置空 + 清 `heroStarMap`/`heroHandBook`
4. 可选封号 `HSET "10001:FORBID_LOGIN:" <uid> 0`
5. 全榜体检（`RankIntegrity`，见下）+ 校验 + 写 `reports/<uid>_<tag>.json`（含回滚命令）

## rank-audit —— 全榜完整性体检

**排行榜打不开时先跑这个。** 客户端「第一名」请求 `RankFirstHandler`(11756) 会遍历所有榜，
而 `HeroForceRank.getFirst()` 取到榜一后直接解引用英雄实体，**没有判空** ⇒
只要有一个榜的第 1 名指向「账号已删」或「英雄已删」的成员，就抛 NPE，
整个排行榜面板打不开（日志特征 `HeroForceRank.getFirst(HeroForceRank.java:69)`）。

```bash
python3 scripts/cheatctl.py rank-audit            # 只报清单（默认）
python3 scripts/cheatctl.py rank-audit --repair   # 执行清理
python3 scripts/cheatctl.py rank-audit --json
```

判定口径：

| 类型 | 含意 | 典型来源 |
|---|---|---|
| `user_gone` | 成员 uid 在 `user` 集合里不存在 | `purge --account` 删号后没清榜 |
| `hero_gone` | uid 存在，但 `heroMap` 里没这个 heroId | 删作弊英雄后榜单/`heroForceSort` 残留 |

只有匹配 `^1\d{7}$` 的成员才按 uid 处理；**公会榜的 `3`/`4` 这类 guildId 不会被误删**。
`purge` 结束时自动跑一次（`--no-rank-integrity` 可关）。

## 安全约束

- `purge` 默认 dry-run；`--account` 必须 `--confirm <uid>`。
- 只删该 uid 的成员，**绝不清整榜**。
- 删英雄必须同步 `heroForceSort`，否则 `HeroForceRank.getMyInfo`/`getOptional` 会取空甚至 NPE。
- 删号 / 删英雄之后**必须** `rank-audit`，否则幽灵成员会让全服排行榜崩掉。
- 改 `RANKING_DATA` / `guildInfo` 后，`RankingRewardLogic` 与 `GuilidManager` 是启动加载 ⇒ **需重启**。

