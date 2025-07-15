require("Base/BasePanel")
local ATM_RankViewPanel = Inherit(BasePanel)
local this = ATM_RankViewPanel
--头名
local TitleName = {
    "r_jingjichang_tiao01","r_jingjichang_tiao02","r_jingjichang_tiao03","r_jingjichang_tiao04"
}
--头描述
 local TitleDesc = {
    GetLanguageStrById(12582),GetLanguageStrById(12583),GetLanguageStrById(12584),
    GetLanguageStrById(12585),GetLanguageStrById(12586),GetLanguageStrById(12587),GetLanguageStrById(12588)
}
--空信息提示
local EmptyTip = {[1] = GetLanguageStrById(10175),[2] = GetLanguageStrById(10176)}
local TitleColor = {
    Color.New(177/255,91/255,90/255,1),Color.New(169/255,132/255,105/255,1),
    Color.New(161/255,105/255,168/255,1),Color.New(97/255,124/255,154/255,1)
}
local battleStage = 0
local battleTurn = 0
local battleState = 0

-- 排行显示类型
local showTip = {
    Four = 5,
    Two = 3,
    One = 1
}
local TitleIndex = {
    [1] = 17,
    [2] = 9,
    [3] = 5,
    [4] = 3,
    [5] = 2,
}

local TurnIndex = {
    [1] = 5,
    [2] = 4,
    [3] = 3,
    [4] = 2,
    [5] = 1
}

--排名预设列表
local itemList = {}

local btnLikeList = {}

---巅峰战排名
--初始化组件（用于子类重写）
function ATM_RankViewPanel:InitComponent()
    this.itemPre = Util.GetGameObject(self.gameObject,"ItemPre")
    this.empty = Util.GetGameObject(self.gameObject,"Empty")
    this.emptyText = Util.GetGameObject(this.empty,"Text"):GetComponent("Text")
    this.panel = Util.GetGameObject(self.gameObject,"Panel")
    for i = 1, 8 do
        itemList[i] = Util.GetGameObject(this.panel,"ItemPre"..i)
    end
    this.myRankContent = Util.GetGameObject(self.gameObject,"MyRank")
    this.myRank = Util.GetGameObject(this.myRankContent,"Rank"):GetComponent("Text")
    this.myPower = Util.GetGameObject(this.myRankContent,"Power"):GetComponent("Text")

    this.scorllRoot = Util.GetGameObject(self.gameObject,"ScorllRoot")
    this.buttonClose = Util.GetGameObject(self.gameObject,"Bg/Image/ButtonClose")
    if not this.scrollView then
        this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scorllRoot.transform,
                this.itemPre, nil,Vector2.New(this.scorllRoot.transform.rect.width, this.scorllRoot.transform.rect.height), 1, 1,Vector2.New(0,5))
        this.scrollView.moveTween.MomentumAmount = 1
        this.scrollView.moveTween.Strength = 2
    end

    this.playerHead = {}--玩家头像列表
    -- this.istop = true
end

--绑定事件（用于子类重写）
function ATM_RankViewPanel:BindEvent()
    Util.AddClick(this.buttonClose, function()
        self:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    end)
end

--添加事件监听（用于子类重写）
function ATM_RankViewPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.ATM_RankView.OnRankChange,this.RefreshRankInfo)
    -- Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnTopMatchDataUpdate,this.OnOpen, this)
end

--移除事件监听（用于子类重写）
function ATM_RankViewPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.ATM_RankView.OnRankChange, this.RefreshRankInfo)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.OnOpen, this)
end

--界面打开时调用（用于子类重写）
function ATM_RankViewPanel:OnOpen(...)
    this.RefreshRankInfo()
end

function ATM_RankViewPanel:OnSortingOrderChange(sortingOrder)

end

--界面关闭时调用（用于子类重写）
function ATM_RankViewPanel:OnClose()
    -- ArenaTopMatchManager.CurPage=0
end

--界面销毁时调用（用于子类重写）
function ATM_RankViewPanel:OnDestroy()
    this.scrollView = nil

    btnLikeList = {}
