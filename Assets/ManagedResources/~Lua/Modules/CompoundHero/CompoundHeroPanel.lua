require("Base/BasePanel")
CompoundHeroPanel = Inherit(BasePanel)
local this = CompoundHeroPanel
local TabBox = require("Modules/Common/TabBox")
local _TabData = {  [1] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", 
                        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", 
                        name = GetLanguageStrById(12527),
                        title = "cn2-X1_julebu_zhaomuyeqian"},
                    [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", 
                        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", 
                        name = GetLanguageStrById(12528),
                        title = "cn2-X1_julebu_zhuanhuanyeqian"}
                }

local _TabFontColor = { default = Color.New(255 / 255, 255 / 255, 255 / 255, 153 / 255),
                        select = Color.New(255 / 255, 255 / 255, 255 / 255, 255 / 255)}
local curIndex = 1

local tabTextPos = {
    default = Vector3.New(0,0,0),
    select = Vector3.New(45,5,0)
}
local tabTitleState = {
    default = false,
    select = true
}

this.contents = {
    [1] = {view = require("Modules/CompoundHero/view/ElementDrawCardPanel"), panelName = "ElementDrawCardPanel"},
    [2] = {view = require("Modules/CompoundHero/view/CompoundHero_Replace"), panelName = "CompoundHeroPanel_Replace"},
}
--初始化组件（用于子类重写）
function CompoundHeroPanel:InitComponent()
    this.HelpBtn = Util.GetGameObject(self.gameObject,"ElementDrawCardPanel/helpBtn")
    this.panle = Util.GetGameObject(self.gameObject,"panle")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition
    this.shopBtn = Util.GetGameObject(self.gameObject,"panle/ElementDrawCardPanel/shopBtn")
    this.btns = Util.GetGameObject(self.gameObject,"panle/ElementDrawCardPanel")
    this.btns2 = Util.GetGameObject(self.gameObject,"panle/CompoundHeroPanel_Replace/bg/Image (1)/btns2")
    this.shopBtn2 = Util.GetGameObject(this.btns2,"shopBtn")
    --子模块脚本
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")    
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
    this.btnBack = Util.GetGameObject(self.gameObject, "panle/btnBack/btnBack")
    this.bgImage = Util.GetGameObject(self.gameObject, "bgImage")
    --预设赋值
    this.prefabs = {}

    for i = 1,#this.contents do
        this.prefabs[i] = Util.GetGameObject(this.panle,this.contents[i].panelName)
        this.contents[i].view:InitComponent(this.panle)
    end
end

--绑定事件（用于子类重写）
function CompoundHeroPanel:BindEvent()
    Util.AddClick(this.shopBtn, function()
        UIManager.OpenPanel(UIName.CustomSuppliesShopPanel, 12,SHOP_TYPE.CHOAS_SHOP)
    end)
    Util.AddClick(this.shopBtn2, function()
        -- UIManager.OpenPanel(UIName.MainShopPanel,19) 
        UIManager.OpenPanel(UIName.CustomSuppliesShopPanel, 12,SHOP_TYPE.CHOAS_SHOP)
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

function CompoundHeroPanel.RefreshHelpBtn()
    if curIndex == 2 then
        this.HelpBtn:SetActive(true)
        Util.AddOnceClick(this.HelpBtn, function()
            UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.HeroReplacement,this.helpPosition.x,this.helpPosition.y) 
        end)
    elseif curIndex == 1 then
        this.HelpBtn:SetActive(true)
        Util.AddOnceClick(this.HelpBtn, function()
            UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.ElementDraw,this.helpPosition.x,this.helpPosition.y)
        end)
    else
        this.HelpBtn:SetActive(false)
    end
end

--添加事件监听（用于子类重写）
function CompoundHeroPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function CompoundHeroPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function CompoundHeroPanel:OnOpen(_curIndex)
    curIndex = _curIndex and _curIndex or 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function CompoundHeroPanel:OnShow()
    -- this.BtView:OnOpen({sortOrder = self.sortingOrder,panelType = PanelTypeView.MainCity})
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
end

function CompoundHeroPanel:OnSortingOrderChange()
    -- this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
    this.sortingOrder = self.sortingOrder
    for i = 1, #this.contents do
        this.contents[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
    Util.GetGameObject(tab,"title"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].title)
    Util.GetGameObject(tab,"Text"):GetComponent("RectTransform").localPosition = tabTextPos[status]
    Util.GetGameObject(tab,"title"):SetActive(tabTitleState[status])

end

--切换视图
function this.SwitchView(index)
    -- this.bgImage.sprite=Util.LoadSprite(bgImage[index])
    -- Util.GetGameObject(this.bgImage.transform,"Image"..index).transform:SetSiblingIndex(2)
    if index == 1 then
        Util.GetGameObject(this.bgImage.transform,"Image1"):SetActive(true)
        Util.GetGameObject(this.bgImage.transform,"Image2"):SetActive(false)
        this.btns:SetActive(true)
        this.btns2:SetActive(false)
    else
        Util.GetGameObject(this.bgImage.transform,"Image1"):SetActive(false)
        Util.GetGameObject(this.bgImage.transform,"Image2"):SetActive(true)
        this.btns:SetActive(false)
        this.btns2:SetActive(true)
    end
    
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect ~= 0 then this.contents[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --区分显示
    if index == 2 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.HeroReplace})
    elseif index == 1 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.CountryDraw})
    end
    this.RefreshHelpBtn()
    --执行子模块初始化
    this.contents[index].view:OnShow(this,this.btnBack)
end

--刷新魂印合成的方法
function this.UpdateCompoundPanel_SoulPrint(equipSign,index)
    --this.contents[curIndex].view.ShowTitleEquipData(nil,equipSign,index)
end

--界面关闭时调用（用于子类重写）
function CompoundHeroPanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

--界面销毁时调用（用于子类重写）
function CompoundHeroPanel:OnDestroy()
    -- SubUIManager.Close(this.BtView)
    SubUIManager.Close(this.upView)
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

return CompoundHeroPanel