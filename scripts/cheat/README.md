# scripts/cheat —— 作弊排查 / 处置工具箱

```
cheat/
  remote.py   远端执行层（SSH → mongo / redis-cli），唯一的 IO 出口
  detect.py   取证与判定（hard / soft / info 三级判据）
  purge.py    处置（备份 → 删产物 → 清榜 → 封号 → 校验 → manifest）
  cli.py      argparse 入口
  reports/    每次处置的 manifest（含回滚命令），git 忽略
```

入口：`python3 scripts/cheatctl.py <scan|hunt|purge|ban|unban|banlist>`

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

## hunt —— 全服找候选（只读）

```bash
python3 scripts/cheatctl.py hunt            # 列出 maxLv 异常/≥100 级英雄的账号
python3 scripts/cheatctl.py hunt --json
```

只做英雄维度粗筛，**候选必须再过一遍 `scan`**（满配大佬也会进候选）。

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

1. 备份 `user` 文档 + 命中榜单快照 → `/root/incident_<tag>_<uid>/`
2. `$unset` 英雄 + `heroForceSort` 置空 + 清 `heroStarMap`/`heroHandBook`
3. 清榜：`ZREM`（含 `uid:heroId` 复合成员）、`RANKING_DATA` JSON 剔除、`supremacyInfo`、`guildInfo`
4. 可选封号 `HSET "10001:FORBID_LOGIN:" <uid> 0`
5. 校验 + 写 `reports/<uid>_<tag>.json`（含回滚命令）

## 安全约束

- `purge` 默认 dry-run；`--account` 必须 `--confirm <uid>`。
- 只删该 uid 的成员，**绝不清整榜**。
- 删英雄必须同步 `heroForceSort`，否则 `HeroForceRank.getMyInfo`/`getOptional` 会取空甚至 NPE。
- 改 `RANKING_DATA` / `guildInfo` 后，`RankingRewardLogic` 与 `GuilidManager` 是启动加载 ⇒ **需重启**。
