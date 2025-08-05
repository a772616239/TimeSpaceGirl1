--[[
 * @ClassName FirstRechargePanel
 * @Description 首充
 * @Date 2019/6/3 11:45
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
local DayRewardItem = require("Modules/FirstRecharge/DayRewardItem")

---@class FirstRechargePanel
local FirstRechargePanel = Inherit(BasePanel)
local this = FirstRechargePanel

local kMaxTab, kMaxDay = 2, 3
local TextColorDef = {
    [1] = Color.New(255 / 255, 255 / 255, 255 / 255, 76/255),
    [2] = Color.New(255 / 255, 255 / 255, 255 / 255, 204/255)
}
local orginLayer
local activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local thread = nil --协程
--显示英雄ID
local showHeroIDs = {
    10003,
    10019,
    10042,
}
local showHeroId = 10042
--当前显示英雄的下标
local showHeroIndex = 0

function FirstRechargePanel:InitComponent()
    orginLayer = 0

    self.hero = Util.GetGameObject(self.transform, "hero")
    this.lihui = Util.GetGameObject(self.hero.transform, "lihuis")
    this.oneLihui = Util.GetGameObject(self.hero.transform, "lihui")
    this.lihuiInfo = Util.GetGameObject(self.hero.transform, "lihuiInfo")
    this.name = Util.GetGameObject(this.lihuiInfo, "name"):GetComponent("Text")
    this.pro = Util.GetGameObject(this.lihuiInfo, "pro"):GetComponent("Image")

    self.closeBtn = Util.GetGameObject(self.transform, "closeBtn")
	this.Btnback = Util.GetGameObject(this.transform, "Btnback")

    self.tabs = {}
    self.selectTabs = {}
    self.tabTitles = {}
    self.tabRedPoint = {}
    for i = 1, kMaxTab do
        self.tabs[i] = Util.GetGameObject(self.transform, "frame/tabsContent/tabs_" .. i)
        self.selectTabs[i] = Util.GetGameObject(self.tabs[i], "selected")
        self.tabTitles[i] = Util.GetGameObject(self.tabs[i], "title"):GetComponent("Text")
        self.tabRedPoint[i] = Util.GetGameObject(self.tabs[i], "redPoint")
    end
    self.selectTabIndex = -1

    self.dayRewardList = {}
    for i = 1, kMaxDay do
        self.dayRewardList[i] = DayRewardItem.new(self,self.transform:Find("frame/rewardBg/rewardDay" .. i))
    end

    --bottomPart
    self.reChargeBtn = Util.GetGameObject(self.transform, "frame/rechargeBtn")
    self.reChargeTips = Util.GetGameObject(self.transform, "frame/tips"):GetComponent("Text")

    self.effect = Util.GetGameObject(self.transform, "frame/effect")
    -- effectAdapte(Util.GetGameObject(self.effect, "Partical/ziti mask (1)"))

    self.oneLihuiInfo = Util.GetGameObject(self.transform,"hero/oneLihuiInfo")
end

function FirstRechargePanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)
	Util.AddClick(this.Btnback, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.reChargeBtn, function()
        self:OnRechargeBtnClicked()
    end)
    for i = 1, kMaxTab do
        Util.AddClick(self.tabs[i], function()
            self:OnTabClicked(i)
        end)
    end
end

function FirstRechargePanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
    --特效穿透特殊处理
    for i = 1, #self.dayRewardList do
        self.dayRewardList[i]:OnSortingOrderChange(self.sortingOrder)
    end
end
local fun = nil
function FirstRechargePanel:OnOpen(context,_fun)
    context = context and context or {}
    self.selectTabIndex = context.tabIndex and context.tabIndex or 1
    fun = _fun
end

function FirstRechargePanel:OnShow()
    self:OnTabChanged(self.selectTabIndex)
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FirstRecharge)
    local AccumRecharge = 0
    for _, missInfo in pairs(activityInfo.mission) do
        if missInfo and missInfo.progress then
            AccumRecharge = missInfo.progress
        end
    end
    self.reChargeTips.text = string.format(GetLanguageStrById(10663), AccumRecharge/100)
    if AccumRecharge/1000 >= 100 then
        self.reChargeBtn:SetActive(false)
    else
        self.reChargeBtn:SetActive(true)
    end
    for i = 1, kMaxTab do
        self:SetTabRedPointStatus(i)
    end

    this.oneHeroData = ConfigManager.GetConfigData(ConfigName.HeroConfig,showHeroId)
    this.Onelive = LoadHerolive(this.oneHeroData,this.oneLihui.transform)

    Util.GetGameObject(self.oneLihuiInfo,"name"):GetComponent("Text").text = GetLanguageStrById(this.oneHeroData.ReadingName)
    Util.GetGameObject(self.oneLihuiInfo,"pro"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(this.oneHeroData.PropertyName))

    thread = coroutine.start(function ()
        for i = 1, 10, 0 do
            SetHeroData(GetHeroId())
        end
    end)
