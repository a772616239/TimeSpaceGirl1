/*
 * 登录服区服列表接口：tk/getServerList
 *
 * 来源说明
 *   原始工程只发布了 class，源码早已丢失。本文件是「CFR 反编译重建 + 本次功能增强」版本，
 *   重建基线来自 webapps/tk/WEB-INF/classes/com/ljsd/controller/GetServerListController.class
 *   （md5 87104ceebb8898be15d3a1398354a3e4）。重建时已用 LocalVariableTable /
 *   LocalVariableTypeTable 逐条核对局部变量的类型与泛型，并通过「同源复编 → 指令流归一化 diff」
 *   验证语义一致（见同目录 build-and-verify.sh）。
 *
 * 本次增强：区服名多语言下沉到服务端数据
 *   原实现只下发中文 name，客户端只能拿中文串去本地翻译表（Lua Language.xlsx / AddManualTranslation）
 *   反查，查不到就红字告警并回落中文 —— 后果是每新增一个区服都要改客户端 Lua、重编字节码、重新发版。
 *
 *   现改为：把 server_info 文档里的分语言字段一并下发给客户端，由客户端按当前语言选用。
 *   新增字段（均按需下发；字段缺失或为空则不下发，因此老记录的响应体与改动前逐字节一致）：
 *       name_en  英文区名
 *       name_jp  日文区名
 *       name_kr  韩文区名
 *
 *   ⇒ 以后新增区服只需在 server_info 里写好 name / name_en / name_jp，客户端零改动。
 *
 *   兼容性：客户端 GetServerName() 的取值顺序是「分语言字段 → 本地翻译表 → 中文原名」，
 *   所以本改动与未升级的老客户端、以及没填分语言字段的老区服都能共存。
 */
package com.ljsd.controller;

import com.ljsd.pojo.UserRecentLoginInfo;
import com.ljsd.util.BaseGlobal;
import com.ljsd.util.NetUtil;
import com.ljsd.util.StringUtils;
import com.mongodb.BasicDBObject;
import com.mongodb.DBObject;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentHashMap;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

public class GetServerListController extends HttpServlet {
    private static final String _COLLECTION_NAME = "server_info";
    private static final String _WHITE_LIST = "white_user_list";
    private static final String _BLACK_LIST = "black_user_list";
    private static final String _IP_LIST = "white_ip_list";
    private static ConcurrentHashMap<String, DBObject> serverInfosCache = new ConcurrentHashMap();
    private static volatile DBObject whiteListCache = new BasicDBObject();
    private static volatile String recommend = "";
    private static volatile long lastRefreshTime = 0L;

    /**
     * 按需下发分语言区名：字段不存在或为空串时不下发。
     * 这样只有中文 name 的老记录，响应体与改动前完全一致，零回归风险。
     */
    private static void putIfNotEmpty(DBObject res, DBObject serverInfo, String key) {
        Object value = serverInfo.get(key);
        if (value != null && value.toString().trim().length() > 0) {
            res.put(key, value);
        }
    }

    public void destroy() {
        super.destroy();
    }

