----- 归元弹窗 -----
local this = {}
--传入父脚本模块
local parent
--层级
local sortingOrder = 0
--传入不定参
local _args = {}
local itemviews = {}
local itemId = 0
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)

function this:InitComponent(gameObject)
    -- this.spLoader = SpriteLoader.New()
    this.titleText = Util.GetGameObject(gameObject, "TitleText"):GetComponent("Text")
    this.bodyText = Util.GetGameObject(gameObject, "BodyText"):GetComponent("Text")
    this.cancelBtn = Util.GetGameObject(gameObject, "CancelBtn")
    this.confirmBtn = Util.GetGameObject(gameObject, "ConfirmBtn")
    Util.GetGameObject(this.confirmBtn,"Text"):GetComponent("Text").text = GetLanguageStrById(10202)
    this.tipText = Util.GetGameObject(gameObject, "tipText"):GetComponent("Text")
    this.addBtn = Util.GetGameObject(gameObject, "addBtn")
    this.root = Util.GetGameObject(gameObject, "Root/Content")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function() 
        local count = 1
        if BagManager.GetItemCountById(itemId) > 0 then
            ShopManager.RequestBuyShopItem(7, 10033, count, function()
                PopupTipPanel.ShowTip(GetLanguageStrById(11628))
                Timer.New(function()
                    --LogGreen("BagManager.GetItemCountById(UpViewRechargeType.YunYouVle)--------------:"..BagManager.GetItemCountById(UpViewRechargeType.YunYouVle))
                    Game.GlobalEvent:DispatchEvent(GameEvent.XiaoYao.RefreshEventShow)
                    this:OnShow(parent,98)
                end,1):Start()              
            end,0)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(11706))
        end    
    end)
    Util.AddClick(this.addBtn,function()        
        UIManager.OpenPanel(UIName.ShopBuyPopup, 7,10032)
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.RefreshPanel)--监听背包信息改变刷新 用于回春散数量刷新
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.RefreshPanel)
end

function this.RefreshPanel()
    this:OnShow(parent,1008)
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder =_parent.sortingOrder
    local args = {...}
    itemId = args[1]

    this.titleText.text=GetLanguageStrById(itemConfig[itemId].Name)
    this.bodyText.text = GetLanguageStrById(itemConfig[itemId].ItemDescribe)
    this.tipText.text = GetLanguageStrById(50328)..BagManager.GetItemCountById(itemId)
    for i,v in pairs(itemviews) do
        v.gameObject:SetActive(false)
    end
    if not itemviews[1] then
        itemviews[1] = SubUIManager.Open(SubUIConfig.ItemView,this.root.transform)
    end
    itemviews[1].gameObject:SetActive(true)
    itemviews[1]:OnOpen(false,{itemId,0},1,false)
end

function this:OnClose()
end

function this:OnDestroy()
    -- this.spLoader:Destroy()
    itemviews={}
end

return this