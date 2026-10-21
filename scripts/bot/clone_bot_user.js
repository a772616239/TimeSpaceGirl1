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
//   3. playerManager.nickName / openId 换成本机器人的
// 其余数据（英雄、道具、关卡、活动进度）原样保留，面板才有内容。
//
// 安全：user 集合只有 _id 和 level 两个索引，没有 openId 唯一索引；_id 用 9xxxxxxx 段，
// 与现有 10000001~10000251 不冲突。脚本只插入新文档，不修改模板玩家。

var DB = db.getSiblingDB("m5_x1_game_10001");

// 模板 → 机器人。tpl 必须是真实、非 GM 的玩家 uid。
var SPECS = [
  { tpl: 10000002, uid: 90000001, name: "Nova" },   // lv50 vip1，158 个英雄，数据最完整
  { tpl: 10000044, uid: 90000002, name: "Kai" }     // lv40，25 个英雄，轻量一些
];

var DRY = (typeof process !== "undefined" && process.env.CLONE_DRY === "1");   // CLONE_DRY=1 只打印不落库
var FORCE = (typeof process !== "undefined" && process.env.CLONE_FORCE === "1"); // CLONE_FORCE=1 覆盖已有文档

function isBson(v) {
  return v && typeof v === "object" && v._bsontype;
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
  if (typeof o === "string" && o === oldStr) return newStr;
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
  doc._id = s.uid;
  doc.playerManager.nickName = s.name;
  doc.playerManager.openId = "bot_" + s.uid;

  // 让"最后在线"落在几小时前：太新像在线，太旧像死号
  var now = Date.now();
  doc.playerManager.offLineTime = NumberLong(String(now - 3600 * 1000));
  doc.playerManager.loginTime = NumberLong(String(now - 7200 * 1000));

  var pm = doc.playerManager;
  var heroes = doc.heroManager && doc.heroManager.heroMap ? Object.keys(doc.heroManager.heroMap).length : 0;

  print("→ " + s.tpl + "(" + src.playerManager.nickName + " lv" + src.playerManager.level + ")"
      + " 复制为 " + s.uid + "(" + s.name + ") lv" + pm.level + " vip" + pm.vipLevel
      + " head=" + pm.head + " 英雄=" + heroes + " 文档=" + JSON.stringify(doc).length + "B");

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
