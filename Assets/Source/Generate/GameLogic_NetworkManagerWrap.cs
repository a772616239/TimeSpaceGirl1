﻿//this source code was auto-generated by tolua#, do not modify it
using System;
using LuaInterface;

public class GameLogic_NetworkManagerWrap
{
	public static void Register(LuaState L)
	{
		L.BeginClass(typeof(GameLogic.NetworkManager), typeof(GameCore.UnitySingleton<GameLogic.NetworkManager>));
		L.RegFunction("Reset", Reset);
		L.RegFunction("OnInit", OnInit);
		L.RegFunction("Unload", Unload);
		L.RegFunction("AddSocket", AddSocket);
		L.RegFunction("SendGetHttp", SendGetHttp);
		L.RegFunction("SendAndroidData", SendAndroidData);
		L.RegFunction("SendHttpPost_Raw_Lua", SendHttpPost_Raw_Lua);
		L.RegFunction("SendHttpPost_Json_Lua", SendHttpPost_Json_Lua);
		L.RegFunction("SendHttpPost_Raw_CSharp", SendHttpPost_Raw_CSharp);
		L.RegFunction("SendHttpPost_Json_CSharp", SendHttpPost_Json_CSharp);
		L.RegFunction("HttpPost_Co", HttpPost_Co);
		L.RegFunction("__eq", op_Equality);
		L.RegFunction("__tostring", ToLua.op_ToString);
		L.EndClass();
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int Reset(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 1);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			obj.Reset();
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int OnInit(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 1);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			obj.OnInit();
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int Unload(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 1);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			obj.Unload();
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int AddSocket(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 3);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			int arg1 = (int)LuaDLL.luaL_checknumber(L, 3);
			SocketClient o = obj.AddSocket(arg0, arg1);
			ToLua.PushObject(L, o);
			return 1;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int SendGetHttp(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 6);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			LuaFunction arg1 = ToLua.CheckLuaFunction(L, 3);
			System.Action<string> arg2 = (System.Action<string>)ToLua.CheckDelegate<System.Action<string>>(L, 4);
			System.Action arg3 = (System.Action)ToLua.CheckDelegate<System.Action>(L, 5);
			LuaFunction arg4 = ToLua.CheckLuaFunction(L, 6);
			obj.SendGetHttp(arg0, arg1, arg2, arg3, arg4);
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int SendAndroidData(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 2);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			obj.SendAndroidData(arg0);
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int SendHttpPost_Raw_Lua(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 5);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			string arg1 = ToLua.CheckString(L, 3);
			LuaFunction arg2 = ToLua.CheckLuaFunction(L, 4);
			LuaFunction arg3 = ToLua.CheckLuaFunction(L, 5);
			obj.SendHttpPost_Raw_Lua(arg0, arg1, arg2, arg3);
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int SendHttpPost_Json_Lua(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 5);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			string arg1 = ToLua.CheckString(L, 3);
			LuaFunction arg2 = ToLua.CheckLuaFunction(L, 4);
			LuaFunction arg3 = ToLua.CheckLuaFunction(L, 5);
			obj.SendHttpPost_Json_Lua(arg0, arg1, arg2, arg3);
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int SendHttpPost_Raw_CSharp(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 5);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			string arg1 = ToLua.CheckString(L, 3);
			System.Action<string> arg2 = (System.Action<string>)ToLua.CheckDelegate<System.Action<string>>(L, 4);
			System.Action arg3 = (System.Action)ToLua.CheckDelegate<System.Action>(L, 5);
			obj.SendHttpPost_Raw_CSharp(arg0, arg1, arg2, arg3);
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int SendHttpPost_Json_CSharp(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 5);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			string arg1 = ToLua.CheckString(L, 3);
			System.Action<string> arg2 = (System.Action<string>)ToLua.CheckDelegate<System.Action<string>>(L, 4);
			System.Action arg3 = (System.Action)ToLua.CheckDelegate<System.Action>(L, 5);
			obj.SendHttpPost_Json_CSharp(arg0, arg1, arg2, arg3);
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int HttpPost_Co(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 7);
			GameLogic.NetworkManager obj = (GameLogic.NetworkManager)ToLua.CheckObject<GameLogic.NetworkManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			string arg1 = ToLua.CheckString(L, 3);
			LuaFunction arg2 = ToLua.CheckLuaFunction(L, 4);
			System.Action<string> arg3 = (System.Action<string>)ToLua.CheckDelegate<System.Action<string>>(L, 5);
			System.Action arg4 = (System.Action)ToLua.CheckDelegate<System.Action>(L, 6);
			LuaFunction arg5 = ToLua.CheckLuaFunction(L, 7);
			System.Collections.IEnumerator o = obj.HttpPost_Co(arg0, arg1, arg2, arg3, arg4, arg5);
			ToLua.Push(L, o);
			return 1;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int op_Equality(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 2);
			UnityEngine.Object arg0 = (UnityEngine.Object)ToLua.ToObject(L, 1);
			UnityEngine.Object arg1 = (UnityEngine.Object)ToLua.ToObject(L, 2);
			bool o = arg0 == arg1;
			LuaDLL.lua_pushboolean(L, o);
			return 1;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}
}

