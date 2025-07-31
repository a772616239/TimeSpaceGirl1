require("Base/BasePanel")
local ChatPanel = Inherit(BasePanel)
local this = ChatPanel
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

local TabBox = require("Modules/Common/TabBox")
local _TabData = {
    {text = GetLanguageStrById(10401), channel = CHAT_CHANNEL.FRIEND, rpType = RedPointType.Chat_Friend, image = "cn2-X1_guaji_liaotiantubiao_04"},
    {text = GetLanguageStrById(10402), channel = CHAT_CHANNEL.FAMILY, image = "cn2-X1_guaji_liaotiantubiao_03"},
    {text = GetLanguageStrById(10403), channel = CHAT_CHANNEL.GLOBAL, image = "cn2-X1_guaji_liaotiantubiao_02"},
    {text = GetLanguageStrById(23004), channel = CHAT_CHANNEL.CrossRealm, image = "cn2-X1_guaji_liaotiantubiao_05"},
    {text = GetLanguageStrById(10384), channel = CHAT_CHANNEL.SYSTEM, image = "cn2-X1_guaji_liaotiantubiao_01"},
}
local txtColor = {
    default = Color.New(199/255,190/255,220/255,153/255),
    select = Color.New(255/255,209/255,43/255,255/255),
}
--  当前所在的聊天通道
this._CurChannel = CHAT_CHANNEL.GLOBAL

--初始化组件（用于子类重写）
function ChatPanel:InitComponent()
    this.tabbox = Util.GetGameObject(self.gameObject, "tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    this.scrollRoot = Util.GetGameObject(self.gameObject, "content/scrollroot")
    this.friendItem = Util.GetGameObject(self.gameObject, "content/friend")
    this.systemItem = Util.GetGameObject(self.gameObject, "content/system")
    this.chatItem = Util.GetGameObject(self.gameObject, "content/chat")

    this.input = Util.GetGameObject(self.gameObject, "bottom/input")
    this.inputText = Util.GetGameObject(self.gameObject, "bottom/input/InputField"):GetComponent("InputField")
    this.btnSend = Util.GetGameObject(self.gameObject, "bottom/input/send")
    this.btncount = Util.GetGameObject(self.gameObject, "bottom/input/count")
    this.freeCount = Util.GetGameObject(self.gameObject, "bottom/input/count/freeCount")
    -- this.freeCountText = Util.GetGameObject(self.gameObject, "bottom/input/count/freeCount/Text")
    this.buyCount = Util.GetGameObject(self.gameObject, "bottom/input/count/buyCount")
    this.buyCountText = Util.GetGameObject(self.gameObject, "bottom/input/count/buyCount/Text")

    this.noInputTip = Util.GetGameObject(self.gameObject, "bottom/tip")

    this.playerInfo = Util.GetGameObject(self.gameObject, "playerInfo")
    this.playerBg = Util.GetGameObject(this.playerInfo, "bg")
    this.playerHead = Util.GetGameObject(this.playerBg, "head"):GetComponent("Image")
    this.playerHeadKuang = Util.GetGameObject(this.playerBg, "headkuang"):GetComponent("Image")
    this.playerLv = Util.GetGameObject(this.playerBg, "lv"):GetComponent("Text")
    this.playerName = Util.GetGameObject(this.playerBg, "name"):GetComponent("Text")
    this.playerPower = Util.GetGameObject(this.playerBg, "power"):GetComponent("Text")
    this.playerInvite = Util.GetGameObject(this.playerBg, "btnInvite")
    this.playerFriend = Util.GetGameObject(this.playerBg, "btnFriend")

    this.tip = Util.GetGameObject(self.gameObject, "tip")
    this.tipTxt = Util.GetGameObject(self.gameObject, "tip/Text"):GetComponent("Text")
    this.tipTxt.text = GetLanguageStrById(50243)

    this.btnNew = Util.GetGameObject(self.gameObject, "btnNew")
end
--绑定事件（用于子类重写）
function ChatPanel:BindEvent()
    -- 关闭界面
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        -- todo:添加公会界面打开聊天，关闭时跳转至主界面的处理
        -- if this._JumpType == 1 then
        --     this:ClosePanel()
        --     UIManager.OpenPanel(UIName.MainPanel)
        -- else
            this:ClosePanel()
        -- end
    end)

    -- 发送消息
    Util.AddClick(this.btnSend, function()
        local content = this.inputText.text
        if this._CurChannel == 16 then
            local count = PrivilegeManager.GetPrivilegeRemainValue(91001)
            if count <= 0 then
                --购买提示
                if BagManager.GetItemCountById(6000126) <= 0 then
                    UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.ChatHorn })
                    return
                end
            end

        end
        ChatManager.RequestSendChatMsg(this._CurChannel, content, function()
            -- 清空聊天显示
            this.inputText.text = ""

            if this._CurChannel == 16 then
                this.freeCount:SetActive(PrivilegeManager.GetPrivilegeRemainValue(91001) > 0)
                this.buyCount:SetActive(PrivilegeManager.GetPrivilegeRemainValue(91001) <= 0)
                if PrivilegeManager.GetPrivilegeRemainValue(91001) > 0 then
                    this.freeCount:GetComponent("Text").text = string.format(GetLanguageStrById(10647),PrivilegeManager.GetPrivilegeRemainValue(91001))
                else
                    local costItem = string.split(G_SpecialConfig[155].Value,"#")
                    this.buyCount:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(G_ItemConfig[tonumber(costItem[1])].ResourceID)) 
                    this.buyCountText:GetComponent("Text").text = "x"..costItem[2]
                end
            end
            this.RefreshShow(true)
        end)
    end)

    -- 关闭玩家信息界面
    Util.AddClick(this.playerInfo, function()
        this.playerInfo:SetActive(false)
    end)

    Util.AddClick(this.btnNew, function ()
        this.RefreshShow(true)
    end)

    -- 创建一个tab管理
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetTabIsLockCheck(this.TabIsLockCheck)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData,this._CurTabIndex)
end