    public void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setCharacterEncoding("UTF-8");
        response.setContentType("application/json; charset=utf-8");
        PrintWriter out = response.getWriter();
        try {
            long time;
            String openId = request.getParameter("openId");
            String channel = request.getParameter("channel");
            String sub_channel = request.getParameter("sub_channel");
            String server_version = String.valueOf(request.getParameter("server_version"));
            String plat = request.getParameter("plat");
            if (StringUtils.checkIsEmpty(openId) || StringUtils.checkIsEmpty(channel) || StringUtils.checkIsEmpty(sub_channel) || StringUtils.checkIsEmpty(plat) || StringUtils.checkIsEmpty(server_version)) {
                response.sendError(400, "parm is wrong");
                return;
            }
            DBObject req = new BasicDBObject();
            req.put("channel", channel);
            req.put("sub_channel", sub_channel);
            req.put("plat", plat);
            List<DBObject> serverList = new ArrayList<DBObject>();
            long local = System.currentTimeMillis();
            serverInfosCache.clear();
            lastRefreshTime = local;
            recommend = "";
            DBObject whiteListDBObject = new BasicDBObject();
            whiteListDBObject.put("openId", openId);
            List<DBObject> whiteList = BaseGlobal.getInstance().mongoDBPool.find(_WHITE_LIST, whiteListDBObject);
            List<DBObject> blackList = BaseGlobal.getInstance().mongoDBPool.find(_BLACK_LIST, whiteListDBObject);
            String userip = NetUtil.getIpAddr(request);
            DBObject whiteIPListDBObject = new BasicDBObject();
            whiteIPListDBObject.put("ip", userip);
            List<DBObject> ipList = BaseGlobal.getInstance().mongoDBPool.find(_BLACK_LIST, whiteIPListDBObject);
            List<DBObject> serverInfoList = BaseGlobal.getInstance().mongoDBPool.find(_COLLECTION_NAME, req);
            SortedSet<String> newServerList = new TreeSet<String>();
            String maxNumServerId = "";
            int maxNum = 0;
            int shenheNum = 0;
            for (DBObject serverInfo : serverInfoList) {
                String server_version1 = serverInfo.get("server_version").toString();
                if (server_version.equals(server_version1)) {
                    ++shenheNum;
                }
            }
            for (DBObject serverInfo : serverInfoList) {
                int state = Integer.parseInt(serverInfo.get("state").toString());
                time = Long.parseLong(serverInfo.get("open_time").toString());
                String server_id = serverInfo.get("server_id").toString();
                String server_version2 = serverInfo.get("server_version").toString();
                int num = this.getOnlineNum(server_id);
                if (whiteList != null && whiteList.size() > 0 && (state == -1 || state == 1 || state == 0)) {
                    state = 2;
                } else if (ipList != null && ipList.size() > 0 && (state == -1 || state == 1 || state == 0)) {
                    state = 2;
                } else if (blackList != null && blackList.size() > 0) {
                    state = 1;
                } else if (state == 5) {
                    state = this.getState(server_id, num);
                }
                if (state == 0) continue;
                if (state == -1) continue;
                if (System.currentTimeMillis() < time && whiteList.size() == 0) continue;
                if (state == 2 && maxNum < num) {
                    maxNum = num;
                    maxNumServerId = server_id;
                }
                if (!server_version2.equals("0") ? !server_version.equals(server_version2) : shenheNum >= 1) continue;
                int isnew = 0;
                if (serverInfo.containsField("is_new")) {
                    isnew = Integer.parseInt(serverInfo.get("is_new").toString());
                }
                if (isnew == 1) {
                    newServerList.add(server_id);
                }
                int banreg = 0;
                if (serverInfo.containsField("is_banreg")) {
                    banreg = Integer.parseInt(serverInfo.get("is_banreg").toString());
                }
                DBObject res = new BasicDBObject();
                res.put("name", serverInfo.get("name"));
                putIfNotEmpty(res, serverInfo, "name_en");
                putIfNotEmpty(res, serverInfo, "name_jp");
                putIfNotEmpty(res, serverInfo, "name_kr");
                res.put("server_id", server_id);
                res.put("state", state);
                res.put("open_time", serverInfo.get("open_time"));
                res.put("isnew", isnew);
                res.put("isbanreg", banreg);
                Object ip = serverInfo.get("ip");
                Object port = serverInfo.get("port");
                if (state == 1) {
                    ip = "";
                    port = "";
                }
                res.put("ip", ip);
                res.put("port", port);
                serverList.add(res);
                serverInfosCache.put(serverInfo.get("server_id").toString(), res);
            }
            if (newServerList.size() != 0) {
                recommend = newServerList.first();
            } else {
                recommend = maxNumServerId;
            }
            Map<String, UserRecentLoginInfo> userServerInfoMap = BaseGlobal.getInstance().redisApp.hgetAll("JL_USER_SERVER_INFO", openId, UserRecentLoginInfo.class, -1, false);
            DBObject myLastServer = null;
            List<DBObject> myServerList = new ArrayList<DBObject>();
            time = 0L;
            for (Map.Entry<String, UserRecentLoginInfo> entry : userServerInfoMap.entrySet()) {
                if (!serverInfosCache.keySet().contains(entry.getKey())) continue;
                myServerList.add(this.getDBObject(entry.getKey(), entry.getValue()));
                if (entry.getValue().getLoginTime() > time) {
                    time = entry.getValue().getLoginTime();
                    myLastServer = this.getDBObject(entry.getKey(), entry.getValue());
                }
            }
            DBObject resp = new BasicDBObject();
            resp.put("serverList", serverList);
            resp.put("myServerList", myServerList);
            if (null != myLastServer) {
                resp.put("lastServer", myLastServer);
            }
            if (recommend != null && !recommend.equals("")) {
                resp.put("recommend", recommend);
            }
            out.print(resp.toString());
        }
        catch (Exception e) {
            e.printStackTrace();
        }
        finally {
            out.flush();
            out.close();
        }
    }

    /** 注意：这里的 name 是「玩家角色名」，与区服名无关，不要混入区服多语言字段。 */
    private DBObject getDBObject(String serverId, UserRecentLoginInfo userRecentLoginInfo) {
        DBObject res = new BasicDBObject();
        res.put("serverid", serverId);
        res.put("name", userRecentLoginInfo.getName());
        res.put("level", userRecentLoginInfo.getLevel());
        res.put("head", userRecentLoginInfo.getHead());
        res.put("headfream", userRecentLoginInfo.getHeadFream());
        return res;
    }

    public void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        this.doGet(request, response);
    }

    private int getState(String server_id, int num) throws Exception {
        int state = 2;
        Map globalCfgMap = BaseGlobal.getInstance().redisApp.hgetAll("GLOBAL_SYS_PRO", "", String.class, -1, false);
        int crowdnum = Integer.valueOf((String)globalCfgMap.getOrDefault("crowdnum", "0"));
        int highnum = Integer.valueOf((String)globalCfgMap.getOrDefault("highnum", "0"));
        if (crowdnum != 0 && highnum != 0 && num >= crowdnum) {
            state = 3;
            if (num >= highnum) {
                state = 4;
            }
        }
        return state;
    }

    private int getOnlineNum(String server_id) throws Exception {
        Integer num = (Integer)BaseGlobal.getInstance().redisApp.get("ONLINE_NUM", server_id, Integer.class, -1);
        if (num == null) {
            num = 0;
        }
        return num;
    }
}
