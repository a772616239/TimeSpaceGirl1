require("Base/BasePanel")
RewardPreviewPopup = Inherit(BasePanel)
local this = RewardPreviewPopup

-- 分类个数
local typeNum = 0
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

--初始化组件（用于子类重写）
function RewardPreviewPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.starScroll = Util.GetGameObject(self.gameObject, "bg/starScroll")
    this.campScroll = Util.GetGameObject(self.gameObject, "bg/campScroll")
    this.otherScroll = Util.GetGameObject(self.gameObject, "bg/otherScroll")
    this.tabBox = Util.GetGameObject(self.gameObject, "bg/TabBox")
    this.itemPre = Util.GetGameObject(self.gameObject, "bg/pre")
    this.grid = Util.GetGameObject(this.otherScroll, "grid")

    this.previewList = {}
    this.List1 = {}
    this.List2 = {}
    this.List3 = {}
    this.List4 = {}
end

--绑定事件（用于子类重写）
function RewardPreviewPopup:BindEvent()
    Util.AddClick(
        this.btnBack,
        function()
            self:ClosePanel()
        end
    )
end

--添加事件监听（用于子类重写）
function RewardPreviewPopup:AddListener()
end

--移除事件监听（用于子类重写）
function RewardPreviewPopup:RemoveListener()
end

function RewardPreviewPopup:OnOpen(type)
    if LengthOfTable(RecruitManager.previewGhostFindData) <= 0 then
        RecruitManager.InitPreData()
    end
    this.starScroll:SetActive(false)
    this.campScroll:SetActive(false)
    this.otherScroll:SetActive(true)
    this.tabBox:SetActive(false)
    this.grid.transform:DOAnchorPosY(0, 0, true)
    if type == PRE_REWARD_POOL_TYPE.LUCK_FIND then
        typeNum = 2
    elseif type == PRE_REWARD_POOL_TYPE.GHOST_FIND then
        typeNum = 4
    end

    this.CreatePreview(typeNum, type)
end

function this.CreatePreview(typeNum, type)
    local showData = {}
    showData = RecruitManager.GetRewardPreviewData(type)
    for i = 1, 4 do
        if not this.previewList[i] then
            this.previewList[i] = newObjToParent(this.itemPre, this.grid)
        end
    end

    for key, value in pairs(this.List1) do
        if value then
            value.gameObject:SetActive(false)
        end
    end
    for key, value in pairs(this.List2) do
        if value then
            value.gameObject:SetActive(false)
        end
    end

    if type == PRE_REWARD_POOL_TYPE.LUCK_FIND then
        this.CreateLuckInfo(showData)
    elseif type == PRE_REWARD_POOL_TYPE.GHOST_FIND then
        this.previewList[4].gameObject:SetActive(false)
        this.CreateEastGhostInfo(showData)
    end

    -- 显隐显示
    for i = 1, 4 do
        if this.previewList[i] then
            if type == PRE_REWARD_POOL_TYPE.LUCK_FIND then
                this.previewList[i]:SetActive(i <= 2)
            elseif type == PRE_REWARD_POOL_TYPE.GHOST_FIND then
                this.previewList[i]:SetActive(i <= 3)
            else
                this.previewList[i]:SetActive(i <= 4)
            end
        end
    end
end

-- 幸运探宝
function this.CreateLuckInfo(showData)
    -- Util.GetGameObject(this.previewList[1], "title/Text"):GetComponent("Text").text = GetLanguageStrById(11761)
    -- Util.GetGameObject(this.previewList[2], "title/Text"):GetComponent("Text").text = GetLanguageStrById(11762)

    local normalData = {}
    local upperData = {}

    for i = 1, #showData do
        if showData[i].ActivityId == 30 then -- 幸运探宝
            normalData[#normalData + 1] = showData[i]
        elseif showData[i].ActivityId == 31 then
            upperData[#upperData + 1] = showData[i]
        end
    end

    for i = 1, #normalData do
        if not this.List1[i] then
            this.List1[i] =
                SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.previewList[1], "gird").transform)
        end
        this.List1[i]:OnOpen(false, {normalData[i].Reward[1], normalData[i].Reward[2]}, 1, true)
        this.List1[i].name:GetComponent("Text").text =
            string.format("<color=#EDB64C>%0.2f%s</color>", normalData[i].ShowWeight, "%")
        this.List1[i].gameObject:SetActive(true)
    end

    for i = 1, #upperData do
        if not this.List2[i] then
            this.List2[i] =
                SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.previewList[2], "gird").transform)
        end
        this.List2[i]:OnOpen(false, {upperData[i].Reward[1], upperData[i].Reward[2]}, 1.1, true)
        this.List2[i].name:GetComponent("Text").text =
            string.format("<color=#EDB64C>%0.2f%s</color>", upperData[i].ShowWeight, "%")
        this.List2[i].gameObject:SetActive(true)
    end
