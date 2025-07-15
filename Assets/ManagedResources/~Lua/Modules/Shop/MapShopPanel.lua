require("Base/BasePanel")
local MapShopPanel = Inherit(BasePanel)
local this = MapShopPanel

--初始化组件（用于子类重写）
function MapShopPanel:InitComponent()
    this.title = Util.GetGameObject(self.gameObject,"bg/Text"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.content = Util.GetGameObject(self.gameObject, "content")
    -- 上部货币显示
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft})
end

--绑定事件（用于子类重写）
function MapShopPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        if this.eventId then
            OptionBehaviourManager.JumpEventPoint(this.eventId, this.options[1], self)
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityProgressStateChange)
        Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MapShopPanel:AddListener()
end

--移除事件监听（用于子类重写）
function MapShopPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function MapShopPanel:OnOpen(shopType, eventId, options)
    this.shopType = shopType
    this.eventId = eventId
    this.options = options
end

function MapShopPanel:OnShow()
    if not this.shopType then return end
    if not this.shopView then
        this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform, this.content)
    end

    this.shopView:ShowShop(this.shopType, this.sortingOrder)
    -- 货币界面
    local _ShopTypeConfig = ConfigManager.GetConfig(ConfigName.StoreTypeConfig)
    local shopId = ShopManager.GetShopDataByType(this.shopType).id
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = _ShopTypeConfig[shopId].ResourcesBar})
    this.title.text = GetLanguageStrById(_ShopTypeConfig[this.shopType].Name)

end

--界面关闭时调用（用于子类重写）
function MapShopPanel:OnClose()
    if this.shopView then
        SubUIManager.Close(this.shopView)
        this.shopView = nil
        Util.ClearChild(this.content.transform)
    end

    if AdjutantActivityPanel then
        AdjutantCurrentPanel:ShowContent()
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
end

--界面销毁时调用（用于子类重写）
function MapShopPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
end

return MapShopPanel