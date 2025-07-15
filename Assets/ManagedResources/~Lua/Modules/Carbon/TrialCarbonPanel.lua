require("Base/BasePanel")
TrialCarbonPanel = Inherit(BasePanel)
local this = TrialCarbonPanel
local trialDataConfig = ConfigManager.GetConfig(ConfigName.TrialConfig)
local TrialConfig = ConfigManager.GetConfig(ConfigName.TrialConfig)
local itemListShowId = {}
-- 副本难度
local carbonType
local jumpCarbonId = 0
local _PanelType = {
    [1] = PanelType.FixforDan,
    [2] = PanelType.FixforDan,
    [3] = PanelType.EliteCarbon
}
--初始化组件（用于子类重写）
function TrialCarbonPanel:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    -- 显示货币
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
    --奖励显示
    this.trialCopy = Util.GetGameObject(self.gameObject, "trialCopy")
    this.gridContent = Util.GetGameObject(self.gameObject, "trialCopy/content/scrollRect/grid")
    this.currentPlies = Util.GetGameObject(self.gameObject, "trialCopy/content/IconBg/Text"):GetComponent("Text")
    this.currentPliess = Util.GetGameObject(self.gameObject, "trialCopy/content/IconBg/Text (1)"):GetComponent("Text")
    this.currentPliesThird = Util.GetGameObject(self.gameObject, "trialCopy/content/IconBg/Text (2)"):GetComponent("Text")
    this.historyMaxPlies = Util.GetGameObject(self.gameObject, "trialCopy/content/historyMaxText"):GetComponent("Text")
    this.canResetTimes = Util.GetGameObject(self.gameObject, "trialCopy/content/resetTimes"):GetComponent("Text")
    this.enterBtn = Util.GetGameObject(self.gameObject, "trialCopy/content/enterBtn")
    this.shopBtn = Util.GetGameObject(self.gameObject, "trialCopy/content/shopBtn")
    this.shopNum = Util.GetGameObject(self.gameObject, "trialCopy/content/shopBtn/Text")
    this.wipeOutBtn = Util.GetGameObject(self.gameObject, "trialCopy/content/wipeOutBtn")
    this.resetBtn = Util.GetGameObject(self.gameObject, "trialCopy/content/resetBtn")
    this.sureResetBtn = Util.GetGameObject(self.gameObject, "trialCopy/resetPanel/sureBtn")
    -- 请求排行
    this.btnTrailRank = Util.GetGameObject(self.gameObject, "trialCopy/btnRank")
    -- 试炼副本层数奖励
    this.btnGetReward = Util.GetGameObject(self.gameObject, "trialCopy/btnGetReward")
    --奖励红点
    this.levelRewardPoint = Util.GetGameObject(this.btnGetReward, "redPoint")
end


--绑定事件（用于子类重写）
function TrialCarbonPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        ClearRedPointObject(RedPointType.EpicExplore_GetReward)
        -- !!!! PS: 这里必须是主动打开副本选择界面，从地图中返回时，这个界面的上一级是地图界面，
        --  如果只是关闭自己，则会打开地图界面，不会打开副本选择界面，导致报错
        PlayerManager.carbonType = 1
        UIManager.OpenPanel(UIName.CarbonTypePanelV2)
        CallBackOnPanelOpen(UIName.CarbonTypePanelV2, function()
            UIManager.ClosePanel(UIName.TrialCarbonPanel)
        end)

    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Trial,this.helpPosition.x,this.helpPosition.y)
    end)
    -- 购买次数按钮
    Util.AddClick(this.btnBuy, this.RequestBuyChanllengeCount)

    ---试炼副本相关事件监听------------------------------------------------------------------------------------

    --进入试炼副本
    Util.AddClick(this.enterBtn, function()
        local curMapId = trialDataConfig[MapTrialManager.curTowerLevel].MapId
        -- UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.CARBON, curMapId)
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CARBON, curMapId)
    end)
    --重置炼狱副本
    Util.AddClick(this.resetBtn, function()
        if (MapTrialManager.resetCount > 0) then
            UIManager.OpenPanel(UIName.TrialResetPopup, function()
                this:OnTrialCopyData()
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10380)
        end
    end)
    -- 试炼商店按钮
    Util.AddClick(this.shopBtn, function()
        if not ShopManager.IsActive(SHOP_TYPE.TRIAL_SHOP) then
            PopupTipPanel.ShowTipByLanguageId(10381)
            return
        end
        UIManager.OpenPanel(UIName.MapShopPanel, SHOP_TYPE.TRIAL_SHOP)
    end)
    -- 请求试炼副本排行
    Util.AddClick(this.btnTrailRank, function()
        UIManager.OpenPanel(UIName.CarbonScoreSortPanel, 1)
    end)
    Util.AddClick(this.btnGetReward, function()
        UIManager.OpenPanel(UIName.EliteCarbonAchievePanel, 100, false, 2)
    end)
    BindRedPointObject(RedPointType.EpicExplore_GetReward, this.levelRewardPoint)

end


