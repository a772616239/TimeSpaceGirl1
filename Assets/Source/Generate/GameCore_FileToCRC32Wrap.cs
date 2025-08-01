﻿//this source code was auto-generated by tolua#, do not modify it
using System;
using LuaInterface;

public class GameCore_FileToCRC32Wrap
{
	public static void Register(LuaState L)
	{
		L.BeginClass(typeof(GameCore.FileToCRC32), typeof(System.Object));
		L.RegFunction("GetFileCRC32", GetFileCRC32);
		L.RegFunction("GetStrCRC32", GetStrCRC32);
		L.RegFunction("GetCRC32", GetCRC32);
		L.RegFunction("New", _CreateGameCore_FileToCRC32);
		L.RegFunction("__tostring", ToLua.op_ToString);
		L.EndClass();
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int _CreateGameCore_FileToCRC32(IntPtr L)
	{
		try
		{
			int count = LuaDLL.lua_gettop(L);

			if (count == 0)
			{
				GameCore.FileToCRC32 obj = new GameCore.FileToCRC32();
				ToLua.PushObject(L, obj);
				return 1;
			}
			else
			{
				return LuaDLL.luaL_throw(L, "invalid arguments to ctor method: GameCore.FileToCRC32.New");
			}
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int GetFileCRC32(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 1);
			string arg0 = ToLua.CheckString(L, 1);
			string o = GameCore.FileToCRC32.GetFileCRC32(arg0);
			LuaDLL.lua_pushstring(L, o);
			return 1;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int GetStrCRC32(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 1);
			string arg0 = ToLua.CheckString(L, 1);
			string o = GameCore.FileToCRC32.GetStrCRC32(arg0);
			LuaDLL.lua_pushstring(L, o);
			return 1;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int GetCRC32(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 1);
			byte[] arg0 = ToLua.CheckByteBuffer(L, 1);
			string o = GameCore.FileToCRC32.GetCRC32(arg0);
			LuaDLL.lua_pushstring(L, o);
			return 1;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}
}

