--require("Base/BasePanel")
local this = {}
--local ArenaMainPanel_RankingSingleList = {}
--local this = ArenaMainPanel_RankingSingleList
--头像
this.firsthead = nil
this.playerHeadList = {}--背景前三头像
this.playerScrollHead = {}--滚动条头像

local mapNpc = "live2d_npc_map"
local mapNpc2 = "live2d_npc_map_nv"
local npc, scale

local btnLikeList = {}

--初始化组件（用于子类重写）
function this:InitComponent()
    this.backBtn = Util.GetGameObject(self.gameObject,"bg/btnBack")
    this.BackMask = Util.GetGameObject(self.gameObject,"BackMask") --m5
    this.firsthead = Util.GetGameObject(self.gameObject,"firstHead")
    this.firstheadClick = Util.GetGameObject(self.gameObject,"firstHead/click")
    this.livePrefab = Util.GetGameObject(self.gameObject,"firstHead/livePrefab")
    this.name = Util.GetGameObject(self.gameObject,"bg/name"):GetComponent("Text")
    this.firstHeadName = Util.GetGameObject(self.gameObject,"firstHead/nameText"):GetComponent("Text")
    this.firstHeadinfoGo = Util.GetGameObject(self.gameObject,"firstHead/infoGo")
    this.scrollParentView = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView")
    this.itemPre = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView/ItemPre")
    local v21 = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView"):GetComponent("RectTransform").rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollParentView.transform,this.itemPre,
            nil,Vector2.New(-v21.x*2, -v21.y*2),1,1,Vector2.New(0,8))
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    --this.titleName=Util.GetGameObject(self.gameObject,"RankList/ScrollTitleRoot/Name"):GetComponent("Text")
    --this.titleInfo=Util.GetGameObject(self.gameObject,"RankList/ScrollTitleRoot/Info"):GetComponent("Text")
    this.record = Util.GetGameObject(self.gameObject,"RankList/Record")
    this.info0 = Util.GetGameObject(this.record,"BG/Text"):GetComponent("Text")
    this.rank0 = Util.GetGameObject(this.record,"Rank0"):GetComponent("Text")
    this.info1 = Util.GetGameObject(this.record,"Info1"):GetComponent("Text")
    this.infoGo = Util.GetGameObject(this.record,"infoGo")
    this.selfHead = Util.GetGameObject(this.record,"Head")
    this.selfHeadName = Util.GetGameObject(this.record,"nameText")
    --自己头像展示
    local playerHead
    this.selfHeadName:GetComponent("Text").text = PlayerManager.nickName
    playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.selfHead.transform)
    playerHead:Reset()
    playerHead:SetScale(Vector3.one * 0.7)
    playerHead:SetHead(PlayerManager.head)
    playerHead:SetFrame(PlayerManager.frame)
    --this.rank1=Util.GetGameObject(this.record,"Rank1"):GetComponent("Text")

    this.noneImage = Util.GetGameObject(self.gameObject,"RankList/NoneImage")--无信息图片
end

--绑定事件（用于子类重写）
function this:BindEvent()
    --返回按钮
    Util.AddClick(this.backBtn,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnWarPowerChange, this.SetWarPowerInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnArenaChange, this.SetArenaInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnTrialChange, this.SetTrialInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnMonsterChange, this.SetMonsterInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnAdventureChange, this.SetAdventureInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnCustomsPassChange,this.SetCustomsPassInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnGuildForceChange,this.SetGuildForceInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnGoldExperSortChange,this.SetGoldExperSortInfo)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnWarPowerChange, this.SetWarPowerInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnArenaChange, this.SetArenaInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnTrialChange, this.SetTrialInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnMonsterChange, this.SetMonsterInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnAdventureChange, this.SetAdventureInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnCustomsPassChange, this.SetCustomsPassInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnGuildForceChange,this.SetGuildForceInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnGoldExperSortChange,this.SetGoldExperSortInfo)
