# 全服邮件 / 全服礼包 下发技能（GM）

> 更新时间：2026-10-19
> 配套：`server_ops_runbook.md`（生产环境事实）、`gm_abuse_incident_playbook.md`（GM 通道被滥用的事故复盘）、`scripts_reference.md`（脚本清单）
> 工具：`scripts/gm_client.py`
> 一句话：**让服务端自己发系统邮件（thrift `idipGm`），不要走客户端 GM 通道。**

---

## 0. 🔴 六条红线

1. **生产发全服 = 全体玩家可见、不可撤回。** 动生产前必须拿到用户明确同意；开发服可自行试。
2. **发出去收不回。** 系统邮件一旦生成，玩家打开邮件面板就会转成个人邮件；已领取的附件无法回收，只能补发/补偿。
3. **标题和正文是单条字符串，不走 i18n 表。** 国际服只有一份文案 ⇒ **默认写英文**（见 §9）。
4. **thrift 通道无鉴权。** 它只 bind `127.0.0.1`，安全性靠"不暴露端口"，不要 `ssh -L 0.0.0.0`、不要写进防火墙放行。
5. **不要用客户端 GM 通道（`GM_REQUEST`）做这件事。** 它只作用于本人、且生产 `server.debug=false` 已被封（2026-10-18 Sieg 事件就出在这条通道）。
6. **`resultCode=0` 不代表发成功。** 必须查库/查 itemLog 验证（§7），详见 §5 的"假成功"。

---

## 1. 什么时候用

- 用户要「发全服邮件」「送全服礼包」「发节日/圣诞/新年奖励」「补偿玩家」
- 用户要「给某个玩家单独发一封带附件的邮件」
- 要查某个指令到底有没有生效（客户端显示正常但玩家没收到）

不适用：改公告板 / 改活动配置（那些走配置表，见 `server_ops_runbook.md`）。

---

## 2. 三条通道，只有一条能用

| 通道 | 入口 | 作用范围 | 生产可用 | 备注 |
|---|---|---|---|---|
| **服务端 thrift RPC** | `127.0.0.1:7916` → `GmService.idipGm` → 反射 `Cmd_<指令>` | 全服 / 指定 uid | ✅ **唯一可用** | 本文主角 |
| 客户端 GM 协议 | `MessageType.GM_REQUEST`（`GMRequestHandler`） | **仅自己** | ❌ `server.debug=false` 直接抛 `In a formal setting` | 事故源 |
| 登录服 HTTP | `tk/...` 等接口 | 无关 | — | 不碰 |

调用链：

```
gm_client.py --port 7916 'sendmailall ...'
   → TBinaryProtocol(strictRead/strictWrite)  idipGm("", cmd)
   → GmService.exeCmd(cmd)                      // 空格切词、指令名小写反射 Cmd_xxx
   → Cmd_sendmailall.exec(args)                 // 解析 items@#title@#content
   → MailLogic.sendMailAll(title, content, items, now, 30天)
   → sendSystemMail(...)  → mongo `mailingSystem.systemMailMap.<nowInt>`
   → 玩家拉邮件列表时 systemMailToUserMail() 转成个人邮件并派附件
```

关键事实：

- 有效期 **30 天写死**（`Cmd_sendmailall` 传 `30*24*60*60`）。
- `registerEndTime = 发送时刻` ⇒ **只有发送前注册的老号收得到，新注册号收不到**（既有语义，不是 bug）。
- 全服 = `userList` 传空列表，服务端**根本不校验**这个字段。
- 邮件上限 `Global.MAIL_BOX_CAPACITY`，超了会按 sendTime 删最早的。

---

## 3. 前置准备（一次性）

```bash
# 依赖（本机 managed venv 已装过；换机重装）
/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/pip install thrift

# 端口确认：本地服 / 生产都只监听 127.0.0.1
lsof -nP -iTCP:7916 -sTCP:LISTEN
ssh gs 'ss -lntp | grep 7916'      # 生产
```

若 `7916` 没监听：服务端没起，或 `config/application.properties` 里 `services.core.gmport` 被改过。**不要**去改这个端口来"方便远程访问"。

---

## 4. 两步走：先单发验证，再全服

### 4.1 单发（只对在线/可加载的号有意义）

```bash
python3 scripts/gm_client.py 'sendmail 10000004 10000004 16#1@#TEST-MAIL@#This is a delivery test.'
```

> 🔴 **uid 必须写两遍。** 第一个是"收件人列表"（`GmService` 用来选人），第二个才是 `Cmd_sendmail` 的 `args[0]`。写一遍会把 items 当成 uid 解析失败。

成功标志（服务端日志）：

```
MailLogic sendMail==>uid=10000004,title=TEST-MAIL,reward:16#1
```

mongo 里会立刻多一条 `user.mailManager.mailMap.<id>`，`state=0`、`effectiveTime=0`（永不过期）。

