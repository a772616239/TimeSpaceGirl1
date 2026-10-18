#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""转发到共享实现 —— 本文件只是为了让 job 里既有的 .jenkins/lib/find_artifact.py 路径继续有效。

真正的代码在：/Users/wangxufeng/Documents/jenkins-shared/lib/find_artifact.py
改逻辑请改共享库；这里不做任何加工。
"""
import runpy
import sys

TARGET = "/Users/wangxufeng/Documents/jenkins-shared/lib/find_artifact.py"
sys.argv[0] = TARGET
runpy.run_path(TARGET, run_name="__main__")
