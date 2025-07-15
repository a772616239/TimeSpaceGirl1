-- windows
package.path = package.path ..';luafight/?.lua';
-- linux
package.path = package.path ..';../luafight/?.lua';

require("Modules.Battle.Logic.Misc.BattleDefine")
require("Modules.Battle.Logic.Misc.BattleUtil")
require("Modules.Battle.Logic.Misc.BattleQueue")
require("Modules.Battle.Logic.Misc.BattleDictionary")
require("Modules.Battle.Logic.Misc.BattleList")
require("Modules.Battle.Logic.Misc.BattleObjectPool")

require("Modules.Battle.Logic.Base.BattleEvent")
require("Modules.Battle.Logic.Base.Random")

require("Modules.Battle.Logic.Base.RoleData")
require("Modules.Battle.Logic.Base.Buff")
require("Modules.Battle.Logic.Base.Skill")
require("Modules.Battle.Logic.Base.Passivity")

require("Modules.Battle.Logic.BattleLogic")
require("Modules.Battle.Logic.RoleLogic")

require("Modules.Battle.Logic.SkillManager")
require("Modules.Battle.Logic.RoleManager")
require("Modules.Battle.Logic.OutDataManager")
require("Modules.Battle.Logic.BattleLogManager")
require("Modules.Battle.Logic.FightUnitLogic")
require("Modules.Battle.Logic.FightUnitManager")

require("Modules.Language")
require("Modules.Debug")


local BattleMain = {}
local BattleLogic = BattleLogic
local Random = Random
local BattleRecord

local _BattleErrorCache = {}
local _BattleErrorIndex = 0
local _seed
local _type
local _maxRound
local _fightData
local _optionData

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

local function PrintTable(tb)
    local indent_str = "{"
    local count = 0
    for k,v in pairs(tb) do
        count = count + 1
    end
    for k=1, #tb do
        local v = tb[k]
        if type(v) == "table" then
            indent_str = indent_str .. PrintTable(v)
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
                indent_str = string.format("%s%s=%s", indent_str, tostring(k), PrintTable(v))
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

local function generateRecordFile()
    local time = string.format("%d-%d-%d-%d-%d-%d",
            os.date("%Y"),
            os.date("%m"),
            os.date("%d"),
            os.date("%H"),
            os.date("%M"),
            os.date("%S"))
    -- local file = io.open("luafight/BattleRecord/"..time..".txt", "a")
    -- local record = BattleLogic.GetRecord()
    -- for i=1, #record do
    --     file:write(record[i].."\n")
    -- end
    -- io.close(file)
end


local function addBattleData()
    local str = ""
    str = str.."seed:\n"..tostring(_seed).."\n"
    str = str.."type:\n"..tostring(_type).."\n"
    str = str.."fightData:\n"..PrintTable(_fightData).."\n"
    str = str.."optionData:\n"..PrintTable(_optionData).."\n"

    _BattleErrorIndex = _BattleErrorIndex + 1
    if _BattleErrorIndex > 5 then
        _BattleErrorIndex = 1
    end
    _BattleErrorCache[_BattleErrorIndex] = str
end

local function AddRecord(fightData)
    BattleRecord = {}
    BattleLogic.Event:AddEvent(BattleEventName.AddRole, function (role)
        local record = {}
        record.uid = role.uid
        record.camp = role.camp
        record.damage = 0
        role.Event:AddEvent(BattleEventName.RoleDamage, function (defRole, damage, bCrit, finalDmg)
            record.damage = record.damage + finalDmg
        end)
        BattleRecord[role.uid] = record
    end)

    for i=1, #fightData.playerData.teamSkill do
        local teamCaster = BattleLogic.GetTeamSkillCaster(0)
        local teamSkill = fightData.playerData.teamSkill[i]
        local teamType = math.floor(teamSkill[1] / 100)

        local str = "order:1".."camp:"..teamCaster.camp.." team"..teamSkill[1]

        local record = {}
        record.uid = str
        record.camp = teamCaster.camp
        record.damage = 0
        record.order = 1

        local curSkill
        teamCaster.Event:AddEvent(BattleEventName.SkillCast, function (skill)
            if skill.owner.camp == record.camp then
                curSkill = skill
            end
        end)
        teamCaster.Event:AddEvent(BattleEventName.RoleDamage, function (defRole, damage, bCrit, finalDmg)
            if curSkill and curSkill.teamSkillType == teamType then
                record.damage = record.damage + finalDmg
            end
        end)
        BattleRecord[str] = record
    end

    for i=1, #fightData.enemyData do
        for j=1, #fightData.enemyData[i].teamSkill do
            local teamCaster = BattleLogic.GetTeamSkillCaster(1)
            local teamSkill = fightData.enemyData[i].teamSkill[j]
            local teamType = math.floor(teamSkill[1] / 100)

            local str = "order:"..i.."camp:"..teamCaster.camp.." team"..teamSkill[1]

            local record = {}
            record.uid = str
            record.camp = teamCaster.camp
            record.damage = 0
            record.order = i

            local curSkill
            teamCaster.Event:AddEvent(BattleEventName.SkillCast, function (skill)
                if skill.owner.camp == record.camp then
                    curSkill = skill
                end
            end)
            teamCaster.Event:AddEvent(BattleEventName.RoleDamage, function (defRole, damage, bCrit, finalDmg)
                if curSkill and curSkill.teamSkillType == teamType and record.order == BattleLogic.CurOrder then
                    record.damage = record.damage + finalDmg
                end
            end)
            BattleRecord[str] = record
        end
    end