单人邮件与全服邮件的差别：**单人邮件不进 `systemMailMap`**，直接落玩家文档；玩家领取后按普通邮件删除。

### 4.2 全服

```bash
python3 scripts/gm_client.py 'sendmailall 0 6001000#20@#Christmas Gift Pack@#Merry Christmas, Commander! ...'
```

> 🔴 **第一个参数是占位符，随便写（习惯写 `0`），不会生效。** 原因见 §5。

成功标志（两道都要看）：

```
MailLogic sendMailall==>title=Christmas Gift Pack,reward:6001000#20
mongo mailingSystem.systemMailMap.<nowInt> 出现对应文档
```

---

## 5. 🔴 参数格式：三个必踩的坑

### 坑 1：`sendmailall` 的第一个 token 被实现丢掉

`Cmd_sendmailall.exec(String[] args)` 里拼接循环从 `i=1` 开始（`args[0]` 只赋给一个没人用的 `items1`）。所以：

| 写法 | 结果 |
|---|---|
| `sendmailall 6001000#20 @#标题@#正文` | ❌ items 变空串 → `NumberFormatException` → **但 `resultCode=0`** |
| `sendmailall 0 6001000#20@#标题@#正文` | ✅ |

同理 `Cmd_sendmail` 要写成 `sendmail <uid> <uid> <items>@#<title>@#<content>`。

### 坑 2：「假成功」

`GmService.exeCmd` 只判断"类能不能 new 出来 + exec 有没有抛异常"，**不看 `exec` 的返回值**。`Cmd_sendmailall` 用 `return false` 表示解析失败，外层照样回 `(0, None)`。

⇒ **永远不要用 `RESULT: (0, None)` 当"发成功"的证据，必须查库或看 `sendMailall==>` 日志。**

### 坑 3：分隔符与空格

| 符号 | 含义 | 正文里能用吗 |
|---|---|---|
| `@#` | 三段分隔（items / title / content） | ❌ 绝不能出现 |
| `\|` | 多个物品之间 | ❌ |
| `#` | 物品内 `id#数量` | 只能出现在 items 段 |
| 空格 | 整条命令按空格切词再拼回 | ⚠️ 连续多个空格会被压成 1 个；换行 `\n` 不会被解析 |

正文**写成一整段、不要换行、不要连续空格**。英文正文天然满足。

---

## 6. 道具 ID 速查（ItemConfig.xlsx）

**没有「三星英雄箱」这个道具**——这是最容易记错的一条。可用的替代：

| 需求 | 道具 ID | 名称 | 数量口径 |
|---|---|---|---|
| 送 1 名三星英雄 | `6001000` | 3星英雄碎片 | **20** 个合成 1 名（`UsePerCount=20`，随机） |
| 送 1 名四星英雄 | `6001010` | 4星英雄碎片 | 30 个 |
| 四星自选 | `60426` | 4星英雄自选箱 | 1 |
| 六星自选 | `60451` | 6星英雄自选箱 | 1 |
| 五星碎片自选 | `60413` | 3系英雄自选 | 1（7 选 1，各 50 碎片） |
| 钻石 | `16` | 钻石（货币） | 任意 |

查新道具（改表后 ID 会变，别凭记忆）：

```bash
cd data_execl/base_data
python3 - <<'PY'
import openpyxl
wb=openpyxl.load_workbook('Language.xlsx',read_only=True,data_only=True); ws=wb['Language']; lang={}
for r in ws.iter_rows(min_row=5,values_only=True):
    if r and r[1] is not None: lang[int(r[1])]=str(r[2] or '')
wb2=openpyxl.load_workbook('ItemConfig.xlsx',read_only=True,data_only=True)
rows=list(wb2['ItemConfig'].iter_rows(values_only=True)); hdr=rows[0]
idx={str(h):i for i,h in enumerate(hdr) if h}
for r in rows[4:]:
    i=r[idx['Id']]
    if not isinstance(i,int): continue
    n=lang.get(r[idx['Name']] if isinstance(r[idx['Name']],int) else 0,'')
    if '英雄' in n and any(k in n for k in ('箱','碎片','自选')):
        print(i,'| type',r[idx['ItemType']],'|',n)
PY
```

> `ItemConfig` 前 4 行是表头/类型/长度/注释，数据从第 5 行开始；`Name` 列是 Language 表的索引，不是文本。

---

## 7. 验证：三层证据，缺一不可

| 层级 | 查什么 | 判定 |
|---|---|---|
| ① 服务端日志 | `grep 'sendMailall==>' ~/home/java/logs/gameserver.log` | 有行且 title/reward 对 |
| ② 库-系统邮件 | `mailingSystem.systemMailMap.<id>` | `title`/`content`/`reward` 正确，`effectiveTime=2592000` |
| ③ 库-玩家到账 | `itemLog` 里 `reason=16`、`itemId` 一致 | `type=0` 且 `num` 与发放量一致 |

