# 游戏服每日巡检（自动任务）执行记录

## 任务
`/usr/bin/python3 scripts/server_health_check.py` → SSH 采集 129.226.213.65 → QQ SMTP 发信 772616239@qq.com → 留档 `scripts/logs/YYYY-MM-DD.log`。

## 执行历史
### 2026-10-12 10:14
- 结果：退出码 0，邮件已发送（凭据来源 `/Volumes/S/TD/.env`；`~/.gs_health.env` 不存在，已自动回退）。留档 `scripts/logs/2026-10-12.log`。
- 总体：⚠️ 基本正常，3 项需关注；核心程序 **4/4 在线**。
- 异常项：① Nginx 未运行（listen 80，老问题）② 可用内存 595 MB（告警线 600 MB，偏低）③ gameserver.log 尾部 3000 行含 2 条系统级故障关键字。
- 追加取证：系统级故障关键字实为 `java.io.IOException: Connection reset by peer`（10:13:48，netty read reset）⇒ 客户端 socket 异常断开，非服务端 OOM/超时，低风险噪音。
- 关注数据：内存 2840/3694 MB (77%)，可用 595 MB；磁盘 / 24G/59G (42%)；负载 1min 0.09。JVM 崩溃文件均为 6 月历史遗留；MongoDB authSource=admin 2/2；游戏服实例数 1（正确）。

### 2026-10-11 10:10
- 结果：退出码 0，邮件已发送（凭据来源 `/Volumes/S/TD/.env`；`~/.gs_health.env` 不存在，已自动回退）。
- 总体：⚠️ 基本正常，2 项需关注；核心程序 **4/4 在线**。
- 异常项：① Nginx 未运行（listen 80，已设开机自启但未启）② 自上次巡检后 gameserver、BT-Panel 发生重启。
- 关注数据：内存 2783/3694 MB (75%)，可用 645 MB；磁盘 / 24G/59G (42%)；负载 1min 0.05。
- gameserver.log 尾部 3000 行：业务级错误 241 条（均为 ScheduleThreadPool/MessageUtil INFO 噪音）/ 系统级故障 0 条。
- MongoDB authSource=admin 命中 2/2；游戏服实例数 1（正确）。

## 注意事项
- `/Volumes/S` 未挂载时凭据链会退到 `~/TD-recovery/.env` 或 `~/TD-salvage-20260911/.env`；后者已失效。需在报告里显式指出凭据来源。
- 巡检为只读：不重启服务、不改配置。
- 直接 `ssh gs` 偶发 `kex_exchange_identification: read: Connection reset by peer`（fail2ban/sshd 瞬时限流），重试即通；不影响脚本内 SSH 采集。
