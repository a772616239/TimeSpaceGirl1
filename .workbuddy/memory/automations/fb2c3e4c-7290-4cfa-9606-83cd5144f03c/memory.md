# 游戏服每日巡检（自动任务）执行记录

## 任务
`/usr/bin/python3 scripts/server_health_check.py` → SSH 采集 129.226.213.65 → QQ SMTP 发信 772616239@qq.com → 留档 `scripts/logs/YYYY-MM-DD.log`。

## 执行历史
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
