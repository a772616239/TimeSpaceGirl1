import com.mongodb.BasicDBList;
import org.bson.BasicBSONEncoder;
import com.mongodb.BasicDBObject;
import com.mongodb.DBObject;
import com.mongodb.DBRef;
import com.ljsd.jieling.db.mongo.MongoBitSetConverter;
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
import java.util.BitSet;
import java.util.List;

public class VerifyBitSetBasic {

    /** 模拟 AbstractMissionType 的字段声明 */
    public static class Holder {
        private BitSet rewardedMissionIds = new BitSet(1024);
        public BitSet getRewardedMissionIds() { return rewardedMissionIds; }
        public void setRewardedMissionIds(BitSet v) { this.rewardedMissionIds = v; }
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

        // ---------- 1. 写路径：BitSet -> BSON ----------
        BitSet bs = new BitSet(1024);
        bs.set(3200001);
        Holder h = new Holder();
        h.setRewardedMissionIds(bs);

        BasicDBObject out = new BasicDBObject();
        conv.write(h, out);
        System.out.println("[1] write 输出 = " + out);
        Object stored = out.get("rewardedMissionIds");
        System.out.println("    stored 类型 = " + (stored == null ? "null" : stored.getClass().getName()));
        System.out.println("    stored 值   = " + stored);
        int bsonSize = new BasicBSONEncoder().encode(out).length;
        System.out.println("    BSON 字节   = " + bsonSize);
        if ("3200001".equals(String.valueOf(stored))) {
            System.out.println("    RESULT: PASS (已写成稀疏字符串)");
        } else {
            System.out.println("    RESULT: FAIL (转换器未生效)");
            fail++;
        }

        // ---------- 2. 读路径：新格式 String -> BitSet ----------
        BasicDBObject newDoc = new BasicDBObject();
        newDoc.put("rewardedMissionIds", "3200001,2000005");
        Holder back = conv.read(Holder.class, newDoc);
        BitSet got = back.getRewardedMissionIds();
        System.out.println("\n[2] read 新格式 -> " + got + "  cardinality=" + got.cardinality());
        if (got.get(3200001) && got.get(2000005) && got.cardinality() == 2) {
            System.out.println("    RESULT: PASS");
        } else {
            System.out.println("    RESULT: FAIL");
            fail++;
        }

        // ---------- 3. 读路径：旧格式 {words, wordsInUse} -> BitSet ----------
        // 还原线上真实形态：words 长 50001，只有 word[50000]=2 （对应 bit 3200001）
        BasicDBList words = new BasicDBList();
        for (int i = 0; i < 50000; i++) {
            words.add(0L);
        }
        words.add(2L);
        BasicDBObject legacy = new BasicDBObject();
        legacy.put("words", words);
        legacy.put("wordsInUse", 50001);
        legacy.put("sizeIsSticky", false);
        System.out.println("\n[3] 旧格式 words 长度 = " + words.size() + "  旧 BSON 字节 = " + new BasicBSONEncoder().encode(legacy).length);

        BasicDBObject legacyDoc = new BasicDBObject();
        legacyDoc.put("rewardedMissionIds", legacy);
        Holder legacyBack = conv.read(Holder.class, legacyDoc);
        BitSet legacyGot = legacyBack.getRewardedMissionIds();
        System.out.println("    read 旧格式 -> " + legacyGot + "  cardinality=" + legacyGot.cardinality());
        if (legacyGot.get(3200001) && legacyGot.cardinality() == 1) {
            System.out.println("    RESULT: PASS (旧数据可读，不会丢已领奖状态)");
        } else {
            System.out.println("    RESULT: FAIL (旧数据读取异常)");
            fail++;
        }

        // ---------- 4. 空集合 ----------
        Holder empty = new Holder();
        empty.setRewardedMissionIds(new BitSet());
        BasicDBObject emptyOut = new BasicDBObject();
        conv.write(empty, emptyOut);
        Object emptyStored = emptyOut.get("rewardedMissionIds");
        System.out.println("\n[4] 空集合 write -> [" + emptyStored + "]  字节=" + new BasicBSONEncoder().encode(emptyOut).length);
        if (emptyStored instanceof String && ((String) emptyStored).isEmpty()) {
            System.out.println("    RESULT: PASS");
        } else {
            System.out.println("    RESULT: FAIL");
            fail++;
        }

        // ---------- 5. 写读往返 ----------
        Holder rt = conv.read(Holder.class, out);
        System.out.println("\n[5] 往返 cardinality=" + rt.getRewardedMissionIds().cardinality()
                + " get(3200001)=" + rt.getRewardedMissionIds().get(3200001));
        if (rt.getRewardedMissionIds().cardinality() == 1 && rt.getRewardedMissionIds().get(3200001)) {
            System.out.println("    RESULT: PASS");
        } else {
            System.out.println("    RESULT: FAIL");
            fail++;
        }

        // ---------- 6. 体积对比 ----------
        System.out.println("\n[6] 体积对比");
        System.out.println("    旧形态 BSON 字段 = " + new BasicBSONEncoder().encode(legacy).length + " 字节");
        System.out.println("    新形态 BSON 字段 = " + new BasicBSONEncoder().encode(new BasicDBObject("rewardedMissionIds", "3200001")).length + " 字节");

        // ---------- 7. 增量更新路径：convertToMongoType(BitSet) 单参 ----------
        // LjsdMongoTemplate.updateMongoData:202 用的就是这个入口
        Object inc = conv.convertToMongoType(bs);
        System.out.println("\n[7] convertToMongoType(bitSet) -> " + inc
                + "  类型=" + (inc == null ? "null" : inc.getClass().getName()));
        if ("3200001".equals(String.valueOf(inc))) {
            System.out.println("    RESULT: PASS (增量更新路径同样走稀疏字符串)");
        } else {
            System.out.println("    RESULT: FAIL (增量更新会写回旧格式)");
            fail++;
        }

        // ---------- 8. 增量更新读回 ----------
        Holder incBack = conv.read(Holder.class, new BasicDBObject("rewardedMissionIds", inc));
        if (incBack.getRewardedMissionIds().cardinality() == 1 && incBack.getRewardedMissionIds().get(3200001)) {
            System.out.println("[8] 增量值可读回  RESULT: PASS");
        } else {
            System.out.println("[8] 增量值读回失败  RESULT: FAIL -> " + incBack.getRewardedMissionIds());
            fail++;
        }

        System.out.println("\n================ FAIL COUNT = " + fail + " ================");
        if (fail > 0) {
            System.exit(1);
        }
    }
}
