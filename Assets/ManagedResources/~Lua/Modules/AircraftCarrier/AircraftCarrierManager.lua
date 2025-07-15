AircraftCarrierManager = {}
local this = AircraftCarrierManager
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local MotherShipResearch = ConfigManager.GetConfig(ConfigName.MotherShipResearch)--基因研究速度配置表
local MotherShipPlaneBlueprint = ConfigManager.GetConfig(ConfigName.MotherShipPlaneBlueprint)--基因研究配置表
local MotherShipConfig = ConfigManager.GetConfig(ConfigName.MotherShipConfig)--神眷者基础数据表
local MotherShipPlaneConfig = ConfigManager.GetConfig(ConfigName.MotherShipPlaneConfig)--基因（主角技能）配置表
local MotherShipResearchPlus = ConfigManager.GetConfig(ConfigName.MotherShipResearchPlus)--基因研究加速配置表
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local HeroRankupGroup = ConfigManager.GetConfig(ConfigName.HeroRankupGroup)

function this.Initialize()
    this.LeadData = nil
end

function AircraftCarrierManager.GetLeadData(func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
        if func then
            func()
        end
        return
    end

    NetManager.MotherShipInfoRequest(function(msg)
    --[[
        msg.motherShipInfo = {
            motherShipLevel = 主角等级
            motherShipResearchLevel = 研究等级
            myPlan = 主角装备的技能
            
            //普通
            normalResearchDegree = 进度
            normalResearchTime = 开始时间
            normalAddResearchDegree = 增加
            curNormalBluePrintId = 当前道具ID

            //特权
            researchDegree = 进度
            researchTime = 开始时间
            addResearchDegree = 增加
            curBluePrintId = 当前道具ID
        }
    ]]
        this.LeadData = {
            lv = msg.motherShipInfo.motherShipLevel,
            researchLv = msg.motherShipInfo.motherShipResearchLevel,
            skill = {},
            normal = {
                progress = msg.motherShipInfo.normalResearchDegree,
                curTime = msg.motherShipInfo.normalResearchTime,
                addProgress = msg.motherShipInfo.normalAddResearchDegree,
                curItemId = msg.motherShipInfo.curNormalBluePrintId
            },
            privilege = {
                progress = msg.motherShipInfo.researchDegree,
                curTime = msg.motherShipInfo.researchTime,
                addProgress = msg.motherShipInfo.addResearchDegree,
                curItemId = msg.motherShipInfo.curBluePrintId
            }
        }

        for i = 1, #msg.motherShipInfo.myPlan do
            local skill = {}
            skill.id = msg.motherShipInfo.myPlan[i].id --技能ID
            skill.cfgId = msg.motherShipInfo.myPlan[i].cfgId -- 战机表ID
            skill.sort = msg.motherShipInfo.myPlan[i].sort --穿戴顺序
            this.LeadData.skill[i] = skill
        end

        this.allGeneData = {}
        for i = 1, 5 do
            local config = ConfigManager.GetAllConfigsDataByKey(ConfigName.MotherShipPlaneConfig, "Lvl", i)
            for j = 1, #config do
                if not this.allGeneData[j] then
                    this.allGeneData[j] = {}
                end
                table.insert(this.allGeneData[j], config[j].Id)
            end
        end

        if func then
            func()
        end
    end)
end

--主角升级
function AircraftCarrierManager.LeadUpLv(func)
    local lv, maxLv = AircraftCarrierManager.GetLeadLvAndMaxLv()
    if lv >= maxLv then
        PopupTipPanel.ShowTipByLanguageId(11993)
        return
    end
    for i = 1, 2 do
        local itemId = MotherShipConfig[this.LeadData.lv].Cost[i][1]
        local bagNum = BagManager.GetItemCountById(itemId)
        if bagNum < MotherShipConfig[this.LeadData.lv].Cost[i][2] then
            PopupTipPanel.ShowTipByLanguageId(10073)
            return
        end
    end
    NetManager.MotherShipUplevelRequest(function()
        this.LeadData.lv = this.LeadData.lv + 1
        if func then
            func()
        end
    end)
end

--开始研发
function AircraftCarrierManager.StartResearch(pos, type, func)
    if not pos then
        return
    end
    local config = MotherShipPlaneBlueprint[pos]
    local itemNum = BagManager.GetItemCountById(config.ItemId)
    if itemNum < 1 then
        -- PopupTipPanel.ShowTipByLanguageId(10060)
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,config.ItemId)
        return
    end
    NetManager.MotherShipResearchStartbuildRequest(pos, type, function()
        AircraftCarrierManager.GetLeadData(function()
            AircraftCarrierManager.InitTimer()
            if func then
                func()
            end
            CheckRedPointStatus(RedPointType.Lead_Normal)
            CheckRedPointStatus(RedPointType.Lead_Privilege)
        end)
    end)
