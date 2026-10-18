--[[
 * 国家排行榜面板（启动页 / 登录页入口弹窗）
 *
 * 层级结构见 Assets/ManagedResources/Prefabs/UI/CountryRank/CountryRankPanel.prefab
--]]
require("Modules/CountryRank/CountryConfig")
require("Modules/CountryRank/CountryRankManager")
require("Base/BasePanel")
CountryRankPanel = Inherit(BasePanel)
local this = CountryRankPanel

local RANK_TYPE = CountryRankManager.RankType

-- 榜单里的条目视图（ItemPre 上的小节组件）
local RowView = {}

function RowView:New(gameObject)
    local b = { gameObject = gameObject, transform = gameObject.transform }
    setmetatable(b, { __index = RowView })
    b:InitComponent()
    return b
end

function RowView:InitComponent()
    self.di = self.gameObject:GetComponent("Image")
    self.medal = Util.GetGameObject(self.gameObject, "medal")
    self.medalImg = Util.GetGameObject(self.gameObject, "medal"):GetComponent("Image")
    self.rankNum = Util.GetGameObject(self.gameObject, "rankNum"):GetComponent("Text")
    self.flag = Util.GetGameObject(self.gameObject, "flag"):GetComponent("Image")
    self.nameText = Util.GetGameObject(self.gameObject, "nameText"):GetComponent("Text")
    self.subText = Util.GetGameObject(self.gameObject, "subText"):GetComponent("Text")
    self.scoreText = Util.GetGameObject(self.gameObject, "scoreText"):GetComponent("Text")
    self.hitArea = Util.GetGameObject(self.gameObject, "hitArea")
end

--- 刷新一条榜单数据
function RowView:SetData(data, isSelf)
    local rank = data.rank or 0
    local isTop3 = rank >= 1 and rank <= 3

    -- 名次牌：前三用奖牌图，其余用数字
    self.medal:SetActive(isTop3)
    self.rankNum.gameObject:SetActive(not isTop3)
    if isTop3 then
        self.medalImg.sprite = Util.LoadSprite("cn2-x1_guojiapaihang_paiming_0" .. rank)
    else
        self.rankNum.text = rank > 0 and tostring(rank) or "--"
    end

    -- 条目底板：前三特殊配色，自己高亮
    local diSprite = "cn2-x1_guojiapaihang_tiaomu"
    if isSelf then
        diSprite = "cn2-x1_guojiapaihang_tiaomu_ziji"
    elseif isTop3 then
        diSprite = "cn2-x1_guojiapaihang_tiaomu_" .. rank
    end
    self.di.sprite = Util.LoadSprite(diSprite)

    -- 旗帜
    self.flag.sprite = Util.LoadSprite(CountryConfig.GetFlagSprite(data.country))

    -- 名字 + 国家名
    self.nameText.text = data.name or ""
    self.subText.text = CountryConfig.GetName(data.country)

    -- 分数
    self.scoreText.text = this.FormatScore(data.score)
end

----------------------------------------------------------------
function CountryRankPanel:InitComponent()
    this.board = Util.GetGameObject(self.gameObject, "board")
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.btnClose = Util.GetGameObject(this.board, "btnClose")
    this.titleText = Util.GetGameObject(this.board, "title"):GetComponent("Text")

    this.tabAll = Util.GetGameObject(this.board, "tabBox/tabAll")
    this.tabLocal = Util.GetGameObject(this.board, "tabBox/tabLocal")
    this.tabAllText = Util.GetGameObject(this.tabAll, "text"):GetComponent("Text")
    this.tabLocalText = Util.GetGameObject(this.tabLocal, "text"):GetComponent("Text")
    this.tabAllImg = this.tabAll:GetComponent("Image")
    this.tabLocalImg = this.tabLocal:GetComponent("Image")

    this.btnPickCountry = Util.GetGameObject(this.board, "btnPickCountry")
    this.pickText = Util.GetGameObject(this.btnPickCountry, "text"):GetComponent("Text")

    this.scrollRoot = Util.GetGameObject(this.board, "scroll")
    this.listRoot = Util.GetGameObject(this.scrollRoot, "ScrollParentView")
    this.itemPre = Util.GetGameObject(this.listRoot, "ItemPre")

    this.myRank = Util.GetGameObject(this.board, "myRank")
    this.myRankText = Util.GetGameObject(this.myRank, "rankText"):GetComponent("Text")
    this.myFlag = Util.GetGameObject(this.myRank, "flag"):GetComponent("Image")
    this.myName = Util.GetGameObject(this.myRank, "nameText"):GetComponent("Text")
    this.myScore = Util.GetGameObject(this.myRank, "scoreText"):GetComponent("Text")

    this.rows = {}
    this.scrollView = nil
end

function CountryRankPanel:BindEvent()
    Util.AddClick(this.btnClose, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.tabAll, function()
        this:SwitchRankType(RANK_TYPE.All)
    end)
    Util.AddClick(this.tabLocal, function()
        this:SwitchRankType(RANK_TYPE.Local)
    end)
    Util.AddClick(this.btnPickCountry, function()
        this:OpenCountryPicker()
    end)
end

