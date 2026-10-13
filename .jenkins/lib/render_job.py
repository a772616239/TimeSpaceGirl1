#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把一个 job 定义文件渲染成 Jenkins 的 config.xml。

job 定义文件（`.jenkins/jobs/<job名>.groovy`）是**单一真源**，格式：

    /**@META
    {
      "description": "这个 job 干什么",
      "cron": "H 3 * * *",              // 可选，定时触发器
      "concurrent": false,               // 可选，false = 禁止并发构建（默认 true）
      "disabled": false,                 // 可选，默认 false
      "keep": [30, 40],                  // 可选，[保留天数, 保留个数]
      "params": [
        {"name":"X","type":"choice","choices":["a","b"],"default":"a","description":"..."},
        {"name":"Y","type":"bool","default":false,"description":"..."},
        {"name":"Z","type":"string","default":"","description":"..."},
        {"name":"W","type":"text","default":"","description":"..."}
      ]
    }
    META*/
    pipeline { ... }        ← 以下是纯 Groovy Pipeline 脚本

这样写的原因：job 的名字、参数、触发器、脚本全在一个文件里，改一处就行；
`apply-jobs.sh` 读这个头生成 XML 并推给 Jenkins，**不需要重启 Jenkins**。

用法：render_job.py <定义文件> > <config.xml>
退出码：0 成功；2 元数据缺失/格式错。
"""
from __future__ import annotations

import json
import os
import re
import sys
import xml.sax.saxutils as sax

META_RE = re.compile(r"/\*\*@META\s*(?P<meta>.*?)\s*META\*/", re.S)


def esc(t) -> str:
    return sax.escape("" if t is None else str(t))


def param_xml(p: dict) -> str:
    t = (p.get("type") or "string").lower()
    name = esc(p.get("name"))
    desc = esc(p.get("description", ""))
    if t == "choice":
        choices = p.get("choices") or []
        items = "".join("      <string>%s</string>\n" % esc(c) for c in choices)
        return (
            "        <hudson.model.ChoiceParameterDefinition>\n"
            "          <name>%s</name>\n"
            "          <description>%s</description>\n"
            '          <choices class="java.util.Arrays$ArrayList">\n'
            '            <a class="string-array">\n%s'
            "            </a>\n"
            "          </choices>\n"
            "        </hudson.model.ChoiceParameterDefinition>\n" % (name, desc, items))
    if t == "bool":
        return (
            "        <hudson.model.BooleanParameterDefinition>\n"
            "          <name>%s</name>\n"
            "          <description>%s</description>\n"
            "          <defaultValue>%s</defaultValue>\n"
            "        </hudson.model.BooleanParameterDefinition>\n"
            % (name, desc, "true" if p.get("default") else "false"))
    if t == "text":
        return (
            "        <hudson.model.TextParameterDefinition>\n"
            "          <name>%s</name>\n"
            "          <description>%s</description>\n"
            "          <defaultValue>%s</defaultValue>\n"
            "        </hudson.model.TextParameterDefinition>\n"
            % (name, desc, esc(p.get("default", ""))))
    return (
        "        <hudson.model.StringParameterDefinition>\n"
        "          <name>%s</name>\n"
        "          <description>%s</description>\n"
        "          <defaultValue>%s</defaultValue>\n"
        "          <trim>false</trim>\n"
        "        </hudson.model.StringParameterDefinition>\n"
        % (name, desc, esc(p.get("default", ""))))


def render(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        raw = fh.read()

    m = META_RE.search(raw)
    if not m:
        raise SystemExit("定义文件缺少 /**@META ... META*/ 元数据头：%s" % path)
    try:
        meta = json.loads(m.group("meta"))
    except json.JSONDecodeError as e:
        raise SystemExit("META 头不是合法 JSON（%s）：\n%s" % (path, e))

    script = (raw[:m.start()] + raw[m.end():]).strip()
    if "pipeline {" not in script:
        raise SystemExit("定义文件里找不到 `pipeline {`：%s" % path)

    props = []
    if not meta.get("concurrent", True):
        props.append("    <hudson.model.DisableConcurrentBuildsJobProperty/>\n")

    keep = meta.get("keep")
    if keep:
        days, num = (list(keep) + [None, None])[:2]
        props.append(
            "    <jenkins.model.BuildDiscarderProperty>\n"
            '      <strategy class="hudson.tasks.LogRotator">\n'
            "        <daysToKeep>%s</daysToKeep>\n"
            "        <numToKeep>%s</numToKeep>\n"
            "        <artifactDaysToKeep>-1</artifactDaysToKeep>\n"
            "        <artifactNumToKeep>-1</artifactNumToKeep>\n"
            "      </strategy>\n"
            "    </jenkins.model.BuildDiscarderProperty>\n" % (days, num))

    params = meta.get("params") or []
    if params:
        props.append(
            "    <hudson.model.ParametersDefinitionProperty>\n"
            "      <parameterDefinitions>\n%s"
            "      </parameterDefinitions>\n"
            "    </hudson.model.ParametersDefinitionProperty>\n"
            % "".join(param_xml(p) for p in params))

    if meta.get("cron"):
        props.append(
            "    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>\n"
            "      <triggers>\n"
            "        <hudson.triggers.TimerTrigger>\n"
            "          <spec>%s</spec>\n"
            "        </hudson.triggers.TimerTrigger>\n"
            "      </triggers>\n"
            "    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>\n"
            % esc(meta["cron"]))

    return (
        "<?xml version='1.1' encoding='UTF-8'?>\n"
        '<flow-definition plugin="workflow-job">\n'
        "  <description>%s</description>\n"
        "  <keepDependencies>false</keepDependencies>\n"
        "  <properties>\n%s  </properties>\n"
        '  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">\n'
        "    <script>%s</script>\n"
        # 🔴 必须是 true（Groovy 沙箱）。
        #    写 false = 「信任脚本、不沙箱」，Jenkins 会要求管理员在
        #    「In-process Script Approval」里**逐份批准脚本内容**
        #    （workflow-cps 的 CpsFlowDefinition.create 会调 ScriptApproval.using），
        #    而批准对象是脚本文本的哈希 ⇒ **仓库里改一个字，approval 立即失效、job 直接
        #    UnapprovedUsageException 失败**。那等于把「改 job 不用点界面」这个设计目标废掉。
        #    实测（2026-10-12）：sandbox=false 时首个构建 21 秒即 FAILURE，
        #    控制台第一行就是 UnapprovedUsageException: script not yet approved for use。
        #    沙箱下 job 里只用标准 DSL + env/currentBuild 这类已白名单的访问，够用；
        #    真撞上需要提权的调用时，script-security 会把它挂到 Script Approval 页面上，
        #    那时才需要人介入（且是「单个方法」而非「整份脚本」）。
        "    <sandbox>true</sandbox>\n"
        "  </definition>\n"
        "  <triggers/>\n"
        "  <disabled>%s</disabled>\n"
        "</flow-definition>\n"
        % (esc(meta.get("description", "")), "".join(props), esc(script),
           "true" if meta.get("disabled") else "false"))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.stdout.write(render(sys.argv[1]))