end

--研发加速 0：普通 1：特权
function AircraftCarrierManager.ResearchSpeedUp(pos, type, autoBuy, func)
    if not pos then
        return
    end
    local data, max = AircraftCarrierManager.GetResearch(type)
    local speed = MotherShipResearch[this.LeadData.researchLv].Speed
    local time = data.progress + data.addProgress + speed * math.floor((GetTimeStamp() * 1000 - data.curTime) / 1000)
    if time > max then
        AircraftCarrierManager.ResearchOver(type)
        return
    end
    local cost = MotherShipResearchPlus[pos]
    local state = false
    if BagManager.GetItemCountById(cost.CostItem[1]) < cost.CostItem[2] then
        -- PopupTipPanel.ShowTipByLanguageId(10492)
        state = false
    else
        state = true
    end
    if BagManager.GetItemCountById(cost.CostDiamond[1]) < cost.CostDiamond[2] and not state then
        PopupTipPanel.ShowTipByLanguageId(10854)
        return
    end
    NetManager.MotherShipResearchSpeedupRequest(pos, type, autoBuy and 1 or 0, function()
        AircraftCarrierManager.GetLeadData(function()
            if func then
                func()
            end
        end)
    end)
end

-- 获取主角当前等级、最大等级、阶段
function AircraftCarrierManager.GetLeadLvAndMaxLv()
    local maxlv = MotherShipConfig[#ConfigManager.GetAllConfigsData(ConfigName.MotherShipConfig)].Level
    local config = ConfigManager.GetConfigDataByKey(ConfigName.MotherShipConfig, "Level", this.LeadData.lv)
    return this.LeadData.lv,
        maxlv,
        config.Step,
        config.Type
end


-- 获取当前研究等级、下一研究等级、研究速度、下一级研究速度
function AircraftCarrierManager.GetMaxRresearchLv()
    local lv = this.LeadData.researchLv
    local maxLv = #ConfigManager.GetAllConfigsData(ConfigName.MotherShipResearch)
    local speed = MotherShipResearch[lv].Speed
    local speedNext = speed
    local nextLv
    if lv < maxLv then
        speedNext = MotherShipResearch[lv+1].Speed
        nextLv = lv+1
    else
        lv = "Max"
        nextLv = "Max"
    end
    return lv, nextLv, speed, speedNext
end

-- 研发速度升级
function AircraftCarrierManager.RresearchLvUp(heroList, func)
    NetManager.MotherShipResearchUplevelRequest(heroList, function()
        AircraftCarrierManager.GetLeadData(function()
            HeroManager.DeleteHeroDatas(heroList)
            Game.GlobalEvent:DispatchEvent(GameEvent.Lead.ResearchLvUp)
            if func then
                func()
            end
        end)
    end)
end

--获取研发速度升级数据
function AircraftCarrierManager.GetRresearchLvUpData()
    local config = MotherShipResearch[this.LeadData.researchLv]
    local rankUpGroupData = HeroRankupGroup[config.Cost[1]]
    return config, rankUpGroupData
end

local lvImg = {
    "cn2-X1_zhandou_zhanjian_xingji_01",
    "cn2-X1_zhandou_zhanjian_xingji_02",
    "cn2-X1_zhandou_zhanjian_xingji_03",
    "cn2-X1_zhandou_zhanjian_xingji_04",
    "cn2-X1_zhandou_zhanjian_xingji_05",
    "cn2-X1_zhandou_zhanjian_xingji_06",
}

-- 通过技能ID获取技能数据
function AircraftCarrierManager.GetSkillLvImgForId(id)
    local data = {
        lv = MotherShipPlaneConfig[id].Lvl,
        lvImg = lvImg[MotherShipPlaneConfig[id].Lvl],
        skillLv = MotherShipPlaneConfig[MotherShipPlaneConfig[id].Lvl],
        config = MotherShipPlaneConfig[id]
    }
    return data
end

-- 获取研究数据
function AircraftCarrierManager.GetResearch(type)
    if not this.LeadData then
        return
    end
    if type == 0 then
        local ResearchDegree
        if this.LeadData.normal.curItemId ~= 0 then
            ResearchDegree = MotherShipPlaneBlueprint[this.LeadData.normal.curItemId].ResearchDegree
        end
        return this.LeadData.normal, ResearchDegree
    elseif type == 1 then
        local ResearchDegree
        if this.LeadData.privilege.curItemId ~= 0 then
            ResearchDegree = MotherShipPlaneBlueprint[this.LeadData.privilege.curItemId].ResearchDegree
        end
        return this.LeadData.privilege, ResearchDegree
    end
end

-- 研究倒计时
function AircraftCarrierManager.InitTimer()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
        return
    end
    if not this.LeadData then
        return
    end
    if this.LeadData.normal.curItemId ~= 0 then
        if this.normalTimer == nil then
            this.normalTimer = Timer.New(function()
                if this.LeadData then
                    AircraftCarrierManager.UpdateProgress(this.LeadData.normal, 0)
                end
            end, 1, -1, true)
            this.normalTimer:Start()
            if this.LeadData then
                AircraftCarrierManager.UpdateProgress(this.LeadData.normal, 0)
            end
        end
    end
    if this.LeadData.privilege.curItemId ~= 0 then
        if this.privilegeTimer == nil then
            this.privilegeTimer = Timer.New(function()
                if this.LeadData then
                    AircraftCarrierManager.UpdateProgress(this.LeadData.privilege, 1)
                end
            end, 1, -1, true)
            this.privilegeTimer:Start()
            if this.LeadData then
                AircraftCarrierManager.UpdateProgress(this.LeadData.privilege, 1)
            end
        end
    end
end

-- 获取当前研究进度、剩余时间
function AircraftCarrierManager.GetCurProgress(type)
    local data, max = AircraftCarrierManager.GetResearch(type)
    local speed = MotherShipResearch[this.LeadData.researchLv].Speed
    local progress = data.progress + data.addProgress + speed * math.floor((GetTimeStamp() * 1000 - data.curTime) / 1000)
    local totalDegree
    if data.curItemId > 0 then
        totalDegree = MotherShipPlaneBlueprint[data.curItemId].ResearchDegree
    else
        totalDegree = 0
    end
    local surplusTime = (totalDegree - progress)/speed
    if not max then max = 0 surplusTime = 0 end
    if progress > max then progress = max surplusTime = 0 end
    if progress < 0 then progress = 0 surplusTime = 0 end
    return progress, surplusTime
end

-- 更新研究进度
function AircraftCarrierManager.UpdateProgress(data, type)
    if data.curItemId == 0 then
        return
    end
    local speed = MotherShipResearch[this.LeadData.researchLv].Speed
    local totalDegree = MotherShipPlaneBlueprint[data.curItemId].ResearchDegree
    local progress = data.progress + data.addProgress + speed * math.floor((GetTimeStamp() * 1000 - data.curTime) / 1000)
    local surplusTime = (totalDegree - progress)/speed
    if progress >= totalDegree then
        progress = totalDegree
        surplusTime = 0
        AircraftCarrierManager.ResearchOver(type)
    end
    if type == 0 then
        Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshNormalProgress, progress, surplusTime)
    else
        Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshPrivilegeProgress, progress, surplusTime)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshProgress, type, progress, surplusTime)
