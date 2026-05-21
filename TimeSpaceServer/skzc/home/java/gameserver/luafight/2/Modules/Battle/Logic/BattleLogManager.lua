BattleLogManager = {}
local this = BattleLogManager
local isLog = nil
if AppConst and AppConst.isOpenBLog then
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
    -- LogYellow("### BattleLogManager fightData")
    -- WYLog(this.fightdata)
    this.logList = {}
end

function this.Log(...)
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
        file = io.open("../luafight/BattleRecord/log-"..time..".txt", "a")
        platform = "Linux"
    end
    -- local window server   
    if not file then
        file = io.open("luafight/BattleRecord/log-"..time..".txt", "a")
        platform = "Local Windows Server"
    end
    -- local
    if not file then
        file = io.open("BattleRecord/log-"..time..".txt", "a")
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
    file:write("timeStamp: " .. this.timestamp)
    LogYellow("timeStamp: " .. this.timestamp)
    io.close(file)
end

return BattleLogManager   