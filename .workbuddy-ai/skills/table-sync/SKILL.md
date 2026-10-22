---
name: table-sync
description: 把导表产出的服务端 txt 增量同步到线上服（gs:/home/java/gameserver/conf/server），并做结构体检（列丢失/行丢失/表头错位/nil 空值）。当需求是「客户端表格和线上服没同步」「导表后服务端没生效」「线上配置表和 xlsx 对不上」「推表到线上」「服务端表漂移」时使用。关键词：导表同步、table_sync、服务端表、conf/server、线上配置、表漂移、整目录覆盖、nil、null、ROW_LOSS、COL_LOSS、Language Korean、EncourageTaskConfig、resource_build --sync-tables。
agent_created: true
---

# 导表服务端同步（table_sync）

**正文在 `docs/table_sync_skill.md`，先读它**（为什么不能整目录覆盖、基线指纹算法、判定规则表、六个坑位、31 张漂移实测数据都在里面）。

先记住一句：**导表只写本地影子目录 `TimeSpaceServer/skzc/.../conf/server`，线上 `gs:/home/java/gameserver/conf/server` 从来没人推** —— 这就是「客户端显示 0、服务端还能领」的根因。

流水线：**①`--plan` 体检 → ②看判定 → ③`--only` 挑表 / 默认增量 → ④`--apply` → ⑤重启才生效**。别跳第 1 步。

执行口：

- `scripts/table_sync.py` — 唯一的实现。默认只体检；`--apply` 才写线上
- `scripts/resource_build.sh --action export` — 导表后自动调用（`--sync-tables plan|off` 可调）

四条不能忘的：

1. **绝不整目录 rsync**：`Language` 会丢 Korean 列、`EncourageTaskConfig` 会删线上 25 条任务、
   30+ 张是未发布内容。
2. **数值列里的 `nil` 会让服务端 `Integer.parseInt("nil")` 抛异常、整表加载失败**。
   2026-10-21 前的导出产物全是 `nil`（实测 54 张表命中）→ 重跑导表或加 `--fix-nil`。
3. **推完必须重启**（`--restart`），`STableManager` 只在启动时 `initMap`。
4. `conf/server` 和 `assets/conf/server` 是两份独立文件，工具默认两份都推、两份都校验。