end

-- 结束研究
function AircraftCarrierManager.ResearchOver(type)
    if type == 0 then
        if this.normalTimer then
            this.normalTimer:Stop()
            this.normalTimer = nil
        end
    else
        if this.privilegeTimer then
            this.privilegeTimer:Stop()
            this.privilegeTimer = nil
        end
    end
    NetManager.MotherShipResearchEndbuildRequest(type, function(msg)
        AircraftCarrierManager.GetLeadData(function()
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
            Game.GlobalEvent:DispatchEvent(GameEvent.Lead.ResearchOver, type)
            CheckRedPointStatus(RedPointType.Lead_Normal)
            CheckRedPointStatus(RedPointType.Lead_Privilege)
            CheckRedPointStatus(RedPointType.Lead_Assembly)
        end)
    end)
end

-- 获取所有技能
function AircraftCarrierManager.GetAllPlaneReq(func)
    NetManager.MotherShipPlanGetAllRequest(function(msg)
        this.allSkillData = {}
        for i = 1, #msg.plan do
            AircraftCarrierManager.UpdateSkillData(msg.plan[i])
        end

        if func then
            func()
        end
    end)
end

function AircraftCarrierManager.UpdateSkillData(sPlane)
    if sPlane == nil then
        LogError("### UpdateSinglePlaneData Error!!!")
        return
    end
    if this.allSkillData[sPlane.id] == nil then
        this.allSkillData[sPlane.id] = this.CreatSkill()
    end
    this.CopyValue(this.allSkillData[sPlane.id], sPlane)
