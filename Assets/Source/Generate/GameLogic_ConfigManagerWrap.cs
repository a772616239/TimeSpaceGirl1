﻿//this source code was auto-generated by tolua#, do not modify it
using System;
using LuaInterface;

public class GameLogic_ConfigManagerWrap
{
	public static void Register(LuaState L)
	{
		L.BeginClass(typeof(GameLogic.ConfigManager), typeof(GameCore.Singleton<GameLogic.ConfigManager>));
		L.RegFunction("Init", Init);
		L.RegFunction("SetNetInfo", SetNetInfo);
		L.RegFunction("GetConfigInfo", GetConfigInfo);
		L.RegFunction("GetConfigNetInfo", GetConfigNetInfo);
		L.RegFunction("New", _CreateGameLogic_ConfigManager);
		L.RegFunction("__tostring", ToLua.op_ToString);
		L.EndClass();
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int _CreateGameLogic_ConfigManager(IntPtr L)
	{
		try
		{
			int count = LuaDLL.lua_gettop(L);

			if (count == 0)
			{
				GameLogic.ConfigManager obj = new GameLogic.ConfigManager();
				ToLua.PushObject(L, obj);
				return 1;
			}
			else
			{
				return LuaDLL.luaL_throw(L, "invalid arguments to ctor method: GameLogic.ConfigManager.New");
			}
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int Init(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 1);
			GameLogic.ConfigManager obj = (GameLogic.ConfigManager)ToLua.CheckObject<GameLogic.ConfigManager>(L, 1);
			obj.Init();
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int SetNetInfo(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 2);
			GameLogic.ConfigManager obj = (GameLogic.ConfigManager)ToLua.CheckObject<GameLogic.ConfigManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			obj.SetNetInfo(arg0);
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int GetConfigInfo(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 2);
			GameLogic.ConfigManager obj = (GameLogic.ConfigManager)ToLua.CheckObject<GameLogic.ConfigManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			string o = obj.GetConfigInfo(arg0);
			LuaDLL.lua_pushstring(L, o);
			return 1;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int GetConfigNetInfo(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 2);
			GameLogic.ConfigManager obj = (GameLogic.ConfigManager)ToLua.CheckObject<GameLogic.ConfigManager>(L, 1);
			string arg0 = ToLua.CheckString(L, 2);
			string o = obj.GetConfigNetInfo(arg0);
			LuaDLL.lua_pushstring(L, o);
			return 1;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}
}

