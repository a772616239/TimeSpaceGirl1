--输出日志--
function Log(str)
    if LogModeLevel == 0 then
        Util.Log(debug.traceback(str))
    end
end

--警告日志--
function LogWarn(str)
    if LogModeLevel >= 0 and LogModeLevel <= 1 then
        Util.LogWarning(debug.traceback(str))
    end
end

--错误日志--
function LogError(str)
    if LogModeLevel <= 2 and LogModeLevel >= 0 then
        Util.LogError(debug.traceback(str))
    end
end


-- 有颜色的log可自定义
-- 
function LogRed( str )
    Log("<color=#f00>"..str.."</color>")
end
function LogGreen( str )
    Log("<color=#0f0>"..str.."</color>")
end
function LogBlue( str )
    Log("<color=#00f>"..str.."</color>")
end
function LogPink(str)
    Log("<color=#FF7AD7>"..str.."</color>")
end
function LogYellow(str)
    Log("<color=yellow>"..str.."</color>")
end
function LogPurple(str)
    Log("<color=purple>"..str.."</color>")
end

--带有颜色的打印 只支持2 4参数个数("red","")  ("red","","#FFFFFF","")
function LogColor(...)
    local args={...}
    if #args==2 then
        Log("<color="..args[1]..">"..args[2].."</color>")
    elseif #args==4 then
        Log("<color="..args[1]..">"..args[2].."</color>".."  <color="..args[3]..">"..args[4].."</color>")
    end
end

local isEditor = AppConst and AppConst.Platform == "EDITOR"
local IsWriteFileOpen = false
local IsWriteFile = isEditor and IsWriteFileOpen
local file = nil
if IsWriteFile then file = io.open("LuaLog.txt", "w") end
local function PrintWrite(...)
    print(...)
    if not file and not IsWriteFile then
        return
    end
    for i, v in ipairs({...}) do
        file:write(tostring(v))
    end
    file:write("\n")
    file:flush()
end

local print = PrintWrite


local function GetDebugIsOpen()
    local DebugLogOpen = nil
    if AppConst and AppConst.isOpenTLog ~= nil then
        DebugLogOpen = AppConst.isOpenTLog
    else
        DebugLogOpen = false
    end
    return DebugLogOpen
end

-- 个人log开关
local LOGCOFIG = {
    SYS = true,
    WY = true,
    WK = false,
    JYH = false,
    HXC = false, 
}

local function logProtoPkg(LOGPrefix, prtPkg , deep)
    local tDeep = deep or 0
    local space = string.rep(' ', 4)
  
    local pkgStr = tostring(prtPkg)
    local splitTab = string.split(pkgStr,'\n')
    for i,v in ipairs(splitTab) do
        print(string.format(LOGPrefix .. "%s%s",string.rep(space, tDeep),v))
    end
end
  
  -- 判断是否是protoTable
local function isProtoTable( tab )
    local bbb = tostring(tab)
    local hasTable = string.find(bbb, "table:")
    if hasTable ~= nil and hasTable == 1 then
        return false
    end
    return true
end

local function logTab(LOGPrefix, tab)
    if type(tab) ~= "table" then
        print(tostring(tab))
        return
    end

    -- 防止proto死循环
    if isProtoTable(tab) then
        print(LOGPrefix .. "Proto-Table")
        print(LOGPrefix .. "{")
        logProtoPkg(LOGPrefix,tab,1)
        print(LOGPrefix .. "}")
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
                local isProto = isProtoTable(v)
                
                if isProto then
                    print(string.format(LOGPrefix .. "%s[%s] => Proto-Table",string.rep(space, deep),key))
                    print(string.format(LOGPrefix .. "%s{",string.rep(space, deep)))
                    logProtoPkg(LOGPrefix,v,deep+1)
                    print(string.format(LOGPrefix .. "%s}", string.rep(space, deep)))
                else
                    print(string.format(LOGPrefix .. "%s[%s] => Table",string.rep(space, deep),key))
                    print(string.format(LOGPrefix .. "%s{",string.rep(space, deep)))
                    deep = deep + 1
                    _dump(v)
                    deep = deep - 1
                    print(string.format(LOGPrefix .. "%s}", string.rep(space, deep)))
                end
            else
                if type(v) ~= "string" then
                    v = tostring(v)
                end
                print(string.format(LOGPrefix .. "%s[%s] => %s", string.rep(space, deep), key, v))
            end
        end
    end

    print(string.format(LOGPrefix .. "Table"))
    print(LOGPrefix .. "{")
    _dump(tab)
    print(string.format(LOGPrefix .. "}\n"))
end

local function PLog(LOGPrefix, fmt, ...)
    if not GetDebugIsOpen() then
        return
    end

    if type(fmt) == "table" then
        logTab(LOGPrefix, fmt)
    elseif type(fmt) == "boolean" or type(fmt) == "nil" or type(fmt) == "function" or type(fmt) == "userdata" then
        print(LOGPrefix, fmt)
    else
        local r, r1, r2 = pcall(string.format, fmt, ...)
        if r then
            print(LOGPrefix .. r1)
        else
            print(LOGPrefix .. "ERROR FORMAT", r1, r2)
        end
    end
end

function SYSLog(fmt, ...)
    if LOGCOFIG["SYS"] == false then
        return
    end
    PLog("[SYSLog] ", fmt, ...)
end

function WYLog(fmt, ...)
    if LOGCOFIG["WY"] == false then
        return
    end
    PLog("[WYLog] ", fmt, ...)
end

function WKLog(fmt, ...)
    if LOGCOFIG["WK"] == false then
        return
    end
    PLog("[WKLog] ", fmt, ...)
end

function JYHLog(fmt, ...)
    if LOGCOFIG["JYH"] == false then
        return
    end
    PLog("[JYHLog] ", fmt, ...)
end
function HXCLog(fmt, ...)
    if LOGCOFIG["HXC"] == false then
        return
    end
    PLog("[HXCLog] ", fmt, ...)
end