end


--刷新排名信息
function this.RefreshRankInfo()
    -- for i = 1, #itemList do
    --     Util.GetGameObject(itemList[i],"Name"):GetComponent("Text").text = ""
    -- end
    -- local isActive = ArenaTopMatchManager.IsTopMatchActive()
    -- battleStage = ArenaTopMatchManager.GetBaseData().battleStage
    -- battleTurn = ArenaTopMatchManager.GetBaseData().battleTurn
    -- battleState = ArenaTopMatchManager.GetBaseData().battleState
    -- -- ArenaTopMatchManager.CurPage=0
    

    -- local isShowRank = isActive and battleStage == TOP_MATCH_STAGE.ELIMINATION and battleTurn>=3--当处于淘汰赛 处于8强(battleStage == TOP_MATCH_STAGE.ELIMINATION or battleStage == TOP_MATCH_STAGE.CHOOSE or  battleState == TOP_MATCH_TIME_STATE.OVER)
    -- this.panel:SetActive(isShowRank)
    -- this.empty:SetActive(not isShowRank)
    -- if battleStage==TOP_MATCH_STAGE.OVER or battleStage==TOP_MATCH_STAGE.CLOSE then --当处于活动已结束 显示赛程尚未开启
    --     this.emptyText.text=EmptyTip[1]
    -- elseif battleStage==TOP_MATCH_STAGE.CHOOSE then --当处于选拔赛 显示尚未决出8强
    --     this.emptyText.text=EmptyTip[2]
    -- end
    -- --后加的结束了 也要显示八强数据
    -- if battleStage == TOP_MATCH_STAGE.OVER and battleTurn==-2 and battleState==TOP_MATCH_TIME_STATE.OVER then
    --     this.panel:SetActive(true)
    --     this.empty:SetActive(false)
    -- end
    
    -- -- if not isShowRank then return end
    -- ArenaTopMatchManager.RequestRankData(1,function()
    --     local rankData,madata=ArenaTopMatchManager.GetRankData()
    
    
    --     if battleStage == TOP_MATCH_STAGE.ELIMINATION and battleTurn==4 and battleState==TOP_MATCH_TIME_STATE.OPEN_IN_END and isShowRank then
    --         this.RefreshRankData(rankData,showTip.Four)
    --     elseif battleStage == TOP_MATCH_STAGE.ELIMINATION and battleTurn==5 and battleState==TOP_MATCH_TIME_STATE.OPEN_IN_END and isShowRank then
    --         this.RefreshRankData(rankData,showTip.Two)
    --     elseif battleStage == TOP_MATCH_STAGE.ELIMINATION and battleTurn==6 and battleState==TOP_MATCH_TIME_STATE.OPEN_IN_END  and isShowRank then
    --         this.RefreshRankData(rankData,showTip.One)
    --     elseif battleStage == TOP_MATCH_STAGE.OVER and battleTurn==-2 and battleState==TOP_MATCH_TIME_STATE.OVER then--后加的结束了 也要显示八强数据
    --         this.RefreshRankData(rankData,showTip.Four)
    --         this.RefreshRankData(rankData,showTip.Two)
    --         this.RefreshRankData(rankData,showTip.One)
    --     end
    -- end)
--     local isActive = ArenaTopMatchManager.IsTopMatchActive()
--     local isShowRank = isActive and battleStage == TOP_MATCH_STAGE.ELIMINATION and battleTurn>=3--当处于淘汰赛 处于8强(battleStage == TOP_MATCH_STAGE.ELIMINATION or battleStage == TOP_MATCH_STAGE.CHOOSE or  battleState == TOP_MATCH_TIME_STATE.OVER)
--     this.scorllRoot:SetActive(isShowRank)
--     this.empty:SetActive(not isShowRank)

