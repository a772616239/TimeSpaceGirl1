// migrate_rewarded_mission_bitset.js
// 用途：把 user 文档里「被 Spring 当 POJO 展开写进 BSON 的 java.util.BitSet」
//      批量压成「逗号分隔的置位下标字符串」。
//
// 背景（2026-10-18 巡检实测）：
//   AbstractMissionType.java:21  private BitSet rewardedMissionIds = new BitSet(1024);
//   AbstractMissionType.java:32  rewardedMissionIds.set(missionId);   // 直接拿 missionId 当 bit 下标
//   而 missionId 是 200 万~320 万量级，于是 words 数组被撑到 5 万~10 万个 long，
//   单玩家单字段落库 1.5MB，而全服 208 人真正记录过的 id 合计只有 5,958 个。
//
// 新存储形态：rewardedMissionIds: "3200001,2000005"   （空集合 → ""）
//   由 com.ljsd.jieling.db.mongo.MongoBitSetConverter 负责双向转换。
//
// ⚠️ 顺序要求（重要）：
//   1) 先备份：mongodump -u <u> -p <p> --authenticationDatabase admin -d m5_x1_game_10001 -o /data/backup/
//   2) 先上新 jar（含 MongoBitSetConverter，能同时读旧 BitSet 和 新字符串）
//   3) 再跑本脚本
//   反了会出问题：旧 jar 没有转换器，读到字符串形态会把已领奖状态读成空 → 玩家可重复领奖。
//
// ⚠️ 本脚本不是必需的：新 jar 读到旧格式会自动还原，玩家下次存档就写成新格式。
//   跑它的意义是「不等玩家上线，一次性把这 18MB 释放掉」。

var APPLY = false;                 // ← 改成 true 才真正写库
var COLL = "user";
var TOP_FIELDS = ["userMissionManager", "activityManager"];   // 在这几个 manager 下深搜
var BACKUP_COLL = "user_bitset_backup_20261018";
var BACKUP_FLAG = "__bitsetValue";                            // 备份文档里存放原值的键

// 判定「这是不是一个 BitSet 被当成 POJO 序列化的产物」
function isSerializedBitSet(o) {
    return o && typeof o === "object" && !Array.isArray(o) &&
           o.words && Object.prototype.toString.call(o.words) === "[object Array]" &&
           ("wordsInUse" in o);
}

// BitSet 的 words[] + wordsInUse 还原出所有置位的 bit 下标
function decodeBitSet(doc) {
    var out = [];
    var words = doc.words;
    // 只解码到 wordsInUse，避免把数组尾部的垃圾当成数据
    var use = (typeof doc.wordsInUse === "number") ? doc.wordsInUse : words.length;
    if (use > words.length) use = words.length;
    for (var i = 0; i < use; i++) {
        var raw = words[i];
        var v = (raw && typeof raw.valueOf === "function") ? raw.valueOf() : raw;
        v = Number(v);
        if (!v) continue;
        for (var b = 0; b < 64; b++) {
            if (v % 2 !== 0) out.push(i * 64 + b);
            v = Math.floor(v / 2);
            if (v === 0) break;
        }
    }
    return out;
}

// 深度遍历，收集所有待替换路径
function walk(node, path, found) {
    if (!node || typeof node !== "object" || Array.isArray(node)) return;
    if (isSerializedBitSet(node)) {
        found.push({path: path.join("."), ids: decodeBitSet(node), kb: bsonsize({x: node}) / 1024});
        return;
    }
    for (var k in node) {
        if (!Object.prototype.hasOwnProperty.call(node, k)) continue;
        walk(node[k], path.concat([k]), found);
    }
}

var stats = {users: 0, fieldsTouched: 0, idsTotal: 0, kbBefore: 0, kbAfter: 0};
var byType = {};
var detail = [];
var toWrite = [];
var backup = [];

db.getCollection(COLL).find({}).forEach(function (u) {
    stats.users++;
    var found = [];
    TOP_FIELDS.forEach(function (f) {
        if (u[f]) walk(u[f], [f], found);
    });
    if (!found.length) return;

    var patch = {};
    var keep = {};
    found.forEach(function (item) {
        var encoded = item.ids.join(",");
        var kbAfter = bsonsize({x: encoded}) / 1024;
        stats.fieldsTouched++;
        stats.idsTotal += item.ids.length;
        stats.kbBefore += item.kb;
        stats.kbAfter += kbAfter;

        var leaf = item.path.split(".").pop();
        byType[leaf] = (byType[leaf] || 0) + 1;

        if (item.kb > 1 || item.ids.length > 3) {
            detail.push("uid=" + u._id + "  " + item.path +
                        "  bits=" + item.ids.length +
                        "  ids=[" + item.ids.slice(0, 6).join(",") + (item.ids.length > 6 ? ",..." : "") + "]" +
                        "  " + item.kb.toFixed(1) + "KB -> " + kbAfter.toFixed(3) + "KB");
        }
        patch[item.path] = encoded;
        keep[item.path] = item.ids;
    });
    toWrite.push({_id: u._id, $set: patch});
    // 备份只留 id 数组（足够还原），不留原始 850KB 位图
    var b = {uid: u._id, backupTime: new Date()};
    b[BACKUP_FLAG] = keep;
    backup.push(b);
});

print("==== " + (APPLY ? "APPLY" : "DRY RUN") + " 报告 ====");
print("玩家数            = " + stats.users);
print("受影响字段数      = " + stats.fieldsTouched);
print("解码出的 id 总数  = " + stats.idsTotal);
print("迁移前体积        = " + (stats.kbBefore / 1024).toFixed(2) + " MB");
print("迁移后体积        = " + (stats.kbAfter / 1024).toFixed(4) + " MB");
print("预计释放          = " + ((stats.kbBefore - stats.kbAfter) / 1024).toFixed(2) + " MB");
print("");
print("---- 按字段名分布 ----");
var bt = [];
for (var k in byType) bt.push([k, byType[k]]);
bt.sort(function (a, b) { return b[1] - a[1]; });
bt.forEach(function (x) { print("  " + x[1] + "\t" + x[0]); });
print("");
print("---- 体积 >1KB 或 bit 数 >3 的字段（前 15 条） ----");
detail.slice(0, 15).forEach(function (d) { print("  " + d); });
if (detail.length > 15) print("  ... 其余 " + (detail.length - 15) + " 条");

if (!APPLY) {
    print("");
    print(">>> 当前为 DRY RUN，未写入任何数据。设置 APPLY=true 后重跑才会落库。");
} else {
    print("");
    print(">>> APPLY=true，开始写入（先备份到 " + BACKUP_COLL + "）");
    // 1) 备份可还原的 id 列表
    backup.forEach(function (b) {
        db.getCollection(BACKUP_COLL).updateOne(
            {_id: b.uid},
            {$set: b},
            {upsert: true}
        );
    });
    // 2) 落库
    var n = 0;
    toWrite.forEach(function (w) {
        db.getCollection(COLL).updateOne({_id: w._id}, {$set: w.$set});
        n++;
    });
    print(">>> 已迁移 " + n + " 个玩家文档；原 id 列表备份于 " + BACKUP_COLL);
}
