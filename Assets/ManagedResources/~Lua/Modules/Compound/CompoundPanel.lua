require("Base/BasePanel")
local CompoundPanel = Inherit(BasePanel)
local this = CompoundPanel
local TabBox = require("Modules/Common/TabBox")

local _TabData = {
    [1] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
        name = GetLanguageStrById(12320),
        title = "cn2-X1_hecheng_zhuangbei_xuanzhong"
        },
    [2] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
        name = GetLanguageStrById(22321),
        title = "cn2-X1_hecheng_jiezhi_xuanzhong"
        },
    [3] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02",
        name = GetLanguageStrById(50183),
        title = "cn2-X1_beibao_fenlantubiao_05"
        },
}
local curIndex = 1

this.contents = {
    [1] = {view = require("Modules/Compound/view/CompoundPanel_Equip"), panelName = "CompoundPanel_Equip"},
    [2] = {view = require("Modules/Compound/view/CompoundPanel_CombatPlan"), panelName = "CompoundPanel_CombatPlan"},
    [3] = {view = require("Modules/Compound/view/CompoundPanel_SoulPrint"), panelName = "CompoundPanel_SoulPrint"},
}
--初始化组件（用于子类重写）
function CompoundPanel:InitComponent()
    this.EquipHelpBtn = Util.GetGameObject(self.gameObject,"panle/CompoundPanel_Equip/helpBtn")
    this.CombatPlanHelpBtn = Util.GetGameObject(self.gameObject,"panle/CompoundPanel_CombatPlan/Compound/helpBtn")
    this.SoulPrintHelpBtn = Util.GetGameObject(self.gameObject,"panle/CompoundPanel_SoulPrint/helpBtn")

    this.EquipHelpBtnPos = this.EquipHelpBtn:GetComponent("RectTransform").localPosition
    this.CombatPlanHelpBtnPos = this.CombatPlanHelpBtn:GetComponent("RectTransform").localPosition
    this.SoulPrintHelpBtnPos = this.SoulPrintHelpBtn:GetComponent("RectTransform").localPosition

    --子模块脚本
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight})
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.btnBack2 = Util.GetGameObject(self.gameObject, "btnBack2")
    --预设赋值
    this.prefabs = {}

    for i = 1, #this.contents do
        this.prefabs[i] = Util.GetGameObject(self.gameObject,this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, "panle/" .. this.contents[i].panelName))
    end
    this.isRefresh = false
end

--绑定事件（用于子类重写）
function CompoundPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnBack2, function ()
        this.btnBack:SetActive(true)
        this.btnBack2:SetActive(false)
        Util.GetGameObject(self.gameObject,"panle/CompoundPanel_CombatPlan/Compound"):SetActive(true)
        Util.GetGameObject(self.gameObject,"panle/CompoundPanel_CombatPlan/PromotionPanel"):SetActive(false)
    end)

    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

function CompoundPanel.RefreshHelpBtn()
    if curIndex == 1 then
        Util.AddOnceClick(this.EquipHelpBtn, function()
            UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.EquipCompose ,this.EquipHelpBtnPos.x,this.EquipHelpBtnPos.y) 
        end)
    elseif curIndex == 2 then
        Util.AddOnceClick(this.CombatPlanHelpBtn, function()
            UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.CombatPlan,this.CombatPlanHelpBtnPos.x,this.CombatPlanHelpBtnPos.y) 
        end)
    elseif curIndex == 3 then
        Util.AddOnceClick(this.SoulPrintHelpBtn, function()
            UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.SoulPrintCommond,this.SoulPrintHelpBtnPos.x,this.SoulPrintHelpBtnPos.y) 
        end)
    else
        -- this.HelpBtn:SetActive(false)
    end
end

--添加事件监听（用于子类重写）
function CompoundPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end

    -- Game.GlobalEvent:AddEvent(GameEvent.ResearchInstitute.OnResearchInstituteRedpointChange,this.RefreshRedpoint)
end

--移除事件监听（用于子类重写）
function CompoundPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end

    -- Game.GlobalEvent:RemoveEvent(GameEvent.ResearchInstitute.OnResearchInstituteRedpointChange,this.RefreshRedpoint)
end

--界面打开时调用（用于子类重写）
function CompoundPanel:OnOpen(_curIndex, _isRefine)
    curIndex = _curIndex and _curIndex or 1
    this.isRefresh = _isRefine
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function CompoundPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)

    this.BindRedpoint()
end


function CompoundPanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
    for i = 1, #this.contents do
        this.contents[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    Util.GetGameObject(tab,"bg"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])

    local name = Util.GetGameObject(tab, "name")
    local name2 = Util.GetGameObject(tab, "name2")
    name:GetComponent("Text").text = _TabData[index].name
    name2:GetComponent("Text").text = _TabData[index].name

    local title = Util.GetGameObject(tab, "title")
    title:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].title)

    name:SetActive(status == "select")
    name2:SetActive(status == "default")
    title:SetActive(status == "select")
end

--切换视图
function this.SwitchView(index)
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect ~= 0 and oldSelect ~= nil then this.contents[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --区分显示
    if index == 1 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    elseif index == 2 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    elseif index == 3 then
        this.upView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    end
    this.RefreshHelpBtn()
    --执行子模块初始化
    this.contents[index].view:OnShow(this)
end

--刷新魂印合成的方法
function this.UpdateCompoundPanel_SoulPrint(equipSign,index)
    this.contents[curIndex].view.ShowTitleEquipData(nil,equipSign,index)
end

--绑定红点
function this.BindRedpoint()
    BindRedPointObject(RedPointType.ResearchInstitute_EquipCompound,Util.GetGameObject(Util.GetGameObject(this.tabBox,"mask/box").transform:GetChild(0), "redpoint"))
    BindRedPointObject(RedPointType.ResearchInstitute_RingCompound,Util.GetGameObject(Util.GetGameObject(this.tabBox,"mask/box").transform:GetChild(1), "redpoint"))

    CheckRedPointStatus(RedPointType.ResearchInstitute_RingCompound)
end

--界面关闭时调用（用于子类重写）
function CompoundPanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
end

--界面销毁时调用（用于子类重写）
function CompoundPanel:OnDestroy()
    ClearRedPointObject(RedPointType.ResearchInstitute_EquipCompound)
    ClearRedPointObject(RedPointType.ResearchInstitute_RingCompound)

    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.upView)
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

return CompoundPanel