end

function AircraftCarrierManager.CreatSkill()
    local skill = {}
    skill.id = nil
    skill.cfgId = nil
    skill.sort = nil
    return skill
end

function AircraftCarrierManager.CopyValue(skill, data)
    skill.id = data.id
    skill.cfgId = data.cfgId
    skill.sort = data.sort
end

function AircraftCarrierManager.DelSkill(skillId)
    if this.allSkillData[skillId] == nil then
        LogError("### DelPlaneData id64 not find or already del")
        return
    end
    this.allSkillData[skillId] = nil
end

-- 获取同类技能数量(不包含自己和已装备)
function AircraftCarrierManager.GetSkillSimilarCount(cfgId, id)
    local cnt = 0
    for k, v in pairs(this.allSkillData) do
        if v.cfgId == cfgId and v.id ~= id then
            local isAdd = true
            for i = 1, #this.LeadData.skill do
                if this.LeadData.skill[i].id == v.id then
                    isAdd = false
                    break
                end
            end
            if isAdd then
                cnt = cnt + 1
            end
        end
    end
    return cnt
end

-- 获取研发道具数据
function AircraftCarrierManager.GetPlaneAtlasDataByStar(star)
    local ret = ConfigManager.GetAllConfigsDataByKey(ConfigName.MotherShipPlaneConfig, "Lvl", star)
    table.sort(ret, function(a, b)
        return a.Type < b.Type
    end)
    return ret
end

