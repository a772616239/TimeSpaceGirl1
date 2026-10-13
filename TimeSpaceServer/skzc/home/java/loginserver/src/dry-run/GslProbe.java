/*
 * GetServerListController 离线 dry-run 探针
 *
 * 用途：不启动 Tomcat，直接把 HttpServletRequest / HttpServletResponse 用动态代理 mock 出来，
 *      调用真实的 doGet 实现，拿到完整 JSON 响应体，用于「原版 vs 补丁版」的输出比对。
 *
 * 安全性：整条链路**只读** —— Mongo 只 find，Redis 只 get / hgetAll，
 *        不产生任何写操作（未调用过 MyMongoDBPool 的写方法，也未触发 Redis 写命令）。
 *
 * 用法：
 *   java -Dfile.encoding=UTF-8 -cp <harness>:<classes>:<lib/*> GslProbe \
 *        <application.properties 路径> <openId> <channel> <sub_channel> <plat> <server_version> \
 *        [JSON 输出文件路径]
 *   （强烈建议给第 7 个参数：stdout 会被 logback / NetUtil 的日志污染）
 */
import com.ljsd.controller.GetServerListController;
import com.ljsd.util.BaseGlobal;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

public class GslProbe {

    private static Object defaultOf(Class<?> type) {
        if (!type.isPrimitive()) {
            return null;
        }
        if (type == boolean.class) return Boolean.FALSE;
        if (type == char.class) return (char) 0;
        if (type == byte.class) return (byte) 0;
        if (type == short.class) return (short) 0;
        if (type == int.class) return 0;
        if (type == long.class) return 0L;
        if (type == float.class) return 0f;
        if (type == double.class) return 0d;
        return null;
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 6) {
            System.err.println("用法: GslProbe <properties> <openId> <channel> <sub_channel> <plat> <server_version>");
            System.exit(2);
        }
        final Map<String, String> params = new HashMap<String, String>();
        params.put("openId", args[1]);
        params.put("channel", args[2]);
        params.put("sub_channel", args[3]);
        params.put("plat", args[4]);
        params.put("server_version", args[5]);

        // 与 WebContextListener 完全一致的初始化路径（Linux 分支）
        try (InputStream in = new FileInputStream(args[0])) {
            BaseGlobal.getInstance().properties.load(in);
        }
        BaseGlobal.getInstance().init();

        HttpServletRequest request = (HttpServletRequest) Proxy.newProxyInstance(
                GslProbe.class.getClassLoader(),
                new Class<?>[] { HttpServletRequest.class },
                new InvocationHandler() {
                    public Object invoke(Object proxy, Method m, Object[] a) {
                        String n = m.getName();
                        if ("getParameter".equals(n)) {
                            return params.get((String) a[0]);
                        }
                        if ("getHeader".equals(n)) {
                            return null;
                        }
                        if ("getRemoteAddr".equals(n)) {
                            return "127.0.0.1";
                        }
                        if ("toString".equals(n)) {
                            return "mock-request";
                        }
                        if ("hashCode".equals(n)) {
                            return System.identityHashCode(proxy);
                        }
                        if ("equals".equals(n)) {
                            return proxy == a[0];
                        }
                        return defaultOf(m.getReturnType());
                    }
                });

        final StringWriter body = new StringWriter();
        final PrintWriter writer = new PrintWriter(body);
        HttpServletResponse response = (HttpServletResponse) Proxy.newProxyInstance(
                GslProbe.class.getClassLoader(),
                new Class<?>[] { HttpServletResponse.class },
                new InvocationHandler() {
                    public Object invoke(Object proxy, Method m, Object[] a) {
                        String n = m.getName();
                        if ("getWriter".equals(n)) {
                            return writer;
                        }
                        if ("sendError".equals(n)) {
                            System.err.println("!! sendError " + Arrays.toString(a));
                            return null;
                        }
                        if ("toString".equals(n)) {
                            return "mock-response";
                        }
                        if ("hashCode".equals(n)) {
                            return System.identityHashCode(proxy);
                        }
                        if ("equals".equals(n)) {
                            return proxy == a[0];
                        }
                        return defaultOf(m.getReturnType());
                    }
                });

        // 打印实际加载到的类位置，确保原版/补丁版确实换了实现
        System.err.println("GetServerListController <= "
                + GetServerListController.class.getProtectionDomain().getCodeSource().getLocation());

        new GetServerListController().doGet(request, response);
        writer.flush();

        // 不能用 stdout 传 JSON —— logback 与 NetUtil 都会往 stdout 打日志，会污染响应体。
        // 第 7 个参数给输出文件路径时写文件；否则用显式标记包起来，便于调用方精确截取。
        if (args.length >= 7) {
            java.io.OutputStream os = new java.io.FileOutputStream(args[6]);
            try {
                os.write(body.toString().getBytes("UTF-8"));
            } finally {
                os.close();
            }
            System.out.println("JSON_WRITTEN_TO=" + args[6]);
        } else {
            System.out.println("<<<JSON_BEGIN>>>" + body.toString() + "<<<JSON_END>>>");
        }
    }
}
