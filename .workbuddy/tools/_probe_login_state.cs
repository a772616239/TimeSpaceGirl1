var asms = System.AppDomain.CurrentDomain.GetAssemblies();
System.Type lmT = null, lsT = null;
foreach (var a in asms) {
    if (lmT == null) lmT = a.GetType("GameLogic.LuaManager", false);
    if (lsT == null) lsT = a.GetType("LuaInterface.LuaState", false);
}
if (lmT == null || lsT == null) return "type missing lm=" + (lmT != null) + " ls=" + (lsT != null);
var pi = lmT.GetProperty("Instance", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.FlattenHierarchy);
object lm = pi != null ? pi.GetValue(null) : null;
if (lm == null) return "instance null";
var fi = lmT.GetField("luaState", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
var ls = fi != null ? fi.GetValue(lm) : null;
if (ls == null) return "luaState null";
System.Reflection.MethodInfo gm = null;
foreach (var mm in lsT.GetMethods()) {
    if (mm.Name == "DoString" && mm.IsGenericMethodDefinition && mm.GetParameters().Length == 2) { gm = mm.MakeGenericMethod(typeof(string)); break; }
}
if (gm == null) return "DoString<T> not found";
var chunk = "local out = {} " +
 "out[#out+1]='openId='..tostring(LoginManager and LoginManager.openId) " +
 "out[#out+1]='token='..tostring(LoginManager and LoginManager.token) " +
 "out[#out+1]='addr='..tostring(LoginManager and LoginManager.SocketAddress) " +
 "out[#out+1]='port='..tostring(LoginManager and LoginManager.SocketPort) " +
 "out[#out+1]='serverId='..tostring(LoginManager and LoginManager.ServerId) " +
 "out[#out+1]='appOpenId='..tostring(AppConst and AppConst.OpenId) " +
 "out[#out+1]='isSDK='..tostring(IsSDKLogin) " +
 "out[#out+1]='smNil='..tostring(SocketManager==nil) " +
 "if type(SocketManager)=='table' then local ks={} for k,v in pairs(SocketManager) do ks[#ks+1]=tostring(k)..':'..type(v) end table.sort(ks) out[#out+1]='SMkeys='..table.concat(ks,',') end " +
 "return table.concat(out, ' | ')";
try { return System.Convert.ToString(gm.Invoke(ls, new object[] { chunk, "@probe_login" })); }
catch (System.Exception e) { return "EX: " + (e.InnerException != null ? e.InnerException.Message : e.Message); }
