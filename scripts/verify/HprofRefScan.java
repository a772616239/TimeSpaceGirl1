import java.io.*;
import java.util.*;

/**
 * HPROF 定向引用扫描器（JDK8 兼容，不构建全量对象图）
 *
 * 回答：类 X 的实例，分别被「哪个类的哪个字段」持有？各多少条？
 * 只需保留目标实例 id（排序 long[]），1GB 级 dump 约需 128MB 堆。
 *
 * 用法: java -Xmx384m -cp <dir> HprofRefScan <dump.hprof> <full.ClassName> [topN]
 */
public class HprofRefScan {

    static int idSize = 8;

    static final Map<Long, String> strings = new HashMap<Long, String>();
    static final Map<Long, Long> nameRef = new HashMap<Long, Long>();      // classObjId -> nameStrId
    static final Map<Long, String> className = new HashMap<Long, String>();// classObjId -> 二进制名
    static final Map<Long, Long> superOf = new HashMap<Long, Long>();
    static final Map<Long, long[]> ownFields = new HashMap<Long, long[]>();  // classObjId -> [nameStrId,type]*
    static final Map<Long, Fld[]> layoutCache = new HashMap<Long, Fld[]>();

    static class Fld { final String name; final int type; Fld(String n, int t) { name = n; type = t; } }

    static long targetClassId = -1;
    static String targetClsDot = "";
    static final Map<String, int[]> groups = new HashMap<String, int[]>();
    static int[] perInstance;          // 目标实例 -> 入边数
    static boolean countsOn = false;
    static boolean detailOn = false;
    static final List<String> detail = new ArrayList<String>();

    // ---------- 缓冲读取 ----------
    static byte[] buf = new byte[1 << 23];
    static int pos = 0, lim = 0;
    static long consumed = 0;
    static InputStream in;

    static void open(String f) throws IOException {
        in = new BufferedInputStream(new FileInputStream(f), 1 << 20);
        pos = 0; lim = 0; consumed = 0;
        StringBuilder sb = new StringBuilder(); int ch;
        while ((ch = u1()) != 0) sb.append((char) ch);
        idSize = (int) u4(); skip(8);
    }
    static boolean eof = false;
    static int u1() throws IOException {
        if (pos >= lim) { lim = in.read(buf, 0, buf.length); pos = 0; if (lim <= 0) { eof = true; throw new EOFException(); } }
        consumed++;
        return buf[pos++] & 0xFF;
    }
    static int u2() throws IOException { int a = u1(); int b = u1(); return (a << 8) | b; }
    static long u4() throws IOException { long a = u2(); long b = u2(); return (a << 16) | b; }
    static long id() throws IOException { long v = 0; for (int i = 0; i < idSize; i++) v = (v << 8) | u1(); return v; }
    static void skip(long n) throws IOException {
        while (n > 0) {
            if (pos >= lim) { lim = in.read(buf, 0, buf.length); pos = 0; if (lim <= 0) throw new EOFException(); }
            int take = (int) Math.min(n, lim - pos);
            pos += take; consumed += take; n -= take;
        }
    }
    static String readStr(int len) throws IOException {
        byte[] b = new byte[len]; int off = 0;
        while (off < len) {
            if (pos >= lim) { lim = in.read(buf, 0, buf.length); pos = 0; if (lim <= 0) throw new EOFException(); }
            int take = Math.min(len - off, lim - pos);
            System.arraycopy(buf, pos, b, off, take);
            pos += take; consumed += take; off += take;
        }
        return new String(b, "UTF-8");
    }

    static int sizeOf(int t) {
        switch (t) {
            case 2: return idSize;
            case 4: return 1; case 5: return 2; case 6: return 4; case 7: return 8;
            case 8: return 1; case 9: return 2; case 10: return 4; case 11: return 8;
            default: return 1;
        }
    }

    static Fld[] layout(long classId) {
        Fld[] c = layoutCache.get(classId);
        if (c != null) return c;
        ArrayList<Fld> acc = new ArrayList<Fld>();
        long cur = classId; int guard = 0;
        while (cur != 0 && guard++ < 64) {
            long[] fs = ownFields.get(cur);
            if (fs != null) for (int i = 0; i + 1 < fs.length; i += 2) {
                String nm = strings.get(fs[i]);
                acc.add(new Fld(nm == null ? ("?" + fs[i]) : nm, (int) fs[i + 1]));
            }
            Long s = superOf.get(cur);
            if (s == null) break;
            cur = s;
        }
        c = acc.toArray(new Fld[0]);
        layoutCache.put(classId, c);
        return c;
    }

