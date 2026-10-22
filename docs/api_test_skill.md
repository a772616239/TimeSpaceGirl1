# 服务端全量接口测试（`TS-Api-Test`）

> 更新时间：2026-10-23
> 适用范围：服务端发版后 / 改过 proto、handler、公共 DAO、配置表之后
> 关联文档：`docs/jenkins_ci.md`（job 清单与阶段表）、`docs/server_ops_runbook.md`（线上运维）、`scripts/verify/protocol_selftest.py`（协议连通自检，**不是同一件事**）

一句话：**把 proto 里每一个 `*_REQUEST`（当前 372 个）都真发一遍，逐个判定「接口在不在、进没进 handler、有没有把服务端搞崩」，每个接口一条 JUnit 用例。**

---

## 1. 它补的是哪个洞

| 已有的检查 | 能证明什么 | 证明不了什么 |
|---|---|---|
| `TS-Server-Health`（⑩ 上线自检） | 进程在、端口在听、没 OOM | 接口还在不在 |
| `protocol_selftest.py`（⑩-2 协议自检） | TEA 编解码、双向通道、鉴权没被绕过、能登录 | 那 372 个接口里有没有哪个已经悄悄没了 handler |
| **`TS-Api-Test`（⑬-2）** | **每个协议号都还有 handler，且没把服务端搞挂** | 业务正确性（参数、数值、奖励对不对） |

典型失效场景：删了一个 handler 类 / 改包名让 Spring 扫不到 / 加了一行 `getMessageCode()` 返回 null 而类名又对不上协议名 —— 这三种都不会让服务端起不来，也不会让登录失败，只有玩家点到那个面板时才暴露。发版当场扫一遍，就坏在发版当场。

---

## 2. 怎么跑

```bash
# 只列清单（不连服务器，改完 proto 先看这里）
python3 scripts/verify/api_full_sweep.py list --scope 全量

# 手工三段式（Jenkins 里就是这三步，分别对应 ②③④ 阶段）
PY=scripts/verify/api_full_sweep.py
python3 $PY preflight --state /tmp/api.json --target 现网-129.226.213.65 --scope 全量
python3 $PY sweep     --state /tmp/api.json --target 现网-129.226.213.65 --scope 全量
python3 $PY postcheck --state /tmp/api.json --target 现网-129.226.213.65
python3 $PY report    --state /tmp/api.json --html /tmp/api.html
```

Jenkins 里：`TS-Api-Test`，参数 `TARGET` / `SCOPE` / `UID` / `TIMEOUT` / `BUDGET`。
`TS-Server-Release` 的 `API_TEST_AFTER=true`（默认）会在打完包后**异步**触发它。

三个档位：

| 档位 | 接口数 | 耗时 | 什么时候用 |
|---|---|---|---|
| `核心` | 11 | ~30s | 改完随手点一下，只看「进得去游戏、主界面不空」 |
| `只读` | 58 | ~1min | 想扫一遍又不想动数据 |
| `全量` | 369 | 6~9min | **发版后默认**；改过 proto / handler / 公共 DAO |

> 369 = 372 个 `*_REQUEST` 减去 3 个特殊协议（心跳/登录/GM，由 `preflight`、`postcheck` 单独覆盖）。

---

## 3. 判定口径（核心，改之前先读这段）

### 3.1 每个接口发什么

**空 payload**（参数全缺）。理由：

1. **安全**：绝大多数写接口会在业务校验处被拒，不会真的买东西/发奖；
2. **可维护**：不用为 372 个接口各写一份合法参数（写不完，写完也会随版本腐烂）；
3. **目标明确**：这一档要证的是「接口还在、还能进 handler」，不是业务正确性。

代价：少数接口用全默认值也能成功（签到、领奖之类）。**所以只能拿专用测试号跑**（现网默认 `10000004`，见 `conf/bot_config.json` 的 `ignoreUids`）。

### 3.2 判定表

| kind | 含义 | 判定 |
|---|---|---|
| `ok` | 收到 `请求号+1` 的回包 | pass |
| `biz-reject` | 回包是 `ErrorResponse`（业务参数缺失被拒） | pass |
| `frame-other` | 收到帧但号对不上，日志也没该接口记录 | pass |
| `exec-no-reply` | 日志有该接口的异常，但没回包 | pass（接口在，只是异常路径不回包） |
| `silent` | 无回包、日志无记录 | pass（handler 存在但空参数下静默早退） |
| `no-handler` | 日志明确 `request unknow commond : <rid>` | **fail** |
| `disconnected` | 服务端断开连接 | **fail** |
| `known-gap` | 命中 `api_known_gaps.json` | skip |

**判红只有两种**：`no-handler`（接口没了）和 `disconnected`（把连接搞崩了）。
另外 ④ 复核阶段还会判：进程期间重启过 → fail；新连接登不上 → fail。

为什么 `exec-no-reply` / `silent` 判 pass：空 payload 下大量接口会抛异常或静默早退，这是**预期**的。把这些判红，这个 job 三天就没人看了。但它们仍逐条列进报告，数量变化本身就是信号。

### 3.3 🔴 为什么用「服务端日志」而不是「回包号」当 oracle

这是本脚本最容易踩错、也最容易被后人「优化」掉的一点：

