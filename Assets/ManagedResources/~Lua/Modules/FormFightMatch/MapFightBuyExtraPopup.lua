require("Base/BasePanel")
local MapFightBuyExtraPopup = Inherit(BasePanel)
local this = MapFightBuyExtraPopup

local _title = GetLanguageStrById(10746)
local _tip1 = GetLanguageStrById(10747)
local _tip2 = GetLanguageStrById(10748)
local _btnTip = GetLanguageStrById(10749)

local nowRewardItem = {}
local otherRewardItem = {}
--初始化组件（用于子类重写）
function MapFightBuyExtraPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "tipImage/btnClose")
    this.btnConfirm = Util.GetGameObject(self.transform, "tipImage/btnCreate")

    this.costIcon = Util.GetGameObject(this.btnConfirm, "icon"):GetComponent("Image")
    this.costValue = Util.GetGameObject(this.btnConfirm, "value"):GetComponent("Text")

    this.tip1 = Util.GetGameObject(self.transform, "tipImage/Scroll/Viewport/Content/tip1"):GetComponent("Text")
    this.tip2 = Util.GetGameObject(self.transform, "tipImage/Scroll/Viewport/Content/tip2"):GetComponent("Text")
    this.box1 = Util.GetGameObject(self.transform, "tipImage/Scroll/Viewport/Content/box1")
    this.box2 = Util.GetGameObject(self.transform, "tipImage/Scroll/Viewport/Content/box2")
end

--绑定事件（用于子类重写）
function MapFightBuyExtraPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    Util.AddClick(this.btnConfirm, function()
        local BloodyBattleSetting = ConfigManager.GetConfigData(ConfigName.BloodyBattleSetting, 1)
        local costId, costNum = BloodyBattleSetting.Price[1], BloodyBattleSetting.Price[2]
        local costName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, costId).Name)
        local str = string.format(GetLanguageStrById(10750), costNum, costName)
        MsgPanel.ShowTwo(str, function()end, function(isShow)
            MatchDataManager.RequestBuyExtraReward(function()
                this:ClosePanel()
                PopupTipPanel.ShowTipByLanguageId(10751)
            end)
        end)
    end)
end

--添加事件监听（用于子类重写）
function MapFightBuyExtraPopup:AddListener()
end

--移除事件监听（用于子类重写）
function MapFightBuyExtraPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function MapFightBuyExtraPopup:OnOpen(...)
    local datalist = ConfigManager.GetConfig(ConfigName.BloodyBattleTreasure)
    local curScore = MatchDataManager.GetRewardScore()
    local nowReward = {}
    local otherReward = {}
    for _, data in ConfigPairs(datalist) do
        local rewardList = curScore >= data.SeasonPass and nowReward or otherReward
        for _, item in ipairs(data.SeasonTokenReward) do
            local id, num = item[1], item[2]
            if not rewardList[id] then
                rewardList[id] = {id, 0}
            end
            rewardList[id][2] = rewardList[id][2] + num
        end
    end

    local rewardNum = 0
    for id, item in pairs(nowReward) do
        if not nowRewardItem[id] then
            nowRewardItem[id] = SubUIManager.Open(SubUIConfig.ItemView, this.box1.transform)
        end
        nowRewardItem[id]:OnOpen(false, item)
        rewardNum = rewardNum + 1
    end
    this.tip1.gameObject:SetActive(rewardNum ~= 0)

    rewardNum = 0
    for id, item in pairs(otherReward) do
        if not otherRewardItem[id] then
            otherRewardItem[id] = SubUIManager.Open(SubUIConfig.ItemView, this.box2.transform)
        end
        otherRewardItem[id]:OnOpen(false, item)
        rewardNum = rewardNum + 1
    end
    this.tip2.gameObject:SetActive(rewardNum ~= 0)

    -- 购买令牌消耗
    local BloodyBattleSetting = ConfigManager.GetConfigData(ConfigName.BloodyBattleSetting, 1)
    local costId, costNum = BloodyBattleSetting.Price[1], BloodyBattleSetting.Price[2]
    this.costIcon.sprite = SetIcon(costId)
    this.costValue.text = costNum
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MapFightBuyExtraPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function MapFightBuyExtraPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function MapFightBuyExtraPopup:OnDestroy()
    for _, item in pairs(nowRewardItem) do
        SubUIManager.Close(item)
    end
    nowRewardItem = {}
    for _, item in pairs(otherRewardItem) do
        SubUIManager.Close(item)
    end
    otherRewardItem = {}
end

return MapFightBuyExtraPopup