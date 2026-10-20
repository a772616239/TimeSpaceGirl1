#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""配置表备份目录的统一出口（工程外）。

为什么不在工程内：
  `data_execl/base_data/` 是导表工具的输入目录。往里面放 `_backup_*/xxx.xlsx`
  会有两个风险：
    1) 导表工具若递归扫描 *.xlsx，会把备份当成同名表重复导出（表名冲突）；
    2) 备份目录会随工程一起被打包/上传。
  所以备份一律落到工程外的 `~/Documents/TimeSpaceGirl1-config-bak/`。

可用环境变量 TSG_CONFIG_BACKUP_ROOT 覆盖（例如放到外置盘）。
"""

import os

_DEFAULT_ROOT = os.path.join(os.path.expanduser("~"), "Documents", "TimeSpaceGirl1-config-bak")


def root() -> str:
    """备份根目录（工程外）。"""
    return os.path.abspath(os.environ.get("TSG_CONFIG_BACKUP_ROOT") or _DEFAULT_ROOT)


def sub(name: str) -> str:
    """某类改动的备份子目录，例如 _backup_before_monetize。"""
    return os.path.join(root(), name)


def ensure(name: str) -> str:
    """取子目录并确保存在。"""
    p = sub(name)
    os.makedirs(p, exist_ok=True)
    return p