end

function SetHeroData(heroId)
    if this.liveNode then
        UnLoadHerolive(this.heroData, this.liveNode)
        Util.ClearChild(this.lihui.transform)
        this.liveNode = nil
    end
    this.heroData = ConfigManager.GetConfigData(ConfigName.HeroConfig,heroId)

    this.name.text = GetLanguageStrById(this.heroData.ReadingName)
    this.pro.sprite = Util.LoadSprite(GetProStrImageByProNum(this.heroData.PropertyName))

    this.liveNode = LoadHerolive(this.heroData, this.lihui.transform)
    
    local stopV3 = Vector3.New(this.heroData.Position[1], this.heroData.Position[2],0)
    local startV3 = Vector3.New(this.heroData.Position[1], this.heroData.Position[2],0)
    local endV3 = Vector3.New(this.heroData.Position[1], this.heroData.Position[2],0)

    startV3.x = 1000
    endV3.x = -1000

    DoTween.To(
        DG.Tweening.Core.DOGetter_UnityEngine_Vector3(
            function()
                return this.liveNode.transform.localPosition
            end
        ),
        DG.Tweening.Core.DOSetter_UnityEngine_Vector3(
            function(progress)
                this.liveNode.transform.localPosition = progress
            end
        ),
        stopV3,
        0.3
    ):SetEase(Ease.InQuad)
    coroutine.wait(3)
    DoTween.To(
        DG.Tweening.Core.DOGetter_UnityEngine_Vector3(
            function()
                return this.liveNode.transform.localPosition
            end
        ),
        DG.Tweening.Core.DOSetter_UnityEngine_Vector3(
            function(progress)
                this.liveNode.transform.localPosition = progress
            end
        ),
        endV3,
        0.3
    ):SetEase(Ease.InQuad)
    coroutine.wait(0.3)
end

function GetHeroId()
    showHeroIndex = showHeroIndex + 1
    if showHeroIndex > #showHeroIDs then
        showHeroIndex = 1
    end

    return showHeroIDs[showHeroIndex]
end

function FirstRechargePanel:OnTabClicked(index)
    if self.selectTabIndex == index then
        return
    end
    self:OnTabChanged(index)
end

function FirstRechargePanel:OnTabChanged(index)
    for i, select in ipairs(self.selectTabs) do
        select:SetActive(i == index)
    end
    for i, title in ipairs(self.tabTitles) do
        title.color = i == index and TextColorDef[2] or TextColorDef[1]
    end
    self:ShowContent(index)
    self.selectTabIndex = index
    this.oneLihui:SetActive(index == 1)
    --this.lihui:SetActive(index == 2)
    this.oneLihuiInfo:SetActive(index == 1)
    this.lihuiInfo:SetActive(index == 1)
    Log("OnTabClicked index:"..index)
end

function FirstRechargePanel:ShowContent(index)
    local tempData = {}
    for _, rewardInfo in ConfigPairs(activityRewardConfig) do
        if rewardInfo.ActivityId == ActivityTypeDef.FirstRecharge and
                rewardInfo.Values[1][1] == IndexValueDef[index] then
            table.insert(tempData, rewardInfo)
        end
    end

    for i, dayRewardItem in ipairs(self.dayRewardList) do
        dayRewardItem:SetValue(tempData[i],self.sortingOrder)
    end
end

function FirstRechargePanel:OnRechargeBtnClicked()
    self:ClosePanel()
    if not ShopManager.SetMainRechargeJump() then
        JumpManager.GoJump(36008)
    else
        -- UIManager.OpenPanel(UIName.MainRechargePanel, 1)
        JumpManager.GoJump(36006)
    end
end

function FirstRechargePanel:SetTabRedPointStatus(tabIndex)
    local redPointStatus = false
    if tabIndex == 1 then
        redPointStatus = redPointStatus or FirstRechargeManager.GetSixMoneyTabRedPointStatus()
    else
        redPointStatus = redPointStatus or FirstRechargeManager.GetHundredTabRedPointStatus()
    end
    self.tabRedPoint[tabIndex]:SetActive(redPointStatus)
end
--界面关闭时调用（用于子类重写）
function FirstRechargePanel:OnClose()
    if thread then
        coroutine.stop(thread)
        thread = nil
    end
    if fun then
        fun()
        fun = nil
    end
    if this.liveNode then
        UnLoadHerolive(this.heroData, this.liveNode)
        Util.ClearChild(this.lihui.transform)
        this.liveNode = nil
    end

    if this.Onelive then
        UnLoadHerolive(this.oneHeroData, this.Onelive)
        Util.ClearChild(this.oneLihui.transform)
        this.Onelive = nil
    end
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

return FirstRechargePanel