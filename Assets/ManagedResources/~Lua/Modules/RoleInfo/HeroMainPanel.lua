require("Base/BasePanel")
HeroMainPanel = Inherit(BasePanel)
local this = HeroMainPanel

local tabs = {}
local orginLayer = 0
local orginLayer2 = 0
local isFristOpenTime = Timer.New()

local TabBox = require("Modules/Common/TabBox")
local _TabData = { 
    [1] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong", 
            select = "cn2-X1_tongyong_fenlan_yixuanzhong", name = GetLanguageStrById(22285), 
            defaultTextColor = Color.New(255/255,255/255,255/255,50/255), selectTextColor = Color.white,
            png = "cn2-X1_tongyong_fenlantubiao_yingxiong",
        },
    [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong", 
            select = "cn2-X1_tongyong_fenlan_yixuanzhong", name = GetLanguageStrById(22286), 
            defaultTextColor = Color.New(255/255,255/255,255/255,50/255), selectTextColor = Color.white,
            png = "cn2-X1_tongyong_fenlantubiao_tujian",
        }
}

local curIndex = 1
TabType = {
    Tank = 1,
    HandBook = 2,
    Relic = 3,
}

this.contents = {
    [1] = {view = require("Modules/RoleInfo/RoleListPanel"), panelName = "RoleListPanel"},
    [2] = {view = require("Modules/HandBook/HandBookHeroPanel"), panelName = "HandBookHeroPanel"},
}
this.prefabs = {}

function HeroMainPanel:InitComponent()
    this.formationBtn = Util.GetGameObject(self.gameObject, "formationBtn")
    this.recommendBtn = Util.GetGameObject(self.gameObject, "subPanel/RoleListPanel/recommendBtn")
    this.recommendBtn2 = Util.GetGameObject(self.gameObject, "subPanel/HandBookHeroPanel/recommendBtn")
    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.BtView =SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    this.contract = Util.GetGameObject(self.gameObject, "TabBox/contract")

    --tab
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")

    --子模块
    this.subPanel = Util.GetGameObject(self.gameObject, "subPanel")

    for i = 1, #this.contents do
        this.prefabs[i] = Util.GetGameObject(this.subPanel, this.contents[i].panelName)
        this.contents[i].view:InitComponent(this.prefabs[i])
    end

    this.mask = Util.GetGameObject(this.tabBox,"mask")
    this.maskCurPos = this.mask.transform.position
end

--绑定事件（用于子类重写）
function HeroMainPanel:BindEvent()
    Util.AddClick(this.formationBtn, function()
        if ActTimeCtrlManager.SingleFuncState(54) then
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.SAVE_FORMATION, 1, true)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(54))
        end
    end)
    Util.AddClick(this.contract, function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GENERAL) then
            NetManager.GetGeneralData(function ()
                UIManager.OpenPanel(UIName.GeneralInfoPanel)
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GENERAL))
        end
    end)
    Util.AddClick(this.recommendBtn,function ()
        UIManager.OpenPanel(UIName.LineupRecommend)
    end)
    Util.AddClick(this.recommendBtn2,function ()
        UIManager.OpenPanel(UIName.LineupRecommend)
    end)

    --子模块
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end

    BindRedPointObject(RedPointType.LineupRecommend, Util.GetGameObject(this.recommendBtn, "redpoint"))
    BindRedPointObject(RedPointType.LineupRecommend, Util.GetGameObject(this.recommendBtn2, "redpoint"))
end

--更新帮助按钮的事件
function HeroMainPanel.RefreshHelpBtn()
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.HeroMain,this.helpPosition.x,this.helpPosition.y) 
    end)
end

--添加事件监听（用于子类重写）
function HeroMainPanel:AddListener()
    --子模块
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
    Game.GlobalEvent:AddEvent(GameEvent.HandBook.RefreshRedPoint, this.RefreshRedPoint)
end

--移除事件监听（用于子类重写）
function HeroMainPanel:RemoveListener()
    --子模块
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
    Game.GlobalEvent:RemoveEvent(GameEvent.HandBook.RefreshRedPoint, this.RefreshRedPoint)
end