--    if battleStage == TOP_MATCH_STAGE.OVER and battleTurn==-2 and battleState==TOP_MATCH_TIME_STATE.OVER then
--         this.scorllRoot:SetActive(true)
--         this.empty:SetActive(false)
--     end
    this.istop = true
    this.InitUnRollingInfo()
    ArenaTopMatchManager.RequestRankData(1,function ()
        local rankData,myRankData=ArenaTopMatchManager.GetRankData()
        this.scorllRoot:SetActive(#rankData > 0)
        this.empty:SetActive(#rankData <= 0)

        --滚动区数据
        if not this.scrollView then
            local rootHight = this.scorllRoot.transform.rect.height
            local rootWidth = this.scorllRoot.transform.rect.width
            this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scorllRoot.transform,
                this.itemPre, nil,Vector2.New(this.scorllRoot.transform.rect.width, this.scorllRoot.transform.rect.height), 1, 1,Vector2.New(0,5))
            this.scrollView.moveTween.MomentumAmount = 1
            this.scrollView.moveTween.Strength = 2
        end
        if this.istop then
            this.scrollView:SetData(rankData, function(index,root)
                this.SetNodeShow(root,rankData[index],myRankData.rank)
                --分页请求
                if index == #rankData then
                    ArenaTopMatchManager.GetNextRankData()
                    return
                end
            end, 1)
            this.istop = false
        else
            this.scrollView:SetData(rankData,function(index,root)
                this.SetNodeShow(root,rankData[index],myRankData.rank)
                --分页请求
                if index == #rankData then
                    ArenaTopMatchManager.GetNextRankData()
                    return
                end
            end)
        end
        this.CheckIsTop()

        this.LikeBtnState()
    end)
end

--刷新显示排行
function this.RefreshRankData(data,type)
    -- 虚位以待
    if type ~= ShowType.One then
        for i = 1,type - 1 do
            this.SetItemData(i)
        end
    end
    --输的玩家
    for i = type,8 do
        this.SetItemData(i,data[i])
    end
end

--设置排行Item数据
function this.SetItemData(...)
    local args = {...}
    local root = itemList[args[1]]
    local head = Util.GetGameObject(root,"Head")
    local info = Util.GetGameObject(root,"Info"):GetComponent("Image")
    local name = Util.GetGameObject(root,"Name"):GetComponent("Text")

    name.text = ""
    if args[2] then
        if not this.playerHead[root] then
            this.playerHead[root] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)--CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,head)
        end
        this.playerHead[root]:Reset()
        this.playerHead[root]:SetScale(Vector3.one * 0.6)
        this.playerHead[root]:SetHead(args[2].head)
        this.playerHead[root]:SetFrame(args[2].headFrame)
        this.playerHead[root]:SetLevel(args[2].level)
        this.playerHead[root]:SetUID(args[2].uid)
        info.enabled = false
        name.text = args[2].name
        Util.AddOnceClick(head,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, args[2].uid)
        end)
    else
        if this.playerHead[root] then
            this.playerHead[root] = nil
        end
        info.enabled = true
        -- name.text=""
    end
end
--设置每条节点显示
function this.SetNodeShow(root,data,myRank)
    local selfBg = Util.GetGameObject(root,"Content/SelfBg")
    --selfBg.gameObject:SetActive(myRank==data[1].rank)

    --this.SetTitle(root,data.rank)
    this.SetHeadInfo(root,data)
    --this.SetTeamInfo(root,data)
    this.SetRankingNum(root,data.rank)
    local name,power= this.InitRollingInfo(root)
    this.SetShowInfo(name,power,data.name,data.totalForce)
    this.AddPlayerInfoClick(root,data.uid)
    this.SetHeroBtnLike(root,data)
end

--玩家信息弹窗
function this.AddPlayerInfoClick(root,uid)
   local bg = Util.GetGameObject(root,"Content/Bg")
   Util.AddOnceClick(bg,function()
       UIManager.OpenPanel(UIName.PlayerInfoPopup, uid)
   end)
end
--设置名次
function this.SetRankingNum(root,rank)
   local rankImage = Util.GetGameObject(root,"Content/SortNum/SortBg"):GetComponent("Image")
   local rankText = Util.GetGameObject(root,"Content/SortNum/SortText"):GetComponent("Text")

   rankImage.sprite = SetRankNumFrame(rank)
   rankText.text = rank > 3 and rank or ""