end


function BattleMain.Simple()
   local fightData =
    {enemyData={{
        {ai={0},camp=1,size=1,element=1,passivity={{{309,309},{4,5,0,5,1,0.12},{4,5,0,9,1,0.1}},{{369},{18,1,0.2,2}},{{357},{0.2,3}},{{368},{2,4,0.2}},{{360},{0.2,4,4,0.1,2}},{{385},{2,22,1,0.01,10}}},passivityIds={"20523","20543","60423","60152","60332","60181","60042","810151"},position=1,professionId=2,property={"246","667874","667874","91279","1673","0","1716","0.21","0.05","1.094","0.03","0.29","1.79","0.04","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.03","0.03","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10006,round=0,skillArray={{"20501",0.8,{0},1,1400,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"20513",1.32,{0},1,2300,0,"0",{cd=1,isCannon=0,release=1,slot=1},{200004,{1,1,2},{261,0.6,1,1,0.2,2}}},{"20533",1.3,{0.233,0.233},3,2700,0,"0",{cd=3,isCannon=0,release=2,slot=3},{200002,{1,2.3,2},{265,4,5,0.4,1,1,2}}}},type=1},
        {ai={0},camp=1,size=1,element=3,passivity={{{308},{0.1,8,1,22,9,0.09,2,8,0.2,2}},{{369},{18,1,0.2,2}},{{357},{0.2,3}},{{368},{2,4,0.2}},{{360},{0.2,4,4,0.1,2}},{{378},{0.26,0.08,1.2}},{{385},{2,22,1,0.01,10}}},passivityIds={"12423","12443","60423","60152","60332","60181","60042","90302","810151"},position=2,professionId=2,property={"246","680858","680858","84703","1770","0","1727","0.21","0.05","1.094","0.03","0.3623","1.8291","0.04","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.03","0.03","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10036,round=0,skillArray={{"12401",0.85,{0},1,1900,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"12413",0.9,{0},1,2400,0,"0",{cd=3,isCannon=0,release=1,slot=1},{200921,{1,2.61,2},{246,3,0.1,2}}},{"12433",3,{0.3,0.3,0.3,0.3,0.3},6,6200,0,"0",{cd=3,isCannon=0,release=2,slot=3},{240000,{235,4,5,1,0.2},{1,2.07,2},{254,0.9,1,4,4,0.2,2,9}}}},type=3},
        {ai={0},camp=1,size=1,element=3,passivity={{{369},{18,1,0.2,2}},{{357},{0.2,3}},{{368},{2,4,0.2}},{{360},{0.2,4,4,0.1,2}},{{385},{2,4,1,10,10}}},passivityIds={"10323","60423","60152","60332","60181","60042","810351"},position=3,professionId=2,property={"246","674622","674622","86345","1747","0","1798","0.21","0.05","1.04","0.03","0.29","1.79","0.04","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.084","0.03","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10039,round=0,skillArray={{"10301",0.62,{0},1,1400,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"10313",0.6,{0.233,0.233,0.233,0.233},5,1800,0,"0",{cd=1,isCannon=0,release=1,slot=1},{200000,{1,1.14,2},{259,0.45,1,1,3,0.1,22,3,0.1,2}}},{"10333",2,{0.333,0.333},3,2800,0,"0",{cd=3,isCannon=0,release=2,slot=3},{200004,{1,1.36,2},{230,1,0.5,8,3}}}},type=3},
        {ai={0},camp=1,size=1,element=5,passivity={{{347},{5,1,0.15}},{{369},{17,1,0.2,2}},{{368},{2,4,0.2}},{{358},{12,0.3,0.2,1,2}},{{377},{0.031,5}},{{385},{2,23,1,0.01,10}}},passivityIds={"50723","50743","60413","60092","60332","60161","60052","90202","810251"},position=5,professionId=3,property={"246","829392","829392","90403","1924","0","1780","0.21","0.104","1.04","0.03","0.29","1.79","0.04","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.03","0.03","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10082,round=0,skillArray={{"50701",0.35,{0},1,1200,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"50713",0.73,{0},1,1400,0,"0",{cd=3,isCannon=0,release=1,slot=1},{200003,{1,1.71,1},{261,0.72,3,1,0.15,2}}},{"50733",0.6,{0.1,0.1,0.1,0.6,0.1,0.55},7,2700,0,"0",{cd=3,isCannon=0,release=2,slot=3},{400000,{264,3,1,6,3,0.2},{1,3.75,1},{216,0}}}},type=5},
        {ai={0},camp=1,size=1,element=4,passivity={{{330},{0.6,1,2,3,0.4,3}},{{369},{6,1,0.3,2}},{{365},{0.45,4}},{{366},{12,0.04}},{{377},{0.031,5}},{{385},{2,27,1,0.01,10}}},passivityIds={"40323","40343","60353","60232","60252","60241","60312","90202","810651"},position=8,professionId=4,property={"246","810794","810794","74754","1853","0","1811","0.1","0.16","1.04","0.03","0.18","1.57","0.15","0.054","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.03","0.14","0.0","0.0","0.0","0.0","0.0","0.054","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10061,round=0,skillArray={{"40301",0.44,{0},1,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"40313",1.4,{0.15,0.15,0.15,0.15,0.35},6,2500,0,"0",{cd=3,isCannon=0,release=1,slot=1},{240000,{1,1.18,2},{254,0.76,1,2,4,0.4,2}}},{"40333",2.1,{0},1,2450,0,"0",{cd=3,isCannon=0,release=2,slot=3},{100000,{24,1,1.43},{211,1,1,22,1,0.25,2}}}},type=4},teamPassive={},teamSkill={}}},
        fightUnitData={{},{},{},{},{},{}},
        playerData={
        {camp=0,size=1,element=4,passivity={},passivityIds={"40423"},position=2,professionId=1,property={255,806590,806590,60525,1890,0,1696,0,0.23,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10062,skillArray={{"40401",0.4,{0},1,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"40413",0.57,{0.2,0.2},3,2200,0,"0",{cd=3,isCannon=0,release=1,slot=1},{200000,{1,0.99,1},{3,0.3,1,2}}},{"40433",2,{0.4},2,3000,0,"0",{cd=3,isCannon=0,release=2,slot=3},{100000,{213,1,2,12,0.2}}}},type=1},
        {camp=0,size=1,element=4,passivity={{{331},{12,0.3}},{{332},{0.6,1.2,1}},{{302},{1,1,1,1}}},passivityIds={"40523","40533","40543"},position=4,professionId=3,property={255,608838,608838,96172,1802,0,1642,0,0.03,1,0,0.2,1.7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10063,skillArray={{"40501",0.4,{0},1,1100,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"40513",1.6,{0.15,0.15,0.15,0.15,0.15},6,3000,0,"0",{cd=1,isCannon=0,release=1,slot=1},{400000,{240,5,6,3,0.25},{260,1,1,23,3,0.4},{10,2.31,1,0.3}}}},type=1},
        {camp=0,size=1,element=4,passivity={{{338,338,339},{4,22,1,0.09},{4,15,1,0.09},{1,0.15}}},passivityIds={"41523","41543"},position=6,professionId=3,property={255,697917,697917,100826,1806,0,1672,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10057,skillArray={{"41501",0.45,{0},1,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"41513",2.1,{0.15,0.15,0.15,0.15},5,5500,0,"0",{cd=3,isCannon=0,release=1,slot=1},{270000,{1,2.07,1}},{270321,{261,0.6,6,12,0.07,2}}},{"41533",0.75,{0.43,0.83,0.4},4,4200,0,"0",{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.51,1}},{200211,{211,1,1,6,3,0.2,2}},{200221,{3,0.5,4,2}}}},type=1},
        {camp=0,size=1,element=4,passivity={{{328},{1,2.41,1}}},passivityIds={"40123","40143"},position=7,professionId=4,property={255,727413,727413,89512,1837,0,1667,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10059,skillArray={{"40101",0.65,{0},1,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"40113",1.05,{0},1,1600,0,"0",{cd=3,isCannon=0,release=1,slot=1},{100324,{208,1,1,0,6},{211,1,1,22,1,0.25,2},{236,4,9,1,0.2,2}}},{"40133",1.7,{0},1,2300,0,"0",{cd=3,isCannon=0,release=2,slot=3},{100000,{253,20,1,0.15,2,1,0.98}}}},type=1},
        {camp=0,size=1,element=4,passivity={{{334},{1,0.5,1,10,2}}},passivityIds={"40723","40743"},position=9,professionId=2,property={255,689833,689833,97764,1768,0,1682,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10065,skillArray={{"40701",0.53,{0},1,1200,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"40713",1.4,{0.08,0.08,0.24},4,3100,0,"0",{cd=3,isCannon=0,release=1,slot=1},{200000,{1,1.28,2},{254,0.5,1,5,4,0.1,3}}},{"40733",3.65,{0.397,0.66},3,6300,0,"0",{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.51,2},{230,5,0.45,1,2},{231,5,0.2,1,2}}}},type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={}}    
    local op1 = {seed=1661757743, type=1, maxTime=300}
    BattleMain.Execute(op1,fightData,"")
    
end

--简单清除事件
function BattleMain.SimpleClean()
    BattleLogic.Clear()
end

function BattleMain.ExecuteProtect(args, fightData, optionData)
    _seed = args.seed
    _type = args.type
    _maxRound = args.maxRound
    _fightData = fightData
    _optionData = optionData or {}

    --该开关用于输出战斗过程中的日志，用于验证前后端是否出现战斗不同步
    --BattleLogic.IsOpenBattleRecord = true
    local time = string.format("%d-%d-%d-%d-%d-%d",
            os.date("%Y"),
            os.date("%m"),
            os.date("%d"),
            os.date("%H"),
            os.date("%M"),
            os.date("%S"))

        Random.SetSeed(args.seed)
        BattleLogManager.WriteServerFightData(fightData, time, "BEGINP "..BattleLogic.Type)
        BattleLogic.Init(fightData, optionData, _maxRound)
        BattleLogic.Type = _type
        if _type == 9 or _type == 10 or _type == 11 or _type == 14 then
            AddRecord(fightData)
        end

        local _new_productor

        local function send(x)
            coroutine.yield(x)
        end       

        local function productor()
            local i = 0
            while not BattleLogic.IsEnd do
                i = i + 1
                i = BattleLogic.Update()
                if i > 30000 then -- 防卡死跳锁次数
                    BattleLogic.IsEnd=true
                end
                send(i)
            end
        end

       local function receive()
            local status,value = coroutine.resume( _new_productor)
                if status then
                    --LogError("status true".." value "..value)
                else
                    --LogError("status false".." value "..value) 
                    BattleLogic.IsEnd=true
                end
            -- end
            return value
       end

       local function consumer()
            while not BattleLogic.IsEnd do
                 local i = receive()     -- 从生产者那里得到物品              
            end
       end

       BattleLogic.StartOrder()
       _new_productor = coroutine.create(productor)
       consumer()       

end

function BattleMain.Execute(args, fightData, optionData)
    -- collectgarbage("collect")
    -- print("内存为：", collectgarbage("count"))--输出当前内存占用
    _seed = args.seed
    _type = args.type
    _maxRound = args.maxRound
    _fightData = fightData
    _optionData = optionData or {}

    --该开关用于输出战斗过程中的日志，用于验证前后端是否出现战斗不同步
    --BattleLogic.IsOpenBattleRecord = true
    local time = string.format("%d-%d-%d-%d-%d-%d",
            os.date("%Y"),
            os.date("%m"),
            os.date("%d"),
            os.date("%H"),
            os.date("%M"),
            os.date("%S"))

    local isError = false
    local errorCache
    if xpcall(function ()
       BattleMain.ExecuteProtect(args, fightData, optionData)
    end, function (err)
        isError = true
        errorCache = "error:\n"..debug.traceback(err).."\n"
    end) then
        -- BattleLogic.useTimes = 10
        BattleLogManager.WriteServerFightDataB(time, "NormalBEGINP")
        local resultList = {0, 0, 0, 0, 0, 0, 0, 0, 0}
        local enemyList = {0, 0, 0, 0, 0, 0, 0, 0, 0}    
        local _mytibuList ={0, 0, 0, 0, 0, 0, 0, 0, 0} 
        local _enemytibuList ={0, 0, 0, 0, 0, 0, 0, 0, 0} 
        local _hpRecord ={}    
        if BattleLogic.Result == 1 then --胜利记录我方剩余血量
            local arr = RoleManager.Query(function (r) return r.camp == 0 end, true)
            local _earr = RoleManager.Query(function (r) return r.camp == 1 end, true)
            for i=1, #arr do
                local pos = arr[i].position
                resultList[pos] = arr[i]:GetRoleData(RoleDataName.Hp)
            end
            for i=1, #_earr do
                local pos = _earr[i].position
                enemyList[pos] = _earr[i]:GetRoleData(RoleDataName.Hp)
            end
            for i=1, #resultList do
                local _set = "1my hp:"..tostring(resultList[i]).." "..i
                table.insert(_hpRecord,_set)
            end
            for i=1, #enemyList do
                local  _set = "1enemy hp:"..tostring(enemyList[i]).." "..i
                table.insert(_hpRecord,_set)
            end       
        elseif BattleLogic.Result == 0 then  --失败记录敌方剩余血量
            local arr = RoleManager.Query(function (r) return r.camp == 1 end, true)
            local _earr = RoleManager.Query(function (r) return r.camp == 0 end, true)
            for i=1, #arr do
                local pos = arr[i].position
                resultList[pos] = arr[i]:GetRoleData(RoleDataName.Hp)
            end
            for i=1, #_earr do
                local pos = _earr[i].position
                enemyList[pos] = _earr[i]:GetRoleData(RoleDataName.Hp)
            end
            for i=1, #resultList do            
                local _set = "0my hp:"..tostring(resultList[i]).." "..i
                table.insert(_hpRecord,_set)
            end
            for i=1, #enemyList do               
                local  _set = "0enemy hp:"..tostring(enemyList[i]).." "..i
                table.insert(_hpRecord,_set)
            end 
        end    
        -- 返回替补数据
        local arrTibu = RoleManager.QueryTibu(function (r) return r.camp == 0 end, true)
        local _earrTibu = RoleManager.QueryTibu(function (r) return r.camp == 1 end, true)
        if #arrTibu > 0 then
         resultList.mytibu=arrTibu[1]:GetRoleData(RoleDataName.Hp)
            if RoleManager.getTibuStateByCamp(0) == 4 or RoleManager.getTibuStateByCamp(0) == 2 then
                resultList.mytibuPos=arrTibu[1].position
            else
                resultList.mytibuPos = -1
            end
        end
        if #_earrTibu > 0 then
          resultList.enemytibu=_earrTibu[1]:GetRoleData(RoleDataName.Hp)
            if RoleManager.getTibuStateByCamp(1) == 4 or RoleManager.getTibuStateByCamp(1) == 2 then
                resultList.enemytibuPos=_earrTibu[1].position
            else
                resultList.enemytibuPos = -1
            end        
        end
        -- BattleLogManager.WriteServerFightData(_hpRecord, time, "HPCHECKER")

        -- local resultChecker = RoleManager.getRecord()

        -- BattleLogManager.WriteServerFightData(resultChecker, time, "resultChecker")
        -- if BattleLogic.IsOpenBattleRecord then
        --     generateRecordFile()
        -- end

        -- print -----------------------------------------
        -- print("最终运行帧数："..BattleLogic.CurFrame())
	    local curRound, maxRound = BattleLogic.GetCurRound()
        if curRound > maxRound and _type == 9 then
            local playerDamage=0
            local enemyDamage=0
            for k,v in pairs(BattleRecord)do
                if v.camp == 0 then
                    playerDamage = playerDamage + v.damage
                else
                    enemyDamage = enemyDamage + v.damage
                end
            end
            resultList.result = playerDamage > enemyDamage and 1 or 0
        else
            resultList.result = BattleLogic.Result
        end

		if _type == 10 or _type == 11 or _type == 14 then  -- 公会boss和车迟斗法boss返回伤害值
			local playerDamage=0
			for k,v in pairs(BattleRecord)do
                if v.camp == 0 then
                    playerDamage = playerDamage + v.damage
                end
            end
			resultList.duration = playerDamage --TODO:公会boss的持续时间传递的是我方总伤害值
		else
			resultList.duration = BattleLogic.CurFrame() / BattleLogic.GameFrameRate
		end

        resultList.useTimes = BattleLogic.useTimes
        resultList.fightRound = curRound
        BattleLogManager.WriteServerFightDataB(time, "NormalENDP")
        -- BattleLogic.Clear()
        -- addBattleData()
        return resultList
    end
    if isError then --捕获异常，并输出错误日志

        BattleLogManager.WriteServerFightDataB(time, "ErrorBEGINP")

        -- BattleLogManager.WriteServerFightData(errorCache,time, "ErrorLog")

        BattleLogManager.WriteServerFightDataB(time, "ErrorENDP")
    end
    --WYLog("return -1")
    -- BattleLogic.Clear()
    return { result = -1 }
end


-- BattleMain.Execute({seed=1614579919, type=1, maxTime=300},{enemyData={{{ai={0},camp=1,element=0,monsterId=10013,passivity={},position=2,professionId=2,property={1,509,509,65,43,0,88,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10011,skillArray={{21201,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{21211,0.2,{0},1,800,0,1,{cd=1,isCannon=1,release=1,slot=1},{230000,{1,0.87,1},{255,0.2,1}}}},star=4,type=1},{ai={0},camp=1,element=0,monsterId=10015,passivity={},position=4,professionId=2,property={1,450,450,85,41,0,85,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10011,skillArray={{21401,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{21411,0.2,{0},1,800,0,1,{cd=-1,isCannon=1,release=1,slot=1},{400000,{260,1,2,9,1,0.2},{260,1,2,10,1,0.2},{1,1.8,1}}}},star=4,type=1},{ai={0},camp=1,element=0,monsterId=10049,passivity={},position=6,professionId=2,property={22,1395,1395,290,133,0,157,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10011,skillArray={{11301,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{11311,0.2,{0},1,800,0,1,{cd=-1,isCannon=1,release=1,slot=1},{200004,{1,0.8,2},{3,0.1,8,2}}}},star=4,type=1},{ai={0},camp=1,element=0,monsterId=10025,passivity={},position=7,professionId=2,property={22,1973,1973,332,180,0,238,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10011,skillArray={{30701,0.2,{0.1,0.1,0.1,0.1,0.1,0.1},7,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{30711,0.5,{0},1,800,0,1,{cd=-1,isCannon=0,release=1,slot=1},{100000,{24,1,0.58},{211,1,1,22,1,0.1,2}}}},star=5,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}}},fightUnitData={},fightUnitDataAppend={},playerData={{camp=0,element=1,passivity={},position=2,professionId=1,property={30,509,2565,348,241,0,279,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10007,skillArray={{20601,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{20611,0.2,{0},1,800,0,1,{cd=-3,isCannon=1,release=1,slot=1},{230000,{219,19,1,0.4,4,2,0.73,1,0.6}}}},star=5,type=1},{camp=0,element=3,passivity={},position=4,professionId=1,property={30,450,2616,340,249,0,280,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10038,skillArray={{10201,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{10211,0.2,{0},1,800,0,1,{cd=-1,isCannon=1,release=1,slot=1},{210000,{10,1.45,1,0.1}}}},star=5,type=1},{camp=0,element=5,passivity={},position=6,professionId=4,property={1,694,408,73,38,0,70,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10090,skillArray={{51301,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{51311,0.2,{0},1,800,0,1,{cd=1,isCannon=0,release=1,slot=1},{200000,{24,1,0.98},{211,0.2,1,23,3,0.2,2}}}},star=3,type=1},{camp=0,element=4,passivity={},position=7,professionId=2,property={30,1284,1284,254,142,0,166,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10071,skillArray={{41301,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{41311,0.2,{0},1,800,0,1,{cd=1,isCannon=1,release=1,slot=1},{200111,{1,2.28,2}}}},star=3,type=1},{camp=0,element=3,passivity={},position=9,professionId=1,property={30,1369,1369,182,148,0,157,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10052,skillArray={{11801,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{11811,0.2,{0},1,800,0,1,{cd=1,isCannon=1,release=1,slot=1},{400000,{1,2.18,1}}}},star=3,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={}})
-- BattleMain.Execute({seed=1616223616, type=1, maxTime=300},{enemyData={{{ai={0},camp=1,element=0,monsterId=10015,passivity={},position=2,professionId=2,property={1,450,450,85,41,0,85,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10011,skillArray={{21401,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{21411,0.2,{0},1,800,0,1,{cd=-1,isCannon=1,release=1,slot=1},{400000,{260,1,2,9,1,0.2},{260,1,2,10,1,0.2},{1,1.8,1}}}},star=4,type=1},{ai={0},camp=1,element=0,monsterId=10051,passivity={},position=4,professionId=2,property={1,514,514,73,44,0,79,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10011,skillArray={{11501,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{11511,0.2,{0},1,800,0,1,{cd=-1,isCannon=1,release=1,slot=1},{400000,{10,1.4,1,1}}}},star=4,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}}},fightUnitData={},fightUnitDataAppend={},playerData={{camp=0,element=3,passivity={},position=2,professionId=2,property={1,441,441,99,42,0,83,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10049,skillArray={{11301,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{11311,0.2,{0},1,800,0,1,{cd=-1,isCannon=1,release=1,slot=1},{200004,{1,0.8,2},{3,0.1,8,2}}}},star=4,type=1},{camp=0,element=3,passivity={},position=4,professionId=4,property={1,459,459,86,42,0,79,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10047,skillArray={{11101,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{11111,0.2,{0},1,800,0,1,{cd=-1,isCannon=1,release=1,slot=1},{400000,{1,1.7,2},{254,0.3,1,1,3,21,0.15,2}}}},star=4,type=1},{camp=0,element=4,passivity={},position=6,professionId=3,property={1,798,798,179,53,0,135,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10063,skillArray={{40501,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{40511,0.2,{0},1,800,0,1,{cd=-1,isCannon=1,release=1,slot=1},{400000,{240,5,6,3,0.15},{260,1,1,23,3,0.3},{1,1.61,1}}}},star=5,type=1},{camp=0,element=5,passivity={},position=7,professionId=1,property={1,507,507,73,42,0,89,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10088,skillArray={{51101,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{51111,0.2,{0},1,800,0,1,{cd=0,isCannon=1,release=1,slot=1},{200111,{1,1.68,1},{261,0.45,3,1,0.15,2}}}},star=4,type=1},{camp=0,element=1,passivity={},position=9,professionId=2,property={1,408,408,94,38,0,79,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10014,skillArray={{21301,0.3,{0},1,1200,0,1,{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{21311,0.2,{0},1,800,0,1,{cd=1,isCannon=1,release=1,slot=1},{400000,{1,1.8,2},{261,0.3,4,1,0.15,2}}}},star=4,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={}})
-- BattleMain.Execute({seed=1616228411, type=17, maxTime=0},{enemyData={{{ai={0},camp=1,element=0,passivity={},position=2,professionId=2,property={"1","450","450","85","41","0","85","0.0","0.0","1.0","0.0","0.0","1.5","0.0","0.0","0.0","0.0","0.0","0","0","0","0","0","0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0"},quality=0,roleId=10011,round=0,skillArray={{"21401",0.3,{0},1,1200,0,"0",{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"21411",0.2,{0},1,800,0,"0",{cd=-1,isCannon=1,release=1,slot=1},{400000,{260,1,2,9,1,0.2},{260,1,2,10,1,0.2},{1,1.8,1}}}},type=1},{ai={0},camp=1,element=0,passivity={},position=4,professionId=2,property={"1","514","514","73","44","0","79","0.0","0.0","1.0","0.0","0.0","1.5","0.0","0.0","0.0","0.0","0.0","0","0","0","0","0","0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0"},quality=0,roleId=10011,round=0,skillArray={{"11501",0.3,{0},1,1200,0,"0",{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"11511",0.2,{0},1,800,0,"0",{cd=-1,isCannon=1,release=1,slot=1},{400000,{10,1.4,1,1}}}},type=1},teamPassive={},teamSkill={}}},fightUnitData={{},{},{},{}},playerData={{camp=0,element=3,passivity={},position=2,professionId=4,property={1,459,459,86,42,0,79,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10047,skillArray={{"11101",0.3,{0},1,1200,0,"0",{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{"11111",0.2,{0},1,800,0,"0",{cd=-1,isCannon=1,release=1,slot=1},{400000,{1,1.7,2},{254,0.3,1,1,3,21,0.15,2}}}},type=1},{camp=0,element=1,passivity={},position=4,professionId=3,property={1,809,809,168,56,0,125,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10008,skillArray={{"20701",0.3,{0},1,1200,0,"0",{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"20711",0.2,{0},1,800,0,"0",{cd=-1,isCannon=1,release=1,slot=1},{200000,{1,0.9,1},{254,0.3,1,2,3,0.2,2}}}},type=1},{camp=0,element=5,passivity={},position=7,professionId=1,property={1,507,507,73,42,0,89,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10088,skillArray={{"51101",0.3,{0},1,1200,0,"0",{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"51111",0.2,{0},1,800,0,"0",{cd=0,isCannon=1,release=1,slot=1},{200111,{1,1.68,1},{261,0.45,3,1,0.15,2}}}},type=1},{camp=0,element=1,passivity={},position=6,professionId=1,property={1,524,524,71,36,0,86,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10012,skillArray={{"21101",0.3,{0},1,1200,0,"0",{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"21111",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{400000,{260,1,1,23,3,0.2},{1,2.1,1}}}},type=1},{camp=0,element=4,passivity={},position=9,professionId=2,property={1,406,406,74,36,0,75,0,0,1,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10071,skillArray={{"41301",0.3,{0},1,1200,0,"0",{cd=-2,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{"41311",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{200111,{1,2.28,2}}}},type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={}})
-- BattleMain.Execute({seed=1624324885, type=1, maxTime=20},{enemyData={{{ai={0},camp=1,element=1,passivity={{{315},{0.5,5,12,0.07,1}}},position=2,professionId=0,property={"92","5931","5931","758","632","0","598","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10007,round=0,skillArray={{"20601",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"20611",0.2,{0},1,800,0,"0",{cd=0,isCannon=1,release=1,slot=1},{230000,{219,1.09,1,0.4,4,2,0.73,1,0.6}}}},type=1},{ai={0},camp=1,element=2,passivity={{{321},{0.7,2,5,1,0.15}}},position=4,professionId=0,property={"92","4985","4985","1085","577","0","581","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10022,round=0,skillArray={{"30401",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{"30411",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{400000,{1,1.72,2},{3,0.6,4,1}}},{"30431",0.833,{0.2,0.2,0.2},4,2430,0,"0",{cd=3,isCannon=0,release=2,slot=3},{200003,{1,1.31,2},{229,4,2,5,1,0.15}}}},type=2},{ai={0},camp=1,element=3,passivity={{{304},{14,3,0.2,2}}},position=6,professionId=0,property={"92","5149","5149","1038","612","0","433","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10044,round=0,skillArray={{"10801",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{"10811",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{210000,{1,1.2,2},{211,0.35,1,14,3,0.35,2},{234,4,0.3,8,2}}},{"10831",0.2,{0},1,800,0,"0",{cd=3,isCannon=1,release=2,slot=3},{200003,{1,1.08,2},{258,0.28,2}}}},type=3},{ai={0},camp=1,element=4,passivity={{{302},{0.6,1,1,1}}},position=7,professionId=0,property={"92","5529","5529","1150","645","0","335","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10063,round=0,skillArray={{"40501",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"40511",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{400000,{240,5,6,3,0.15},{260,1,1,23,3,0.3},{1,1.61,1}}}},type=4},{ai={0},camp=1,element=5,passivity={{{343,344},{1,0.1},{0.3,2,1,0.3}}},position=9,professionId=0,property={"92","5499","5499","1140","634","0","405","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10079,round=0,skillArray={{"50401",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{"50411",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{200000,{1,0.75,2},{268,0.45,2,1,0.3}}},{"50431",0.2,{0},1,800,0,"0",{cd=3,isCannon=1,release=2,slot=3},{200000,{1,1.05,2},{270,0.1,1,1}}}},type=5},teamPassive={},teamSkill={}}},fightUnitData={{},{},{},{}},fightUnitDataAppend={},playerData={{camp=0,element=1,passivity={{{309,310},{4,5,2,9,1,0.2},{3,2,2,5,1,0.2}}},position=2,professionId=3,property={225,237145,237145,48533,1493,0,1431,0,0,1,0,0.25,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10002,skillArray={{"20101",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"20113",0.2,{0},1,1500,0,"0",{cd=1,isCannon=0,release=1,slot=1},{200321,{1,2.6,1},{248,5,0.2,3,1,2}}},{"20133",0.2,{0},1,800,0,"0",{cd=3,isCannon=1,release=2,slot=3},{270000,{1,2.07,1},{261,0.9,1,4,1,0.2,2},{3,0.25,9,2}}}},type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={}})
-- BattleMain.Execute({seed=1626848262, type=1, maxTime=20},{enemyData={{{ai={},camp=1,element=4,passivity={},position=2,professionId=0,property={"1","216","216","95","44","0","0","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10067,round=0,skillArray={{"40901",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{"40911",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{400000,{1,1.68,2},{3,0.2,1,2}}}},type=4},{ai={},camp=1,element=3,passivity={},position=4,professionId=0,property={"1","220","220","80","42","0","0","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10049,round=0,skillArray={{"11301",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,2}}},{"11311",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{200004,{1,0.8,2},{3,0.1,8,2}}}},type=3},{ai={},camp=1,element=1,passivity={},position=6,professionId=0,property={"1","975","975","77","41","0","0","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10015,round=0,skillArray={{"21401",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"21411",0.2,{0},1,800,0,"0",{cd=1,isCannon=1,release=1,slot=1},{400000,{260,1,2,9,2,0.2},{260,1,2,10,2,0.2},{1,1.8,1}}}},type=1},teamPassive={},teamSkill={}}},fightUnitData={{},{},{},{},{},{}},fightUnitDataAppend={},playerData={{camp=0,element=1,passivity={},position=2,professionId=1,property={1,509,509,65,43,0,88,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10013,skillArray={{"21201",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"21211",0.2,{0},1,800,0,"0",{cd=3,isCannon=1,release=1,slot=1},{230000,{1,0.87,1},{255,0.2,1}}}},type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={{ai={},camp=0,element=4,passivity={},position=9,professionId=0,property={"50","841","841","99","42","0","118","0.0","0.0","1.0","0.0","0.0","0.0","0.0","1.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0"},quality=0,roleId=10057,round=2,skillArray={{"41501",0.3,{0},1,1200,0,"0",{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,1}}},{"41531",0.833,{0.2,0.2,0.2},4,2430,0,"0",{cd=3,isCannon=0,release=2,slot=3},{200211,{211,1,1,6,3,0.1,2}},{200000,{1,1.05,1}},{200221,{3,0.3,4,2}}},{"41511",0.2,{0},1,800,0,"0",{cd=3,isCannon=1,release=1,slot=1},{270000,{1,1.44,1}},{270321,{261,0.4,6,12,0.07,2}}}},type=4}}})





return BattleMain