--添加事件监听（用于子类重写）
function ChatPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Chat.OnChatDataChanged, this.OnChatDataChanged)
end

--移除事件监听（用于子类重写）
function ChatPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Chat.OnChatDataChanged, this.OnChatDataChanged)
end

--界面打开时调用（用于子类重写）
function ChatPanel:OnOpen(...)
    -- 参数保存
    local args = {...}
    this._JumpType = args[2] or 1
    this._CurTabIndex = args[1] or 3
    this._CurChannel = _TabData[this._CurTabIndex].channel

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ChatPanel:OnShow()
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(this._CurTabIndex or 3)
    end

    -- 开始定时刷新数据
    ChatManager.StartChatDataUpdate()

    this.SetActive(this.tip, false)
    if GetChannerConfig().Chat_health_tips then
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.SetActive(this.tip, true)
        this.timer = Timer.New(function()
            if this.tipTxt.transform:GetComponent("RectTransform").rect.width > 0 then
                if this.timer then
                    this.timer:Stop()
                    this.timer = nil
                end
                this.MoveTip()
            end
        end, 1, -1)
        this.timer:Start()
    end
end

--界面关闭时调用（用于子类重写）
function ChatPanel:OnClose()
    -- 关闭定时刷新数据
    ChatManager.StopChatDataUpdate()

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function ChatPanel:OnDestroy()
    this.FriendScrollView = nil
    this.ChatScrollView = nil
    this.SystemScrollView = nil
    this.CrossRealmScrollView = nil

    -- 资源回收
    -- if this.ChatScrollView then
    --     this.ChatScrollView:RecycleNode()
    --     this.ChatScrollView = nil
    -- end
    -- -- 资源回收
    -- if this.SystemScrollView then
    --     this.SystemScrollView:RecycleNode()
    --     this.SystemScrollView = nil
    -- end

    -- 清除红点绑定
    for _, v in ipairs(_TabData) do
        if v.rpType then
            ClearRedPointObject(v.rpType)
        end
    end

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