- 正常回包用 `请求号+1`；
- **错误回包用的是 `session.getLastMsgId() + 1`**（`MessageUtil.sendErrorResponse`），不是请求号+1；
- 而 `session.setLastMsgId()` 只在 `HandlerLogicThread` 里对**进了 handler** 的请求赋值 —— 未注册 handler 时 `lastMsgId` 还停在上一个请求上。

实测证据（2026-10-23 首跑）：

```
客户端发 10016 (ADVENTURE_INFO_REQUEST)
服务端日志：ProtocolsManager#115 - INFO:request unknow commond : 10016
服务端回包：msgId=10009   ← 上一个请求 10008 的响应号
```

按回包号认领会得出两个错误结论：「10016 收到了推送」+「10009 莫名多了一帧」。所以判定只认日志里这两行：

```
processWithProto Exception protoID=<rid>     → 该接口进了 handler（并附异常文本）
request unknow commond : <rid>               → 该接口没有 handler
```

日志路径：`/data/srvlog/gameserver.log`（`/proc/<pid>/fd/1` 指向它，不是 `assets/log/` 下那份业务日志）。
取法：扫描前后各记一次文件大小，`tail -c +<offset+1>` 只拉增量里命中的行。

**没有 ssh 时会降级**：只用回包判，「无回包」不判红（`kind=no-reply`），报告里标 `判定 oracle：仅回包（降级）`。本地自测服就是这种情况。

---

## 4. 已知缺口（baseline）

`scripts/verify/api_known_gaps.json`：proto 里声明、服务端**本来就没实现**的协议号。

```json
{ "gaps": [ { "id": 10016, "name": "ADVENTURE_INFO_REQUEST", "reason": "冒险系统已下线，客户端入口也关了" } ] }
```

命中的判 `skip` 并在报告里写原因。与 `tests/lua-baseline.json` 同一套路：**已知失败走基线，基线外的新失败才红**。

⚠️ 加条目前先确认真的是「不打算实现」，而不是「漏了」—— 后者该修服务端，不该进这里。

---

## 5. 坑位

1. **空 payload 也会改数据**：签到/领奖/刷新这类接口用默认值就能成功。只用专用测试号。
2. **登录会顶号**：`LOGIN_REQUEST` 会建会话，该号若在线会被顶下线。发版后自动跑会顶掉 10000004（测试号，无妨）。
3. **不能靠并发加速**：服务端按 `uid % HANDLER_THREAD_NUM` 把同一 uid 的请求**串到同一个 handler 线程**，并发连接也还是排队。所以全量档的时长 ≈ 不回包的接口数 × `TIMEOUT`，想快就调小 `TIMEOUT`（正常接口 200ms 内就回，1.5s 已经余量很大）。
4. **`TIMEOUT` 直接决定整轮时长**：369 个接口里约 220 个不回包，1.5s ⇒ 约 5.5 分钟；2.0s ⇒ 约 7.5 分钟。
5. **日志 offset 要在扫描开始时取**，不能沿用 preflight 的 —— 中间隔着别的阶段，沿用旧 offset 会把别的环节的日志算进本轮。
6. **服务端日志在 `/data/srvlog/gameserver.log`**，不是 `assets/log/jl_logs/` 下那份。找法：`ls -l /proc/<pid>/fd | grep log`。
7. **协议号会重复/改名**：`parse_message_types` 对重复号直接抛错（早死早好）；「核心」档的名字对不上 proto 时 `preflight` 会出一条 `warn`，不会静默少测。
8. **判定逻辑改之前先跑一次全量留底**：把 `kind` 分布记下来，改完对比。历史上「按回包号认领」这个坑就是这么发现的。

---

## 6. 首跑数据（2026-10-23，现网 129.226.213.65，全量档）

```
369/369 个接口已扫 · 有回包 307 · 静默早退 34 · 无 handler 28 · 耗时 8m20s（TIMEOUT=2.0）
服务端日志增量：217 行可判定记录（161 个接口有异常、28 个接口无 handler）
```

28 个「proto 有、服务端没 handler」里比较扎眼的：

| 协议号 | 名字 | 备注 |
|---|---|---|
| 10016 | `ADVENTURE_INFO_REQUEST` | **客户端 `NetManager.lua:3132` 仍在发** |
| 10018 / 10020 / 10032 / 10049 | `ADVENTURE_CHALLENGE` / `UPLEVEL` / `FLUSH_BOSS` / `LEFT` | 冒险系统整组 |
| 10113 | `BUY_TREASURE_REQUEST` | |
| 10200 | `COOK_FOOD_REQUEST` | 烹饪系统 |
| 11214 / 11223 / 11240 | `MAP_BUY_FIGHT_COUNT` / `MAP_TOWER_RESET` / `MAIN_LEVEL_GET_RANK` | 地图塔一组 |

这批要么补 handler、要么确认下线后写进 `api_known_gaps.json`。**在此之前全量档会一直是红球**，这是刻意的：缺口没确认之前不该是绿的。

---

## 7. 加东西怎么加

| 要加什么 | 改哪里 |
|---|---|
| 新目标服 | `scripts/verify/api_targets.json`（host/port/ssh/redis/log_file/uid_hint）—— 改地址只改这里 |
| 新的「核心」接口 | `api_full_sweep.py` 的 `CORE_NAMES`（名字必须与 proto 逐字一致） |
| 允许缺的协议 | `scripts/verify/api_known_gaps.json`（附 reason） |
| 判定口径 | `api_full_sweep.py` 的 `rejudge()`，改完同步本文件第 3 节 |