    static String name2(long cid) {
        String n = className.get(cid);
        return n == null ? ("<class " + cid + ">") : n.replace('/', '.');
    }

    static void hit(String cls, String field) {
        String k = cls + "#" + field;
        int[] c = groups.get(k);
        if (c == null) { c = new int[1]; groups.put(k, c); }
        c[0]++;
    }

    /** 记录某个目标实例被引用了一次 */
    static void hitIdx(int idx) { if (countsOn && idx >= 0) perInstance[idx]++; }

    static void detail(long target, long referrer, String cls, String field) {
        if (detailOn && detail.size() < 400)
            detail.add("  target=" + target + "  <- referrer=" + referrer + "  (" + cls + "#" + field + ")");
    }

    /** 只读 STRING / LOAD_CLASS，其余记录整体跳过 */
    static void passMeta(String f) throws IOException {
        open(f);
        while (true) {
            int tag;
            try { tag = u1(); } catch (EOFException e) { break; }
            u4(); long len = u4();
            if (tag == 0x01) { long sid = id(); strings.put(sid, readStr((int) (len - idSize))); }
            else if (tag == 0x02) { u4(); long cid = id(); u4(); long ns = id(); nameRef.put(cid, ns); }
            else if (tag == 0x2C) break;
            else skip(len);
        }
        in.close();
        for (Map.Entry<Long, Long> e : nameRef.entrySet()) {
            String n = strings.get(e.getValue());
            if (n != null) {
                className.put(e.getKey(), n);
                if (n.replace('/', '.').equals(targetClsDot)) targetClassId = e.getKey();
            }
        }
    }

    /** 目标实例 id 收集 + 类布局构建 */
    static long[] passCollect(String f) throws IOException {
        open(f);
        long[] tb = new long[1 << 20]; int tn = 0;
        while (true) {
            int tag;
            try { tag = u1(); } catch (EOFException e) { break; }
            u4(); long len = u4();
            if (tag == 0x0C || tag == 0x1C) {
                long start = consumed;
                while (consumed - start < len) {
                    int sub = u1();
                    switch (sub) {
                        case 0x20: {
                            long cid = id(); u4(); long sup = id(); id(); id(); id(); id(); id();
                            u4();
                            int cp = u2();
                            for (int i = 0; i < cp; i++) { u2(); int ty = u1(); skip(sizeOf(ty)); }
                            int st = u2();
                            for (int i = 0; i < st; i++) { id(); int ty = u1(); skip(sizeOf(ty)); }
                            int ic = u2();
                            long[] fs = new long[ic * 2];
                            for (int i = 0; i < ic; i++) { fs[i * 2] = id(); fs[i * 2 + 1] = u1(); }
                            ownFields.put(cid, fs); superOf.put(cid, sup);
                            break;
                        }
                        case 0x21: {
                            long oid = id(); u4(); long cid = id(); long nb = u4();
                            if (cid == targetClassId) {
                                if (tn == tb.length) tb = Arrays.copyOf(tb, tn * 2);
                                tb[tn++] = oid;
                            }
                            skip(nb);
                            break;
                        }
                        case 0x22: { id(); u4(); long num = u4(); id(); skip(num * idSize); break; }
                        case 0x23: { id(); u4(); long num = u4(); int ty = u1(); skip(num * sizeOf(ty)); break; }
                        case 0xFE: { u4(); id(); break; }
                        case 0xC3: { id(); u4(); u1(); break; }
                        case 0xFF: case 0x05: case 0x07: case 0x8A: case 0x8B: case 0x8C: case 0x8D: { id(); break; }
                        case 0x01: { id(); id(); break; }
                        case 0x02: case 0x03: case 0x08: case 0x8E: { id(); u4(); u4(); break; }
                        case 0x04: case 0x06: case 0x89: { id(); u4(); break; }
                        default: throw new IOException("unknown subrecord 0x" + Integer.toHexString(sub) + " @" + consumed);
                    }
                }
            } else if (tag == 0x2C) break;
            else skip(len);
        }
        in.close();
        long[] r = Arrays.copyOf(tb, tn);
        Arrays.sort(r);
        return r;
    }

