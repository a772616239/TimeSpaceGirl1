local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0

-- local ItemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)

local _GuildPosBtnType = {
    [GUILD_MEM_POPUP_TYPE.INFORMATION] = {
        [GUILD_GRANT.MASTER] = {
            [GUILD_GRANT.ADMIN] = {
                {name = GetLanguageStrById(10942), func = 1},
                {name = GetLanguageStrById(10943), func = 6},
                {name = GetLanguageStrById(10944), func = 3},
            },
            [GUILD_GRANT.MEMBER] = {
                {name = GetLanguageStrById(10942), func = 1},
                {name = GetLanguageStrById(10945), func = 2},
                {name = GetLanguageStrById(10944), func = 3},
            },
        },
        [GUILD_GRANT.ADMIN] = {
            [GUILD_GRANT.MEMBER] = {
                {name = GetLanguageStrById(10944), func = 3},
            }
        },
    },
}


function this:InitComponent(gameObject)
    this.FontText = Util.GetGameObject(gameObject, "Root/Text"):GetComponent("Text")


    this.ChangeMasterBtn = Util.GetGameObject(gameObject, "ChangeMasterBtn")
    this.SetDeputyBtn = Util.GetGameObject(gameObject, "SetDeputyBtn")
    this.OutBtn = Util.GetGameObject(gameObject, "OutBtn")

    -- 注册按钮事件
    this.btnFunc = {
        [1] = this.SetMaster,
        [2] = this.SetAdmin,
        [3] = this.KickOut,
        [4] = this.ChangeMemBuildType,
        [5] = this.AttackEnemy,
        [6] = this.CancelAdmin,
    }

    this.btnList = {}
    this.btnList[1] = Util.GetGameObject(gameObject, "btn1")
    this.btnList[2] = Util.GetGameObject(gameObject, "btn2")
    this.btnList[3] = Util.GetGameObject(gameObject, "btn3")
end

function this:BindEvent()
    Util.AddClick(this.ChangeMasterBtn,function()

    end)
    Util.AddClick(this.SetDeputyBtn,function()

    end)
    Util.AddClick(this.OutBtn,function()

    end)
end

function this:AddListener()

end

function this:RemoveListener()

end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder = _parent.sortingOrder
    local _args = {...}
    this.GamerName = _args[1]
    this._MemId = _args[2]


    self:Init()
end

function this:Init()
    this.FontText.text = string.format(GetLanguageStrById(12539), this.GamerName)

    this._MemData = MyGuildManager.GetMemInfo(this._MemId)

    this:FreshBtn()
end

function this:FreshBtn()
    --> 延用之前功能(GuildMemberInfoPopup) 挪出 单独界面
    local posToType = _GuildPosBtnType[GUILD_MEM_POPUP_TYPE.INFORMATION]
    local pos = MyGuildManager.GetMyPositionInGuild()
    local btnType = posToType[pos]
    if btnType and (not btnType[1] or not btnType[1].name) then    -- 判断类型
        btnType = btnType[this._MemData.position]
    end

    for index, btn in ipairs(this.btnList) do
        btn:SetActive(btnType[index] ~= nil)
        if btnType[index] then
            Util.GetGameObject(btn, "Text"):GetComponent("Text").text = btnType[index].name
            Util.AddOnceClick(btn, function()
                local funcType = btnType[index].func
                if not this.btnFunc[funcType] then

                    return
                end
                this.btnFunc[funcType](btnType[index].param)
            end)
        end
    end
end

----===============================  按钮事件==================================
-- 转让会长
function this.SetMaster()
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10958)
        return
    end
    if this._MemId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end
    if this._MemData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10960)
        return
    end

    MsgPanel.ShowTwo(GetLanguageStrById(10961), nil, function()
        -- 转让会长
        MyGuildManager.AppointmentPos(this._MemId, GUILD_GRANT.MASTER, function ()
            parent:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10962)
        end)
    end)
end
-- 委任管理员
function this.SetAdmin()
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10963)
        return
    end
    if this._MemId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end
    if this._MemData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10964)
        return
    end
    if this._MemData.position == GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10965)
        return
    end

    local adminNum = MyGuildManager.GetAdminMemNum()
    local guildData = MyGuildManager.GetMyGuildInfo()
    local maxNum = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, guildData.levle).OfficalNum
    if adminNum >= maxNum then
        PopupTipPanel.ShowTipByLanguageId(10966)
        return
    end

    MsgPanel.ShowTwo(GetLanguageStrById(10967), nil, function()
        -- 委任管理员
        MyGuildManager.AppointmentPos(this._MemId, GUILD_GRANT.ADMIN, function ()
            parent:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10968)
        end)
    end)
end
-- 取消管理员
function this.CancelAdmin()
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10969)
        return
    end
    if this._MemId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end
    if this._MemData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10970)
        return
    end
    if this._MemData.position ~= GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10971)
        return
    end

    MsgPanel.ShowTwo(GetLanguageStrById(10972), nil, function()
        -- 委任管理员
        MyGuildManager.AppointmentPos(this._MemId, GUILD_GRANT.MEMBER, function ()
            parent:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10973)
        end)
    end)
end

-- 驱逐公会
function this.KickOut()
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10974)
        return
    end
    if this._MemId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end
    if this._MemData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10975)
        return
    end
    if pos == GUILD_GRANT.ADMIN and this._MemData.position == GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10976)
        return
    end


    MsgPanel.ShowTwo(GetLanguageStrById(10977), nil, function()
        MyGuildManager.RequestKickOut(this._MemId, function()
            parent:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10978)
        end)
    end)

end

function this:OnClose()
    
end

function this:OnDestroy()

end

return this