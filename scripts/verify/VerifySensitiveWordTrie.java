import com.ljsd.jieling.util.SensitiveWordTrie;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;

/**
 * 敏感词 DFA 重构的等价性验证：原 HashMap 树 vs 新 CSR 紧凑树，逐字对拍。
 *
 * 用法: java -Xmx3g -cp <classes> VerifySensitiveWordTrie <mingan.txt>
 */
public class VerifySensitiveWordTrie {

    // ---------------- 原实现（照抄重构前的 SensitiveWordInit / SensitivewordFilter） ----------------
    @SuppressWarnings({"rawtypes", "unchecked"})
    static Map buildLegacy(Set<String> keyWordSet) {
        Map root = new HashMap(keyWordSet.size());
        for (String key : keyWordSet) {
            if (key == null || key.length() == 0) continue;
            Map nowMap = root;
            for (int i = 0; i < key.length(); i++) {
                char keyChar = key.charAt(i);
                Object wordMap = nowMap.get(keyChar);
                if (wordMap != null) {
                    nowMap = (Map) wordMap;
                } else {
                    Map newWorMap = new HashMap();
                    newWorMap.put("isEnd", "0");
                    nowMap.put(keyChar, newWorMap);
                    nowMap = newWorMap;
                }
                if (i == key.length() - 1) nowMap.put("isEnd", "1");
            }
        }
        return root;
    }

    @SuppressWarnings({"rawtypes"})
    static int legacyCheck(Map root, String txt, int beginIndex, int matchType) {
        boolean flag = false;
        int matchFlag = 0;
        Map nowMap = root;
        for (int i = beginIndex; i < txt.length(); i++) {
            char word = txt.charAt(i);
            nowMap = (Map) nowMap.get(word);
            if (nowMap != null) {
                matchFlag++;
                if ("1".equals(nowMap.get("isEnd"))) {
                    flag = true;
                    if (1 == matchType) break;
                }
            } else break;
        }
        if (matchFlag < 1 || !flag) matchFlag = 0;
        return matchFlag;
    }

    // ---------------- 对拍 ----------------
    static int checks = 0, fails = 0;
    static List<String> failSamples = new ArrayList<String>();

    static void cmp(Map legacy, SensitiveWordTrie trie, String txt, String tag) {
        for (int i = 0; i < txt.length(); i++) {
            for (int mt = 1; mt <= 2; mt++) {
                int a = legacyCheck(legacy, txt, i, mt);
                int b = trie.matchLength(txt, i, mt);
                checks++;
                if (a != b) {
                    fails++;
                    if (failSamples.size() < 10) {
                        failSamples.add(tag + " idx=" + i + " matchType=" + mt + " legacy=" + a + " new=" + b
                                + " ctx=[" + safe(txt, i) + "]");
                    }
                }
            }
        }
    }

    static String safe(String s, int i) {
        int a = Math.max(0, i - 6), b = Math.min(s.length(), i + 12);
        return s.substring(a, b);
    }

