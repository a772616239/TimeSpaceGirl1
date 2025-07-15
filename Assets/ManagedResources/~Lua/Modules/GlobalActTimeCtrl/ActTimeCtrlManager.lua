--- 管理游戏所有功能的开关状态
--- Created by Steven.
--- DateTime: 2019/5/9 16:07

ActTimeCtrlManager = {};
local this = ActTimeCtrlManager
local AllActSetConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
local censorshipConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local gameSetConfig = ConfigManager.GetConfig(ConfigName.GameSetting)
local vipConfig = ConfigManager.GetConfig(ConfigName.VipLevelConfig)
local SpecialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)

-- 整数的服务器时间
this.serTime = 0
local lastTime
local count = 0
local sendTime = 0
--时间间隔
local fixedTime = 1
local noVersion = {}

-- 服务数据
this.serData = {}

function this.Initialize()
    lastTime = this.serTime
    this.hasSendMsg = false

    -- 工坊等级提升
    Game.GlobalEvent:AddEvent(GameEvent.WorkShow.WorkShopLvChange, function()
        local lv =  WorkShopManager.WorkShopData.lv
        this.CheckFuncActiveByType(3, lv)
    end)
    -- 等级提升
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnLevelChange, function()
        local lv = PlayerManager.level
        this.CheckFuncActiveByType(2, lv)
    end)
    -- 关卡解锁
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnOpenFight, function(fightId)
        this.CheckFuncActiveByType(1, fightId)
    end)
end

-- 当功能解锁条件变化时检测
function this.CheckFuncActiveByType(activeType, params)
    for id, funcData in pairs(this.serData) do
        local funcInfo = ConfigManager.GetConfigData(ConfigName.GlobalSystemConfig, id)
        if funcInfo.OpenRules[1] == activeType then
            local typeId = funcInfo.IsIDdSame
            local isActive = this.SingleFuncState(typeId)
            
            if not funcData.isActive and isActive then
                -- 未解锁，但是判断已解锁
                Game.GlobalEvent:DispatchEvent(GameEvent.FunctionCtrl.OnFunctionOpen, typeId)
            elseif funcData.isActive and not isActive then
                -- 已解锁但是判断未解锁
                Game.GlobalEvent:DispatchEvent(GameEvent.FunctionCtrl.OnFunctionClose, typeId)
            end
            -- 保存状态
            funcData.isActive = isActive
        end
    end
end

--判断功能是否解锁
function this.CheckFuncIsActive(isIDdSame)
    local isActive = this.SingleFuncState(isIDdSame)     
    return isActive
end

--> 检测当前等级下 是否有功能引导
function this.CheckIsHaveFuncGuideByLv(lv)
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)) do
        if configInfo and configInfo.OpenRules[1] == 2 and configInfo.GuideId and configInfo.GuideId > 0 and configInfo.OpenRules[2] == lv then
            return true
        end
    end
    return false
end

-- 初始化服务器数据
function this.InitMsg(msg)
    if #msg.functionOfTime == 0 then
        return
    end
    for i = 1, #msg.functionOfTime do
        local t = msg.functionOfTime[i]
        local id = t.functionId
        local startTime = t.startTime
        local endTime = t.endTime
        local restTime = t.interval

        this.serData[id] = {}
        this.serData[id].id = id
        this.serData[id].startTime = startTime
        this.serData[id].endTime = endTime
        this.serData[id].restTime = restTime

        -- 用于标记是否解锁使用
        local typeId = AllActSetConfig[id].IsIDdSame
        this.serData[id].isActive = this.SingleFuncState(typeId)
    end
    this.WatchFuncState()
    GeneralManager.GetGeneralMode()
end

-- 根据活动类型获取当前活动表数据
local ActTypeConfigList = {}    -- 做一个缓存避免重复遍历表数据
function this.GetTableDataByTypeId(typeId)
    if not ActTypeConfigList[typeId] then
        ActTypeConfigList[typeId] = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalSystemConfig, "IsIDdSame", typeId)
    end
    return ActTypeConfigList[typeId]
end
-- 根据活动类型获取当前活动得数据
function this.GetSerDataByTypeId(typeId)
    local configList = this.GetTableDataByTypeId(typeId)
    for _, config in ipairs(configList) do
        local actId = config.Id
        if this.serData[actId] then
            return this.serData[actId]
        end
    end
end

-- ////////////////////////////////////////////////////////////////////////////
-- 根据服务器时间更新
function this.Updata()
    if this.serTime ~= lastTime then
        lastTime = this.serTime
        this.FixedUpDate()
    end
