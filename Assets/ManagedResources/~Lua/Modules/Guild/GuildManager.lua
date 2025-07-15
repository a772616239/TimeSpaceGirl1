GuildManager = {}
local this = GuildManager

this.RecommandGuildList = {}
this.SearchGuildList = {}

function GuildManager.Initialize()

end

-- 请求推荐公会列表
function GuildManager.RequestRecommandGuildList(func)
    NetManager.RequestRecommandGuild(function(msg)
        this.RecommandGuildList = msg.familyRecomandInfo
        if func then func() end
    end)
end

-- 请求搜索公会
function GuildManager.RequestSearchGuild(name, func)
    NetManager.RequestSearchGuild(name, function(msg)
        this.SearchGuildList = msg.familyRecomandInfo
        if func then func() end
    end)
end

-- 获取推荐列表数据
function GuildManager.GetRecommandGuildList()
    return this.RecommandGuildList
end

-- 获取搜索列表数据
function GuildManager.GetSearchGuildList()
    return this.SearchGuildList
end

-- 请求创建公会
function GuildManager.RequestCreateGuild(name, announce, func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
        PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
        return
    end
    NetManager.RequestCreateGuild(name, announce, function(msg)
        MyGuildManager.SetMyGuildInfo(msg)
        MyGuildManager.SetMyMemInfo(msg)
        MyGuildManager.SetMyFeteInfo(msg)
        MyGuildManager.InitAllData(function()
            if func then func() end
        end)
    end)
end

-- 请求加入公会
function GuildManager.RequestJoinGuild(guildId, func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
        PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
        return
    end
    NetManager.RequestJoinGuild(guildId, function(msg)
        MyGuildManager.SetMyGuildInfo(msg.familyJoinIndicaion)
        MyGuildManager.SetMyMemInfo(msg.familyJoinIndicaion)
        MyGuildManager.InitAllData(function()
            if func then func() end
        end)
        MyGuildManager.RefreshAidRedPot()
    end)
end

-- 申请加入某个公会
function GuildManager.RequestApplyOneGuild(guildId, func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
        PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
        return
    end
    NetManager.RequestApplyGuild({guildId}, function(msg)
        this.ChangeGuildApplyStatus({guildId})
        if func then func() end
    end)
end

-- 申请加入好多公会（推荐和搜索）
function GuildManager.RequestApplyManyGuilds(guildIdList, func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
        PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GUILD))
        return
    end
    NetManager.RequestApplyGuild(guildIdList, function(msg)
        this.ChangeGuildApplyStatus(guildIdList)
        if func then func() end
    end)
end

-- 改变公会的申请状态
function this.ChangeGuildApplyStatus(guildIdList)
    -- 推荐列表检测
    for _, v in ipairs(this.RecommandGuildList) do
        for _, guildId in ipairs(guildIdList) do
            if v.familyBaseInfo.id == guildId then
                v.isApply = GUILD_APPLY_STATUS.APPLY
                break
            end
        end
    end
    -- 搜索列表检测
    for _, v in ipairs(this.SearchGuildList) do
        for _, guildId in ipairs(guildIdList) do
            if v.familyBaseInfo.id == guildId then
                v.isApply = GUILD_APPLY_STATUS.APPLY
                break
            end
        end
    end
end

-- 获取公会图腾资源名
function GuildManager.GetLogoResName(logoId)
    logoId = (not logoId or logoId == 0) and GUILD_DEFAULT_LOGO or logoId
    local logoList = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).TotemItem
    if not logoList[logoId] then
        return
    end
    return GetResourcePath(logoList[logoId])
end


--
local _TipList = {}
local _TipTimer = nil
local function _IsNeedShowTip()
    return UIManager.IsOpen(UIName.MainPanel) or UIManager.IsOpen(UIName.GuildMainCityPanel)
end
function GuildManager.AddGuildTip(type, ...)
    local isNeedShow = _IsNeedShowTip()
    -- 如果在需要显示的界面，或者类型为加入（加入公会tip需要在返回主界面时显示，其他数据不在主界面直接丢弃），则保存数据并检测显示
    if isNeedShow or type == GUILD_TIP_TYPE.JOIN then
        -- 保存数据
        table.insert(_TipList, {type, ...})
        -- 按type类型排序，类型值小的优先显示
        table.sort(_TipList, function(a, b)
            return a[1] < b[1]
        end)
        -- 如果需要显示，并且没有timer运行中则检测数据开始显示
        if isNeedShow and not _TipTimer then
            this.CheckGuildTip()
        end
    end
end
function GuildManager.CheckGuildTip()
    if #_TipList == 0 then return end
    if not _TipTimer then
        _TipTimer = Timer.New(function()
            local tip = table.remove(_TipList, 1)
            local tType = tip[1]
            if tType == GUILD_TIP_TYPE.JOIN then
                local guildName = tip[2]
                MsgPanel.ShowTwo(string.format(GetLanguageStrById(10933), guildName), nil, function()
                    JumpManager.GoJump(4001)
                end, GetLanguageStrById(10934),GetLanguageStrById(10935))
            elseif tType == GUILD_TIP_TYPE.POS then
                local pos = tip[2]
                local oldPos = tip[3]
                if pos == GUILD_GRANT.MEMBER then
                    PopupTipPanel.ShowTip(oldPos == GUILD_GRANT.MASTER and GetLanguageStrById(10936) or GetLanguageStrById(10937))
                else
                    PopupTipPanel.ShowTip(GetLanguageStrById(10938)..GUILD_GRANT_STR[pos])
                end
            elseif tType == GUILD_TIP_TYPE.KICKOUT then
                local uid = tip[2]
                if uid == 0 then
                    PopupTipPanel.ShowTipByLanguageId(10939)
                else
                    PopupTipPanel.ShowTipByLanguageId(10940)
                end
            elseif tType == GUILD_TIP_TYPE.REFUSE and PlayerManager.familyId == 0 then
                local guildName = tip[2]
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10941), guildName))
            end
            -- 判断是否需要继续显示，不需要显示了，清空后面所有数据
            if not _IsNeedShowTip() then
                _TipList = {}
            end
            -- 没有数据要显示了，关闭计时器
            if #_TipList == 0 and _TipTimer then
                _TipTimer:Stop()
                _TipTimer = nil
            end
        end, 1, -1, true)
        _TipTimer:Start()
    end
end

return GuildManager