end
--设置排名头标签
function this.SetTitle(root,rank)
    local titl = Util.GetGameObject(root,"Title")

    this.CheckInfo(battleStage,root,rank)
    -- title:SetActive(this.CheckActive(battleStage,battleTurn,battleState,rank))
end

--名次标签内容检测
function this.CheckInfo(stage,root,rank)
    local titleBg = Util.GetGameObject(root,"Title/Bg"):GetComponent("Image")
    local titleText = Util.GetGameObject(root,"Title/Bg/Text"):GetComponent("Text")
    local f = function()
        for i = 1, 7 do
            if rank == i and i <= 3 then
                titleBg.sprite = Util.LoadSprite(TitleName[i])
                titleText.text = TitleDesc[i]
                titleText.color = TitleColor[i]
            end
            if rank >= 5 then
                titleBg.sprite = Util.LoadSprite(TitleName[4])
                titleText.color = TitleColor[4]
            end
        end
        if rank == 5 then
            titleText.text = TitleDesc[4]
        elseif rank == 9 then
            titleText.text = TitleDesc[5]
        elseif rank == 17 then
            titleText.text = TitleDesc[6]
        elseif rank == 33 then
            titleText.text = TitleDesc[7]
        end
    end

    if stage == TOP_MATCH_STAGE.CHOOSE then--1选拔赛阶段
        if rank == 1 then--直接显示128
            titleBg.sprite = Util.LoadSprite(TitleName[4])
            titleText.text = TitleDesc[7]
            titleText.color = TitleColor[4]
        end
    elseif stage == TOP_MATCH_STAGE.ELIMINATION then--2 32强淘汰赛阶段
        if rank == 1 then   -- 第一个特殊处理
            local curTurn = battleTurn
            local maxTurn = ArenaTopMatchManager.GetEliminationMaxRound()
            if curTurn <= 0 then curTurn = maxTurn end
            local opTurn = maxTurn - curTurn + 1 --- 将服务器发过来的轮数倒序，方便计算
            local groupNum = math.pow(2, opTurn)
            if opTurn <= 3 then
                titleBg.sprite = Util.LoadSprite(TitleName[opTurn])
                titleText.color = TitleColor[opTurn]
            else
                titleBg.sprite = Util.LoadSprite(TitleName[4])
                titleText.color = TitleColor[4]
            end
            titleText.text = groupNum .. GetLanguageStrById(12589)
        else
            f()
        end
    elseif stage == TOP_MATCH_STAGE.OVER then --活动结束-2 仍显示名次标签
        f()
    end
end
--名次标签显隐状态检测
function this.CheckActive(stage,turn,state,rank)
    -- 第一名永远显示
    if rank == 1 then
        return true
    end
    --
    local open=false
    local _turn
    local f=function()
        --若状态为3 控制数据结算时表现的及时性
        if state==TOP_MATCH_TIME_STATE.OPEN_IN_END then
            turn=turn+1
        end
        for j = 1, turn do
            for i = 1, #TurnIndex do
                if j == i then
                    _turn = TurnIndex[j]--返回唯一
                end
            end
            if rank == math.pow(2,_turn)+1 then--显示4-128
                open = true
                break
            elseif turn == 6 and rank <= 2 and state == 3 then--显示1-2
                open = rank == math.pow(2,0) or rank == math.pow(2,1)
                break
            else
                open = false
            end
        end
    end

    if stage == TOP_MATCH_STAGE.CHOOSE then--1选拔赛阶段
        open = rank == 1
    elseif stage == TOP_MATCH_STAGE.ELIMINATION then--2 32强淘汰赛阶段
        f()
    elseif stage == TOP_MATCH_STAGE.OVER then --活动结束-2 仍显示名次标签
        turn = 5
        state = 3
        f()
    end
    return open
end

