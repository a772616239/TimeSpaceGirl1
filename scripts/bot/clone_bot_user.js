// 从真实玩家复制出「虚拟玩家」账号数据（测试服用）
//
//   mongosh "mongodb://.../m5_x1_game_10001?authSource=admin" clone_bot_user.js
//
// 为什么要复制：机器人原先只有 ChatInfo 里的 uid/名字/等级，user 集合里没有这条文档，
// 客户端点开机器人头像 → 查不到玩家数据 → 个人面板全空。
//
// 做法：整份文档复制，把「指向自己的引用」全部改掉：
//   1. 值等于模板 uid 的字段（rootId / roleUid / _id …）
//   2. 以模板 uid 开头的 map key（合成主键，形如 <uid><type><timestamp>）
//   3. 以模板 uid 开头的**字符串值**（同样是合成主键，见下方说明）
//   4. playerManager.nickName / openId 换成本机器人的
// 其余数据（英雄、道具、关卡、活动进度）原样保留，面板才有内容。
//
// 🔴 第 3 条是 2026-10-21 补的坑：游戏里所有实例 id 都是「uid + 类型 + 时间戳」拼出来的
// 字符串（英雄 10000002010017798801320000 = uid 10000002 + 010 + 017798801320000）。
// 只改 map key 不改字符串值，就会出现：heroManager.heroMap 的键已经是 90000001…，
// 而编队 teamPosManager.teamPosForHero[1].listTeamPosHeroInfo[].heroId 还是 10000002…，
// 服务端 getUserTeamOneInfo 里 getHero(heroId) 查不到 → 面板「等级/头像有、编队 0 人、战力 0」。
//
// 安全：user 集合只有 _id 和 level 两个索引，没有 openId 唯一索引；_id 用 9xxxxxxx 段，
// 与现有 10000001~10000251 不冲突。脚本只插入新文档，不修改模板玩家。

var DB = db.getSiblingDB("m5_x1_game_10001");

// 模板 → 机器人。tpl 必须是真实、非 GM 的玩家 uid。
// ⚠️ 每个机器人必须用**不同模板**，否则两个机器人数据一模一样（曾经 Kai 和 Tester
// 同源 10000044，面板上等级/战力/编队全一样，一眼就能看出是复制的）。
// head/frame/country 显式写死，不要继承模板 —— 否则和模板玩家头像相同，也会露馅。
var SPECS = [
  { tpl: 10000002, uid: 90000001, name: "Nova",   head: 71041, frame: 80000, country: "ad" }, // lv50 vip1，158 英雄
  { tpl: 10000044, uid: 90000002, name: "Kai",    head: 71018, frame: 80000, country: "pt" }, // lv40，25 英雄
  // 假玩家（GM `bot fake` / 控制台「模拟玩家发言」用的 99990001）。
  // 不建这份文档的话，客户端点它头像 → 服务端 getUser 抛异常 → **不回包** →
  // PlayerInfoPopup 停在上一个玩家的数据上（实测「点 Tester 弹出 Nova 的面板」）。
  { tpl: 10000025, uid: 99990001, name: "Tester", head: 71000, frame: 80000, country: "us" }
];

var DRY = (typeof process !== "undefined" && process.env.CLONE_DRY === "1");   // CLONE_DRY=1 只打印不落库
var FORCE = (typeof process !== "undefined" && process.env.CLONE_FORCE === "1"); // CLONE_FORCE=1 覆盖已有文档

// 🔴 mongoKey 是「这个子对象在 user 文档里的路径」，形如
//      heroManager.heroMap.<uid><010><timestamp>
// 它以 "heroManager" 开头，**不以 uid 开头**，所以上面 rewrite 的「前缀替换」抓不到它。
// 漏改的后果（2026-10-22 踩到）：机器人英雄升级时 updateString("level") 拼出来的路径
// 还是 heroManager.heroMap.10000002…，数据写到野路径上 → 面板等级永远不变，
// 看起来就是「改了没生效」。这里专门把路径里的 .<oldUid> 段换掉。
function fixMongoKeyPaths(o, oldStr, newStr) {
  if (o === null || typeof o !== "object") return o;
  if (o instanceof Date || isBson(o)) return o;
  if (Array.isArray(o)) {
    for (var i = 0; i < o.length; i++) o[i] = fixMongoKeyPaths(o[i], oldStr, newStr);
    return o;
  }
  for (var k in o) {
    if (typeof o[k] === "function") continue;
    if (k === "mongoKey" && typeof o[k] === "string") {
      o[k] = o[k].split("." + oldStr).join("." + newStr);
    } else {
      fixMongoKeyPaths(o[k], oldStr, newStr);
    }
  }
  return o;
}

