import javassist.*;
import java.io.*;

/**
 * 向 CombatLogic.takeNewAdventureReward(ISession,int,int) 的 type==2 分支入口
 * 注入 AdventureRewardGuard.checkAndMark(uid, serverId) 调用。
 *
 * 插入点选在方法开头（iload_2 / iconst_2 / if_icmpeq 之前），
 * 用 $1.getUid() 取 uid；serverId 用 GameApplication.serverId（若不可用则 0）。
 * 只在 type==2 时生效，其它 type 完全不受影响。
 */
public class Inject {
    public static void main(String[] args) throws Exception {
        String jarPath = args[0];
        String outDir  = args[1];

        ClassPool pool = new ClassPool(true);
        pool.insertClassPath(jarPath);
        // 依赖：把 jar 里的 lib 全部加入搜索路径
        if (args.length > 2) {
            for (String cp : args[2].split(File.pathSeparator)) {
                if (cp.trim().isEmpty()) continue;
                pool.insertClassPath(cp.trim());
            }
        }

        CtClass cc = pool.get("com.ljsd.jieling.logic.fight.CombatLogic");
        CtClass sess = pool.get("com.ljsd.jieling.network.session.ISession");

        CtMethod m = null;
        for (CtMethod cm : cc.getDeclaredMethods()) {
            if (cm.getName().equals("takeNewAdventureReward")
                    && cm.getParameterTypes().length == 3
                    && cm.getParameterTypes()[0].getName().equals("com.ljsd.jieling.network.session.ISession")) {
                m = cm;
                break;
            }
        }
        if (m == null) {
            throw new IllegalStateException("takeNewAdventureReward(ISession,int,int) 未找到");
        }
        System.out.println("目标方法: " + m.getSignature());

        // 在方法最开头插入：仅当 type==2 时做频次校验
        String code =
            "{" +
            "  int _t = $2;" +
            "  if (_t == 2) {" +
            "    com.ljsd.jieling.patch.AdventureRewardGuard.checkAndMark($1.getUid(), com.ljsd.GameApplication.serverId);" +
            "  }" +
            "}";
        m.insertBefore(code);
        System.out.println("字节码注入完成");

        File out = new File(outDir);
        out.mkdirs();
        cc.writeFile(outDir);
        cc.detach();
        System.out.println("已输出到: " + outDir);
    }
}
