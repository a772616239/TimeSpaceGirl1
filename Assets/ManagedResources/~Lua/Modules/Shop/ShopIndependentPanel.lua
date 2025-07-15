require("Base/BasePanel")
local ShopIndependentPanel = Inherit(BasePanel)
local this = ShopIndependentPanel

local TabBox = require("Modules/Common/TabBox")

local TabData = {
    [1] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong", select = "cn2-x1_haoyou_biaoqian_xuanzhong", lock = ""},
    [2] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_xuanzhong", lock = ""},
}
--初始化组件（用于子类重写）
function ShopIndependentPanel:InitComponent()
    -- this.title = Util.GetGameObject(self.gameObject,"title"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.gameObject, "down/btnBack")
    this.content = Util.GetGameObject(self.gameObject, "content")

    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft})
    this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform, this.content.transform)
    
    this.tabCtrl = TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter)
    this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)
end

--绑定事件（用于子类重写）
function ShopIndependentPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ShopIndependentPanel:AddListener()
end

--移除事件监听（用于子类重写）
function ShopIndependentPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ShopIndependentPanel:OnOpen(page)
    this.page = page
    this.allPages = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.StoreTypeConfig, "Pages", page, "Category", 0)
    table.sort(this.allPages, function(a, b)
        return a.Sort < b.Sort
    end)

    this.tabCtrl:Init(this.tabBox, TabData, 1)
end

function ShopIndependentPanel:OnShow()
    -- 货币界面
    -- local _ShopTypeConfig = ConfigManager.GetConfig(ConfigName.StoreTypeConfig)
    -- local shopId = ShopManager.GetShopDataByType(this.shopType).id
    -- this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = _ShopTypeConfig[shopId].ResourcesBar})
    -- this.title.text = SHOP_INDEPENDENT_PAGE_NAME[this.page]
    if not this.UpView then
        this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform, this.content.transform)
    end
    this.UpView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main})
end

function this.OnTabAdapter(tab, index, status)
    tab:GetComponent("Image").sprite = Util.LoadSprite(TabData[index][status])
    Util.GetGameObject(tab, "Text"):GetComponent("Text").text = GetLanguageStrById(this.allPages[index].Name)
end

function this.OnTabIsLockCheck(index)
end

function this.OnChangeTab(index, lastIndex)
    local storeTypeConfigData = this.allPages[index]
    local shopId = storeTypeConfigData.Id
    if not this.UpView then
        this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform, this.content.transform)
    end
    this.shopView:ShowShop(shopId, this.sortingOrder)
end

--界面关闭时调用（用于子类重写）
function ShopIndependentPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function ShopIndependentPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    if this.shopView then
        this.shopView = SubUIManager.Close(this.shopView)
        this.shopView = nil
    end
end

return ShopIndependentPanel