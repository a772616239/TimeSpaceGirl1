----- 装备批量出售 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local _args={}
--传入选择宝器计算返回奖励数据列表
local dropList = {}
--item容器
local itemList = {}
--传入选择英雄
local selectEquipsData
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)

function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.bodyText=Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.BodyText2=Util.GetGameObject(gameObject,"BodyText2")
    this.cancelBtn=Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn=Util.GetGameObject(gameObject,"ConfirmBtn")

    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        local data = {}
        for k,v in ipairs(selectEquipsData) do
            local equip = {}
            equip.itemId = v.id
            equip.itemNum = v.num
            table.insert(data,equip)
        end
        NetManager.UseAndPriceItemRequest(1, data, function(msg)         
            parent:ClosePanel()
            UIManager.OpenPanel(UIName.RewardItemPopup,msg,1,function ()
                BagManager.OnShowTipDropNumZero(msg)
            end)
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
    selectEquipsData=args[1]
    dropList = EquipManager.GetEquipRewardList(selectEquipsData)
    this.titleText.text=GetLanguageStrById(12233)
    --返还比
    local num = 0
    local isShow=false
    for k,v in ipairs(selectEquipsData) do
        num = num + v.num
        if v.itemConfig.Quantity > 4 and not isShow then
            isShow=true
        end
    end
    this.bodyText.text=string.format(GetLanguageStrById(12234),num)
    this.BodyText2:GetComponent("Text").text=GetLanguageStrById(12271)
    this.BodyText2.gameObject:SetActive(isShow)
    local data={}
    local index = 1 
    for i, v in pairs(dropList) do
        data[index]={i,v}
        index = index + 1
    end

    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,4,1,sortingOrder,false,data)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this