require("Base/BasePanel")
local FriendChatPanel = Inherit(BasePanel)
local this = FriendChatPanel

--初始化组件（用于子类重写）
function FriendChatPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "rightUp/btnBack")

    this.friendName = Util.GetGameObject(self.gameObject, "content/friendname")

    this.scrollRoot = Util.GetGameObject(self.gameObject, "content/scrollroot")
    this.chatItem = Util.GetGameObject(self.gameObject, "content/chat")

    this.input = Util.GetGameObject(self.gameObject, "bottom/input")
    this.inputText = Util.GetGameObject(self.gameObject, "bottom/input/InputField"):GetComponent("InputField")
    this.btnSend = Util.GetGameObject(self.gameObject, "bottom/input/send")

    this.noInputTip = Util.GetGameObject(self.gameObject, "bottom/tip")

    -- 上部货币显示
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft})
    this.BtView =SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)

end

--绑定事件（用于子类重写）
function FriendChatPanel:BindEvent()
    -- 关闭界面
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        UIManager.ClosePanel(UIName.FriendChatPanel)
    end)
    -- 发送消息
    Util.AddClick(this.btnSend, function()
        if not GoodFriendManager.IsMyFriend(this.friendId) then
            PopupTipPanel.ShowTipByLanguageId(10416)
            return
        end
        local content = this.inputText.text
        FriendChatManager.RequestSendChatMsg(this.friendId, content, function()
            this.inputText.text = ""
        end)
    end)
end
--添加事件监听（用于子类重写）
function FriendChatPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Chat.OnChatDataChanged, this.OnChatDataChanged)
end
--移除事件监听（用于子类重写）
function FriendChatPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Chat.OnChatDataChanged, this.OnChatDataChanged)
end
--界面打开时调用（用于子类重写）
function FriendChatPanel:OnOpen(friendId)
    this.friendId = friendId
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FriendChatPanel:OnShow()
    -- 获取任务名称
    this.friendData = GoodFriendManager.GetFriendInfo(this.friendId)
    if not this.friendData then return end
    this.friendName:GetComponent("Text").text = this.friendData.name
    -- 刷新显示
    this.RefreshShow(true)
    -- 货币界面
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    this.BtView:OnOpen({sortOrder = self.sortingOrder,panelType = PanelTypeView.MainCity})

end
--界面关闭时调用（用于子类重写）
function FriendChatPanel:OnClose()
    -- 设置好友消息不再是新消息
    FriendChatManager.SetFriendNewChatState(this.friendId, false)
end
--界面销毁时调用（用于子类重写）
function FriendChatPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.BtView)

    -- 资源回收
    this.ChatScrollView = nil
    --if this.ChatScrollView then
    --    this.ChatScrollView:RecycleNode()
    --    this.ChatScrollView = nil
    --end
end

-- 数据变化回调
function this.OnChatDataChanged(channel, friendId)
    if channel == CHAT_CHANNEL.FRIEND and friendId == this.friendId then
        this.RefreshShow(false)
    end
end

-- 刷新显示
function this.RefreshShow(isForceBottom)
    if not this.ChatScrollView then
        local rootHight = this.scrollRoot.transform.rect.height
        local sv = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.scrollRoot.transform,
                this.chatItem, Vector2.New(1080, rootHight - 10), 1, 10)
        sv.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, -5)
        sv.moveTween.Strength = 5
        -- 保存
        this.ChatScrollView = sv
    end

    local friendChatList = FriendChatManager.GetFriendChatList(this.friendId)
    this.ChatScrollView:SetData(friendChatList, function(dataIndex, go)
        -- 判断是否要显示聊天的时间
        local isShowTime = false
        if dataIndex == 1 then
            isShowTime = true
        elseif dataIndex > 1 then
            local deltaTime = friendChatList[dataIndex].times - friendChatList[dataIndex - 1].times
            isShowTime = deltaTime >= ChatManager.ShowTimeDT
        end
        this.ChatItemAdapter(go, friendChatList[dataIndex], isShowTime)
    end, #friendChatList)
    -- 滚动到最下面
    --this.ChatScrollView:ScrollToBottom(isForceBottom)
end

-- 聊天节点数据匹配
function this.ChatItemAdapter(node, data, isShowTime)
    local right = Util.GetGameObject(node, "rightchat")
    local left = Util.GetGameObject(node, "leftchat")
    local isMyChat = data.senderId == PlayerManager.uid
    right:SetActive(isMyChat)
    left:SetActive(not isMyChat)
    node = isMyChat and right or left

    local time = Util.GetGameObject(node, "time")
    local timeLab = Util.GetGameObject(node, "time/Text"):GetComponent("Text")
    local content = Util.GetGameObject(node, "contentroot/bg/content"):GetComponent("Text")
    local head = Util.GetGameObject(node, "base/head"):GetComponent("Image")
    local headKuang = Util.GetGameObject(node, "base/headkuang"):GetComponent("Image")
    local lv = Util.GetGameObject(node, "base/lv"):GetComponent("Text")
    local name = Util.GetGameObject(node, "base/name"):GetComponent("Text")
    local zw = Util.GetGameObject(node, "base/zhiwei")
    local zwName = Util.GetGameObject(node, "base/zhiwei/Text"):GetComponent("Text")

    -- 判断是否显示时间
    time:SetActive(isShowTime)
    if isShowTime then
        timeLab.text = TimeStampToDateStr(tonumber(data.times)/1000)
    end

    content.text = data.msg
    if data.senderId == PlayerManager.uid then
        lv.text = PlayerManager.level
        name.text = PlayerManager.nickName
        head.sprite = GetPlayerHeadSprite(PlayerManager.head)
        headKuang.sprite = GetPlayerHeadFrameSprite(PlayerManager.frame)
    else
        lv.text = this.friendData.lv
        name.text = this.friendData.name
        head.sprite = GetPlayerHeadSprite(this.friendData.head)
        headKuang.sprite = GetPlayerHeadFrameSprite(this.friendData.frame)
    end

    -- 头像添加点击事件，屏蔽
    Util.AddOnceClick(head.gameObject, function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup,data.senderId)
    end)
    Util.AddOnceClick(content.gameObject, function()end)

    zw:SetActive(false)
end

return FriendChatPanel