function CountryRankPanel:AddListener()
    if Game.GlobalEvent then
        Game.GlobalEvent:AddEvent(GameEvent.CountryRank.OnCountryChanged, this.OnCountryChanged, this)
    end
end

function CountryRankPanel:RemoveListener()
    if Game.GlobalEvent then
        Game.GlobalEvent:RemoveEvent(GameEvent.CountryRank.OnCountryChanged, this.OnCountryChanged, this)
    end
end

function CountryRankPanel:OnOpen(msg)
    msg = msg or {}
    -- 允许外部指定初始榜单类型与"是否强制先选国家"
    this._initType = msg.rankType or RANK_TYPE.All
    this._forcePick = msg.forcePick == true
    this.titleText.text = GetLanguageStrByStr("国家排行榜")
    this.pickText.text = GetLanguageStrByStr("选择国家")
    this.tabAllText.text = GetLanguageStrByStr("全服排行")
    this.tabLocalText.text = GetLanguageStrByStr("本国排行")
end

function CountryRankPanel:OnShow()
    this:EnsureScrollView()
    this:SwitchRankType(this._initType or RANK_TYPE.All, true)

    -- 第一次进来还没选过国家：先弹选择面板
    if this._forcePick or not CountryRankManager.HasChosenCountry() then
        this._forcePick = false
        this:OpenCountryPicker()
    end
end

function CountryRankPanel:OnClose()
    this.rows = {}
end

---------------------------------------------------------------- 列表
function CountryRankPanel:EnsureScrollView()
    if this.scrollView then
        return
    end
    local rect = this.listRoot:GetComponent("RectTransform").rect
    this.scrollView = SubUIManager.Open(
        SubUIConfig.ScrollCycleView,
        this.listRoot.transform,
        this.itemPre,
        nil,
        Vector2.New(-rect.x * 2, -rect.y * 2),
        1, 1,
        Vector2.New(0, 8)
    )
    local rt = this.scrollView.gameObject:GetComponent("RectTransform")
    rt.anchoredPosition = Vector2.New(0, 0)
    rt.anchorMin = Vector2.New(0.5, 0.5)
    rt.anchorMax = Vector2.New(0.5, 0.5)
    rt.pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

function CountryRankPanel:UpdateRow(index, go)
    local data = this._curList and this._curList[index]
    if not data then
        return
    end
    local view = this.rows[go]
    if not view then
        view = RowView:New(go)
        this.rows[go] = view
    end
    local myCountry = CountryRankManager.GetPlayerCountry()
    view:SetData(data, data.country == myCountry and data.uid == (PlayerManager and PlayerManager.uid or -1))
end

function CountryRankPanel:RefreshList()
    local list = CountryRankManager.GetRankList(CountryRankManager.GetRankType())
    this._curList = list
    if this.scrollView then
        this.scrollView:SetData(list, function(index, go)
            this:UpdateRow(index, go)
        end)
    end
    this:RefreshMyRank()
end

function CountryRankPanel:RefreshMyRank()
    local rankType = CountryRankManager.GetRankType()
    local mine = CountryRankManager.GetMyRankInfo(rankType)
    this.myRankText.text = mine.rank and string.format(GetLanguageStrByStr("我的排名") .. " 第%d名", mine.rank)
            or GetLanguageStrByStr("未上榜")
    this.myFlag.sprite = Util.LoadSprite(CountryConfig.GetFlagSprite(mine.country))
    this.myName.text = CountryConfig.GetName(mine.country)
    this.myScore.text = this.FormatScore(mine.score)
end

function CountryRankPanel:SwitchRankType(rankType, force)
    if not force and CountryRankManager.GetRankType() == rankType then
        return
    end
    CountryRankManager.SetRankType(rankType)

    -- 页签态：选中金黄、未选暗紫
    local selectedSprite = Util.LoadSprite("cn2-x1_guojiapaihang_yetan_xuanzhong")
    local normalSprite = Util.LoadSprite("cn2-x1_guojiapaihang_yetan_weixuanzhong")
    if rankType == RANK_TYPE.All then
        this.tabAllImg.sprite = selectedSprite
        this.tabLocalImg.sprite = normalSprite
        this.tabAllText.color = Color.New(0.09, 0.07, 0.04, 1)
        this.tabLocalText.color = Color.New(0.588, 0.549, 0.706, 1)
    else
        this.tabAllImg.sprite = normalSprite
        this.tabLocalImg.sprite = selectedSprite
        this.tabAllText.color = Color.New(0.588, 0.549, 0.706, 1)
        this.tabLocalText.color = Color.New(0.09, 0.07, 0.04, 1)
    end
    this:RefreshList()
end

---------------------------------------------------------------- 国家选择
function CountryRankPanel:OpenCountryPicker()
    UIManager.OpenPanel(UIName.CountryFlagSelectPopup, function(code)
        if code then
            this:SwitchRankType(CountryRankManager.GetRankType(), true)
        end
    end)
end

function CountryRankPanel:OnCountryChanged()
    this:SwitchRankType(CountryRankManager.GetRankType(), true)
end

---------------------------------------------------------------- 工具
--- 分数千分位
function CountryRankPanel.FormatScore(score)
    score = math.floor(tonumber(score) or 0)
    local s = tostring(score)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    out = out:gsub("^,", "")
    return out
end
