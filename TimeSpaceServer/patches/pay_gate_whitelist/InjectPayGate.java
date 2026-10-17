import javassist.*;
import java.io.*;

/**
 * 把 TestBuyGiftGoodsHandler.process() 的 debug 硬门禁替换成 PayGateGuard 白名单门禁。
 *
 * 原始字节码（仓库 jar 与线上 jar 完全一致，已逐条 diff 校验）：
 * <pre>
 *   0: getstatic   GameApplication.serverProperties
 *   3: invokevirtual ServerProperties.isDebug()Z
 *   6: ifne   19
 *   9: new     ErrorCodeException
 *  12: dup
 *  13: ldc     "In a formal setting"
 *  15: invokespecial ErrorCodeException.<init>(String)
 *  18: athrow
 *  19: aload_2                        ← 原方法体真正的逻辑从这里开始（共 43 字节）
 *      parseClientProtoNetData → parseFrom → testBuyGoods(session, goodsId, channel) → return
 * </pre>
 *
 * 做法：<b>只删掉 0~18 这 19 个字节的门禁</b>，原方法体 19 之后逐条保留，
 * 在方法最前面改为调用 PayGateGuard.check(...)。这样业务语义零改动。
 *
 * 为什么用 setBody 重写而不是 insertBefore：
 * insertBefore 只能在最前面插入，原 athrow 门禁仍然在，照样全拦；
 * Javassist 也没有「删除方法体中间一段」的公开 API。
 * 因此按原字节码逐条重写成等价 Java 源码（已用 javap 核对每条指令语义），
 * 没有任何额外分支或副作用。
 */
public class InjectPayGate {

    private static final String HANDLER = "com.ljsd.jieling.handler.store.TestBuyGiftGoodsHandler";

    public static void main(String[] args) throws Exception {
        String jarPath = args[0];
        String outDir = args[1];

        ClassPool pool = new ClassPool(true);
        pool.insertClassPath(jarPath);
        if (args.length > 2) {
            for (String cp : args[2].split(File.pathSeparator)) {
                if (!cp.trim().isEmpty()) {
                    pool.insertClassPath(cp.trim());
                }
            }
        }

        CtClass cc = pool.get(HANDLER);

        CtMethod m = null;
        for (CtMethod cm : cc.getDeclaredMethods()) {
            if (cm.getName().equals("process") && cm.getParameterTypes().length == 2) {
                m = cm;
                break;
            }
        }
        if (m == null) {
            throw new IllegalStateException("process(ISession, PacketNetData) 未找到");
        }
        System.out.println("目标方法: " + m.getSignature());
        System.out.println("原方法体字节数: " + m.getMethodInfo().getCodeAttribute().getCodeLength());

        // 与原字节码逐条等价的重写：
        //   19: aload_2 → parseClientProtoNetData()
        //   23: invokestatic TestBuyGiftGoodsRequest.parseFrom([B)
        //   27: astore_3
        //   29..39: testBuyGoods($1, String.valueOf(req.getGoodsId()), req.getChannel())
        //   42: return
        // 唯一新增：在 testBuyGoods 之前插入 PayGateGuard.check(uid, goodsId, channel)。
        // parseClientProtoNetData() 是纯 arraycopy（无副作用），故这里复用同一份字节，
        // 不会出现「二次解析读空」问题。
        String body =
                "{" +
                "  byte[] _data = $2.parseClientProtoNetData();" +
                "  com.ljsd.jieling.protocols.PlayerInfoProto$TestBuyGiftGoodsRequest _req = " +
                "      com.ljsd.jieling.protocols.PlayerInfoProto$TestBuyGiftGoodsRequest.parseFrom(_data);" +
                "  com.ljsd.jieling.patch.PayGateGuard.check(" +
                "      $1.getUid(), _req.getGoodsId(), _req.getChannel());" +
                "  com.ljsd.jieling.logic.store.BuyGoodsLogic.testBuyGoods(" +
                "      $1, java.lang.String.valueOf(_req.getGoodsId()), _req.getChannel());" +
                "}";

        m.setBody(body);
        System.out.println("重写完成：debug 硬门禁 → PayGateGuard 白名单门禁");

        File out = new File(outDir);
        out.mkdirs();
        cc.writeFile(outDir);
        cc.detach();
        System.out.println("已输出到: " + outDir);
    }
}