    public static void main(String[] args) throws Exception {
        String dictPath = args.length > 0 ? args[0] : "mingan.txt";

        // 1) 读词库（与原实现一致：逐行，非空）
        Set<String> words = new LinkedHashSet<String>();
        BufferedReader br = new BufferedReader(new InputStreamReader(new FileInputStream(dictPath), "UTF-8"));
        String line;
        while ((line = br.readLine()) != null) {
            line = line.trim();
            if (line.length() > 0) words.add(line);
        }
        br.close();
        System.out.println("[1] 词库条数 = " + words.size());

        // 2) 建两棵树并测内存
        long base = used();
        long t0 = System.currentTimeMillis();
        Map legacy = buildLegacy(words);
        long tLegacy = System.currentTimeMillis() - t0;
        System.gc(); Thread.sleep(300); System.gc();
        long memLegacy = used() - base;
        System.out.println("[2] 原实现 build=" + tLegacy + "ms  常驻≈" + mb(memLegacy));

        legacy = null;
        System.gc(); Thread.sleep(300); System.gc();
        long base2 = used();

        t0 = System.currentTimeMillis();
        SensitiveWordTrie trie = SensitiveWordTrie.build(words);
        long tTrie = System.currentTimeMillis() - t0;
        System.gc(); Thread.sleep(300); System.gc();
        long memTrie = used() - base2;
        System.out.println("[3] 新实现 build=" + tTrie + "ms  常驻≈" + mb(memTrie)
                + "  nodes=" + trie.nodeCount() + " edges=" + trie.edgeCount()
                + "  (结构估算 " + mb(trie.estimatedBytes()) + ")");

        // 3) 重建 legacy 用于对拍
        legacy = buildLegacy(words);

        // 3.1 每个词本身（index 0 与全位置）
        long t1 = System.currentTimeMillis();
        for (String w : words) cmp(legacy, trie, w, "word");
        System.out.println("[4] 词库自身对拍完成 " + (System.currentTimeMillis() - t1) + "ms  checks=" + checks);

        // 3.2 词与词拼接（制造重叠与最长匹配）
        List<String> list = new ArrayList<String>(words);
        Random rnd = new Random(20261018L);
        for (int i = 0; i < 20000; i++) {
            String a = list.get(rnd.nextInt(list.size()));
            String b = list.get(rnd.nextInt(list.size()));
            cmp(legacy, trie, a + b, "concat");
        }

        // 3.3 词的前缀 / 后缀（应当不命中，验证 isEnd 语义）
        for (int i = 0; i < 20000; i++) {
            String w = list.get(rnd.nextInt(list.size()));
            if (w.length() > 1) cmp(legacy, trie, w.substring(0, w.length() - 1), "prefix");
        }

        // 3.4 干净文本（用词库字符随机拼，长度 8~40）
        StringBuilder pool = new StringBuilder();
        for (int i = 0; i < 5000 && i < list.size(); i++) pool.append(list.get(i));
        for (int i = 0; i < 5000; i++) {
            int len = 8 + rnd.nextInt(33);
            StringBuilder sb = new StringBuilder(len);
            for (int j = 0; j < len; j++) sb.append(pool.charAt(rnd.nextInt(pool.length())));
            cmp(legacy, trie, sb.toString(), "random");
        }

        // 3.5 边界：空串 / 单字符 / 非常长串
        cmp(legacy, trie, "", "empty");
        cmp(legacy, trie, "a", "one");
        StringBuilder longTxt = new StringBuilder();
        for (int i = 0; i < 300; i++) longTxt.append(list.get(rnd.nextInt(list.size())));
        cmp(legacy, trie, longTxt.toString(), "long");

        System.out.println("[5] 总对拍次数 = " + checks + "  不一致 = " + fails);
        if (!failSamples.isEmpty()) {
            System.out.println("---- 差异样例 ----");
            for (String s : failSamples) System.out.println("  " + s);
        }

        // 4) 顺带验证查询性能（同一批文本）
        String sample = longTxt.toString();
        long s1 = System.nanoTime();
        for (int r = 0; r < 200; r++) legacyCheck(legacy, sample, 0, 1);
        long legacyNs = System.nanoTime() - s1;
        long s2 = System.nanoTime();
        for (int r = 0; r < 200; r++) trie.matchLength(sample, 0, 1);
        long trieNs = System.nanoTime() - s2;
        System.out.println("[6] 单点匹配 x200 (len=" + sample.length() + "): 旧=" + (legacyNs / 1000000)
                + "ms  新=" + (trieNs / 1000000) + "ms");

        System.out.println(fails == 0 ? "\n==== PASS：新实现与原实现完全等价 ====" : "\n==== FAIL ====");
        if (fails != 0) System.exit(1);
    }

    static long used() {
        Runtime r = Runtime.getRuntime();
        return r.totalMemory() - r.freeMemory();
    }

    static String mb(long b) {
        return String.format("%.1fMB", b / 1048576.0);
    }
}
