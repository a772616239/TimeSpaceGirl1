require("Base/BasePanel")
FastExploreInfoPopup = Inherit(BasePanel)
local this = FastExploreInfoPopup
local fightLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local TaskConfig = ConfigManager.GetConfig(ConfigName.TaskConfig)
local PrivilegeConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, 4002)
local JumpConfig = ConfigManager.GetConfig(ConfigName.JumpConfig)
local SpecialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local itemList = {}--训练特权道具
local itemList2 = {}--无任务训练特权道具
local costItem = nil--消耗道具
local taskItem = {}--任务奖励
local stageItem = {}--阶段奖励
local finishNum = 0--任务完成数量

--初始化组件（用于子类重写）
function this:InitComponent()
    this.mask = Util.GetGameObject(self.gameObject, "mask")
	this.UImask = Util.GetGameObject(self.gameObject, "UImask")
    this.btnBack = Util.GetGameObject(this.mask, "btnBack")

    this.notOpenPanel = Util.GetGameObject(this.mask, "notOpenPanel")--未开启
    this.activatedPanel = Util.GetGameObject(this.mask, "activatedPanel")--已激活
    this.privilegePanel = Util.GetGameObject(this.mask, "privilegePanel")--特权
    this.taskPanel = Util.GetGameObject(this.mask, "taskPanel")--任务
    this.notTaskPanel = Util.GetGameObject(this.mask, "notTaskPanel")--无任务

    this.btnHelp = Util.GetGameObject(this.mask, "btnHelp")
    this.btnTrain = Util.GetGameObject(this.mask, "btnTrain")--快速训练
    this.trainTime = Util.GetGameObject(this.btnTrain, "Text"):GetComponent("Text")--快速训练次数
    this.btnBuyPrivilege = Util.GetGameObject(this.privilegePanel, "btn")--购买特权
    this.privilegePanelImg = Util.GetGameObject(this.privilegePanel, "Image"):GetComponent("Image")--购买特权

    this.itemGrid = Util.GetGameObject(this.taskPanel, "scroll/Viewport/Content")
    this.costItem = Util.GetGameObject(this.btnTrain, "costItem")--消耗道具
    this.btnReceive = Util.GetGameObject(this.taskPanel, "btnReceive")--领取阶段奖励

    --无任务
    this.notTaskGrid = Util.GetGameObject(this.notTaskPanel, "grid")
    this.notTaskItem = Util.GetGameObject(this.notTaskPanel, "grid/pos")

end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.UImask, function ()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnHelp, function()
        local pos = this.btnHelp:GetComponent("RectTransform").localPosition
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.SpeedExploration, pos.x, pos.y)
    end)

    Util.AddClick(this.btnTrain, function ()
        this.Train()
    end)

    Util.AddClick(this.btnBuyPrivilege, function ()
        local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, 4002) or 0
        if boughtNum >= PrivilegeConfig.Limit then
            return
        end
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = PrivilegeConfig.Id }, function()
                FirstRechargeManager.RefreshAccumRechargeValue(PrivilegeConfig.Id)
                PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)
                this:OnShow()
            end)
        else
            NetManager.RequestBuyGiftGoods(PrivilegeConfig.Id, function()
                FirstRechargeManager.RefreshAccumRechargeValue(PrivilegeConfig.Id)
                PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)
                this:OnShow()
            end)
        end
    end)
    Util.AddClick(this.btnReceive, function ()
        if finishNum < 3 then
            return
        end
        NetManager.TakeMissionRewardRequest(TaskTypeDef.Train, 0, function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                AdventureManager.trainStageLevel = AdventureManager.trainStageLevel + 1
                local taskConfig = ConfigManager.GetConfigDataByKey(ConfigName.TrainTask, "Level", AdventureManager.GetTrainStageLevel())
                if not taskConfig then
                    AdventureManager.trainStageLevel = -1
                end
                this:OnShow()
                Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.TrainTask)
            end)
        end)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.RedPoint.TrainTask, this.RefreshTask)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnFastBattleChanged, this.OnShow)
    Game.GlobalEvent:AddEvent( GameEvent.Adventure.UpdateMultiUI, this.OnChangedLang)
   
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.RedPoint.TrainTask, this.RefreshTask)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnFastBattleChanged, this.OnShow)
end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
    
end

function this:OnChangedLang()
    this.privilegePanelImg:SetNativeSize()