```bash
# 生产/本地通用（本地 = mongodb://a772616239:Wang@127.0.0.1:27017/m5_x1_game_10001?authSource=admin）
mongo --quiet "$MONGO_URI" --eval '
var m=db.mailingSystem.findOne({_id:10001});
for(var k in m.systemMailManager.systemMailMap){var d=m.systemMailManager.systemMailMap[k];print(k+" | "+d.title+" | "+d.reward)}
db.itemLog.find({itemId:6001000}).sort({_id:-1}).limit(3).forEach(function(d){print(JSON.stringify(d).substring(0,300))});
'
```

2026-10-19 开发服实测证据（可作为对照）：

```
uid=10000005 type=0 reason=16 itemId=6001000 num=+20 total=34   ← 领取邮件
uid=10000005 type=1 reason=1014    itemId=6001000 num=-20 total=14   ← 15 秒后合成用掉
```

---

## 8. 纠错与回滚

| 情况 | 处理 |
|---|---|
| 发错但**还没人打开邮件面板** | mongo `$unset mailingSystem.systemMailMap.<id>`，玩家侧不会生成 |
| 已经生成个人邮件、**未领取** | 只能逐号 `$unset user.mailManager.mailMap.<id>`（注意玩家在线时内存会回写 ⇒ 先踢线/停服） |
| 已领取 | **收不回**。补发一封说明邮件或补偿，并在公告里解释 |
| 文案错字但只发了个别号 | 单人邮件可直接改 `user.mailManager.mailMap.<id>.content`（同上下线要求） |

开发服清理示例：

```js
db.user.updateOne({_id:10000004},{$unset:{"mailManager.mailMap.10000004010217924001520000":""}})
```

---

## 9. 英文文案模板库（默认口径）

生产是国际服，**默认英文**。标题 ≤ 24 字符较安全，正文单段、无换行、无 `@#`。

**A. 圣诞 / 节日礼包（3 星英雄碎片×20）**

```
sendmailall 0 6001000#20@#Christmas Gift Pack@#Merry Christmas, Commander! Your gift pack contains 20x 3-Star Hero Shards. Collect 20 shards to summon 1 random 3-Star Hero. Thank you for playing with us!
```

**B. 通用节日（钻石 + 碎片）**

```
sendmailall 0 16#300|6001000#20@#Holiday Gift@#Happy holidays, Commander! Please enjoy 300x Diamonds and 20x 3-Star Hero Shards, a small thank-you for your support. See you on the battlefield!
```

**C. 维护补偿**

```
sendmailall 0 16#500@#Maintenance Compensation@#Dear Commander, the server is back online. We are sorry for the downtime and hope these 500x Diamonds make up for it. Thank you for your patience!
```

**D. 版本更新 / 新服开放**

```
sendmailall 0 60426#1@#Update Celebration@#Dear Commander, thank you for joining our new update! Here is a 4-Star Hero Selection Chest for you. Enjoy the adventure!
```

> 中文文案只用于本地开发服自测；正式服不要混语言。若确实需要多语言，只能按服分别发（每服一份文案），系统邮件不支持按语言分流。

---

## 10. 生产服执行（需要用户明确同意）

`gmport` 只监听服务器本机 ⇒ 本地必须开隧道：

```bash
# 终端 A（后台挂着）
ssh -N -L 17916:127.0.0.1:7916 gs

# 终端 B
python3 scripts/gm_client.py --port 17916 'sendmailall 0 16#300@#Holiday Gift@#Happy holidays!'
```

生产验证（SSH 到服务器跑 mongo，库名 `m5_x1_game_10001`）：

```bash
ssh gs 'mongo --quiet "mongodb://<user>:<pass>@127.0.0.1:27017/m5_x1_game_10001?authSource=admin" --eval "..."'
```

> 生产 Mongo 串见 `.secrets/`，**必须带 `authSource=admin`**。
> 生产目前只有 1 个 gameserver（区服 `10001`）；若以后多区，每区独立 JVM + 独立库，要**逐区发**。

---

## 11. 一页纸清单

- [ ] 确认目标服：开发服（本机 16081）还是生产（`gs`）
- [ ] 生产需先拿到用户同意；说明"不可撤回"
- [ ] 确认真实道具 ID（**没有"三星英雄箱"**，用 `6001000`×20）
- [ ] 默认英文文案；检查无 `@#`、无 `|`、无换行、无连续空格
- [ ] `sendmailall 0 <items>@#<title>@#<content>`（第一个 token 是占位符）
- [ ] 单发验证优先：`sendmail <uid> <uid> <items>@#<title>@#<content>`
- [ ] 全服发完：查 `sendMailall==>` 日志 + `systemMailMap` + `itemLog reason=16`
- [ ] 汇报里带上量化证据，不要只说"已发送"
