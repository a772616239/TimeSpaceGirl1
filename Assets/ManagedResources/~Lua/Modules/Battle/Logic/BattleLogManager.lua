BattleLogManager = {}
local this = BattleLogManager
local isLog = nil
if AppConst and AppConst.isOpenBLog ~= nil then
    isLog = AppConst.isOpenBLog
else
    isLog = true    --< 服务端跑战斗开启
end

local function pairsByKeys(t)
    local a = {}
    for n in pairs(t) do
        if n then
            a[#a+1] = n
        end
    end
    table.sort(a, function( op1, op2 )
        local type1, type2 = type(op1), type(op2)
        local num1,  num2  = tonumber(op1), tonumber(op2)

        if ( num1 ~= nil) and (num2 ~= nil) then
            return  num1 < num2
        elseif type1 ~= type2 then
            return type1 < type2
        elseif type1 == "string"  then
            return op1 < op2
        elseif type1 == "boolean" then
            return op1
            -- 以上处理: number, string, boolean
        else -- 处理剩下的:  function, table, thread, userdata
            return tostring(op1) < tostring(op2)  -- tostring后比较字符串
        end
    end)
    local i = 0
    return function()
        i = i + 1
        return a[i], t[a[i]]
    end
end
function this.PrintBattleTable(tb)
    local indent_str = "{"
    local count = 0
    for k,v in pairs(tb) do
        count = count + 1
    end
    for k=1, #tb do
        local v = tb[k]
        if type(v) == "table" then
            indent_str = indent_str .. this.PrintBattleTable(v)
        elseif type(v) == "string" then
            indent_str = indent_str .. "\""..tostring(v) .. "\""
        else
            indent_str = indent_str .. tostring(v)
        end
        if k < count then
            indent_str = indent_str..","
        end
    end

    local index = 0
    for k,v in pairsByKeys(tb) do
        index = index + 1
        if type(k) ~= "number" then
            if type(v) == "table" then
                indent_str = string.format("%s%s=%s", indent_str, tostring(k), this.PrintBattleTable(v))
            elseif type(v) == "string" then
                indent_str = string.format("%s%s=\"%s\"", indent_str, tostring(k), tostring(v))
            else
                indent_str = string.format("%s%s=%s", indent_str, tostring(k), tostring(v))
            end
            if index < count then
                indent_str = indent_str .. ","
            end
        end
    end
    indent_str = indent_str .. "}"
    return indent_str
end
--
function this.Init(fightdata)
    this.timestamp = Random.GetSeed()
    this.fightdata = fightdata  
    this.logList = {}
    this.logListCa = {}
end

function this.Log(...)
    -- Log(...)
    if not isLog then return end
    local args = {...}
    local log = args[1] .. ":\n"
    log = log .. string.format("%s = %s, ", "frame", BattleLogic.CurFrame())
    for i = 2, #args, 2 do
        local key = args[i]
        local value = args[i + 1]
        log = log .. string.format("%s = %s, ", key, value)
    end
    table.insert(this.logList, log)
end

function this.WriteFile()
    
    if not isLog then return end
    local time = string.format("%d-%d-%d-%d-%d-%d",
        os.date("%Y"),
        os.date("%m"),
        os.date("%d"),
        os.date("%H"),
        os.date("%M"),
        os.date("%S"))
    local file
    local platform
    -- linux   
    if not file then
        file = io.open("../luafight/BattleRecord/log-ServerFightData-"..time..".txt", "a")
        platform = "Linux"
    end
    -- local window server   
    if not file then
        file = io.open("luafight/BattleRecord/log-ServerFightData-"..time..".txt", "a")
        platform = "Local Windows Server"
    end
    -- local
    if not file then
        file = io.open("BattleRecord/log-ServerFightData-"..time..".txt", "a")
        platform = "Local"
    end
    
    file:write(platform..":\n\n\n")
    for i = 1, #this.logList do
        file:write(this.logList[i].."\n")
    end
    file:write("\n\n\n\n\n")
    file:write("fightData:\n")
    file:write(this.PrintBattleTable(this.fightdata))
    file:write("\n\n")
    
    
    -- this.PLog(file, "S ", this.fightdata)
    file:write("\n\n")
    file:write("timeStamp: " .. this.timestamp)
    
    io.close(file)

end



function this.logProtoPkg(file, LOGPrefix, prtPkg , deep)
    local tDeep = deep or 0
    local space = string.rep(' ', 4)
  
    local pkgStr = tostring(prtPkg)
    local splitTab = string.split(pkgStr,'\n')
    for i,v in ipairs(splitTab) do
        file:write(string.format(LOGPrefix .. "%s%s",string.rep(space, tDeep),v))
        file:write("\n")
    end
end
  
  -- 判断是否是protoTable
function this.isProtoTable( tab )
    local bbb = tostring(tab)
    local hasTable = string.find(bbb, "table:")
    if hasTable ~= nil and hasTable == 1 then
        return false
    end
    return true
end

function this.logTab(file, LOGPrefix, tab)
    if type(tab) ~= "table" then
        file:write(tostring(tab))
        file:write("\n")
        return
    end

    -- 防止proto死循环
    if this.isProtoTable(tab) then
        file:write(LOGPrefix .. "Proto-Table")
        file:write("\n")
        file:write(LOGPrefix .. "{")
        file:write("\n")
        this.logProtoPkg(file, LOGPrefix,tab,1)
        file:write(LOGPrefix .. "}")
        file:write("\n")
        return
    end

    local space, deep = string.rep(" ", 4), 1
    local function _dump(t)
        for k, v in pairs(t) do
            local key = tostring(k)
            if key == "class" or key == "_listener_for_children" or key == "_message_descriptor" or key == "_listener" then
                --todo
            elseif type(v) == "table" then
                -- 防止proto死循环
                local isProto = this.isProtoTable(v)
                
                if isProto then
                    file:write(string.format(LOGPrefix .. "%s[%s] => Proto-Table",string.rep(space, deep),key))
                    file:write("\n")
                    file:write(string.format(LOGPrefix .. "%s{",string.rep(space, deep)))
                    file:write("\n")
                    this.logProtoPkg(file, LOGPrefix,v,deep+1)
                    file:write(string.format(LOGPrefix .. "%s}", string.rep(space, deep)))
                    file:write("\n")
                else
                    file:write(string.format(LOGPrefix .. "%s[%s] => Table",string.rep(space, deep),key))
                    file:write("\n")
                    file:write(string.format(LOGPrefix .. "%s{",string.rep(space, deep)))
                    file:write("\n")
                    deep = deep + 1
                    _dump(v)
                    deep = deep - 1
                    file:write(string.format(LOGPrefix .. "%s}", string.rep(space, deep)))
                    file:write("\n")
                end
            else
                if type(v) ~= "string" then
                    v = tostring(v)
                end
                file:write(string.format(LOGPrefix .. "%s[%s] => %s", string.rep(space, deep), key, v))
                file:write("\n")
            end
        end
    end

    file:write(string.format(LOGPrefix .. "Table"))
    file:write("\n")
    file:write(LOGPrefix .. "{")
    file:write("\n")
    _dump(tab)
    file:write(string.format(LOGPrefix .. "}\n"))
    file:write("\n")
end

function this.PLog(file, LOGPrefix, fmt, ...)

    if type(fmt) == "table" then
        this.logTab(file, LOGPrefix, fmt)
    elseif type(fmt) == "boolean" or type(fmt) == "nil" or type(fmt) == "function" or type(fmt) == "userdata" then
        file:write(LOGPrefix, fmt)
        file:write("\n")
    else
        local r, r1, r2 = pcall(string.format, fmt, ...)
        if r then
            file:write(LOGPrefix .. r1)
            file:write("\n")
        else
            file:write(LOGPrefix .. "ERROR FORMAT", r1, r2)
            file:write("\n")
        end
    end
end

--> 输出战斗log
function this.WriteServerFightData(data, time, sign)
    if not isLog then return end
    local file
    local platform
    -- linux   
    if not file then
        file = io.open("../luafight/BattleRecord/log-ServerFightData" .. time .. "_" .. sign .. ".txt", "a+")
        platform = "Linux"
    end
    -- local window server   
    if not file then
        file = io.open("luafight/BattleRecord/log-ServerFightData" .. time .. "_" .. sign .. ".txt", "a+")
        platform = "Local Windows Server"
    end
    -- local
    if not file then
        file = io.open("BattleRecord/log-ServerFightData" .. time .. "_" .. sign .. ".txt", "a+")
        platform = "Local"
    end

    file:write(platform..":\n\n\n")

    file:write(this.PrintBattleTable(data))
    file:write("\n\n")
    file:write("timeStamp: " .. Random.GetSeed())
    io.close(file)
end

--> 用于战斗log标识
function this.WriteServerFightDataB(time, sign)
    if not isLog then return end
    local file
    local platform
    -- linux   
    if not file then
        file = io.open("../luafight/BattleRecord/log-ServerFightData" .. time .. "_" .. sign .. ".txt", "a+")
        platform = "Linux"
    end
    -- local window server   
    if not file then
        file = io.open("luafight/BattleRecord/log-ServerFightData" .. time .."_" .. sign .. ".txt", "a+")
        platform = "Local Windows Server"
    end
    -- local
    if not file then
        file = io.open("BattleRecord/log-ServerFightData" .. time .."_" .. sign .. ".txt", "a+")
        platform = "Local"
    end

    file:write(platform..":\n\n\n")

    file:write(sign)
    file:write("\n\n")
    file:write("timeStamp: " .. Random.GetSeed())
    io.close(file)
end

function this.LogCa(...)
    if not isLog then return end
    local args = {...}
    local log = args[1] .. ":\n"
    log = log .. string.format("%s = %s, ", "frame", BattleLogic.CurFrame())
    for i = 2, #args, 2 do
        local key = args[i]
        local value = args[i + 1]
        log = log .. string.format("%s = %s, ", key, value)
    end
    table.insert(this.logListCa, log)
end

return BattleLogManager   