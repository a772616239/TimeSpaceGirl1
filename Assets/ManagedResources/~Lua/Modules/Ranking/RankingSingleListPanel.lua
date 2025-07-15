require("Base/BasePanel")
RankingSingleListPanel = Inherit(BasePanel)
local this = RankingSingleListPanel
--头像
this.firsthead = nil
this.playerHeadList = {}--背景前三头像
this.playerHeroListHead= {} --背景前三英雄头像 
this.playerHeroListGo= {} --背景前三英雄头像 
this.playerScrollHead = {}--滚动条头像

local mapNpc = "live2d_npc_map"
local mapNpc2 = "live2d_npc_map_nv"
local npc, scale

--初始化组件（用于子类重写）
function RankingSingleListPanel:InitComponent()
    this.backBtn = Util.GetGameObject(self.gameObject,"bg/btnBack")
    this.BackMask = Util.GetGameObject(self.gameObject,"BackMask")
    this.firsthead = Util.GetGameObject(self.gameObject,"firstHead")
    this.firstheadClick = Util.GetGameObject(self.gameObject,"firstHead/click")
    this.livePrefab = Util.GetGameObject(self.gameObject,"firstHead/livePrefab")
    this.name = Util.GetGameObject(self.gameObject,"bg/name"):GetComponent("Text")
    this.firstHeadName = Util.GetGameObject(self.gameObject,"firstHead/nameText"):GetComponent("Text")
    this.firstHeadinfoGo = Util.GetGameObject(self.gameObject,"firstHead/infoGo")

    this.secondhead = Util.GetGameObject(self.gameObject,"secondHead")
    this.secondheadClick = Util.GetGameObject(self.gameObject,"secondHead/click")
    this.secondlivePrefab = Util.GetGameObject(self.gameObject,"secondHead/livePrefab")    
    this.secondHeadName = Util.GetGameObject(self.gameObject,"secondHead/nameText"):GetComponent("Text")
    this.secondHeadinfoGo = Util.GetGameObject(self.gameObject,"secondHead/infoGo")

    this.thirdhead = Util.GetGameObject(self.gameObject,"thirdHead")
    this.thirdheadClick = Util.GetGameObject(self.gameObject,"thirdHead/click")
    this.thirdlivePrefab = Util.GetGameObject(self.gameObject,"thirdHead/livePrefab")    
    this.thirdHeadName = Util.GetGameObject(self.gameObject,"thirdHead/nameText"):GetComponent("Text")
    this.thirdHeadinfoGo = Util.GetGameObject(self.gameObject,"thirdHead/infoGo")

    this.scrollParentView = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView")
    this.itemPre = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView/ItemPre")
    this.lvPre = Util.GetGameObject(self.gameObject,"RankList/ScrollParentView/lvtext")

    local v2 = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollParentView.transform,this.itemPre,
            nil,Vector2.New(-v2.x*2, -v2.y*2),1,1,Vector2.New(0,8))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.record = Util.GetGameObject(self.gameObject,"RankList/Record")
    this.noneImage = Util.GetGameObject(self.gameObject,"RankList/NoneImage")--无信息图片

    --
    this.TextTopEnd = Util.GetGameObject(self.gameObject, "title/Text (2)"):GetComponent("Text")
    this.myRank = Util.GetGameObject(this.record, "Rank0"):GetComponent("Text")
    this.myRankName = Util.GetGameObject(this.record, "nameText")
    this.infoGo = Util.GetGameObject(this.record,"infoGo")

    this.MyRankHead = Util.GetGameObject(this.record, "Head")
    this.MyRankHeroHead = Util.GetGameObject(this.record, "HeroHead")
end

--绑定事件（用于子类重写）
function RankingSingleListPanel:BindEvent()
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
function RankingSingleListPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnWarPowerChange, this.SetWarPowerInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnArenaChange, this.SetArenaInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnTrialChange, this.SetTrialInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnMonsterChange, this.SetMonsterInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnAdventureChange, this.SetAdventureInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnCustomsPassChange,this.SetCustomsPassInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnGuildForceChange,this.SetGuildForceInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnGoldExperSortChange,this.SetGoldExperSortInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnClimbTowerChange,this.SetClimbTowerInfo)
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnAlameinWarChange,this.SetAlameinWarInfo)
end

--移除事件监听（用于子类重写）
function RankingSingleListPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnWarPowerChange, this.SetWarPowerInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnArenaChange, this.SetArenaInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnTrialChange, this.SetTrialInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnMonsterChange, this.SetMonsterInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnAdventureChange, this.SetAdventureInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnCustomsPassChange, this.SetCustomsPassInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnGuildForceChange,this.SetGuildForceInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnGoldExperSortChange,this.SetGoldExperSortInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnClimbTowerChange, this.SetClimbTowerInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnAlameinWarChange, this.SetAlameinWarInfo)
end

