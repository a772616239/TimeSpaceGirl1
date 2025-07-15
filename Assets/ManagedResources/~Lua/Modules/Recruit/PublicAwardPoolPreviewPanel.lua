require("Base/BasePanel")
PublicAwardPoolPreviewPanel = Inherit(BasePanel)
local this = PublicAwardPoolPreviewPanel
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local guildWarRewardBOX = ConfigManager.GetAllConfigsData(ConfigName.GuildWarRewardBOX)
local titleList = {}
local girdPre = {}
local itemBgList = {}
local itemList = {}

function PublicAwardPoolPreviewPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "bg/btnBack")
    this.mask = Util.GetGameObject(self.transform, "mask")

    this.grid = Util.GetGameObject(self.transform, "bg/scroll/Viewport/grid")
    this.titlePre = Util.GetGameObject(this.grid, "titlePre")
    this.girdPre = Util.GetGameObject(this.grid, "girdPre")
    this.itemPre = Util.GetGameObject(self.transform, "bg/scroll/Viewport/itemPre")
end

function PublicAwardPoolPreviewPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
end

function PublicAwardPoolPreviewPanel:AddListener()
end

function PublicAwardPoolPreviewPanel:RemoveListener()
end

function PublicAwardPoolPreviewPanel:OnSortingOrderChange()
end

function PublicAwardPoolPreviewPanel:OnOpen()
end

function PublicAwardPoolPreviewPanel:OnShow()
    this.GuildBattleReward()
end

function PublicAwardPoolPreviewPanel:OnClose()
    -- titleList = {}
    -- girdPre = {}
    -- itemBgList = {}
    -- itemList = {}
end

function PublicAwardPoolPreviewPanel:OnDestroy()
    titleList = {}
    girdPre = {}
    itemBgList = {}
    itemList = {}
end

function this.GuildBattleReward()
    local allData = {}
    local type = 1
    if GuildBattleManager.guildType == 1 then
        type = 2
    end
    for i = 1, 4 do
        allData[i] = {}
        for index, value in ipairs(guildWarRewardBOX) do
            if value.Mode == type then
                if value.Ranking == i then
                    table.insert(allData[i], {value.Reward[1][1], value.Reward[1][2]})
                end
            end
        end
    end

    for i = 1, #allData do
        table.sort(allData[i], function (a, b)
            if itemConfig[a[1]].Quantity < itemConfig[b[1]].Quantity then
                return false
            elseif itemConfig[a[1]].Quantity > itemConfig[b[1]].Quantity then
                return true
            else
                return a[2] > b[2]
            end
        end)
    end

    for i = 1, #titleList do
        titleList[i].gameObject:SetActive(false)
    end
    for i = 1, #girdPre do
        girdPre[i].gameObject:SetActive(false)
    end
    for i = 1, #itemList do
        itemList[i].gameObject:SetActive(false)
    end
    for i = 1, #itemBgList do
        itemBgList[i].gameObject:SetActive(false)
    end

    for i = 1, #allData do
        if not titleList[i] then
            titleList[i] = newObjToParent(this.titlePre, this.grid)
        end
        Util.GetGameObject(titleList[i].gameObject, "Image/Text"):GetComponent("Text").text = string.format(GetLanguageStrById(50256), i)
        titleList[i].gameObject:SetActive(true)
        if not girdPre[i] then
            girdPre[i] = newObjToParent(this.girdPre, this.grid)
        end
        girdPre[i].gameObject:SetActive(true)
        local num = #itemBgList

        for index, value in ipairs(allData[i]) do
            if not itemBgList[num+index] then
                itemBgList[num+index] = newObjToParent(this.itemPre, girdPre[i])
            end
            itemBgList[num+index].gameObject:SetActive(true)

            if not itemList[num+index] then
                local parent = Util.GetGameObject(itemBgList[num+index].gameObject, "bg/pos").transform
                itemList[num+index] = SubUIManager.Open(SubUIConfig.ItemView, parent)
            end
            itemList[num+index]:OnOpen(false, value, 0.72)
            itemList[num+index].gameObject:SetActive(true)
        end
    end
end

return PublicAwardPoolPreviewPanel