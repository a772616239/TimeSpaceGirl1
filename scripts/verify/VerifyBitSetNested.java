import com.mongodb.BasicDBList;
import com.mongodb.BasicDBObject;
import com.mongodb.DBObject;
import com.mongodb.DBRef;
import com.ljsd.jieling.db.mongo.MongoBitSetConverter;
import org.bson.BasicBSONEncoder;
import org.springframework.core.convert.converter.Converter;
import org.springframework.data.mongodb.core.convert.CustomConversions;
import org.springframework.data.mongodb.core.convert.DbRefResolver;
import org.springframework.data.mongodb.core.convert.DbRefResolverCallback;
import org.springframework.data.mongodb.core.convert.DbRefProxyHandler;
import org.springframework.data.mongodb.core.convert.DefaultMongoTypeMapper;
import org.springframework.data.mongodb.core.convert.MappingMongoConverter;
import org.springframework.data.mongodb.core.mapping.MongoMappingContext;
import org.springframework.data.mongodb.core.mapping.MongoPersistentEntity;
import org.springframework.data.mongodb.core.mapping.MongoPersistentProperty;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.BitSet;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 复刻真实线上的对象层级（User -> UserMissionManager -> JadeDynastyMissionType extends AbstractMissionType），
 * 验证 BitSet 转换在「整体对象展开」和「整体对象读回」两条路径上都正确。
 */
public class VerifyBitSetNested {

    // 等价于 AbstractMissionType（字段在父类里）
    public static abstract class AbstractMissionType {
        private Set<Integer> doingMissionIds = new HashSet<Integer>();
        private Set<Integer> finishMissionIds = new HashSet<Integer>();
        private BitSet rewardedMissionIds = new BitSet(1024);

        public Set<Integer> getDoingMissionIds() { return doingMissionIds; }
        public void setDoingMissionIds(Set<Integer> v) { this.doingMissionIds = v; }
        public Set<Integer> getFinishMissionIds() { return finishMissionIds; }
        public void setFinishMissionIds(Set<Integer> v) { this.finishMissionIds = v; }
        public BitSet getRewardedMissionIds() { return rewardedMissionIds; }
        public void setRewardedMissionIds(BitSet v) { this.rewardedMissionIds = v; }
    }

    // 等价于 JadeDynastyMissionType
    public static class JadeDynastyMissionType extends AbstractMissionType {
        private int lastRefreshDay;
        public int getLastRefreshDay() { return lastRefreshDay; }
        public void setLastRefreshDay(int v) { this.lastRefreshDay = v; }
    }

    // 等价于 UserMissionManager
    public static class UserMissionManager {
        private JadeDynastyMissionType jadeDynastyMissionType = new JadeDynastyMissionType();
        public JadeDynastyMissionType getJadeDynastyMissionType() { return jadeDynastyMissionType; }
        public void setJadeDynastyMissionType(JadeDynastyMissionType v) { this.jadeDynastyMissionType = v; }
    }

    // 等价于 User
    public static class User {
        private long _id;
        private UserMissionManager userMissionManager = new UserMissionManager();
        public long get_id() { return _id; }
        public void set_id(long v) { this._id = v; }
        public UserMissionManager getUserMissionManager() { return userMissionManager; }
        public void setUserMissionManager(UserMissionManager v) { this.userMissionManager = v; }
    }

    static MappingMongoConverter buildConverter() throws Exception {
        MongoMappingContext ctx = new MongoMappingContext();
        ctx.afterPropertiesSet();
        DbRefResolver noop = new DbRefResolver() {
            public Object resolveDbRef(MongoPersistentProperty p, DBRef r, DbRefResolverCallback cb, DbRefProxyHandler h) { return null; }
            public DBRef createDbRef(org.springframework.data.mongodb.core.mapping.DBRef ann, MongoPersistentEntity<?> e, Object t) { return null; }
            public DBObject fetch(DBRef r) { return null; }
            public List<DBObject> bulkFetch(List<DBRef> r) { return new ArrayList<DBObject>(); }
        };
        MappingMongoConverter conv = new MappingMongoConverter(noop, ctx);
        conv.setTypeMapper(new DefaultMongoTypeMapper(null));
        List<Converter<?, ?>> list = new ArrayList<Converter<?, ?>>();
        list.add(new MongoBitSetConverter.BitSetToString());
        list.add(new MongoBitSetConverter.StringToBitSet());
        list.add(new MongoBitSetConverter.LegacyToBitSet());
        conv.setCustomConversions(new CustomConversions(list));
        conv.afterPropertiesSet();
        return conv;
    }

