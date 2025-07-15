require("Base/BasePanel")
local GuildFindPopup = Inherit(BasePanel)
local this = GuildFindPopup
local _GuildApplyStatusStr = {
    [GUILD_JOIN_TYPE.NO_LIMIT] = GetLanguageStrById(10891),
    [GUILD_JOIN_TYPE.LIMIT] = GetLanguageStrById(10892),
    [GUILD_JOIN_TYPE.FORBID] = GetLanguageStrById(10893),
}
local needDataList={}
this._RefreshCD = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).RefreshCd
this._RefreshStamp = 0
--初始化组件（用于子类重写）
function GuildFindPopup:InitComponent()
    -- this.title2 = Util.GetGameObject(self.transform, "Title/text"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.btnSearch = Util.GetGameObject(self.transform, "bottomImage/searchButton")
    this.btnRefresh = Util.GetGameObject(self.transform, "bottomImage/refreshButton")
    this.btnCreate = Util.GetGameObject(self.transform, "bottomImage/createBtn")
    this.btnAdd = Util.GetGameObject(self.transform, "bottomImage/addBtn")
    this.input = Util.GetGameObject(self.transform, "bottomImage/InputField"):GetComponent("InputField")
    this.scrollRoot = Util.GetGameObject(self.transform, "scrollpos")
    this.item = Util.GetGameObject(self.transform, "scrollpos/item")
    this.UnfullFilter=Util.GetGameObject(self.transform,"bottomImage/UnfullFilter"):GetComponent("Toggle")

    local height = this.scrollRoot.transform.rect.height
    local width = this.scrollRoot.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
            this.item, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,5))
    -- this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    -- this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function GuildFindPopup:BindEvent()
    --
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    -- 搜索
    Util.AddClick(this.btnSearch, function()
        local name = this.input.text
        if name == "" then
            this.input.text = ""
            this.RefreshRecommandList()
            PopupTipPanel.ShowTipByLanguageId(10894)
            return
        end
        GuildManager.RequestSearchGuild(name, function()
            this.SetListType(2)
        end)
    end)

    -- 刷新
    Util.AddClick(this.btnRefresh, function()
        local curTimeStamp = GetTimeStamp()
        local cd = this._RefreshCD - (curTimeStamp - this._RefreshStamp)
        if cd > 0 then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10895), cd))
            return
        end
        this.input.text = ""
        this.RefreshRecommandList()
        this._RefreshStamp = curTimeStamp
    end)

    -- 创建
    Util.AddClick(this.btnCreate, function()
        UIManager.OpenPanel(UIName.GuildCreatePopup, function()
            this:ClosePanel()
        end)
    end)
    
    --隐藏满员军团
    this.UnfullFilter.onValueChanged:AddListener(function(state)
        if state then
            local dataList = this.FilterData(needDataList)
            this.ScrollView:SetData(dataList, function(index, go)
                this.GuildItemAdapter(go, dataList[index])
            end)
        else
            this.ScrollView:SetData(needDataList, function(index, go)
                this.GuildItemAdapter(go, needDataList[index])
            end)
        end
    end)
    -- 一键加入
    Util.AddClick(this.btnAdd, function()
        --local _IsInFight = GuildFightManager.IsInGuildFight()
        --if _IsInFight then
        --    PopupTipPanel.ShowTip("公会战期间无法加入公会")
        --    return
        --end
        local list = nil
        if this._ListType == 1 then
            list = GuildManager.GetRecommandGuildList()
        elseif this._ListType == 2 then
            list = GuildManager.GetSearchGuildList()
        end
        if not list or #list == 0 then
            PopupTipPanel.ShowTipByLanguageId(10896)
            return
        end
        -- 遍历列表获取符合条件的公会
        local operateType = 1   -- 操作类型  1  申请  2 加入
        local applyGuildIdList = {}
        local joinGuild = nil
        for i = 1, #list do
            local data = list[i]
            if data.isApply == GUILD_APPLY_STATUS.NO_APPLY then
                local guildData = data.familyBaseInfo
                if guildData.joinType == GUILD_JOIN_TYPE.NO_LIMIT then
                    if guildData.totalNum < guildData.maxNum and PlayerManager.level >= guildData.playerIntoLevel then
                        if not joinGuild or joinGuild.levle < guildData.levle then
                            joinGuild = guildData
                            operateType = 2
                        end
                    end
                elseif guildData.joinType == GUILD_JOIN_TYPE.LIMIT then
                    if guildData.totalNum < guildData.maxNum and PlayerManager.level >= guildData.playerIntoLevel then
                        table.insert(applyGuildIdList, guildData.id)
                    end
                end
            end
        end

        -- 跟据类型执行操作
        if operateType == 1 then
            -- 申请公会
            if #applyGuildIdList == 0 then
                PopupTipPanel.ShowTipByLanguageId(10896)
                return
            end
            GuildManager.RequestApplyManyGuilds(applyGuildIdList, function()
                -- 刷新下显示
                this.SetListType(this._ListType)
                PopupTipPanel.ShowTipByLanguageId(10823)
            end)
        elseif operateType == 2 then
            --加入公会
            if not joinGuild then
                PopupTipPanel.ShowTipByLanguageId(10896)
                return
            end
            GuildManager.RequestJoinGuild(joinGuild.id, function ()
                this.JoinGuildSuccess()
            end)
        end


    end)
end

--添加事件监听（用于子类重写）
function GuildFindPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.JoinGuildSuccess, this.CloseSelf)
end

