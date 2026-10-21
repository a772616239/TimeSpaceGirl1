# CV 全量英文配音流水线（CV_En_Full）

把工程内**带语言的人声音效**（角色 CV、战斗语音）整套翻成英文并合成新音频。
与之前手工试听的 `CV_Translation_Test` / `CV_Natural_Speed` 相比，这套是全自动、可重跑、可局部返工的版本。

## 一句话流程

```
原中文音频 ──(faster-whisper 中文识别)──> 中文台词
      │                                      │
      └─(YIN 基频)──> 音区/性别 ──┐          ├─(人工校正 + 翻译)─> 英文台词
                                  ├──> 音色分配 ─┘
                                  ▼
              英文台词 ──(edge-tts 神经音色)──> 英文音频
                              │
                              └─(静音裁剪 + rate/atempo 对齐)──> 与原时长一致的 48k/立体声/192k mp3
```

## 目录

| 文件 | 作用 |
|---|---|
| `audio_inventory.json` | 全量音频清单（路径/时长），含 CV/Battle/UI |
| `asr_raw.jsonl` | 中文识别结果（每行一条，含 nsp/lp 置信度） |
| `pitch.json` | 每条音频的中位基频（自相关 + YIN 两套） |
| `translations_cv.json` | **人工校对的中文台词 + 英文译文**（核心资产） |
| `translations_battle.json` | 战斗语音的译文（同上格式） |
| `lines.csv` | 汇总表：文件、中文、英文、音色、音高、目标时长、备注 |
| `en/` | 合成好的英文音频（文件名与工程内原文件一一对应） |
| `preview/` | 中英交替试听（`<hero>_cn_en.mp3`） |
| `zh_backup/` | 替换进工程前自动备份的中文原声 |
| `tts_report.csv` | 每条的实际时长偏差、使用的 rate/atempo |

## 脚本

```bash
PY=.workbuddy-ai/tmp/cvenv/bin/python      # 独立 venv，勿用系统 python

$PY CV_En_Full/asr_pack.py                 # 1. 中文识别（打包 28s 窗口，约 25 分钟/488 条）
$PY CV_En_Full/pitch_yin.py                # 2. 基频（决定音区/性别）
$PY CV_En_Full/make_lines.py               # 3. 生成 lines.csv（缺译文的会列出来）
$PY CV_En_Full/tts_batch.py CV_En_Full/lines.csv          # 4. 批量合成
$PY CV_En_Full/tts_batch.py CV_En_Full/lines.csv badun    #    只重跑某个英雄
$PY CV_En_Full/preview.py badun baiqi guanyu              # 5. 中英交替试听
$PY CV_En_Full/deploy.py apply cv                         # 6. 替换进 Assets（自动备份）
$PY CV_En_Full/deploy.py revert cv                        #    一键还原中文
```

## 关键设计

**时长对齐**：先裁掉 edge-tts 头尾静音（`silenceremove` + `areverse`），再按
`实际/目标` 比例用 `rate` 重合成（最多两轮，短句允许到 +45%），残余差值用 `atempo`
（长句 ≤1.18、短句 ≤1.35）收敛。实测偏差多在 ±3% 内。

**音色分配**：按原声基频分音区（男 <185Hz / 女 >235Hz，中间按角色人设人工覆盖），
从 edge-tts 的 25 个英文音色里按音区取池、用 key 的 md5 做稳定散列，保证
同一角色每次跑都是同一个声音，不同角色尽量不撞音。`pitch` 列做 ±25Hz 微调贴音区。

**可返工**：`lines.csv` 是唯一真相源。改译文或换音色只改这一行，然后
`tts_batch.py lines.csv <关键字>` 单条重跑，不影响其它文件。

## 已知限制

- 中文台词由 ASR 得到，**诗意/口播型台词有 20~30% 识别错乱**，`translations_*.json`
  里已人工校正；备注含 ⚠ 的是按语境推断、建议听音确认的条目。
- `cm_*` / `cw_*` 是「哈/嘿/啊」这类非语言拟声，不做翻译（保留中文原声即可）。
- edge-tts 是微软在线神经音色，**免费、无需 key，但需联网**；商用前建议核对
  微软语音服务的授权条款，或换成已购的 ElevenLabs / MiniMax / 火山音色
  （只需改 `cast.py` 的 `OVERRIDE`/池子，合成接口换一处即可）。