end
local sData = nil
--界面打开时调用（用于子类重写）
function this:OnOpen()
    SoundManager.PlayMusic(SoundConfig.BGM_Rank)
    sData = RankKingList[6]
    this.name.text = sData.name
    --设置信息方法的列表
    this.SetInfoFuncList = {
        [FUNCTION_OPEN_TYPE.ALLRANKING] = this.SetWarPowerInfo,
        [FUNCTION_OPEN_TYPE.ARENA] = this.SetArenaInfo,
        [FUNCTION_OPEN_TYPE.TRIAL] = this.SetTrialInfo,
        [FUNCTION_OPEN_TYPE.MONSTER_COMING] = this.SetMonsterInfo,
        [FUNCTION_OPEN_TYPE.FIGHT_ALIEN] = this.SetAdventureInfo,
        [FUNCTION_OPEN_TYPE.CUSTOMSPASS] = this.SetCustomsPassInfo,
        [FUNCTION_OPEN_TYPE.GUILD] = this.SetGuildForceInfo,
        [FUNCTION_OPEN_TYPE.EXPERT] = this.SetGoldExperSortInfo,
    }
    --RankingManager.ClearData()
    this.GetRankInfo(sData.Id)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    --RankingManager.ClearData()
    RankingManager.isRequest = 0
    this.noneImage:SetActive(false)
    
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    for _, playerHead in ipairs(this.playerHeadList) do
        playerHead:Recycle()
    end
    this.playerHeadList = {}
    this.scrollView = nil

    if this.liveNode then
        poolManager:UnLoadLive(npc, this.liveNode)
        this.liveNode = nil
    end

    btnLikeList = {}
end

--点击获取对应排行信息
function this.GetRankInfo(key)
    RankingManager.CurPage = 0
    --local key = RankingManager.GetCurRankingInfo("Id",index)
    this.istop = true
    
    RankingManager.InitData(key, this.SetInfoFuncList[key])--算是半个策略模式吧
    --RankingManager.InitData(key,this.SetArenaInfo)
end

