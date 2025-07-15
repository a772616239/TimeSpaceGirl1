require("Base/BasePanel")
local BlackShopPanel = Inherit(BasePanel)
local this = BlackShopPanel

this._MainShopPageList = {}
this._MainShopTypeList = {}
--初始化组件（用于子类重写）
function BlackShopPanel:InitComponent()
    this.btnCloseSelf = Util.GetGameObject(self.gameObject, "btnBack")
    this.content = Util.GetGameObject(self.gameObject, "content")
    this.btnRefresh = Util.GetGameObject(self.gameObject, "btnRefresh")

    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)
end
--绑定事件（用于子类重写）
function BlackShopPanel:BindEvent()
    this.OnShopTabChange(2)
    -- 关闭界面打开主城
    Util.AddClick(this.btnCloseSelf, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function BlackShopPanel:AddListener()
end
--移除事件监听（用于子类重写）
function BlackShopPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BlackShopPanel:OnOpen(chooseShopType)
    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Shop)
end

-- 打开，重新打开时回调
function BlackShopPanel:OnShow()
    this.PlayerHeadFrameView:OnShow(true)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
end

-- 层级变化时，子界面层级刷新
function BlackShopPanel:OnSortingOrderChange()
    if this.shopView then
        this.shopView:SetSortLayer(self.sortingOrder)
    end
end

-- tab改变事件
function this.OnShopTabChange(index)
    if not this.shopView then
        this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform,this.content)
        -- 修改商品栏的位置
        this.shopView:SetItemContentPosition(Vector3.New(0, 1100, 0))
    end
    this.shopView:ShowShop(index, 200)
    this.shopView:SetBasePanelPostion(Vector2.New(0,-96))
end

--界面关闭时调用（用于子类重写）
function BlackShopPanel:OnClose()
    CheckRedPointStatus(RedPointType.BlackShop)
    Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.TrainTask)
end
--界面销毁时调用（用于子类重写）
function BlackShopPanel:OnDestroy()
    -- 销毁shopview
    if this.shopView then
        SubUIManager.Close(this.shopView)
        this.shopView = nil
    end

    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.PlayerHeadFrameView)
end

return BlackShopPanel