local sData = nil
--界面打开时调用（用于子类重写）
function RankingSingleListPanel:OnOpen(_sData)
    SoundManager.PlayMusic(SoundConfig.BGM_Rank)
    sData = _sData
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
        [FUNCTION_OPEN_TYPE.CLIMB_TOWER] = this.SetClimbTowerInfo,
        [FUNCTION_OPEN_TYPE.ALAMEIN_WAR] = this.SetAlameinWarInfo,
        [RANK_TYPE.CELEBRATION_GUILD] = this.SetGoldExperGuildSortInfo,
        [RANK_TYPE.HERO_FORCE_RANK] = this.SetHeroForceSortInfo,
    }
    RankingManager.ClearData()
    this.GetRankInfo(sData.Id, sData)

    this.record:SetActive(true)

    --英雄排行榜 
    if sData.rankType == RANK_TYPE.HERO_FORCE_RANK then
        this.MyRankHead :SetActive(false)
        this.MyRankHeroHead :SetActive(true)
    else 
        this.MyRankHead :SetActive(true)
        this.MyRankHeroHead :SetActive(false)
    end

    -- if sData.rankType == RANK_TYPE.GUILD_FORCE_RANK then
    --     this.record:SetActive(false)
    -- end    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RankingSingleListPanel:OnShow()
    --重新打开时刷新数据 由于头像原因仅刷新英雄排行
    if sData.rankType == RANK_TYPE.HERO_FORCE_RANK then
        this.name.text = sData.name
        RankingManager.ClearData()
        this.GetRankInfo(sData.Id, sData)
        this.record:SetActive(true)

        this.MyRankHead :SetActive(false)
        this.MyRankHeroHead :SetActive(true)
    end 
end

--界面关闭时调用（用于子类重写）
function RankingSingleListPanel:OnClose()
    RankingManager.ClearData()
    RankingManager.isRequest = 0    
    this.noneImage:SetActive(false)

    Util.GetGameObject(this.firsthead,"Head"):SetActive(true) 
    Util.GetGameObject(this.secondhead,"Head"):SetActive(true) 
    Util.GetGameObject(this.thirdhead,"Head"):SetActive(true) 

    for k, v in ipairs(this.playerHeroListGo) do
        SubUIManager.Close(SubUIConfig.ItemView, v)
        GameObject.DestroyImmediate(v)
    end

    this.playerHeroListGo = {}
    this.playerHeroListHead = {}
    -- this.HideList()
end

--界面销毁时调用（用于子类重写）
function RankingSingleListPanel:OnDestroy()
    for _, playerHead in ipairs(this.playerHeadList) do
         playerHead:Recycle()
    end
    this.playerHeroListHead ={}
    this.playerHeadList = {}
    this.scrollView = nil

end

--点击获取对应排行信息
function this.GetRankInfo(key, sData)
    RankingManager.CurPage = 0
    --local key = RankingManager.GetCurRankingInfo("Id",index)
    this.istop = true
    this.activiteId = nil
    if sData and sData.activiteId and sData.activiteId > 0 then
        this.activiteId = sData.activiteId
    end
    
    RankingManager.InitData(key, this.SetInfoFuncList[key], this.activiteId)--算是半个策略模式吧
end

