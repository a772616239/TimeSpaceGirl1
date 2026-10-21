#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""notify_package.py —— 测试包结果邮件（正文里给版本号与下载地址）。

为什么单独一个文件，而不是直接 `notify.py release`
--------------------------------------------------
共享库的 `notify.py release` 是给**发版**写的：主题固定「发版完成」、事实行固定
「轨道/状态/包」。夜间测试包既不是发版、也没有轨道，硬套会让邮件第一行就在说谎
（「发版完成」但根本没上传 Play）。而 `notify.py mail` 又只收一段死正文，
每次改措辞都要动 job。所以这里只做**组装**，投递仍然复用 `notify.py` 的
`send()`（多候选授权码 / 465→587 换端口 / 失败分类重试，一份实现不许有第二份）。

事实从哪来（全部读本次取证目录，不猜）
-------------------------------------
  <run>/apk.artifact.txt   stage_apk.sh 写的 KEY=VALUE：APK_NAME / SIZE_H / MD5 /
                           APK_ARTIFACT_URL / APK_STABLE_URL
  <run>/version.txt        bump_version.py 的输出版本行（bump 后那行）
  <run>/stages/*.json      每个环节的结论（失败/警告的原文）
  <run>/context.txt        工程 @ commit
读不到就留空，绝不因为「取证不全」而让发信失败 —— 半夜三点最需要的是
「失败了」这三个字，而不是一份格式完美的空白。

用法
----
    notify_package.py --run-dir <取证目录> --job TS-Android-TestPackage \
        --build 12 --url http://127.0.0.1:8080/job/x/12/ \
        --result SUCCESS --env 现网-129.226.213.65 --trigger 定时 \
        [--to a@b.com] [--note "附加一句"] [--dry-run] [--json]

退出码：0 成功（含 dry-run）；2 参数/环境错误；4 投递失败
（与 notify.py 对齐，job 里用 `--warn-rc 4` 兜住：发信抖一下不该把已经出好的包判红）
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import unicodedata
from datetime import datetime

DEFAULT_SHARED = '/Users/wangxufeng/Documents/jenkins-shared'

STATUS_ICON = {'pass': '✅', 'fail': '🔴', 'warn': '⚠️', 'skip': '⏭️'}
RESULT_ICON = {'SUCCESS': '✅', 'UNSTABLE': '⚠️', 'FAILURE': '🔴', 'ABORTED': '⏹️'}


# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------
def dwidth(s: str) -> int:
    """显示宽度：中日韩全角算 2，其余算 1（对齐用，别用 len）。"""
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in s)


def kv(label: str, value: str, width: int = 10) -> str:
    return '%s: %s' % (label + ' ' * max(0, width - dwidth(label)), value)


def read(path: str) -> str:
    try:
        return open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return ''


def norm_url(u: str) -> str:
    """`http://h:8080//job/x` → `http://h:8080/job/x`（stage_apk 早期版本会拼出双斜杠）。"""
    if not u:
        return ''
    m = re.match(r'^([a-zA-Z][\w+.-]*://)(.*)$', u)
    if not m:
        return u
    return m.group(1) + re.sub(r'/{2,}', '/', m.group(2))


# ---------------------------------------------------------------------------
# 取证目录 → 事实
# ---------------------------------------------------------------------------
def parse_artifact_txt(run_dir: str) -> dict:
    out = {}
    for line in read(os.path.join(run_dir, 'apk.artifact.txt')).splitlines():
        if '=' not in line or line.lstrip().startswith('#'):
            continue
        k, v = line.split('=', 1)
        k = k.strip()
        # 文件后半段是给人看的说明行（「本次下载（…）：http://…」），没有合法 KEY 形态，跳过
        if re.fullmatch(r'[A-Z][A-Z0-9_]*', k):
            out[k] = v.strip()
    return out


def parse_version(run_dir: str, apk_name: str) -> str:
    """优先 version.txt 的 bump 后那行，其次从 APK 文件名 `1.2.51_vc79_104147.apk` 里取。"""
    lines = [l for l in read(os.path.join(run_dir, 'version.txt')).splitlines() if l.strip()]
    for line in reversed(lines):
        m_name = re.search(r'versionName[^=]*=\s*([0-9A-Za-z._-]+)', line)
        if m_name:
            m_code = re.search(r'versionCode[^=]*=\s*(\d+)', line)
            return '%s (%s)' % (m_name.group(1), m_code.group(1)) if m_code else m_name.group(1)
    m = re.match(r'^(.+?)_vc(\d+)_', apk_name or '')
    if m:
        return '%s (%s)' % (m.group(1), m.group(2))
    return ''


def parse_commit(run_dir: str) -> tuple[str, str]:
    """返回 (短 sha, 提交标题)。标题取自打包目录的 git log；取不到就只给 sha。"""
    sha = ''
    ctx = read(os.path.join(run_dir, 'context.txt'))
    m = re.search(r'@\s*([0-9a-f]{7,40})\b', ctx)
    if m:
        sha = m.group(1)[:7]
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(run_dir))))
    subject = ''
    try:
        r = subprocess.run(['git', '-C', root, 'log', '-1', '--format=%s'],
                           capture_output=True, text=True, timeout=5)
        if r.returncode == 0:
            subject = r.stdout.strip().splitlines()[0] if r.stdout.strip() else ''
            if dwidth(subject) > 60:                          # 邮件主题行别被一条长 commit 撑爆
                subject = subject[:28] + '…'
    except Exception:                                         # noqa: BLE001
        pass
    return sha, subject


def parse_stages(run_dir: str) -> list[dict]:
    out = []
    for f in sorted(glob.glob(os.path.join(run_dir, 'stages', '*.json'))):
        try:
            d = json.load(open(f, encoding='utf-8'))
        except Exception:                                     # noqa: BLE001
            continue
        out.append({'name': d.get('name', '?'), 'group': d.get('group', ''),
                    'status': d.get('status', '?'), 'detail': (d.get('detail') or '').strip()})
    return out


# ---------------------------------------------------------------------------
# 组装邮件
# ---------------------------------------------------------------------------
def build(args) -> tuple[str, str]:
    art = parse_artifact_txt(args.run_dir)
    apk = art.get('APK_NAME', '')
    version = parse_version(args.run_dir, apk)
    sha, subject_git = parse_commit(args.run_dir)
    stages = parse_stages(args.run_dir)

    result = (args.result or 'SUCCESS').upper()
    icon = RESULT_ICON.get(result, '·')
    nightly = (args.trigger == '定时')
    tag = '夜间测试包' if nightly else '测试包'

    # ---- 主题：第一眼要能判断「有没有包 / 什么版本 / 连哪个服」------------------
    head = '%s【%s】%s #%s' % (icon, tag, args.job, args.build or '?')
    if result == 'SUCCESS':
        bits = [b for b in (version, args.env) if b]
        if bits:
            head += ' · ' + ' · '.join(bits)
    else:
        head += ' · 出包未完成（无可用包）'
        if args.env:
            head += ' · ' + args.env

    # ---- 正文 ----------------------------------------------------------------
    L: list[str] = []
    L.append('%s %s #%s' % (icon, args.job, args.build or '?'))
    L.append('')
    L.append(kv('结果', result))
    L.append(kv('时间', datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %z')))
    if args.trigger:
        L.append(kv('触发', '%s（每天 03:00；手动触发走同一条链）' % args.trigger if nightly
                    else args.trigger))
    if version:
        L.append(kv('版本', version))
    if args.env:
        L.append(kv('连服', args.env))
    if sha:
        L.append(kv('代码', ('%s @ %s' % (args.branch, sha) if args.branch else sha)
                    + ((' · ' + subject_git) if subject_git else '')))
    if apk:
        size = art.get('APK_SIZE_H', '')
        md5 = art.get('APK_MD5', '')[:8]
        L.append(kv('包', ' · '.join([x for x in (apk, size, ('md5 ' + md5) if md5 else '') if x])))

    stable = norm_url(art.get('APK_STABLE_URL', ''))
    one = norm_url(art.get('APK_ARTIFACT_URL', ''))
    if one:
        L.append(kv('下载', one))
    if stable:
        L.append(kv('稳定地址', stable + '（永远指向最近一次成功的包，可收藏）'))
    if args.url:
        L.append(kv('构建页', norm_url(args.url)))
    if art.get('APK_PATH'):
        L.append(kv('本机路径', art['APK_PATH']))

    # ---- 环节：只把「不是全绿」的部分展开，全绿就一行 ------------------------
    if stages:
        ok = sum(1 for s in stages if s['status'] == 'pass')
        L.append('')
        if ok == len(stages):
            L.append('环节（%d 个）: 全部通过' % len(stages))
        else:
            L.append('环节（%d 个，通过 %d，有问题 %d）:'
                     % (len(stages), ok, len(stages) - ok))
            for s in stages:
                if s['status'] == 'pass':
                    continue
                line = '  %s %s' % (STATUS_ICON.get(s['status'], '·'), s['name'])
                if s['detail']:
                    line += '  — ' + s['detail'][:160]
                L.append(line)

    if not apk:
        L.append('')
        # 「没包」有两种：环节判红（有线索）与环节全绿却没登记产物（多半是被中断/超时，
        # 或者 ⑤ 没跑到）。这两种要说不同的话，否则「没有可用包」下面接一句「全部通过」
        # 会让人以为邮件发错了。
        bad = [s for s in stages if s['status'] not in ('pass', 'skip')]
        if bad:
            L.append('本次没有产出可用 APK —— 上面的失败环节就是原因，'
                     '点构建页看对应环节的日志（logs/ 下同名文件）。')
        else:
            L.append('本次没有产出可用 APK，且没有环节判红 —— 多半是构建被中断/超时，'
                     '或「APK 收成构建产物」那一步没跑到。点构建页看最后几行日志。')

    if args.note:
        L.append('')
        L.append(args.note)

    L.append('')
    if apk:
        L.append('侧载：adb install -r "<上面的包>"。手机若已装 Play 版必须先卸载 —— '
                 '本包用 upload key 签名，与 Play 的 app signing key 不同。')
    L.append('-' * 46)
    L.append('本邮件由 .jenkins/lib/notify_package.py 自动发送（测试包出完即发，不含任何上传 Play 动作）。')
    return head, '\n'.join(L)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description='测试包结果邮件（复用共享库 notify.py 投递）')
    ap.add_argument('--run-dir', required=True)
    ap.add_argument('--job', required=True)
    ap.add_argument('--build', default='')
    ap.add_argument('--url', default='')
    ap.add_argument('--result', default='SUCCESS')
    ap.add_argument('--env', default='')
    ap.add_argument('--trigger', default='')
    ap.add_argument('--branch', default='')
    ap.add_argument('--to', action='append', default=[])
    ap.add_argument('--note', default='')
    ap.add_argument('--shared', default=os.environ.get('SHARED', DEFAULT_SHARED))
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--json', action='store_true')
    args = ap.parse_args(argv)

    if not os.path.isdir(args.run_dir):
        print('[ERROR] 取证目录不存在：%s' % args.run_dir, file=sys.stderr)
        return 2

    subject, body = build(args)

    if args.dry_run:
        print('=== DRY-RUN 邮件 ===')
        print('To      : %s' % (', '.join(args.to) if args.to else '（notify.py 默认收件人）'))
        print('Subject : %s' % subject)
        print('-' * 46)
        print(body)
        if args.json:
            print(json.dumps({'dry_run': True, 'subject': subject}, ensure_ascii=False))
        return 0

    sys.path.insert(0, os.path.join(args.shared, 'lib'))
    try:
        from notify import send                                  # noqa: PLC0415
    except Exception as e:                                       # noqa: BLE001
        print('[ERROR] 载入共享发信器失败（%s/lib/notify.py）：%s' % (args.shared, e),
              file=sys.stderr)
        return 2

    ok, msg = send(subject, body, [t for t in args.to if t] or None)
    print(('[OK] ' if ok else '[FAIL] ') + msg)
    if args.json:
        print(json.dumps({'ok': ok, 'message': msg, 'subject': subject}, ensure_ascii=False))
    return 0 if ok else 4


if __name__ == '__main__':
    sys.exit(main())