    static void passRefs(String f, long[] T) throws IOException {
        open(f);
        while (true) {
            int tag;
            try { tag = u1(); } catch (EOFException e) { break; }
            u4(); long len = u4();
            if (tag == 0x0C || tag == 0x1C) {
                long start = consumed;
                while (consumed - start < len) {
                    int sub = u1();
                    switch (sub) {
                        case 0x20: {
                            long ccid = id(); u4(); id(); id(); id(); id(); id(); id(); u4();
                            int cp = u2();
                            for (int i = 0; i < cp; i++) { u2(); int ty = u1(); skip(sizeOf(ty)); }
                            int st = u2();
                            String scn = name2(ccid);
                            for (int i = 0; i < st; i++) {
                                long nsid = id(); int ty = u1();
                                if (ty == 2) {
                                    long r = id();
                                    if (r != 0) {
                                        int bi = Arrays.binarySearch(T, r);
                                        if (bi >= 0) {
                                            String fn = "<static>" + strings.get(nsid);
                                            hit(scn, fn); hitIdx(bi); detail(r, ccid, scn, fn);
                                        }
                                    }
                                } else skip(sizeOf(ty));
                            }
                            int ic = u2();
                            for (int i = 0; i < ic; i++) { id(); u1(); }
                            break;
                        }
                        case 0x21: {
                            long oid = id(); u4(); long cid = id(); long nb = u4();
                            Fld[] lay = layout(cid);
                            if (lay == null) { skip(nb); break; }
                            String cn = name2(cid);
                            long used = 0;
                            for (Fld fl : lay) {
                                int sz = sizeOf(fl.type);
                                if (fl.type == 2) {
                                    long r = id();
                                    if (r != 0) { int bi = Arrays.binarySearch(T, r); if (bi >= 0) { hit(cn, fl.name); hitIdx(bi); detail(r, oid, cn, fl.name); } }
                                } else skip(sz);
                                used += sz;
                            }
                            if (nb > used) skip(nb - used);
                            break;
                        }
                        case 0x22: {
                            long aid = id(); u4(); long num = u4(); id();
                            for (long i = 0; i < num; i++) {
                                long r = id();
                                if (r != 0) { int bi = Arrays.binarySearch(T, r); if (bi >= 0) { hit("[objarray]", "[]"); hitIdx(bi); detail(r, aid, "[objarray]", "[]"); } }
                            }
                            break;
                        }
                        case 0x23: { id(); u4(); long num = u4(); int ty = u1(); skip(num * sizeOf(ty)); break; }
                        case 0xFE: { u4(); id(); break; }
                        case 0xC3: { id(); u4(); u1(); break; }
                        case 0xFF: case 0x05: case 0x07: case 0x8A: case 0x8B: case 0x8C: case 0x8D: {
                            long r = id();
                            if (r != 0 && Arrays.binarySearch(T, r) >= 0) hit("[GC_ROOT:0x" + Integer.toHexString(sub) + "]", "-");
                            break;
                        }
                        case 0x01: { id(); long r = id();
                            if (r != 0 && Arrays.binarySearch(T, r) >= 0) hit("[GC_ROOT:JNI_GLOBAL]", "-"); break; }
                        case 0x02: case 0x03: case 0x08: case 0x8E: { long r = id(); u4(); u4();
                            if (r != 0 && Arrays.binarySearch(T, r) >= 0) hit("[GC_ROOT:frame]", "-"); break; }
                        case 0x04: case 0x06: case 0x89: { long r = id(); u4();
                            if (r != 0 && Arrays.binarySearch(T, r) >= 0) hit("[GC_ROOT:native/interned]", "-"); break; }
                        default: throw new IOException("unknown subrecord 0x" + Integer.toHexString(sub));
                    }
                }
            } else if (tag == 0x2C) break;
            else skip(len);
        }
        in.close();
    }

