require("Base/BasePanel")
local HeroExchangePanel= Inherit(BasePanel)
local this = HeroExchangePanel
local TabBox = require("Modules/Common/TabBox")

panelName = {
    [1] = "HeroExchangePanel_NormalBack",
    [2] = "HeroExchangePanel_AdvBack",
    [3] = "HeroExchangePanel_Exchange",
}

btnData = {
    [1] = {
        name = GetLanguageStrById(23115),
        colorBg = Color.New(171/255,103/255,255/255,255/255),
        colorFont = Color.New(49/255,33/255,87/255,255/255)
    },
    [2] = {
        name = GetLanguageStrById(23116),
        colorBg = Color.New(254/255,213/255,41/255,255/255),
        colorFont = Color.New(88/255,52/255,25/255,255/255)
    }
}

local _TabData = {
    [1] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
            select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
            name = GetLanguageStrById(12647),
            title = "cn2-X1_yingxiongxiangqing_shuxingyeqian"},
    [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
            select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
            name = GetLanguageStrById(12649),
            title = "cn2-X1_yingxiongxiangqing_shuxingyeqian"},
    [3] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
            select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
            name = GetLanguageStrById(12648),
            title = "cn2-X1_yingxiongxiangqing_shuxingyeqian"},
}
local curIndex = 1

this.contents = {
    [1] = {view = require("Modules/Remould/view/HeroExchangePanel_NormalBack"), panelName = "HeroExchangePanel_NormalBack"},
    [2] = {view = require("Modules/Remould/view/HeroExchangePanel_AdvBack"), panelName = "HeroExchangePanel_AdvBack"},
    [3] = {view = require("Modules/Remould/view/HeroExchangePanel_Exchange"), panelName = "HeroExchangePanel_Exchange"},
}
--初始化组件（用于子类重写）
function HeroExchangePanel:InitComponent()
    --子模块脚本
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
    this.btnBack = Util.GetGameObject(self.gameObject, "BackBtn")

    --预设赋值
    this.prefabs = {}

    for i = 1,#this.contents do
        this.prefabs[i] = Util.GetGameObject(self.gameObject,this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, "Panel"))
    end
end

--绑定事件（用于子类重写）
function HeroExchangePanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function HeroExchangePanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function HeroExchangePanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function HeroExchangePanel:OnOpen(_curIndex)
    curIndex = _curIndex and _curIndex or 1
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HeroExchangePanel:OnShow()
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
end

function HeroExchangePanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
    for i = 1, #this.contents do
        this.contents[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab,"default")
    local select = Util.GetGameObject(tab,"select")
    Util.GetGameObject(tab,"select/title"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].title)
    Util.GetGameObject(tab,"default/Text"):GetComponent("Text").text = _TabData[index].name
    Util.GetGameObject(tab,"select/Text"):GetComponent("Text").text = _TabData[index].name

    default:SetActive(status == "default")
    select:SetActive(status == "select")
end

--切换视图
function this.SwitchView(index)
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
    -- if index == 1 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.recall})
    -- elseif index == 2 then
    --     this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.recall})
    -- elseif index == 3 then
    --     this.upView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.recall})
    -- end
    --执行子模块初始化
    this.contents[index].view:OnShow(this)
end

--界面关闭时调用（用于子类重写）
function HeroExchangePanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

--界面销毁时调用（用于子类重写）
function HeroExchangePanel:OnDestroy()
    SubUIManager.Close(this.upView)
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

return HeroExchangePanel