-- tab节点自定义设置
function this.TabAdapter(tab, index, status)
    Util.GetGameObject(tab, "Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index].image)
    Util.GetGameObject(tab, "Text"):GetComponent("Text").text = _TabData[index].text

    Util.GetGameObject(tab, "select"):SetActive(status == "select")
    if status == "select" then
        Util.GetGameObject(tab, "Text"):GetComponent("Text").color = txtColor.select
        Util.GetGameObject(tab, "Image"):GetComponent("Image").color = txtColor.select
    else
        Util.GetGameObject(tab, "Text"):GetComponent("Text").color = txtColor.default
        Util.GetGameObject(tab, "Image"):GetComponent("Image").color = txtColor.default
    end

    local redpot = Util.GetGameObject(tab, "redpot")
    if _TabData[index].rpType then
        BindRedPointObject(_TabData[index].rpType, redpot)
    else
        redpot:SetActive(false)
    end
end

-- tab锁定检测
function this.TabIsLockCheck(index)
    local channel = _TabData[index].channel
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
    -- 关闭上个界面
    if lastIndex then
        local lastSV = this.GetScrollView(lastIndex)
        -- if lastIndex ~= 1 then
        --     lastSV:RecycleNode()
        -- end
        lastSV.gameObject:SetActive(false)
    end
    -- 打开当前界面
    this._CurTabIndex = index
    local curSV = this.GetScrollView(index)
    curSV.gameObject:SetActive(true)

    -- 是否能够发言
    this._CurChannel = _TabData[index].channel
    if this._CurChannel == 1 or this._CurChannel == 2 or this._CurChannel == 16 then
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.CHAT) then
            this.input:SetActive(true)
            this.noInputTip:SetActive(false)
            if this._CurChannel == 16 then
                this.btncount:SetActive(true)
                this.freeCount:SetActive(PrivilegeManager.GetPrivilegeRemainValue(91001) > 0)
                this.buyCount:SetActive(PrivilegeManager.GetPrivilegeRemainValue(91001) <= 0)
                if PrivilegeManager.GetPrivilegeRemainValue(91001)>0 then
                    this.freeCount:GetComponent("Text").text = string.format(GetLanguageStrById(10647),PrivilegeManager.GetPrivilegeRemainValue(91001))
                else
                    local costItem = string.split(G_SpecialConfig[155].Value,"#")
                    this.buyCount:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(G_ItemConfig[tonumber(costItem[1])].ResourceID)) 
                    this.buyCountText:GetComponent("Text").text = "x"..costItem[2]
                end
            else
                this.btncount:SetActive(false)
            end
        else
            this.input:SetActive(false)
            this.noInputTip:SetActive(true)
            this.noInputTip:GetComponent("Text").text = GetLanguageStrById(10387)
        end
    elseif this._CurChannel == 0 or this._CurChannel == 3 then
        this.input:SetActive(false)
        this.noInputTip:SetActive(true)
        this.noInputTip:GetComponent("Text").text = GetLanguageStrById(10406)
    end

    -- 刷新显示
    this.RefreshShow(true)
end

-- 数据变化回调
function this.OnChatDataChanged(channel)
    if channel == this._CurChannel then
        this.RefreshShow(false)
    end
end