-- 根据id获取当前主角阶级最大等级
function AircraftCarrierManager.GetMaxLvInCurBreak(id)
    local datas = ConfigManager.GetAllConfigsDataByKey(ConfigName.MotherShipConfig, "Step", MotherShipConfig[id].Step)
    table.sort(datas, function(a, b)
        return a.Id < b.Id
    end)
    return datas[#datas].Level
end

--获取升级消耗
function AircraftCarrierManager.GetCost()
    return MotherShipConfig[this.LeadData.lv].Cost
end

-- 获取主角属性
function AircraftCarrierManager.GetAllPro()
    local ret = {}
    local config = MotherShipConfig[this.LeadData.lv]

    local function setPro(tb, pros)
        for i = 1, #pros do
            if tb[pros[i][1]] == nil then
                tb[pros[i][1]] = 0
            end
            tb[pros[i][1]] = tb[pros[i][1]] + pros[i][2]
        end
    end
    setPro(ret, config.Attr)

    for i = 1, #this.LeadData.skill do
        local skllId = this.LeadData.skill[i].cfgId
        local pConfig = MotherShipPlaneConfig[skllId]
        setPro(ret, pConfig.Attr)
    end
    return ret
end

-- 获取主角战斗属性
function AircraftCarrierManager.GetFightDataProperty()
    local allPro = AircraftCarrierManager.GetAllPro()
    local property
    property = {
        0,-- Level,
        allPro[1] and allPro[1] or 0,-- Hp,
        allPro[1] and allPro[1] or 0,-- Hp,
        allPro[2] and allPro[2] or 0,-- Attack,
        allPro[3] and allPro[3] or 0,-- PhysicalDefence,
        0,-- MagicDefence,
        allPro[5] and allPro[5] or 0,-- Speed,
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
    }
    return property
end

-- 获取开启槽位最大值
function AircraftCarrierManager.GetOpenSlotMaxCnt()
    return MotherShipConfig[this.LeadData.lv].UnlockSite
end

-- 根据槽位个数获取开启阶数
function AircraftCarrierManager.GetSlotOpenBreak(slotCnt)
    if slotCnt < 0 or slotCnt > 4 then
        LogError("GetSlotOpenBreak Error")
        return 0
    end
    local data = ConfigManager.GetConfigDataByDoubleKey(ConfigName.MotherShipConfig, "Type", 2, "UnlockSite", slotCnt)
    return data.Step
end

-- 获取拥有飞机 isContainEquip是否包含装配
function AircraftCarrierManager.GetAllSkillData(_isContainEquip)
    local isContainEquip = true
    if _isContainEquip ~= nil then
        isContainEquip = _isContainEquip
    end
    
    local ret = {}
    for k, v in pairs(this.allSkillData) do
        local isAdd = true
        if not isContainEquip then
            for i = 1, #this.LeadData.skill do
                if this.LeadData.skill[i].id == v.id then
                    isAdd = false
                    break
                end
            end
        end

        if isAdd then
            table.insert(ret, v)
        end
    end

    table.sort(ret, function(a, b)
        local ac = MotherShipPlaneConfig[a.cfgId]
        local bc = MotherShipPlaneConfig[b.cfgId]
        if ac.Lvl == bc.Lvl then
            if ac.Quality == bc.Quality then
                return ac.Type < bc.Type
            else
                return ac.Quality > bc.Quality
            end
        else
            return ac.Lvl > bc.Lvl
        end
    end)

    return ret
end

-- 获取单个技能数据
function AircraftCarrierManager.GetSingleSkillData(id)
    for k, v in pairs(this.allSkillData) do
        if v.id == id then
            return v
        end
    end
    return nil
end

-- 获取表内技能属性
function AircraftCarrierManager.GetSinglePlanePro(cfgId)
    local ret = {}
    local config = MotherShipPlaneConfig[cfgId]
    local function setPro(tb, pros)
        for i = 1, #pros do
            if tb[pros[i][1]] == nil then
                tb[pros[i][1]] = 0
            end
            tb[pros[i][1]] = tb[pros[i][1]] + pros[i][2]
        end
    end
    setPro(ret, config.Attr)
    return ret
end

-- 获取显示tips属性
function AircraftCarrierManager.GetMainProList(cfgId)
    local allAdd = AircraftCarrierManager.GetSinglePlanePro(cfgId)

    local propList = {}
    for k, v in pairs(allAdd) do
        table.insert(propList, {propertyId = k, propertyValue = v, PropertyConfig = PropertyConfig[k]})
    end
    return propList
end

--通过表Id获取下一级技能信息
function AircraftCarrierManager.GetSkillNextIdForConfigId(cfgId)
    local nextId = MotherShipPlaneConfig[cfgId].NextId
    if nextId and nextId > 0 then
        return MotherShipPlaneConfig[nextId]
    end
    return nil
end

--检测基因是否可升级
function AircraftCarrierManager.GetSkillIsCanLevelUp(cfgId, onlyId)
    local state = false
    local id = cfgId

    local data = {}
    for i = 1, #this.allGeneData do
        for j = 1, #this.allGeneData[i] do
            if id == this.allGeneData[i][j] then
                data = this.allGeneData[i]
            end
        end
    end
    for i = 1, #data do
        if AircraftCarrierManager.CheckSkillIsGet(data[i]) then
            id = data[i]
        end
    end

    local config = AircraftCarrierManager.GetSkillLvImgForId(id)
    local nextConfig = AircraftCarrierManager.GetSkillNextIdForConfigId(id)
    if nextConfig then
        if BagManager.GetItemCountById(config.config.CostItem[1]) >= config.config.CostItem[2] and
            AircraftCarrierManager.GetSkillSimilarCount(config.config.CostPlane[1], onlyId) >= config.config.CostPlane[2] then
                state = true
            end
    end
    -- LogError(cfgId.."   ==>  "..id.."   ==>  "..tostring(state))
    if id == cfgId and state then
        return true
    end
    return false
end

-- 获取已装备数据
function AircraftCarrierManager.EquipSkillDataToChooseList()
    local ret = {}
    for i = 1, #this.LeadData.skill do
        -- local t = AircraftCarrierManager.CreatSkill()
        -- AircraftCarrierManager.CopyValue(t, this.LeadData.skill[i])
        table.insert(ret, this.LeadData.skill[i])
    end
    table.sort(ret, function (a, b)
        return a.sort < b.sort
    end)
    return ret
end

--获取装备技能空位
function AircraftCarrierManager.GetSkillIsEquipPos()
    -- local index = 1
    -- for i = 1, #this.LeadData.skill do
    --     if this.LeadData.skill[i].sort >= index then
    --         if this.LeadData.skill[i].sort <= AircraftCarrierManager.GetOpenSlotMaxCnt() - 1 then
    --             index = this.LeadData.skill[i].sort + 1
    --         else
    --             index = 0
    --         end
    --     end
    -- end
    -- if #this.LeadData.skill == AircraftCarrierManager.GetOpenSlotMaxCnt() then
    --     index = 0
    -- end
    -- return index

    for i = 1, 4 do
        local isOk = true
        for j = 1, #this.LeadData.skill do
            if this.LeadData.skill[j].sort == i then
                isOk = false
            end
        end
        if isOk then
            if i <= AircraftCarrierManager.GetOpenSlotMaxCnt() then
                return i
            end
        end
    end
    return 0
end

--通过ID获取技能所在槽位
function AircraftCarrierManager.GetSkillPosForId(id)
    for i = 1, #this.LeadData.skill do
        if this.LeadData.skill[i].id == id then
            return this.LeadData.skill[i].sort
        end
    end
end

--通过ID判断技能是否已装备
function AircraftCarrierManager.GetSkillIsEquipForId(id)
    for i = 1, #this.LeadData.skill do
        if id == this.LeadData.skill[i].id then
            return true
        end
    end
    return false
end

--装/卸 技能
function AircraftCarrierManager.EquipOrDowmSkill(skillId, func)
    if AircraftCarrierManager.GetSkillIsEquipForId(skillId) then
        local pos = AircraftCarrierManager.GetSkillPosForId(skillId)
        if pos == 0 then
            return
        end
        NetManager.MotherShipUnloadRequest(skillId, pos, function ()
            AircraftCarrierManager.GetLeadData(function ()
                if func then
                    func()
                end
                Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshSkill)
                Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshInfo)
            end)
        end)
    else
        local equipList = AircraftCarrierManager.EquipSkillDataToChooseList()
        local state = false
        for i = 1, #equipList do
            if MotherShipPlaneConfig[AircraftCarrierManager.GetSingleSkillData(skillId).cfgId].Type == MotherShipPlaneConfig[equipList[i].cfgId].Type then
                state = true
            end
        end
        if state then
            PopupTipPanel.ShowTipByLanguageId(50369)
            return
        end
        local pos = AircraftCarrierManager.GetSkillIsEquipPos()
        if pos == 0 then
            PopupTipPanel.ShowTipByLanguageId(50370)
            return
        end
        NetManager.MotherShipWearRequest(skillId, pos, function ()
            AircraftCarrierManager.GetLeadData(function ()
                if func then
                    func()
                end
                Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshSkill)
                Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshInfo)
            end)
        end)
    end
