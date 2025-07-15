--[[
 * @ClassName TreasureOfSomebodyPanelV2
 * @Description 戒灵秘宝
 * @Date 2019/9/20 14:15
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
local TreasureOfSomebodyScorePageV2 = require("Modules/TreasureOfSomebody/TreasureOfSomebodyScorePageV2")
local TreasureOfSomebodyRewardPageV2 = require("Modules/TreasureOfSomebody/TreasureOfSomebodyRewardPageV2")

---@class TreasureOfSomebodyPanelV2
local TreasureOfSomebodyPanelV2 = quick_class("TreasureOfSomebodyPanelV2", BasePanel)

local PageContent = {
    None = -1,
    Score = 1,
    Reward = 2
}

function TreasureOfSomebodyPanelV2:InitComponent()
    self.btnBack = Util.GetGameObject(self.transform, "bg/btnBack")
    --topPart
    self.treasureBtn = Util.GetGameObject(self.transform, "bg/topBar/treasureBtn")
    self.treasureBtnRedPoint = Util.GetGameObject(self.treasureBtn, "redPoint")

    self.gainScoreBtn = Util.GetGameObject(self.transform,"bg/topBar/gainScoreBtn")
    self.gainScoreBtnRedPoint = Util.GetGameObject(self.gainScoreBtn, "redPoint")

    self.actTime = Util.GetGameObject(self.transform, "bg/topBar/actTime"):GetComponent("Text")
    self.extraScoreBox = Util.GetGameObject(self.transform, "bg/topBar/extraScoreBox")
    self.level = Util.GetGameObject(self.transform, "bg/topBar/levelBg/value"):GetComponent("Text")
    self.buyLevelBtn = Util.GetGameObject(self.transform, "bg/topBar/buyLevelBtn")
    self.progress = Util.GetGameObject(self.transform, "bg/topBar/progressbar/progress"):GetComponent("Image")
    self.progressValue = Util.GetGameObject(self.transform, "bg/topBar/progressbar/value"):GetComponent("Text")
    self.sorting=0

    self.pageContents = {
        ---ScorePart
        [PageContent.Score] = TreasureOfSomebodyScorePageV2.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_1")),
        ----RewardPart
        [PageContent.Reward] = TreasureOfSomebodyRewardPageV2.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_2"))
    }
    table.walk(self.pageContents, function(page)
        page:OnHide()
    end)
    self.pageSelect = PageContent.None

    self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft })
end

function TreasureOfSomebodyPanelV2:BindEvent()
    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.treasureBtn, function()
        self:OnTopBarBtnClicked(PageContent.Reward)
    end)
    Util.AddClick(self.gainScoreBtn, function()
        self:OnTopBarBtnClicked(PageContent.Score)
    end)
    Util.AddClick(self.extraScoreBox, function()
        self:OnExtraScoreBoxBtnClicked()
    end)
    Util.AddClick(self.buyLevelBtn, function()
        self:OnBuyLevelBtnClicked()
    end)
end

function TreasureOfSomebodyPanelV2:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityProgressStateChange, self.SetRewardRedPoint, self)
end

function TreasureOfSomebodyPanelV2:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityProgressStateChange, self.SetRewardRedPoint, self)
end

function TreasureOfSomebodyPanelV2:OnOpen(data)
    data = data and data or {}
    self.pageSelect = data.tabIndex and data.tabIndex or PageContent.Score
    self.extraParam = data.extraParam
    self.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.SoulCrystal })
end

function TreasureOfSomebodyPanelV2:OnShow()
    self:OnPageChanged(self.pageSelect)
    self:SetTopTitle()
    self:SetRewardRedPoint()
end

function TreasureOfSomebodyPanelV2:OnSortingOrderChange()
    Util.AddParticleSortLayer(Util.GetGameObject(self.transform, "bg/topBar/UI_effect_extraScoreBox/kuosan01"), self.sortingOrder-self.sorting)
    Util.AddParticleSortLayer(Util.GetGameObject(self.transform, "bg/topBar/UI_effect_extraScoreBox/lizi01"), self.sortingOrder-self.sorting)
    self.sorting=self.sortingOrder
end

function TreasureOfSomebodyPanelV2:OnClose()
    if self.pageSelect ~= PageContent.None then
        self.pageContents[self.pageSelect]:OnHide()
    end
end