end

-- 1秒更新一次
function this.FixedUpDate()
    count = count + 1
    this.WatchFuncState()

    if count == fixedTime then -- 每fixedTime更新一次
        count = 0
        -- do something
    end

    if this.hasSendMsg then
        sendTime = sendTime  + 1
        if sendTime >= 5 then
            sendTime = 0
            this.hasSendMsg = false
        end
    end
end

-- ///////////////////////////////////////////////////////////////////////////
-- 监测所有活动状态
function this.WatchFuncState()
    for i, v in pairs(this.serData) do
        local typeId = AllActSetConfig[i].IsIDdSame
        if this.IsQualifiled(typeId) then

            local timeType = ""
            if this.serTime >= v.startTime and this.serTime < v.endTime then
                --活动结束倒计时
                local closeTime = v.endTime - this.serTime
                --local showStr = os.date("%d天%H时%M分%S秒",closeTime)
                local showStr = FormatSecond(closeTime)
                timeType = GetLanguageStrById(10770) .. showStr
            else
                local openTime = 0
                openTime = v.startTime - this.serTime

                if openTime > 0 then
                    --local showStr = os.date("%Y年%M月%d日%H时%M分%S秒", 30)
                    local showStr = FormatSecond(openTime)
                    timeType = GetLanguageStrById(10771) .. showStr
                end
            end
            this.serData[i].countDown = timeType -- 活动计时文字
            this.serData[i].isOpen = this.SingleFuncState(typeId) -- 活动开启状态

            -- 活动开启前同步一次状态
            if this.serTime == v.startTime + 1 then
                if not this.hasSendMsg then
                    this.hasSendMsg = true
                    NetManager.GetAllFunState(function ()
                        Game.GlobalEvent:DispatchEvent(GameEvent.FunctionCtrl.OnFunctionOpen, typeId)
                    end)
                end
            end
            -- 活动结束前同步一次状态
            if this.serTime == v.endTime + 1 then
                if not this.hasSendMsg then
                    this.hasSendMsg = true
                    NetManager.GetAllFunState(function ()
                        Game.GlobalEvent:DispatchEvent(GameEvent.FunctionCtrl.OnFunctionClose, typeId)
                    end)
                end
            end
        end
    end
end

-- ///////////////////////////////////////////////////////////////////////////
--  检测某一活动开启与否
function this.FuncTimeJudge(id)
    local isActive = false
    local serData = this.GetSerDataByTypeId(id)
    if serData then
        local startTime = serData.startTime
        local endTime = serData.endTime

        if this.serTime >= startTime and this.serTime <= endTime then
            isActive = true
        else
            isActive = false
        end
    else
    end
    return isActive
end

-- 活动状态， 返回提示文字
function this.GetFuncTip(id)
    local tip = ""
    local qualifiled = this.IsQualifiled(id)
    local isActive = this.FuncTimeJudge(id)
    if noVersion[id] then
        tip = GetLanguageStrById(10773)
        return tip
    end
    if not qualifiled then
        -- 相同活动类型解锁数据相同，所以只用第一个进行判断
        local data = this.GetTableDataByTypeId(id)[1]
        local rules = data.OpenRules
        if rules[1] == 1 then
            tip = string.format(GetLanguageStrById(10774), censorshipConfig[rules[2]].Name)
        elseif rules[1] == 2 then
            tip = string.format(GetLanguageStrById(10775), rules[2])
        elseif rules[1] == 3 then
            tip = string.format(GetLanguageStrById(10776), rules[2])
        end
    else
        if not isActive then
            if id == FUNCTION_OPEN_TYPE.ARENA then
                tip = GetLanguageStrById(10777)
            else
                tip = GetLanguageStrById(10778)
            end
        end
    end

    return tip
end

-- 活动总状态
function this.SingleFuncState(id)
    local isOpen = false
    local qualifiled = this.IsQualifiled(id)
    local isActive = this.FuncTimeJudge(id)

    if qualifiled and isActive then
        isOpen = true
    else
        isOpen = false
    end
    return isOpen
end

-- 传入活动的ID, 显示活动期间文字
function this.ShowActText(id)
    local serData = this.GetSerDataByTypeId(id)
    if not serData then return end
    -- 如果活动正在进行，返回活动开启结束文字
    if this.FuncTimeJudge(id)then
        local beginStr = os.date(GetLanguageStrById(10779),this.serData[id].startTime)
        local endStr = os.date(GetLanguageStrById(10779),this.serData[id].endTime)
        return beginStr, endStr
    else
        return GetLanguageStrById(10780)
    end