function this:OnSortingOrderChange()
    orginLayer = self.sortingOrder
    this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
   
    --子模块
    for i = 1, #this.contents do
        this.contents[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end

--界面打开时调用（用于子类重写）
function HeroMainPanel:OnShow()
    --检测成员红点
    CheckRedPointStatus(RedPointType.Role)
    CheckRedPointStatus(RedPointType.LineupRecommend)

    
    this.PlayerHeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.HeroMain })
    this.BtView:OnOpen({sortOrder = self.sortingOrder,panelType = PanelTypeView.MemberPanel})
    SoundManager.PlayMusic(SoundConfig.BGM_Main)
    if ActTimeCtrlManager.SingleFuncState(54) then
        Util.SetGray(this.formationBtn, false)
    else
        Util.SetGray(this.formationBtn, true)
    end

    -- curIndex = 1
    this.RefreshHelpBtn()
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
    -- this.mask.transform.position = this.maskCurPos

    this.mask:SetActive(curIndex == 1)
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    local title = Util.GetGameObject(tab,"title")
    title:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].png)
    tabLab:GetComponent("Text").color = _TabData[index][status .. "TextColor"]
    title:SetActive(status == "select")
    this.mask:SetActive(index == 1)
    if index == 1 then
        local heros = HeroManager.GetAllHeroDatas()
        local teamHero = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_NORMAL)
        local red = false
        for i, v in ipairs(heros) do
            if teamHero[v.dynamicId] ~= nil then
                if not red and HeroManager.GetCurHeroIsShowRedPoint(v) then
                    red = true
                end
            else
                if not red and HeroManager.GetCurHeroIsShowRedPoint(v) then
                    red = true
                end
            end
        end
        Util.GetGameObject(tab,"Redpot"):SetActive(red)
    end

    if index == 2 then
        tab:SetActive(ActTimeCtrlManager.FunctionIsOpen(51))
        Util.GetGameObject(tab,"Redpot"):SetActive(false)
        for key, value in pairs(PlayerManager.heroHandBook) do
            if value.status == 0 then
                Util.GetGameObject(tab,"Redpot"):SetActive(true)
            end
        end
    end
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

    local box = Util.GetGameObject(this.tabBox,"box").transform

    -- this.mask.transform.position = box.transform:GetChild(index-1).position
    this.RefreshRedPoint()

    local red = Util.GetGameObject(this.mask.gameObject,"Redpot")
    red:SetActive(false)
    if index == 1 then
        if Util.GetGameObject(box:GetChild(index-1),"Redpot").activeSelf then
            red:SetActive(true)
        end
    end
    
    -- Util.GetGameObject(this.mask.gameObject,"Text"):GetComponent("Text").text = Util.GetGameObject(box:GetChild(index-1),"Text"):GetComponent("Text").text
    -- Util.GetGameObject(this.mask.gameObject,"title"):GetComponent("Image").sprite = Util.GetGameObject(box:GetChild(index-1),"title"):GetComponent("Image").sprite

    --执行子模块初始化
    this.contents[index].view:OnShow(this)
end

--界面关闭时调用（用于子类重写）
function HeroMainPanel:OnClose()
    --子模块
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end

    if isFristOpenTime then
        isFristOpenTime:Stop()
        isFristOpenTime = nil
    end

    this.maskCurPos = this.mask.transform.position
end

--界面销毁时调用（用于子类重写）
function HeroMainPanel:OnDestroy()
    --子模块
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end

    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.BtView)

    this.ScrollView = nil

    ClearRedPointObject(RedPointType.LineupRecommend, Util.GetGameObject(this.recommendBtn, "redpoint"))
    ClearRedPointObject(RedPointType.LineupRecommend, Util.GetGameObject(this.recommendBtn2, "redpoint"))
end

function this.RefreshRedPoint()
    for i = 1, 2 do
        local tab = Util.GetGameObject(this.tabBox, "box").transform:GetChild(i-1)
        if i == 1 then
            local heros = HeroManager.GetAllHeroDatas()
            local teamHero = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_NORMAL)
            local red = false
            for i, v in ipairs(heros) do
                if teamHero[v.dynamicId] ~= nil then
                    if not red and HeroManager.GetCurHeroIsShowRedPoint(v) then
                        red = true
                    end
                end
            end
            Util.GetGameObject(tab,"Redpot"):SetActive(red)
        end
        if i == 2 then
            Util.GetGameObject(tab,"Redpot"):SetActive(false)
            for key, value in pairs(PlayerManager.heroHandBook) do
                if value.status == 0 then
                    Util.GetGameObject(tab,"Redpot"):SetActive(true)
                end
            end
        end
    end
end

return HeroMainPanel