function TreasureOfSomebodyPanelV2:OnDestroy()
    SubUIManager.Close(self.UpView)
    for _, pageInfo in ipairs(self.pageContents) do
        pageInfo:OnDestroy()
    end
end

function TreasureOfSomebodyPanelV2:OnTopBarBtnClicked(type)
    if self.pageSelect == type then
        return
    end
    self:OnPageChanged(type)
end

--戒灵秘宝 宝箱点击
function TreasureOfSomebodyPanelV2:OnExtraScoreBoxBtnClicked()
    if TreasureOfSomebodyManagerV2.hadBuyTreasure then
        PopupTipPanel.ShowTipByLanguageId(11992)
        return
    end
    UIManager.OpenPanel(UIName.UnlockExtraRewardPanel,5001, {
        callBack = function()
            if self.pageContents[PageContent.Reward] ~= nil then
                self.pageContents[PageContent.Reward]:RefreshTreasureBuy()
            end
        end
    })
end

function TreasureOfSomebodyPanelV2:OnBuyLevelBtnClicked()
    if TreasureOfSomebodyManagerV2.currentLv == TreasureOfSomebodyManagerV2.treasureMaxLv then
        PopupTipPanel.ShowTipByLanguageId(11993)
        return
    end
    UIManager.OpenPanel(UIName.BuyTreasureLevelPanel, {
        callBack = function()
            self:SetTreasureProgress()
            self:SetRewardRedPoint()
            if self.pageSelect == PageContent.Reward then
                self.pageContents[PageContent.Reward]:RefreshTreasureBuy()
            else
                if TreasureOfSomebodyManagerV2.currentLv == TreasureOfSomebodyManagerV2.treasureMaxLv then
                    self.pageContents[PageContent.Score]:MainPanelCallRefresh()
                end
            end
        end
    })
end

function TreasureOfSomebodyPanelV2:OnPageChanged(page)
    local oldSelect
    oldSelect, self.pageSelect = self.pageSelect, page
    if oldSelect ~= -1 then
        self.pageContents[oldSelect]:OnHide()
    end
    if self.extraParam then
        self.pageContents[self.pageSelect]:OnShow(self.extraParam)
        self.extraParam = nil
    else
        self.pageContents[self.pageSelect]:OnShow()
    end

    Util.SetGray(self.treasureBtn,page == PageContent.Reward)
    Util.SetGray(self.gainScoreBtn,page == PageContent.Score)
    -- self.treasureBtn:GetComponent("Image").color = page == PageContent.Reward and UIColor.GRAY or UIColor.WHITE
    -- self.gainScoreBtn:GetComponent("Image").color = page == PageContent.Score and UIColor.GRAY or UIColor.WHITE
end

function TreasureOfSomebodyPanelV2:SetTopTitle()
    local actInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.TreasureOfSomeBody)
    self.actTime.text = string.format(GetLanguageStrById(11994), self:GetTimeFormat(actInfo.startTime),
            self:GetTimeFormat(actInfo.endTime))
    self:SetTreasureProgress()
end

function TreasureOfSomebodyPanelV2:GetTimeFormat(actTime)
    local date = os.date("*t", actTime)
    return string.format(GetLanguageStrById(11995), date.month, date.day)
end

function TreasureOfSomebodyPanelV2:SetTreasureProgress()
    local currentLv = TreasureOfSomebodyManagerV2.currentLv
    self.level.text = currentLv
    if currentLv == TreasureOfSomebodyManagerV2.treasureMaxLv then
        self.progress.fillAmount = 1
        self.progressValue.text = GetLanguageStrById(11802)
    else
        local treasureConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.TreasureSunLongConfig,
                "ActivityId", TreasureOfSomebodyManagerV2.activityId, "Level", currentLv)
        self.progress.fillAmount = TreasureOfSomebodyManagerV2.GetTreasureScore() / treasureConfig.Integral[1][2]
        self.progressValue.text = string.format("%s/%s",
                TreasureOfSomebodyManagerV2.GetTreasureScore(), treasureConfig.Integral[1][2])
    end
end

function TreasureOfSomebodyPanelV2:SetRewardRedPoint()
    self.treasureBtnRedPoint:SetActive(TreasureOfSomebodyManagerV2.GetRewardPageRedPointStatus())
    self.gainScoreBtnRedPoint:SetActive(TreasureOfSomebodyManagerV2.GetTaskPageRedPointStatus())
end

return TreasureOfSomebodyPanelV2