end

-- 玩家是否有资格开启
function this.IsQualifiled(id)
    if id == FUNCTION_OPEN_TYPE.QuickTrain then
        return PlayerManager.level >= tonumber(SpecialConfig[513].Value)
    end

    -- 相同类型活动解锁类型相同，所以只判断第一个
    local data = this.GetTableDataByTypeId(id)[1]
    if not data then return false end
    if data.IsOpen == 0 then
        noVersion[id] = true
        return false
    else
        noVersion[id] = false
    end
    -- 当前玩家等级
    local qualifiled = false
    local playerLv = PlayerManager.level
    local openRule = data.OpenRules
    if openRule[1] == 1 then  -- 关卡开启
        qualifiled = FightPointPassManager.IsFightPointPass(openRule[2])
    elseif openRule[1] == 2 then-- 等级开启
        qualifiled = playerLv >= openRule[2]
    elseif openRule[1] == 3 then-- 工坊等级开启
        qualifiled = WorkShopManager.WorkShopData.lv >= openRule[2]
    end
    return qualifiled
end

--功能是否开启
function this.FunctionIsOpen(id)
    local state = false
    local openRule = AllActSetConfig[id].OpenRules
    if openRule[1] == 1 then  -- 关卡开启
        state = FightPointPassManager.IsFightPointPass(openRule[2])
    elseif openRule[1] == 2 then-- 等级开启
        state = PlayerManager.level >= openRule[2]
    elseif openRule[1] == 3 then-- 工坊等级开启
        state = WorkShopManager.WorkShopData.lv >= openRule[2]
    end
    return state
end

--传入需要锁上的功能, state 为true，需要置灰
function this.SetFuncLockState(obj, id, state,isWorkShop)
    local isOpen = this.SingleFuncState(id)
    if isWorkShop == true then
        if not isOpen then
            if state then
                Util.GetGameObject(obj.transform, "maskImage"):SetActive(true)
                local data = this.GetTableDataByTypeId(id)[1]
                local rules = data.OpenRules
                Util.GetGameObject(obj.transform, "maskImage/unLockText"):GetComponent("Text").text=string.format(GetLanguageStrById(10776), rules[2])
            else
                obj:SetActive(false)
            end
        else
            obj:SetActive(true)
            Util.GetGameObject(obj.transform, "maskImage"):SetActive(false)
        end
    else
        if not isOpen then
            if state then
                Util.SetGray(obj, true)
            else
                obj:SetActive(false)
            end
        else
            obj:SetActive(true)
            Util.SetGray(obj, false)
        end
    end
end

-- ==================== 编队设置 ===============
-- 最大上阵人数
function this.MaxArmyNum()
    local num = 0
    local formatData = gameSetConfig[1].HeroLocation
    for i = 1, #formatData do
        local judgeType = formatData[i][1]
        local value = formatData[i][2]
        if judgeType == 1 then -- 关卡判断
            local isPass = FightPointPassManager.IsFightPointPass(value)
            if isPass then
                num = num + 1
            end
        elseif judgeType == 2 then -- 等级判断
            local isPass = PlayerManager.level >= value
            if isPass then
                num = num + 1
            end
        end
    end
    return num
end

-- 上阵位置解锁条件
function this.UnLockCondition(index)
    local tip = GetLanguageStrById(10781)
    local formatData = gameSetConfig[1].HeroLocation
    local judgeType = formatData[index][1]
    local value = formatData[index][2]
    if judgeType == 1 then -- 关卡判断
        tip = GetLanguageStrById(10356) .. censorshipConfig[value].Name
    elseif judgeType == 2 then-- 等级判断
        tip = GetLanguageStrById(10782) .. tostring(value) .. GetLanguageStrById(10072)
    end
    return tip
end

-- 下一个解锁可上阵的条件
function this.NextArmCondition()
    -- 当前已经解锁的数量
    local nextIndex = this.MaxArmyNum() + 1
    if nextIndex >= this.MaxArmyNum() then
        nextIndex = this.MaxArmyNum()
    end
    local formatData = gameSetConfig[1].HeroLocation
    local judgeType = formatData[nextIndex][1]
    local value = formatData[nextIndex][2]
    local nextTip = GetLanguageStrById(10783)
    if judgeType == 1 then -- 关卡判断
        nextTip = GetLanguageStrById(10356) .. censorshipConfig[value].Name .. GetLanguageStrById(10784)
    elseif judgeType == 2 then -- 等级判断
        nextTip = GetLanguageStrById(10782) .. tostring(value) .. GetLanguageStrById(10785)
    end
    return nextTip