-- 刷新当前显示
function this.RefreshShow(isForceBottom)
    -- 刷新数据
    local curSV = this.GetScrollView(this._CurTabIndex)
    local datalist = ChatManager.GetChatList(this._CurChannel)
    local _GoToIndex = nil
    if this._CurChannel ~= CHAT_CHANNEL.FRIEND then
        _GoToIndex = #datalist
    end
 
    curSV:SetData(datalist, function(dataIndex, go)
        -- 判断是否要显示聊天的时间
        local isShowTime = false
        if dataIndex == 1 then
            isShowTime = true
        elseif dataIndex > 1 then
            local deltaTime = datalist[dataIndex].times - datalist[dataIndex - 1].times
            isShowTime = deltaTime >= ChatManager.ShowTimeDT
        end
        -- 设置数据
        local data = datalist[dataIndex]
        if this._CurChannel == CHAT_CHANNEL.FRIEND then
            this.FriendItemAdapter(go, data)
        elseif this._CurChannel == CHAT_CHANNEL.SYSTEM then
            this.SystemItemAdapter(go, data, isShowTime)
        -- elseif this._CurChannel == CHAT_CHANNEL.CrossRealm then
        --     this.CrossRealmChatItemAdapter(go, data, isShowTime)
        else
            this.ChatItemAdapter(go, data, isShowTime, this._CurChannel == CHAT_CHANNEL.CrossRealm)
        end
    end)--, _GoToIndex)


    if isForceBottom and _GoToIndex then
        curSV:SetIndex(_GoToIndex)
    end
    this.btnNew:SetActive(not isForceBottom)

    -- 好友数据置顶
    if this._CurChannel == CHAT_CHANNEL.FRIEND then
        curSV:SetIndex(1)
    end
end

-- 创建滚动列表
function this.GetScrollView(index)
    -- 不存在则创建
    if index == 1 then
        
        -- 判断是否存在
        if not this.FriendScrollView then
            local rootHight = this.scrollRoot.transform.rect.height
            local sv = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
                    this.friendItem, nil, Vector2.New(1080, rootHight - 10), 1, 1, Vector2.New(0, 10))
            sv.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, -5)
            sv.moveTween.Strength = 2
            -- 保存
            this.FriendScrollView = sv
        end
        return this.FriendScrollView

    elseif index == 2 or index == 3 then
        if not this.ChatScrollView then
            local rootHight = this.scrollRoot.transform.rect.height
            local sv = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.scrollRoot.transform,
                    this.chatItem, Vector2.New(1080, rootHight - 10), 1, 10)
            sv.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, -5)
            sv.moveTween.Strength = 2
            -- 保存
            this.ChatScrollView = sv
        end
        return this.ChatScrollView

    elseif index == 5 then
        if not this.SystemScrollView then
            local rootHight = this.scrollRoot.transform.rect.height
            local sv = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.scrollRoot.transform,
                    this.systemItem, Vector2.New(980, rootHight - 10), 1, 20)
            sv.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, -5)
            sv.moveTween.Strength = 2
            -- 保存
            this.SystemScrollView = sv
        end
        return this.SystemScrollView
    elseif index == 4 then
        if not this.CrossRealmScrollView then
            local rootHight = this.scrollRoot.transform.rect.height
            local sv = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.scrollRoot.transform,
                    this.chatItem, Vector2.New(1080, rootHight - 10), 1, 10)
            sv.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, -5)
            sv.moveTween.Strength = 2
            -- 保存
            this.CrossRealmScrollView = sv
        end
        return this.CrossRealmScrollView
    end
end

-- 好友节点数据匹配
function this.FriendItemAdapter(node, data)
    -- 获取节点
    local bg = Util.GetGameObject(node, "head")
    local content = Util.GetGameObject(node, "content"):GetComponent("Text")
    local name = Util.GetGameObject(node, "name"):GetComponent("Text")
    local lv = Util.GetGameObject(node, "lv"):GetComponent("Text")
    local head = Util.GetGameObject(node, "head"):GetComponent("Image")
    local frame = Util.GetGameObject(node, "headkuang"):GetComponent("Image")
    local redpot = Util.GetGameObject(node, "redpot")
    local CH = Util.GetGameObject(node, "name/title"):GetComponent("Image")
    local CHison = Util.GetGameObject(node, "name/title")
    -- 数据匹配
    local fdata = GoodFriendManager.GetFriendInfo(data.friendId)
    -- if data.chenghao > 0 then
    --     this.SetActive(CHison,true)
    --     CH.sprite = this.GetTitleIcon(data.chenghao)            
    -- else
    --     this.SetActive(CHison,false)
    -- end

    content.text = GetLanguageStrById(data.content)

    name.text = fdata.name
    lv.text = fdata.lv
    head.sprite = GetPlayerHeadSprite(fdata.head)
    frame.sprite = GetPlayerHeadFrameSprite(fdata.frame)
    redpot:SetActive(FriendChatManager.IsFriendNewChat(data.friendId))
    redpot:SetActive(false)
    -- 头像添加点击事件
    Util.AddOnceClick(bg, function()
        UIManager.OpenPanel(UIName.FriendChatPanel, data.friendId)
    end)
