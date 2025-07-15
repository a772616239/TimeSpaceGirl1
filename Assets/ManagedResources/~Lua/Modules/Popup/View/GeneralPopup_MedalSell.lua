----- 芯片售出弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0

function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.bodyText = Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.cancelBtn = Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn = Util.GetGameObject(gameObject,"ConfirmBtn")
    this.root = Util.GetGameObject(gameObject, "Root")--滚动条根节点
    this.itemList = {}
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn, function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        MedalManager.SellMedal(this.planData.idDyn, function(msg)
            Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
            if msg.drop then
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
            end
        end)
        parent:ClosePanel()
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder =_parent.sortingOrder
    local args = {...}
    this.planData = args[1]
    this.InitDrop()
end

function this.InitDrop()
    if #this.itemList == 0 then
        for i = 1, 5 do     --目前最多支持四个item
            this.itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.root.transform)
        end
    end

    local returnList = {}
    local sell = this.planData.medalConfig.Sell
    for k,v in pairs(sell) do
        table.insert(returnList,{v[1],v[2]})
    end
    --table.insert(returnList,{sell[1],sell[2]})
    if this.planData.refineAttrNum > 0 then
        local RefineCost = this.planData.medalConfig.RefineCost
        for k,v in pairs(RefineCost) do
            table.insert(returnList,{v[1], v[2]*this.planData.refineAttrNum})
        end
    end

    for i = 1, 5 do
        local ItemView = this.itemList[i]
        if i <= #returnList then
            ItemView.gameObject:SetActive(true)
            ItemView:OnOpen(false, {returnList[i][1], returnList[i][2]}, 0.9, nil, nil, nil, nil, nil)
        else
            ItemView.gameObject:SetActive(false)
        end
    end
end

function this:OnClose()
end

function this:OnDestroy()
    this.itemList = {}
end

return this