end

function this:OnShow()
    CheckRedPointStatus(RedPointType.QuickTrain)
    this:UIChange()
    this.RefreshItemNum()
    this.InitRewardShow()
    this.RefreshTask()
    
end

function this:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    FightPointPassManager.isBeginFight = false
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    itemList = {}
    costItem = nil
    taskItem = {}
    itemList2 = {}
    stageItem = {}
end

function this:UIChange()
    local taskIsOpen = ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.QuickTrain)

    --任务未开启
    this.notOpenPanel:SetActive(not taskIsOpen)
    -- local config = ConfigManager.GetConfigData(ConfigName.GlobalSystemConfig, FUNCTION_OPEN_TYPE.QuickTrain)
    Util.GetGameObject(this.notOpenPanel , "Text"):GetComponent("Text").text = string.format(GetLanguageStrById(12297),tonumber(SpecialConfig[513].Value))
    Util.AddClick(Util.GetGameObject(this.notOpenPanel , "btn"), function ()
        self:ClosePanel()
    end)

    Util.GetGameObject(this.taskPanel, "stage"):GetComponent("Text").text = AdventureManager.trainStageLevel
    Util.GetGameObject(this.taskPanel, "title"):SetActive(taskIsOpen and AdventureManager.GetTrainStageLevel() ~= -1)--ui训练任务
    Util.GetGameObject(this.taskPanel, "stage"):SetActive(taskIsOpen and AdventureManager.GetTrainStageLevel() ~= -1)--ui阶段奖励
    Util.GetGameObject(this.taskPanel, "scroll"):SetActive(AdventureManager.GetTrainStageLevel() ~= -1)

    --特权
    local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(33)
    this.privilegePanel:SetActive(not isActive)
    Util.GetGameObject(this.privilegePanel, "desc"):GetComponent("Text").text = GetLanguageStrById(PrivilegeConfig.Desc)
    Util.GetGameObject(this.btnBuyPrivilege, "Text"):GetComponent("Text").text = MoneyUtil.GetMoney(PrivilegeConfig.Price)
    local grid = Util.GetGameObject(this.privilegePanel, "grid")

    this.activatedPanel:SetActive(isActive)
    if isActive then
        local time = PrivilegeManager.GetPrivilegeLeftTimeById(33)
        Util.GetGameObject(this.activatedPanel, "time"):GetComponent("Text").text = string.format(GetLanguageStrById(10930),  GetLeftTimeStrByDeltaTime(time))
    else
        Util.ClearChild(grid.transform)
        for index, value in ipairs(PrivilegeConfig.BaseReward) do
            local item = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            item:OnOpen(false, {value[1], value[2]}, 0.55)
        end
    end

    this.notTaskPanel:SetActive(AdventureManager.GetTrainStageLevel() == -1 and taskIsOpen)
end

-- 刷新道具数量
function this.RefreshItemNum()
    local fastMaxNum = PrivilegeManager.GetPrivilegeNumber(33)
    local fastBuyNum = PrivilegeManager.GetPrivilegeRemainValue(33)

    local str
    local freeTimes = AdventureManager.GetSandFastBattleCount()
    if freeTimes > 0 then
        str = string.format(GetLanguageStrById(12092).." <size=44>%s</size>", freeTimes)
    else
        if BagManager.GetItemCountById(105) > 0 then
            str = string.format(GetLanguageStrById(50359).." <size=44>%s</size>", BagManager.GetItemCountById(105))
        else
            str = string.format(GetLanguageStrById(50360).." <size=44>%s</size>", fastBuyNum.."/"..fastMaxNum)
        end
    end
    this.trainTime.text = str

    if not costItem then
        costItem = SubUIManager.Open(SubUIConfig.ItemView, this.costItem.transform)
    end
    if BagManager.GetItemCountById(105) > 0 then
        costItem:OnOpen(false, {105, 1}, 0.6)
    else
        costItem:OnOpen(false, {16, 50}, 0.6)
    end
    costItem.gameObject:SetActive(freeTimes <= 0)
end