end

-- 系统消息节点数据匹配
function this.SystemItemAdapter(node, data, isShowTime)
    local time = Util.GetGameObject(node, "time")
    local bg = Util.GetGameObject(node, "bg")
    local content = Util.GetGameObject(node, "bg/content"):GetComponent("Text")
    local sType = Util.GetGameObject(node, "type/type")
    local sTypeStr = Util.GetGameObject(node, "type/type/Text"):GetComponent("Text")

    isShowTime = false
    time:SetActive(isShowTime)
    if isShowTime then
        time:GetComponent("Text").text = TimeStampToDateStr(tonumber(data.times)/1000)
    end

    local sTypeInfo = ChatManager.SYS_MSG_TYPE[data.messageType]
    if sTypeInfo then
        this.SetActive(sType,true)
        sTypeStr.text = sTypeInfo.name
        content.text = GetMailConfigDesc(data.msg,data.chatparms)
    else
        this.SetActive(sType,false)
        content.text = GetMailConfigDesc(data.msg,data.chatparms)
    end

    Util.AddOnceClick(bg, function()
        -- 内容包含异妖的不显示
        local pos = string.find(data.msg, GetLanguageStrById(10407))
        if pos then return end
        -- 其他的按物品显示
        local itemDataConFig = itemConfig[data.itemId]
        if not itemDataConFig then return end
        if itemDataConFig.ItemType == ItemType.Hero then
            local heroConfigData = ConfigManager.GetConfigData(ConfigName.HeroConfig, itemConfig[data.itemId].HeroStar[1])
            LogGreen("HeroStar:"..itemConfig[data.itemId].HeroStar[1])
            UIManager.OpenPanel(UIName.RoleGetInfoPopup,false,heroConfigData.Id,itemConfig[data.itemId].HeroStar[2])
        elseif itemDataConFig.ItemType == ItemType.Equip then
            UIManager.OpenPanel(UIName.HandBookEquipInfoPanel, data.itemId)
        else
            LogGreen("itemId:"..data.itemId)
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, data.itemId)
        end
    end)
end

