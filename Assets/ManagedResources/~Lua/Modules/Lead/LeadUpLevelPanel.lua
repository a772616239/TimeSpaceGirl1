require("Base/BasePanel")
LeadUpLevelPanel = Inherit(BasePanel)
local this = LeadUpLevelPanel
local curSelectHeroList = {}--选择消耗的英雄列表
local scrollItem = {}
local isClose = false

--初始化组件（用于子类重写）
function LeadUpLevelPanel:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")

    this.cur = Util.GetGameObject(this.gameObject, "cur")
    this.next = Util.GetGameObject(this.gameObject, "next")

    this.consume = Util.GetGameObject(this.gameObject, "consume")--消耗
    this.num = Util.GetGameObject(this.consume, "num"):GetComponent("Text")

    this.scroll = Util.GetGameObject(this.gameObject, "scroll")
    this.prefab = Util.GetGameObject(this.gameObject, "prefab")
    local v2 = this.scroll.transform.rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 5, Vector2.New(5, 5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    this.btnCancel = Util.GetGameObject(this.gameObject, "btnCancel")
    this.btnUpLv = Util.GetGameObject(this.gameObject, "btnUpLv")
end

--绑定事件（用于子类重写）
function LeadUpLevelPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnCancel, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnUpLv, function ()
        local lv, maxLv = AircraftCarrierManager.GetMaxRresearchLv()
        if type(maxLv) == "string" then
            PopupTipPanel.ShowTipByLanguageId(11993)
            return
        end
        local heroList = {}
        for k, v in pairs(curSelectHeroList) do
            table.insert(heroList, v.dynamicId)
        end
        local config = AircraftCarrierManager.GetRresearchLvUpData()
        if #heroList < config.Cost[2] then
            PopupTipPanel.ShowTipByLanguageId(12655)
            return
        end
        local vipLv = VipManager.GetVipLevel()
        if vipLv < config.VipUnlock then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11520), config.VipUnlock))
            return
        end
        AircraftCarrierManager.RresearchLvUp(heroList, function ()
            local grid = Util.GetGameObject(this.ScrollView.gameObject, "grid")
            for i = 1, grid.transform.childCount do
                local choose = Util.GetGameObject(grid.transform:GetChild(i-1), "choose")
                if choose.activeSelf then
                    choose:SetActive(false)
                end
            end
            curSelectHeroList = {}
            if type(AircraftCarrierManager.GetMaxRresearchLv()) == "string" then
                PopupTipPanel.ShowTipByLanguageId(11960)
                self:ClosePanel()
            else
                this:OnShow()
            end
        end)
    end)
end

--添加事件监听（用于子类重写）
function LeadUpLevelPanel:AddListener()
end

--移除事件监听（用于子类重写）
function LeadUpLevelPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LeadUpLevelPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeadUpLevelPanel:OnShow()
    this.SetSpeed()
    this.SetConsume()
    this.SetScroll()
end

--界面关闭时调用（用于子类重写）
function LeadUpLevelPanel:OnClose()
    curSelectHeroList = {}
    isClose = true
end

--界面销毁时调用（用于子类重写）
function LeadUpLevelPanel:OnDestroy()
    curSelectHeroList = {}
    scrollItem = {}
end

--设置速度信息
function this.SetSpeed()
    local lv, nextLv, speed, nextSpeed = AircraftCarrierManager.GetMaxRresearchLv()
    Util.GetGameObject(this.cur, "lv/Text"):GetComponent("Text").text = "Lv"..lv
    Util.GetGameObject(this.cur, "speed"):GetComponent("Text").text = string.format(GetLanguageStrById(22539), speed)
    Util.GetGameObject(this.next, "lv/Text"):GetComponent("Text").text = "Lv"..nextLv
    Util.GetGameObject(this.next, "speed"):GetComponent("Text").text = string.format(GetLanguageStrById(22539), nextSpeed)
end

--设置消耗
function this.SetConsume()
    local frame = Util.GetGameObject(this.consume, "item/frame"):GetComponent("Image")
    local icon = Util.GetGameObject(this.consume, "item/icon"):GetComponent("Image")
    local starGrid = Util.GetGameObject(this.consume, "item/starGrid")

    local config, data = AircraftCarrierManager.GetRresearchLvUpData()
    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(nil, data.StarLimit))
    icon.sprite = Util.LoadSprite(GetNoTargetHero(data.StarLimit))
    this.num.text = GetNumUnenoughColor(LengthOfTable(curSelectHeroList), config.Cost[2])
    SetHeroStars(starGrid, data.StarLimit)
end

function this.SetScroll()
    local config, data = AircraftCarrierManager.GetRresearchLvUpData()
    local allHeros = HeroManager.GetAllHeroDatasAndZero()
    local allData = {}
    for i, v in ipairs(allHeros) do
        local isIn = true
        for n, w in pairs(FormationManager.formationList) do
            for m = 1, #w.teamHeroInfos do
                if v.dynamicId == w.teamHeroInfos[m].heroId then
                    isIn = false
                end
            end
        end
        if v.star ~= data.StarLimit and data.StarLimit ~= 0 then -- 0全部进入
            isIn = false
        end
        if v.lockState == 1 then
            isIn = false
        end
        if isIn then
            table.insert(allData, v)
        end
    end

    table.sort(allData, function(a, b)
        if a.heroConfig.Star == b.heroConfig.Star then
            if a.lv == b.lv then
                return a.id > b.id
            else
                return a.lv < b.lv
            end
        else
            return a.heroConfig.Star < b.heroConfig.Star
        end
    end)
    this.ScrollView:SetData(allData, function(index, go)
        this.SetScrollItem(go, allData[index], config.Cost[2])
    end)
end

function this.SetScrollItem(go, data, need)
    local pos = Util.GetGameObject(go, "pos")
    local choose = Util.GetGameObject(go, "choose")
    local btn = Util.GetGameObject(go, "btn")
    if not scrollItem[go] then
        scrollItem[go] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
    end
    scrollItem[go]:OnOpen(false, {data.heroConfig.Id, 1}, 0.85)
    local config, upData = AircraftCarrierManager.GetRresearchLvUpData()
    scrollItem[go]:SetCorner(6, true, {star = upData.StarLimit, lv = data.lv})
    if isClose then
        choose:SetActive(false)
    end
    Util.AddOnceClick(btn, function ()
        if curSelectHeroList[data.dynamicId] then
            choose:SetActive(false)
            curSelectHeroList[data.dynamicId] = nil
            this.num.text = GetNumUnenoughColor(LengthOfTable(curSelectHeroList), need)
            return
        end
        if LengthOfTable(curSelectHeroList) >= need then
            PopupTipPanel.ShowTipByLanguageId(10660)
            return
        end
        curSelectHeroList[data.dynamicId] = data
        choose:SetActive(true)
        this.num.text = GetNumUnenoughColor(LengthOfTable(curSelectHeroList), need)
    end)
end

return LeadUpLevelPanel