--设置头像
function this.SetHeadInfo(root,data)
    local headObj = Util.GetGameObject(root,"Content/Head")
    if not this.playerHead[root] then
        this.playerHead[root] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headObj.transform)--CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,headObj)
    end
    this.playerHead[root]:Reset()
    this.playerHead[root]:SetScale(Vector3.one * 0.6)
    this.playerHead[root]:SetHead(data.head)
    this.playerHead[root]:SetFrame(data.headFrame)
    this.playerHead[root]:SetLevel(data.level)
    this.playerHead[root]:SetUID(data.uid)
end

--设置出战阵容
function this.SetTeamInfo(root,teamData)
    --设置出战角色头像
    for i = 1, 5 do
        local heroHeadBg = Util.GetGameObject(root, "Content/Demons/Head_"..i)
        local hearIcon = Util.GetGameObject(heroHeadBg, "Icon")
        local heroTId = teamData[2].heroTid[i]
        if heroTId then
            heroHeadBg:SetActive(true)
            local demonData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroTId)
            heroHeadBg:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(demonData.Star))
            hearIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(demonData.Icon))
        else
            heroHeadBg:SetActive(false)
        end
    end
end

--设置显示信息
function this.SetShowInfo(name,power,info1,info2)
    name.text = GetLanguageStrById(info1)
    power.text = GetLanguageStrById(12591)..info2
end

--初始化滚动区信息
function this.InitRollingInfo(root)
    local name = Util.GetGameObject(root,"Content/Name"):GetComponent("Text")
    local power = Util.GetGameObject(root,"Content/Power"):GetComponent("Text")
    name.text = ""
    power.text = ""
    return name,power
end
--初始化非滚动区信息
function this.InitUnRollingInfo()
    this.myRank.text = ""
    this.myPower.text = ""
end

--检查是否显示第一页 当切换页签时切换到第一页 当请求下一页时不跳转第一页
function this.CheckIsTop()
    if this.istop then
        this.scrollView:SetIndex(1)
        this.istop = false
    end
end

--排行榜人物点赞
function this.SetHeroBtnLike(root,data)
    local btnLike = Util.GetGameObject(root,"Button_DianZan")
    if data.uid < 10000000 then
        btnLike:SetActive(false)
    else
        btnLike:SetActive(true)
    end
    local btnLikeText = Util.GetGameObject(root,"Button_DianZan/Text_DianZanNum")
    btnLikeText:GetComponent("Text").text = data.likeNums
    local allLisr
    btnLikeList[data.uid] = btnLike.gameObject
    Util.AddOnceClick(btnLike,function()
        if ArenaTopMatchManager.CheckTodayIsAlreadyLike(data.uid) then
            PopupTipPanel.ShowTipByLanguageId(50357)
            return
        end
        NetManager.ArenaTopMatchLikeRequest(data.uid,function()
            NetManager.ArenaTopMatchGetAllSendLikeResponse(function(msg) 
                local alreadyLike = msg.uid
                for i = 1, #alreadyLike do
                    if btnLikeList[alreadyLike[i]] then
                        -- Util.SetGray(btnLikeList[alreadyLike[i]], true)
                        btnLikeText:GetComponent("Text").text = data.likeNums+1 --值对应改变
                        PopupTipPanel.ShowTipByLanguageId(12579)
                        btnLikeList[alreadyLike[i]]:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[2])
                    else
                        -- Util.SetGray(btnLikeList[alreadyLike[i]], false)
                        btnLikeList[alreadyLike[i]]:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[1])
                    end
                end
             end)
        end)
    end)
end

function this.LikeBtnState()
    ArenaTopMatchManager.RequestTodayAlreadyLikeUids_TopMatch(function(msg)
        local alreadyLike = msg.uid
        for k, v in pairs(btnLikeList) do
            local isAlreadyLike = false
            for i = 1, #alreadyLike do
                if alreadyLike[i] == k then
                    isAlreadyLike = true
                end
            end
            Util.SetGray(v, isAlreadyLike)

            if isAlreadyLike then
                v:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[2])
            else
                v:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[1])
            end
        end
    end)

end
return ATM_RankViewPanel