-- 请求购买挑战次数
function this.RequestBuyChanllengeCount()
    UIManager.OpenPanel(UIName.CarbonBuyCountPopup, 1)
end

--添加事件监听（用于子类重写）
function TrialCarbonPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Map.OnRefreshStarReward, this.RefreshRewardShow)
    Game.GlobalEvent:AddEvent(GameEvent.Carbon.RefreshCarbonData, this.OnTrialCopyData)
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshRedpot)
end

--移除事件监听（用于子类重写）
function TrialCarbonPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.OnRefreshStarReward, this.RefreshRewardShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Carbon.RefreshCarbonData, this.OnTrialCopyData)
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshRedpot)
end

--界面打开时调用（用于子类重写）
function TrialCarbonPanel:OnOpen(_jumpCarbonId)
    if _jumpCarbonId then
        jumpCarbonId = _jumpCarbonId
    else
        jumpCarbonId = 0
    end
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = _PanelType[CarbonManager.difficulty] })
end

function TrialCarbonPanel:OnShow()
        carbonType = 2
        this.trialCopy:SetActive(true)
        this.OnTrialCopyData()
        -- 从试炼副本出来时，检测一下红点，看看是否有奖励
        CheckRedPointStatus(RedPointType.EpicExplore_GetReward)


    --页面跳转，调节Item显示位置
    if jumpCarbonId > 0 then
        this.SetGridPosY()
    elseif jumpCarbonId < 0 then
        jumpCarbonId = CarbonManager.NeedLockId(jumpCarbonId,carbonType)
        this.SetGridPosY()
    end
end

--试炼副本数据显示
function TrialCarbonPanel:OnTrialCopyData()
    this:IsCanShowReset()
    this:InitShopBtnShow()
    if (MapTrialManager.curTowerLevel < 10) then
        this.currentPlies.text = MapTrialManager.curTowerLevel
        this.currentPliess.text = ""
        this.currentPliesThird.text=""
    elseif (MapTrialManager.curTowerLevel >= 10 and MapTrialManager.curTowerLevel < 100) then
        this.currentPlies.text = ""
        this.currentPliess.text = MapTrialManager.curTowerLevel
        this.currentPliesThird.text=""
    elseif(MapTrialManager.curTowerLevel >= 100) then
        this.currentPlies.text = ""
        this.currentPliess.text = ""
        this.currentPliesThird.text=MapTrialManager.curTowerLevel
    end
    this.historyMaxPlies.text = MapTrialManager.highestLevel
    this.canResetTimes.text = GetLanguageStrById(10382) .. string.format("<color=#EE1111>%s</color>", MapTrialManager.resetCount) .. GetLanguageStrById(10054)
    Util.ClearChild(this.gridContent.transform)
    local isCanInsert = true
    for k, v in ConfigPairs(TrialConfig) do
        if (v.Id <= MapTrialManager.curTowerLevel) then
            for i, n in pairs(v.RewardShow) do
                for j, m in pairs(itemListShowId) do
                    if (n == m) then
                        isCanInsert = false
                    end
                end
                if (isCanInsert == true) then
                    table.insert(itemListShowId, n)
                    isCanInsert = true
                end
            end
        end
    end
    for i, v in pairs(itemListShowId) do
        local itemdata = {}
        table.insert(itemdata, itemListShowId[i])
        table.insert(itemdata, 0)
        local view = SubUIManager.Open(SubUIConfig.ItemView, this.gridContent.transform)
        view:OnOpen(false, itemdata, 1.1)
    end
end

--试炼副本重置按钮显示隐藏控制
function TrialCarbonPanel:IsCanShowReset()
    if (MapTrialManager.isCanReset == 1) then
        this.resetBtn:SetActive(true)
        this.enterBtn:SetActive(false)
    else
        this.resetBtn:SetActive(false)
        this.enterBtn:SetActive(true)
    end
end

-- 刷新试炼按钮的显示
function TrialCarbonPanel:InitShopBtnShow()
    local shopData = ShopManager.GetShopDataByType(SHOP_TYPE.TRIAL_SHOP)
    if not shopData or #shopData.storeItem <= 0 then
        this.shopBtn:SetActive(false)
        return
    end
    -- 获取可购买的商品数量
    local itemNum = 0
    for _, item in ipairs(shopData.storeItem) do
        local limitCount = ShopManager.GetShopItemLimitBuyCount(item.id)
        if limitCount == -1 or limitCount - item.buyNum > 0 then
            itemNum = itemNum + 1
        end
    end
    this.shopBtn:SetActive(true)
    this.shopNum:GetComponent("Text").text = itemNum
end


-- 刷新红点显示
function this.RefreshRedpot()
    --for mapId, redpot in pairs(this.redpotList) do
    --    redpot:SetActive(CarbonManager.CheckEliteCarbonRedpot(mapId))
    --end
end


--界面关闭时调用（用于子类重写）
function TrialCarbonPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function TrialCarbonPanel:OnDestroy()

    SubUIManager.Close(this.UpView)
end



function this.SetGridPosY()
    local num = jumpCarbonId % 100
    this.ScrollView:SetIndex(num)
end

return TrialCarbonPanel