    /** 枚举长度超过 minLen 的对象数组（用于找巨型 map 的 table） */
    static void passBigArrays(String f, int minLen) throws IOException {
        passMeta(f);
        open(f);
        while (true) {
            int tag;
            try { tag = u1(); } catch (EOFException e) { break; }
            u4(); long len = u4();
            if (tag == 0x0C || tag == 0x1C) {
                long start = consumed;
                while (consumed - start < len) {
                    int sub = u1();
                    switch (sub) {
                        case 0x20: {
                            id(); u4(); id(); id(); id(); id(); id(); id(); u4();
                            int cp = u2();
                            for (int i = 0; i < cp; i++) { u2(); int ty = u1(); skip(sizeOf(ty)); }
                            int st = u2();
                            for (int i = 0; i < st; i++) { id(); int ty = u1(); skip(sizeOf(ty)); }
                            int ic = u2();
                            for (int i = 0; i < ic; i++) { id(); u1(); }
                            break;
                        }
                        case 0x21: { id(); u4(); id(); long nb = u4(); skip(nb); break; }
                        case 0x22: {
                            long aid = id(); u4(); long num = u4(); long ec = id();
                            if (num >= minLen) {
                                System.out.println("  arrId=" + aid + "  len=" + num + "  elem=" + name2(ec));
                            }
                            skip(num * idSize);
                            break;
                        }
                        case 0x23: { id(); u4(); long num = u4(); int ty = u1(); skip(num * sizeOf(ty)); break; }
                        case 0xFE: { u4(); id(); break; }
                        case 0xC3: { id(); u4(); u1(); break; }
                        case 0xFF: case 0x05: case 0x07: case 0x8A: case 0x8B: case 0x8C: case 0x8D: { id(); break; }
                        case 0x01: { id(); id(); break; }
                        case 0x02: case 0x03: case 0x08: case 0x8E: { id(); u4(); u4(); break; }
                        case 0x04: case 0x06: case 0x89: { id(); u4(); break; }
                        default: throw new IOException("unknown subrecord 0x" + Integer.toHexString(sub));
                    }
                }
            } else if (tag == 0x2C) break;
            else skip(len);
        }
        in.close();
    }

    static long[] readIds(String f) throws IOException {
        BufferedReader br = new BufferedReader(new FileReader(f));
        ArrayList<Long> v = new ArrayList<Long>();
        String ln;
        while ((ln = br.readLine()) != null) {
            ln = ln.trim();
            if (ln.isEmpty() || ln.startsWith("#")) continue;
            for (String p : ln.split("[,\\s]+")) {
                if (p.isEmpty()) continue;
                v.add(p.toLowerCase().startsWith("0x") ? Long.parseLong(p.substring(2), 16) : Long.parseLong(p));
            }
        }
        br.close();
        long[] r = new long[v.size()];
        for (int i = 0; i < r.length; i++) r[i] = v.get(i);
        return r;
    }