-- 概率获得显示的道具
function this.InitRewardShow()
    local reward = {}
    local rewardLs = {}
    local r1 = fightLevelConfig[FightPointPassManager.curOpenFight].RewardShowMin
    local r2 = fightLevelConfig[FightPointPassManager.curOpenFight].RewardShow
    local open, extral = FightPointPassManager.GetExtralReward()
    for key, value in pairs(r1) do
        if not rewardLs[value[1]] then
            rewardLs[value[1]] = value
        end
    end
    for key, value in pairs(r2) do
        if not rewardLs[value[1]] then
            rewardLs[value[1]] = value
        end
    end
    for key, value in pairs(rewardLs) do
        reward[#reward + 1] = value
    end
    -- for i = 1, #r1 do
    --     reward[#reward + 1] = r1[i]
    -- end

    -- if r2 then
    --     for j = 1, #r2 do
    --         reward[#reward + 1] = r2[j]
    --     end
    -- end

    if open > 0 then
        for m = 1, #extral do
            reward[#reward + 1] = extral[m]
        end
    end

    if #reward > 1 then
        table.sort(reward, function (a, b)
            if ItemConfig[a[1]].Quantity == ItemConfig[b[1]].Quantity then
                return a[1] < b[1]
            else
                return ItemConfig[a[1]].Quantity > ItemConfig[b[1]].Quantity
            end
        end)
    end

    if AdventureManager.GetTrainStageLevel() == -1 and ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.QuickTrain) then
        for i = 1, 35 do
            if not itemList2[i] then
                itemList2[i] = newObjToParent(this.notTaskItem, this.notTaskGrid)
            end
            if reward[i] then
                local item = ItemConfig[reward[i][1]]
                Util.GetGameObject(itemList2[i], "item"):SetActive(true)
                Util.GetGameObject(itemList2[i], "item"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(item.Quantity))
                Util.GetGameObject(itemList2[i], "item/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(item.ResourceID))
            else
                Util.GetGameObject(itemList2[i], "item"):SetActive(false)
            end
        end
        return
    end
    for k = 1, #reward do
        if not itemList[k] then
            itemList[k] = SubUIManager.Open(SubUIConfig.ItemView, this.itemGrid.transform)
        end
        local item = {}
        local itemId = reward[k][1]
        item[#item + 1] = itemId
        item[#item + 1] = 0
        itemList[k]:OnOpen(false, item, 0.65)
    end
end

-- 刷新任务
function this.RefreshTask()
    if AdventureManager.GetTrainStageLevel() == -1 then
        return
    elseif not ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.QuickTrain) then
        return
    end
    finishNum = 0
    local taskConfig = ConfigManager.GetConfigDataByKey(ConfigName.TrainTask, "Level", AdventureManager.GetTrainStageLevel())
    for i = 1, #taskConfig.TaskID do
        local taskData = TaskConfig[taskConfig.TaskID[i]]
        local task = Util.GetGameObject(this.taskPanel, "task"..i)
        local severData = TaskManager.GetTypeTaskInfo(TaskTypeDef.Train, taskData.Id)
        if severData == nil then
            break
        end
        if not taskItem[i] then
            taskItem[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(task, "pos").transform)
        end
        taskItem[i]:OnOpen(false, taskData.Reward[1], 0.7)
        taskItem[i]:SetCorner(5, severData.state == 1)
        Util.GetGameObject(task, "desc"):GetComponent("Text").text = GetLanguageStrById(taskData.Desc)
        Util.GetGameObject(task, "Text"):GetComponent("Text").text = string.format("( %s/%s )", severData.progress, taskData.TaskValue[2][1])
        Util.GetGameObject(task, "mask"):SetActive(severData.state == 2)
        Util.GetGameObject(task, "btn/redpoint"):SetActive(severData.state == 1)
        if severData.state == 0 then
            Util.GetGameObject(task, "btn/Text"):GetComponent("Text").text = GetLanguageStrById(10023)
        elseif severData.state == 1 then
            Util.GetGameObject(task, "btn/Text"):GetComponent("Text").text = GetLanguageStrById(10022)
        elseif severData.state == 2 then
            finishNum = finishNum + 1
            Util.GetGameObject(task, "btn/Text"):GetComponent("Text").text = GetLanguageStrById(10350)
        end
        Util.AddOnceClick(Util.GetGameObject(task, "btn"), function ()
            if severData.state == 0 and taskData.Jump then
                local jumpSData = JumpConfig[taskData.Jump[1]]
                if jumpSData and jumpSData.Type == 62 then--公会副本
                    if not MyGuildManager.CheckGuildExitCdTime(true) then return end
                    if PlayerManager.familyId == 0 then
                        UIManager.OpenPanel(UIName.GuildFindPopup)
                    else
                        if UIManager.IsOpen(UIName.GuildMainCityPanel) then
                            UIManager.OpenPanel(UIName.GuildTranscriptMainPopup)
                        else
                            MyGuildManager.InitAllData(function()
                                UIManager.OpenPanel(UIName.GuildMainCityPanel)
                                UIManager.OpenPanel(UIName.GuildTranscriptMainPopup)
                            end)
                        end
                    end
                    return
                end

                JumpManager.GoJump(taskData.Jump[1])
            elseif severData.state == 1 then
                NetManager.TakeMissionRewardRequest(TaskTypeDef.Train, taskData.Id, function(msg)
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                        this:OnShow()
                        Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.TrainTask)
                    end)
                end)
            end
        end)
    end

    for i = 1, #stageItem do
        stageItem[i].gameObject:SetActive(false)
    end

    --阶段奖励
    for i = 1, #taskConfig.LevelReward do
        if not stageItem[i] then
            stageItem[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.taskPanel, "reward").transform)
        end
        stageItem[i]:OnOpen(false, taskConfig.LevelReward[i], 0.7)
        stageItem[i]:SetCorner(5, finishNum >= 3)
        stageItem[i].gameObject:SetActive(true)
    end

    Util.SetGray(this.btnReceive, not (finishNum >= 3))
end

-- 训练
function this.Train()
    FightPointPassManager.oldLevel = PlayerManager.level
    local maxNeed = ConfigManager.GetConfigData(ConfigName.PlayerLevelConfig, PlayerManager.level).MazeTreasureMax--最大持有道具数量
    local curNeed = BagManager.GetItemCountById(FindTreasureManager.materialItemId)
    local itemName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, FindTreasureManager.materialItemId).Name)
    local str = string.format(GetLanguageStrById(10562).."%s"..GetLanguageStrById(10563).."%s"..GetLanguageStrById(10564), curNeed.."/"..maxNeed, itemName)
    local state = AdventureManager.GetSandFastBattleCount() <= 0 and BagManager.GetItemCountById(105) <= 0
    
    local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "mazeTreasureMax")
    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
    if curNeed >= maxNeed and isPopUp ~= currentTime then
        MsgPanel.ShowTwo(str, nil, function(isShow)
            if isShow then
                local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .."mazeTreasureMax", currentTime)
            end
            AdventureManager.GetAventureRewardRequest(1, 0, state, true, function(msg)
                this.ShowReward(msg)
                this.RefreshItemNum()
            end)
        end,nil,nil,nil,true)
    else
        AdventureManager.GetAventureRewardRequest(1, 0, state, true, function(msg)
            this.ShowReward(msg)
            this.RefreshItemNum()
        end)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.TrainTask)
    CheckRedPointStatus(RedPointType.QuickTrain)