function isBson(v) {
  if (!v || typeof v !== "object") return false;
  if (v._bsontype) return true;                       // mongosh / 新版驱动
  // 🔴 老 mongo shell（4.0 只有它连得上）里 NumberLong/NumberInt 是**包装对象**，
  // 没有 _bsontype，但带 floatApprox / exactValueString 这类内部字段。
  // 漏判的后果：for...in 把它拆成 {floatApprox,top,bottom,exactValueString,tojson}，
  // 写回后 Spring 报 "No mapping metadata found for long"，整个玩家读不出来
  // （2026-10-22 实测：Tester 面板 500，createTime 被拆坏）。
  if (v.floatApprox !== undefined || v.exactValueString !== undefined) return true;
  if (v instanceof Date) return true;
  if (typeof NumberLong !== "undefined" && v instanceof NumberLong) return true;
  if (typeof NumberInt !== "undefined" && v instanceof NumberInt) return true;
  if (typeof ObjectId !== "undefined" && v instanceof ObjectId) return true;
  if (typeof Timestamp !== "undefined" && v instanceof Timestamp) return true;
  if (typeof Binary !== "undefined" && v instanceof Binary) return true;
  return false;
}

// 兜底修复：万一某个老 shell 类型还是被拆成了 {floatApprox, …}，这里还原成 NumberLong。
// 只在「源文档本身已经脏了」（二次克隆）时才会命中，正常路径零改动。
function repairShellNumbers(o) {
  if (o === null || o === undefined) return o;
  if (o instanceof Date || isBson(o)) return o;
  if (Array.isArray(o)) {
    for (var i = 0; i < o.length; i++) o[i] = repairShellNumbers(o[i]);
    return o;
  }
  if (typeof o === "object") {
    if (o.exactValueString !== undefined && o.floatApprox !== undefined) {
      return NumberLong(String(o.exactValueString));
    }
    for (var k in o) {
      if (typeof o[k] === "function") continue;
      o[k] = repairShellNumbers(o[k]);
    }
    return o;
  }
  return o;
}

function rewrite(o, oldUid, newUid) {
  var oldStr = String(oldUid), newStr = String(newUid);
  if (o === null || o === undefined) return o;
  // ⚠️ Date 必须最先拦：它是原生对象、没有 _bsontype，一旦走进下面的对象分支
  // 会被 for...in 遍历成空对象 {}，写回后 Spring 反序列化报
  // "No mapping metadata found for java.util.Date"，整个玩家读不出来
  if (o instanceof Date) return o;
  if (isBson(o)) return o;                       // Long / ObjectId / Binary / Decimal128 原样
  if (Array.isArray(o)) {
    for (var i = 0; i < o.length; i++) o[i] = rewrite(o[i], oldUid, newUid);
    return o;
  }
  if (typeof o === "object") {
    var out = {};
    for (var k in o) {
      var nk = (k.indexOf(oldStr) === 0) ? newStr + k.slice(oldStr.length) : k;
      out[nk] = rewrite(o[k], oldUid, newUid);
    }
    return out;
  }
  if (o === oldUid) return newUid;
  if (typeof o === "string") {
    // 字符串值里的合成主键：heroId / equipId / mailId … 都以 uid 开头。
    // 必须和 map key 用同一条规则，否则「键改了值没改」→ 查不到英雄。
    if (o === oldStr) return newStr;
    if (o.indexOf(oldStr) === 0) return newStr + o.slice(oldStr.length);
  }
  return o;
}