-- 聊天节点数据匹配
function this.ChatItemAdapter(node, data, isShowTime, isShowServerName)
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
    -- local lv = Util.GetGameObject(node, "base/lv"):GetComponent("Text")
    local name = Util.GetGameObject(node, "contentroot/bg/info/name/name"):GetComponent("Text")
    local zw = Util.GetGameObject(node, "contentroot/bg/info/pos")
    local zwName = Util.GetGameObject(node, "contentroot/bg/info/pos/pos/Text"):GetComponent("Text")
	local CH = Util.GetGameObject(node, "contentroot/bg/info/title/title"):GetComponent("Image")
	local CHison = Util.GetGameObject(node, "contentroot/bg/info/title")
    local vip = Util.GetGameObject(node, "base/vip"):GetComponent("Image")

    -- 判断是否显示时间
    time:SetActive(isShowTime)
    if isShowTime then
        timeLab.text = TimeStampToDateStr(tonumber(data.times)/1000)
    end

    zw:SetActive(false)

    local contentStr = ""
    if this._CurChannel == CHAT_CHANNEL.GLOBAL then
        local chat = ChatManager.AnalysisGlobalChat(data.msg)
        contentStr = chat.content
        if chat.type == GLOBAL_CHAT_TYPE.COMMON then
            Util.AddOnceClick(content.gameObject, function() end)
        elseif chat.type == GLOBAL_CHAT_TYPE.GUILD_INVITE then
            Util.AddOnceClick(content.gameObject, function()
                if PlayerManager.familyId ~= 0 then
                    PopupTipPanel.ShowTip(GetLanguageStrById(10408))
                    return
                end
                --local _IsInFight = GuildFightManager.IsInGuildFight()
                --if _IsInFight then
                --    PopupTipPanel.ShowTip("公会战期间无法加入公会")
                --    return
                --end
                MsgPanel.ShowTwo(string.format(GetLanguageStrById(10409), chat.gName),nil, function()
                    if PlayerManager.level < chat.gLimitLv then
                        PopupTipPanel.ShowTip(GetLanguageStrById(10410))
                        return
                    end
                    if chat.joinType == GUILD_JOIN_TYPE.NO_LIMIT then
                        GuildManager.RequestJoinGuild(chat.gId, function ()
                            -- 关闭当前界面
                            if this._JumpType == 1 then
                                this:ClosePanel()
                                UIManager.OpenPanel(UIName.MainPanel)
                            else
                                this:ClosePanel()
                            end
                            -- 打开公会主城
                            UIManager.OpenPanel(UIName.GuildMainCityPanel)
                            PopupTipPanel.ShowTip(GetLanguageStrById(10411))
                        end)
                    elseif chat.joinType == GUILD_JOIN_TYPE.LIMIT then
                        GuildManager.RequestApplyManyGuilds({chat.gId}, function()
                            PopupTipPanel.ShowTip(GetLanguageStrById(10412))
                        end)

                    elseif chat.joinType == GUILD_JOIN_TYPE.FORBID then
                        PopupTipPanel.ShowTip(GetLanguageStrById(10413))
                    end
                end)
            end)
        end

    elseif this._CurChannel == CHAT_CHANNEL.FAMILY then
        local chat = ChatManager.AnalysisGlobalChat(data.msg)
        contentStr = chat.content
        if chat.type == GLOBAL_CHAT_TYPE.COMMON then
            Util.AddOnceClick(content.gameObject, function() end)
        elseif chat.type == GLOBAL_CHAT_TYPE.GUILD_REDPACKET then
            contentStr = chat.content
        elseif chat.type == GLOBAL_CHAT_TYPE.GUILD_AID then
            Util.AddOnceClick(content.gameObject, function()
                JumpManager.GoJump(72001)
            end)
        end

        --只在公会频道显示职务
        if data.job and data.job > 0 then
            zwName.text = JobString[data.job]
            zw:SetActive(true)
        end
    else
        contentStr = GetMailConfigDesc(data.msg,data.chatparms)
    end


    -- 基础信息
    content.text = contentStr
    if data.senderId == PlayerManager.uid then
        if isShowServerName then
            name.text = PlayerManager.nickName .. "[Lv." .. PlayerManager.level .. "]" .. "<color='#9fff88'>    [" .. data.serverName .. "]</color>"
        else
            name.text = PlayerManager.nickName .. "[Lv." .. PlayerManager.level .. "]"
        end
        head.sprite = GetPlayerHeadSprite(PlayerManager.head)
        headKuang.sprite = GetPlayerHeadFrameSprite(PlayerManager.frame)
        if VipManager.GetVipLevel() > 0 then
            if PlayerManager.isShowVip then
                this.SetActive(vip.gameObject,true)
                vip.sprite = Util.LoadSprite("T_vip_".. VipManager.GetVipLevel() .. "_meisuzi")
            else
                this.SetActive(vip.gameObject,false)
            end
        else
            this.SetActive(vip.gameObject,false)
        end
        if PlayerManager.designation > 0 then
            this.SetActive(CHison,true)
            CH.sprite = this.GetTitleIcon(PlayerManager.designation)
        else
            this.SetActive(CHison,false)
        end
    else
        if isShowServerName then
            name.text = data.senderName .. "[Lv." .. data.senderlevel .. "]" .. "<color='#9fff88'>    [" .. data.serverName .. "]</color>"
        else
            name.text = data.senderName .. "[Lv." .. data.senderlevel .. "]"
        end
        head.sprite = GetPlayerHeadSprite(data.head)
        headKuang.sprite = GetPlayerHeadFrameSprite(data.frame)
        if data.sendervip > 0 then
            if data.showVip then
                this.SetActive(vip.gameObject,true)
                vip.sprite = Util.LoadSprite("T_vip_".. data.sendervip .. "_meisuzi")
            else
                this.SetActive(vip.gameObject,false)
            end
        else
            this.SetActive(vip.gameObject,false)
        end
        if data.chenghao > 0 then
            this.SetActive(CHison,true)
            CH.sprite = this.GetTitleIcon(data.chenghao)
        else
            this.SetActive(CHison,false)
        end
    end

    -- 头像添加点击事件
    Util.AddOnceClick(head.gameObject, function()
        if this._CurChannel == CHAT_CHANNEL.CrossRealm then
            return
        end
        -- 自己不做任何操作
        if data.senderId ~= PlayerManager.uid then
            this.playerFriend:SetActive(true)
            for i,v in pairs(GoodFriendManager.friendAllData) do
                if i == data.senderId and v ~= nil then
                    this.SetActive(this.playerFriend,false)
                end
            end
            --this.ShowPlayerInfo(node, data)
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.senderId)
        end
    end)
