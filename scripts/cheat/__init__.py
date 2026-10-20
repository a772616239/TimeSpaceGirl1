#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""作弊排查 / 处置工具箱（cheat ops toolkit）。

模块划分：
  remote.py  —— 远端执行层（SSH → mongo / redis-cli），唯一的 IO 出口
  detect.py  —— 取证与判定（硬信号 / 软信号 → CHEAT / SUSPECT / CLEAN）
  purge.py   —— 处置（备份 → 删英雄 / 清榜 / 封号 / 删号 → 校验 → 回滚清单）
  cli.py     —— 命令行入口

设计约束（改代码前先读）：
  1. **只读优先**：detect 全程只读；purge 默认 dry-run，必须显式 `--apply`。
  2. **先备份后动手**：purge 任何写操作之前必然生成 `/root/incident_<日期>/` 备份 +
     本地 manifest，回滚命令随报告一起打印。
  3. **不猜字段**：所有集合/字段都来自实测样例（见 docs/cheat_detection_skill.md）。
"""

__all__ = ['remote', 'detect', 'purge']
__version__ = '1.0.0'
