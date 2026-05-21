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
function BattleMain.Execute(args, fightData, optionData)
    _seed = args.seed
    _type = args.type
    _maxRound = args.maxRound
    _fightData = fightData
    _optionData = optionData or {}

    --该开关用于输出战斗过程中的日志，用于验证前后端是否出现战斗不同步
    --BattleLogic.IsOpenBattleRecord = true

    local isError = false
    local errorCache
    if xpcall(function ()
        Random.SetSeed(args.seed)
        BattleLogic.Init(fightData, optionData, _maxRound)
        BattleLogic.Type = _type
        if _type == 9 or _type == 10 or _type == 11 or _type == 14 then
            AddRecord(fightData)
        end
        BattleLogic.StartOrder()
        while not BattleLogic.IsEnd do
            BattleLogic.Update()
        end
    end, function (err)
        isError = true
        errorCache = "error:\n"..debug.traceback(err).."\n"
    end) then
    	BattleLogic.useTimes = 10
        local resultList = {0, 0, 0, 0, 0, 0, 0, 0, 0}
        if BattleLogic.Result == 1 then --胜利记录我方剩余血量
            local arr = RoleManager.Query(function (r) return r.camp == 0 end, true)
            for i=1, #arr do
                local pos = arr[i].position
                resultList[pos] = arr[i]:GetRoleData(RoleDataName.Hp)
            end
        elseif BattleLogic.Result == 0 then  --失败记录敌方剩余血量
            local arr = RoleManager.Query(function (r) return r.camp == 1 end, true)
            for i=1, #arr do
                local pos = arr[i].position
                resultList[pos] = arr[i]:GetRoleData(RoleDataName.Hp)
            end
        end

        if BattleLogic.IsOpenBattleRecord then
            generateRecordFile()
        end

        -- print -----------------------------------------
        --for i=1, #resultList do
        --    print("hp:"..resultList[i])
        --end
        --print("最终运行帧数："..BattleLogic.CurFrame())
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

        addBattleData()
        return resultList
    end
    if isError then --捕获异常，并输出错误日志
        print("error")
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
            file = io.open("../luafight/LogError/"..time..".txt", "a")
            platform = "Linux"
        end
        -- local window server   
        if not file then
            file = io.open("luafight/LogError/"..time..".txt", "a")
            platform = "Local Windows Server"
        end
        -- local
        if not file then
            file = io.open("LogError/"..time..".txt", "a")
            platform = "Local"
        end

        file:write(platform..":\n\n\n")
        file:write(errorCache)
        file:write("seed:\n"..tostring(args.seed).."\n")
        file:write("type:\n"..tostring(args.type).."\n")
        file:write("fightData:\n"..PrintTable(_fightData).."\n")
        file:write("optionData:\n"..PrintTable(_optionData).."\n")
        file:write("\n\nlast com.ljsd.battle data:\n")
        for i=1, #_BattleErrorCache do
            file:write(string.format("\nindex:%d\n", i))
            file:write(_BattleErrorCache[i])
        end
        io.close(file)
    end
    return { result = -1 }
end


-- BattleMain.Execute({seed=1606726052, type=1, maxTime=300},{enemyData={{{ai={0},camp=1,element=0,monsterId=101011,passivity={},position=1,professionId=0,property={1,457,457,91,44,0,86,0,0,1,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0},quality=0,roleId=10067,skillArray={{40901,0.3,{0},1,1200,0,1,{cd=1,release=1,slot=0},{400000,{1,1,2}}},{40911,0.2,{0},1,800,0,1,{cd=2,release=1,slot=1},{400000,{1,0.56,2},{3,0.2,1,2}}},{40931,0.2,{0},1,800,0,1,{cd=4,release=2,slot=3},{200000,{1,1.29,2},{3,0.2,1,2}}}},star=0,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}}},fightUnitData={},playerData={{camp=0,element=4,passivity={},position=1,professionId=2,property={1,592,592,122,53,3,0,0,0,1.0062,0,0,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10065,skillArray={{40701,0.3,{0},1,1200,0,1,{cd=1,release=1,slot=0},{400000,{1,1,2}}},{40711,0.2,{0},1,800,0,1,{cd=4,release=1,slot=1},{200000,{1,0.89,2},{254,0.3,1,5,3,0.1,3}}}},star=5,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}}})




return BattleMain