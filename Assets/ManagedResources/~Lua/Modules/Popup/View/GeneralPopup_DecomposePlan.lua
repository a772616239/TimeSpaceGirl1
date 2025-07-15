----- 送神弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local CombatPlanPromotion = ConfigManager.GetConfig(ConfigName.CombatPlanPromotion)



function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.bodyText=Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.cancelBtn=Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn=Util.GetGameObject(gameObject,"ConfirmBtn")

    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root")

    this.itemList = {}
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        CombatPlanManager.DecomposePlan(this.planData.id, function(msg)

            CombatPlanManager.DelSinglePlanData(this.planData.id)
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
    parent=_parent
    sortingOrder =_parent.sortingOrder
    local args = {...}
    this.planData = args[1]

    this.InitDrop()
end

function this.InitDrop()
    if #this.itemList == 0 then
        for i = 1, 4 do     --< 目前最多支持四个item
            this.itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.root.transform)
        end
    end
    
    local itemDataList={}
    local combatPlanConfig = G_CombatPlanConfig[this.planData.combatPlanId]
    if combatPlanConfig.DecomposeGet ~= nil then
        for i = 1, #combatPlanConfig.DecomposeGet do
            table.insert(itemDataList,combatPlanConfig.DecomposeGet[i])

        end
    end
    --table.insert(itemDataList,combatPlanConfig.DecomposeGet)
    --local itemData = combatPlanConfig.DecomposeGet
    
    if this.planData.promotionLevel~=0 then
        local data=CombatPlanPromotion[this.planData.promotionLevel]
        if data.DecomposeGet ~= nil then 
            for i = 1, #data.DecomposeGet do
                table.insert(itemDataList,data.DecomposeGet[i])
    
            end
        end
        
    end
    
    

    for i = 1, 4 do
        local ItemView = this.itemList[i]
        if i <= #itemDataList then
            ItemView.gameObject:SetActive(true)
            ItemView:OnOpen(false, {itemDataList[i][1], itemDataList[i][2]}, 0.9, nil, nil, nil, nil, nil)
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