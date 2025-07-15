require("Base/BasePanel")
HeroPreviewPanel = Inherit(BasePanel)
local this = HeroPreviewPanel
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

--Tab
local TabBox = require("Modules/Common/TabBox")
local _TabData = {
    [1] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_03", select = "cn2-X1_shouhu_biaoqian_xuanzhong", name = GetLanguageStrById(50185) },
    [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_03", select = "cn2-X1_shouhu_biaoqian_xuanzhong", name = GetLanguageStrById(11754) },
    [3] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_03", select = "cn2-X1_shouhu_biaoqian_xuanzhong", name = GetLanguageStrById(10352) }}
local _TabFontColor = { default = Color.New(255 / 255, 255 / 255, 255 / 255, 128/255),
                        select = Color.New(255 / 255, 255 / 255, 255 / 255, 1)}
--上一模块索引
local curIndex = 0
local weightCompute = false--是否是权重计算

local dataType = {
    [1] = PRE_REWARD_POOL_TYPE.RECRUIT,
    [2] = PRE_REWARD_POOL_TYPE.FRIEND,
    [3] = PRE_REWARD_POOL_TYPE.NORMAL,
    [4] = PRE_REWARD_POOL_TYPE.TIME_LIMITED,
    [5] = PRE_REWARD_POOL_TYPE.CARDACTIVITY,
}

function HeroPreviewPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "bg/btnBack")
    this.mask = Util.GetGameObject(self.transform, "mask")

    this.starScroll = Util.GetGameObject(self.transform,"bg/starScroll")
    this.campScroll = Util.GetGameObject(self.transform,"bg/campScroll")
    this.otherScroll = Util.GetGameObject(self.transform,"bg/otherScroll")
    this.turnTableScroll = Util.GetGameObject(self.transform,"bg/turnTableScroll")

    this.starGrid = Util.GetGameObject(self.transform,"bg/starScroll/Viewport/grid")--星级
    this.campGrid = Util.GetGameObject(self.transform, "bg/campScroll/Viewport/grid")--阵营
    this.otherGrid = Util.GetGameObject(self.transform, "bg/otherScroll/Viewport/grid")--其他
    this.turnTableGrid = Util.GetGameObject(self.transform, "bg/turnTableScroll/Viewport/grid")--转盘

    --预制
    this.heroBg = Util.GetGameObject(self.transform, "bg/pre")
    this.cardPre = Util.GetGameObject(self.gameObject, "bg/item")

    this.tabBox = Util.GetGameObject(self.gameObject, "bg/TabBox/grid")

    this.heroList = {[1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {}}
end

function HeroPreviewPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
end

function HeroPreviewPanel:AddListener()
end

function HeroPreviewPanel:RemoveListener()
end

function HeroPreviewPanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

--index:1 = 星级 | 2 = 阵营 | 3 = 其他  | 4 = 转盘
--isShowTab:是否显示TabBox
function HeroPreviewPanel:OnOpen(index, isShowTab)
    this.tabBox:SetActive(isShowTab)
    this.starScroll:SetActive(index == 1)
    this.campScroll:SetActive(index == 2)
    this.otherScroll:SetActive(index == 3)
    this.turnTableScroll:SetActive(index == 4)
    weightCompute = not isShowTab
    if index == 1 then
        if isShowTab then
            this.TabCtrl = TabBox.New()
            this.TabCtrl:SetTabAdapter(this.TabAdapter)
            this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
            this.TabCtrl:Init(this.tabBox, _TabData, 1)
        else
            this.SwitchView(4)
        end
    elseif index == 2 then
        if RecruitManager.isFirstEnterElementScroll then
            RecruitManager.isFirstEnterElementScroll = false
            for i, v in pairs(RecruitManager.previewElementData) do
                if v.Pool > 10 and v.Pool < 15 then
                    if v.ShowChance > 0 then
                        local bg = newObjToParent(this.heroBg, Util.GetGameObject(this.campGrid, "pool"..v.Pool).transform)
                        local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(bg, "pos").transform)
                        view:OnOpen(false, {v.Reward[1], v.Reward[2]}, 0.72)
                        Util.GetGameObject(bg, "probability"):GetComponent("Text").text = string.format("%.2f", v.ShowChance/100) .."%"
                        Util.GetGameObject(bg, "pos"):GetComponent("RectTransform").anchoredPosition3D = Vector3.New(0, 30, 0)
                    end
                end
            end
        end
    elseif index == 3 then
        this.CardActivity()
    elseif index == 4 then
        this.TurnTable()
    end
end

function HeroPreviewPanel:OnShow()
end
function HeroPreviewPanel:OnClose()
end

function HeroPreviewPanel:OnDestroy()
    RecruitManager.isFirstEnterElementScroll = true
    RecruitManager.isFirstEnterHeroScroll = true
    this.heroList = {}
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    tab:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end

--切换视图
function this.SwitchView(index)
    curIndex = index

    local weight = 0
    local allPoolData = RecruitManager.GetRewardPreviewData(dataType[curIndex])
    local poolData = {[1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {}}

    for i, v in ipairs(allPoolData) do
        if weightCompute then
            if v.Weight > 0 then
                local pool = itemConfig[v.Reward[1]].HeroStar[2]
                if pool > 0 and pool < 6 then
                    table.insert(poolData[pool], v)
                end
            end
        else
            if v.ShowChance > 0 then
                local pool = itemConfig[v.Reward[1]].HeroStar[2]
                if pool > 0 and pool < 6 then
                    table.insert(poolData[pool], v)
                end
            end
        end
    end

    for i, v in ipairs(allPoolData) do
        weight = v.Weight + weight
    end

    --隐藏不显示的预制
    for i = 1, #this.heroList do
        if #this.heroList[i] > #poolData[i]+1 then
            for j = #poolData[i]+1, #this.heroList[i] do
                this.heroList[i][j].transform.parent.parent.parent.gameObject:SetActive(false)
            end
        end
    end

    for pool = 1, #poolData do
        local parent = Util.GetGameObject(this.starGrid, "star"..pool)
        for i = 1, #poolData[pool] do
            local bg
            if not this.heroList[pool][i]then
                bg = newObjToParent(this.heroBg, parent.transform)
                this.heroList[pool][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(bg, "bg/pos").transform)
            else
                bg = this.heroList[pool][i].transform.parent.parent
            end
            this.heroList[pool][i]:OnOpen(false, {poolData[pool][i].Reward[1], poolData[pool][i].Reward[2]}, 0.85, false)
            local probability = Util.GetGameObject(bg, "probability"):GetComponent("Text")
            if  weightCompute then
                probability.text = string.format("%.2f", (poolData[pool][i].Weight/weight)*100) .."%"
            else
                probability.text = string.format("%.2f", poolData[pool][i].ShowChance/100) .."%"
            end
            Util.GetGameObject(bg, "pos"):GetComponent("RectTransform").anchoredPosition3D = Vector3.New(0, 15, 0)
            this.heroList[pool][i].transform.parent.parent.parent.gameObject:SetActive(true)
        end
    end

    if index == 1 or index == 4 then
        Util.GetGameObject(this.starGrid, "star1"):SetActive(false)
        Util.GetGameObject(this.starGrid, "star1num"):SetActive(false)
        Util.GetGameObject(this.starGrid, "star2"):SetActive(false)
        Util.GetGameObject(this.starGrid, "star2num"):SetActive(false)

    elseif index == 2 then
        Util.GetGameObject(this.starGrid, "star1"):SetActive(false)
        Util.GetGameObject(this.starGrid, "star1num"):SetActive(false)
        Util.GetGameObject(this.starGrid, "star2"):SetActive(true)
        Util.GetGameObject(this.starGrid, "star2num"):SetActive(true)
    else
        Util.GetGameObject(this.starGrid, "star1num"):SetActive(true)
        Util.GetGameObject(this.starGrid, "star1"):SetActive(true)
        Util.GetGameObject(this.starGrid, "star2num"):SetActive(true)
        Util.GetGameObject(this.starGrid, "star2"):SetActive(true)
    end
end

--卡牌主题活动
function this.CardActivity()
    local allPoolData = RecruitManager.GetRewardPreviewData(dataType[5])
    local poolData = {}
    local weight = 0

    for i, v in ipairs(allPoolData) do
        if weightCompute then
            if v.Weight > 0 then
                table.insert(poolData, v)
            end
        else
            if v.ShowChance > 0 then
                table.insert(poolData, v)
            end
        end
    end

    for i, v in ipairs(allPoolData) do
        weight = v.Weight + weight
    end

    Util.ClearChild(this.otherGrid.transform)
    for i = 1, #poolData do
        local bg = newObjToParent(this.heroBg, this.otherGrid.transform)
        local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(bg, "pos").transform)
        view:OnOpen(false, {poolData[i].Reward[1], poolData[i].Reward[2]}, 0.72)
        Util.GetGameObject(bg, "probability"):GetComponent("Text").text = string.format("%.2f", poolData[i].ShowChance/100) .."%"
        Util.GetGameObject(bg, "pos"):GetComponent("RectTransform").anchoredPosition3D = Vector3.New(0, 30, 0)
    end
end

--幸运轮盘
function this.TurnTable()
    local showData = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.LUCK_FIND)
    local normalData = {}
    local upperData = {}

    for i = 1, #showData do
        if showData[i].ActivityId == 30 then -- 幸运探宝
            normalData[#normalData + 1] = showData[i]
        elseif showData[i].ActivityId == 31 then
            upperData[#upperData + 1] = showData[i]
        end
    end

    Util.ClearChild(Util.GetGameObject(this.turnTableGrid, "normalPool").transform)
    for i = 1, #normalData do
        local bg = newObjToParent(this.heroBg, Util.GetGameObject(this.turnTableGrid, "normalPool").transform)
        local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(bg, "pos").transform)
        view:OnOpen(false, {normalData[i].Reward[1], normalData[i].Reward[2]}, 0.72)
        Util.GetGameObject(bg, "probability"):GetComponent("Text").text = string.format("<color=#EDB64C>%.2f</color>", normalData[i].ShowWeight).."%"
        Util.GetGameObject(bg, "pos"):GetComponent("RectTransform").anchoredPosition3D = Vector3.New(0, 30, 0)
    end
    Util.ClearChild(Util.GetGameObject(this.turnTableGrid, "upperPool").transform)
    for i = 1, #upperData do
        local bg = newObjToParent(this.heroBg, Util.GetGameObject(this.turnTableGrid, "upperPool").transform)
        local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(bg, "pos").transform)
        view:OnOpen(false, {upperData[i].Reward[1], upperData[i].Reward[2]}, 0.72)
        Util.GetGameObject(bg, "probability"):GetComponent("Text").text = string.format("<color=#EDB64C>%.2f</color>", upperData[i].ShowWeight).."%"
        Util.GetGameObject(bg, "pos"):GetComponent("RectTransform").anchoredPosition3D = Vector3.New(0, 30, 0)
    end
end

return HeroPreviewPanel