SPECS.forEach(function (s) {
  var src = DB.user.findOne({ _id: s.tpl });
  if (!src) { print("!! 模板不存在 " + s.tpl); return; }

  if (DB.user.countDocuments({ _id: s.uid }) > 0) {
    if (!FORCE) {
      print("!! 目标已存在，跳过 " + s.uid + "（重做加 CLONE_FORCE=1）");
      return;
    }
    if (!DRY) {
      DB.user.deleteOne({ _id: s.uid });
      print("   已删除旧文档 " + s.uid);
    }
  }

  var doc = rewrite(src, s.tpl, s.uid);
  doc = fixMongoKeyPaths(doc, String(s.tpl), String(s.uid));
  doc = repairShellNumbers(doc);
  doc._id = s.uid;
  doc.playerManager.nickName = s.name;
  doc.playerManager.openId = "bot_" + s.uid;
  // 头像/头像框/国家必须和模板不同，否则聊天条、面板上一模一样
  if (s.head) doc.playerManager.head = NumberInt(s.head);
  if (s.frame) doc.playerManager.headFrame = NumberInt(s.frame);
  if (s.country) doc.playerManager.country = s.country;

  // 「最后登录」装成很久以前的老号 —— 刚做出来的号 loginTime 是「1 小时前」，
  // 谁点开都像个人工造的号。这里按 uid 取固定种子（3~9 天前），
  // 重跑脚本结果稳定，不会今天 3 天前、明天 5 天前。
  var now = Date.now();
  var seed = s.uid % 7;                                   // 0..6
  var daysAgo = 3 + seed;                                 // 3 ~ 9 天
  var lastLogin = now - daysAgo * 86400000 - (s.uid % 12) * 3600000;
  var lastOffline = lastLogin + (20 + s.uid % 60) * 60000; // 上线 20~80 分钟后下线
  doc.playerManager.loginTime = NumberLong(String(lastLogin));
  doc.playerManager.offLineTime = NumberLong(String(lastOffline));
  doc.playerManager.loginTimeTody = NumberLong(String(lastLogin));
  doc.playerManager.OnlineTimeTody = NumberLong("0");
  // createTime 必须早于 loginTime，否则「注册时间晚于最后登录」一眼假。
  // 模板的 createTime 一般更早，只在真的晚于 loginTime 时才往前挪。
  var ct = doc.playerManager.createTime;
  var ctVal = (ct && ct.exactValueString) ? Number(ct.exactValueString) : Number(ct);
  if (!ctVal || ctVal > lastLogin) {
    doc.playerManager.createTime = NumberLong(String(lastLogin - (30 + seed) * 86400000));
  }

  var pm = doc.playerManager;
  var heroes = doc.heroManager && doc.heroManager.heroMap ? Object.keys(doc.heroManager.heroMap).length : 0;

  print("→ " + s.tpl + "(" + src.playerManager.nickName + " lv" + src.playerManager.level + ")"
      + " 复制为 " + s.uid + "(" + s.name + ") lv" + pm.level + " vip" + pm.vipLevel
      + " head=" + pm.head + " 国家=" + pm.country + " 英雄=" + heroes
      + " 最后登录=" + daysAgo + "天前 文档=" + JSON.stringify(doc).length + "B");

  if (DRY) { print("   [DRY] 未写入"); return; }

  DB.user.replaceOne({ _id: s.uid }, doc, { upsert: true });
  print("   ✔ 已写入");
});

print("--- 结果 ---");
SPECS.forEach(function (s) {
  var d = DB.user.findOne({ _id: s.uid });
  if (!d) { print(s.uid + " 不存在"); return; }
  var pm = d.playerManager;
  // Date 字段必须还是 date 类型；被遍历成 {} 的话服务端 getUser 会抛
  // "No mapping metadata found for java.util.Date"，玩家面板读不出来
  var dt = DB.user.aggregate([
    { $match: { _id: s.uid } },
    { $project: { d: { $type: "$playerManager.nextDailyRefreshTime" }, c: { $type: "$playerManager.createTime" } } }
  ]).toArray()[0];
  print(s.uid + " | " + pm.nickName + " | lv" + pm.level + " | vip" + pm.vipLevel
        + " | head=" + pm.head + " | force=" + pm.maxForce + " | rootId=" + pm.rootId
        + " | openId=" + pm.openId
        + " | Date字段=" + JSON.stringify(dt));
});
