GuideManager = {}
local this = GuideManager
local GuideConfig = ConfigManager.GetConfig(ConfigName.GuideConfig)
local GlobalSystemConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
local PlayerLevelConfig = ConfigManager.GetAllConfigsData(ConfigName.PlayerLevelConfig)
local openDic = {}

local json = require 'cjson'

local _CarbonGuildList = {}
local _IsFuncGuild = false
local _FuncGuideList = {}

--初始化
function this.Initialize()
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, this.OnFunctionOpen)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnLevelChange, this.OnLevelChange)
    Game.GlobalEvent:AddEvent(GameEvent.GuideTask.OnGuideTaskChange, this.OnGuideShow)
end

function this.OnLevelChange()
    -- 首充引导特殊处理到十级开放
    -- if PlayerManager.level == 10 then
    --     table.insert(_FuncGuideList, 100200)
    --     this.CheckFuncGuide()
    -- end

    local triggleNum = 0
    for i, v in ipairs(PlayerLevelConfig) do
        if PlayerManager.level >= v.PlayerLv then
            if v.GuideId and v.GuideId > 0 then
                if not this.IsTriggered(v.GuideId) then
                    table.insert(_FuncGuideList, v.GuideId)
                    triggleNum = triggleNum + 1
                end
            end
        end
    end
    if triggleNum > 0 then
        this.CheckFuncGuide()
    end
end

function this.IsTriggered(id)
    if AppConst.isOpenGM then --GM下可以重复触发
        return false
    end

    for i = 1, #openDic[GuideType.Function] do
        if openDic[GuideType.Function][i] == id then
            return true
        end
    end
    return false
end

function this.OnFunctionOpen(funcId)
    if not AppConst.isGuide then
        return
    end

    local guideId = GlobalSystemConfig[funcId].GuideId
    if not guideId or guideId == 0 or this.IsTriggered(guideId) then
        return
    end

    table.insert(_FuncGuideList, guideId)
    this.CheckFuncGuide()
end

function this.OnGuideShow(guideId)
    if not AppConst.isGuide then
        return
    end

    if not guideId or guideId == 0 or this.IsTriggered(guideId) then
        return
    end

    table.insert(_FuncGuideList, guideId)
    this.CheckFuncGuide()
end

-- 初始化引导数据
function this.InitData(guideData)
    --this.RefreshTriggerListen(1701, 35, { 17,})
    --只有勾了新手引导，才会读取引导数据，否则置为-1

    openDic[GuideType.Force] = -1
    openDic[GuideType.Function] = {}

    if not AppConst.isGuide then
        NetManager.SaveGuideDataRequest(GuideType.Force, -1)
        return
    end

    for i = 1, #guideData do
        local guide = guideData[i]
        local guideId = guide.id
        if guide.type == GuideType.Force then --强制引导
            openDic[GuideType.Force] = guideId            
        elseif guide.type == GuideType.Function then -- 功能性引导记录
            table.insert(openDic[GuideType.Function], guideId)  
        end
    end

    if openDic[GuideType.Force] ~= -1 then
        local openType = GuideConfig[openDic[GuideType.Force]].OpenType
        local openArgs = GuideConfig[openDic[GuideType.Force]].OpenArgs
        this.RefreshTriggerListen(openDic[GuideType.Force], openType, openArgs)
    end

    -- -- 测试功能引导用
    -- Timer.New(function()
    --    this.OnGuideShow(20500)
    -- end, 1):Start()
end

-- 检测功能引导
function GuideManager.CheckFuncGuide()
    if not GuideManager.IsInMainGuide() and not _IsFuncGuild and #_FuncGuideList > 0 then
        if BattleManager.IsInBackBattle() then
            return
        end
        local guideId = _FuncGuideList[1]
        if GuideConfig[guideId].Type == GuideType.Function then
            LogRed("准备功能引导："..guideId)
        end
        --功能性引导触发发送给服务器存储
        if GuideConfig[guideId].Type == GuideType.Function then
            table.insert(openDic[GuideType.Function], guideId) 
            NetManager.SaveGuideDataRequest(GuideConfig[guideId].Type, guideId)
        end
        GuideManager.ShowGuide(guideId)
        table.remove(_FuncGuideList, 1)
        if GuideConfig[guideId].Type == GuideType.Function then
            LogRed("移除："..guideId)
        end
    end
end