end

-- 获取某模块剩余开放时间  -1 表示未开放/已关闭
function this.GetActLeftTime(typeId)
    -- 检测数据正确性
    local serData = this.GetSerDataByTypeId(typeId)
    if not typeId or not serData then return -1 end
    -- 判断时间戳
    local curTimeStamp = GetTimeStamp()---毫秒
    if curTimeStamp < serData.startTime then    --- 时间未到
        return -1
    end
    -- 计算剩余时间
    local leftTime = math.floor(serData.endTime - curTimeStamp)
    return leftTime
end


function this.GetActOpenTime(id)
    local serData = this.GetSerDataByTypeId(id)
    if not serData then return end
    if this.SingleFuncState(id) then return end
    local openTime = serData.startTime - this.serTime
    local str = FormatSecond(openTime)
    return str
end

-- 最大上阵异妖数量
function this.MaxDemonNum()
    local maxNum = 0
    local gameSettingConFig = ConfigManager.GetConfigData(ConfigName.GameSetting,1).DifferLocation
    for i = 1, #gameSettingConFig do
        if gameSettingConFig[i][1] == 1 then--关卡判断
            if FightPointPassManager.IsFightPointPass(gameSettingConFig[i][2]) then
                maxNum = maxNum + 1
            end
        elseif gameSettingConFig[i][1] == 2 then--等级判断
            if PlayerManager.level >= gameSettingConFig[i][2] then
                maxNum = maxNum + 1
            end
        end
    end
    return maxNum
end

-- 开启下一个位置需要的VIP等级, 只有未解锁的才有用
function this.DemonNeedVipLv(index,srtType)
    local gameSettingConFig = ConfigManager.GetConfigData(ConfigName.GameSetting,1).DifferLocation
    for i = 1, #gameSettingConFig do
        if i == index then
            if gameSettingConFig[i][1] == 1 then--关卡判断
                local str = ""
                if srtType == 1 then
                    str = GetLanguageStrById(10356)..string.gsub(ConfigManager.GetConfigData(ConfigName.MainLevelConfig,gameSettingConFig[i][2]).Name,"-","|")
                else
                    str = GetLanguageStrById(10356)..ConfigManager.GetConfigData(ConfigName.MainLevelConfig,gameSettingConFig[i][2]).Name
                end
                return str
            elseif gameSettingConFig[i][1] == 2 then--等级判断
                return GetLanguageStrById(10786)..gameSettingConFig[i][2]
            end
        end
    end
end

-- 异妖上阵数量提示内容
function this.TipText(index)
    local tip = this.DemonNeedVipLv(index,2) .. GetLanguageStrById(10787)
    return tip
end


-- 恶心的副本的单独提示
function this.CarbonOpenTip()
    local minFight = 99999
    local minLevel = 99999
    local openRuleList = {}
    -- table.insert(openRuleList, AllActSetConfig[17].OpenRules)
    -- table.insert(openRuleList, AllActSetConfig[18].OpenRules)
    -- table.insert(openRuleList, AllActSetConfig[30].OpenRules)
    -- table.insert(openRuleList, AllActSetConfig[46].OpenRules)
    table.insert(openRuleList, AllActSetConfig[67].OpenRules)

    for i = 1, #openRuleList do
        local openRule = openRuleList[i][1]
        local openValue = openRuleList[i][2]
        if openRule == 1 then
            minFight = minFight < openValue and minFight or openValue
        elseif openRule == 2 then
            minLevel = minLevel < openRule and minLevel or openValue
        end
    end

    local str = ""
    if minLevel < 99999 and minFight ~= 99999 then
        str = string.format(GetLanguageStrById(10788), censorshipConfig[minFight].Name, minLevel)
    elseif minLevel == 99999 then
        str = string.format(GetLanguageStrById(10789), censorshipConfig[minFight].Name)
    elseif minFight == 99999 then
        str = string.format(GetLanguageStrById(10790), minLevel)
    end

    return str
end

--系统开启规则提示 type 开启系统类型
function this.SystemOpenTip(type)
    local str = ""
    if AllActSetConfig[type].OpenRules[1] == 1 then
        str = string.format(GetLanguageStrById(10791),censorshipConfig[AllActSetConfig[type].OpenRules[2]].Name)
    elseif AllActSetConfig[type].OpenRules[1] == 2 then
        str = string.format(GetLanguageStrById(10792),AllActSetConfig[type].OpenRules[2])
    end
    return str
end

return this