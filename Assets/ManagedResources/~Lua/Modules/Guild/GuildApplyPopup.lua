require("Base/BasePanel")
GuildApplyPopup = Inherit(BasePanel)
local this = GuildApplyPopup

-- 头像管理
local _PlayerHeadList = {}

--初始化组件（用于子类重写）
function GuildApplyPopup:InitComponent()
    this.maskImage = Util.GetGameObject(self.gameObject, "maskImage")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    this.verifyScrollRoot = Util.GetGameObject(self.gameObject, "content/verify/scrollpos")
    this.verifyItem = Util.GetGameObject(self.gameObject, "content/verify/scrollpos/verify")
    this.empty = Util.GetGameObject(self.gameObject, "content/verify/empty")
    this.btnBg = Util.GetGameObject(self.gameObject, "content/verify/btnbg")
    this.clear = Util.GetGameObject(self.gameObject, "content/verify/btnbg/clear")
    this.agree = Util.GetGameObject(self.gameObject, "content/verify/btnbg/agree")
    this.agreeRedpot = Util.GetGameObject(self.gameObject, "content/verify/btnbg/agree/redpot")
end

--绑定事件（用于子类重写）
function GuildApplyPopup:BindEvent()
    Util.AddClick(this.maskImage, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.clear, function()
        -- 判断是否有权限
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end
        MyGuildManager.OperateApply(GUILD_APPLY_OPTYPE.ALL_REFUSE)
    end)
    Util.AddClick(this.agree, function()
        -- 判断是否有权限
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end
        MyGuildManager.OperateApply(GUILD_APPLY_OPTYPE.ALL_AGREE)
    end)
end

--添加事件监听（用于子类重写）
function GuildApplyPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function GuildApplyPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function GuildApplyPopup:OnOpen(fun)
    this.fun=fun
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildApplyPopup:OnShow()
    this.RefreshVerifyShow()

    this.BindRedpot(this.agreeRedpot)
end

-- 刷新申请信息
function this.RefreshVerifyShow()
    local pos = MyGuildManager.GetMyPositionInGuild()
    local isAdmin = pos == GUILD_GRANT.MASTER or pos == GUILD_GRANT.ADMIN
    this.btnBg:SetActive(isAdmin)
    -- 创建滚动
    if not this.verifyScrollView then
        local width = this.verifyScrollRoot.transform.rect.width
        local height = isAdmin and this.verifyScrollRoot.transform.rect.height or this.verifyScrollRoot.transform.rect.height + this.btnBg.transform.rect.height
        this.verifyScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.verifyScrollRoot.transform,
                this.verifyItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,20))
        this.verifyScrollView.transform.anchoredPosition = Vector2.New(0, 0)
        this.verifyScrollView.transform.anchorMin = Vector2.New(0.5, 1)
        this.verifyScrollView.transform.anchorMax = Vector2.New(0.5, 1)
        this.verifyScrollView.transform.pivot = Vector2.New(0.5, 1)
        this.verifyScrollView.moveTween.Strength = 2
    end
    -- 获取数据
    local verifies = MyGuildManager.GetMyGuildApplyList()
    
    
    this.verifyScrollView:SetData(verifies, function(index, go)
        this.VerifyItemAdapter(go, verifies[index])
    end)
    -- 判断空数据显示
    this.empty:SetActive(#verifies == 0)
end
-- 成员信息节点数据匹配
function this.VerifyItemAdapter(item, data)
    local headpos = Util.GetGameObject(item, "head")
    local nameText = Util.GetGameObject(item, "name")
    local powerText = Util.GetGameObject(item, "power")
    local btnRefuse = Util.GetGameObject(item, "btnRefuse")
    local btnAgree = Util.GetGameObject(item, "btnAgree")
    nameText:GetComponent("Text").text = data.name
    powerText:GetComponent("Text").text = data.foreces
    -- 头像
    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetScale(Vector3.one * 0.8)
    _PlayerHeadList[item]:SetHead(data.head)
    _PlayerHeadList[item]:SetFrame(data.frame)
    _PlayerHeadList[item]:SetLevel(data.level)

    local pos = MyGuildManager.GetMyPositionInGuild()
    local isAdmin = pos == GUILD_GRANT.MASTER or pos == GUILD_GRANT.ADMIN
    btnRefuse:SetActive(isAdmin)
    btnAgree:SetActive(isAdmin)
    Util.AddOnceClick(btnRefuse, function()
        -- 判断是否有权限
        if not isAdmin then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end
        MyGuildManager.OperateApply(GUILD_APPLY_OPTYPE.ONE_REFUSE, data.roleUid,function()
            MyGuildManager.RequestMyGuildApplyList(function()
                this.RefreshVerifyShow()
            end)
        end)
    end)
    Util.AddOnceClick(btnAgree, function()
        -- 判断是否有权限
        if not isAdmin then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end
        MyGuildManager.OperateApply(GUILD_APPLY_OPTYPE.ONE_AGREE, data.roleUid,function()
            MyGuildManager.RequestMyGuildApplyList(function()
                this.RefreshVerifyShow()
            end)
        end)
    end)
end

-- 绑定数据
local _RedBindData = {}
function this.BindRedpot(redpot)
    local pos = MyGuildManager.GetMyPositionInGuild()
    local rpType = RedPointType.Guild_House_Apply
    if not rpType then return end
    BindRedPointObject(rpType, redpot)
    _RedBindData[rpType] = redpot
    this.agreeRedpot:SetActive(redpot.activeSelf)
end

function this.ClearRedpot()
    -- 全部清除
    for rpt, redpot in pairs(_RedBindData) do
        ClearRedPointObject(rpt, redpot)
    end
    _RedBindData = {}
end

--界面关闭时调用（用于子类重写）
function GuildApplyPopup:OnClose()
    if this.fun then
        this.fun()
    end
end

--界面销毁时调用（用于子类重写）
function GuildApplyPopup:OnDestroy()
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    this.verifyScrollView = nil

    -- 清除红点
    this.ClearRedpot()
end

return GuildApplyPopup