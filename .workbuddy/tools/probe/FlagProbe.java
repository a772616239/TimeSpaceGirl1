import com.ljsd.jieling.netty.cocdex.Tea;
import com.ljsd.jieling.protocols.MessageTypeProto;
import com.ljsd.jieling.protocols.PlayerInfoProto;

import java.io.DataInputStream;
import java.io.OutputStream;
import java.net.Socket;

/**
 * 游戏服协议探针（无 UI、无客户端，直接说二进制协议）。
 *
 * 用途：验证「别人看我的国旗」这条链路端到端是否真的把 country 发出去了。
 * 走的是和真客户端完全相同的封包/鉴权路径，所以结论等价于真机。
 *
 * 封包格式（从 GameSession / TeaDecoder / MessageUtil 反推）：
 *   客户端 -> 服务端 : [2B 明文长度][TEA(align8(明文))]
 *                      明文 = uid(4) token(4) msgId(4) index(4) body
 *   服务端 -> 客户端 : [4B 明文长度][TEA(align8(明文))]
 *                      明文 = uid(4) token(4) msgId(4) index(4) result(4) body
 *
 * 用法：
 *   java FlagProbe <本机uid> <token> <目标uid>
 * token 从 redis 取：redis-cli get JL_TOKEN:<uid>
 */
public class FlagProbe {

    private static final int HEADER_CLIENT = 16;
    private static final int HEADER_SERVER = 20;

    private Socket socket;
    private DataInputStream in;
    private OutputStream out;
    private int index = 1;

    public FlagProbe(String host, int port, int uid, int token) throws Exception {
        socket = new Socket(host, port);
        socket.setSoTimeout(6000);
        socket.setTcpNoDelay(true);
        in = new DataInputStream(socket.getInputStream());
        out = socket.getOutputStream();
        this.uid = uid;
        this.token = token;
    }

    private final int uid;
    private final int token;

    private static byte[] intToBytes(int v) {
        return new byte[]{(byte) (v >> 24), (byte) (v >> 16), (byte) (v >> 8), (byte) v};
    }

    private void send(int msgId, byte[] body) throws Exception {
        byte[] plain = new byte[HEADER_CLIENT + body.length];
        System.arraycopy(intToBytes(uid), 0, plain, 0, 4);
        System.arraycopy(intToBytes(token), 0, plain, 4, 4);
        System.arraycopy(intToBytes(msgId), 0, plain, 8, 4);
        System.arraycopy(intToBytes(index++), 0, plain, 12, 4);
        System.arraycopy(body, 0, plain, HEADER_CLIENT, body.length);

        byte[] enc = Tea.encrypt2(plain, Tea.KEY);   // [4B len][cipher]，长度字段是给本端用的
        int len = plain.length;
        out.write(new byte[]{(byte) (len >> 8), (byte) len});
        out.write(enc, 4, enc.length - 4);           // 去掉内层 4B 长度，换成本端 2B 长度
        out.flush();
    }

    /** 读一个完整包，返回 {msgId, index, result, body} */
    private Object[] read() throws Exception {
        int len = in.readInt();
        if (len <= 0 || len > 1 << 20) {
            throw new IllegalStateException("非法包长 " + len);
        }
        int encLen = (len + 7) / 8 * 8;
        byte[] cipher = new byte[encLen];
        in.readFully(cipher);
        byte[] plain = Tea.decrypt2(cipher, len, 0, Tea.KEY);
        int msgId = Tea.byteToInt(plain, 8);
        int idx = Tea.byteToInt(plain, 12);
        int result = Tea.byteToInt(plain, 16);
        byte[] body = new byte[len - HEADER_SERVER];
        System.arraycopy(plain, HEADER_SERVER, body, 0, body.length);
        return new Object[]{msgId, idx, result, body};
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 3) {
            System.out.println("用法: FlagProbe <uid> <token> <targetUid> [host] [port]");
            return;
        }
        int uid = Integer.parseInt(args[0]);
        int token = Integer.parseInt(args[1]);
        int target = Integer.parseInt(args[2]);
        String host = args.length > 3 ? args[3] : "127.0.0.1";
        int port = args.length > 4 ? Integer.parseInt(args[4]) : 16081;

        FlagProbe p = new FlagProbe(host, port, uid, token);
        System.out.println("[1] 连接 " + host + ":" + port + "  uid=" + uid);

        // --- 登录（服务端用 redis 里的 JL_TOKEN:<uid> 校验）---
        p.send(MessageTypeProto.MessageType.LOGIN_REQUEST_VALUE,
                PlayerInfoProto.LoginRequest.newBuilder().build().toByteArray());
        long deadline = System.currentTimeMillis() + 5000;
        boolean logged = false;
        while (System.currentTimeMillis() < deadline) {
            Object[] pkt = p.read();
            int msgId = (Integer) pkt[0];
            if (msgId == MessageTypeProto.MessageType.LOGIN_RESPONSE_VALUE) {
                System.out.println("[2] 登录成功 result=" + pkt[2]);
                logged = true;
                break;
            }
        }
        if (!logged) {
            System.out.println("[2] 登录未收到 LOGIN_RESPONSE，继续尝试");
        }

        // --- 拉目标玩家信息（真客户端点开 PlayerInfoPopup 发的就是这一条）---
        PlayerInfoProto.GetPlayerOneTeamInfoRequest req =
                PlayerInfoProto.GetPlayerOneTeamInfoRequest.newBuilder()
                        .setPlayerId(target)
                        .setTeamId(1)
                        .setServerId(0)
                        .setTypeId(0)
                        .build();
        p.send(16650, req.toByteArray());
        System.out.println("[3] 发送 GET_PLAYER_ONE_TEAM_INFO_REQUEST playerId=" + target);

        boolean got = false;
        deadline = System.currentTimeMillis() + 6000;
        while (System.currentTimeMillis() < deadline) {
            Object[] pkt = p.read();
            int msgId = (Integer) pkt[0];
            int result = (Integer) pkt[2];
            byte[] body = (byte[]) pkt[3];
            if (msgId != 16651) {
                continue;
            }
            got = true;
            System.out.println("[4] 收到回包 result=" + result + " bodyLen=" + body.length);
            if (result != 0) {
                System.out.println("    错误码=" + result);
                break;
            }
            PlayerInfoProto.GetPlayerOneTeamInfoResponse resp =
                    PlayerInfoProto.GetPlayerOneTeamInfoResponse.parseFrom(body);
            if (!resp.hasTeamInfo()) {
                System.out.println("    回包里没有 teamInfo！");
                break;
            }
            com.ljsd.jieling.protocols.CommonProto.TeamOneInfo ti = resp.getTeamInfo();
            System.out.println("    ── 关键字段 ──");
            System.out.println("    uid         = " + ti.getUid());
            System.out.println("    name        = " + ti.getName());
            System.out.println("    level       = " + ti.getLevel());
            System.out.println("    hasCountry  = " + ti.hasCountry());
            System.out.println("    country     = '" + ti.getCountry() + "'");
            System.out.println("    (空字符串=服务端没写值；非空=链路通，问题在客户端渲染)");
            break;
        }
        if (!got) {
            System.out.println("[4] 超时：没收到 16651 回包");
        }
        p.socket.close();
    }
}
