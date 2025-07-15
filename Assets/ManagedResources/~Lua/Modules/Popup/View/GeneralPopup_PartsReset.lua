----- 部件重置弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0

local curHeroData
local curPos

function this:InitComponent(gameObject)
    -- this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    -- this.bodyText=Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.cancelBtn=Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn=Util.GetGameObject(gameObject,"ConfirmBtn")
    this.Cost1=Util.GetGameObject(gameObject,"Cost1")

    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root")

    this.itemList = {}
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        local partsShowLv = curHeroData.partsData[curPos].isUnLock
        local partsConfig = HeroManager.GetPartsConfigData(partsShowLv)
        local itemId = partsConfig.recast_cost[1]
        local cost = partsConfig.recast_cost[2]
        local num = BagManager.GetItemCountById(itemId)
        if num < cost then
            PopupTipPanel.ShowTipByLanguageId(10455)
            return
        end

        NetManager.AdjustResetRequest(curHeroData.dynamicId, curPos, function(msg)
            HeroManager.PartsSetUnlockValue(curHeroData, curPos)
            if msg.drop then
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
            end
            
            if PartsMainPopup then
                PartsMainPopup.RreshEquip()
            end
            if RoleInfoPanel then
                RoleInfoPanel.ShowHeroEquip()
                RoleInfoPanel:UpdatePanelData()
            end
            
            parent:ClosePanel()
        end)
        
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder =_parent.sortingOrder
    local args = {...}
    curHeroData = args[1]
    curPos = args[2]


    this.InitMain()
end

function this.InitMain()

    local partsShowLv = curHeroData.partsData[curPos].isUnLock
    local partsConfig = HeroManager.GetPartsConfigData(partsShowLv)
    --> item
    local itemDatas = partsConfig.recast

    for i = 1, #this.itemList do
        this.itemList[i].gameObject:SetActive(false)
    end
    for i = 1, #itemDatas do
        if this.itemList[i] == nil then
            this.itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.root.transform)
        end
        this.itemList[i]:OnOpen(false, {itemDatas[i][1], itemDatas[i][2]}, 0.9, nil, nil, nil, nil, nil)
        this.itemList[i].gameObject:SetActive(true)
    end


    --> cost
    local itemId = partsConfig.recast_cost[1]
    local cost = partsConfig.recast_cost[2]
    local num = BagManager.GetItemCountById(itemId)
    local itemData = G_ItemConfig[itemId]
    
    Util.GetGameObject(this.Cost1, "icon1"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
    Util.GetGameObject(this.Cost1, "Num1"):GetComponent("Text").text = GetNumUnenoughColor(num, cost, PrintWanNum2(num), PrintWanNum2(cost))
    ItemImageTips(itemId, Util.GetGameObject(this.Cost1, "icon1"))
end

function this:OnClose()
end

function this:OnDestroy()
    this.itemList = {}
end

return this