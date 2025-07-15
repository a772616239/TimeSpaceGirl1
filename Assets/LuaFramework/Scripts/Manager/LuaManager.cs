using UnityEngine;
using System.Collections;
using LuaInterface;
using GameCore;
namespace GameLogic
{
    public class LuaManager : UnitySingleton<LuaManager>
    {
        /// <summary>
        /// lua虚拟机
        /// </summary>
        private LuaState luaState;
        /// <summary>
        /// lua加载器
        /// </summary>
        private LuaLoader luaLoader;
        /// <summary>
        /// lua
        /// </summary>
        private LuaLooper luaLooper = null;

        // Use this for initialization

        /// <summary>
        /// 初始化
        /// </summary>
        public void InitLua()
        {
            luaLoader = new LuaLoader();
            luaState = new LuaState();

            this.OpenLibs();
            luaState.LuaSetTop(0);

            //LuaBinder.Bind(luaState);
            Bind();
            //LuaCoroutine.Register(luaState, this);
        }

        /// <summary>
        /// 启动lua虚拟机
        /// </summary>
        public void InitStart()
        {
            InitLuaPath();
            InitLuaBundle();
            this.luaState.Start();    //启动LUAVM
            this.StartMain();
            this.StartLooper();
        }

        /// <summary>
        /// 添加SearchPath
        /// </summary>
        /// <param name="path"></param>
        public void AddSearchPath(string path) {
            if (luaState != null) 
            {
                luaState.AddSearchPath(path);
                Debug.LogFormat("AddSearchPath:{0}",path);
            }
        }

        /// <summary>
        /// 移除SearchPath
        /// </summary>
        /// <param name="path"></param>
        public void RemoveSearchPath(string path) {
            if (luaState != null)
            {
                luaState.RemoveSeachPath(path);
                Debug.LogFormat("RemoveSearchPath:{0}", path);
            }
        }

        void StartLooper()
        {
            luaLooper = gameObject.GetComponent<LuaLooper>();
            if (luaLooper != null)
                Destroy(luaLooper);

            luaLooper = gameObject.AddComponent<LuaLooper>();
            luaLooper.luaState = luaState;
        }

        //cjson 比较特殊，只new了一个table，没有注册库，这里注册一下
        protected void OpenCJson()
        {
            luaState.LuaGetField(LuaIndexes.LUA_REGISTRYINDEX, "_LOADED");
            luaState.OpenLibs(LuaDLL.luaopen_cjson);
            luaState.LuaSetField(-2, "cjson");

            luaState.OpenLibs(LuaDLL.luaopen_cjson_safe);
            luaState.LuaSetField(-2, "cjson.safe");
        }

        void StartMain()
        {
            luaState.DoFile("Main.lua");

            LuaFunction main = luaState.GetFunction("Main");
            main.Call();
            main.Dispose();
            main = null;
        }
        public void CallLuaFunction(string Path, string FunctionName)
        {

            luaState.DoFile(Path);

            LuaFunction main = luaState.GetFunction(FunctionName);
            main.Call();
            main.Dispose();
            main = null;
        }

        /// <summary>
        /// 初始化加载第三方库
        /// </summary>
        void OpenLibs()
        {
            luaState.OpenLibs(LuaDLL.luaopen_pb);
            //lua.OpenLibs(LuaDLL.luaopen_sproto_core);
            //lua.OpenLibs(LuaDLL.luaopen_protobuf_c);
            //lua.OpenLibs(LuaDLL.luaopen_lpeg);
            //lua.OpenLibs(LuaDLL.luaopen_bit);
            //lua.OpenLibs(LuaDLL.luaopen_socket_core);

            this.OpenCJson();
        }

        /// <summary>
        /// 绑定
        /// </summary>
        void Bind()
        {
            LuaBinder.Bind(luaState);
            DelegateFactory.Init();
            LuaCoroutine.Register(luaState, this);
        }

        /// <summary>
        /// 初始化Lua代码加载路径
        /// </summary>
        void InitLuaPath()
        {
            if (!AppConst.luaBundleMode)
            {
                App.LuaMgr.AddSearchPath(AppConst.GameResRealPath + "/~Lua");
            }
        }

        /// <summary>
        /// 初始化LuaBundle
        /// </summary>
        void InitLuaBundle()
        {
            //if (loader.beZip)
            //{
            //    loader.AddBundle("lua/lua.unity3d");
            //    loader.AddBundle("lua/lua_math.unity3d");
            //    loader.AddBundle("lua/lua_system.unity3d");
            //    loader.AddBundle("lua/lua_system_reflection.unity3d");
            //    loader.AddBundle("lua/lua_unityengine.unity3d");
            //    loader.AddBundle("lua/lua_common.unity3d");
            //    loader.AddBundle("lua/lua_logic.unity3d");
            //    loader.AddBundle("lua/lua_view.unity3d");
            //    loader.AddBundle("lua/lua_controller.unity3d");
            //    loader.AddBundle("lua/lua_misc.unity3d");

            //    loader.AddBundle("lua/lua_protobuf.unity3d");
            //    loader.AddBundle("lua/lua_3rd_cjson.unity3d");
            //    loader.AddBundle("lua/lua_3rd_luabitop.unity3d");
            //    loader.AddBundle("lua/lua_3rd_pbc.unity3d");
            //    loader.AddBundle("lua/lua_3rd_pblua.unity3d");
            //    loader.AddBundle("lua/lua_3rd_sproto.unity3d");
            //}
        }

        public void DoFile(string filename)
        {
            if (!CanUseLua())
                return;
            luaState.DoFile(filename);
        }

        // Update is called once per frame
        public void CallFunction(string funcName, params object[] args)
        {
            if (!CanUseLua())
                return;

            LuaFunction func = luaState.GetFunction(funcName);
            if (func != null)
            {
                func.LazyCall(args);
            }
        } 

        public T DoString<T>(string str){
            if (!CanUseLua())
                return default(T);
            return luaState.DoString<T>(str);
        }

        public void LuaGC()
        {
            if (!CanUseLua())
                return;

            luaState.LuaGC(LuaGCOptions.LUA_GCCOLLECT);
        }

        public void Close()
        {
            if (luaLooper != null)
                Destroy(luaLooper);
            if (luaState != null)
                luaState.Dispose();
            if (luaLoader != null)
                luaLoader.Dispose();

            luaState = null;
            luaLooper = null;
            luaLoader = null;
        }

        public bool CanUseLua()
        {
            if (luaLooper == null)
                return false;

            if (luaState == null)
                return false;

            if (luaLoader == null)
                return false;

            return true;
        }

        LuaTable profiler = null;

        public void AttachProfiler()
        {
            if (profiler == null)
            {
                profiler = luaState.Require<LuaTable>("UnityEngine.Profiler");
                profiler.Call("start", profiler);
            }
        }
        public void DetachProfiler()
        {
            if (profiler != null)
            {
                profiler.Call("stop", profiler);
                profiler.Dispose();
                LuaProfiler.Clear();
            }
        }

        public void Reset()
        {
            //LuaGC();
            Close();
        }
    }
}