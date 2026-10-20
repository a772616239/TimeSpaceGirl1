# REF-game-domain —— 货币/道具 id、protobuf、国家旗帜、区服与语言

> 从 `MEMORY.md` 迁出（2026-10-20），内容为原文。

## 🔴 货币 / 道具 id（错一个就误封）
- `3=英雄经验 14=金钱 16=钻石 17=玩家经验 79=?`，权威来源 `conf/server/ItemConfig.txt` + `Language.txt`（1010645 金钱 / 1010646 钻石 / 1010647 经验 / 1010641 英雄经验）。
- 🔴 `scripts/cheat/detect.py:116` 曾把 `itemMap["3"]` 标成 diamond ⇒ 全部"钻石异常"结论实为英雄经验（10-20 复核：Mozart 真钻石 1,107、Sakuya 951，全服 209 号 max 13,460）。现已全部改走 `scripts/cheat/currency.py`（从 `ItemConfig+Language` 现算 2,998 项，禁止写死）。
- 🔴 `item17` **语义未定，禁作基线**：209 个号里有 22 个 lv22~49 的号该值≈0，而 lv110 的 Mozart 是 125,634,740 ⇒ 它既不是稳定的"累计经验"，更不能拿去比空壳号中位数（那样能算出 62.8 万倍假离群，就是 10-18 误封的第二个原因）。
- 挂机/探险 `reason=1` 产出只有 经验/英雄经验/金钱/item79，**钻石 0**；钻石只在 `reason=2` 随机掉落（≈33/次）、邮件、`reason=28`(GM_REWARD)。

## protobuf 2.5.0
- 运行时 2.5.0；protoc 33 生成的 `GeneratedMessageV3` 编不过 ⇒ 按 HEAD proto 生成并与在库 `CommonProto.java` 逐字节 diff。
- `protocols.*` 在 `lib/gamecommon-1.0.0-SNAPSHOT.jar`（主 jar 靠 MANIFEST Class-Path 引 47 lib）⇒ 换协议两 jar 同动，否则 `NoSuchMethodError` 卡登录；重建会丢 `util/SysUtil.class` 补丁 ⇒ `zip -u` 只注差异类（先 touch）。
- 客户端 `~Lua/Message/*_pb.lua` 手补字段后重编 LuaBytes。已加 country：Player=25、UserRank=17、TeamOneInfo=21、ArenaPersonInfo=16、ChatInfo=28。

## 国家旗帜（→ docs/CountryFlag_FeatureDesign.md）
- 250 国（ISO 3166-1）、旗 132×88：新增 png 补 `.meta`（textureType 8/spriteMode 1/spritePackingTag）+ `ResourcePathConfig.asset` 登记。
- 下发收口 `AbstractRank.getOneUserRank.setCountry`；**关卡榜例外**：`getRank` 同分重排逐字段复制 UserRank，改行字段须同步。
- 改旗收口 `CountryRankManager.SetPlayerCountry`→`OnCountryChanged`+`RefreshSelfFlags()`；前三名只在 `SetHeadFlag`；「我的排名」走 `RefreshMyRankFlag`（Unranked 必须隐藏；公会战力榜取会长国籍）。
- 测试陷阱：`GetPlayerCountry()` 优先服务端值 ⇒ 断言前先 `PlayerManager.country=nil`。
- 10-20 落地运行时 IP→国家（`9ed2c1f3`）：入口 `PlayerCountryBootstrap.onLogin` → `InetSocketAddress` 对端 IP（**别用** `NettyGameSession.getIp()`）→ 查 `conf/ipcountry.dat`（380k 条，`tools/gen_ipcountry_table.py`）；机房/VPN/无证据 ⇒ 随机国籍（主要市场 3 倍权重）。离线表**必须带 endIp**；`countrySource` 0 老/1 手选/2 IP/3 随机，手选永不覆盖。
- 榜单读 `getUser(uid,true)` 实时 ⇒ 改库立即生效；setter 走 `updateString`+`SimpleTransaction.commit`。

## 区服 / 语言（→ REF-server-ops）
- 列表动态（`server_info`→登录服 HTTP）：新区服只插记录，`channel=pc/plat=android/sub_channel=1` 对齐；`tk/getServerList` 的 server_version 传真版本 `1.26001`（传 0 ⇒ 空列表）。
- 🔴 lanid=floor(id/100)%100：10001 中文CNY / 10101 英文USD / 10002 中文USD / 10201 日文 / 10301 韩文；真机首启用设备语言覆盖（`GameSettings.cs:110-114`）。
- 🔴 本地服性能基线（别改回去）：`threadNum=8`、`redis.timeout=2000`、`mongo maxConnectionIdleTime=60000`、`MaxMetaspaceSize=256m`；`timeLimitMap` 504 条不可删；netty 通道选项必须 `childOption`。
