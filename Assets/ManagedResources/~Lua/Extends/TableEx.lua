--[[
 * @Classname TableEx
 * @Description table extension
 * @Date 2019/5/10 20:43
 * @Created by MagicianJoker
--]]

function table.nums(t)
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
    end
    return count
end

function table.insertto(dest, src, begin)
    if begin <= 0 then
        begin = #dest + 1
    end

    local len = #src
    for i = 0, len - 1 do
        dest[i + begin] = src[i + 1]
    end
    return dest
end

function table.indexof(array, value, begin)
    for i = begin or 1, #array do
        if array[i] == value then
            return i
        end
    end
    return false
end

function table.keyof(hashtable, value)
    for k, v in pairs(hashtable) do
        if v == value then
            return k
        end
    end
    return false
end

function table.keyvalueindexof(array, key, value)
    for i = 1, #array do
        if array[i][key] == value then
            return i
        end
    end
    return false
end

function table.removebyvalue(array, value, removeall)
    local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not removeall then
                break
            end
        end
        i = i + 1
    end
    return c
end

function table.walk(t, fn)
    for k, v in pairs(t) do
        fn(v, k)
    end
end

function table.clone(t)
    local ret = {}
    for k, v in pairs(t) do
        ret[k] = v
    end
    return ret
end

function table.merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
    return dest
end

function table.mergeV2(dest, src)
    for k, v in pairs(src) do
        if dest[k] then
            dest[k] = dest[k] + v
        else
            dest[k] = v
        end
    end
    return dest
end

function table.reverse(list, s, e)
    while s<e do
        list[s], list[e] = list[e], list[s]
        s = s+1
        e = e-1
    end
end

--获取table的长度
function LengthOfTable(table)
    local length = 0
    for i, v in pairs(table) do
        length = length + 1
    end
    return length
end

function DelTableByKey(tb, key)
    if type(tb) ~= "table" then
        error("Delete value in table,the tb is not table")
    else
        if tb[key] then
            local i = 1
            for k, v in pairs(tb) do
                if k == key then
                    break
                end
                i = i + 1
            end
            table.remove(tb, i)
        end
    end
end

function TableInsert_CheckRepeat(targetTable, value)
    for i, v in ipairs(targetTable) do
        if v == value then
            return
        end
    end

    table.insert(targetTable, value)
end

function TableMerge(table1, table2, checkRepeat)
    local tempTable = {}
    if table1 ~= nil then
        for i, v in ipairs(table1) do
            if checkRepeat == false then
                table.insert(tempTable, v)
            else
                TableInsert_CheckRepeat(tempTable, v)
            end
        end
    end

    if table2 ~= nil then
        for i, v in ipairs(table2) do
            if checkRepeat == false then
                table.insert(tempTable, v)
            else
                TableInsert_CheckRepeat(tempTable, v)
            end
        end
    end

    return tempTable
end

function Table_DeepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then

            return lookup_table[object]
        end  -- if
        local new_table = {}
        lookup_table[object] = new_table

        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

--搬运深度比较代码 url：http://www.it1352.com/537908.html
function Table_Equal(table1, table2)
    local avoid_loops = {}
    local function recurse(t1, t2)
        -- compare value types
        if type(t1) ~= type(t2) then
            return false
        end
        -- Base case: compare simple values
        if type(t1) ~= "table" then
            return t1 == t2
        end
        -- Now, on to tables.
        -- First, let's avoid looping forever.
        if avoid_loops[t1] then
            return avoid_loops[t1] == t2
        end
        avoid_loops[t1] = t2
        -- Copy keys from t2
        local t2keys = {}
        local t2tablekeys = {}
        for k, _ in pairs(t2) do
            if type(k) == "table" then
                table.insert(t2tablekeys, k)
            end
            t2keys[k] = true
        end
        -- Let's iterate keys from t1
        for k1, v1 in pairs(t1) do
            local v2 = t2[k1]
            if type(k1) == "table" then
                -- if key is a table, we need to find an equivalent one.
                local ok = false
                for i, tk in ipairs(t2tablekeys) do
                    if Table_Equal(k1, tk) and recurse(v1, t2[tk]) then
                        table.remove(t2tablekeys, i)
                        t2keys[tk] = nil
                        ok = true
                        break
                    end
                end
                if not ok then
                    return false
                end
            else
                -- t1 has a key which t2 doesn't have, fail.
                if v2 == nil then
                    return false
                end
                t2keys[k1] = nil
                if not recurse(v1, v2) then
                    return false
                end
            end
        end
        -- if t2 has a key which t1 doesn't have, fail.
        if next(t2keys) then
            return false
        end
        return true
    end
    return recurse(table1, table2)
    --print( Table_Equal({}, {}) )
    --print( Table_Equal({1,2,3}, {1,2,3}) )
    --print( Table_Equal({1,2,3, foo = "fighters"}, {["foo"] = "fighters", 1,2,3}) )
    --print( Table_Equal({{{}}}, {{{}}}) )
    --print( Table_Equal({[{}] = {1}, [{}] = {2}}, {[{}] = {1}, [{}] = {2}}) )
    --print( Table_Equal({a = 1, [{}] = {}}, {[{}] = {}, a = 1}) )
    --print( Table_Equal({a = 1, [{}] = {1}, [{}] = {2}}, {[{}] = {2}, a = 1, [{}] = {1}}) ) --TODO:`false` under Lua 5.2

    --print( not Table_Equal({1,2,3,4}, {1,2,3}) )
    --print( not Table_Equal({1,2,3, foo = "fighters"}, {["foo"] = "bar", 1,2,3}) )
    --print( not Table_Equal({{{}}}, {{{{}}}}) )
    --print( not Table_Equal({[{}] = {1}, [{}] = {2}}, {[{}] = {1}, [{}] = {2}, [{}] = {3}}) )
    --print( not Table_Equal({[{}] = {1}, [{}] = {2}}, {[{}] = {1}, [{}] = {3}}) )
end