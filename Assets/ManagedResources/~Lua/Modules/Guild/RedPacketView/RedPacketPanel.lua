----- 公会红包 -----
require("Base/BasePanel")
local RedPacketPanel = Inherit(BasePanel)
local this = RedPacketPanel

local TabBox = require("Modules/Common/TabBox")
-- local _TabImgData = {select = "N1_btn_tongyongbeibao_xuanzhong", default = "N1_btn_tongyongbeibao_weixuanzhong",}
-- local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
--                         select = Color.New(243 / 255, 235 / 255, 202 / 255, 1) }
local _TabData = {
    [1]= {txt = GetLanguageStrById(11062),img = "cn2-X1_gonghui_hongbaoyeqian"},
    [2]= {txt = GetLanguageStrById(11063),img = "cn2-X1_gonghui_kaihongbaoyeqian"},
    [3]= {txt = GetLanguageStrById(11064),img = "cn2-X1_jingjichang_paihangyeqian"},
}
--子模块脚本
this.contents = {
    --发红包
    [1] = {view = require("Modules/Guild/RedPacketView/RedPacket_SendView"), panelName = "SendView"},
    --抢红包
    [2] = {view = require("Modules/Guild/RedPacketView/RedPacket_GetView"), panelName = "GetView"},
    --排行榜
    [3] = {view = require("Modules/Guild/RedPacketView/RedPacket_RankView"), panelName = "RankView"},
}
-- this.contentPanel={}
this.sortingOrder = 0
--初始化组件（用于子类重写）
function RedPacketPanel:InitComponent()
    this.panel = Util.GetGameObject(self.gameObject, "Panel")
    this.backBtn = Util.GetGameObject(this.panel,"BackBtn")
    this.tabbox = Util.GetGameObject(this.panel, "TabBox")

    this.content = Util.GetGameObject(this.panel,"Contents")
    this.contentPanel = {}
    --预设
    for i = 1, #this.contents do
        this.contentPanel[i]=Util.GetGameObject(this.content,this.contents[i].panelName)
    end
    --脚本
    for i = 1, #this.contents do
        this.contents[i].view:InitComponent(Util.GetGameObject(this.content, this.contents[i].panelName))
    end
    this.redPoint = Util.GetGameObject(this.content,"RedPoint")
end

--绑定事件（用于子类重写）
function RedPacketPanel:BindEvent()
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RedPacketPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
    Game.GlobalEvent:AddEvent(GameEvent.GuildRedPacket.OnCloseRedPointClick, this.CloseRedPointClick)
end

--移除事件监听（用于子类重写）
function RedPacketPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildRedPacket.OnCloseRedPointClick, this.CloseRedPointClick)
end

--界面打开时调用（用于子类重写）
function RedPacketPanel:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RedPacketPanel:OnShow()
    BindRedPointObject(RedPointType.Guild_RedPacket,this.redPoint)
    CheckRedPointStatus(RedPointType.Guild_RedPacket)
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
end

--重设层级
function RedPacketPanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

--界面关闭时调用（用于子类重写）
function RedPacketPanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
    ClearRedPointObject(RedPointType.Guild_RedPacket,this.redPoint)
end

--界面销毁时调用（用于子类重写）
function RedPacketPanel:OnDestroy()
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab, "default")
    Util.GetGameObject(tab, "default/Text"):GetComponent("Text").text = _TabData[index].txt
    local select = Util.GetGameObject(tab, "select")
    Util.GetGameObject(tab, "select/Text"):GetComponent("Text").text = _TabData[index].txt
    Util.GetGameObject(tab, "select/Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].img)

    default:SetActive(status == "default")
    select:SetActive(status == "select")
end

-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    if lastIndex then
        this.CloseView(lastIndex)
    end
    this.OpenView(index)
    if index==2 then
        Game.GlobalEvent:DispatchEvent(GameEvent.GuildRedPacket.OnCloseRedPointClick)
    end
end

-- 打开View
function this.OpenView(index)
    this.contents[index].view:OnShow(this.sortingOrder)
    for i = 1, #this.contentPanel do
        this.contentPanel[i]:SetActive(i==index)
    end
end

-- 关闭View
function this.CloseView(lastIndex)
    this.contents[lastIndex].view:OnClose()
end

-- 刷新红包查看后红点点击操作
function this.CloseRedPointClick()
    GuildRedPacketManager.isCheck=false
    CheckRedPointStatus(RedPointType.Guild_RedPacket)
end

return RedPacketPanel