    /** idMode 下只需 CLASS_DUMP 建布局，对象体全部跳过 */
    static void buildLayouts(String f) throws IOException {
        open(f);
        while (true) {
            int tag;
            try { tag = u1(); } catch (EOFException e) { break; }
            u4(); long len = u4();
            if (tag == 0x0C || tag == 0x1C) {
                long start = consumed;
                while (consumed - start < len) {
                    int sub = u1();
                    switch (sub) {
                        case 0x20: {
                            long cid = id(); u4(); long sup = id(); id(); id(); id(); id(); id();
                            u4();
                            int cp = u2();
                            for (int i = 0; i < cp; i++) { u2(); int ty = u1(); skip(sizeOf(ty)); }
                            int st = u2();
                            for (int i = 0; i < st; i++) { id(); int ty = u1(); skip(sizeOf(ty)); }
                            int ic = u2();
                            long[] fs = new long[ic * 2];
                            for (int i = 0; i < ic; i++) { fs[i * 2] = id(); fs[i * 2 + 1] = u1(); }
                            ownFields.put(cid, fs); superOf.put(cid, sup);
                            break;
                        }
                        case 0x21: { id(); u4(); id(); long nb = u4(); skip(nb); break; }
                        case 0x22: { id(); u4(); long num = u4(); id(); skip(num * idSize); break; }
                        case 0x23: { id(); u4(); long num = u4(); int ty = u1(); skip(num * sizeOf(ty)); break; }
                        case 0xFE: { u4(); id(); break; }
                        case 0xC3: { id(); u4(); u1(); break; }
                        case 0xFF: case 0x05: case 0x07: case 0x8A: case 0x8B: case 0x8C: case 0x8D: { id(); break; }
                        case 0x01: { id(); id(); break; }
                        case 0x02: case 0x03: case 0x08: case 0x8E: { id(); u4(); u4(); break; }
                        case 0x04: case 0x06: case 0x89: { id(); u4(); break; }
                        default: throw new IOException("unknown subrecord 0x" + Integer.toHexString(sub));
                    }
                }
            } else if (tag == 0x2C) break;
            else skip(len);
        }
        in.close();
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 2) { System.out.println("usage: HprofRefScan <hprof> <full.ClassName|@ids.txt> [topN]"); return; }
        String hprof = args[0];
        int topN = args.length > 2 ? Integer.parseInt(args[2]) : 25;
        if (args[1].startsWith("@bigarray:")) {
            int minLen = Integer.parseInt(args[1].substring("@bigarray:".length()));
            System.out.println("==== 长度 >= " + minLen + " 的对象数组 ====");
            passBigArrays(hprof, minLen);
            return;
        }
        boolean idMode = args[1].startsWith("@");
        long[] explicit = null;
        if (idMode) {
            explicit = readIds(args[1].substring(1));
        } else {
            targetClsDot = args[1];
        }

        long t0 = System.currentTimeMillis();
        passMeta(hprof);
        System.out.println("[meta] " + (System.currentTimeMillis() - t0) / 1000 + "s  classes=" + className.size()
                + "  targetClassId=" + targetClassId + "  (" + targetClsDot + ")");
        if (!idMode && targetClassId < 0) { System.out.println("!! 目标类未加载"); return; }

        long t1 = System.currentTimeMillis();
        long[] T;
        if (idMode) { T = explicit; Arrays.sort(T); }
        else T = passCollect(hprof);
        // 布局仍需构建（idMode 下 passCollect 未跑）
        if (idMode) buildLayouts(hprof);
        perInstance = new int[T.length]; countsOn = true; detailOn = (T.length <= 64);
        System.out.println("[collect] " + (System.currentTimeMillis() - t1) / 1000 + "s  instances=" + T.length);

        long t2 = System.currentTimeMillis();
        passRefs(hprof, T);
        System.out.println("[refs] " + (System.currentTimeMillis() - t2) / 1000 + "s");

        List<Map.Entry<String, int[]>> es = new ArrayList<Map.Entry<String, int[]>>(groups.entrySet());
        Collections.sort(es, new Comparator<Map.Entry<String, int[]>>() {
            public int compare(Map.Entry<String, int[]> a, Map.Entry<String, int[]> b) {
                return b.getValue()[0] - a.getValue()[0];
            }
        });
        System.out.println();
        System.out.println("==== 谁持有 " + targetClsDot + "（按引用边数） ====");
        System.out.printf("%-10s %s%n", "edges", "referrer#field");
        int shown = 0; long tot = 0;
        for (Map.Entry<String, int[]> e : es) {
            tot += e.getValue()[0];
            if (shown++ < topN) System.out.printf("%-10d %s%n", e.getValue()[0], e.getKey());
        }
        System.out.println("---- 总引用边=" + tot + "  目标实例=" + T.length);

        if (!detail.isEmpty()) {
            System.out.println();
            System.out.println("==== 引用方明细 ====");
            for (String d : detail) System.out.println(d);
        }
        if (T.length > 1) {
            Integer[] idx = new Integer[T.length];
            for (int i = 0; i < idx.length; i++) idx[i] = i;
            Arrays.sort(idx, new Comparator<Integer>() {
                public int compare(Integer a, Integer b) { return perInstance[b] - perInstance[a]; }
            });
            System.out.println();
            System.out.println("==== 入边最多的目标实例 TOP" + Math.min(10, T.length) + " ====");
            for (int i = 0; i < Math.min(10, idx.length); i++) {
                int k = idx[i];
                if (perInstance[k] == 0) break;
                System.out.println("  id=" + T[k] + "  inEdges=" + perInstance[k]);
            }
        }
    }
}