---设置战力排名信息
function this.SetWarPowerInfo()
    local warPowerData,myRankData = RankingManager.GetWarPowerInfo()
    this.noneImage:SetActive(#warPowerData == 0)
    -- 没有排行数据需要立刻刷新，只在打开界面时有用
    if #warPowerData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(11713),
        GetLanguageStrById(11714),
        GetLanguageStrById(10104),
        GetLanguageStrById(11716),
        myRankData.myRank,
        GetLanguageStrById(10041),
        FormationManager.GetFormationPower(1),
        myRankData.myRank,
        myRankData.myForce)
    local dData = {
        rankInfo = {param1 = myRankData.myForce},
        force = myRankData.myForce
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not warPowerData or (warPowerData and #warPowerData <= 0) then
        return
    end
    local dt,db = RankingManager.CutDate(warPowerData)
    this.SetHeadsInfo(dt[1],this.firstHeadinfoGo,1,dt[1].userName,dt[1].level)
    --设置滚动区信息
    this.scrollView:SetData(db,function(index,root)
        this.ShowWarPowerInfo(root,warPowerData[index],myRankData)
        if index == #warPowerData then
            RankingManager.RequestNextWarPowerPageData()
        end
    end)
    this.CheckIsTop()
end

--显示每条数据
function this.ShowWarPowerInfo(root,data,myRankData)
    this.AddPlayerInfoClick(root,data.uid)
    this.SetSelfBG(root,myRankData.myRank, data.rankInfo.rank)
    this.SetRankingNum(root, data.rankInfo.rank)
    this.SetHeadInfo(root,data.head, data.headFrame,data.level)
    this.SetInfoShow(Util.GetGameObject(root,"infoGo"),data,sData.rankType,Util.GetGameObject(root,"Value0"))
end

---设置竞技场排名信息
function this.SetArenaInfo()
    local arenaData, myRankData = RankingManager.GetArenaInfo()
    CheckRedPointStatus(RedPointType.ArenaTodayAlreadyLike)

    this.noneImage:SetActive(#arenaData == 0)
    if #arenaData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(11713),
        GetLanguageStrById(11717),
        GetLanguageStrById(10104),
        GetLanguageStrById(11718),
        myRankData.myRank,GetLanguageStrById(10041),
        "",
        myRankData.myRank,
        myRankData.myScore)
    local dData = {
        rankInfo = {param1 = myRankData.myScore},
        score = myRankData.myScore
    }
    this.SetInfoShow(this.infoGo, dData, sData.rankType)
    --数据拆分
    if not arenaData or (arenaData and #arenaData <= 0) then
        return
    end

    --设置滚动区信息
    this.scrollView:SetData(arenaData,function(index,root)
        this.ShowArenaInfo(root,arenaData[index],myRankData)
        if index == #arenaData then
            RankingManager.RequestNextArenaPageData()
        end
    end)
    this.CheckIsTop()
end

--显示每条数据
function this.ShowArenaInfo(root,data,myRankData)
    this.AddPlayerInfoClick(root,data.personInfo.uid)
    this.SetSelfBG(root,myRankData.myRank,data.personInfo.rank)
    this.SetRankingNum(root,data.personInfo.rank)
    this.SetHeadInfo(root,data.personInfo.head,data.personInfo.headFrame,data.personInfo.level)
    this.SetHeroBtnLike(root,data.personInfo)

    Util.GetGameObject(root,"name"):GetComponent("Text").text = data.personInfo.name
    Util.GetGameObject(root,"totalForce"):GetComponent("Text").text = tostring(data.personInfo.totalForce)
    Util.GetGameObject(root,"integral"):GetComponent("Text").text = tostring(data.personInfo.score)
end

---设置试炼排名信息
function this.SetTrialInfo()
    local trialData,myRankData=RankingManager.GetTrialInfo()
    this.noneImage:SetActive(#trialData == 0)
    if #trialData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(11713),
        GetLanguageStrById(11719),
        GetLanguageStrById(10104),
        GetLanguageStrById(11720),
        myRankData.rank,
        GetLanguageStrById(10041),
        myRankData.highestTower,myRankData.rank,
        myRankData.highestTower..GetLanguageStrById(10319))
    local dData = {
        rankInfo = {param1 = myRankData.highestTower},
        force = myRankData.highestTower
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not trialData or (trialData and #trialData <= 0) then
        return
    end
    local dt,db = RankingManager.CutDate(trialData)
    
    this.SetHeadsInfo(dt[1],this.firstHeadinfoGo,1,dt[1].userName,dt[1].level)
    this.scrollView:SetData(db,function(index,root)
        this.ShowTrialInfo(root,trialData[index],myRankData)
    end)
    this.CheckIsTop()
end

--显示每条数据
function this.ShowTrialInfo(root,data,myRankData)
    this.AddPlayerInfoClick(root,data.uid)
    this.SetSelfBG(root,myRankData.rank,data.rankInfo.rank)
    this.SetRankingNum(root,data.rankInfo.rank)
    this.SetHeadInfo(root,data.head,data.headFrame,data.level)
    this.SetInfoShow(Util.GetGameObject(root,"infoGo"),data,sData.rankType,Util.GetGameObject(root,"Value0"))
end

---设置兽潮玩家排名信息
function this.SetMonsterInfo()
    local monsterData,myRankData=RankingManager.GetMonsterInfo()
    this.noneImage:SetActive(#monsterData==0)
    if #monsterData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    local myScore = myRankData.myScore and myRankData.myScore or 0
    this.SetNotRollingInfo(GetLanguageStrById(11713),
        GetLanguageStrById(11719),
        GetLanguageStrById(10104),
        GetLanguageStrById(11721),
        myRankData.myRank,GetLanguageStrById(10041),
        "0",myRankData.myRank,
        GetLanguageStrById(10311) .. myScore  .. GetLanguageStrById(10316))
    local dData = {
        rankInfo = {param1 = myRankData.myScore},
        force = myRankData.myScore
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not monsterData or (monsterData and #monsterData <= 0) then
        return
    end
    local dt,db = RankingManager.CutDate(monsterData)
    this.SetHeadsInfo(dt[1],this.firstHeadinfoGo,1,dt[1].userName,dt[1].level)
    this.scrollView:SetData(db,function(index,root)
        this.ShowMonsterInfo(root,monsterData[index],myRankData)
    end)
    this.CheckIsTop()
end

--显示每条数据
function this.ShowMonsterInfo(root,data,myRankData)
    this.AddPlayerInfoClick(root,data.uid)
    this.SetSelfBG(root,myRankData.myRank,data.rankInfo.rank)
    this.SetRankingNum(root,data.rankInfo.rank)
    this.SetHeadInfo(root,data.head,data.headFrame,data.level)
    this.SetInfoShow(Util.GetGameObject(root,"infoGo"),data,sData.rankType,Util.GetGameObject(root,"Value0"))
end

---设置外敌排名信息
function this.SetAdventureInfo()
    local adventureData,myRankData = RankingManager.GetAdventureInfo()
    this.noneImage:SetActive(#adventureData == 0)
    if #adventureData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(11713),
        GetLanguageStrById(11722),
        GetLanguageStrById(10104),
        GetLanguageStrById(11722),
        myRankData.rank,
        GetLanguageStrById(10041),
        myRankData.hurt,
        myRankData.rank,
        myRankData.hurt)
    local dData = {
        rankInfo = {param1 = myRankData.hurt},
        force = myRankData.hurt
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not adventureData or (adventureData and #adventureData <= 0) then
        return
    end
    local dt,db = RankingManager.CutDate(adventureData)
    this.SetHeadsInfo(dt[1],this.firstHeadinfoGo,1,dt[1].name,dt[1].level)
    this.scrollView:SetData(db,function(index,root)
        this.ShowAdventureInfo(root,adventureData[index],myRankData)
        if index == #adventureData then
            RankingManager.RequestNextAdventurePageData()
        end
    end)
    this.CheckIsTop()
end

--显示每条数据
function this.ShowAdventureInfo(root,data,myRankData)
    this.AddPlayerInfoClick(root,data.uid)
    this.SetSelfBG(root,myRankData.rank,data.rank)
    this.SetRankingNum(root,data.rank)
    this.SetHeadInfo(root,data.head,data.headFrame,data.level)
    this.SetInfoShow(Util.GetGameObject(root,"infoGo"),data,sData.rankType,Util.GetGameObject(root,"Value0"))
end

---设置关卡排名信息
function this.SetCustomsPassInfo()
    local data,myData = RankingManager.GetCustomsPassInfo()
    this.noneImage:SetActive(#data == 0)
    if #data == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()

    local myRankText = ""
    if myData.fightId < 0 then
        myRankText = GetLanguageStrById(10041)
    else
        myRankText = RankingManager.mainLevelConfig[myData.fightId].Name
    end
    this.SetNotRollingInfo(GetLanguageStrById(11713),
        GetLanguageStrById(11723),
        GetLanguageStrById(10104),
        GetLanguageStrById(11724),
        myData.myRank,GetLanguageStrById(10041),
        "",myData.myRank, myRankText)
    
    local dData = {
        rankInfo = {param1 = myData.fightId},
        force = myData.fightId
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    
    --local curdata = table.remove(data,1)
    
    --数据拆分
    if not data or (data and #data <= 0) then
        return
    end
    local dt,db = RankingManager.CutDate(data)
    this.SetHeadsInfo(dt[1],this.firstHeadinfoGo,1,dt[1].userName,dt[1].level)
    this.scrollView:SetData(db,function(index,root)
        this.ShowCustomsPassInfo(root,data[index],myData)
    end)
    this.CheckIsTop()
end

--显示每条数据
function this.ShowCustomsPassInfo(root,data,myRankData)
    if data.rankInfo.param1 > 0 then
        this.AddPlayerInfoClick(root,data.uid)
        this.SetSelfBG(root,myRankData.myRank,data.rankInfo.rank)
        this.SetRankingNum(root,data.rankInfo.rank)
        this.SetHeadInfo(root,data.head,data.headFrame,data.level)
        this.SetInfoShow(Util.GetGameObject(root,"infoGo"),data,sData.rankType,Util.GetGameObject(root,"Value0"))
    end
end

---设置公会战力信息
function this.SetGuildForceInfo()
    local data,myData = RankingManager.GetGuildForeInfo()
    this.noneImage:SetActive(#data == 0)
    if #data == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()

    local myRankText = ""
    if not myData.myRank or myData.myRank < 0 then
        myRankText = GetLanguageStrById(10041)
    else
        myRankText = myData.myRank
    end
    this.SetNotRollingInfo("",
        "",GetLanguageStrById(10104),
        "",
        myData.myRank,GetLanguageStrById(10041),
        "",
        myData.myRank,
        myRankText)
    local dData = {
        rankInfo = {rank = myData.myRank ,param1= myData.myForce},
        guildName = PlayerManager.familyId == 0 and "" or MyGuildManager.GetMyGuildInfo().name
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not data or (data and #data <= 0) then
        return
    end
    local dt,db = RankingManager.CutDate(data)
    this.SetHeadsInfo(dt[1],this.firstHeadinfoGo,1,dt[1].guildName,dt[1].level)
    this.scrollView:SetData(db,function(index,root)
        this.ShowGuildForceInfo(root,data[index],myData)
    end)
    this.CheckIsTop()
end

--显示每条数据
function this.ShowGuildForceInfo(root,data,myRankData)
    if data.rankInfo.param1 > 0 then
        this.AddPlayerInfoClick(root,data.uid)
        this.SetSelfBG(root,myRankData.myRank,data.rankInfo.rank)
        this.SetRankingNum(root,data.rankInfo.rank)
        this.SetHeadInfo(root,data.head,data.headFrame,data.level)
        this.SetInfoShow(Util.GetGameObject(root,"infoGo"),data,sData.rankType,Util.GetGameObject(root,"Value0"))
    end
end

--设置点金信息
function this.SetGoldExperSortInfo()
    local data,myData = RankingManager.GetGoldExperSortInfo()
    this.noneImage:SetActive(#data == 0)
    if #data == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()

    local myRankText = ""
    if not myData.myRank or myData.myRank < 0 then
        myRankText = GetLanguageStrById(10041)
    else
        myRankText = myData.myRank
    end

    this.SetNotRollingInfo("",
        "",
        GetLanguageStrById(10104),
        "",
        myData.myRank,
        GetLanguageStrById(10041),
        "",
        myData.myRank,
        myRankText)
    local dData = {
        rankInfo = {rank = myData.myRank ,param1= myData.myNum},
        userName = PlayerManager.nickName
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not data or (data and #data <= 0) then
        return
    end
     local dt,db = RankingManager.CutDate(data)
     
    this.SetHeadsInfo(dt[1],this.firstHeadinfoGo,1,dt[1].userName,dt[1].level)
    this.scrollView:SetData(db,function(index,root)
        this.ShowGoldExperSortInfo(root,data[index],myData)
    end)
    this.CheckIsTop()
end
--显示每条数据
function this.ShowGoldExperSortInfo(root,data,myRankData)
    if data.rankInfo.param1 > 0 then
        this.AddPlayerInfoClick(root,data.uid)
        this.SetSelfBG(root,myRankData.myRank,data.rankInfo.rank)
        this.SetRankingNum(root,data.rankInfo.rank)
        this.SetHeadInfo(root,data.head,data.headFrame,data.level)
        this.SetInfoShow(Util.GetGameObject(root,"infoGo"),data,sData.rankType,Util.GetGameObject(root,"Value0"))
    end
end

--设置前三名背景头像
function this.SetHeadsInfo(data,root,index,name,level)
    if not this.playerHeadList[root] then
        this.playerHeadList[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,Util.GetGameObject(this.firsthead,"Head"))
    end
    this.firsthead:SetActive(true)
    this.playerHeadList[root]:Reset()
    this.playerHeadList[root]:SetHead(data.head)
    this.playerHeadList[root]:SetFrame(data.headFrame)
    this.playerHeadList[root]:SetLevel(level)
    this.playerHeadList[root]:SetParent(Util.GetGameObject(this.firsthead,"Head"))
    if index == 1 then
        this.playerHeadList[root]:SetPosition(Vector3(0,0,0))
        this.playerHeadList[root]:SetScale(Vector3.one*0.6)
        this.firstHeadName.text = name
        this.SetInfoShow(this.firstHeadinfoGo,data,sData.rankType)
        --data.sex
        --加载立绘
        if this.liveNode then
            poolManager:UnLoadLive(npc, this.liveNode)
            this.liveNode=nil
        end
        npc = data.sex == ROLE_SEX.BOY and mapNpc or mapNpc2
        local scale =  data.sex == ROLE_SEX.BOY and Vector3.one * 0.32 or Vector3.one * 0.19
        this.liveNode = poolManager:LoadLive(npc, this.livePrefab.transform, scale, Vector3.New(0,-158.31,0))
        Util.AddOnceClick(this.firstheadClick,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end)

    end
end
--初始化非滚动区信息
function this.InitNotRollingInfo()
    this.firsthead:SetActive(false)
    this.firstHeadName.text = ""
    this.info0.text = ""
    this.info1.text = ""
    this.rank0.text = ""
end

--设置非滚动区信息
function this.SetNotRollingInfo(...)
    local args = {...}
    this.info0.text = args[3]--底部信息
    this.info1.text = args[4]

    if not args[5] or args[5] < 1 then--排名对比 < 0未上榜
        this.rank0.text = args[6] --未上榜
        this.SetRankingNum(this.record, args[6])
    else
        this.rank0.text = args[8] --上榜
        this.SetRankingNum(this.record, args[8])
        --this.rank1.text = args[9] --显示内容
    end
end

--初始化滚动区信息
function this.InitRollingInfo(_root)
    local info0 = Util.GetGameObject(_root,"Value0"):GetComponent("Text")
    info0.text = ""
    return info0--,info1
end
--玩家信息弹窗
function this.AddPlayerInfoClick(root,uid)
    local clickBtn = Util.GetGameObject(root,"ClickBtn")
    Util.AddOnceClick(clickBtn,function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, uid)
    end)
end

--设置自身背景
function this.SetSelfBG(root,myRank,rank)
end

--设置名次
function this.SetRankingNum(root, rank)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] = Util.GetGameObject(root,"SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if type(rank) == "number" and rank < 4 then
        sortNumTabs[rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rank
    end

    --底板颜色根据排名更改
    local spriteName
    local colorValue

    if rank == 1 then
        spriteName = "cn2-X1_tongyong_liebiao_02"
        colorValue = Color.New(1, 0.7764706, 0.1568628, 1)
    elseif rank == 2 then
        spriteName = "cn2-X1_tongyong_liebiao_03"
        colorValue = Color.New(1, 0.6627451, 0.3607843, 1)
    elseif rank ==3 then
        spriteName = "cn2-X1_tongyong_liebiao_04"
        colorValue = Color.New(1, 0.6117647, 0.5803922, 1)
    else
        spriteName = "cn2-X1_tongyong_liebiao_05"
        colorValue = Color.New(0.7803922,0.5529412, 0.9960784, 1)
    end

    Util.GetGameObject(root, "BG/Image_BG1"):GetComponent("Image").sprite = Util.LoadSprite(spriteName)
    Util.GetGameObject(root, "BG/Image_BG2"):GetComponent("Image").color = colorValue
end
--设置头像
function this.SetHeadInfo(root,head,frame,level)
    local headObj = Util.GetGameObject(root,"Head")
    if not this.playerScrollHead[root] then
        this.playerScrollHead[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,headObj)
    end
    this.playerScrollHead[root]:Reset()
    this.playerScrollHead[root]:SetHead(head)
    this.playerScrollHead[root]:SetFrame(frame)
    this.playerScrollHead[root]:SetLevel(level)
    this.playerScrollHead[root]:SetScale(Vector3.one * 0.55)
end

local btnLikeSpriteName_dianzan = GetPictureFont("cn2-X1_jingjichang_dianzan")
local btnLikeSpriteName_yizan = GetPictureFont("cn2-X1_jingjichang_yizan")
--排行榜人物点赞
function this.SetHeroBtnLike(root,data)
    local btnLike = Util.GetGameObject(root,"btnPraise")
    local btnLikeText = Util.GetGameObject(root,"Text_DianZan")
    local redpoint = Util.GetGameObject(btnLike , "redpoint")
    btnLikeText:GetComponent("Text").text = data.likeNums

    btnLikeList[data.uid] = btnLike.gameObject
    if ArenaManager.CheckTodayIsAlreadyLike(data.uid) then
        btnLike:GetComponent("Image").sprite = Util.LoadSprite(btnLikeSpriteName_yizan)
        redpoint:SetActive(false)
    else
        btnLike:GetComponent("Image").sprite = Util.LoadSprite(btnLikeSpriteName_dianzan)
        redpoint:SetActive(ArenaManager.RefreshAlreadyLikeRedpoint())
    end

    Util.AddOnceClick(btnLike,function()
        if ArenaManager.CheckTodayIsAlreadyLike(data.uid) then
            PopupTipPanel.ShowTipByLanguageId(90010029)
            return
        end
        NetManager.RedPackageLikeRequest(data.uid,function()
            ArenaManager.AddTodayAlreadyLikeUids_Arena(data.uid)
            this.SetArenaInfo()
            data.likeNums = data.likeNums + 1
            btnLikeText:GetComponent("Text").text = data.likeNums
            PopupTipPanel.ShowTipByLanguageId(12579)
        end)
    end)
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "Image")
    local lockImage = Util.GetGameObject(tab,"LockImage")
    local txt = Util.GetGameObject(tab, "Text")

    if status == "lock" then
        lockImage:SetActive(true)
        lockImage:GetComponent("Image").sprite = Util.LoadSprite(_tabImageData[status])
        txt:GetComponent("Text").text = RankingManager.GetTabTextData()[index].txt
        txt:GetComponent("Text").color = _tabFontColor[status]
    else
        lockImage:SetActive(false)
        img:GetComponent("Image").sprite = Util.LoadSprite(_tabImageData[status])
        txt:GetComponent("Text").text = RankingManager.GetTabTextData()[index].txt
        txt:GetComponent("Text").color = _tabFontColor[status]
    end
end
--检查是否显示第一页 当切换页签时切换到第一页 当请求下一页时不跳转第一页
function this.CheckIsTop()
    if this.istop then
        this.scrollView:SetIndex(1)
        this.istop = false
    end
end
--检查Tab是否解锁
function this.CheckTabCtrlIsLockP(index)
    local type = RankingManager.GetCurRankingInfo("Id",index)
    local des = RankingManager.GetCurRankingInfo("Des",index)
    local b,str = this.CheckTabCtrlIsLockS(type,des)
    if b then
        return b,str
    end
    return false
end
function this.CheckTabCtrlIsLockS(type,des)
    if type == 8 then
        if not ActTimeCtrlManager.IsQualifiled(type) then
            return true, des..ActTimeCtrlManager.GetFuncTip(type)
        end
    else
        if not ActTimeCtrlManager.SingleFuncState(type) then
            return true, des..ActTimeCtrlManager.GetFuncTip(type)
        end
    end
end
function this.SetInfoShow(go,data,rankType,Value0)
    local  fight = Util.GetGameObject(go,"fight")
    local  warPower = Util.GetGameObject(go,"warPower")
    local  trial = Util.GetGameObject(go,"trial")
    local  goldExper = Util.GetGameObject(go,"goldExper")
    local  arenaScore = Util.GetGameObject(go,"arenaScore")
    fight:SetActive(false)
    warPower:SetActive(false)
    trial:SetActive(false)
    goldExper:SetActive(false)
    arenaScore:SetActive(false)
    if rankType == RANK_TYPE.FIGHT_LEVEL_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            fight:SetActive(true)
            if Value0 then
                Value0:GetComponent("Text").text = "<size=40%>"..data.userName.."</size>"
            end
            Util.GetGameObject(go,"fight"):GetComponent("Text").text = RankingManager.mainLevelConfig[data.rankInfo.param1].Name
        end
    elseif rankType == RANK_TYPE.FORCE_CURR_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 >0 then
            warPower:SetActive(true)
            if Value0 then
                Value0:GetComponent("Text").text = "<size=40%>"..data.userName.."</size>"
            end
            Util.GetGameObject(go,"warPower/Text"):GetComponent("Text").text = data.rankInfo.param1--data.force
        end
    elseif rankType == RANK_TYPE.GUILD_FORCE_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            warPower:SetActive(true)
            if Value0 then
                Value0:GetComponent("Text").text = "<size=40%>"..data.guildName.."</size>"
            end
            Util.GetGameObject(go,"warPower/Text"):GetComponent("Text").text = data.rankInfo.param1
        end
    elseif rankType == RANK_TYPE.MONSTER_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            trial:SetActive(true)
            if Value0 then
                Value0:GetComponent("Text").text = "<size=40%>"..data.userName.."</size>"
            end
            Util.GetGameObject(go,"trial/Text"):GetComponent("Text").text = data.rankInfo.param1
            Util.GetGameObject(go,"trial"):GetComponent("Text").text = GetLanguageStrById(11745)
        end
    elseif rankType == RANK_TYPE.GOLD_EXPER then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            goldExper:SetActive(true)
            if Value0 then
                Value0:GetComponent("Text").text = "<size=40%>"..data.userName.."</size>"
            end
            Util.GetGameObject(go,"goldExper/Text"):GetComponent("Text").text = data.rankInfo.param1
        end
    elseif rankType == RANK_TYPE.ARENA_RANK then
        -- if data.personInfo.score and data.personInfo.score > 0 then
            arenaScore:SetActive(true)
            if Value0 then
                Value0:GetComponent("Text").text = "<size=40%>"..data.personInfo.name .."</size>"
                Util.GetGameObject(go,"arenaScore"):GetComponent("Text").text = data.personInfo.score
            else
                Util.GetGameObject(go,"arenaScore"):GetComponent("Text").text = data.score
            end
        -- end
    end
end
return this