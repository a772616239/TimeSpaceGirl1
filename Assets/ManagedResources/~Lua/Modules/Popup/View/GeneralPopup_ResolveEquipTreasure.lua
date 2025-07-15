----- 宝器分解弹窗 -----
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
local selectEquipTreasureData
local selectEquipTreasureDataDid
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)

function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.bodyText=Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.bodyText2=Util.GetGameObject(gameObject,"BodyText2")
    this.tipText=Util.GetGameObject(gameObject,"tipText"):GetComponent("Text")
    this.cancelBtn=Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn=Util.GetGameObject(gameObject,"ConfirmBtn")

    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root/Viewport/Content")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()                  
        NetManager.UseAndPriceItemRequest(4,selectEquipTreasureDataDid,function (drop)
            this.SendBackResolveReCallBack(drop)
        end)
    end)       
end
function this.SendBackResolveReCallBack(drop)
    local isShowReward=false
    if drop.itemlist~=nil and #drop.itemlist>0 then
        for i = 1, #drop.itemlist do
            if drop.itemlist[i].itemNum>0 then
                isShowReward=true
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
    for k, v in ipairs(selectEquipTreasureDataDid) do
        EquipTreasureManager.RemoveTreasureByIdDyn(v)
    end
    ResolvePanel.SwitchView(3)
    parent:ClosePanel()
end
function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder =_parent.sortingOrder
    local args = {...}
    dropList = args[1]
    selectEquipTreasureData=args[2]

    this.titleText.text=GetLanguageStrById(12212)
    --返还比
    local isEquipShowSure = false
    selectEquipTreasureDataDid = {}
    local data = {}
    for k, v in pairs(selectEquipTreasureData) do
        table.insert(selectEquipTreasureDataDid,k)
        if v.quantity>4 then
            isEquipShowSure=true
        end
    end
    this.bodyText.text=GetLanguageStrById(12273)
    this.bodyText2:GetComponent("Text").text=GetLanguageStrById(12274)
    this.bodyText2.gameObject:SetActive(isEquipShowSure)
    this.tipText.text = GetLanguageStrById(12275)

    local data={}
    local index = 1
    for i, v in pairs(dropList) do
        
        data[index]={v.id,v.num}
        index = index + 1
    end
    
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,60,1,sortingOrder,false,data)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this