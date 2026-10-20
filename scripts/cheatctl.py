#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""cheatctl 薄封装：`python3 scripts/cheatctl.py <scan|hunt|purge|ban|unban|banlist> ...`

真正的实现在 `scripts/cheat/`（remote / detect / purge 三层）。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cheat.cli import main  # noqa: E402

if __name__ == '__main__':
    sys.exit(main())
