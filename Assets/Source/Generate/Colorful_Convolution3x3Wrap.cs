﻿//this source code was auto-generated by tolua#, do not modify it
using System;
using LuaInterface;

public class Colorful_Convolution3x3Wrap
{
	public static void Register(LuaState L)
	{
		L.BeginClass(typeof(Colorful.Convolution3x3), typeof(Colorful.BaseEffect));
		L.RegFunction("__eq", op_Equality);
		L.RegFunction("__tostring", ToLua.op_ToString);
		L.RegVar("KernelTop", get_KernelTop, set_KernelTop);
		L.RegVar("KernelMiddle", get_KernelMiddle, set_KernelMiddle);
		L.RegVar("KernelBottom", get_KernelBottom, set_KernelBottom);
		L.RegVar("Divisor", get_Divisor, set_Divisor);
		L.RegVar("Amount", get_Amount, set_Amount);
		L.EndClass();
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
	static int get_KernelTop(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			UnityEngine.Vector3 ret = obj.KernelTop;
			ToLua.Push(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index KernelTop on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int get_KernelMiddle(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			UnityEngine.Vector3 ret = obj.KernelMiddle;
			ToLua.Push(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index KernelMiddle on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int get_KernelBottom(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			UnityEngine.Vector3 ret = obj.KernelBottom;
			ToLua.Push(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index KernelBottom on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int get_Divisor(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			float ret = obj.Divisor;
			LuaDLL.lua_pushnumber(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index Divisor on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int get_Amount(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			float ret = obj.Amount;
			LuaDLL.lua_pushnumber(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index Amount on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_KernelTop(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			UnityEngine.Vector3 arg0 = ToLua.ToVector3(L, 2);
			obj.KernelTop = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index KernelTop on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_KernelMiddle(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			UnityEngine.Vector3 arg0 = ToLua.ToVector3(L, 2);
			obj.KernelMiddle = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index KernelMiddle on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_KernelBottom(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			UnityEngine.Vector3 arg0 = ToLua.ToVector3(L, 2);
			obj.KernelBottom = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index KernelBottom on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_Divisor(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			float arg0 = (float)LuaDLL.luaL_checknumber(L, 2);
			obj.Divisor = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index Divisor on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_Amount(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			Colorful.Convolution3x3 obj = (Colorful.Convolution3x3)o;
			float arg0 = (float)LuaDLL.luaL_checknumber(L, 2);
			obj.Amount = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index Amount on a nil value");
		}
	}
}

