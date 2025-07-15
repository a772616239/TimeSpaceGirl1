local RankView = {}
local this = RankView

-- 头像对象管理
local _PlayerHeadList = {}

--初始化组件（用于子类重写）
function RankView:InitComponent()
    this.rankItem = Util.GetGameObject(self.gameObject, "item")
    this.myRankItem = Util.GetGameObject(self.gameObject, "myrank")
    this.myRankLab = Util.GetGameObject(self.gameObject, "myrank/rank")
    this.myPowerLab = Util.GetGameObject(self.gameObject, "myrank/power")

    this.scorllRoot = Util.GetGameObject(self.gameObject, "scorllroot")
    local rootHight = this.scorllRoot.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scorllRoot.transform,
            this.rankItem, nil, Vector2.New(1080, rootHight), 1, 1, Vector2.New(0,-3))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    --this.ScrollView.gameObject:GetComponent("RectTransform").sizeDelta = Vector2.New(0, 0)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function RankView:BindEvent()
end

--添加事件监听（用于子类重写）
function RankView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnRankDataChange, this.RefreshRankInfo)
end

--移除事件监听（用于子类重写）
function RankView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnRankDataChange, this.RefreshRankInfo)
end

--界面打开时调用（用于子类重写）
function RankView:OnOpen(...)
    -- 默认不是立刻刷新，需要延时
    this.isRefreshNow = false
    -- 刷新排行榜显示
    this.RefreshRankInfo(true)
    -- 赛季结束不再刷新
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
        return
    end
    -- 判断是否需要刷新数据
    if this.isRefreshNow then
        -- 强制刷新第一页数据
        ArenaManager.RequestNextPageRank(true)
        return
    end
    -- 延迟刷新排名数据，避免来回切换页签，向服务器不停发数据
    if this.delayRefresh then return end
    this.delayRefresh = Timer.New(function()
        -- 强制刷新第一页数据
        ArenaManager.RequestNextPageRank(true)
        this.delayRefresh = nil
    end, 1)
    this.delayRefresh:Start()
end

-- 刷新排名显示
function this.RefreshRankInfo(isTop)
    local rankList, myRankInfo, curPage = ArenaManager.GetRankInfo()
    -- 没有排行数据需要立刻刷新，只在打开界面时有用
    if #rankList == 0 then
        this.isRefreshNow = true
    end

    -- 节点数据匹配
    local rankAdapterFunc = function (index, go)
        this.RankNodeAdapter(go, rankList[index],myRankInfo.personInfo.rank)
        -- 如果显示到最后一个，刷新下一页数据
        if index == #rankList then
            ArenaManager.RequestNextPageRank()
        end
    end
    -- 重置排行列表
    this.ScrollView:SetData(rankList, rankAdapterFunc)
    if isTop then   -- 判断是否滚动到最上面
        this.ScrollView:SetIndex(1)
    end
    -- 我的排名
    --this.RankNodeAdapter(this.myRankItem, myRankInfo)
    local rankStr = myRankInfo.personInfo.rank
    if myRankInfo.personInfo.rank <= 0 then
        rankStr = GetLanguageStrById(10041)
    end
    this.myRankLab:GetComponent("Text").text = rankStr
    this.myPowerLab:GetComponent("Text").text = GetLanguageStrById(10105)..myRankInfo.personInfo.totalForce

end


-- 排名节点数据匹配
function this.RankNodeAdapter(node, data,myRank)
    --- 基础信息
    local rankBg = Util.GetGameObject(node, "rankbg")
    local rankLab = Util.GetGameObject(rankBg, "rank")
    local head = Util.GetGameObject(node, "head")
    local lv_name = Util.GetGameObject(node, "lv_name")
    local integral = Util.GetGameObject(node, "integral")
    local power = Util.GetGameObject(node, "power")
    local bg = Util.GetGameObject(node, "bg")

    --设置表现背景
    if myRank==data.personInfo.rank then
        Util.GetGameObject(node,"selfBg").gameObject:SetActive(true)
    else
        Util.GetGameObject(node,"selfBg").gameObject:SetActive(false)
    end

    if not _PlayerHeadList[node] then
        _PlayerHeadList[node] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    _PlayerHeadList[node]:Reset()
    -- 排名
    if data.personInfo.rank > 0 and data.personInfo.rank <= 3 then
        rankBg:GetComponent("Image").sprite = Util.LoadSprite("N1_icon_paihangbang_mingci"..data.personInfo.rank)
        rankBg:GetComponent("Image"):SetNativeSize()
        rankLab:SetActive(false)
    else
        rankBg:GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        rankBg:GetComponent("RectTransform").sizeDelta = Vector2.New(120, 120)
        rankLab:GetComponent("Text").text = data.personInfo.rank <= 0 and "200+" or data.personInfo.rank
        rankLab:SetActive(true)
    end

    _PlayerHeadList[node]:SetHead(data.personInfo.head)
    _PlayerHeadList[node]:SetFrame(data.personInfo.headFrame)
    lv_name:GetComponent("Text").text = "lv"..data.personInfo.level.." "..data.personInfo.name
    integral:GetComponent("Text").text = GetLanguageStrById(10147).." "..data.personInfo.score
    power:GetComponent("Text").text = GetLanguageStrById(10090)..data.personInfo.totalForce
    Util.AddOnceClick(bg, function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, data.personInfo.uid, PLAYER_INFO_VIEW_TYPE.ARENA)
    end)
    --- 英雄信息
    for i = 1, 5 do
        local heroHeadBg = Util.GetGameObject(node, "demons/head_"..i)
        local hearIcon = Util.GetGameObject(heroHeadBg, "icon")
        local heroTId = data.team.heroTid[i]
        if heroTId then
            heroHeadBg:SetActive(true)
            local demonData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroTId)
            heroHeadBg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(demonData.Quality))
            hearIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(demonData.Icon))
        else
            heroHeadBg:SetActive(false)
        end
    end
end



--界面关闭时调用（用于子类重写）
function RankView:OnClose()
    -- 判断如果还没有请求刷新，则停止
    if this.delayRefresh then
        this.delayRefresh:Stop()
        this.delayRefresh = nil
    end
end

--界面销毁时调用（用于子类重写）
function RankView:OnDestroy()
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    this.ScrollView = nil
end

return RankView