--- 外部调用检测副本引导的方法
function GuideManager.CheckCarbonGuild(carbonType)
    -- 判断当前
    if CarbonManager.difficulty ~= carbonType then return end
    -- 判断是否时第一次进入某类型副本
    if MapManager.IsPlayedByMapType(carbonType) then return end
    -- 设置已经进入过此类型副本（感觉放在这里不好，但是为了统一处理先放在这里）
    MapManager.SetMapTypePlayed(carbonType)
    -- 找到符合条件的引导数据
    for _, config in ipairs(_CarbonGuildList) do
        if config.OpenArgs[1] == carbonType then
            this.ShowGuide(config.Id)
        end
    end
end

-- 获取当前引导节点
function this.GetCurId(type)
    return openDic[type]
end

--判定是否在强制引导阶段
function this.IsInMainGuide()
    return openDic[GuideType.Force] and openDic[GuideType.Force] ~= -1
end

-- 判断功能引导是否存在
function this.IsFunctionGuideExist()
    return _IsFuncGuild
end

--更新下一步引导
function this.CheckNextGuideListen(nextId)
    if GuideConfig[nextId] then
        local type = GuideConfig[nextId].Type
        if GuideType.Force == type then
            openDic[type] = nextId
            this.RefreshTriggerListen(nextId, GuideConfig[nextId].OpenType, GuideConfig[nextId].OpenArgs)
        end

        if openDic[GuideType.Force] == -1 and GuideConfig[nextId].OpenType ~= 0 then
            this.RefreshTriggerListen(nextId, GuideConfig[nextId].OpenType, GuideConfig[nextId].OpenArgs)
        end
    end
end

function this.ShowGuide(id, ...)
    -- 引导数据打点
    DataCenterManager.CommitClickStatus(GetLanguageStrById(10839), tostring(id))
    -- ThinkingAnalyticsManager.Track("guild", {
    --     step_id = id,
    --     guild_start_time = math.floor(GetTimeStamp()),
    -- })
    -- 引导结束回调
    local function onGuideClose()
        if GuideConfig[id].Type == GuideType.Force then
            if not this.IsInMainGuide() then
                -- 强制引导结束检测是否需要功能引导
                this.CheckFuncGuide()
            end
        elseif GuideConfig[id].Type == GuideType.Function then
            -- 关闭功能引导
            _IsFuncGuild = false
            -- 检测是否还需要功能引导
            this.CheckFuncGuide()
        end
    end
    -- 监听下一步引导
    if GuideConfig[id].Next ~= 0 then
        this.CheckNextGuideListen(GuideConfig[id].Next)
    end
    -- 开始功能引导
    if GuideConfig[id].Type == GuideType.Function then
        _IsFuncGuild = true
        LogRed("开始功能引导:"..id)
    end
    Log("执行引导panel")
    -- 显示当前引导
    UIManager.OpenPanel(UIName.GuidePanel, id, onGuideClose, ...)
end

-- 同步引导数据到服务器
function this.SyncServer(id)     --同步到后端
    Game.GlobalEvent:DispatchEvent(GameEvent.Guide.NextTrigger, id)
    if GuideConfig[id].ServerNext ~= 0 then
        if GuideConfig[id].Type == GuideType.Force then
            openDic[GuideType.Force] = GuideConfig[id].ServerNext
            NetManager.SaveGuideDataRequest(GuideConfig[id].Type, GuideConfig[id].ServerNext)
        end 
    end
end

