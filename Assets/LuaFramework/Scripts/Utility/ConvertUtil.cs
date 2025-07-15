using System;
using System.Collections;
using System.Collections.Generic;
using ResUpdate;
using UnityEngine;

public static class ConvertUtil
{
    public static string ObjToString(object obj)
    {
        return obj.ToString();
    }

    public static ResUpdateProgress ObjToUpdateProgress(object param)
    {
        return param as ResUpdateProgress;
    }

    public static float ObjToFloat(object obj)
    {
        float v = 0;
        if (obj is int) v = (float)(int)obj;
        else if (obj is string) v = StrToFloat((string)obj);
        else if (obj is byte) v = (float)(byte)obj;
        else v = Convert.ToSingle(obj);
        return v;
    }

    public static int ObjToInt(object obj)
    {
        int v = 0;
        if (obj is float)
            v = (int)(float)obj;
        else if (obj is string)
            v = StrToInt((string)obj);
        else if (obj is byte)
            v = (int)(byte)obj;
        else
            v = Convert.ToInt32(obj);
        return v;
    }

    public static long StrToLong(string str)
    {
        return str == null || str.Trim() == "" ? 0 : long.Parse(str.Replace("_", "-"));
    }
    public static int StrToInt(string str)
    {
        return str == null || str.Trim() == "" ? 0 : int.Parse(str.Replace("_", "-"));
    }
    public static byte StrToByte(string str)
    {
        return str == null || str.Trim() == "" ? (byte)0 : byte.Parse(str);
    }
    public static short StrToShort(string str)
    {
        return str == null || str.Trim() == "" ? (short)0 : short.Parse(str.Replace("_", "-"));
    }
    public static float StrToFloat(string str)
    {
        return str == null || str.Trim() == "" ? 0f : float.Parse(str.Replace("_", "-"));
    }

}
