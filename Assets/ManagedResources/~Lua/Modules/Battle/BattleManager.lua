BattleManager = {}
local this = BattleManager
local PassiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local MonsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local CombatControl = ConfigManager.GetConfig(ConfigName.CombatControl)
local MainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local BattleEventConfig = ConfigManager.GetConfig(ConfigName.BattleEventConfig)
local FormationConfig = ConfigManager.GetConfig(ConfigName.FormationConfig)
local MotherShipPlaneConfig =ConfigManager.GetConfig(ConfigName.MotherShipPlaneConfig)

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

function this.Initialize()
    --加载相关模块
    local files = ReloadFile("Modules/Battle/Config/LuaFileConfig")
    LoadLuaFiles(files)

    BattleManager.ResetCVDatas()
end

--获取技能数据（战斗用）
function this.GetSkillData(skillId, pos,leaderskill,leaderlv)
    pos = pos or 0
    if not skillId or not SkillLogicConfig[skillId] then
        return
    end
    local skill = {skillId}
    --skill = {skillId, 命中时间, 持续时间, 伤害次数, {目标id1, 效果1, 效果2, ...},{目标id2, 效果3, 效果4, ...}, ...}
    --效果 = {效果类型id, 效果参数1, 效果参数2, ...}

    local target = SkillLogicConfig[skillId].Target
    local effectList = SkillLogicConfig[skillId].Effect
    local effectArgsList = SkillLogicConfig[skillId].EffectValue
    local repeatAttackTimes = 0--SkillLogicConfig[skillId].Repeat
    local EffectCombat = CombatControl[SkillLogicConfig[skillId].SkillDisplay]
    local index = 1
  
    skill[1] = skillId
    skill[2] = EffectCombat.KeyFrame/1000
    local SkillDurationSecound = {}
    for i = 1, #EffectCombat.SkillDuration do
        table.insert(SkillDurationSecound, EffectCombat.SkillDuration[i] / 1000)
    end
    skill[3] = SkillDurationSecound
    skill[4] = EffectCombat.SkillNumber
    skill[5] = EffectCombat.ReturnTime
    skill[6] = EffectCombat.CastBullet
    skill[7] = repeatAttackTimes

    local _isleader = false

    local ext = {slot = SkillLogicConfig[skillId].Slot,
                cd = SkillLogicConfig[skillId].CD,
                release = SkillLogicConfig[skillId].release,
                isCannon = EffectCombat.IsCannon,
                isLeaderSkill = _isleader,
                lv = 0
                }
    if leaderskill then
        --测试数据
        ext.isLeaderSkill = leaderskill
        ext.slot = pos
        ext.cd = 4
        ext.release = pos
        ext.sort = pos
        ext.lv = leaderlv
        -- LogError("ADD "..  ext.slot)
    end
    skill[8] = ext

    for i = 1, #effectList do
        local effectGroup = { target[i][1] }    -- 效果目标
        for j = 1, #effectList[i] do
            local effect = { effectList[i][j] } -- 效果Id
            for k = 1, #effectArgsList[index] do
                effect[k + 1] = effectArgsList[index][k] -- 效果参数
            end
            effectGroup[j + 1] = effect
            index = index + 1
        end
        skill[i + 8] = effectGroup
    end

    --IgnoreControl==1表示无视技能
    skill[-1] = SkillLogicConfig[skillId].IgnoreControl

    return skill
end

function this.GetPassivityData(passivityList)
    local pList = {}
    if not passivityList then
        return pList
    end

    -- 遍历被动，检查是否有要覆盖的被动技能
    local orderList = {}
    local coverList = {}
    for i = 1, #passivityList do
        local passiveId = tonumber(passivityList[i])
        local cfg = PassiveSkillLogicConfig[passiveId]
        -- 判断技能是否在战斗中生效
        -- if cfg and cfg.EffectiveRange == 1 then
        --     -- 判断是否有需要覆盖的被动技能
        --     local coverId = cfg.CoverID
        --     if coverId and coverId ~= 0 then
        --         if orderList[coverId] then
        --             orderList[coverId] = nil
        --         end
        --         coverList[coverId] = 1
        --     end

        --     --> 最初数据格式passivity={{90,22,0.1,1}}
        --     --> 此处已错误 passivity={{{90,90},{22,0.1,1},{26,0.05,1}}}
        --     --> 但是战斗处解析被动数据时按照上面规则进行解析了 后端已按此传数据 暂时不动 后续需要需修正

        --     -- 判断该被动技能是否已经被覆盖
        --     if not coverList[passiveId] then
        --         -- 没有被覆盖，数据加入
        --         local pass = {}
        --         if cfg and cfg.Type ~= 0 then
        --             pass[1] = cfg.Type
        --             for j = 1, #cfg.Value do
        --                 pass[j + 1] = cfg.Value[j]
        --             end
        --             orderList[passiveId] = pass
        --         end
        --     end
        -- end


        if cfg then
            -- 判断是否有需要覆盖的被动技能
            local coverId = cfg.CoverID
            if coverId and coverId ~= 0 then
                if orderList[coverId] then
                    orderList[coverId] = nil
                end
                coverList[coverId] = 1
            end

            --> 最初数据格式passivity={{90,22,0.1,1}}
            --> 此处已错误 passivity={{{90,90},{22,0.1,1},{26,0.05,1}}}
            --> 但是战斗处解析被动数据时按照上面规则进行解析了 后端已按此传数据 暂时不动 后续需要需修正

            --> 应对EffectiveRange 修改为数组修改

            -- 判断该被动技能是否已经被覆盖
            if not coverList[passiveId] then
                -- 没有被覆盖，数据加入
                local pass = {}
                local j = 2
                for idx, v in ipairs(cfg.Type) do
                    if cfg.EffectiveRange[idx] == 1 and v ~= 0 then
                        if pass[1] == nil then
                            pass[1] = {}
                        end
                        table.insert(pass[1], v)
                        pass[j] = cfg.Value[idx]
                        j = j + 1
                    end
                end
                if next(pass) ~= nil then
                    orderList[passiveId] = pass
                end
            end
        end
    end

    -- 构建数据
    for _, passive in pairs(orderList) do
        table.insert(pList, passive)
    end

    return pList
end

--> deprecated
--获取怪物数据（战斗用）
function this.GetMonsterData(monsterId)
    local monsterConfig = MonsterConfig[monsterId]
    return {
        roleId = monsterConfig.MonsterId,
        monsterId = monsterId, --非战斗数据，仅用于显示怪物名称
        professionId = monsterConfig.Profession,
        size = monsterConfig.Size,
        camp = 1,
        type = 1,
        quality = 0,
        skill = this.GetSkillData(monsterConfig.SkillList[1]),
        superSkill = this.GetSkillData(monsterConfig.SkillList[2]),
        element = monsterConfig.PropertyName,
        passivity = this.GetPassivityData(monsterConfig.PassiveSkillList),
        property = {
            monsterConfig.Level,
            monsterConfig.Hp,
            monsterConfig.Hp,
            monsterConfig.Attack,
            monsterConfig.PhysicalDefence,
            monsterConfig.MagicDefence,
            monsterConfig.Speed,
            monsterConfig.DamageBocusFactor,
            monsterConfig.DamageReduceFactor,
            monsterConfig.Hit,
            monsterConfig.Dodge,
            monsterConfig.CritFactor,
            monsterConfig.CritDamageFactor,
            monsterConfig.AntiCritDamageFactor,
            monsterConfig.TreatFacter,
            monsterConfig.CureFacter,
            monsterConfig.DifferDemonsBocusFactor,
            monsterConfig.DifferDemonsReduceFactor,
            monsterConfig.ElementDamageReduceFactor[1],
            monsterConfig.ElementDamageReduceFactor[2],
            monsterConfig.ElementDamageReduceFactor[3],
            monsterConfig.ElementDamageReduceFactor[4],
            monsterConfig.ElementDamageReduceFactor[5],
            monsterConfig.ElementDamageReduceFactor[6],
            monsterConfig.ElementDamageBonusFactor,
        },
        ai = monsterConfig.MonsterAi,
        star = monsterConfig.Star,
        level = monsterConfig.Level
    }
end

