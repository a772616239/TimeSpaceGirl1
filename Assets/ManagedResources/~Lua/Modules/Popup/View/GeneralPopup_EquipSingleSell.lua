----- 装备分解弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local _args = {}
--传入选择宝器计算返回奖励数据列表
local dropList = {}
--item容器
local itemList = {}
--传入选择英雄
local selectEquipTreasureData
local func
local count = 0

function this:SetCount(value)
    if value < 0 then value = 0 end
    if value > selectEquipTreasureData.num then value = selectEquipTreasureData.num end
    count = value
    this.slider.value = value
    this.bodyText.text = string.format(GetLanguageStrById(12235),count,GetLanguageStrById(selectEquipTreasureData.itemConfig.Name))
end

function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.bodyText = Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.confirmBtn = Util.GetGameObject(gameObject,"ConfirmBtn")
    this.addBtn = Util.GetGameObject(gameObject,"add")
    this.reduceBtn = Util.GetGameObject(gameObject,"reduce")
    this.slider = Util.GetGameObject(gameObject,"Slider"):GetComponent("Slider")
    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root")
end
--道具 和 装备分解 发送请求后 回调
function this.SendBackResolveReCallBack(drop)
    local isShowReward = false
    if drop.itemlist ~= nil and #drop.itemlist > 0 then
        for i = 1, #drop.itemlist do
            if drop.itemlist[i].itemNum > 0 then
                isShowReward = true
                break
            end
        end
    end
    if isShowReward then
        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function ()
            BagManager.OnShowTipDropNumZero(drop)
        end)
    else
        BagManager.OnShowTipDropNumZero(drop)
    end
    parent:ClosePanel()
    if func then
        func()
    end
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        if count == 0 then
            PopupTipPanel.ShowTipByLanguageId(12272)
            return
        end
        if selectEquipTreasureData.itemConfig.Quantity >= 4 then
        UIManager.OpenPanel(UIName.BagResolveAnCompoundPanel, 2, selectEquipTreasureData.itemConfig.ItemBaseType, selectEquipTreasureData, function() end, count)
        parent:ClosePanel()
        else
            local curResolveAllItemList = {}
            local equip = {}
            equip.itemId = selectEquipTreasureData.id
            equip.itemNum = count
            table.insert(curResolveAllItemList,equip)
            local type = 1
            NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                this.SendBackResolveReCallBack(drop)
            end)
        end
    end)
    Util.AddClick(this.addBtn,function()
        this:SetCount(count + 1)
    end)
    Util.AddClick(this.reduceBtn,function()
        this:SetCount(count - 1)
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
    this.titleText.text = GetLanguageStrById(12236)

    local equip =  args[1]
    func = args[2]
    selectEquipTreasureData = BagManager.GetItemById(equip.id)
    this:SetCount(selectEquipTreasureData.num)
    if not itemList or #itemList < 1 then
        local item = SubUIManager.Open(SubUIConfig.ItemView, this.root.transform)
        table.insert(itemList,item)
    end
    itemList[1].gameObject:SetActive(true)
    itemList[1]:OnOpen(false,{selectEquipTreasureData.id,selectEquipTreasureData.num},1,true,false)

    this.slider.maxValue = selectEquipTreasureData.num
    this.slider.value = selectEquipTreasureData.num
    this.slider.onValueChanged:AddListener(function()
        this:SetCount(this.slider.value)
    end)
end

function this:OnClose()
end

function this:OnDestroy()
    itemList = {}
    count = 0
end

return this