end

--升级技能
function AircraftCarrierManager.SkillLevelUp(skillId, func)
    local configId = AircraftCarrierManager.GetSingleSkillData(skillId).cfgId
    local config = AircraftCarrierManager.GetSkillLvImgForId(configId)

    local bagNum = BagManager.GetItemCountById(config.config.CostItem[1])
    if bagNum < config.config.CostItem[2] then
        PopupTipPanel.ShowTipByLanguageId(10073)
        return
    end

    local ownConditionCnt = AircraftCarrierManager.GetSkillSimilarCount(config.config.CostPlane[1], skillId)
    if ownConditionCnt < config.config.CostPlane[2] then
        PopupTipPanel.ShowTipByLanguageId(10073)
        return
    end
    NetManager.MotherShipPlanUpStarRequest(skillId, function ()
        AircraftCarrierManager.GetAllPlaneReq(function ()
            AircraftCarrierManager.GetLeadData(function ()
                PopupTipPanel.ShowTipByLanguageId(50371)
                if func then
                    func()
                end
                Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshSkill)
            end)
        end)
    end)
end

-- 获取装备飞机对应技能ids 需按槽位顺序
function AircraftCarrierManager.GetFightDataSkillIds()
    local skills = {}
    local list = this.EquipSkillDataToChooseList()
    table.sort(list, function(a, b)
        return a.sort < b.sort
    end)
    for i = 1, #list do
        local config = MotherShipPlaneConfig[list[i].cfgId]
        table.insert(skills, config.Skill)
    end
    return skills