end

function this.GetTitleIcon(title)
    local titleData = ConfigManager.GetConfigData("TitleConfig", title)
    if not titleData then
        LogError("未找到Title:" .. title)
        return ""
    end

    return Util.LoadSprite(ConfigManager.GetConfigData("ArtResourcesConfig", titleData.TitleImage).Name)
end

--- 显示玩家信息
function this.ShowPlayerInfo(node, data)
    -- 显示
    this.SetActive(this.playerInfo,true)
    -- 设置位置
    local v2 = RectTransformUtility.WorldToScreenPoint(UIManager.camera, node.transform.position)
    this.playerBg.transform.localPosition = Vector3(v2.x + 200, v2.y, 0)
    -- 设置内容
    this.playerLv.text = data.senderlevel
    this.playerName.text = data.senderName
    this.playerPower.text = data.soulVal
    this.playerHead.sprite = GetPlayerHeadSprite(data.head)
    this.playerHeadKuang.sprite = GetPlayerHeadFrameSprite(data.frame)

    -- 邀请加入公会
    Util.AddOnceClick(this.playerInvite, function()
        PopupTipPanel.ShowTip(GetLanguageStrById(10414))
    end)

    -- 添加好友
    Util.AddOnceClick(this.playerFriend, function()
        GoodFriendManager.InviteFriendRequest(data.senderId, function()
            PopupTipPanel.ShowTip(GetLanguageStrById(10415))
            this.SetActive(this.playerInfo,false)
        end)
    end)
end

function this.MoveTip()
    this.SetActive(this.tip, true)

    local tipRect = this.tipTxt.transform:GetComponent("RectTransform")
    tipRect.anchoredPosition3D = Vector3.New(0, 0, 0)
    local finalPos = 1080 + tipRect.rect.width

    DoTween.To(DG.Tweening.Core.DOGetter_int(function()
        return 0
    end),
    DG.Tweening.Core.DOSetter_int(function(progress)
        tipRect.anchoredPosition3D = Vector3.New(0 - progress, 0, 0)
    end),
    finalPos,
    finalPos/100):SetEase(Ease.Linear):OnComplete(function()
        this.SetActive(this.tip, false)
    end)
end

function this.SetActive(go, value)
    if value and not go.activeSelf then
        go:SetActive(value)
    elseif not value and go.activeSelf then
        go:SetActive(value)
    end
end

return ChatPanel