--更新触发监听
function this.RefreshTriggerListen(id, openType, openArgs)
    if openType == 1 then
        --进入新关卡界面
        local trigger
        trigger = function(panelType, panel)
            if panelType == UIName.FightPointPassMainPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 101 then
        local isTrigger = false
        local trigger
        trigger = function(panelType, panel)
            if panelType == UIName.FightPointPassMainPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnFocus, trigger)
                if not isTrigger then
                    this.ShowGuide(id)
                    isTrigger = true
                end
            end
        end
        local trigger2
        trigger2 = function(panelType, panel)
            if panelType == UIName.FightPointPassMainPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger2)
                if not isTrigger then
                    this.ShowGuide(id)
                    isTrigger = true
                end
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnFocus, trigger)
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger2)
    elseif openType == 2 then
        --地图走格子触发
        local trigger
        trigger = function(u, v, callList)
            if MapManager.curMapId == 100 and u == openArgs[1] and v == openArgs[2] then
                Game.GlobalEvent:RemoveEvent(GameEvent.Guide.MapPosTriggered, trigger)
                this.ShowGuide(id)
                callList:Push(function()
                    trigger = function(panelType)
                        if panelType == UIName.GuidePanel then
                            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                            MapPanel.CallListPop()
                        end
                    end
                    Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
                end)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.MapPosTriggered, trigger)
    elseif openType == 3 then
        --监听指定怪物组id的战斗,战斗技能触发,显示对位敌人
        local trigger
        trigger = function(roleView)
            if FightPointPassManager.curOpenFight == openArgs[1] then
                Game.GlobalEvent:RemoveEvent(GameEvent.Guide.GuideBattleCDDone, trigger)
                BattleManager.PauseBattle()
                this.ShowGuide(id, roleView)

                GuidePanel.upArrow.transform.position = roleView.GameObject.transform.position
                local enemyView = roleView.RootPanel.GetRoleView(BattleLogic.GetAggro(roleView.role))
                GuidePanel.upArrow.transform.up = Vector3.Normalize(enemyView.GameObject.transform.position - roleView.GameObject.transform.position)
                -- Util.GetTransform(GuidePanel.upArrow, "1").localEulerAngles = -GuidePanel.upArrow.transform.localEulerAngles
                GuidePanel.upArrow:SetActive(true)

                local canGO1 = roleView.GameObject.transform.parent.parent.gameObject:GetComponent("Canvas")
                local canGO2 = enemyView.GameObject.transform.parent.gameObject:GetComponent("Canvas")
                local canGO3 = Util.GetGameObject(roleView.RootPanel.EnemyPanel, "live_"..canGO2.name):GetComponent("Canvas")
                canGO1.overrideSorting = true
                canGO2.overrideSorting = true
                canGO3.overrideSorting = true
                canGO1.sortingOrder = GuidePanel.sortingOrder
                canGO2.sortingOrder = GuidePanel.sortingOrder
                canGO3.sortingOrder = GuidePanel.sortingOrder

                trigger = function(theId)
                    if id == theId then
                        Game.GlobalEvent:RemoveEvent(GameEvent.Guide.NextTrigger, trigger)
                        BattleManager.ResumeBattle()
                        GuidePanel.upArrow:SetActive(false)
                        canGO1.overrideSorting = false
                        canGO2.overrideSorting = false
                        canGO3.overrideSorting = false
                    end
                    end
                Game.GlobalEvent:AddEvent(GameEvent.Guide.NextTrigger, trigger)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.GuideBattleCDDone, trigger)
    elseif openType == 4 then
        --序章完成进入主界面完成触发
        local trigger
        trigger = function(panelType, panel)
            if panelType == UIName.MainPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 5 then
        --监听指定怪物组id的战斗,有敌方角色死亡时,我方对位角色技能触发
        local trigger
        trigger = function(roleView)
            if FightPointPassManager.curOpenFight == openArgs[1] and roleView.RootPanel.GuideCheckEnemyDead(roleView.role) then
                Game.GlobalEvent:RemoveEvent(GameEvent.Guide.GuideBattleCDDone, trigger)
                BattleManager.PauseBattle()
                this.ShowGuide(id, roleView)

                GuidePanel.upArrow.transform.position = roleView.GameObject.transform.position
                local enemyView = roleView.RootPanel.GetRoleView(BattleLogic.GetAggro(roleView.role))
                GuidePanel.upArrow.transform.up = Vector3.Normalize(enemyView.GameObject.transform.position - roleView.GameObject.transform.position)
                -- Util.GetTransform(GuidePanel.upArrow, "1").localEulerAngles = -GuidePanel.upArrow.transform.localEulerAngles
                GuidePanel.upArrow:SetActive(true)

                local canGO1 = roleView.GameObject.transform.parent.parent.gameObject:GetComponent("Canvas")
                local canGO2 = enemyView.GameObject.transform.parent.gameObject:GetComponent("Canvas")
                local canGO3 = Util.GetGameObject(roleView.RootPanel.EnemyPanel, "live_"..canGO2.name):GetComponent("Canvas")
                canGO1.overrideSorting = true
                canGO2.overrideSorting = true
                canGO3.overrideSorting = true
                canGO1.sortingOrder = GuidePanel.sortingOrder
                canGO2.sortingOrder = GuidePanel.sortingOrder
                canGO3.sortingOrder = GuidePanel.sortingOrder

                trigger = function(theId)
                    if id == theId then
                        GuidePanel.upArrow:SetActive(false)
                        canGO1.overrideSorting = false
                        canGO2.overrideSorting = false
                        canGO3.overrideSorting = false
                    end
                    if GuideConfig[id].Next == theId then
                        Game.GlobalEvent:RemoveEvent(GameEvent.Guide.NextTrigger, trigger)
                        BattleManager.ResumeBattle()
                    end
                end
                Game.GlobalEvent:AddEvent(GameEvent.Guide.NextTrigger, trigger)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.GuideBattleCDDone, trigger)
    elseif openType == 6 then
        --监听指定怪物组id的战斗技能是否触发
        local trigger
        trigger = function(roleView)
            if FightPointPassManager.curOpenFight == openArgs[1] then
                Game.GlobalEvent:RemoveEvent(GameEvent.Guide.GuideBattleCDDone, trigger)
                BattleManager.PauseBattle() --触发时暂停游戏逻辑
                this.ShowGuide(id, roleView)

                local canGO1 = roleView.GameObject.transform.parent.parent.gameObject:GetComponent("Canvas")
                canGO1.overrideSorting = true
                canGO1.sortingOrder = GuidePanel.sortingOrder

                trigger = function(panelType)
                    if panelType == UIName.GuidePanel then
                        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                        BattleManager.ResumeBattle()
                        canGO1.overrideSorting = false
                    end
                end
                Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.GuideBattleCDDone, trigger)
    elseif openType == 7 then
        --进入上阵选择界面，判定指定关卡通关
        local trigger
        trigger = function(panelType)
            if panelType == UIName.FormationPanel and FightPointPassManager.curOpenFight == openArgs[1] then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 8 then
        --监听指定怪物组id的战斗，触发战场分割,显示战斗提示，切换到第二提示
        local trigger
        trigger = function(stage)
            if FightPointPassManager.curOpenFight == openArgs[1] and stage == openArgs[2] then
                Game.GlobalEvent:RemoveEvent(GameEvent.Guide.GuideBattleStageChange, trigger)
                BattleManager.PauseBattle() --触发时暂停游戏逻辑
                this.ShowGuide(id, stage)

                trigger = function(theId)
                    if GuideConfig[id].Next == theId then
                        Game.GlobalEvent:RemoveEvent(GameEvent.Guide.NextTrigger, trigger)
                        BattleManager.ResumeBattle()
                    end
                end
                Game.GlobalEvent:AddEvent(GameEvent.Guide.NextTrigger, trigger)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.GuideBattleStageChange, trigger)
    elseif openType == 9 then
        --进入新关卡界面，判定指定关卡通关
        local trigger
        trigger = function(panelType, panel)
            if panelType == UIName.FightPointPassMainPanel and FightPointPassManager.curOpenFight == openArgs[1] then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 10 then
        --进入单抽界面
        local trigger
        trigger = function(panelType, panel)
            if panelType == UIName.SingleRecruitPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 11 then
        --进入上阵选择界面
        local trigger
        trigger = function(panelType)
            if panelType == UIName.FormationPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 12 then
        --进入副本引导界面
        local trigger
        trigger = function(panelType)
            if panelType == UIName.CarbonMissionPopup then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 13 then
        --关闭剧情对话窗口
        local trigger
        trigger = function(panelType)
            if panelType == UIName.StoryDialoguePanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)       
    elseif openType == 14 then
        --地图点option完成触发
        local trigger
        trigger = function(type, optionId)
            if type == 1 and optionId == openArgs[1] then
                Game.GlobalEvent:RemoveEvent(GameEvent.Map.ProgressChange, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Map.ProgressChange, trigger)
    elseif openType == 15 then
        --战斗胜利结算
        local trigger
        trigger = function(panelType)
            if panelType == UIName.BattleWinPopup then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 16 then
        --序章战开始
        local trigger
        trigger = function(panelType)
            if MapManager.curMapId == 100 then
                Game.GlobalEvent:RemoveEvent(GameEvent.Guide.GuideBattleStart, trigger)
                BattleManager.PauseBattle()
                this.ShowGuide(id)

                trigger = function(panelType)
                    if panelType == UIName.GuidePanel then
                        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                        BattleManager.ResumeBattle()
                    end
                end
                Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.GuideBattleStart, trigger)
    elseif openType == 17 then
        --序章探索完成
        local trigger
        trigger = function(panelType)
            if MapManager.curMapId == 100 and panelType == UIName.MissionRewardPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 18 then
        --恭喜获得界面
        local trigger
        trigger = function(panelType)
            if panelType == UIName.RewardItemPopup then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 19 then
        --监听角色升级界面
        local trigger
        trigger = function(panelType)
            if panelType == UIName.RoleUpLvBreakSuccessPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
    elseif openType == 20 then
        --监听地图任务界面
        local trigger
        trigger = function(panelType)
            if panelType == UIName.CarbonMissionPopup then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 21 then
        --进入地图
        local trigger
        trigger = function()
            if MapManager.curMapId == openArgs[1] then
                Game.GlobalEvent:RemoveEvent(GameEvent.Guide.MapInit, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.MapInit, trigger)
    elseif openType == 22 then
        --监听副本结算界面
        local trigger
        trigger = function(panelType)
            if panelType == UIName.MapStatsPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 23 then
        --监听副本界面
        local trigger
        trigger = function(panelType)
            if panelType == UIName.CarbonTypePanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 24 then
        --恭喜获得界面弹出后
        local trigger
        trigger = function(panelType)
            if panelType == UIName.RewardItemPopup then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
    elseif openType == 25 then
        --升阶完成后
        local trigger
        trigger = function(panelType)
            if panelType == UIName.RoleUpStarSuccessPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
    --elseif openType == 26 then
    --    --功能开启后
    --    local trigger
    --    trigger = function(panelType)
    --        if panelType == UIName.MainPanel and ActTimeCtrlManager.IsQualifiled(openArgs[1]) then
    --            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
    --            this.ShowGuide(id)
    --        end
    --    end
    --    Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 27 then
        --天赋收集完成
        local trigger
        trigger = function(panelType)
            if panelType == UIName.MsgPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 28 then
        --首次进入试炼副本
        local trigger
        trigger = function()
            if MapTrialManager.firstEnter then
                Game.GlobalEvent:RemoveEvent(GameEvent.Guide.MapInit, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.MapInit, trigger)
    elseif openType == 29 then
        --工坊升级界面关闭
        local trigger
        trigger = function(panelType)
            if panelType == UIName.WorkShopLevelUpNotifyPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
    elseif openType == 30 then
        --击败秘境的看守
        local trigger
        trigger = function(areaId)
            if areaId then
                Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.MonsterSayInfo, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.Adventure.MonsterSayInfo, trigger)
    elseif openType == 31 then
        local trigger
        trigger = function(panelType)
            if panelType == UIName.ArenaMainPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 32 then
        local trigger
        trigger = function(panelType)
            if panelType == UIName.FightEndLvUpPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
    elseif openType == 33 then
        --local trigger
        --trigger = function(panelType)
        --    if panelType == UIName.TalentUpGradSuccessPanel then
        --        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
        --        this.ShowGuide(id)
        --    end
        --end
        --Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 34 then
        --local trigger
        --trigger = function(panelType)
        --    if panelType == UIName.TalentUpGradSuccessPanel then
        --        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, trigger)
        --        this.ShowGuide(id)
        --    end
        --end
        --Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, trigger)
    elseif openType == 35 then
        local trigger
        trigger = function(panelType)
            --close => BattlePanel
            if panelType == UIName.FightPointPassMainPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    elseif openType == 36 then  -- 第一次进入副本触发
        local trigger
        trigger = function(panelType)
            --close => BattlePanel
            if panelType == UIName.MapPanel then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, trigger)
                this.ShowGuide(id)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, trigger)
    end
end

this.isShowGuide = false
--弱引导
function this.RefreshGuide()
    local task, battle = false, false
    local curGuideTaskData = TaskManager.GetCurrentGuideTask(TaskTypeDef.GuideTask)--新手任务
    local isBattle = BattleManager.IsInBackBattle()--战斗中
    local isCanBattle = FightPointPassManager.IsCanFight(FightPointPassManager.curOpenFight)--有挑战的关卡
    if not GuideManager.IsInMainGuide() or not UIManager.IsOpen(UIName.GuidePanel) then--不在强制引导
        if curGuideTaskData ~= nil then--新手任务没有结束
            if curGuideTaskData.state == 1 then --新手任务可领取
                task = true
            elseif curGuideTaskData.state ~= 1 then
                if not isBattle then
                    if isCanBattle then
                        battle = true
                    else
                        local config = ConfigManager.GetConfigData(ConfigName.GuideTaskConfig, curGuideTaskData.missionId)
                        if config.isGuideShow == 1 then
                            task = false
                        else
                            task = true
                        end
                    end
                end
            end
        else
            if isCanBattle and not isBattle then
                battle = true
            end
        end
    end
    return task, battle
end

return this