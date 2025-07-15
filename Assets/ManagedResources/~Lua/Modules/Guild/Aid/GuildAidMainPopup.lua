require("Base/BasePanel")
GuildAidMainPopup = Inherit(BasePanel)
local this = GuildAidMainPopup
local curIndex = 1
local TabBox = require("Modules/Common/TabBox")
local _TabData={ [1] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10999) },
                 [2] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(11000) },
                 [3] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(11001) }, }
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1)}
this.contents = {
    [1] = {view = require("Modules/Guild/Aid/GuildAid_MyAid"), panelName = "GuildAid_MyAid"},
    [2] = {view = require("Modules/Guild/Aid/GuildAid_GuildAid"), panelName = "GuildAid_GuildAid"},
    [3] = {view = require("Modules/Guild/Aid/GuildAid_AidRecord"), panelName = "GuildAid_AidRecord"},
}
local redPointList = {}

--初始化组件（用于子类重写）
function GuildAidMainPopup:InitComponent()
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.TabCtrl = TabBox.New()
    this.BackBtn = Util.GetGameObject(self.gameObject, "bg/btnBack")

    --预设赋值
    this.prefabs = {}
    for i=1,#this.contents do
        this.prefabs[i]=Util.GetGameObject(self.gameObject,"bg/panel/"..this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, "bg/panel"))
    end

end

--绑定事件（用于子类重写）
function GuildAidMainPopup:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function GuildAidMainPopup:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function GuildAidMainPopup:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function GuildAidMainPopup:OnOpen(_curIndex)
    curIndex = _curIndex or 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildAidMainPopup:OnShow()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
    redPointList = {}
    for i = 1, Util.GetGameObject(this.tabBox,"box").transform.childCount do
        redPointList[i] =Util.GetGameObject(Util.GetGameObject(this.tabBox,"box").transform:GetChild(i-1).gameObject,"Redpot")
        redPointList[i]:SetActive(false)
    end
    if redPointList[1] and redPointList[2] then
        BindRedPointObject(RedPointType.Guild_AidMy, redPointList[1])
        BindRedPointObject(RedPointType.Guild_AidGuild, redPointList[2])
    end
end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end
--切换视图
function this.SwitchView(index)
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect~=0 then this.contents[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --执行子模块初始化
    this.contents[index].view:OnShow(this)
end
--界面关闭时调用（用于子类重写）
function GuildAidMainPopup:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
    ClearRedPointObject(RedPointType.Guild_AidMy)
    ClearRedPointObject(RedPointType.Guild_AidGuild)
end

--界面销毁时调用（用于子类重写）
function GuildAidMainPopup:OnDestroy()
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
    ClearRedPointObject(RedPointType.Guild_AidMy)
    ClearRedPointObject(RedPointType.Guild_AidGuild)
end

return GuildAidMainPopup