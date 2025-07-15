using System.Collections;
using LuaInterface;
using GameLogic;

public static class LuaUtil
{
    static public LuaTable CreateLuaTable()
    {
        return  LuaManager.Instance.DoString<LuaTable>("return {}");
    }

    static public LuaTable CreateLuaTable(IEnumerable objs)
    {
        var table = CreateLuaTable();
        int index = 0;
        foreach (var obj in objs)
        {
            table[index.ToString()] = obj;
            index++;
        }
        return table;
    }

    static public LuaTable CreateLuaTable(IList objs)
    {
        var table = CreateLuaTable();
        int index = 0;
        foreach (var obj in objs)
        {
            table[index.ToString()] = obj;
            index++;
        }
        return table;
    }

    static public LuaTable CreateLuaTable(IDictionary objs)
    {
        var table = CreateLuaTable();

        foreach (var key in objs.Keys)
        {
            if (key is int) 
            {
                table[ConvertUtil.ObjToInt(key)] = objs[key];
            }
            else if(key is string)
            {
                if(key!=null)
                    table[key.ToString()] = objs[key];
            }
            else
            {
                
            }
        }
        return table;
    }

    public static LuaTable toLuaTable(this IEnumerable objs)
    {
        return CreateLuaTable(objs);
    }

    public static LuaTable toLuaTable(this IList objs)
    {
        return CreateLuaTable(objs);
    }

    public static LuaTable toLuaTable(this IDictionary objs)
    {
        return CreateLuaTable(objs);
    }
}

