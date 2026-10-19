---
name: gm-fullserver-mail
description: 通过服务端 thrift RPC（127.0.0.1:7916 的 idipGm）给 TimeSpaceGirl1 全服或指定玩家发邮件 / 节日礼包 / 补偿。当用户说"发全服邮件""送全服礼包""发节日奖励/圣诞礼物""补偿玩家""给某个玩家发个箱子"时使用。内含道具 ID 口径（游戏里没有"三星英雄箱"）、参数格式陷阱（首个 token 被丢弃、resultCode=0 可能是假成功）、默认英文文案模板、itemLog 三层验证与回滚方法。
---

# 全服邮件 / 全服礼包

> 完整原理、踩坑复盘、回滚 SQL、模板库：**`docs/gm_fullserver_mail_skill.md`**
> 工具：**`scripts/gm_client.py`**（本地服/生产通用，`--host/--port` 或 `GM_HOST/GM_PORT`）

## 用哪条通道

服务端 thrift `idipGm` → `Cmd_<指令>`。**不要**用客户端 GM 协议（只作用于本人，且生产 `server.debug=false` 已封，是 2026-10-18 Sieg 事故的通道）。

```bash
python3 scripts/gm_client.py 'oneuserinfo 10000004'                  # 只读探查
python3 scripts/gm_client.py 'sendmailall 0 6001000#20@#标题@#正文'   # 全服
python3 scripts/gm_client.py 'sendmail <uid> <uid> 6001000#20@#标题@#正文'  # 单发
```

## 🔴 三个必记的坑

1. **`sendmailall` 的第一个 token 被实现丢弃**（拼接循环从 `i=1` 开始）。
   正确：`sendmailall <占位,习惯写0> <items>@#<title>@#<content>`。
   `sendmail` 则要 **uid 写两遍**（第一个用于选人，第二个是 `args[0]`）。
2. **`RESULT: (0, None)` ≠ 成功**。`exeCmd` 不看 `exec` 的返回值，解析失败也回 0。
   必须验证：日志 `sendMailall==>` + mongo `systemMailMap` + `itemLog reason=16`。
3. **分隔符**：`@#` 分段、`|` 分物品、`#` 是 `id#数量`。正文不能含 `@#` / `|` / 换行；连续空格会被压成一个。

## 道具口径

**没有「三星英雄箱」这个道具。** 送 1 名三星英雄 = `6001000`（3星英雄碎片）× **20**（`UsePerCount=20`）。
其他：`6001010` 4星碎片(30)、`60426` 4星自选箱、`60451` 6星自选箱、`60413` 3系英雄自选、`16` 钻石。

## 文案

**默认英文**（系统邮件不走 i18n，一份文案全区可见）：

```
sendmailall 0 6001000#20@#Christmas Gift Pack@#Merry Christmas, Commander! Your gift pack contains 20x 3-Star Hero Shards. Collect 20 shards to summon 1 random 3-Star Hero. Thank you for playing with us!
```

## 铁律

- **生产发全服先问用户**（全体可见、不可撤回）；开发服（本机 16081，库 `m5_x1_game_10001`）可自行试。
- 生产 `gmport` 只监听服务器本机 ⇒ `ssh -N -L 17916:127.0.0.1:7916 gs` 后 `--port 17916`。
- 全服邮件 `registerEndTime=发送时刻` ⇒ **新注册号收不到**；有效期 30 天写死。
- 汇报要带量化证据（itemLog 那条 `+N`），不要只说"已发送"。