end

-- 支持背包的数据
function AircraftCarrierManager.GetBagAllDatas()
    local data = {}
    local allGene = AircraftCarrierManager.GetAllSkillData(false)
    for i = 1, #allGene do
        local state = true
        for j = 1, #data do
            if data[j].cfgId == allGene[i].cfgId then
                state = false
            end
        end
        if state then
            local num = AircraftCarrierManager.GetSkillSimilarCount(allGene[i].cfgId, allGene[i].id) + 1
            table.insert(data, {
                itemConfig = ItemConfig[allGene[i].cfgId],
                frame = GetQuantityImageByquality(MotherShipPlaneConfig[allGene[i].cfgId].Quality),
                icon = GetResourcePath(ItemConfig[allGene[i].cfgId].ResourceID),
                id = allGene[i].id,
                cfgId = allGene[i].cfgId,
                num = num,
            })
        end
    end
    return data
end

-- 检测技能是否已获得（在当前已拥有里查找，只会判断当前等级的已拥有）
function AircraftCarrierManager.CheckSkillIsGet(cfgId)
    for k, v in pairs(this.allSkillData) do
        if v.cfgId == cfgId then
            return true
        end
    end
    return false
end

function AircraftCarrierManager.SetGeneAtlas(msg)
    this.geneAtlas = msg.motherShipPlanCfgIds
end

function AircraftCarrierManager.GetGeneAtlasIsHave(cfgId)
    for i = 1, #this.geneAtlas do
        if this.geneAtlas[i] == cfgId then
            return true
        end
    end
    return false