--移除事件监听（用于子类重写）
function GuildFindPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.JoinGuildSuccess, this.CloseSelf)
end

--界面打开时调用（用于子类重写）
function GuildFindPopup:OnOpen(...)
    this._ListType = nil
    this.UnfullFilter.isOn = false
    -- 刷新推荐列表
    this.RefreshRecommandList()

    -- 控制挂机界面伤害文字显示
    FightPointPassManager.isBeginFight = true
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFindPopup:OnShow()
end

-- 关闭界面
function this.CloseSelf()
    this:ClosePanel()
end

-- 刷新推荐列表
function this.RefreshRecommandList()
    GuildManager.RequestRecommandGuildList(function()
        this.SetListType(1)
    end)
end

-- 公会节点数据匹配
function this.GuildItemAdapter(item, data)
    -- item:SetActive(true)
    local head = Util.GetGameObject(item, "head"):GetComponent("Image")
    local nameText = Util.GetGameObject(item, "name"):GetComponent("Text")
    local announceText = Util.GetGameObject(item, "content"):GetComponent("Text")
    local membersText = Util.GetGameObject(item, "num"):GetComponent("Text")
    local limitText = Util.GetGameObject(item, "limit/Text"):GetComponent("Text")
    local btn = Util.GetGameObject(item, "btn")
    local btnStr = Util.GetGameObject(item, "btn/text"):GetComponent("Text")

    -- 基础信息
    local guildData = data.familyBaseInfo
    local gName = guildData.name
    --if string.len(gName) > 15 then
    --    gName = SubString(gName, 5).."..."
    --end
    nameText.text = gName
    announceText.text = guildData.annouce
    head.sprite = Util.LoadSprite(GuildManager.GetLogoResName(guildData.icon))
    local curGuildLevelInfo = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, guildData.levle)
    local maxMemNum = curGuildLevelInfo.Num
    membersText.text = string.format("%s/%s", guildData.totalNum, maxMemNum)
    limitText.text = guildData.playerIntoLevel

    -- 按钮显示
    local _AddType = guildData.joinType
    local _IsApply = data.isApply == GUILD_APPLY_STATUS.APPLY
    local _IsForbid = _AddType == GUILD_JOIN_TYPE.FORBID
    --local _IsInFight = GuildFightManager.IsInGuildFight()
    Util.SetGray(btn, _IsForbid or _IsApply)-- or _IsInFight)
    btnStr.text = _IsApply and GetLanguageStrById(10898) or _GuildApplyStatusStr[_AddType]

    -- 按钮监听事件
    Util.AddOnceClick(btn, function()
        if _IsForbid then
            PopupTipPanel.ShowTipByLanguageId(10899)
            return
        end
        if _IsApply then
            PopupTipPanel.ShowTipByLanguageId(10900)
            return
        end
        --if _IsInFight then
        --    PopupTipPanel.ShowTip("公会战期间无法加入公会")
        --    return
        --end
        if guildData.totalNum >= maxMemNum then
            PopupTipPanel.ShowTipByLanguageId(10901)
            return
        end
        if PlayerManager.level < guildData.playerIntoLevel then
            PopupTipPanel.ShowTipByLanguageId(10410)
            return
        end

        -- 根据加入类型不同执行不同操作
        if _AddType == GUILD_JOIN_TYPE.NO_LIMIT then
            GuildManager.RequestJoinGuild(guildData.id, function ()
                this.JoinGuildSuccess()
            end)
        elseif _AddType == GUILD_JOIN_TYPE.LIMIT then
            GuildManager.RequestApplyManyGuilds({guildData.id}, function()
                -- 刷新下显示
                this.SetListType(this._ListType)
                PopupTipPanel.ShowTipByLanguageId(10823)
            end)
        end
    end)

end

-- 加入公会成功回调
function this.JoinGuildSuccess()
    -- 关闭当前界面
    this:ClosePanel()
    -- 打开主城
    UIManager.OpenPanel(UIName.GuildMainCityPanel)
    --
    PopupTipPanel.ShowTipByLanguageId(10411)
end

-- 设置数据类型
function this.SetListType(type)
    this._ListType = type
    local datalist = {}
    if this._ListType == 1 then
        -- this.title2.text = GetLanguageStrById(10902)
        this.input.text = ""
        datalist = GuildManager.GetRecommandGuildList()
    elseif this._ListType == 2 then
        -- this.title2.text = GetLanguageStrById(10800)
        datalist = GuildManager.GetSearchGuildList()
    end
    needDataList = datalist
    this.itemList = {}
    -- 刷新列表显示
    this.ScrollView:SetData(datalist, function(index, go)
        this.GuildItemAdapter(go, datalist[index])
        this.itemList[index] = go
    end)
    DelayCreation(this.itemList)
end

function this.FilterData(dataList)
    local filterList = {}
    for i = 1, #dataList do
        local guildData = dataList[i].familyBaseInfo      
        local curGuildLevelInfo = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, guildData.levle)
        local maxMemNum = curGuildLevelInfo.Num
        if  guildData.totalNum < maxMemNum then
            table.insert(filterList,dataList[i])
        end 
    end
    return filterList
end

--界面关闭时调用（用于子类重写）
function GuildFindPopup:OnClose()
    -- 控制挂机界面伤害文字显示
    FightPointPassManager.isBeginFight = false
    needDataList = {}
    for index, value in ipairs(this.itemList) do
        value:SetActive(false)
    end
end

--界面销毁时调用（用于子类重写）
function GuildFindPopup:OnDestroy()
    this.ScrollView = nil
end

return GuildFindPopup