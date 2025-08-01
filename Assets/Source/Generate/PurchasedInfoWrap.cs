﻿//this source code was auto-generated by tolua#, do not modify it
using System;
using LuaInterface;

public class PurchasedInfoWrap
{
	public static void Register(LuaState L)
	{
		L.BeginClass(typeof(PurchasedInfo), typeof(System.Object));
		L.RegFunction("New", _CreatePurchasedInfo);
		L.RegFunction("__tostring", ToLua.op_ToString);
		L.RegVar("Receipt", get_Receipt, set_Receipt);
		L.RegVar("TransactionId", get_TransactionId, set_TransactionId);
		L.RegVar("ProductId", get_ProductId, set_ProductId);
		L.EndClass();
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int _CreatePurchasedInfo(IntPtr L)
	{
		try
		{
			int count = LuaDLL.lua_gettop(L);

			if (count == 0)
			{
				PurchasedInfo obj = new PurchasedInfo();
				ToLua.PushObject(L, obj);
				return 1;
			}
			else
			{
				return LuaDLL.luaL_throw(L, "invalid arguments to ctor method: PurchasedInfo.New");
			}
		}
		catch (Exception e)
		{
			return LuaDLL.toluaL_exception(L, e);
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int get_Receipt(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			PurchasedInfo obj = (PurchasedInfo)o;
			string ret = obj.Receipt;
			LuaDLL.lua_pushstring(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index Receipt on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int get_TransactionId(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			PurchasedInfo obj = (PurchasedInfo)o;
			string ret = obj.TransactionId;
			LuaDLL.lua_pushstring(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index TransactionId on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int get_ProductId(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			PurchasedInfo obj = (PurchasedInfo)o;
			string ret = obj.ProductId;
			LuaDLL.lua_pushstring(L, ret);
			return 1;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index ProductId on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_Receipt(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			PurchasedInfo obj = (PurchasedInfo)o;
			string arg0 = ToLua.CheckString(L, 2);
			obj.Receipt = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index Receipt on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_TransactionId(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			PurchasedInfo obj = (PurchasedInfo)o;
			string arg0 = ToLua.CheckString(L, 2);
			obj.TransactionId = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index TransactionId on a nil value");
		}
	}

	[MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
	static int set_ProductId(IntPtr L)
	{
		object o = null;

		try
		{
			o = ToLua.ToObject(L, 1);
			PurchasedInfo obj = (PurchasedInfo)o;
			string arg0 = ToLua.CheckString(L, 2);
			obj.ProductId = arg0;
			return 0;
		}
		catch(Exception e)
		{
			return LuaDLL.toluaL_exception(L, e, o, "attempt to index ProductId on a nil value");
		}
	}
}

