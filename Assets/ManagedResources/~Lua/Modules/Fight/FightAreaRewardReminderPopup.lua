require("Base/BasePanel")
local FightAreaRewardReminderPopup = Inherit(BasePanel)
local this = FightAreaRewardReminderPopup

local _RewardList = {}
--初始化组件（用于子类重写）
function FightAreaRewardReminderPopup:InitComponent()
    this.maskbg = Util.GetGameObject(self.transform, "maskbg")
	this.btnBack = Util.GetGameObject(self.transform, "mask")
    -- this.closeBtn = Util.GetGameObject(self.transform, "Reminder/Bg/closeBtn")
    this.time = Util.GetGameObject(self.transform, "Reminder/Bg/info/time"):GetComponent("Text")
   
    this.rewardBox = Util.GetGameObject(self.transform, "Reminder/Bg/RewardScroll/Viewport/Content")
    this.getBtn = Util.GetGameObject(self.transform, "Reminder/Bg/Gobtn")

end

--绑定事件（用于子类重写）
function FightAreaRewardReminderPopup:BindEvent()
    Util.AddClick(this.maskbg, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    -- Util.AddClick(this.closeBtn, function()
    --     PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    --     this:ClosePanel()
    -- end)
    Util.AddClick(this.getBtn, function()
        local mazeTreasureMax = ConfigManager.GetConfigData(ConfigName.PlayerLevelConfig,PlayerManager.level).MazeTreasureMax
        local str = GetLanguageStrById(10562)..BagManager.GetItemCountById(FindTreasureManager.materialItemId) .."/"..mazeTreasureMax ..
                GetLanguageStrById(10563).. GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, FindTreasureManager.materialItemId).Name) ..
                GetLanguageStrById(10566)
        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "mazeTreasureMax")
        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
        if BagManager.GetItemCountById(FindTreasureManager.materialItemId) >= mazeTreasureMax    and isPopUp ~= currentTime then
            MsgPanel.ShowTwo(str, nil, function(isShow)
                if (isShow) then
                    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                    RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .."mazeTreasureMax", currentTime)
                end
                this.GetBtnClickEvent()
            end,nil,nil,nil,true)
        else
            this.GetBtnClickEvent()
        end
    end)
end

function this.GetBtnClickEvent()
    NetManager.GetAventureRewardRequest(function(msg)
        if AdventureManager.stateTime >= AdventureManager.adventureRefresh then
            if AdventureManager.stateTime >= AdventureManager.adventureBoxShow[2] then
                AdventureManager.stateTime = AdventureManager.adventureBoxShow[2]
            end
            AdventureManager.stateTime = AdventureManager.stateTime % AdventureManager.adventureRefresh
            CheckRedPointStatus(RedPointType.SecretTer_MaxBoxReward)
            Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnRefeshBoxRewardShow)
        end

        this:ClosePanel()
        local drop = {}
        drop = this.AddDrop(drop, msg.Drop)
        drop = this.AddDrop(drop, msg.randomDrop)

        UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function() this:ClosePanel() end, 1, false)
    end, 2)
end
--
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

--添加事件监听（用于子类重写）
function FightAreaRewardReminderPopup:AddListener()
end

--移除事件监听（用于子类重写）
function FightAreaRewardReminderPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function FightAreaRewardReminderPopup:OnOpen(...)
    local curFightId = FightPointPassManager.GetCurFightId()
    local config = ConfigManager.GetConfigData(ConfigName.MainLevelConfig, curFightId)
    if not config then return end

    local curTime = AdventureManager.stateTime
    local maxTime = AdventureManager.adventureOffline * 3600
    if curTime > maxTime then
        curTime = maxTime
    end
    this.time.text = TimeToHMS(curTime)
    local index = 0
  
    local randReward = {}
    if config.RewardShow then
        for j = 1, #config.RewardShow do
            randReward[#randReward + 1] = config.RewardShow[j]
        end
    end

    local open, extral = FightPointPassManager.GetExtralReward()
    if open > 0 then
        for k = 1, #extral do
            randReward[#randReward + 1] = extral[k]
        end
    end

    for _, reward in ipairs(randReward) do
        index = index + 1
        if not _RewardList[index] then
            _RewardList[index] = SubUIManager.Open(SubUIConfig.ItemView, this.rewardBox.transform)
        end
        local rdata = {reward[1], 0}
        _RewardList[index]:OnOpen(false, rdata, 0.8, true)
    end
    AdventureManager.fightAreaMax=false
end

function this.GetPlayerLevelInfo(addExp)
    local curLevel = PlayerManager.level
    local curExp = PlayerManager.exp
    local maxExp = 0
    local isUp = false

    local function Add()
        local curLevelConfig = ConfigManager.GetConfigData(ConfigName.PlayerLevelConfig, curLevel)
        if not curLevelConfig then return end
        maxExp = curLevelConfig.Exp
        curExp = curExp + addExp
        if curExp >= maxExp then
            addExp = curExp - maxExp
            curExp = 0
            curLevel = curLevel + 1
            isUp = true
            Add()
        end
    end
    Add()
    return curLevel, curExp, maxExp, isUp
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightAreaRewardReminderPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function FightAreaRewardReminderPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function FightAreaRewardReminderPopup:OnDestroy()
    for _, node in ipairs(_RewardList) do
        SubUIManager.Close(node)
    end
    _RewardList = {}
end

return FightAreaRewardReminderPopup