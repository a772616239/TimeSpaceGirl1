---
name: table-sync
description: 把导表产出的服务端 txt 增量同步到本机测试服（~/home/java/gameserver）和线上服（gs:/home/java/gameserver），并做结构体检（列丢失/行丢失/表头错位/nil 空值）。当需求是「客户端表格和线上服没同步」「测试服和线上服表不一致」「导表后服务端没生效」「线上配置表和 xlsx 对不上」「推表到线上」时使用。关键词：导表同步、table_sync、服务端表、conf/server、assets/conf/server、线上配置、测试服配置、表漂移、整目录覆盖、nil、null、ROW_LOSS、COL_LOSS、Language Korean、EncourageTaskConfig、resource_build --sync-tables。
agent_created: true
---

# 导表服务端同步（table_sync）

**正文在 `docs/table_sync_skill.md`，先读它**（为什么不能整目录覆盖、基线指纹算法、判定规则表、七个坑位、双目标实测数据都在里面）。

先记住两句：

1. **导表只写本地影子目录 `TimeSpaceServer/skzc/.../conf/server`**，而服务端读的是另外两处 ——
   `~/home/java/gameserver`（本机测试服）和 `gs:/home/java/gameserver`（线上服）。三条链互不相通。
2. **两个目标都要推，只推一边等于没改**：测试服旧表 → 自测过的东西上线不成立；线上旧表 → 客户端显示与服务端校验继续对不上。

流水线：**①`--plan` 体检 → ②看逐表判定 → ③`--only` 挑表 / 默认增量 → ④`--apply` → ⑤重启才生效**。别跳第 1 步。

执行口：

- `scripts/table_sync.py` — 唯一的实现。默认只体检；`--apply` 才写；`--targets local,gs` 选目标
- `scripts/resource_build.sh --action export` — 导表后自动调用（`--sync-tables plan|off` 可调）

四条不能忘的：

1. **绝不整目录 rsync**：`Language` 会丢 Korean 列、`EncourageTaskConfig` 会删线上 25 条任务、
   30+ 张是未发布内容。
2. **数值列里的 `nil` 会让服务端 `Integer.parseInt("nil")` 抛异常、整表加载失败**。
   2026-10-21 前的导出产物全是 `nil`（实测 54 张表命中）→ 重跑导表或加 `--fix-nil`。
3. **推完必须重启**：本机 `launchctl kickstart -k gui/<uid>/com.ts.localserver.gameserver`，
   线上 `RESTART-GAMESERVER.sh`（会踢线）。
4. `conf/server` 和 `assets/conf/server` 是两份独立文件，工具默认两份都推、两份都校验。