end

function AircraftCarrierManager.GetGeneAtlasHaveNumberForLv(lv)
    local config = ConfigManager.GetAllConfigsDataByKey(ConfigName.MotherShipPlaneConfig, "Lvl", lv)
    local haveNum = 0
    for i = 1, #config do
        if AircraftCarrierManager.GetGeneAtlasIsHave(config[i].Id) then
            haveNum = haveNum + 1
        end
    end
    return haveNum
end

-- 获取所有该等级的技能
function AircraftCarrierManager.GetAtlasForLv(lv)
    local config = ConfigManager.GetAllConfigsDataByKey(ConfigName.MotherShipPlaneConfig, "Lvl", lv)
    local haveNum = 0
    for i = 1, #config do
        if AircraftCarrierManager.CheckSkillIsGet(config[i].Id) then
            haveNum = haveNum + 1
        end
    end
    return config, haveNum
end

-- 检测主角是否可以升级红点
function AircraftCarrierManager.CheckRedPoint_CV_LvUp()
    if not this.LeadData then
        return false
    end
    local id = this.LeadData.lv
    local shipConfig = MotherShipConfig[id]
    if shipConfig.NextId == 0 then
        return false
    end
    for i = 1, 2 do
        local itemId = shipConfig.Cost[i][1]
        local bagNum = BagManager.GetItemCountById(itemId)
        if bagNum < shipConfig.Cost[i][2] then
            return false
        end
    end
    return true
end

-- 获取特权是否解锁
function AircraftCarrierManager.GetPrivilege()
    return PrivilegeManager.GetPrivilegeOpenStatusById(60002)
end

-- 检测普通研究红点
function AircraftCarrierManager.CheckRedPointForNormal()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
        return false
    end
    if not this.LeadData then
        return false
    end
    if this.LeadData.normal.curItemId ~= 0 then
        return false
    end
    for i = 1, 3 do
        while true
        do
            local bulePrintConfig = MotherShipPlaneBlueprint[i]
            if bulePrintConfig == nil then
                break
            end
            local itemid = bulePrintConfig.ItemId
            local itemOwnNum = BagManager.GetItemCountById(itemid)
            if itemOwnNum > 0 then
                return true
            end

            break
        end
    end
    return false
end

-- 检测特权研究红点
function AircraftCarrierManager.CheckRedPointForPrivilege()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
        return false
    end
    if not this.LeadData then
        return false
    end
    if this.LeadData.privilege.curItemId ~= 0 then
        return false
    end
    if not AircraftCarrierManager.GetPrivilege() then
        return false
    end
    for i = 1, 3 do
        while true
        do
            local bulePrintConfig = MotherShipPlaneBlueprint[i]
            if bulePrintConfig == nil then
                break
            end
            local itemid = bulePrintConfig.ItemId
            local itemOwnNum = BagManager.GetItemCountById(itemid)
            if itemOwnNum > 0 then
                return true
            end

            break
        end
    end
    return false
end

--检测研发速度升级红点
function AircraftCarrierManager.CheckRedPointForSpeed()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
        return false
    end
    if not this.LeadData then
        return false
    end
    for i = 1, 3 do
        local speedConfig = MotherShipResearchPlus[i]
        if speedConfig == nil then LogError("打印|MotherShipResearchPlus表出错") return false end
        local itemid = speedConfig.CostItem[1]
        local itemOwnNum = BagManager.GetItemCountById(itemid)
        if itemOwnNum >= speedConfig.CostItem[2] then
            return true
        end
    end
    return false
end

--检测是否有技能可以装配
function AircraftCarrierManager.CheckRedPointForSkill()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER) then
        return false
    end
    if not this.LeadData then
        return false
    end
    local max = AircraftCarrierManager.GetOpenSlotMaxCnt()
    local cur = #this.LeadData.skill
    local data = AircraftCarrierManager.GetAllSkillData(true)
    return (#data > cur) and (cur < max)
end

return this