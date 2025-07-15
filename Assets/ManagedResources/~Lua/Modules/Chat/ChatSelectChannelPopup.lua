require("Base/BasePanel")
local ChatSelectChannelPopup = Inherit(BasePanel)
local this = ChatSelectChannelPopup

local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        lock = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1) }
local _TabImage = { default = Color.New(255/255, 208/255, 43/255, 1),  lock = Color.New(120/255, 120/255, 120/255, 1),  select =  Color.New(0/255, 255/255, 17/255, 1)}

function this:InitComponent()
    this.tabbox = Util.GetGameObject(self.gameObject, "tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    -- 关闭界面
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)

    -- 创建一个tab管理
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetTabIsLockCheck(this.TabIsLockCheck)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, ChatManager._TabData,ChatManager.GetCurSelectChannel())
end
--添加事件监听（用于子类重写）
function this:AddListener()
    --Game.GlobalEvent:AddEvent(GameEvent.Chat.OnChatDataChanged, this.OnChatDataChanged)
end
--移除事件监听（用于子类重写）
function this:RemoveListener()
    --Game.GlobalEvent:RemoveEvent(GameEvent.Chat.OnChatDataChanged, this.OnChatDataChanged)
end
--界面打开时调用（用于子类重写）
function this:OnOpen()

end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(ChatManager.GetCurSelectChannel())
    end
end
--界面关闭时调用（用于子类重写）
function this:OnClose()
    -- 关闭定时刷新数据
end
--界面销毁时调用（用于子类重写）
function this:OnDestroy()

end


-- tab节点自定义设置
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    tabLab:GetComponent("Text").text = ChatManager._TabData[index].text
    tabLab:GetComponent("Text").color = _TabFontColor[status]
    local tabImg = Util.GetGameObject(tab, "Image")
    --tabImg:GetComponent("Image").sprite = Util.LoadSprite(_TabImage[status])
    tabImg:GetComponent("Image").color = _TabImage[status]

    local redpot = Util.GetGameObject(tab, "redpot")
    if ChatManager._TabData[index].rpType then
        BindRedPointObject(ChatManager._TabData[index].rpType, redpot)
    else
        redpot:SetActive(false)
    end
end


-- tab锁定检测
function this.TabIsLockCheck(index)
    local channel = ChatManager._TabData[index].channel
    if channel == CHAT_CHANNEL.FAMILY then
        local isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD)
        if not isOpen then
            return true, GetLanguageStrById(10404)
        end
        if isOpen and PlayerManager.familyId == 0 then
            return true, GetLanguageStrById(10405)
        end
    end
    return false
end

-- 节点状态改变回调事件
function this.OnTabChange(index, lastIndex)
    ChatManager.SetCurSelectChannel(index)
end


return ChatSelectChannelPopup