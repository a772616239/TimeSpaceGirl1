﻿//this source code was auto-generated by tolua#, do not modify it
using System;
using LuaInterface;

public class UnrealM_ImageAnimationWrap
{
	public static void Register(LuaState L)
	{
		L.BeginClass(typeof(UnrealM.ImageAnimation), typeof(UnrealM.SpriteAnimation));
		L.RegFunction("OnFrame", OnFrame);
		L.RegFunction("ResetFrame", ResetFrame);
		L.RegFunction("__eq", op_Equality);
		L.RegFunction("__tostring", ToLua.op_ToString);
		L.RegVar("image", get_image, set_image);
		L.EndClass();
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int OnFrame(IntPtr L)
	{
		try
		{
			ToLua.CheckArgsCount(L, 2);
			UnrealM.ImageAnimation obj = (UnrealM.ImageAnimation)ToLua.CheckObject<UnrealM.ImageAnimation>(L, 1);
			int arg0 = (int)LuaDLL.luaL_checknumber(L, 2);
			obj.OnFrame(arg0);
			return 0;
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int ResetFrame(IntPtr L)
	{
		try
		{
			int count = LuaDLL.lua_gettop(L);

			if (count == 1)
			{
				UnrealM.ImageAnimation obj = (UnrealM.ImageAnimation)ToLua.CheckObject<UnrealM.ImageAnimation>(L, 1);
				obj.ResetFrame();
				return 0;
			}
			else if (count == 2)
			{
				UnrealM.ImageAnimation obj = (UnrealM.ImageAnimation)ToLua.CheckObject<UnrealM.ImageAnimation>(L, 1);
				int arg0 = (int)LuaDLL.luaL_checknumber(L, 2);
				obj.ResetFrame(arg0);
				return 0;
			}
			else
			{
				return LuaDLL.luaL_throw(L, "invalid arguments to method: UnrealM.ImageAnimation.ResetFrame");
			}
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

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int get_image(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			UnrealM.ImageAnimation obj = (UnrealM.ImageAnimation)o;
			UnityEngine.UI.Image ret = obj.image;
			ToLua.Push(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index image on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_image(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			UnrealM.ImageAnimation obj = (UnrealM.ImageAnimation)o;
			UnityEngine.UI.Image arg0 = (UnityEngine.UI.Image)ToLua.CheckObject<UnityEngine.UI.Image>(L, 2);
			obj.image = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index image on a nil value");
		}
	}
}