    public static void main(String[] args) throws Exception {
        MappingMongoConverter conv = buildConverter();
        int fail = 0;

        // 构造真实形态：jade 只有 3200001 一个已领奖，doing 里有 2 个
        User u = new User();
        u.set_id(10000002L);
        JadeDynastyMissionType jade = u.getUserMissionManager().getJadeDynastyMissionType();
        jade.getRewardedMissionIds().set(3200001);
        jade.getDoingMissionIds().addAll(Arrays.asList(3200002, 3200003));

        // ---------- A. 全量存档路径：converter.write(整个 User) ----------
        BasicDBObject doc = new BasicDBObject();
        conv.write(u, doc);
        Object field = ((DBObject) ((DBObject) doc.get("userMissionManager")).get("jadeDynastyMissionType")).get("rewardedMissionIds");
        int size = new BasicBSONEncoder().encode(doc).length;
        System.out.println("[A] 全量 write(User) 的 rewardedMissionIds = " + field
                + " (" + (field == null ? "null" : field.getClass().getSimpleName()) + ")");
        System.out.println("    整个 User BSON = " + size + " 字节");
        if ("3200001".equals(String.valueOf(field))) {
            System.out.println("    RESULT: PASS");
        } else { System.out.println("    RESULT: FAIL"); fail++; }

        // ---------- B. 增量更新路径：convertToMongoType(整个 mission 对象) ----------
        // 对应 LjsdMongoTemplate.updateMongoData:202
        Object inc = conv.convertToMongoType(jade);
        Object incField = ((DBObject) inc).get("rewardedMissionIds");
        System.out.println("\n[B] convertToMongoType(jadeMissionType) 的 rewardedMissionIds = " + incField
                + " (" + (incField == null ? "null" : incField.getClass().getSimpleName()) + ")");
        if ("3200001".equals(String.valueOf(incField))) {
            System.out.println("    RESULT: PASS (领奖后的增量 $set 也写稀疏串)");
        } else { System.out.println("    RESULT: FAIL"); fail++; }

        // ---------- C. 读新格式整档 ----------
        User r1 = conv.read(User.class, doc);
        BitSet b1 = r1.getUserMissionManager().getJadeDynastyMissionType().getRewardedMissionIds();
        System.out.println("\n[C] 读新格式整档 -> " + b1 + "  doing="
                + r1.getUserMissionManager().getJadeDynastyMissionType().getDoingMissionIds());
        if (b1.cardinality() == 1 && b1.get(3200001)) {
            System.out.println("    RESULT: PASS");
        } else { System.out.println("    RESULT: FAIL"); fail++; }

        // ---------- D. 读旧格式整档（线上现状：18MB 的 words 位图） ----------
        BasicDBList words = new BasicDBList();
        for (int i = 0; i < 50000; i++) { words.add(0L); }
        words.add(2L);   // word[50000] = 2 -> bit 3200001
        BasicDBObject legacyBitset = new BasicDBObject();
        legacyBitset.put("words", words);
        legacyBitset.put("wordsInUse", 50001);
        legacyBitset.put("sizeIsSticky", false);

        BasicDBObject jadeDoc = new BasicDBObject();
        jadeDoc.put("rewardedMissionIds", legacyBitset);
        BasicDBList doing = new BasicDBList();
        doing.add(3200002);
        doing.add(3200003);
        jadeDoc.put("doingMissionIds", doing);
        jadeDoc.put("finishMissionIds", new BasicDBList());
        jadeDoc.put("lastRefreshDay", 0);

        BasicDBObject umDoc = new BasicDBObject();
        umDoc.put("jadeDynastyMissionType", jadeDoc);
        BasicDBObject fullDoc = new BasicDBObject();
        fullDoc.put("_id", 10000002L);
        fullDoc.put("userMissionManager", umDoc);

        System.out.println("\n[D] 旧格式整档 BSON = " + new BasicBSONEncoder().encode(fullDoc).length + " 字节");
        User r2 = conv.read(User.class, fullDoc);
        BitSet b2 = r2.getUserMissionManager().getJadeDynastyMissionType().getRewardedMissionIds();
        System.out.println("    读出 -> " + b2 + "  cardinality=" + b2.cardinality());
        if (b2.cardinality() == 1 && b2.get(3200001)) {
            System.out.println("    RESULT: PASS (新 jar 直接读线上旧数据，状态不丢)");
        } else { System.out.println("    RESULT: FAIL (读旧数据丢状态)"); fail++; }

        // ---------- E. 旧数据读完再写回，应自动收敛成新格式 ----------
        BasicDBObject rewritten = new BasicDBObject();
        conv.write(r2, rewritten);
        Object rewField = ((DBObject) ((DBObject) rewritten.get("userMissionManager")).get("jadeDynastyMissionType")).get("rewardedMissionIds");
        System.out.println("\n[E] 旧数据读入再存回 -> rewardedMissionIds = " + rewField
                + "  BSON=" + new BasicBSONEncoder().encode(rewritten).length + " 字节");
        if ("3200001".equals(String.valueOf(rewField))) {
            System.out.println("    RESULT: PASS (玩家上线一次即自动转新格式)");
        } else { System.out.println("    RESULT: FAIL"); fail++; }

        System.out.println("\n================ FAIL COUNT = " + fail + " ================");
        if (fail > 0) { System.exit(1); }
    }
}
