var asms = System.AppDomain.CurrentDomain.GetAssemblies();
System.Type lmT = null, lsT = null;
foreach (var a in asms) {
    if (lmT == null) lmT = a.GetType("GameLogic.LuaManager", false);
    if (lsT == null) lsT = a.GetType("LuaInterface.LuaState", false);
}
var pi = lmT.GetProperty("Instance", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.FlattenHierarchy);
object lm = pi.GetValue(null);
var ls = lmT.GetField("luaState", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance).GetValue(lm);
System.Reflection.MethodInfo gm = null;
foreach (var mm in lsT.GetMethods()) {
    if (mm.Name == "DoString" && mm.IsGenericMethodDefinition && mm.GetParameters().Length == 2) { gm = mm.MakeGenericMethod(typeof(string)); break; }
}
var chunk = "local out={} " +
 "local d=SocketManager.SocketDic " +
 "for k,v in pairs(d) do local s='key='..tostring(k)..' type='..type(v) if type(v)=='table' then s=s..' [' for kk,vv in pairs(v) do if type(vv)~='function' and type(vv)~='table' then s=s..tostring(kk)..'='..tostring(vv)..';' end end s=s..']' end out[#out+1]=s end " +
 "out[#out+1]='list='..tostring(SocketManager.SocketList and #SocketManager.SocketList) " +
 "local n = SocketManager.GetNetwork(1) " +
 "if n==nil then out[#out+1]='getnet(1)=nil' else out[#out+1]='getnet1 type='..type(n) end " +
 "local panels={} for k,v in pairs(UIManager and UIManager.panels or {}) do panels[#panels+1]=tostring(k) end table.sort(panels) out[#out+1]='panels='..table.concat(panels,',') " +
 "return table.concat(out,' || ')";
try { return System.Convert.ToString(gm.Invoke(ls, new object[] { chunk, "@probe_sock" })); }
catch (System.Exception e) { return "EX: " + (e.InnerException != null ? e.InnerException.Message : e.Message); }