------------ 迷雾之战
function this.SetAlameinWarInfo()
    local ranksData, myRankData = RankingManager.GetAlameinWarInfo()
    this.scrollParentView:SetActive(#ranksData ~= 0)
    this.noneImage:SetActive(#ranksData == 0)
    if #ranksData == 0 then
        this.isRefreshNow = true
    end
    local param1 = myRankData.param1 and myRankData.param1 or 0
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(11729), myRankData.rank)                    --< 设置名次 上榜头像
    local dData = {
        rankInfo = {param1 = myRankData.param1, param2 = myRankData.param2},
        userName = PlayerManager.nickName
    }
    
    this.SetInfoShow(this.infoGo, dData, sData.rankType, this.myRankName)        -- 设置名字 topend
    --数据拆分
    if not ranksData or (ranksData and #ranksData <= 0) then
        return
    end
    local list = {}
    for i = 1, #ranksData do
        if ranksData[i].rankInfo.rank ~= 0 then
            table.insert(list, ranksData[i])
        end
    end
    if #ranksData >= 1 then
        this.SetHeadsInfo(ranksData[1], this.firstHeadinfoGo,1, ranksData[1].userName, ranksData[1].level)
    end
    if #ranksData >= 2 then
        this.SetHeadsInfo(ranksData[2], this.secondHeadinfoGo,2, ranksData[2].userName, ranksData[2].level)
    end
    if #ranksData >= 3 then
        this.SetHeadsInfo(ranksData[3], this.thirdHeadinfoGo,3, ranksData[3].userName, ranksData[3].level)
    end
    this.scrollView:SetData(ranksData, function(index, root)
        this.ShowAlameinWarInfo(root, ranksData[index], myRankData)
    end)
    this.CheckIsTop()
end

-- 显示每条数据
function this.ShowAlameinWarInfo(root, data, myRankData)
    this.AddPlayerInfoClick(root, data.uid)
    this.SetSelfBG(root, myRankData.myRank, data.rankInfo.rank)
    this.SetRankingNum(root, data.rankInfo.rank)
    this.SetHeadInfo(root, data.head, data.headFrame, data.level)
    this.SetInfoShow(Util.GetGameObject(root, "infoGo"), data, sData.rankType, Util.GetGameObject(root, "Value0"))
end

------------设置神之塔玩家排名信息
function this.SetClimbTowerInfo()
    local ranksData, myRankData = RankingManager.GetClimbTowerInfo()
    this.scrollParentView:SetActive(#ranksData ~= 0)
    this.noneImage:SetActive(#ranksData == 0)
    if #ranksData == 0 then
        this.isRefreshNow = true
    end
    local param1 = myRankData.param1 and myRankData.param1 or 0
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(12669), myRankData.rank)                    --< 设置名次 上榜头像
    local dData = {
        rankInfo = {param1 = myRankData.param1},
        userName = PlayerManager.nickName
    }
    this.SetInfoShow(this.infoGo, dData, sData.rankType, this.myRankName)        --< 设置名字 topend
    --数据拆分
    if not ranksData or (ranksData and #ranksData <= 0) then
        return
    end
    local list = {}
    for i = 1, #ranksData do
        if ranksData[i].rankInfo.rank ~= 0 then
            table.insert(list, ranksData[i])
        end
    end
    ranksData = list
    if #ranksData >= 1 then
        this.SetHeadsInfo(ranksData[1], this.firstHeadinfoGo,1, ranksData[1].userName, ranksData[1].level)
    end
    if #ranksData >= 2 then
        this.SetHeadsInfo(ranksData[2], this.secondHeadinfoGo,2, ranksData[2].userName, ranksData[2].level)
    end
    if #ranksData >= 3 then
        this.SetHeadsInfo(ranksData[3], this.thirdHeadinfoGo,3, ranksData[3].userName, ranksData[3].level)
    end
    this.scrollView:SetData(ranksData, function(index, root)
        this.ShowClimbTowerInfo(root, ranksData[index], myRankData)
    end)
    this.CheckIsTop()
end
-- 显示每条数据
function this.ShowClimbTowerInfo(root, data, myRankData)
    this.AddPlayerInfoClick(root, data.uid)
    this.SetSelfBG(root, myRankData.myRank, data.rankInfo.rank)
    this.SetRankingNum(root, data.rankInfo.rank)
    this.SetHeadInfo(root, data.head, data.headFrame, data.level)
    this.SetInfoShow(Util.GetGameObject(root, "infoGo"), data, sData.rankType, Util.GetGameObject(root, "Value0"))
end

------------设置战力排名信息
function this.SetWarPowerInfo()
    local warPowerData,myRankData = RankingManager.GetWarPowerInfo()
    this.noneImage:SetActive(#warPowerData == 0)
    this.scrollParentView:SetActive(#warPowerData ~= 0)
    -- 没有排行数据需要立刻刷新，只在打开界面时有用
    if #warPowerData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(12667),myRankData.myRank)
    local dData = {
        rankInfo = {param1 = myRankData.myForce},
        userName = PlayerManager.nickName
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType, this.myRankName)
    --数据拆分
    if not warPowerData or (warPowerData and #warPowerData <= 0) then
        return
    end
    --local dt,db = RankingManager.CutDate(warPowerData)
    this.SetHeadsInfo(warPowerData[1],this.firstHeadinfoGo,1,warPowerData[1].userName,warPowerData[1].level)
    if #warPowerData >= 2 then
        this.SetHeadsInfo(warPowerData[2],this.secondHeadinfoGo,2,warPowerData[2].userName,warPowerData[2].level)
    end
    if #warPowerData >= 3 then
        this.SetHeadsInfo(warPowerData[3],this.thirdHeadinfoGo,3,warPowerData[3].userName,warPowerData[3].level)
    end

    --设置滚动区信息
    this.scrollView:SetData(warPowerData,function(index,root)
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

------------设置逐胜场排名信息
function this.SetArenaInfo()
    local arenaData,myRankData = RankingManager.GetArenaInfo()
    this.scrollParentView:SetActive(#arenaData ~= 0)
    this.noneImage:SetActive(#arenaData == 0)
    if #arenaData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(11713),GetLanguageStrById(11717),GetLanguageStrById(10104),GetLanguageStrById(11718),myRankData.myRank,GetLanguageStrById(10041),"",myRankData.myRank,myRankData.myScore)
    local dData = {
        rankInfo = {param1 = myRankData.myScore},
        score = myRankData.myScore
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not arenaData or (arenaData and #arenaData <= 0) then
        return
    end
    --local dt,db = RankingManager.CutDate(arenaData)
    this.SetHeadsInfo(arenaData[1].personInfo,this.firstHeadinfoGo,1,arenaData[1].personInfo.name,arenaData[1].personInfo.level)   
    if #arenaData >= 2 then
        this.SetHeadsInfo(arenaData[2],this.secondHeadinfoGo,2,arenaData[2].name,arenaData[2].level)
    end
    if #arenaData >= 3 then
        this.SetHeadsInfo(arenaData[3],this.thirdHeadinfoGo,3,arenaData[3].name,arenaData[3].level)
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
    this.SetInfoShow(Util.GetGameObject(root,"infoGo"),data,sData.rankType,Util.GetGameObject(root,"Value0"))
end

------------设置试炼排名信息
function this.SetTrialInfo()
    local trialData,myRankData = RankingManager.GetTrialInfo()
    this.scrollParentView:SetActive(#trialData ~= 0)
    this.noneImage:SetActive(#trialData == 0)
    if #trialData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(11720),myRankData.rank)
    local dData = {
        rankInfo = {param1 = myRankData.highestTower},
        force = myRankData.highestTower
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not trialData or (trialData and #trialData <= 0) then
        return
    end
    --local dt,db = RankingManager.CutDate(trialData)
    this.SetHeadsInfo(trialData[1],this.firstHeadinfoGo,1,trialData[1].userName,trialData[1].level)
    
    if #trialData >= 2 then
        this.SetHeadsInfo(trialData[2],this.secondHeadinfoGo,2,trialData[2].userName,trialData[2].level)
    end
    if #trialData >= 3 then
        this.SetHeadsInfo(trialData[3],this.thirdHeadinfoGo,3,trialData[3].userName,trialData[3].level)
    end

    this.scrollView:SetData(trialData,function(index,root)
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

------------设置兽潮玩家排名信息
function this.SetMonsterInfo()
    local monsterData,myRankData = RankingManager.GetMonsterInfo()
    this.scrollParentView:SetActive(#monsterData ~= 0)
    this.noneImage:SetActive(#monsterData == 0)
    if #monsterData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    local myScore = myRankData.myScore and myRankData.myScore or 0
    this.SetNotRollingInfo(GetLanguageStrById(11721),myRankData.myRank)
    local dData = {
        rankInfo = {param1 = myRankData.myScore},
        force = myRankData.myScore
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not monsterData or (monsterData and #monsterData <= 0) then
        return
    end
    --local dt,db = RankingManager.CutDate(monsterData)
    this.SetHeadsInfo(monsterData[1],this.firstHeadinfoGo,1,monsterData[1].userName,monsterData[1].level)
    if #monsterData >= 2 then
        this.SetHeadsInfo(monsterData[2],this.secondHeadinfoGo,2,monsterData[2].userName,monsterData[2].level)
    end
    if #monsterData >= 3 then
        this.SetHeadsInfo(monsterData[3],this.thirdHeadinfoGo,3,monsterData[3].userName,monsterData[3].level)
    end

    this.scrollView:SetData(monsterData,function(index,root)
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

------------设置外敌排名信息
function this.SetAdventureInfo()
    local adventureData,myRankData=RankingManager.GetAdventureInfo()
    this.scrollParentView:SetActive(#adventureData ~= 0)
    this.noneImage:SetActive(#adventureData == 0)
    if #adventureData == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()
    this.SetNotRollingInfo(GetLanguageStrById(11722),myRankData.rank)
    local dData = {
        rankInfo = {param1 = myRankData.hurt},
        force = myRankData.hurt
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not adventureData or (adventureData and #adventureData <= 0) then
        return
    end
    --local dt,db=RankingManager.CutDate(adventureData)
    this.SetHeadsInfo(adventureData[1],this.firstHeadinfoGo,1,adventureData[1].name,adventureData[1].level)
    if #adventureData >= 2 then
        this.SetHeadsInfo(adventureData[2],this.secondHeadinfoGo,2,adventureData[2].name,adventureData[2].level)
    end
    if #adventureData >= 3 then
        this.SetHeadsInfo(adventureData[3],this.thirdHeadinfoGo,3,adventureData[3].name,adventureData[3].level)
    end
    this.scrollView:SetData(adventureData,function(index,root)
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
    this.scrollParentView:SetActive(#data ~= 0)
    this.noneImage:SetActive(#data == 0)
    if #data == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()

    this.SetNotRollingInfo(GetLanguageStrById(12666), myData.myRank)
    
    local dData = {
        rankInfo = {param1 = myData.fightId},
        force = myData.fightId
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    
    --数据拆分
    if not data or (data and #data <= 0) then
        return
    end
    -- local dt,db = RankingManager.CutDate(data)
    this.SetHeadsInfo(data[1],this.firstHeadinfoGo,1,data[1].userName,data[1].level)
    if #data >= 2 then
        this.SetHeadsInfo(data[2],this.secondHeadinfoGo,2,data[2].userName,data[2].level)
    end
    if #data >= 3 then
        this.SetHeadsInfo(data[3],this.thirdHeadinfoGo,3,data[3].userName,data[3].level)
    end

    this.scrollView:SetData(data,function(index,root)
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

------------设置公会排名信息
function this.SetGuildForceInfo()
    local data,myData = RankingManager.GetGuildForeInfo()
    this.scrollParentView:SetActive(#data ~= 0)
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
    this.SetNotRollingInfo(GetLanguageStrById(12668), myData.myRank)
    local dData = {
        rankInfo = {rank = myData.myRank ,param1= myData.myForce},
        guildName = PlayerManager.familyId == 0 and "" or MyGuildManager.GetMyGuildInfo().name
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not data or (data and #data <= 0) then
        return
    end
    --local dt,db=RankingManager.CutDate(data)
    this.SetHeadsInfo(data[1],this.firstHeadinfoGo,1,data[1].guildName,data[1].level)
    if #data >= 2 then
        this.SetHeadsInfo(data[2],this.secondHeadinfoGo,2,data[2].guildName,data[2].level)
    end
    if #data >= 3 then
        this.SetHeadsInfo(data[3],this.thirdHeadinfoGo,3,data[3].guildName,data[3].level)
    end

    this.scrollView:SetData(data,function(index,root)
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
    this.scrollParentView:SetActive(#data ~= 0)
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

    this.SetNotRollingInfo(GetLanguageStrById(22802), myData.myRank)
    local dData = {
        rankInfo = {rank = myData.myRank ,param1= myData.myNum},
        userName = PlayerManager.nickName
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not data or (data and #data <= 0) then
        return
    end
    --local dt,db=RankingManager.CutDate(data)
    this.SetHeadsInfo(data[1],this.firstHeadinfoGo,1,data[1].userName,data[1].level)
    if #data >= 2 then
        this.SetHeadsInfo(data[2],this.secondHeadinfoGo,2,data[2].userName,data[2].level)
    end
    if #data >= 3 then
        this.SetHeadsInfo(data[3],this.thirdHeadinfoGo,3,data[3].userName,data[3].level)
    end
    this.scrollView:SetData(data,function(index,root)
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

------------设置次元引擎公会信息
function this.SetGoldExperGuildSortInfo()
    local data,myData = RankingManager.GetGoldExperGuildSortInfo()
    this.scrollParentView:SetActive(#data ~= 0)
    this.noneImage:SetActive(#data==0)
    if #data == 0 then
        this.isRefreshNow = true
    end
    this.InitNotRollingInfo()

    -- local myRankText = ""
    -- if not myData.myRank or myData.myRank < 0 then
    --     myRankText = GetLanguageStrById(10041)
    -- else
    --     myRankText = myData.myRank
    -- end

    this.SetNotRollingInfo(GetLanguageStrById(22802), myData.myRank)
    local dData = {
        rankInfo = {rank = myData.myRank ,param1= myData.myNum},
        guildName =  PlayerManager.familyId == 0 and "" or MyGuildManager.GetMyGuildInfo().name
    }
    this.SetInfoShow(this.infoGo,dData,sData.rankType)
    --数据拆分
    if not data or (data and #data <= 0) then
        return
    end
    --local dt,db = RankingManager.CutDate(data)
    this.SetHeadsInfo(data[1],this.firstHeadinfoGo,1,data[1].userName,data[1].level)
    if #data >= 2 then
        this.SetHeadsInfo(data[2],this.secondHeadinfoGo,2,data[2].userName,data[2].level)
    end
    if #data >= 3 then
        this.SetHeadsInfo(data[3],this.thirdHeadinfoGo,3,data[3].userName,data[3].level)
    end
    this.scrollView:SetData(data,function(index,root)
        this.ShowGoldExperGuildSortInfo(root,data[index],myData)
    end)
    this.CheckIsTop()
end

--显示每条数据
function this.ShowGoldExperGuildSortInfo(root,data,myRankData)
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
    if index == 1 then
        if not this.playerHeadList[root] then
            this.playerHeadList[root]=CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,Util.GetGameObject(this.firsthead,"Head"))
        end
        this.firsthead:SetActive(true)
        this.playerHeadList[root]:Reset()
        this.playerHeadList[root]:SetHead(data.head)
        this.playerHeadList[root]:SetFrame(data.headFrame)
        this.playerHeadList[root]:SetLevel("LV." .. level)
        this.playerHeadList[root]:SetParent(Util.GetGameObject(this.firsthead,"Head"))
        this.playerHeadList[root]:SetPosition(Vector3(0,0,0))
        this.playerHeadList[root]:SetScale(Vector3.one*0.6)
        this.firstHeadName.text = name
        --this.SetInfoShow(this.firstHeadinfoGo,data,sData.rankType)
        Util.AddOnceClick(this.firstheadClick,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end)
    elseif index == 2 then   
        if not this.playerHeadList[root] then
            this.playerHeadList[root]=CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,Util.GetGameObject(this.secondhead,"Head"))
        end
        this.secondhead:SetActive(true)
        this.playerHeadList[root]:Reset()
        this.playerHeadList[root]:SetHead(data.head)
        this.playerHeadList[root]:SetFrame(data.headFrame)
        this.playerHeadList[root]:SetLevel("LV." .. level)
        this.playerHeadList[root]:SetParent(Util.GetGameObject(this.secondhead,"Head"))    
        this.playerHeadList[root]:SetPosition(Vector3(0,0,0))
        this.playerHeadList[root]:SetScale(Vector3.one*0.5)
        this.secondHeadName.text = name
        --this.SetInfoShow(this.secondHeadinfoGo,data,sData.rankType)
        Util.AddOnceClick(this.secondheadClick,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end)
    elseif index == 3 then
        if not this.playerHeadList[root] then
            this.playerHeadList[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD, Util.GetGameObject(this.thirdhead,"Head"))
        end
        this.thirdhead:SetActive(true)
        this.playerHeadList[root]:Reset()
        this.playerHeadList[root]:SetHead(data.head)
        this.playerHeadList[root]:SetFrame(data.headFrame)
        this.playerHeadList[root]:SetLevel("LV." .. level)
        this.playerHeadList[root]:SetParent(Util.GetGameObject(this.thirdhead,"Head"))
        this.playerHeadList[root]:SetPosition(Vector3(0,0,0))
        this.playerHeadList[root]:SetScale(Vector3.one*0.5)
        this.thirdHeadName.text = name
        --this.SetInfoShow(this.thirdHeadinfoGo,data,sData.rankType)
        Util.AddOnceClick(this.thirdheadClick,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end)
    end
end

--初始化非滚动区信息
function this.InitNotRollingInfo()    
    this.firsthead:SetActive(false)
    this.secondhead:SetActive(false)
    this.thirdhead:SetActive(false)
    this.firstHeadName.text = ""
    this.myRank.text = ""
    this.myRankName:GetComponent("Text").text = ""
end

--设置非滚动区信息
function this.SetNotRollingInfo(...)
    local args = {...}

    local topEndName = args[1]      -- 最后一列标题名
    local myRank = args[2]          -- 名次

    this.TextTopEnd.text = topEndName
    if not myRank or myRank < 1 then
        this.myRank.text = GetLanguageStrById(10041)
        this.MyRankHead:SetActive(false)
    else
        this.myRank.text = myRank
        if sData.rankType == RANK_TYPE.GUILD_FORCE_RANK then
            this.myRankName:GetComponent("Text").text = MyGuildManager.GetMyGuildInfo().name--PlayerManager.nickName
        else
            this.myRankName:GetComponent("Text").text = PlayerManager.nickName
        end
        
        this.MyRankHead:SetActive(true)
        this.SetHeadInfo(this.MyRankHead, PlayerManager.head, PlayerManager.frame, PlayerManager.level)
    end
end

--初始化滚动区信息
function this.InitRollingInfo(_root)
    local info0 = Util.GetGameObject(_root,"Value0"):GetComponent("Text")
    info0.text = ""
    return info0
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
    if myRank == rank then
        Util.GetGameObject(root,"SelfBG").gameObject:SetActive(true)
    else
        Util.GetGameObject(root,"SelfBG").gameObject:SetActive(false)
    end
end

--设置名次
function this.SetRankingNum(root,rank)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] = Util.GetGameObject(root,"SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if rank < 4 and rank > 0 then
        sortNumTabs[rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rank
    end
end

--设置头像
function this.SetHeadInfo(root,head,frame,level)
    local headObj = Util.GetGameObject(root,"Head")
    if not this.playerScrollHead[root] then
        this.playerScrollHead[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,headObj)
    end
    Util.GetGameObject(root,"Head"):SetActive(true) 
    -- Util.GetGameObject(root,"HeroHead"):SetActive(false)
    this.playerScrollHead[root]:Reset()
    this.playerScrollHead[root]:SetHead(head)
    this.playerScrollHead[root]:SetFrame(frame)
    this.playerScrollHead[root]:SetLevel("LV." .. level)
    this.playerScrollHead[root]:SetScale(Vector3.one*0.5)
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "Image")
    local lockImage=Util.GetGameObject(tab,"LockImage")
    local txt = Util.GetGameObject(tab, "Text")

    if status == "lock" then
        lockImage:SetActive(true)
        txt:GetComponent("Text").text = RankingManager.GetTabTextData()[index].txt
    else
        lockImage:SetActive(false)
        txt:GetComponent("Text").text = RankingManager.GetTabTextData()[index].txt
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

function this.SetInfoShow(go,data,rankType,name)
    local fight = Util.GetGameObject(go,"fight")
    local warPower = Util.GetGameObject(go,"warPower")
    local trial = Util.GetGameObject(go,"trial")
    local goldExper = Util.GetGameObject(go,"goldExper")
    local arenaScore = Util.GetGameObject(go,"arenaScore")
    local climbTower = Util.GetGameObject(go,"climbTower")
    local alameinStage = Util.GetGameObject(go,"alameinStage")

    fight:SetActive(false)
    warPower:SetActive(false)
    trial:SetActive(false)
    goldExper:SetActive(false)
    arenaScore:SetActive(false)
    climbTower:SetActive(false)
    alameinStage:SetActive(false)

    if rankType == RANK_TYPE.FIGHT_LEVEL_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            fight:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.userName
            end
            Util.GetGameObject(go,"fight"):GetComponent("Text").text = RankingManager.mainLevelConfig[data.rankInfo.param1].Name
        end
    elseif rankType == RANK_TYPE.FORCE_CURR_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            warPower:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.userName
            end
            Util.GetGameObject(go,"warPower/Text"):GetComponent("Text").text = data.rankInfo.param1--data.force
        end
    elseif rankType == RANK_TYPE.GUILD_FORCE_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            warPower:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.guildName
            end
            Util.GetGameObject(go,"warPower/Text"):GetComponent("Text").text = data.rankInfo.param1
        end
    elseif rankType == RANK_TYPE.MONSTER_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            trial:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.userName
            end
            Util.GetGameObject(go,"trial"):GetComponent("Text").text = GetLanguageStrById(11745).." "..data.rankInfo.param1
        end
    elseif rankType == RANK_TYPE.GOLD_EXPER then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            local txt = Util.GetGameObject(goldExper,"Text"):GetComponent("Text")
            goldExper:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.userName
            end
            goldExper:GetComponent("Text").text = ""
            txt.text = data.rankInfo.param1
            if this.activiteId and this.activiteId > 0 then
                if this.activiteId == ActivityTypeDef.GoldExper then
                    goldExper:GetComponent("Text").text = GetLanguageStrById(12381)
                    txt.text = data.rankInfo.param1

                elseif this.activiteId == ActivityTypeDef.RecruitExper then
                    goldExper:GetComponent("Text").text = GetLanguageStrById(50331)
                    txt.text = data.rankInfo.param1
                end
            end
            if data.rankInfo.rank >= 11 then
                return
            end
        end
    elseif rankType == RANK_TYPE.CELEBRATION_GUILD then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            goldExper:GetComponent("Text").text = GetLanguageStrById(22801)
            goldExper:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.guildName
            end
            Util.GetGameObject(goldExper, "Text"):GetComponent("Text").text = data.rankInfo.param1
        end
    elseif rankType == RANK_TYPE.ARENA_RANK then
        -- if data.personInfo.score and data.personInfo.score > 0 then
            arenaScore:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.userName
                Util.GetGameObject(go,"arenaScore"):GetComponent("Text").text = GetLanguageStrById(12241) ..  data.personInfo.score
            else
                Util.GetGameObject(go,"arenaScore"):GetComponent("Text").text = GetLanguageStrById(12241) ..  data.score
            end
        -- end
    elseif rankType == RANK_TYPE.CLIMB_TOWER then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            climbTower:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.userName
            end
            Util.GetGameObject(go, "climbTower"):GetComponent("Text").text = GetLanguageStrById(12669)
            Util.GetGameObject(go, "climbTower/Text"):GetComponent("Text").text =  data.rankInfo.param1
        end
    elseif rankType == RANK_TYPE.ALAMEIN_WAR then
        if data.rankInfo.param2 and data.rankInfo.param2 > 0 then
            alameinStage:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.userName
            end
            local config = G_AlameinLevel[tonumber(data.rankInfo.param2)]
            Util.GetGameObject(go, "alameinStage"):GetComponent("Text").text = string.format(GetLanguageStrById(22416), config.AlameinId) .. GetLanguageStrById(config.Name)                    
        end
    elseif rankType == RANK_TYPE.HERO_FORCE_RANK then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            warPower:SetActive(true)
            if name then
                name:GetComponent("Text").text = data.userName
            end
            Util.GetGameObject(go, "warPower/Text"):GetComponent("Text").text = data.rankInfo.param1  --战力显示
        end
    end
end

function this.HideList()
    if not this.itemList then return end
    for index, value in ipairs(this.itemList) do
        if value.activeSelf then
            value:SetActive(false)
        end
    end
end

-- 设置英雄排行数据
function this.SetHeroForceSortInfo()
    -- to do add yh
    local ranksData, myRankData = RankingManager.GetHeroForceInfo()
    this.scrollParentView:SetActive(#ranksData ~= 0)
    this.noneImage:SetActive(#ranksData == 0)
    if #ranksData == 0 then
        this.isRefreshNow = true
    end   

    this.InitNotRollingInfo()   
    local dData = {
        rankInfo={rank=myRankData.myrank,
            param1=myRankData.myforce
        },  
        heroDate={
            heroTemplateId = myRankData.myHeroTemplateId,
            heroLevel = myRankData.myheroLevel,
            heroStar = myRankData.myheroStar,
            userName = PlayerManager.nickName
        },
        force= myRankData.myforce , 
        userName = PlayerManager.nickName
    }
    
    this.SetInfoShow(this.infoGo, dData, sData.rankType, this.myRankName)        -- 设置名字 topend
    this.SetHeroNotRollingInfo(GetLanguageStrById(11729), myRankData.myrank,dData.heroDate,#ranksData)     --< 设置名次 上榜头像
    --数据拆分
    if not ranksData or (ranksData and #ranksData <= 0) then
        return
    end

    local list = {}
    for i = 1, #ranksData do
        if ranksData[i].rankInfo.rank ~= 0 then
            table.insert(list, ranksData[i])
        end
    end

    --此处字段数据修改
    if #ranksData >= 1 then
        this.SetHeadsHeroInfo(ranksData[1], this.firstHeadinfoGo,1, ranksData[1].userName, ranksData[1].heroLevel )
    end
    if #ranksData >= 2 then
        this.SetHeadsHeroInfo(ranksData[2], this.secondHeadinfoGo,2, ranksData[2].userName, ranksData[2].heroLevel )
    end
    if #ranksData >= 3 then
        this.SetHeadsHeroInfo(ranksData[3], this.thirdHeadinfoGo,3, ranksData[3].userName, ranksData[3].heroLevel)
    end
    this.scrollView:SetData(ranksData, function(index, root)
        -- LogError("scro star "..ranksData[index].heroStar.."heroLevel "..ranksData[index].heroLevel)
        this.SetOneHeroInfo(root, ranksData[index], dData,index)
    end)
    this.CheckIsTop()
end

--设置前三名背景头像
function this.SetHeadsHeroInfo(data,root,index,name,level)   
    if index == 1 then
        if not this.playerHeroListHead[root] then          
            this.playerHeroListHead[root]=SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.firsthead,"HeroHead").transform)
        end
        Util.GetGameObject(this.firsthead,"Head"):SetActive(false) 
        this.firsthead:SetActive(true)        
        this.playerHeroListHead[root]:OnOpen(false,{data.heroTemplateId,data.heroLevel,data.heroStar,nil,data.userName},0.6,false,false,false,false)
        this.playerHeroListHead[root].gameObject:GetComponent("RectTransform").anchoredPosition=Vector3.zero
        this.playerHeroListGo[index]=this.playerHeroListHead[root].gameObject
        Util.GetGameObject(this.playerHeroListGo[index],"item/num"):SetActive(false) 
        this.firstHeadName.text = name
        local star=Util.GetGameObject(this.playerHeroListGo[index],"item/starGrid").gameObject
        SetHeroStars(star, data.heroStar)
        Util.AddOnceClick(this.firstheadClick,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end)
    elseif index == 2 then   
        if not this.playerHeroListHead[root] then
            this.playerHeroListHead[root]=SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.secondhead,"HeroHead").transform)            
        end
        Util.GetGameObject(this.secondhead,"Head"):SetActive(false) 
        this.secondhead:SetActive(true)        
        this.playerHeroListHead[root]:OnOpen(false,{data.heroTemplateId,data.heroLevel,data.heroLevel,nil,data.userName},0.5,false,false,false,false)
        this.playerHeroListHead[root].gameObject:GetComponent("RectTransform").anchoredPosition=Vector3.zero
        this.playerHeroListGo[index]=this.playerHeroListHead[root].gameObject
        Util.GetGameObject(this.playerHeroListGo[index],"item/num"):SetActive(false) 
        this.secondHeadName.text = name
        local star=Util.GetGameObject(this.playerHeroListGo[index],"item/starGrid").gameObject
        SetHeroStars(star, data.heroStar)
        Util.AddOnceClick(this.secondheadClick,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end)
    elseif index == 3 then
        if not this.playerHeroListHead[root] then
            this.playerHeroListHead[root]=SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.thirdhead,"HeroHead").transform) 
        end
        Util.GetGameObject(this.thirdhead,"Head"):SetActive(false) 
        this.thirdhead:SetActive(true)        
        this.playerHeroListHead[root]:OnOpen(false,{data.heroTemplateId,data.heroLevel,data.heroStar,nil,data.userName},0.5,false,false,false,false)
        this.playerHeroListHead[root].gameObject:GetComponent("RectTransform").anchoredPosition=Vector3.New(0,-10,0)
        this.playerHeroListGo[index]=this.playerHeroListHead[root].gameObject
        Util.GetGameObject(this.playerHeroListGo[index],"item/num"):SetActive(false) 
        this.thirdHeadName.text = name
        local star=Util.GetGameObject(this.playerHeroListGo[index],"item/starGrid").gameObject
        SetHeroStars(star, data.heroStar)
        Util.AddOnceClick(this.thirdheadClick,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end)
    end
end

-- 显示每条数据
function this.SetOneHeroInfo(root, data, myRankData,myIndex)
    this.AddPlayerInfoClick(root, data.uid)
    --可能上榜多个自己的英雄
    -- 如果id 等同于自己则设置为 亮
    this.SetSelfBGByName(root, myRankData.userName, data.userName)
    this.SetRankingNum(root, data.rankInfo.rank)
    -- this.SetHeadInfo(root, data.heroTemplateId , data.headFrame, data.heroLevel )
    -- LogError("index adding ".. myIndex)
    this.SetHeadHeroInfo(root, data,myIndex)
    this.SetInfoShow(Util.GetGameObject(root, "infoGo"), data, sData.rankType, Util.GetGameObject(root, "Value0"))
end

local OffsetTop=3
-- 显示英雄数据
function this.SetHeadHeroInfo(root,data,myIndex)
    local headObj = Util.GetGameObject(root,"HeroHead")
    if not this.playerHeroListHead[root] then          
        this.playerHeroListHead[root]=SubUIManager.Open(SubUIConfig.ItemView,headObj.transform)
        local _lv =Util.GetGameObject(this.playerHeroListHead[root].gameObject,"item/frameMask")
        _lv:GetComponent("Image").sprite=Util.LoadSprite("cn2-X1_tongyong_daojukuang_dengji_01")
        local pre = newObjToParent(this.lvPre,_lv)
        pre:GetComponent("RectTransform").anchoredPosition= Vector2.New(-18,-16)
    end
    Util.GetGameObject(root,"Head"):SetActive(false) 
    Util.GetGameObject(root,"HeroHead"):SetActive(true)
    this.playerHeroListHead[root]:OnOpen(false,{data.heroTemplateId,data.heroLevel,data.heroStar,nil,data.userName},0.7,false,false,false,false)
    this.playerHeroListHead[root].gameObject:GetComponent("RectTransform").anchoredPosition=Vector3.zero
    this.playerHeroListGo[myIndex+OffsetTop]=this.playerHeroListHead[root].gameObject
    Util.GetGameObject(this.playerHeroListGo[myIndex+OffsetTop],"item/num"):SetActive(false) 
    local star=Util.GetGameObject(this.playerHeroListGo[myIndex+OffsetTop],"item/starGrid").gameObject
    SetHeroStars(star, data.heroStar)
    local _oplv = Util.GetGameObject(this.playerHeroListGo[myIndex+OffsetTop],"item/frameMask").gameObject
    local _setLv = Util.GetGameObject(_oplv,"lvtext(Clone)"):GetComponent("Text")
    if _setLv then
        _setLv.text = data.heroLevel
        _oplv:SetActive(true)    
    end
end

function this.SetHeroNotRollingInfo(...)
    local args = {...}

    local topEndName = args[1]                -- 最后一列标题名
    local myRank = args[2]                    -- 名次
    local data = args[3]                      -- 我的英雄数据
    local length = args[4]+OffsetTop+1        -- 未设缓存列表为当前最大长度
    this.TextTopEnd.text = topEndName
    if not myRank or myRank < 1 then
        this.myRank.text = GetLanguageStrById(10041)
        this.MyRankHeroHead:SetActive(false)
    else
        this.myRank.text = myRank
        this.myRankName:GetComponent("Text").text = PlayerManager.nickName
        this.MyRankHeroHead:SetActive(true)
        this.SetHeadHeroInfo(this.record,data,length) 
    end
end

function this.SetSelfBGByName(root,myName,rankName)
    if myName==rankName then
        Util.GetGameObject(root,"SelfBG").gameObject:SetActive(true)
    else
        Util.GetGameObject(root,"SelfBG").gameObject:SetActive(false)
    end
end

-- 设置英雄排行数据 end

return RankingSingleListPanel