---获取服务端传过来的战斗数据和随机数种子
---参数2 isFightPlayer 0和怪物对战 1和玩家对战
---> fightId 关卡id 随机加入副系统战斗单位(支援 副官)
function this.GetBattleServerData(msg, isFightPlayer, fightId)
    BattleManager.ResetCVDatas()
    local fightData = {
        playerData = { teamSkill = {}, teamPassive = {}, firstCamp = 0},
        tibuData = {},
        enemyData = { },
        fightUnitData = {},
        leaderData = {},
        fightUnitDataAppend = {},
        tankDataAppend = {},
        noUnitDataAppend = {}
    }
    isFightPlayer = isFightPlayer == 1
    local data = msg.fightData.heroFightInfos
    local elementIds = {}
    local setPlayerItemData = function(fightUnit,istibu)
        local rid = tonumber(fightUnit.unitId)
        local position = tonumber(fightUnit.position)
        local star = tonumber(fightUnit.star)

        -- if rid == 0 then --to do add check yh 模拟数据
        --     rid = 10006  
        --     star = 5
        --     position = 9 
        --     fightUnit.unitSkillIds = "22301#22313#22333#22323#22343" 
        ---                         lv  hp     maxhp
        --     fightUnit.property = "255#432093#432093#41941#1827#0#1521#0.0#0.0#1.0#0.0#0.1#1.5#0.0#0.1#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0"        
                                 --340#1208430#118239#2359#0#2100#1208430#0.0#0.0#1.0#0.0#0.25#1.5#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0.0#0#0#0.0#0.0#0.0#0.0#0.0#0.0  #0.0#0.0#0.0#0.0#0.0#0.0#0.0
        -- end 
        --                         340
        --                         915423#915423#116098#2355#0#2294#0.15#0.15#1.0
        --                         0.0#0.45#1.6#0.15#0.0#0.0#0.0#0.0#0.0#0.0
        --                         0.0#0.0 #0.0#0.0 #0.0#0.0#0.0#0.0#0.0#0.0
        --                         0.0#0.0 #0.0#0.0 #0.1#0.0#0.0#0.0#0.1
        local Reflact = {
            [1]={"Level"," --等级"},
            [2]={"Hp"," --生命"},
            [3]={"MaxHp"," --最大生命"},
            [4]={"Attack"," --攻击力"},
            [5]={"PhysicalDefence","--护甲"},
            [6]={"MagicDefence","--魔抗"},
            [7]={"Speed","--速度"},
            [8]={"DamageBocusFactor"," --伤害加成系数（%）"},
            [9]={"DamageReduceFactor"," --伤害减免系数（%）"},
            [10]={"Hit"," --施法率（%"},
            [11]={"Dodge"," --后期基础施法率（%）"},
            [12]={"Crit"," --暴击率（%）"},
            [13]={"CritDamageFactor"," --暴击伤害系数（%）"},
            [14]={"Tenacity"," --抗暴率（%）"},
            [15]={"TreatFacter","--治疗加成系数（%）"},
            [16]={"CureFacter","--受到治疗加成系数（%）"},
            [17]={"PhysicalDamage","--< 物伤"},
            [18]={"MagicDamage","--< 法伤"},
            [19]={"PhysicalImmune","--< 物免"},
            [20]={"MagicImmune","--< 法免"},
            [21]={"SpeedAddition"," --< 速度加成"},
            [22]={"AttackAddition","--< 攻击加成"},
            [23]={"ArmorAddition"," --< 护甲加成"},
            [24]={"ControlProbability"," --< 控制几率"},
            [25]={"ControlResist","--< 控制抵抗"},
            [26]={"SkillDamage","--< 技能伤害"},
            [27]={"DamageToMage"," --< 对高爆型伤害"},
            [28]={"DamageToFighter","--< 对穿甲型伤害"},
            [29]={"DamageToDefender","--< 对防御型伤害"},
            [30]={"DamageToHealer","--< 对辅助型伤害"},
            [31]={"DefenceFromFighter","--< 受穿甲型伤害降低"},
            [32]={"DefenceFromMage","--< 受高爆型伤害降低"},
            [33]={"DefenceFromDefender","--< 受防御型伤害降低"},
            [34]={"DefenceFromHealer","--< 受辅助型伤害降低"},
            [35]={"CriDamageReduceRate","--< 暴伤抵抗"},
            [36]={"HealCritical","--< 修理暴击"},
            [37]={"HealCriEffect","--< 修理暴击效果"},
            [38]={"MaxHpPercentage","--< 生命加成"},
            [39]={"other","--< temp"},
            [40]={"other","--< temp"},
            [41]={"other","--< temp"},
            [42]={"other","--< temp"},
            [43]={"other","--< temp"},
            [44]={"other","--< temp"},
            }
        local skills = string.split(fightUnit.unitSkillIds, "#")
        local propertys = string.split(fightUnit.property, "#")


        -- LogError("fightUnit.property："..tostring(fightUnit.property))
        local role = {           
            roleId = rid,
            position = position,
            star = star,
            camp = 0,
            type = 1,
            quality = 0,
            element = HeroConfig[rid].PropertyName,
            professionId = HeroConfig[rid].Profession,
            size = 1,
            passivity = { },
            property = { },
            isTibu = istibu,
            leader = false
        }
        if not istibu and not role.leader then
            table.insert(elementIds, role.element)
        end
        -- if skills[1] then
        --     role.skill = this.GetSkillData(tonumber(skills[1]))
        -- end
        -- if skills[2] and skills[2] ~= "0" then
        --     role.superSkill = this.GetSkillData(tonumber(skills[2]))
        -- end

        --> 
        role.skillArray = {}
        local passivityList = {}
        local idx = 1

        for i = 1, #skills do
            if skills[i] and skills[i] ~= 0 then
                --> 0 1 3 主动技
                --if i - 1 == SkillSlotPos.Slot_0 or i - 1 == SkillSlotPos.Slot_1 or i - 1 == SkillSlotPos.Slot_3 then
                if i <= 3 then
                    role.skillArray[idx] = this.GetSkillData(tonumber(skills[i]))
                    idx = idx + 1
                    -- table.insert(role.skillArray, this.GetSkillData(tonumber(skills[i])))
                else
                    local passivityId = tonumber(skills[i])
                    for j = 1,#passivityList do 
                        if PassiveSkillLogicConfig[passivityList[j]].Group == PassiveSkillLogicConfig[passivityId].Group then
                            if PassiveSkillLogicConfig[passivityList[j]].Level < PassiveSkillLogicConfig[passivityId].Level then
                                table.remove(passivityList,j)
                            else
                                passivityId = nil
                            end
                            break
                        end
                    end
                    if passivityId ~= nil then
                        table.insert(passivityList, passivityId)
                    end
                end
            end
            
        end

        --做个普攻技能检查
        if role.skillArray[1] == nil then
            LogError("配表错误!!!进攻方普攻未找到 roleId:" .. role.roleId .. " 普攻技能id:" .. tonumber(skills[1]))
        end
        
        -- role.passivity, role.passivityIds = this.GetPassivityData(passivityList)
        role.passivity = this.GetPassivityData(passivityList)
        role.passivityIds = passivityList

        -- if #skills > 2 then
        --     local passivityList = {}
        --     for j = 3, #skills do
        --         table.insert(passivityList, tonumber(skills[j]))
        --     end
            -- role.passivity = this.GetPassivityData(passivityList)
        -- end
        for j = 1, #propertys do
            role.property[j] = tonumber(propertys[j])
            -- LogError(j.."prop:"..tostring(role.property[j]))
        end
        return role
    end

    for i = 1, #data.fightUnitList do
        fightData.playerData[i] = setPlayerItemData(data.fightUnitList[i],false)
    end

    -- 替补数据条件 to do yh check
    if data.substitute.unitId ~= "" then
        fightData.tibuData[1] = setPlayerItemData(data.substitute,true)
    end

    this.SetFightElement(0, elementIds)
    
    -- local teamSkills = string.split(data.teamSkillList, "|") --异妖位置1#技能id1|异妖位置2#技能id2|..
    -- for i = 1, #teamSkills do
    --     local s = string.split(teamSkills[i], "#")
    --     fightData.playerData.teamSkill[i] = this.GetSkillData(tonumber(s[2]), tonumber(s[1]))
    -- end

    -- 
    -- local teamPassives = string.split(data.teamPassiveList, "|")
    -- for i = 1, #teamPassives do
    --     local s = string.split(teamPassives[i], "#")
    --     local teamPassiveList = {}
    --     for j = 1, #s do
    --         teamPassiveList[j] = tonumber(s[j])
    --     end
    --     fightData.playerData.teamPassive[i] = this.GetPassivityData(teamPassiveList)
    -- end

    -- 一些战斗外数据
    fightData.playerData.outData = data.specialPassive
    
    --> 支援
    if data.useSupportId and data.useSupportId ~= 0 and data.useSupportId ~= "" then
        this.AddUnitDataByType(data.useSupportId, fightData.fightUnitData, data.supportSkillLevel, FightUnitType.UnitSupport, 0)
    end
    --> 副官
    if data.useAdjutantId and data.useAdjutantId ~= 0 and data.useAdjutantId ~= "" then
        this.AddUnitDataByType(data.useAdjutantId, fightData.fightUnitData, data.adjutantSkillLevel, FightUnitType.UnitAdjutant, 0)
    end

    -- 模拟数据
    local setPlayerLeaderItemDate = function(fightUnit,_camp)
        local rid = 1
        local position = 99
        local star = 0
        local allPro = {10,10,10,10,10,10}
        if fightUnit ~= nil then
            allPro = string.split(fightUnit.property, "#")
        end
        local propertys = {
            allPro[1],-- Level,
            allPro[2] and allPro[2] or 0,-- Hp,
            allPro[3] and allPro[3] or 0,-- Hp,
            allPro[4] and allPro[4] or 0,-- Attack,
            allPro[5] and allPro[5] or 0,-- PhysicalDefence,
            0,-- MagicDefence,
            allPro[7] and allPro[7] or 0,-- Speed,
            0,-- DamageBocusFactor,
            0,-- DamageReduceFactor,
            10000,-- Hit,
            0,-- Dodge,
            0,-- CritFactor,
            0,-- CritDamageFactor,
            0,-- AntiCritDamageFactor,
            0,-- TreatFacter,
            0,-- CureFacter,
            0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,
        }   --AircraftCarrierManager.GetFightDataProperty() 对应读表方法

        local role = {
            roleId = rid,
            position = position,
            star = star,
            camp = _camp,
            type = 1,
            quality = 0,
            element = 0,
            professionId = 0,
            size = 1,
            passivity = { },
            property = { },
            isTibu = false,
            leader = true,
            leaderSkillUnlock = 0
        }

        --data.motherShipInfo.plan
        --id (string) 战机ID
        --cfgId  (int32) 战机表ID （服务器需要切换为技能id脚本中没有此数据！！！）
        --sort (int32) 穿戴顺序
        --skillid （string）技能id
        -- 技能等级通过id反向读表 todo 需要修改读取方式
        role.leaderSkillUnlock = fightUnit.unlockSkillSize
        local skills = fightUnit.plan
        role.skillArray = {}   
        if false then --true测试数据
            if _camp == 0 then
                skills = string.split("910111#911012#910513#910714", "#")--910111
            else
                skills = string.split("910915#911011#911111#911211", "#")
            end
            local idx = 1
            for i = 1,  #skills do
                role.skillArray[idx] = this.GetSkillData(tonumber(skills[i]),i,true,1)
                idx = idx + 1
            end
        else
            local idx = 1
            for i = 1,  #fightUnit.plan do
                local plane = fightUnit.plan[i]
                local id = plane.cfgId
                local lv =  MotherShipPlaneConfig[id].Lvl
                role.skillArray[idx] = this.GetSkillData(tonumber(plane.leaderSkill),plane.sort,true,lv)
                idx = idx + 1
                LogError(i.." skilld>>> "..plane.leaderSkill.." plane.sort："..plane.sort)
            end
            --非测试数据方法 读取方式根据数据结构决定
        end

        for j = 1, #propertys do
            role.property[j] = tonumber(propertys[j])
        end
        return role
    end

    -- 数据结构
    -- data.motherShipInfo 
    -- Id (int32)
    -- property (string)
    -- plan (MotherShipPlan) 技能数据

    if data.motherShipInfo and #data.motherShipInfo.plan > 0 then
        fightData.leaderData[1] = setPlayerLeaderItemDate(data.motherShipInfo,0)
    end

    --data.motherShipInfo.plan
    --id (string) 战机ID
    --cfgId  (int32) 战机表ID （服务器需要切换为技能id脚本中没有此数据！！！）
    --sort (int32) 穿戴顺序
    -- 角色性别为非主要信息前端显示即可
    -- 测试数据 test       
    -- fightData.enemyAircraftCarrier = setPlayerLeaderItemDate(nil,1)
    --> 航母
    if data.motherShipInfo and #data.motherShipInfo.plan > 0 then  -- todo 数据结构需要调整
        --> 0 1 主装备数据 2 3 ext数据
        -- this.CV_equipDatas[0] = {}
        -- this.CV_equipDatas[2] = {}        

        -- local infos = string.format("id:%s proprty:%s skillLen:%s",
        -- data.motherShipInfo.id,
        -- data.motherShipInfo.property,
        -- #data.motherShipInfo.plan)
        -- LogError("motherShipInfo 》》》 "..infos)
        for i = 1,  #data.motherShipInfo.plan do
            -- local plane =data.motherShipInfo.plan[i]
            -- local planeInfo = string.format("id:%s cfgId:%s sort:%s",
            -- plane.id,plane.cfgId,plane.sort)
            -- LogError("plane>>> "..planeInfo)
        end

        local cvMineTb = {}
        for i = 1, #data.motherShipInfo.plan do
            -- local equipPlane = AircraftCarrierManager.CreateEmptyTable()
            -- AircraftCarrierManager.CopyValue(equipPlane, data.motherShipInfo.plan[i])
            -- table.insert(this.CV_equipDatas[0], equipPlane)
        end
        -- this.CV_equipDatas[2].CVLv = data.motherShipInfo.id
        table.sort(this.CV_equipDatas[0], function(a, b)
            return a.sort < b.sort
        end)
        cvMineTb.skill = {}
        for i = 1, #this.CV_equipDatas[0] do
            -- local planeConfig = G_MotherShipPlaneConfig[this.CV_equipDatas[0][i].cfgId]
            -- table.insert(cvMineTb.skill, this.GetSkillData(planeConfig.Skill))
            -- cvMineTb.skill[i][8].release = this.CV_equipDatas[0][i].sort    --< 修改触发顺序为槽位顺序

            -- --> 设置显示用到数据 需排序完数据
            -- this.CV_equipDatas[0][i].release = this.CV_equipDatas[0][i].sort
            -- this.CV_equipDatas[0][i].cd = cvMineTb.skill[i][8].cd
        end

        -- local proArr = string.split(data.motherShipInfo.property, "#")
        -- cvMineTb.property = {}
        -- for j = 1, #proArr do
        --     cvMineTb.property[j] = tonumber(proArr[j])
        -- end
        -- cvMineTb.rootId = data.motherShipInfo.id   --< 各系统主表id
        -- cvMineTb.camp = 0
        -- cvMineTb.type = FightUnitType.UnitAircraftCarrier
        -- table.insert(fightData.fightUnitData, cvMineTb)
    end

    -- 敌方
    for i = 1, #msg.fightData.monsterList do
        local data2 = msg.fightData.monsterList[i]
        fightData.enemyData[i] = { teamSkill = {}, teamPassive = {} , firstCamp = 0, }

        -- 判断是否先手
        --fightData.enemyData[i].firstCamp = data2.firstCamp or 0
        local elementIds = {}

        for j = 1, #data2.fightUnitList do
            local skills, propertys, role
            if not isFightPlayer then
                local monsterConfig = ConfigManager.GetConfigData(ConfigName.MonsterConfig, tonumber(data2.fightUnitList[j].unitId))
                local position = tonumber(data2.fightUnitList[j].position)
                local star = tonumber(data2.fightUnitList[j].star)
                skills = string.split(data2.fightUnitList[j].unitSkillIds, "#")

                propertys = string.split(data2.fightUnitList[j].property, "#")
                role = {
                    roleId = monsterConfig.MonsterId,
                    --monsterId = tonumber(data2.fightUnitList[j].unitId), --非战斗数据，仅用于显示怪物名称
                    position = position,
                    star = star,
                    camp = 1,
                    type = monsterConfig.Type,
                    quality = monsterConfig.Quality,
                    element = monsterConfig.PropertyName,
                    ai = monsterConfig.MonsterAi,
                    professionId = monsterConfig.Profession,
                    size = monsterConfig.Size,
                    passivity = { },
                    property = { },
                }
            else
                local rid = tonumber(data2.fightUnitList[j].unitId)
                local position = tonumber(data2.fightUnitList[j].position)
                local star = tonumber(data2.fightUnitList[j].star)
                skills = string.split(data2.fightUnitList[j].unitSkillIds, "#")
                propertys = string.split(data2.fightUnitList[j].property, "#")
                role = {
                    roleId = rid,
                    position = position,
                    star = star,
                    camp = 1,
                    type = 1,
                    quality = 0,
                    element = HeroConfig[rid].PropertyName,
                    professionId = HeroConfig[rid].Profession,
                    size = 1,
                    passivity = { },
                    property = { },
                }
            end

            table.insert(elementIds, role.element)

            -- HeroConfig[role.roleId].OpenSkillRules
            -- this.GetSkillUnlockLv(skillpos, _star, _break)
            --> 
            role.skillArray = {}
            local passivityList = {}
            local idx = 1
            for i = 1, #skills do
                if skills[i] and skills[i] ~= 0 then
                    --> 0 1 3 主动技
                    --> monster 技能顺序为 三个主动后面全是被动11011...格式
                    -- if i - 1 == SkillSlotPos.Slot_0 or i - 1 == SkillSlotPos.Slot_1 or i - 1 == SkillSlotPos.Slot_3 then
                    if i <= 3 then
                        role.skillArray[idx] = this.GetSkillData(tonumber(skills[i]))
                        idx = idx + 1
                        -- table.insert(role.skillArray, this.GetSkillData(tonumber(skills[i])))
                    else
                        table.insert(passivityList, tonumber(skills[i]))
                    end
                end
            end
            
            --做个普攻技能检查
            if role.skillArray[1] == nil then
                LogError("配表错误!!!防守方普攻未找到 roleId:" .. role.roleId .. " 普攻技能id:" .. tonumber(skills[1]))
            end

            -- role.passivity, role.passivityIds = this.GetPassivityData(passivityList)
            role.passivity = this.GetPassivityData(passivityList)
            role.passivityIds = passivityList

            -- if skills[1] then
            --     role.skill = this.GetSkillData(tonumber(skills[1]))
            -- end
            -- if skills[2] and skills[2] ~= "0" then
            --     role.superSkill = this.GetSkillData(tonumber(skills[2]))
            -- end
            -- if #skills > 2 then
            --     local passivityList = {}
            --     for k = 3, #skills do
            --         table.insert(passivityList, tonumber(skills[k]))
            --     end
            --     role.passivity = this.GetPassivityData(passivityList)
            -- end
            for k = 1, #propertys do
                role.property[k] = tonumber(propertys[k])
            end
            fightData.enemyData[i][j] = role
            -- break
        end

        local setEnemyItemData = function(fightUnit,istibu)
            local rid = tonumber(fightUnit.unitId)
            local position = tonumber(fightUnit.position)
            local star = tonumber(fightUnit.star)    
            local skills = string.split(fightUnit.unitSkillIds, "#")
            local propertys = string.split(fightUnit.property, "#")    
            local role = {           
                roleId = rid,
                position = -1,
                star = star,
                camp = 1,
                type = 1,
                quality = 0,
                element = HeroConfig[rid].PropertyName,
                professionId = HeroConfig[rid].Profession,
                size = 1,
                passivity = { },
                property = { },
                isTibu = istibu,
            }
            if not istibu then
                table.insert(elementIds, role.element)
            end
            role.skillArray = {}
            local passivityList = {}
            local idx = 1
            for i = 1, #skills do
                if skills[i] and skills[i] ~= 0 then
                    if i <= 3 then
                        role.skillArray[idx] = this.GetSkillData(tonumber(skills[i]))
                        idx = idx + 1
                    else
                        local passivityId = tonumber(skills[i])
                        for j = 1,#passivityList do 
                            if PassiveSkillLogicConfig[passivityList[j]].Group == PassiveSkillLogicConfig[passivityId].Group then
                                if PassiveSkillLogicConfig[passivityList[j]].Level < PassiveSkillLogicConfig[passivityId].Level then
                                    table.remove(passivityList,j)
                                else
                                    passivityId = nil
                                end
                                break
                            end
                        end
                        if passivityId ~= nil then
                            table.insert(passivityList, passivityId)
                        end
                    end
                end
            end    
            --做个普攻技能检查
            if role.skillArray[1] == nil then
                LogError("配表错误!!!进攻方普攻未找到 roleId:" .. role.roleId .. " 普攻技能id:" .. tonumber(skills[1]))
            end
            role.passivity = this.GetPassivityData(passivityList)
            role.passivityIds = passivityList
    
            for j = 1, #propertys do
                role.property[j] = tonumber(propertys[j])
            end
            return role
        end

         -- 敌方替补测试数据 真是数据
        if data2.substitute.unitId ~= ""  then
            if data.substitute.unitId == "" then 
                fightData.tibuData[1] = setEnemyItemData(data2.substitute,true)
            else
                fightData.tibuData[2] = setEnemyItemData(data2.substitute,true)
            end            
        end

        if i == 1 then
            this.SetFightElement(1, elementIds)
        end

        -- local teamSkills2 = string.split(data2.teamSkillList, "|") --异妖位置1#技能id1|异妖位置2#技能id2|..
        -- for j = 1, #teamSkills2 do
        --     local s = string.split(teamSkills2[j], "#")
        --     fightData.enemyData[i].teamSkill[j] = this.GetSkillData(tonumber(s[2]), tonumber(s[1]))
        -- end

        -- 一些战斗外数据
        fightData.enemyData[i].outData = data2.specialPassive


        --> 支援
        if data2.useSupportId and data2.useSupportId ~= 0 and data2.useSupportId ~= "" then
            this.AddUnitDataByType(data2.useSupportId, fightData.fightUnitData, data2.supportSkillLevel, FightUnitType.UnitSupport, 1)
        end
        --> 副官
        if data2.useAdjutantId and data2.useAdjutantId ~= 0 and data2.useAdjutantId ~= "" then
            -- LogError("skillLv："..data2.adjutantSkillLevel)
            this.AddUnitDataByType(data2.useAdjutantId, fightData.fightUnitData, data2.adjutantSkillLevel, FightUnitType.UnitAdjutant, 1)
        end
        --> 航母主角
        if data2.motherShipInfo and #data2.motherShipInfo.plan > 0 then
            fightData.leaderData[2] = setPlayerLeaderItemDate(data2.motherShipInfo,1)
        end
        --> 航母
        if data2.motherShipInfo and #data2.motherShipInfo.plan > 0 then
            --> 0 1 主装备数据 2 3 ext数据
            -- this.CV_equipDatas[1] = {}
            -- this.CV_equipDatas[3] = {}

            -- local cvMineTb = {}
            -- for i = 1, #data2.motherShipInfo.plan do
            --     local equipPlane = AircraftCarrierManager.CreateEmptyTable()
            --     AircraftCarrierManager.CopyValue(equipPlane, data2.motherShipInfo.plan[i])
            --     table.insert(this.CV_equipDatas[1], equipPlane)
            -- end
            -- this.CV_equipDatas[3].CVLv = data2.motherShipInfo.id
            -- table.sort(this.CV_equipDatas[1], function(a, b)
            --     return a.sort < b.sort
            -- end)
            -- cvMineTb.skill = {}
            -- for i = 1, #this.CV_equipDatas[1] do
            --     local planeConfig = G_MotherShipPlaneConfig[this.CV_equipDatas[1][i].cfgId]
            --     table.insert(cvMineTb.skill, this.GetSkillData(planeConfig.Skill))
            --     cvMineTb.skill[i][8].release = this.CV_equipDatas[1][i].sort    --< 修改触发顺序为槽位顺序

            --     --> 设置显示用到数据 需排序完数据
            --     this.CV_equipDatas[1][i].release = this.CV_equipDatas[1][i].sort
            --     this.CV_equipDatas[1][i].cd = cvMineTb.skill[i][8].cd
            -- end

            -- local proArr = string.split(data2.motherShipInfo.property, "#")
            -- cvMineTb.property = {}
            -- for j = 1, #proArr do
            --     cvMineTb.property[j] = tonumber(proArr[j])
            -- end

            -- cvMineTb.rootId = data2.motherShipInfo.id   --< 各系统主表id
            -- cvMineTb.camp = 1
            -- cvMineTb.type = FightUnitType.UnitAircraftCarrier
            -- table.insert(fightData.fightUnitData, cvMineTb)
        end
        
    end

    --> 关卡插入
    if fightId then
        local stageData = MainLevelConfig[fightId]
        if stageData then
            if stageData.BattleEvent and #stageData.BattleEvent > 0 then
                local temp = {}
                for i = 1, #stageData.BattleEvent do
                    local becId = stageData.BattleEvent[i]
                    if becId and BattleEventConfig[becId] then
                        if #BattleEventConfig[becId].Event ~= 5 then
                            LogError("### BattleEventConfig[i].Event not 5")
                        end
                        local typeId = BattleEventConfig[becId].Event[1]
                        if (typeId == FightUnitType.UnitSupport or 
                            typeId == FightUnitType.UnitAircraftCarrier or 
                            typeId == FightUnitType.UnitAdjutant) then --< 类型判断 坦克类型不加入

                            table.insert(temp, {})
                            for j = 1, #BattleEventConfig[becId].Event do
                                table.insert(temp[#temp], tonumber(BattleEventConfig[becId].Event[j]))
                            end
                            table.insert(temp[#temp], tonumber(BattleEventConfig[becId].Dialogue))
                        end
                    end
                end
                --> 1 FightUnitType 2 rootId 3 skilllv 4 camp 5 round
                -- local temp = {{1, 1, 1, 0, 3}, {3, 1, 1, 1, 2}}
                for i = 1, #temp do
                    this.AddUnitDataByType(temp[i][2], fightData.fightUnitDataAppend, temp[i][3], temp[i][1], temp[i][4])
                    fightData.fightUnitDataAppend[i].round = temp[i][5]
                    fightData.fightUnitDataAppend[i].client_dialogue = temp[i][6]   --< 只在客户端用 模拟战斗中不能用
                end
            end
        else
            LogError(string.format("BattleManager stageData nil fightId is %s", tostring(fightId)))
        end
    else
    end

    --> 关卡插入 坦克类型
    if fightId then
        local stageData = MainLevelConfig[fightId]
        if stageData then
            local msgTankAppendData = msg.fightData.temporaryUnit
            if #msgTankAppendData > 0 then
                local dialogueIdx = 1
                for j = 1, #msgTankAppendData do
                    local dialogue = 0
                    for k = 1, #stageData.BattleEvent do
                        if BattleEventConfig[stageData.BattleEvent[k]].Event[1] == 4 and dialogueIdx == j then --< 4类型为tank
                            dialogue = BattleEventConfig[stageData.BattleEvent[k]].Dialogue
                            dialogueIdx = dialogueIdx + 1
                        end
                    end

                    local skills, propertys, role
                    local monsterConfig = ConfigManager.GetConfigData(ConfigName.MonsterConfig, tonumber(msgTankAppendData[j].unitId))
                    skills = string.split(msgTankAppendData[j].unitSkillIds, "#")
                    propertys = string.split(msgTankAppendData[j].property, "#")
                    role = {
                        roleId = monsterConfig.MonsterId,
                        position = tonumber(msgTankAppendData[j].position),
                        star = monsterConfig.Star,
                        camp = tonumber(msgTankAppendData[j].camp),
                        type = monsterConfig.Type,
                        quality = monsterConfig.Quality,
                        element = monsterConfig.PropertyName,
                        ai = monsterConfig.MonsterAi,
                        professionId = monsterConfig.Profession,
                        size = monsterConfig.Size,
                        passivity = { },
                        property = { },
                        round = tonumber(msgTankAppendData[j].round),
                        client_dialogue = dialogue --< 只在客户端用 模拟战斗中不能用
                    }
                    role.skillArray = {}
                    local passivityList = {}
                    local idx = 1
                    for i = 1, #skills do
                        if skills[i] and skills[i] ~= 0 then
                            --> 0 1 3 主动技
                            --> monster 技能顺序为 三个主动后面全是被动11011...格式
                            if i <= 3 then
                                role.skillArray[idx] = this.GetSkillData(tonumber(skills[i]))
                                idx = idx + 1
                            else
                                table.insert(passivityList, tonumber(skills[i]))
                            end
                        end
                    end
                    -- role.passivity, role.passivityIds = this.GetPassivityData(passivityList)
                    role.passivity = this.GetPassivityData(passivityList)
                    role.passivityIds = passivityList
            
                    for k = 1, #propertys do
                        role.property[k] = tonumber(propertys[k])
                    end
                    fightData.tankDataAppend[j] = role
                end
            end

            --插入无战斗单位进入的聊天对话
            if stageData.BattleEvent then
                local dialogue = 0
                local dialogueRound = 0
                for k = 1, #stageData.BattleEvent do
                    local battleEvent = BattleEventConfig[stageData.BattleEvent[k]]
                    if battleEvent.Event[1] == 0 then --< 0类型为不需要插入战斗单位
                        dialogue = battleEvent.Dialogue
                        dialogueRound = battleEvent.Event[5]

                        local noUnitData = {
                            round = dialogueRound,
                            client_dialogue = dialogue --< 只在客户端用 模拟战斗中不能用
                        }

                        table.insert(fightData.noUnitDataAppend, noUnitData)
                    end
                end
            end

        else
            LogError(string.format("BattleManager stageData append tank nil fightId is %s", tostring(fightId)))
        end
    end

    local data = {
        fightData = fightData,
        fightSeed = msg.fightData.fightSeed,
        fightType = msg.fightData.fightType,
        maxRound = msg.fightData.fightMaxTime,
    }

    -- 本地模拟战斗
    -- data.fightSeed = 1661235986
    -- {enemyData={{
    --     {ai={0},size=1,start=0,camp=1,element=4,
    --passivity={{{369},{6,1,0.3,2}},{{371},{6,2,0.09}},{{385},{2,23,1,0.01,10}}},
    --passivityIds={40423,60353,60302,60242,60291,60372,810251},position=2,professionId=1,
    --property={221,591983,591983,46673,1907,0,1646,0.1,0.185,1.025,0.02,0.17,1.545,0.11,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.02,0.105,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0},
    --quality=0,roleId=10062,round=0,
    --skillArray={
        --{40401,0.4,{0},1,1300,0,0,
        --{cd=0,isCannon=0,release=1,slot=0},
        --{400000,{1,1,1}}},
        --{40413,0.57,{0.2,0.2},3,2200,0,0,{cd=3,isCannon=0,release=1,slot=1},
        --{200000,{1,0.99,1},{3,0.3,1,2}}},
        --{40433,2,{0.4},2,3000,0,0,{cd=3,isCannon=0,release=2,slot=3},
        --{100000,{213,1,2,12,0.2}}}},type=4},
   --skill = {skillId, 命中时间, 持续时间, 伤害次数, {目标id1, 效果1, 效果2, ...},{目标id2, 效果3, 效果4, ...}, ...}
    --效果 = {效果类型id, 效果参数1, 效果参数2, ...}
    --     {ai={0},size=1,start=0,camp=1,element=3,passivity={{{369},{6,1,0.3,2}},{{371},{6,2,0.09}},{{385},{2,23,1,0.01,10}}},passivityIds={10223,60353,60302,60242,60291,60372,810251},position=4,professionId=1,property={221,475696,475696,44650,1852,0,1527,0.1,0.185,1.025,0.02,0.17,1.545,0.11,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.02,0.105,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0},quality=0,roleId=10038,round=0,skillArray={{10201,0.4,{0.263},2,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{10213,0.99,{0},1,1700,0,0,{cd=1,isCannon=0,release=1,slot=1},{210000,{10,2.06,1,0.3}}},{10233,1.15,{0},1,2600,0,0,{cd=3,isCannon=0,release=2,slot=3},{300000,{4,23,0.25,2,1},{4,6,0.25,2,1}}}},type=3},
    --     {ai={0},size=1,start=0,camp=1,element=4,passivity={{{334},{1,0.5,1,10,2}},{{369},{18,1,0.2,2}},{{357},{0.2,3}},{{368},{2,4,0.2}},{{360},{0.2,4,4,0.1,2}},{{377},{0.031,5}},{{385},{2,4,1,10,10}}},passivityIds={40723,40743,60423,60152,60332,60181,60042,90202,810351},position=6,professionId=2,property={221,416745,416745,64048,1573,0,1710,0.185,0.05,1.025,0.02,0.255,1.715,0.025,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.07,0.02,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0},quality=0,roleId=10065,round=0,skillArray={{40701,0.53,{0},1,1200,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40713,1.4,{0.08,0.08,0.24},4,3100,0,0,{cd=3,isCannon=0,release=1,slot=1},{200000,{1,1.28,2},{254,0.5,1,5,4,0.1,3}}},{40733,3.65,{0.397,0.66},3,6300,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.51,2},{230,5,0.45,1,2},{231,5,0.2,1,2}}}},type=4},
    --     {ai={0},size=1,start=0,camp=1,element=2,passivity={{{319},{5,1,0.25,9,1,0.15,1,0.8}},{{369},{17,1,0.2,2}},{{368},{2,4,0.2}},{{358},{12,0.3,0.2,1,2}},{{385},{2,4,1,10,10}}},passivityIds={30223,30243,60413,60092,60332,60161,60052,810351},position=7,professionId=3,property={221,397484,397484,64600,1462,0,1640,0.185,0.05,1.025,0.02,0.255,1.715,0.025,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.07,0.02,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0},quality=0,roleId=10020,round=0,skillArray={{30201,0.4,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{30213,0.85,{0},1,1700,0,0,{cd=3,isCannon=0,release=1,slot=1},{250002,{235,2,22,1,0.3},{1,2.1,1},{3,0.59,2,1}}},{30233,0.95,{0},1,2100,0,0,{cd=3,isCannon=0,release=2,slot=3},{200111,{232,1,0.4,2,5,1,0.25},{1,3.75,1},{226,12,0.25}}}},type=2},
    --     {ai={0},size=1,start=0,camp=1,element=3,passivity={{{369},{6,1,0.3,2}},{{365},{0.45,4}},{{366},{12,0.04}},{{385},{2,27,1,0.01,10}}},passivityIds={11121,60353,60232,60252,60241,60312,810651},position=9,professionId=4,property={221,447306,447306,54316,1575,0,1447,0.1,0.135,1.025,0.02,0.17,1.545,0.11,0.05,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.02,0.105,0.0,0.0,0.0,0.0,0.0,0.05,0.0,0.0,0.0,0.0,0.0,0.0},quality=0,roleId=10047,round=0,skillArray={{11101,0.4,{0},1,1100,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{11111,1.1,{0},1,1800,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{1,1.7,2},{254,0.3,1,1,4,0.3,2}}},{11131,1.9,{0},1,2400,0,0,{cd=3,isCannon=0,release=2,slot=3},{100112,{24,1,2.47}}}},type=3},teamPassive={},teamSkill={}}},
    --     fightUnitData={{camp=0,property={},rootId=5,skill={{80404,2.5,{0.15,0.15,0.15,0.15,0.15,0.15,0.15,0.15,0.15},10,4800,0,0,{cd=2,isCannon=0,release=3,slot=1},{200002,{272,4992},{275,0.16,1,2}}}},type=1},{},{},{},{},{}},
    --     playerData={{camp=0,size=1,element=3,passivity={{{300},{9,1,0.2,18,1,0.2,1}},{{358},{12,0.3,0.2,1,2}},{{350},{2,0.2,0.5,24,4,0.5}},{{366},{12,0.06}}},passivityIds={10123,10143,60161,60031,60012,60253},position=1,professionId=2,property={251,527538,527538,75309,1693,0,1783,0.045,0,1.01,0.01,0.31,1.62,0.01,0,0,0,0,0,0,0,0,0,0.01,0.01,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10037,skillArray={{10101,1,{0},1,1400,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{10113,2.4,{0.096,0.147,0.257},4,4600,0,0,{cd=1,isCannon=0,release=1,slot=1},{200000,{1,1,2},{211,0.5,1,20,4,0.2,2}}},{10133,2.456,{0.45,0.45,0.45},4,5300,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.58,2},{254,1,1,1,4,0.15,2}}}},type=1},
    --     {camp=0,size=1,element=2,passivity={{{319},{5,1,0.2,9,1,0.1,0.6,0.8}},{{358},{12,0.3,0.2,1,2}},{{370},{1,0.3}}},passivityIds={30223,30242,60161,60363,60083},position=3,professionId=3,property={205,283091,283091,54873,1347,0,1454,0.1,0,1.01,0.01,0.415,2.03,0.01,0,0,0,0,0,0,0,0,0,0.01,0.01,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10020,skillArray={{30201,0.4,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{30213,0.85,{0},1,1700,0,0,{cd=3,isCannon=0,release=1,slot=1},{250002,{235,2,22,1,0.3},{1,2.1,1},{3,0.59,2,1}}},{30233,0.95,{0},1,2100,0,0,{cd=3,isCannon=0,release=2,slot=3},{200111,{232,1,0.4,2,5,1,0.25},{1,3.75,1},{226,12,0.25}}}},type=1},
    --     {camp=0,size=1,element=1,passivity={{{313},{0.08}},{{367},{0.12,12,0.1,3}}},passivityIds={20321,20341,60261},position=4,professionId=4,property={100,90937,90937,11665,755,0,696,0,0,1.01,0.01,0.11,1.52,0.01,0,0,0,0,0,0,0,0,0,0.01,0.01,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10004,skillArray={{20301,0.55,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{20311,1.05,{0.15,0.15,0.15,0.15},5,2000,0,0,{cd=1,isCannon=0,release=1,slot=1},{240000,{211,0.5,1,6,3,0.2,2},{1,0.87,2}}},{20331,1.7,{0},1,2700,0,0,{cd=3,isCannon=0,release=2,slot=3},{100000,{263,0.1,2,1}}}},type=1},
    --     {camp=0,size=1,element=2,passivity={{{367},{0.12,12,0.1,3}},{{354},{8,2,0.25,2}}},passivityIds={30523,30542,60261,60113},position=6,professionId=2,property={185,220444,220444,31271,1386,0,1256,0.045,0.15,1.01,0.01,0.16,1.62,0.01,0,0,0,0,0,0,0,0,0,0.01,0.01,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10023,skillArray={{30501,0.48,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{30513,0.5,{0.1,0.47},3,1900,0,0,{cd=3,isCannon=0,release=1,slot=1},{200000,{1,1.44,2},{3,0.25,1,2}}},{30532,1.03,{0.25,0.25,0.25,0.45,0.85},6,4000,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{239,1,5,1,0.2},{1,1.38,2}}}},type=1},
    --     {camp=0,size=1,element=5,passivity={{{347},{5,1,0.12}},{{370},{1,0.25}},{{358},{12,0.3,0.2,1,2}}},passivityIds={50722,50742,60362,60161},position=8,professionId=3,property={149,191168,191168,24197,1205,0,1121,0.1,0,1.01,0.01,0.315,1.73,0.01,0,0,0,0,0,0,0,0,0,0.01,0.01,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10082,skillArray={{50701,0.35,{0},1,1200,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{50713,0.73,{0},1,1400,0,0,{cd=3,isCannon=0,release=1,slot=1},{200003,{1,1.71,1},{261,0.72,3,1,0.15,2}}},{50732,0.6,{0.1,0.1,0.1,0.6,0.1,0.55},7,2700,0,0,{cd=3,isCannon=0,release=2,slot=3},{400000,{264,3,1,6,3,0.2},{1,3.13,1}}}},type=1},
    --     firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={}}
        
    -- data.fightSeed = 1661307997
    -- data.fightData={enemyData={{{ai={0},camp=1,element=3,passivity={{{369},{6,1,0.3,2}},{{371},{6,2,0.09}},{{385},{2,23,1,0.01,10}}},passivityIds={11521,60353,60302,60242,60291,60372,810251},position=1,professionId=1,property={224,520414,520414,47645,1877,0,1519,0.1,0.19,1.025,0.02,0.17,1.545,0.115,0,0,0,0,0,0,0,0,0,0.03,0.11,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10051,size=1,skillArray={{11501,0.35,{0.29},2,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{11511,0.5,{0.25,0.3,0.2,0.4},5,2800,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{10,1.4,1,1}}},{11531,1.2,{0},1,2200,0,0,{cd=3,isCannon=0,release=2,slot=3},{100321,{220,0.4,2,3}},{300000,{211,1,1,23,2,0.3,2}}}},star=0,type=3},{ai={0},camp=1,element=1,passivity={{{371},{6,2,0.09}},{{314},{12,0.55,6,1,0.3}},{{369},{6,1,0.3,2}},{{385},{2,23,1,0.01,10}},{{315},{1,5,12,0.07,1}}},passivityIds={20623,20633,20643,60353,60302,60242,60291,60372,810251},position=3,professionId=1,property={224,514137,514137,48389,1808,0,1576,0.1,0.19,1.025,0.02,0.17,1.545,0.115,0,0,0,0,0,0,0,0,0,0.03,0.11,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10007,size=1,skillArray={{20601,0.38,{0},1,1000,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{20613,0.86,{0},1,2200,0,0,{cd=0,isCannon=0,release=1,slot=1},{230000,{219,1.56,1,0.9,4,2,1.04,1,1,1,0.15}}}},star=0,type=1},{ai={0},camp=1,element=4,passivity={{{368},{2,4,0.2}},{{360},{0.2,4,4,0.1,2}},{{357},{0.2,3}},{{369},{18,1,0.2,2}},{{385},{2,4,1,10,10}}},passivityIds={40921,60423,60152,60332,60181,60042,810351},position=5,professionId=2,property={224,550424,550424,68697,1597,0,1713,0.19,0.05,1.025,0.02,0.26,1.725,0.025,0,0,0,0,0,0,0,0,0,0.08,0.02,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10067,size=1,skillArray={{40901,0.68,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40911,1.7,{0},1,2000,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{1,1.68,2},{3,0.2,1,2}}},{40931,1.1,{0},1,2300,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.29,2},{3,0.2,1,2}}}},star=0,type=4},{ai={0},camp=1,element=4,passivity={{{368},{2,4,0.2}},{{360},{0.2,4,4,0.1,2}},{{357},{0.2,3}},{{369},{18,1,0.2,2}},{{385},{2,4,1,10,10}}},passivityIds={40921,60423,60152,60332,60181,60042,810351},position=7,professionId=2,property={224,458687,458687,68697,1597,0,1713,0.19,0.05,1.025,0.02,0.26,1.725,0.025,0,0,0,0,0,0,0,0,0,0.08,0.02,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10067,size=1,skillArray={{40901,0.68,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40911,1.7,{0},1,2000,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{1,1.68,2},{3,0.2,1,2}}},{40931,1.1,{0},1,2300,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.29,2},{3,0.2,1,2}}}},star=0,type=4},{ai={0},camp=1,element=4,passivity={{{369},{6,1,0.3,2}},{{365},{0.45,4}},{{385},{2,27,1,0.01,10}},{{366},{12,0.04}}},passivityIds={41221,60353,60232,60252,60241,60312,810651},position=9,professionId=4,property={224,514370,514370,56030,1651,0,1594,0.1,0.14,1.025,0.02,0.17,1.545,0.115,0.1802,0,0,0,0,0,0,0,0,0.03,0.11,0,0,0,0,0,0.05,0,0,0,0,0,0},quality=0,roleId=10070,size=1,skillArray={{41201,0.46,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{41211,0.5,{0},1,1600,0,0,{cd=1,isCannon=0,release=1,slot=1},{100111,{24,1,1.18}}},{41231,2,{0},1,2400,0,0,{cd=3,isCannon=0,release=2,slot=3},{100000,{24,1,0.98},{211,1,1,22,1,0.2,2}}}},star=0,type=4},firstCamp=0,outData="",teamPassive={},teamSkill={}}},fightUnitData={},fightUnitDataAppend={},noUnitDataAppend={},playerData={{camp=0,element=4,passivity={},passivityIds={40423},position=2,professionId=1,property={255,657846,657846,47322,1890,0,1696,0,0.23,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10062,size=1,skillArray={{40401,0.4,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{40413,0.57,{0.2,0.2},3,2200,0,0,{cd=3,isCannon=0,release=1,slot=1},{200000,{1,0.99,1},{3,0.3,1,2}}},{40433,2,{0.4},2,3000,0,0,{cd=3,isCannon=0,release=2,slot=3},{100000,{213,1,2,12,0.2}}}},star=10,type=1},{camp=0,element=4,passivity={{{334},{1,0.5,1,10,2}}},passivityIds={40723,40743},position=4,professionId=2,property={255,573956,573956,79328,1768,0,1682,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10065,size=1,skillArray={{40701,0.53,{0},1,1200,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40713,1.4,{0.08,0.08,0.24},4,3100,0,0,{cd=3,isCannon=0,release=1,slot=1},{200000,{1,1.28,2},{254,0.5,1,5,4,0.1,3}}},{40733,3.65,{0.397,0.66},3,6300,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.51,2},{230,5,0.45,1,2},{231,5,0.2,1,2}}}},star=10,type=1},{camp=0,element=4,passivity={{{328},{1,2.41,1}}},passivityIds={40123,40143},position=7,professionId=4,property={255,581467,581467,72085,1837,0,1667,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10059,size=1,skillArray={{40101,0.65,{0},1,1300,400,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40113,1.05,{0},1,1600,0,0,{cd=3,isCannon=0,release=1,slot=1},{100324,{208,1,1,0,6},{211,1,1,22,1,0.25,2},{236,4,9,1,0.2,2}}},{40133,1.7,{0},1,2300,0,0,{cd=3,isCannon=0,release=2,slot=3},{100000,{253,20,1,0.15,2,1,0.98}}}},star=10,type=1},{camp=0,element=4,passivity={{{338,338,339},{4,22,1,0.09},{4,15,1,0.09},{1,0.15}}},passivityIds={41523,41543},position=6,professionId=3,property={255,578888,578888,81251,1806,0,1672,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10057,size=1,skillArray={{41501,0.45,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{41513,2.1,{0.15,0.15,0.15,0.15},5,5500,0,0,{cd=3,isCannon=0,release=1,slot=1},{270000,{1,2.07,1}},{270321,{261,0.6,6,12,0.07,2}}},{41533,0.75,{0.43,0.83,0.4},4,4200,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.51,1}},{200211,{211,1,1,6,3,0.2,2}},{200221,{3,0.5,4,2}}}},star=10,type=1},{camp=0,element=4,passivity={{{332},{0.6,1.2,1}},{{302},{1,1,1,1}},{{331},{12,0.3}}},passivityIds={40523,40533,40543},position=9,professionId=3,property={255,516631,516631,77461,1802,0,1642,0,0.03,1,0,0.2,1.7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10063,size=1,skillArray={{40501,0.4,{0},1,1100,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{40513,1.6,{0.15,0.15,0.15,0.15,0.15},6,3000,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{240,5,6,3,0.25},{260,1,1,23,3,0.4},{10,2.31,1,0.3}}}},star=10,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={}}
    

    
    -- {enemyData={{{camp=1,element=5,size=1,passivity={{{347},{5,1,0.15}}},passivityIds={50723,50743},position=2,professionId=3,property={340,1095843,1095843,108605,2359,0,2100,0,0,1,0,0.25,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10082,size=1,skillArray={{50701,0.35,{0},1,1200,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{50713,0.73,{0},1,1400,430,0,{cd=3,isCannon=0,release=1,slot=1},{200003,{1,1.71,1},{261,0.72,3,1,0.15,2}}},{50733,0.6,{0.1,0.1,0.1,0.6,0.1,0.55},7,2700,0,0,{cd=3,isCannon=0,release=2,slot=3},{400000,{264,3,1,6,3,0.2},{1,3.75,1},{216,0}}}},star=13,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}}},fightUnitData={},fightUnitDataAppend={},noUnitDataAppend={},
    -- playerData={{camp=0,element=2,size=1,isTibu=false,passivity={{{396},{1,10,22,1,0.03}}},passivityIds={30123,30143},position=2,professionId=3,property={340,833612,833612,115416,2145,0,2050,0,0,1,0,0.25,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10019,size=1,skillArray={{30101,0.25,{0.25},2,1350,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{30113,0.7,{0},1,1900,0,0,{cd=3,isCannon=0,release=1,slot=1},{300000,{245,2},{211,1,2,9,1,0.3,2},{211,1,1,6,1,0.25,2}}},{30133,0.3,{0.3,0.9,0.75,0.35},5,3500,0,0,{cd=3,isCannon=0,release=2,slot=3},{400000,{260,1,2,7,1,0.3},{285,4.53,1,3,0.33,2,2}}}},star=13,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={},tibuData={}}
    -- data.fightData =
    -- {enemyData={{{camp=1,element=5,size=1,passivity={{{347},{5,1,0.15}}},passivityIds={50723,50743},position=2,professionId=3,property={340,1095843,1095843,108605,2359,0,2100,0,0,1,0,0.25,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10082,size=1,skillArray={{50701,0.35,{0},1,1200,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{50713,0.73,{0},1,1400,430,0,{cd=3,isCannon=0,release=1,slot=1},{200003,{1,1.71,1},{261,0.72,3,1,0.15,2}}},{50733,0.6,{0.1,0.1,0.1,0.6,0.1,0.55},7,2700,0,0,{cd=3,isCannon=0,release=2,slot=3},{400000,{264,3,1,6,3,0.2},{1,3.75,1},{216,0}}}},star=13,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}}},fightUnitData={},fightUnitDataAppend={},noUnitDataAppend={},
    -- playerData={{camp=0,element=2,size=1,isTibu=false,passivity={{{396},{1,10,22,1,0.03}}},passivityIds={30123,30143},position=2,professionId=3,property={340,833612,833612,115416,2145,0,2050,0,0,1,0,0.25,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10019,size=1,skillArray={{30101,0.25,{0.25},2,1350,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{30113,0.7,{0},1,1900,0,0,{cd=3,isCannon=0,release=1,slot=1},{300000,{245,2},{211,1,2,9,1,0.3,2},{211,1,1,6,1,0.25,2}}},{30133,0.3,{0.3,0.9,0.75,0.35},5,3500,0,0,{cd=3,isCannon=0,release=2,slot=3},{400000,{260,1,2,7,1,0.3},{285,4.53,1,3,0.33,2,2}}}},star=13,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={},tibuData={}}
    
    -- data.fightSeed=1670224979
    -- data.fightSeed=1673022464
    -- data.fightData =
    -- {enemyData={{{ai={0},camp=1,element=3,size=1,passivity={},passivityIds={},position=2,professionId=1,property={1,199,199,65,39,0,72,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10052,size=1,skillArray={{11801,0.38,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{11811,0.61,{0},1,1500,0,0,{cd=3,isCannon=0,release=1,slot=1},{400000,{1,2.18,1}}}},star=0,type=3},
    -- {ai={0},camp=1,size=1,element=2,passivity={},passivityIds={},position=8,professionId=3,property={1,207,207,60,25,0,59,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10034,size=1,skillArray={{32001,0.38,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{32011,0.83,{0},1,1700,570,0,{cd=3,isCannon=0,release=1,slot=1},{200111,{1,2.47,1}}}},star=0,type=2},firstCamp=0,outData="",teamPassive={},teamSkill={}}},fightUnitData={},fightUnitDataAppend={},noUnitDataAppend={},
    -- playerData={{camp=0,size=1,element=3,isTibu=false,passivity={},passivityIds={},position=2,professionId=1,property={1,514,514,73,44,0,79,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10051,size=1,skillArray={{11501,0.35,{0.29},2,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{11511,0.5,{0.25,0.3,0.2,0.4},5,2800,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{10,1.4,1,1}}}},star=4,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={},tibuData={}}

    
    -- this.Execute({seed=1661307997, type=1, maxTime=300},{enemyData={{{ai={0},camp=1,element=3,passivity={{{369},{6,1,0.3,2}},{{371},{6,2,0.09}},{{385},{2,23,1,0.01,10}}},passivityIds={11521,60353,60302,60242,60291,60372,810251},position=1,professionId=1,property={224,520414,520414,47645,1877,0,1519,0.1,0.19,1.025,0.02,0.17,1.545,0.115,0,0,0,0,0,0,0,0,0,0.03,0.11,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10051,size=1,skillArray={{11501,0.35,{0.29},2,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{11511,0.5,{0.25,0.3,0.2,0.4},5,2800,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{10,1.4,1,1}}},{11531,1.2,{0},1,2200,0,0,{cd=3,isCannon=0,release=2,slot=3},{100321,{220,0.4,2,3}},{300000,{211,1,1,23,2,0.3,2}}}},star=0,type=3},{ai={0},camp=1,element=1,passivity={{{371},{6,2,0.09}},{{314},{12,0.55,6,1,0.3}},{{369},{6,1,0.3,2}},{{385},{2,23,1,0.01,10}},{{315},{1,5,12,0.07,1}}},passivityIds={20623,20633,20643,60353,60302,60242,60291,60372,810251},position=3,professionId=1,property={224,514137,514137,48389,1808,0,1576,0.1,0.19,1.025,0.02,0.17,1.545,0.115,0,0,0,0,0,0,0,0,0,0.03,0.11,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10007,size=1,skillArray={{20601,0.38,{0},1,1000,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{20613,0.86,{0},1,2200,0,0,{cd=0,isCannon=0,release=1,slot=1},{230000,{219,1.56,1,0.9,4,2,1.04,1,1,1,0.15}}}},star=0,type=1},{ai={0},camp=1,element=4,passivity={{{368},{2,4,0.2}},{{360},{0.2,4,4,0.1,2}},{{357},{0.2,3}},{{369},{18,1,0.2,2}},{{385},{2,4,1,10,10}}},passivityIds={40921,60423,60152,60332,60181,60042,810351},position=5,professionId=2,property={224,550424,550424,68697,1597,0,1713,0.19,0.05,1.025,0.02,0.26,1.725,0.025,0,0,0,0,0,0,0,0,0,0.08,0.02,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10067,size=1,skillArray={{40901,0.68,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40911,1.7,{0},1,2000,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{1,1.68,2},{3,0.2,1,2}}},{40931,1.1,{0},1,2300,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.29,2},{3,0.2,1,2}}}},star=0,type=4},{ai={0},camp=1,element=4,passivity={{{368},{2,4,0.2}},{{360},{0.2,4,4,0.1,2}},{{357},{0.2,3}},{{369},{18,1,0.2,2}},{{385},{2,4,1,10,10}}},passivityIds={40921,60423,60152,60332,60181,60042,810351},position=7,professionId=2,property={224,458687,458687,68697,1597,0,1713,0.19,0.05,1.025,0.02,0.26,1.725,0.025,0,0,0,0,0,0,0,0,0,0.08,0.02,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10067,size=1,skillArray={{40901,0.68,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40911,1.7,{0},1,2000,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{1,1.68,2},{3,0.2,1,2}}},{40931,1.1,{0},1,2300,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.29,2},{3,0.2,1,2}}}},star=0,type=4},{ai={0},camp=1,element=4,passivity={{{369},{6,1,0.3,2}},{{365},{0.45,4}},{{385},{2,27,1,0.01,10}},{{366},{12,0.04}}},passivityIds={41221,60353,60232,60252,60241,60312,810651},position=9,professionId=4,property={224,514370,514370,56030,1651,0,1594,0.1,0.14,1.025,0.02,0.17,1.545,0.115,0.1802,0,0,0,0,0,0,0,0,0.03,0.11,0,0,0,0,0,0.05,0,0,0,0,0,0},quality=0,roleId=10070,size=1,skillArray={{41201,0.46,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{41211,0.5,{0},1,1600,0,0,{cd=1,isCannon=0,release=1,slot=1},{100111,{24,1,1.18}}},{41231,2,{0},1,2400,0,0,{cd=3,isCannon=0,release=2,slot=3},{100000,{24,1,0.98},{211,1,1,22,1,0.2,2}}}},star=0,type=4},firstCamp=0,outData="",teamPassive={},teamSkill={}}},fightUnitData={},fightUnitDataAppend={},noUnitDataAppend={},playerData={{camp=0,element=4,passivity={},passivityIds={40423},position=2,professionId=1,property={255,657846,657846,47322,1890,0,1696,0,0.23,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10062,size=1,skillArray={{40401,0.4,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{40413,0.57,{0.2,0.2},3,2200,0,0,{cd=3,isCannon=0,release=1,slot=1},{200000,{1,0.99,1},{3,0.3,1,2}}},{40433,2,{0.4},2,3000,0,0,{cd=3,isCannon=0,release=2,slot=3},{100000,{213,1,2,12,0.2}}}},star=10,type=1},{camp=0,element=4,passivity={{{334},{1,0.5,1,10,2}}},passivityIds={40723,40743},position=4,professionId=2,property={255,573956,573956,79328,1768,0,1682,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10065,size=1,skillArray={{40701,0.53,{0},1,1200,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40713,1.4,{0.08,0.08,0.24},4,3100,0,0,{cd=3,isCannon=0,release=1,slot=1},{200000,{1,1.28,2},{254,0.5,1,5,4,0.1,3}}},{40733,3.65,{0.397,0.66},3,6300,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.51,2},{230,5,0.45,1,2},{231,5,0.2,1,2}}}},star=10,type=1},{camp=0,element=4,passivity={{{328},{1,2.41,1}}},passivityIds={40123,40143},position=7,professionId=4,property={255,581467,581467,72085,1837,0,1667,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10059,size=1,skillArray={{40101,0.65,{0},1,1300,400,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{40113,1.05,{0},1,1600,0,0,{cd=3,isCannon=0,release=1,slot=1},{100324,{208,1,1,0,6},{211,1,1,22,1,0.25,2},{236,4,9,1,0.2,2}}},{40133,1.7,{0},1,2300,0,0,{cd=3,isCannon=0,release=2,slot=3},{100000,{253,20,1,0.15,2,1,0.98}}}},star=10,type=1},{camp=0,element=4,passivity={{{338,338,339},{4,22,1,0.09},{4,15,1,0.09},{1,0.15}}},passivityIds={41523,41543},position=6,professionId=3,property={255,578888,578888,81251,1806,0,1672,0,0.03,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10057,size=1,skillArray={{41501,0.45,{0},1,1300,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{41513,2.1,{0.15,0.15,0.15,0.15},5,5500,0,0,{cd=3,isCannon=0,release=1,slot=1},{270000,{1,2.07,1}},{270321,{261,0.6,6,12,0.07,2}}},{41533,0.75,{0.43,0.83,0.4},4,4200,0,0,{cd=3,isCannon=0,release=2,slot=3},{200000,{1,1.51,1}},{200211,{211,1,1,6,3,0.2,2}},{200221,{3,0.5,4,2}}}},star=10,type=1},{camp=0,element=4,passivity={{{332},{0.6,1.2,1}},{{302},{1,1,1,1}},{{331},{12,0.3}}},passivityIds={40523,40533,40543},position=9,professionId=3,property={255,516631,516631,77461,1802,0,1642,0,0.03,1,0,0.2,1.7,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=0,roleId=10063,size=1,skillArray={{40501,0.4,{0},1,1100,0,0,{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{40513,1.6,{0.15,0.15,0.15,0.15,0.15},6,3000,0,0,{cd=1,isCannon=0,release=1,slot=1},{400000,{240,5,6,3,0.25},{260,1,1,23,3,0.4},{10,2.31,1,0.3}}}},star=10,type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tankDataAppend={}})
--     data.fightData =
--     {enemyData={{
--         {camp=1,element=5,size=1,passivity={},passivityIds={},position=1,professionId=1,property={38,3277,3277,426,308,0,337,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10081,skillArray={{"50601",0.68,{0},1,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"50611",0.3,{0.15,0.15,0.15,0.15,0.6},6,2200,0,"0",{cd=1,isCannon=0,release=1,slot=1},{210001,{1,1.23,1},{268,1,2,1,0.3}}}},type=1},
--         {camp=1,element=3,size=1,passivity={},passivityIds={},position=3,professionId=1,property={38,3086,3086,396,302,0,321,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10038,skillArray={{"10201",0.4,{0.263},2,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"10211",0.99,{0},1,1700,0,"0",{cd=1,isCannon=0,release=1,slot=1},{210000,{10,1.45,1,0.1}}}},type=1},
--         {camp=1,element=1,size=1,passivity={},passivityIds={},position=5,professionId=3,property={38,2661,2661,557,278,0,313,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10008,skillArray={{"20701",1.05,{0},1,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"20711",1.2,{0},1,1700,0,"0",{cd=1,isCannon=0,release=1,slot=1},{200000,{1,0.9,1},{254,0.3,1,2,3,0.2,2}}}},type=1},
--         {camp=1,element=4,size=1,passivity={},passivityIds={},position=7,professionId=4,property={38,3085,3085,508,306,0,337,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10060,skillArray={{"40201",0.56,{0},1,1200,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"40211",1.5,{0},1,2200,0,"0",{cd=1,isCannon=0,release=1,slot=1},{100000,{24,1,0.69},{214,1,2,6,1,0.15,14,1,0.25,11,1,0,2}}}},type=1},
--         {camp=1,element=4,size=1,passivity={},passivityIds={},position=9,professionId=1,property={38,3227,3227,425,311,0,345,0,0,1,0,0.1,1.5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10062,skillArray={{"40401",0.4,{0},1,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"40411",0.57,{0.2,0.2},3,2200,0,"0",{cd=3,isCannon=0,release=1,slot=1},{200000,{1,0.69,1},{3,0.1,1,2}}}},type=1},firstCamp=1,outData="",teamPassive={},teamSkill={}}},
--         fightUnitData={{},{},{},{},{},{}},
-- leaderData={{camp=0,property={"65","88111","88111","23713","611","0","294","0.0","0.0","1.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0.0","0","0","0.0"},
-- rootId=65,size=1,
-- skill={{"910914",1.1,{0},1,2000,0,"0",{cd=3,isCannon=0,release=1,slot=0,sort="1"},{200111,{281,7.41,1,1}}},{"910613",1.1,{0},1,2000,0,"0",{cd=3,isCannon=0,release=2,slot=0,sort="2"},{100113,{4,13,0.42,2,2},{211,1,1,13,2,0.05,2},{212,1,1,15,1,0.09,6,1,0.09,2},{232,1,0.3,1,14,1,1.5}}},{"910112",2.5,{0},1,4000,0,"0",{cd=3,isCannon=0,release=3,slot=0,sort="3"},{200111,{1,3.12,2},{211,1,1,22,3,0.1,1},{261,0.05,2,1,1,1}}},{"910611",1.1,{0},1,2000,0,"0",{cd=3,isCannon=0,release=4,slot=0,sort="4"},{100113,{4,13,0.29,2,2},{211,1,1,13,2,0.04,2},{212,1,1,15,1,0.05,6,1,0.05,2},{232,1,0.3,1,14,1,1.5}}}},type=2}},
-- playerData={
-- {camp=0,element=4,size=1,passivity={{{329},{1,0.5}}},passivityIds={"40223","40243"},position=4,professionId=4,property={340,1176825,1176825,89971,2405,0,2138,0,0,1,0,0.1,1.5,0,0.1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10060,skillArray={{"40201",0.56,{0},1,1200,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"40213",1.5,{0},1,2200,0,"0",{cd=1,isCannon=0,release=1,slot=1},{100000,{24,1,0.99},{214,1,2,6,1,0.15,14,1,0.25,11,1,0.15,2}}},{"40233",2.4,{0},1,3000,0,"0",{cd=3,isCannon=0,release=2,slot=3},{700111,{221,1,1.58,1,2.3}}}},type=1},
-- {camp=0,element=2,size=1,passivity={},passivityIds={"30723","30743"},position=2,professionId=4,property={340,957687,957687,87201,2188,0,2048,0,0,1,0,0.1,1.5,0,0.15,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},quality=1,roleId=10025,skillArray={{"30701",0.4,{0},1,1200,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,2}}},{"30713",1.8,{0},1,2400,0,"0",{cd=1,isCannon=0,release=1,slot=1},{100000,{24,1,0.81},{211,1,1,22,1,0.3,2}}},{"30733",1.5,{0},1,2500,0,"0",{cd=3,isCannon=0,release=2,slot=3},{700111,{221,1,1.58,1,2.3}}}},type=1},firstCamp=0,outData="",teamPassive={},teamSkill={}},tibuData={}}

--skillArray={{"50601",0.68,{0},1,1300,0,"0",{cd=0,isCannon=0,release=1,slot=0},{400000,{1,1,1}}},{"50611",0.3,{0.15,0.15,0.15,0.15,0.6},6,2200,0,"0",{cd=1,isCannon=0,release=1,slot=1},{210001,{1,1.23,1},{268,1,2,1,0.3}}}}    
--skillArray={{"910914",1.1,{0},1,2000,0,"0",{cd=3,isCannon=0,release=1,slot=0,sort="1"},{200111,{281,7.41,1,1}}},{"910613",1.1,{0},1,2000,0,"0",{cd=3,isCannon=0,release=2,slot=0,sort="2"},{100113,{4,13,0.42,2,2},{211,1,1,13,2,0.05,2},{212,1,1,15,1,0.09,6,1,0.09,2},{232,1,0.3,1,14,1,1.5}}},{"910112",2.5,{0},1,4000,0,"0",{cd=3,isCannon=0,release=3,slot=0,sort="3"},{200111,{1,3.12,2},{211,1,1,22,3,0.1,1},{261,0.05,2,1,1,1}}},{"910611",1.1,{0},1,2000,0,"0",{cd=3,isCannon=0,release=4,slot=0,sort="4"},{100113,{4,13,0.29,2,2},{211,1,1,13,2,0.04,2},{212,1,1,15,1,0.05,6,1,0.05,2},{232,1,0.3,1,14,1,1.5}}}}   
    local op1 = {
        seed = msg.fightData.fightSeed,
        -- seed= data.fightSeed,
        type = msg.fightData.fightType,
        maxTime = msg.fightData.fightMaxTime,
    }
    local op2 = fightData
    -- if op1.type~=BATTLE_TYPE.CollectMaterials then --屏蔽简化一些
    --   this.Execute(op1, data.fightData)
    -- end

    return data
end

function this.AddUnitDataByType(rootId, parentTable, skillLv, type, camp)
    local configData = nil
    local skillid = nil
    if skillLv == 0 then skillLv = 1 end
    if type == FightUnitType.UnitSupport then
        configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ArtifactSkillConfig, "ArtifactId", rootId, "SkillLevel", skillLv)
        skillid = configData.SkillId
    elseif type == FightUnitType.UnitAdjutant then
        configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantSkillConfig, "AdjutantId", rootId, "SkillLvl", skillLv)
        skillid = configData.Skill_Id
    end  
    local fightUnitMine = {}
    fightUnitMine.skill = {}
    table.insert(fightUnitMine.skill, this.GetSkillData(skillid))
    fightUnitMine.property = {0,0,0,0,0,  0,0,0,0,10000,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0, 0,0,0,0,0,  0,0}
    fightUnitMine.rootId = rootId   --< 各系统主表id
    fightUnitMine.camp = camp
    fightUnitMine.type = type
    
    table.insert(parentTable, fightUnitMine)
end

--> 获取次级属性初始值
function this.GetSecondaryFactorValue(monsterConfig, propertyId)
    for i = 1, #monsterConfig.SecondaryFactor do
        if monsterConfig.SecondaryFactor[i][1] == propertyId then
            return monsterConfig.SecondaryFactor[i][2] / 10000
        end
    end
    return 0
end

--todo
--> 获取hero战斗数据 可分阵营
function this.GetHeroFightData(monsterId, camp)
    local monsterConfig = MonsterConfig[monsterId]
    local role = {
        roleId = monsterConfig.MonsterId,
        star = monsterConfig.Star,
        camp = camp,
        type = monsterConfig.Type,
        quality = monsterConfig.Quality,
        element = monsterConfig.PropertyName,
        professionId = monsterConfig.Profession,
        size = monsterConfig.Size,
        passivity = {},
        property = {
            monsterConfig.Level,
            monsterConfig.Hp,
            monsterConfig.Hp,
            monsterConfig.Attack,
            monsterConfig.PhysicalDefence,
            monsterConfig.MagicDefence,
            monsterConfig.Speed,
            this.GetSecondaryFactorValue(monsterConfig, 51),
            this.GetSecondaryFactorValue(monsterConfig, 52),
            this.GetSecondaryFactorValue(monsterConfig, 53),
            this.GetSecondaryFactorValue(monsterConfig, 54),
            this.GetSecondaryFactorValue(monsterConfig, 55),
            this.GetSecondaryFactorValue(monsterConfig, 56),
            this.GetSecondaryFactorValue(monsterConfig, 60),
            this.GetSecondaryFactorValue(monsterConfig, 58),
            this.GetSecondaryFactorValue(monsterConfig, 57),

            this.GetSecondaryFactorValue(monsterConfig, 151),

            this.GetSecondaryFactorValue(monsterConfig, 153),
            this.GetSecondaryFactorValue(monsterConfig, 152),
            this.GetSecondaryFactorValue(monsterConfig, 154),
            this.GetSecondaryFactorValue(monsterConfig, 65),
            this.GetSecondaryFactorValue(monsterConfig, 62),

            this.GetSecondaryFactorValue(monsterConfig, 63),
            this.GetSecondaryFactorValue(monsterConfig, 155),
            this.GetSecondaryFactorValue(monsterConfig, 156),

            this.GetSecondaryFactorValue(monsterConfig, 160),

            this.GetSecondaryFactorValue(monsterConfig, 161),
            this.GetSecondaryFactorValue(monsterConfig, 162),
            this.GetSecondaryFactorValue(monsterConfig, 163),
            this.GetSecondaryFactorValue(monsterConfig, 164),
            this.GetSecondaryFactorValue(monsterConfig, 167),

            this.GetSecondaryFactorValue(monsterConfig, 168),
            this.GetSecondaryFactorValue(monsterConfig, 169),
            this.GetSecondaryFactorValue(monsterConfig, 170),
            this.GetSecondaryFactorValue(monsterConfig, 150),
            this.GetSecondaryFactorValue(monsterConfig, 165),

            this.GetSecondaryFactorValue(monsterConfig, 166),
            this.GetSecondaryFactorValue(monsterConfig, 61)
        },
    }

    role.skillArray = {}
    local passivityList = {}
    --> 主
    for i = 1, #monsterConfig.SkillList do
        table.insert(role.skillArray, this.GetSkillData(monsterConfig.SkillList[i]))
    end
    --> 被
    for i = 1, #monsterConfig.PassiveSkillList do
        table.insert(passivityList, monsterConfig.PassiveSkillList[i])
    end

    role.passivity = this.GetPassivityData(passivityList)

    return role
end

--> 获取monster战斗数据 可分阵营
function this.GetMonsterFightData(monsterId, camp)
    local monsterConfig = MonsterConfig[monsterId]
    local role = {
        roleId = monsterConfig.MonsterId,
        star = monsterConfig.Star,
        camp = camp,
        type = monsterConfig.Type,
        quality = monsterConfig.Quality,
        element = monsterConfig.PropertyName,
        professionId = monsterConfig.Profession,
        size = monsterConfig.Size,
        passivity = {},
        property = {
            monsterConfig.Level,
            monsterConfig.Hp,
            monsterConfig.Hp,
            monsterConfig.Attack,
            monsterConfig.PhysicalDefence,
            monsterConfig.MagicDefence,
            monsterConfig.Speed,
            this.GetSecondaryFactorValue(monsterConfig, 51),
            this.GetSecondaryFactorValue(monsterConfig, 52),
            this.GetSecondaryFactorValue(monsterConfig, 53),
            this.GetSecondaryFactorValue(monsterConfig, 54),
            this.GetSecondaryFactorValue(monsterConfig, 55),
            this.GetSecondaryFactorValue(monsterConfig, 56),
            this.GetSecondaryFactorValue(monsterConfig, 60),
            this.GetSecondaryFactorValue(monsterConfig, 58),
            this.GetSecondaryFactorValue(monsterConfig, 57),

            this.GetSecondaryFactorValue(monsterConfig, 151),

            this.GetSecondaryFactorValue(monsterConfig, 153),
            this.GetSecondaryFactorValue(monsterConfig, 152),
            this.GetSecondaryFactorValue(monsterConfig, 154),
            this.GetSecondaryFactorValue(monsterConfig, 65),
            this.GetSecondaryFactorValue(monsterConfig, 62),

            this.GetSecondaryFactorValue(monsterConfig, 63),
            this.GetSecondaryFactorValue(monsterConfig, 155),
            this.GetSecondaryFactorValue(monsterConfig, 156),

            this.GetSecondaryFactorValue(monsterConfig, 160),

            this.GetSecondaryFactorValue(monsterConfig, 161),
            this.GetSecondaryFactorValue(monsterConfig, 162),
            this.GetSecondaryFactorValue(monsterConfig, 163),
            this.GetSecondaryFactorValue(monsterConfig, 164),
            this.GetSecondaryFactorValue(monsterConfig, 167),

            this.GetSecondaryFactorValue(monsterConfig, 168),
            this.GetSecondaryFactorValue(monsterConfig, 169),
            this.GetSecondaryFactorValue(monsterConfig, 170),
            this.GetSecondaryFactorValue(monsterConfig, 150),
            this.GetSecondaryFactorValue(monsterConfig, 165),

            this.GetSecondaryFactorValue(monsterConfig, 166),
            this.GetSecondaryFactorValue(monsterConfig, 61)
        },
    }

    role.skillArray = {}
    local passivityList = {}
    --> 主
    for i = 1, #monsterConfig.SkillList do
        table.insert(role.skillArray, this.GetSkillData(monsterConfig.SkillList[i]))
    end
    --> 被
    for i = 1, #monsterConfig.PassiveSkillList do
        table.insert(passivityList, monsterConfig.PassiveSkillList[i])
    end

    role.passivity = this.GetPassivityData(passivityList)

    return role
end


---> EVE 战斗测试工具 需策划提前填写好相应的表格 MonsterGroup即可
function this.GetBattleServerDataEVE(monsterGroupId1, monsterGroupId2,round)
    BattleManager.ResetCVDatas()
    local mgId1 = monsterGroupId1
    local mgId2 = monsterGroupId2
    local fightData = {
        playerData = {},
        enemyData = {},
        tibuData = {},
        fightUnitData = {},
        fightUnitDataAppend = {},
        tankDataAppend = {}
    }

    --> mine
    local monsterConfig = MonsterGroup[mgId1]
    local pos = G_FormationConfig[monsterConfig.Formation].pos
    local Contents = monsterConfig.Contents
    for i = 1, #Contents do
        local enemyList = {}
        local elementIds = {}
        local idx = 1
        for j = 1, #Contents[i] do
            if Contents[i][j] ~= 0 then
                fightData.playerData[j] = this.GetMonsterFightData(Contents[i][j], 0)
                fightData.playerData[j].position = pos[idx]
                table.insert(elementIds, fightData.playerData[j].element)
            end
            idx = idx + 1
        end
        this.SetFightElement(0, elementIds)
        break   --< 取一组
    end

    --> left
    -- local monsterConfig = MonsterGroup[mgId1]

    --> enemy
    monsterConfig = MonsterGroup[mgId2]
    pos = G_FormationConfig[monsterConfig.Formation].pos
    Contents = monsterConfig.Contents
    for i = 1, #Contents do
        local enemyList = {}
        local elementIds = {}
        local idx = 1
        for j = 1, #Contents[i] do
            if Contents[i][j] ~= 0 then
                enemyList[j] = this.GetMonsterFightData(Contents[i][j], 1)
                enemyList[j].position = pos[idx]
                table.insert(elementIds, enemyList[j].element)
            end
            idx = idx + 1
        end
        fightData.enemyData[i] = enemyList
        this.SetFightElement(1, elementIds)

        break   --< 取一组
    end
    local seed = tostring(os.time()):reverse():sub(1, 7)
    local data = {
        fightData = fightData,
        fightSeed = tonumber(seed),
        fightType = 1,
        maxRound = round,
    }
    return data
end

--> deprecated
--> gm之前用
--获取战斗数据（战斗用）
function this.GetBattleData(formationId, monsterGroupId)
    local fightData = {
        playerData = { teamSkill = {}, teamPassive = {} },
        enemyData = {},
        tibuData = {},
    }
    local pokemonInfos = FormationManager.formationList[formationId].teamPokemonInfos
    local teamHeroInfos = FormationManager.formationList[formationId].teamHeroInfos
    for i = 1, #pokemonInfos do
        fightData.playerData.teamSkill[i] = this.GetSkillData(DiffMonsterManager.GetSinglePokemonSkillIdData(pokemonInfos[i].pokemonId), pokemonInfos[i].position)
        fightData.playerData.teamPassive[i] = this.GetPassivityData(DiffMonsterManager.GetSinglePokemonPassiveSkillIdData(pokemonInfos[i].pokemonId))
    end

    for i = 1, #teamHeroInfos do
        local heroData = HeroManager.GetSingleHeroData(teamHeroInfos[i].heroId)
        if heroData then
            local role = {
                roleId = heroData.id,
                camp = 0,
                type = 1,
                quality = 0,
                element = HeroConfig[heroData.id].PropertyName,
                professionId = heroData.profession,
                size = 1,
                --skill = this.GetSkillData(1000112),
                --superSkill = nil,
                passivity = this.GetPassivityData(this.GetTalismanSkillData(heroData.dynamicId)),
            }
            if heroData.skillIdList[1] then
                role.skill = this.GetSkillData(heroData.skillIdList[1].skillId)
            end
            if heroData.skillIdList[2] then
                role.superSkill = this.GetSkillData(heroData.skillIdList[2].skillId)
            end
            local allPassiveSkillIds = HeroManager.GetHeroAllPassiveSkillIds(heroData)
            if allPassiveSkillIds then
                role.passivity = this.GetPassivityData(allPassiveSkillIds)
            end
            -- if heroData.passiveSkillList[2] then
            --     local skillPL = this.GetPassivityData({heroData.passiveSkillList[2].skillId})
            --     for i = 1, #skillPL do
            --         table.insert(role.passivity, skillPL[i])
            --     end
            -- end

            role.property = HeroManager.CalculateWarAllProVal(heroData.dynamicId)
            fightData.playerData[i] = role
        end
    end

    local Contents = MonsterGroup[monsterGroupId].Contents
    for i = 1, #Contents do
        local enemyList = { teamSkill = {}, teamPassive = {} }
        for j = 1, #Contents[i] do
            enemyList[j] = this.GetMonsterData(Contents[i][j])
        end
        fightData.enemyData[i] = enemyList
    end
    return fightData
end

--> deprecated
--> before testbattle
-- 获取我数据
function this.GetBattlePlayerData(fId)
    fId = fId or 1  -- 默认主线编队
    local playerData = { teamSkill = {}, teamPassive = {} }

    -- local pokemonInfos = FormationManager.formationList[formationId].teamPokemonInfos
    -- for i = 1, #pokemonInfos do
        -- fightData.playerData.teamSkill[i] = this.GetSkillData(DiffMonsterManager.GetSinglePokemonSkillIdData(pokemonInfos[i].pokemonId), pokemonInfos[i].position)
        -- fightData.playerData.teamPassive[i] = this.GetPassivityData(DiffMonsterManager.GetSinglePokemonPassiveSkillIdData(pokemonInfos[i].pokemonId))
    -- end
    
    local teamHeroInfos = FormationManager.formationList[fId].teamHeroInfos
    for i = 1, #teamHeroInfos do
        local teamData = teamHeroInfos[i]
        local heroData = HeroManager.GetSingleHeroData(teamData.heroId)
        if heroData then
            local role = {
                roleId = heroData.id,
                position = teamData.position,
                star = heroData.star,
                camp = 0,
                type = 1,
                quality = 0,
                element = HeroConfig[heroData.id].PropertyName,
                professionId = heroData.profession,
                size = 1,
            }
            if heroData.skillIdList[1] then
                role.skill = this.GetSkillData(heroData.skillIdList[1].skillId)
            end
            if heroData.skillIdList[2] then
                role.superSkill = this.GetSkillData(heroData.skillIdList[2].skillId)
            end
            local allPassiveSkillIds = HeroManager.GetHeroAllPassiveSkillIds(heroData)
            if allPassiveSkillIds then
                role.passivity = this.GetPassivityData(allPassiveSkillIds)
            end
            role.property = HeroManager.CalculateWarAllProVal(heroData.dynamicId)
            -- 
            table.insert(playerData, role)
        end
    end
    return playerData
end

--> deprecated
-- 根据怪物组数据
function this.GetBattleEnemyData(gId)
    -- body
    local enemyData = {}
    local Contents = MonsterGroup[gId].Contents
    for i = 1, #Contents do
        local enemyList = { teamSkill = {}, teamPassive = {} }
        for j = 1, #Contents[i] do
            if Contents[i][j] ~= 0 then
                local data =  this.GetMonsterData(Contents[i][j])
                data.position = j
                table.insert(enemyList, data)
            end
        end
        enemyData[i] = enemyList
    end
    return enemyData
end

--获取单个英雄装备被动技能list
--function this.GetSingHeroAllEquipSkillListData(_heroId)
--    local allEquipSkillList = {}
--    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
--    if curHeroData then
--        for i = 1, #curHeroData.equipIdList do
--            local curEquip = EquipManager.GetSingleEquipData(curHeroData.equipIdList[i])
--            if curEquip then
--                if curEquip.skillId and curEquip.skillId > 0 then
--                    table.insert(allEquipSkillList, curEquip.skillId)
--                end
--            end
--        end
--    end
--    return allEquipSkillList
--end
--获取单个英雄法宝被动技能list
function this.GetTalismanSkillData(_heroId)
    local allTalismanSkillList = {}
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        
        for i = 1, #curHeroData.talismanList do
            local curTalisman = TalismanManager.GetSingleTalismanData(curHeroData.talismanList[i])
            if curTalisman then
                local talismanConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId", curTalisman.backData.equipId,"Level",curTalisman.star)
                if talismanConFig then
                    for j = 1, #talismanConFig.OpenSkillRules do
                        table.insert(allTalismanSkillList, talismanConFig.OpenSkillRules[j])
                    end
                end
            end
        end
    end
    return allTalismanSkillList
end

-- 获取技能表现
local _CombatList = {}
function this.GetSkillCombat(id)
    if not _CombatList[id] then
        local combat = CombatControl[id]
        if not combat then return end
        _CombatList[id] = {
            Id = combat.Id,
            SkillType = combat.SkillType,
            VerticalDrawing = combat.VerticalDrawing,
            KeyFrame = combat.KeyFrame,
            Eterm = combat.Eterm,
            ShockScreen = combat.ShockScreen,
            Bullet = combat.Bullet,
            BulletTime = combat.BulletTime,
            Hit = combat.Hit,
            Offset = combat.Offset,
            skillname = combat.skillname,
            BeforeBullet = combat.BeforeBullet,	
            SkillNumber = combat.SkillNumber,	
            SkillDuration = combat.SkillDuration,	
            BeforeOrientation = combat.BeforeOrientation,
            Orientation = combat.Orientation,
            HitOrientation = combat.HitOrientation,
            BeforeEffectType = combat.BeforeEffectType ,
            EffectType = combat.EffectType ,
            HitEffectType = combat.HitEffectType,
            BeforeOffset = combat.BeforeOffset,
            HitOffset = combat.HitOffset,
            SkillNameVoice = combat.SkillNameVoice,
            Move = combat.Move,
            CastBullet = combat.CastBullet,
            ReturnTime = combat.ReturnTime,
            DirectivityEff = combat.DirectivityEff,
            SkillSoundDelay = combat.SkillSoundDelay,
            SkillSound = combat.SkillSound,
            HitSound = combat.HitSound,
            FireSound = combat.FireSound,
            fire_smoke = combat.fire_smoke,
            Closeup = combat.Closeup,
            CloseupSound = combat.CloseupSound,
            IsCannon = combat.IsCannon,
            CloseupDuration = combat.CloseupDuration,
            isRecoil = combat.isRecoil,
            MissEff = combat.MissEff,
            HitArea = combat.HitArea,
            Animation = combat.Animation,
            BeforeHideActor = combat.BeforeHideActor,
            HideActor = combat.HideActor,
            PV = combat.PV,
            PVDuration = combat.PVDuration,
            isDiaup = combat.isDiaup,
            FriendHitEffect = combat.FriendHitEffect,
        }
    end
    return _CombatList[id]
end

function this.SetSkillCombat(id, combat)
    _CombatList[id] = combat
end

-----  战斗控制相关 ------------------
-- 是否解锁二倍速
function this.IsUnlockBattleSpeed()
    return PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.DoubleTimesFight)
end
function this.IsUnlockBattleSpeedThree()
    return PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ThreeTimesFight)
end
-- 是否解锁跳过功能
function this.IsUnlockBattlePass()
    -- return false
    return PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.SkipFight)
end
--> 是否解锁战斗切后台
function this.IsUnlockBattleInBack()
    return PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.BattleInBack)
end

-- --> 是否解锁替补
-- function this.IsUnlockBattleInBack()
--     return PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.BattleInBack)
-- end

-- 战斗暂停控制
this.IsPlay = 0
function this.StartBattle()
    if this.IsPlay == 0 then
        this.IsPlay = 1
    end
end
function this.IsBattlePlaying()
    return this.IsPlay == 1
end
function this.PauseBattle()
    if this.IsPlay == 1 then
        this.IsPlay = 2        
    end
end
function this.ResumeBattle()
    if this.IsPlay == 2 then
        this.IsPlay = 1
    end
end
function this.StopBattle()
    this.IsPlay = 0
end
function this.IsCanOperate()
    return this.IsPlay ~= 0
end

--> battlePanelBehind
this.BattleIsStart = false
this.BattleIsEnd = false

function BattleManager.IsInBackBattle()
    return BattleManager.BattleIsStart and not BattleManager.BattleIsEnd
end

function BattleManager.GotoFight(func)
    if this.IsInBackBattle() then
        PopupTipPanel.ShowTip(GetLanguageStrById(50014))
        return
    else
        if func then
            func()
        end
    end
end

-- 战斗加速控制
BATTLE_TIME_SCALE_ZERO = 0
BATTLE_TIME_SCALE_ONE = 1.2
BATTLE_TIME_SCALE_TWO =  2.1
BATTLE_TIME_SCALE_Three = 3
this.TimeScale = 0
function this.InitTimeScale()
    this.TimeScale = 0
    local _TimeScale = PlayerPrefs.GetFloat(PlayerManager.uid.."battleTimeScaleKey")--, BATTLE_TIME_SCALE_ONE)
    if _TimeScale <= 0 then
        _TimeScale = BATTLE_TIME_SCALE_ONE
    end
    this.SetTimeScale(_TimeScale)
end
function this.GetTimeScale()
    return this.TimeScale
end
function this.SetTimeScale(TimeScale)
    if TimeScale < 0 or not this.IsUnlockBattleSpeed() then--or this.IsFirstBattle()then
        TimeScale = BATTLE_TIME_SCALE_ONE
    end
    if TimeScale > BATTLE_TIME_SCALE_Three then
        TimeScale = BATTLE_TIME_SCALE_Three
    end

    if this.TimeScale ~= TimeScale then
        this.TimeScale = TimeScale
        PlayerPrefs.SetFloat(PlayerManager.uid.."battleTimeScaleKey", this.TimeScale)
        -- 刷新前端显示
        Game.GlobalEvent:DispatchEvent(GameEvent.Battle.OnTimeScaleChanged)
        -- 真正生效的敌方 
        Time.timeScale = TimeScale
        -- 设置音效播放的速度
        SoundManager.SetAudioSpeed(TimeScale)
    end
end

-- 获取战斗界面层级
function this.GetBattleSorting()
    if UIManager.IsOpen(UIName.BattlePanel) then
        return BattlePanel.sortingOrder
    end

    if UIManager.IsOpen(UIName.GuideBattlePanel) then
        return GuideBattlePanel.sortingOrder
    end
    
    if not BattleManager.BattleIsEnd then
        return BattlePanel.sortingOrder
    end
end

-- -- 获取战斗背景
-- local bgConfig = {
--     [1] = "Map2",
--     [2] = "Map2",
--     [3] = "Map2",
--     [1001] = "Map2",
--     [1002] = "Map2",
-- }
this.battleType = 0
function this.GetBattleBg(fightType)
    this.battleType = fightType
    if fightType == BATTLE_TYPE.STORY_FIGHT then
        return G_MainLevelConfig[FightPointPassManager.curOpenFight].BG
    elseif fightType == BATTLE_TYPE.EXECUTE_FIGHT then
        return "Map2"
    elseif fightType == BATTLE_TYPE.BACK then
        return "Map6"
    elseif fightType == BATTLE_TYPE.LADDERS
        or fightType == BATTLE_TYPE.CONTEND_HEGEMONY
        or fightType == BATTLE_TYPE.Climb_Tower
        or fightType == BATTLE_TYPE.Ladders_Challenge
        or fightType == BATTLE_TYPE.DAILY_CHALLENGE then
        return "Map4"
    elseif fightType == BATTLE_TYPE.DefenseTraining then
        return "Map5"
    elseif fightType == BATTLE_TYPE.BLITZ_STRIKE
        or fightType == BATTLE_TYPE.Test
        or fightType == BATTLE_TYPE.GUILD_CAR_DELAY then
        return "Map1"
    elseif fightType == BATTLE_TYPE.Climb_Tower_Advance then
        return "Map4"
    else
        return "Map2"
    end
end

-- 引导战斗暂停控制
this.isGuidePause = false
function this.IsGuidePause()
    return this.isGuidePause
end
function this.SetGuidePause(isPause)
    this.isGuidePause = isPause
end

-- 声音事件
function FireSound()
    if GVM.soundsIdx == 0 then
        return
    end
    SoundManager.PlaySound(GVM.sounds[GVM.soundsIdx])

    GVM.soundsIdx = GVM.soundsIdx + 1
end

-- 设置战斗显示数据
this.elements = {}
function this.SetFightElement(camp, _elements)
    this.elements[camp] = {}

    for i = 1, #_elements do
        table.insert(this.elements[camp], _elements[i])
    end
end

-- 设置战斗对阵信息
-- struct = {
--     head = 0,
--     headFrame = 0,
--     name = 0,
--     formationId = 0
-- }
BattleManager.structA = {}
BattleManager.structB = {}
function BattleManager.SetAgainstInfoData(fightType, _structA, _structB)
    this.structA = {}
    this.structB = {}
    if _structA then
        this.structA.head             = _structA.head
        this.structA.headFrame        = _structA.headFrame
        this.structA.name             = _structA.name
        this.structA.formationId      = _structA.formationId
        this.structA.investigateLevel = _structA.investigateLevel
    else
        this.structA.head             = PlayerManager.head
        this.structA.headFrame        = PlayerManager.frame
        this.structA.name             = PlayerManager.nickName
        this.structA.formationId      = FormationManager.GetFormationId()
        this.structA.investigateLevel = FormationCenterManager.GetInvestigateLevel()
    end
    if _structB then
        this.structB.head             = _structB.head
        this.structB.headFrame        = _structB.headFrame
        this.structB.name             = _structB.name
        this.structB.formationId      = _structB.formationId
        this.structB.investigateLevel = _structB.investigateLevel
    end
end

-- AI 公共对阵信息  需在编队后
function BattleManager.SetAgainstInfoAICommon(fightType, _monsterGroupId, levelName)
    local monsterShowId = GetMonsterGroupFirstEnemy(_monsterGroupId)
    local heroid = G_MonsterConfig[monsterShowId].MonsterId
    local image = GetResourcePath(G_HeroConfig[heroid].Icon)
    local structA = nil
    local structB = {
        head = tostring(image),
        headFrame = nil,
        name = levelName or GetLanguageStrById(G_MonsterGroup[_monsterGroupId].Name),
        formationId = G_MonsterGroup[_monsterGroupId].Formation,
        investigateLevel = G_MonsterGroup[_monsterGroupId].Investigate
    }
    BattleManager.SetAgainstInfoData(fightType, structA, structB)
end

--> 记录类型对战信息
function BattleManager.SetAgainstInfoRecordCommon(_TeamOneInfoA, _TeamOneInfoB)
    this.structA = {}
    this.structB = {}
    if _TeamOneInfoA then
        this.structA.head             = _TeamOneInfoA.head
        this.structA.headFrame        = _TeamOneInfoA.headFrame
        this.structA.name             = _TeamOneInfoA.name
        this.structA.formationId      = _TeamOneInfoA.formationId
        this.structA.investigateLevel = _TeamOneInfoA.investigateLevel
    else
        this.structA.head             = PlayerManager.head
        this.structA.headFrame        = PlayerManager.frame
        this.structA.name             = PlayerManager.nickName
        this.structA.formationId      = FormationManager.GetFormationId()
        this.structA.investigateLevel = FormationCenterManager.GetInvestigateLevel()
    end
    if _TeamOneInfoB then
        this.structB.head             = _TeamOneInfoB.head
        this.structB.headFrame        = _TeamOneInfoB.headFrame
        this.structB.name             = _TeamOneInfoB.name
        this.structB.formationId      = _TeamOneInfoB.formationId
        this.structB.investigateLevel = _TeamOneInfoB.investigateLevel
    end
end

function BattleManager.ResetCVDatas()
    BattleManager.CV_equipDatas = {}
    BattleManager.CV_equipDatas[0] = {}
    BattleManager.CV_equipDatas[1] = {}
end

---创建战场
---@param parent any 父节点
---@return table
---@return table
function BattleManager.CreateBattleScene(parent)
    --创建战场逻辑Prefab
    local battleSceneLogicPrefab = resMgr:LoadAsset("BattleSceneLogic")
    if battleSceneLogicPrefab == nil then
        LogError("资源创建失败！！ 没有找到对应的资源！！ Prefab:BattleScene")
        return
    end
    local battleSceneLogicGameObject = GameObject.Instantiate(battleSceneLogicPrefab, parent)
    battleSceneLogicGameObject.name = battleSceneLogicPrefab.name
    local battleSceneLogicTransform = battleSceneLogicGameObject.transform
    battleSceneLogicTransform.localScale = Vector3.one

    --场景战场场景Prefab
    local battleScenePrefab = resMgr:LoadAsset("BattleScene")
    if battleScenePrefab == nil then
        LogError("资源创建失败！！ 没有找到对应的资源！！ Prefab:BattleScene")
        return
    end
    local battleSceneGameObject = GameObject.Instantiate(battleScenePrefab, parent)
    battleSceneGameObject.name = battleScenePrefab.name
    local battleSceneTransform = battleSceneGameObject.transform
    battleSceneTransform.localScale = Vector3.one


    if Screen.height / Screen.width < 16/9 then
        local w = Screen.height/1920 * 1080
        Camera.main.sensorSize = Vector2.New(40 * (Screen.width/w),40)
    end

    return battleSceneLogicGameObject, battleSceneGameObject
end

---创建地图
---@param battleScene any
---@param mapName any
---@return table
function BattleManager.CreateMap(battleScene, mapName)
    local floor = Util.GetGameObject(battleScene, "Floor").transform
    local mapPrefab = resMgr:LoadAsset(mapName)
    local mapGameObject
    if mapPrefab ~= nil then
        mapGameObject = GameObject.Instantiate(mapPrefab, floor)
        mapGameObject.transform.localScale = Vector3.one
    end

    return mapGameObject
end

function this.Execute(args, fightData)
   local _seed = args.seed
   local _type = args.type
   local _maxRound = args.maxRound
   local _fightData = fightData

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
        -- 执行帧记录
        BattleRecordManager.InitFrameRecord()

        Random.SetSeed(args.seed)
        BattleLogManager.WriteServerFightData(fightData, time, "BEGINP")
        BattleLogic.Init(fightData, optionData, _maxRound)
        BattleLogic.Type = _type

        ---- 加入监听帧同步
        local function xfram()
            local curframe = 0
            curframe = BattleLogic.CurFrame()
            if curframe == nil then curframe = -1 end
            BattleRecordManager.recordFrame(curframe)
        end 

        local function xRound()
            local _round = 0
            _round = BattleLogic.GetCurRound()
            if _round == nil then _round = -1 end
            BattleRecordManager.recordRoundBytype(_round,RecordType.RoleManager)
        end

        
        local function xMove()
            local _move = 0
            _move = BattleLogic.GetMoveTimes()
            if _move == nil then _move = -1 end
            BattleRecordManager.recordRoundBytype(_move,RecordType.RoleManager)
        end

        local function XRecordResult(result)
            BattleRecordManager.recordResult(result)
        end

        ----加入监听帧检测计入状态值
        -- BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, xRound)
        BattleLogic.Event:AddEvent(BattleEventName.CheckFrame, xMove)
        BattleLogic.Event:AddEvent(BattleEventName.BattleEnd, XRecordResult)
        -- BattleLogic.Event:AddEvent(BattleEventName.BattleOrderChange, xfram)
        
        BattleLogic.StartOrder()
        while not BattleLogic.IsEnd do
            BattleLogic.Update()
            -- xfram()
        end
        ---- 移除监听帧检测
        -- BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, xRound)
        BattleLogic.Event:RemoveEvent(BattleEventName.CheckFrame, xMove)        
        BattleLogic.Event:RemoveEvent(BattleEventName.BattleEnd, XRecordResult)
        -- BattleLogic.Event:RemoveEvent(BattleEventName.BattleOrderChange, xfram)

        BattleLogManager.WriteServerFightDataB(time, "ENDP")
    end, function (err)
        isError = true
        errorCache[1] = "error:\n"..err.."\n"
    end) then
        -- BattleLogic.useTimes = 10
        BattleLogManager.WriteServerFightDataB(time, "NormalBEGINP")
        local resultList = {0, 0, 0, 0, 0, 0, 0, 0, 0}
        local enemyList = {0, 0, 0, 0, 0, 0, 0, 0, 0}     
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


        resultList.useTimes = BattleLogic.useTimes
        resultList.fightRound = curRound
        BattleLogManager.WriteServerFightDataB(time, "NormalENDP")

        return resultList
    end
    if isError then --捕获异常，并输出错误日志
        local isLog = AppConst.isOpenBLog
        if not isLog then return end

        BattleLogManager.WriteServerFightDataB(time, "ErrorBEGINP")

        BattleLogManager.WriteServerFightData(errorCache,time, "ErrorLog")

        BattleLogManager.WriteServerFightDataB(time, "ErrorENDP")
    end
    LogRed("return -1")
    --注销事件
    -- BattleLogic.Clear()
    return { result = -1 }

end

---获取服务端传过来的战斗数据和随机数种子
---参数2 isFightPlayer 0和怪物对战 1和玩家对战
---> fightId 关卡id 随机加入副系统战斗单位(支援 副官)
------> PVE 战斗测试工具 需策划提前填写好相应的表格 MonsterGroup即可 敌方暂不支持配置替补
function this.GetTestBattleServerData(msg, isFightPlayer, monsterGroupId,round)
    BattleManager.ResetCVDatas()
    local fightData = {
        playerData = { teamSkill = {}, teamPassive = {}, firstCamp = 0},
        tibuData = {},
        enemyData = { },
        fightUnitData = {},
        fightUnitDataAppend = {},
        tankDataAppend = {},
        noUnitDataAppend = {}
    }
    isFightPlayer = isFightPlayer == 1
    
    local data = msg.fightData.heroFightInfos
    
    local elementIds = {}
    local setPlayerItemData = function(fightUnit,istibu)
        local rid = tonumber(fightUnit.unitId)
        local position = tonumber(fightUnit.position)
        local star = tonumber(fightUnit.star)
        local skills = string.split(fightUnit.unitSkillIds, "#")
        local propertys = string.split(fightUnit.property, "#")

        local role = {           
            roleId = rid,
            position = position,
            star = star,
            camp = 0,
            type = 1,
            quality = 0,
            element = HeroConfig[rid].PropertyName,
            professionId = HeroConfig[rid].Profession,
            size = 1,
            passivity = { },
            property = { },
            isTibu = istibu,
        }
        if not istibu then
            table.insert(elementIds, role.element)
        end
        --> 
        role.skillArray = {}
        local passivityList = {}
        local idx = 1
        for i = 1, #skills do
            if skills[i] and skills[i] ~= 0 then
                --> 0 1 3 主动技
                --if i - 1 == SkillSlotPos.Slot_0 or i - 1 == SkillSlotPos.Slot_1 or i - 1 == SkillSlotPos.Slot_3 then
                if i <= 3 then
                    role.skillArray[idx] = this.GetSkillData(tonumber(skills[i]))
                    idx = idx + 1
                    -- table.insert(role.skillArray, this.GetSkillData(tonumber(skills[i])))
                else
                    local passivityId = tonumber(skills[i])
                    for j = 1,#passivityList do 
                        if PassiveSkillLogicConfig[passivityList[j]].Group == PassiveSkillLogicConfig[passivityId].Group then
                            if PassiveSkillLogicConfig[passivityList[j]].Level < PassiveSkillLogicConfig[passivityId].Level then
                                table.remove(passivityList,j)
                            else
                                passivityId = nil
                            end
                            break
                        end
                    end
                    if passivityId ~= nil then
                        table.insert(passivityList, passivityId)
                    end
                end
            end
        end

        --做个普攻技能检查
        if role.skillArray[1] == nil then
            LogError("配表错误!!!进攻方普攻未找到 roleId:" .. role.roleId .. " 普攻技能id:" .. tonumber(skills[1]))
        end
        
        role.passivity = this.GetPassivityData(passivityList)
        role.passivityIds = passivityList

        for j = 1, #propertys do
            role.property[j] = tonumber(propertys[j])
        end
        return role
    end

    for i = 1, #data.fightUnitList do
        fightData.playerData[i] = setPlayerItemData(data.fightUnitList[i],false)
    end

    -- 替补数据条件 to do yh check
    if data.substitute.unitId~="" then
        fightData.tibuData[1] = setPlayerItemData(data.substitute,true)
    end

    this.SetFightElement(0, elementIds)

    -- 一些战斗外数据
    fightData.playerData.outData = data.specialPassive
    
    --> 支援
    if data.useSupportId and data.useSupportId ~= 0 and data.useSupportId ~= "" then
        this.AddUnitDataByType(data.useSupportId, fightData.fightUnitData, data.supportSkillLevel, FightUnitType.UnitSupport, 0)
    end
    --> 副官
    if data.useAdjutantId and data.useAdjutantId ~= 0 and data.useAdjutantId ~= "" then
        this.AddUnitDataByType(data.useAdjutantId, fightData.fightUnitData, data.adjutantSkillLevel, FightUnitType.UnitAdjutant, 0)
    end
    --> 航母
    if data.motherShipInfo and #data.motherShipInfo.plan > 0 then
        --> 0 1 主装备数据 2 3 ext数据
        this.CV_equipDatas[0] = {}
        this.CV_equipDatas[2] = {}

        local cvMineTb = {}
        for i = 1, #data.motherShipInfo.plan do
            local equipPlane = AircraftCarrierManager.CreateEmptyTable()
            AircraftCarrierManager.CopyValue(equipPlane, data.motherShipInfo.plan[i])
            table.insert(this.CV_equipDatas[0], equipPlane)
        end
        this.CV_equipDatas[2].CVLv = data.motherShipInfo.id
        table.sort(this.CV_equipDatas[0], function(a, b)
            return a.sort < b.sort
        end)
        cvMineTb.skill = {}
        for i = 1, #this.CV_equipDatas[0] do
            local planeConfig = G_MotherShipPlaneConfig[this.CV_equipDatas[0][i].cfgId]
            table.insert(cvMineTb.skill, this.GetSkillData(planeConfig.Skill))
            cvMineTb.skill[i][8].release = this.CV_equipDatas[0][i].sort    --< 修改触发顺序为槽位顺序

            --> 设置显示用到数据 需排序完数据
            this.CV_equipDatas[0][i].release = this.CV_equipDatas[0][i].sort
            this.CV_equipDatas[0][i].cd = cvMineTb.skill[i][8].cd
        end

        local proArr = string.split(data.motherShipInfo.property, "#")
        cvMineTb.property = {}
        for j = 1, #proArr do
            cvMineTb.property[j] = tonumber(proArr[j])
        end

        cvMineTb.rootId = data.motherShipInfo.id   --< 各系统主表id
        cvMineTb.camp = 0
        cvMineTb.type = FightUnitType.UnitAircraftCarrier
        table.insert(fightData.fightUnitData, cvMineTb)
    end

     --> mine
     local monsterConfig = MonsterGroup[monsterGroupId]
     local pos = G_FormationConfig[monsterConfig.Formation].pos
     local Contents = monsterConfig.Contents
     for i = 1, #Contents do
         local enemyList = {}
         local elementIds = {}
         local idx = 1
         for j = 1, #Contents[i] do
             if Contents[i][j] ~= 0 then
                 enemyList[j] = this.GetMonsterFightData(Contents[i][j], 1)
                 enemyList[j].position = pos[idx]
                 table.insert(elementIds, enemyList[j].element)
             end
             idx = idx + 1
         end
         fightData.enemyData[i] = enemyList
         this.SetFightElement(1, elementIds)
         break   --< 取一组
     end

    local data = {
        fightData = fightData,
        fightSeed = msg.fightData.fightSeed,
        fightType = msg.fightData.fightType,
        maxRound = round,
    }
  

    return data
end

return this