end

function this.ShowReward(msg)
    local drop = {}
    local normalDrop = msg.Drop
    local randDrop = msg.randomDrop

    this.AddDrop(drop, normalDrop)
    this.AddDrop(drop, randDrop)

    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function() end, 1)
end

function this.AddDrop(drop, addDrop)
    if not drop then
        drop = {}
    end
    if not drop.itemlist then
        drop.itemlist = {}
    end
    for _, data in ipairs(addDrop.itemlist) do
        table.insert(drop.itemlist, data)
    end

    if not drop.equipId then
        drop.equipId = {}
    end
    for _, data in ipairs(addDrop.equipId) do
        table.insert(drop.equipId, data)
    end

    if not drop.Hero then
        drop.Hero = {}
    end
    for _, data in ipairs(addDrop.Hero) do
        table.insert(drop.Hero, data)
    end

    -- if not drop.especialEquipId then
    --     drop.especialEquipId = {}
    -- end
    -- for _, data in ipairs(addDrop.especialEquipId) do
    --     table.insert(drop.soulEquip, data)
    -- end

    if not drop.soulEquip then
        drop.soulEquip = {}
    end
    for _, data in ipairs(addDrop.soulEquip) do
        table.insert(drop.soulEquip, data)
    end
    if not drop.plan then
        drop.plan = {}
    end
    for _, data in ipairs(addDrop.plan) do
        table.insert(drop.plan, data)
    end
    return drop
end

return this