end

-- 东海寻鬼
function this.CreateEastGhostInfo(showData)
    Util.GetGameObject(this.previewList[1], "title/Text"):GetComponent("Text").text = GetLanguageStrById(11763)
    Util.GetGameObject(this.previewList[2], "title/Text"):GetComponent("Text").text = GetLanguageStrById(11764)
    Util.GetGameObject(this.previewList[3], "title/Text"):GetComponent("Text").text = GetLanguageStrById(11765)
    Util.GetGameObject(this.previewList[4], "title/Text"):GetComponent("Text").text = GetLanguageStrById(11766)

    local fiveData = {}
    local fourData = {}
    local ThreeData = {}
    local otherList = {}

    for i = 1, #showData do
        if itemConfig[showData[i].Reward[1]].ItemType == 1 or itemConfig[showData[i].Reward[1]].ItemType == 2 then
            if itemConfig[showData[i].Reward[1]].Quantity == 5 then -- 5星
                fiveData[#fiveData + 1] = showData[i]
            elseif itemConfig[showData[i].Reward[1]].Quantity == 4 then -- 4星
                fourData[#fourData + 1] = showData[i]
            elseif itemConfig[showData[i].Reward[1]].Quantity == 3 then -- 3
                ThreeData[#ThreeData + 1] = showData[i]
            end
        else
            otherList[#otherList + 1] = showData[i]
        end
    end

    for i = 1, #fiveData do
        if not this.List1[i] then
            this.List1[i] =
                SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.previewList[1], "gird").transform)
        end
        this.List1[i]:OnOpen(false, {fiveData[i].Reward[1], fiveData[i].Reward[2]}, 1.1, true)
        this.List1[i].name:GetComponent("Text").text =
            "<color=#EDB64C>" .. string.format("%.2f", (fiveData[i].Weight / 100000) * 100) .. "%</color>"
        this.List1[i].gameObject:SetActive(true)
    end

    for i = 1, #fourData do
        if not this.List2[i] then
            this.List2[i] =
                SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.previewList[2], "gird").transform)
        end
        this.List2[i]:OnOpen(false, {fourData[i].Reward[1], fourData[i].Reward[2]}, 1.1, true)
        this.List2[i].name:GetComponent("Text").text =
            "<color=#EDB64C>" .. string.format("%.2f", (fourData[i].Weight / 100000) * 100) .. "%</color>"
        this.List2[i].gameObject:SetActive(true)
    end

    for i = 1, #ThreeData do
        if not this.List3[i] then
            this.List3[i] =
                SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.previewList[3], "gird").transform)
        end
        this.List3[i]:OnOpen(false, {ThreeData[i].Reward[1], ThreeData[i].Reward[2]}, 1.1, true)
        this.List3[i].name:GetComponent("Text").text =
            "<color=#EDB64C>" .. string.format("%.2f", (ThreeData[i].Weight / 100000) * 100) .. "%</color>"
    end

    for i = 1, #otherList do
        if not this.List4[i] then
            this.List4[i] = SubUIManager.Open(SubUIConfig.ItemView,  Util.GetGameObject(this.previewList[4],  "gird").transform)
        end
        this.List4[i]:OnOpen(false, {otherList[i].Reward[1], otherList[i].Reward[2] }, 1.1, true)
        this.List4[i].name:GetComponent("Text").text = "<color=#EDB64C>"..string.format("%.2f",(otherList[i].Weight/100000)*100) .."%</color>"
    end
end

--界面打开时调用（用于子类重写）
function RewardPreviewPopup:OnShow(...)
end

function RewardPreviewPopup:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function RewardPreviewPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function RewardPreviewPopup:OnDestroy()
    this.previewList = {}
    this.List1 = {}
    this.List2 = {}
    this.List3 = {}
    this.List4 = {}
end

return RewardPreviewPopup