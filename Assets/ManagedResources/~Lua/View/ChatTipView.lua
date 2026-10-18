local ChatTipView = {}

local SYS_MSG_TYPE = {
    [0] = {name = 10384},
    [1] = {name = 10385},
    [2] = {name = 10386}
}

local VIEW_TYPE = {
    MAIN = 1,
    GUILD = 2,
}

function ChatTipView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = ChatTipView })
    return b
end

--初始化组件（用于子类重写）
function ChatTipView:InitComponent()
    self.btn = Util.GetGameObject(self.transform, "button")
    self.content = Util.GetGameObject(self.transform, "content"):GetComponent("Text")
    self.redpot = Util.GetGameObject(self.transform, "icon/redpot")
end

--绑定事件（用于子类重写）
function ChatTipView:BindEvent()
    Util.AddClick(self.btn, function()
        if self._ViewType == VIEW_TYPE.MAIN then
            UIManager.OpenPanel(UIName.ChatPanel)
        elseif self._ViewType == VIEW_TYPE.GUILD then
            UIManager.OpenPanel(UIName.ChatPanel, 2, 2)
        end
    end)
end

--添加事件监听（用于子类重写）
function ChatTipView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Chat.OnMainChatChanged, self.RefreshChatShow, self)

    BindRedPointObject(RedPointType.Chat, self.redpot)
end

--移除事件监听（用于子类重写）
function ChatTipView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Chat.OnMainChatChanged, self.RefreshChatShow, self)

    ClearRedPointObject(RedPointType.Chat, self.redpot)
end

--界面打开时调用（用于子类重写）
function ChatTipView:OnOpen(viewType)
    self._ViewType = viewType or VIEW_TYPE.MAIN
    self:RefreshChatShow()
end

-- 刷新聊天显示
-- 注意：msg.chat 可能来自世界/公会频道（无 senderName、msg 由 AnalysisGlobalChat 解析），
--       也可能来自系统频道（走配置文案 + chatparms）。任一参数为 nil 都会让 string.format 抛异常，
--       而这里在 MainPanel:InitComponent 内部被同步调用，一旦抛错会导致主界面后半段初始化全部中断。
function ChatTipView:RefreshChatShow()
    local msg = ChatManager.GetMainPanelShowMsg()
    local content = ""
    local chatData = msg and msg.chat
    if chatData then
        if msg.channel == CHAT_CHANNEL.SYSTEM then
            local sTypeInfo = SYS_MSG_TYPE[chatData.messageType]
            local desc = GetMailConfigDesc(chatData.msg, chatData.chatparms or {}) or ""
            if sTypeInfo then
                content = string.format("[%s]：%s", GetLanguageStrById(sTypeInfo.name), desc)
            else
                content = string.format(GetLanguageStrById(12071), desc)
            end
        elseif msg.channel == CHAT_CHANNEL.GLOBAL then
            local chat = ChatManager.AnalysisGlobalChat(chatData.msg)
            content = string.format(GetLanguageStrById(12072), chatData.senderName or "", chat.content or "")
        elseif msg.channel == CHAT_CHANNEL.FAMILY then
            local chat = ChatManager.AnalysisGlobalChat(chatData.msg)
            content = string.format(GetLanguageStrById(12073), chatData.senderName or "", chat.content or "")
        end
    end
    -- content 已经是本地化后的成品文本，不能再走 GetLanguageStrById（会误报"language表内未找到 id"）
    self.content.text = content
end

-- 开始聊天数据刷新
function ChatTipView:StartCheck()
    ChatManager.StartChatDataUpdate()
end
-- 停止聊天数据刷新
function ChatTipView:StopCheck()
    ChatManager.StopChatDataUpdate()
end

--界面关闭时调用（用于子类重写）
function ChatTipView:OnClose()
end

return ChatTipView