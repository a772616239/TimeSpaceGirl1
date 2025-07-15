require("Base/BasePanel")
local GuildFightAttackLogPopup = Inherit(BasePanel)
local this = GuildFightAttackLogPopup

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(168 / 255, 168 / 255, 167 / 255, 1),
                        select = Color.New(250 / 255, 227 / 255, 175 / 255, 1) }
local _TabSprite = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001"}
local _TabData = {
    [1] = { name = GetLanguageStrById(10871) },
    [2] = { name = GetLanguageStrById(10872) },
}
-- 头像管理
local _PlayerHeadList = {}

--初始化组件（用于子类重写）
function GuildFightAttackLogPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.tabbox = Util.GetGameObject(self.transform, "top")

    this.rankPanel = Util.GetGameObject(self.transform, "content/rank")
    this.empty = Util.GetGameObject(self.transform, "content/empty")

    this.rankScrollRoot = Util.GetGameObject(this.rankPanel, "scrollpos")
    this.rankItem = Util.GetGameObject(this.rankPanel, "scrollpos/mem")

end

--绑定事件（用于子类重写）
function GuildFightAttackLogPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)


    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
end

--添加事件监听（用于子类重写）
function GuildFightAttackLogPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildFightAttackLogPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildFightAttackLogPopup:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFightAttackLogPopup:OnShow()
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(1)
    end
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Img"):GetComponent("Image").sprite = Util.LoadSprite(_TabSprite[status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end

-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    local type = index - 1
    GuildFightManager.RequestGuildFightAttackLogData(type, function()
        this.RefreshRankShow(type)
    end)
end

-- 刷新排名显示
function this.RefreshRankShow(type)
    local rankList = GuildFightManager.GetGuildFightAttackLogData(type)
    if not rankList then return end
    -- 创建滚动
    if not this.rankScroll then
        local height = this.rankScrollRoot.transform.rect.height
        local width = this.rankScrollRoot.transform.rect.width
        this.rankScroll = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rankScrollRoot.transform,
                this.rankItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
        this.rankScroll.moveTween.Strength = 2
    end

    this.rankScroll:SetData(rankList, function(index, go)
        this.RankItemAdapter(go, rankList[index])
    end)
    this.rankScroll:SetIndex(1)
    this.empty:SetActive(#rankList == 0)
end

-- 排名节点数据匹配
function this.RankItemAdapter(node, data)
    local rank = Util.GetGameObject(node, "rank"):GetComponent("Image")
    local rankNum = Util.GetGameObject(node, "rank/num"):GetComponent("Text")
    local head = Util.GetGameObject(node, "head")
    local name = Util.GetGameObject(node, "name"):GetComponent("Text")
    local pos = Util.GetGameObject(node, "pos"):GetComponent("Text")
    local count = Util.GetGameObject(node, "count"):GetComponent("Text")
    local starNum = Util.GetGameObject(node, "num"):GetComponent("Text")


    -- 排名
    if data.rank <= 3 then
        rank.sprite = Util.LoadSprite("r_playerrumble_paiming_0"..data.rank)
        --rank:SetNativeSize()
        rankNum.gameObject:SetActive(false)
    else
        rank.sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        --rank.transform.sizeDelta = Vector2.New(120, 120)
        rankNum.gameObject:SetActive(true)
    end

    rankNum:GetComponent("Text").text = data.rank
    name:GetComponent("Text").text = data.name
    pos:GetComponent("Text").text = GUILD_GRANT_STR[data.position]
    count:GetComponent("Text").text = data.attackCount..GetLanguageStrById(10054)
    starNum:GetComponent("Text").text = data.starCount

    -- 头像
    if not _PlayerHeadList[node] then
        _PlayerHeadList[node] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    _PlayerHeadList[node]:Reset()
    _PlayerHeadList[node]:SetScale(Vector3.one * 0.6)
    _PlayerHeadList[node]:SetHead(data.head)
    _PlayerHeadList[node]:SetFrame(data.headFrame)


end
--界面关闭时调用（用于子类重写）
function GuildFightAttackLogPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildFightAttackLogPopup:OnDestroy()
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    this.rankScroll = nil
end

return GuildFightAttackLogPopup