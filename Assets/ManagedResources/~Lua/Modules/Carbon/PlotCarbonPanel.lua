require("Base/BasePanel")
PlotCarbonPanel = Inherit(BasePanel)
local this = PlotCarbonPanel
local challengeMapConfig = ConfigManager.GetConfig(ConfigName.ChallengeMapConfig)
local levelDifficultyData = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local ChallengeStarBox = ConfigManager.GetConfig(ConfigName.ChallengeStarBox)
local hasGetStarNumber = 0
local AttackList = {}
local jumpNeedBtn={}
local jumpIndexOne=0
local isJumpNewestId=false
-- 副本难度
local carbonType
local jumpCarbonId = 0
local _PanelType = {
    [1] = PanelType.Main,
    [2] = PanelType.Main,
    [3] = PanelType.EliteCarbon
}

local indexTable = {}
--初始化组件（用于子类重写）
function PlotCarbonPanel:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition

    -- 图片设置相关
    this.leftLight = Util.GetGameObject(self.gameObject, "imgRoot/left/Image"):GetComponent("Image")
    this.rightLight = Util.GetGameObject(self.gameObject, "imgRoot/right/Image"):GetComponent("Image")
    this.carbonName = Util.GetGameObject(self.gameObject, "imgRoot/Name"):GetComponent("Image")
    this.bgIcon = Util.GetGameObject(self.gameObject, "imgRoot/bgIcon"):GetComponent("Image")
    this.maskIcon = Util.GetGameObject(self.gameObject, "imgRoot/maskImage"):GetComponent("Image")
    -- 选项
    this.itemPre = Util.GetGameObject(self.gameObject, "ViewRect/item")
    this.itemGrid= Util.GetGameObject(self.gameObject, "ViewRect/item/rewardRect/grid")
    this.viewRect = Util.GetGameObject(self.gameObject, "ViewRect")
    -- 挑战次数
    this.leftTimeTip = Util.GetGameObject(self.gameObject, "imgRoot/tip")
    this.leftTime = Util.GetGameObject(self.gameObject, "imgRoot/leftTime"):GetComponent("Text")
    this.btnBuy = Util.GetGameObject(self.gameObject, "imgRoot/btnBuy")

    -- 显示货币
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    --奖励显示
    this.rewardDetail = Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail")
    this.starText = Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail/starText"):GetComponent("Text")
    this.itemContent = Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail/item")
    this.itemContent2 = Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail/item2")
    this.jumpBtn=Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail/jumpBtn")
    this.imgRoot = Util.GetGameObject(self.gameObject, "imgRoot")
    this.getRewardBtn = Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail/getRewardBtn")
    this.bottom = Util.GetGameObject(self.gameObject, "imgRoot/bottom")
    this.getRewardRedPoint = Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail/getRewardBtn/getRewardRedPoint")
    this.unLockMask = Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail/unLockMask")

    -- 设置循环滚动
    local v2 = this.viewRect:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.viewRect.transform,
            this.itemPre, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    this.ScrollViewRect = Util.GetGameObject(self.gameObject, "ViewRect/ScrollCycleView")
    this.ScrollViewGrid = Util.GetGameObject(self.gameObject, "ViewRect/ScrollCycleView/grid")
    this.viewCache = {}

    -- 奖励预览
    this.btnPreview = Util.GetGameObject(self.gameObject, "imgRoot/rewardDetail/btnPreview")
end

--显示使用的美术资源路径
-- 1 -> 困难 ； 2 -> 英雄； 3 -> 史诗； 4 -> 传说
local resPath = {
    [1] = { portrait = "lingjijuyuan", fire = "r_Dungeon_huo_01", name = "r_Dungeon_juqing", bgIcon = "r_Dungeon_rendi_01", maskIcon = "r_Dungeon_renzhao_01" },
}

--绑定事件（用于子类重写）
function PlotCarbonPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        ClearRedPointObject(RedPointType.EpicExplore_GetReward)
        -- !!!! PS: 这里必须是主动打开副本选择界面，从地图中返回时，这个界面的上一级是地图界面，
        --  如果只是关闭自己，则会打开地图界面，不会打开副本选择界面，导致报错
        PlayerManager.carbonType = 1
        UIManager.OpenPanel(UIName.CarbonTypePanelV)
        CallBackOnPanelOpen(UIName.CarbonTypePanelV2, function()
            UIManager.ClosePanel(UIName.PlotCarbonPanel)
        end)
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Plot,this.helpPosition.x,this.helpPosition.y)
    end)
    -- 购买次数按钮
    Util.AddClick(this.btnBuy, this.RequestBuyChanllengeCount)

    ---剧情副本相关事件监听------------------------------------------------------------------------------------

    --领取副本星级奖励
    Util.AddClick(this.getRewardBtn, function()
        if ((hasGetStarNumber - CarbonManager.hasGetRewardCostStar) >= 3) then
            CarbonManager.FbStarRewardRequest()
            CheckRedPointStatus(RedPointType.NormalExplore_GetStarReward)
        else
            PopupTipPanel.ShowTipByLanguageId(10377)
        end
    end)

    -- 奖励预览
    Util.AddClick(this.btnPreview, function ()
        UIManager.OpenPanel(UIName.PlotRewardPreviewPupop)
    end)
end


-- 请求购买挑战次数
function this.RequestBuyChanllengeCount()
    UIManager.OpenPanel(UIName.CarbonBuyCountPopup, 1)
end

--添加事件监听（用于子类重写）
function PlotCarbonPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Map.OnRefreshStarReward, this.RefreshRewardShow)
    Game.GlobalEvent:AddEvent(GameEvent.Carbon.RefreshCarbonData, this.OnTrialCopyData)
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshRedpot)
end

--移除事件监听（用于子类重写）
function PlotCarbonPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.OnRefreshStarReward, this.RefreshRewardShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Carbon.RefreshCarbonData, this.OnTrialCopyData)
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshRedpot)
end

--界面打开时调用（用于子类重写）
function PlotCarbonPanel:OnOpen(_jumpCarbonId)
    if _jumpCarbonId then
        jumpCarbonId = _jumpCarbonId
    else
        jumpCarbonId = 0
    end
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = _PanelType[CarbonManager.difficulty] })
end

function PlotCarbonPanel:OnShow()
    carbonType = 1
    --剧情副本
    this.imgRoot:SetActive(true)
    this.viewRect:SetActive(true)
    --设置页面头部显示
    this.InitImageShow()
    this.InitLeftTimesShow()
    local a = os.clock()
    this.PlotCarbonDataShow()
    local b = os.clock()
    local c = b - a



    --页面跳转，调节Item显示位置
    if jumpCarbonId~=0 then
        jumpCarbonId = CarbonManager.NeedLockId(jumpCarbonId,carbonType)
        this.SetGridPosY()
        isJumpNewestId=true
    end
end

-- 刷新挑战次数显示
function this.InitLeftTimesShow()
    local isNormal = CarbonManager.difficulty == 1
    this.leftTimeTip:SetActive(isNormal)
    this.leftTime.gameObject:SetActive(isNormal)
    if isNormal then
        local allTimes = PrivilegeManager.GetPrivilegeNumber(7)
        local leftTimes = BagManager.GetItemCountById(27)
        this.leftTime.text = string.format("%d/%d", leftTimes, allTimes)
    end     
end

-- 设置页面头部显示
function this.InitImageShow()
        this.leftLight.sprite = Util.LoadSprite((resPath[carbonType].fire))
        this.rightLight.sprite = Util.LoadSprite((resPath[carbonType].fire))
        this.carbonName.sprite = Util.LoadSprite((resPath[carbonType].name))
        this.bgIcon.sprite = Util.LoadSprite((resPath[carbonType].bgIcon))
end

--剧情副本页面数据显示
function this.PlotCarbonDataShow()

    -- 清空红点对象
    this.redpotList = {}
    --当前难度副本数量
    local mission = CarbonManager.GetCarBonMission()
    this.rewardDetail:SetActive(false)
    this.bottom:SetActive(false)
    --已获得星星数
    indexTable = {}
    hasGetStarNumber = 0
    for j=1,#mission do
        local carbonId=mission[j].Id
        indexTable[carbonId] = j
        if (CarbonManager.CarbonInfo[carbonId]) then
            for i = 1, #CarbonManager.CarbonInfo[carbonId].stars do
                local star = CarbonManager.CarbonInfo[carbonId].stars[i]
                if star ~= 0 then
                    hasGetStarNumber = hasGetStarNumber + 1
                end
            end
        end
    end
    this.ScrollView:SetData(mission, function(index, item1)
        local shows = mission[index].CoreItem
        if this.viewCache[item1] then
            for i = 1, #shows do
                if  this.viewCache[item1].views[i] then
                    this.viewCache[item1].views[i]:OnOpen(false, {shows[i], 0}, 0.75)
                end
            end
            this:ScrollPlotCarbonDataShow(item1, mission[index], this.viewCache[item1])
        else
            local viewCacheItem = {views = {}}
            for i = 1, #shows do
                local view = SubUIManager.Open(SubUIConfig.ItemView,Util.GetTransform(item1, "rewardRect/grid"))
                view:OnOpen(false, {shows[i], 0}, 0.75)
                viewCacheItem.views[i] = view
            end
            this.viewCache[item1] = viewCacheItem
            this:ScrollPlotCarbonDataInit(item1, mission[index], this.viewCache[item1],index)
            this:ScrollPlotCarbonDataShow(item1, mission[index], this.viewCache[item1])
        end
    end)
    --刷新普通副本星级奖励
    this:RefreshRewardShow()
end

function PlotCarbonPanel:ScrollPlotCarbonDataInit(item, itemData, viewCacheItem,index)
    --实例化任务数量(副本的公共方法)
    -- 序章无任务
    -- 当前副本ID
    -- 核心奖励
    local carbonId = itemData.Id
    item.name = "item" .. tostring(carbonId)
    -- 副本名称
    viewCacheItem.Name = Util.GetGameObject(item, "Image/Name"):GetComponent("Text")
    -- 详情按钮
    viewCacheItem.btnDetail = Util.GetGameObject(item, "btnRoot/detail")
    viewCacheItem.btnDetail:SetActive(true)

    -- 排名按钮
    viewCacheItem.btnFeats = Util.GetGameObject(item, "btnRoot/feats")

    --保存红点
    this.redpotList[itemData.MapId] = Util.GetGameObject(viewCacheItem.btnFeats, "redpot")

    -- 推荐战力
    viewCacheItem.adviceAtk = Util.GetGameObject(item, "atkNum"):GetComponent("Text")

    -- 最快通关时间
    viewCacheItem.fastestTime = Util.GetGameObject(item, "time"):GetComponent("Text")

    -- 开启条件
    viewCacheItem.lockMask = Util.GetGameObject(item, "Mask")
    viewCacheItem.lockInfo = Util.GetGameObject(item, "Mask/condition"):GetComponent("Text")

    viewCacheItem.normalRedPoint = Util.GetGameObject(item, "btnEnter/normalRedPoint")
    viewCacheItem.isCanShowRedPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "normal" .. itemData.MapId)
    -- 进入副本
    viewCacheItem.btnEnter = Util.GetGameObject(item, "btnEnter")
    if(index==1) then
        jumpIndexOne= viewCacheItem.btnEnter
    end

    -- 评星
    local starRoot = Util.GetGameObject(item, "starRoot")
    local starPre = Util.GetGameObject(item, "star")
    local grayStar = Util.GetGameObject(item, "greyStar")
    local star1 = Util.GetGameObject(item, "starRoot/greyStar"):GetComponent("Image")
    local star2 = Util.GetGameObject(item, "starRoot/greyStar2"):GetComponent("Image")
    local star3 = Util.GetGameObject(item, "starRoot/greyStar3"):GetComponent("Image")
    starRoot:SetActive(true)
    viewCacheItem.starList ={}
    viewCacheItem.starList[1]=star1
    viewCacheItem.starList[2]=star2
    viewCacheItem.starList[3]=star3
    for i=1,3 do
        viewCacheItem.starList[i].sprite=Util.LoadSprite("r_Dungeon_kongxinji")
    end
    starPre:SetActive(false)
    grayStar:SetActive(false)
end

--循环滚动剧情副本数据显示
function PlotCarbonPanel:ScrollPlotCarbonDataShow(item, itemData, viewCacheItem)
    local carbonId = itemData.Id

    viewCacheItem.Name.text = itemData.Name
    jumpNeedBtn[itemData.Id] = viewCacheItem.btnEnter
    Util.GetGameObject(viewCacheItem.btnDetail, "Text"):GetComponent("Text").text = indexTable[carbonId]

    if challengeMapConfig[carbonId] then
        local ifRank = challengeMapConfig[carbonId].IfRank
        local isShow = false
        if ifRank == 0 then
            isShow = false
        else
            isShow = true
        end
        --btnDRange:SetActive(isShow)
        viewCacheItem.btnFeats:SetActive(false)
    end

    AttackList[itemData.Id] = viewCacheItem.adviceAtk
    viewCacheItem.adviceAtk.text = itemData.RecommendFightAbility
    CarbonManager.recommendFightAbility[itemData.Id]=itemData.RecommendFightAbility
    if CarbonManager.CarbonInfo[carbonId] then
        local data = CarbonManager.CarbonInfo[carbonId]
        viewCacheItem.fastestTime.text = SetTimeFormation(data.leastTime)
    else
        viewCacheItem.fastestTime.text = "00:00"
    end

    local openRules = itemData.OpenRule
    if not openRules then

        return
    end

    local fightId = openRules[1][1]
    local levelNeed = openRules[1][2]
    local canEnter = false
    local tipText = ""
    if levelDifficultyData[fightId] then
        local fightName = levelDifficultyData[fightId].Name
        if fightName then
            -- 设置未开启文字
            tipText = GetLanguageStrById(10356) .. fightName .. GetLanguageStrById(10357)
        end
    end

    if levelNeed > 0 and fightId == 0 then
        tipText = string.format(GetLanguageStrById(10358), levelNeed)
    end

    viewCacheItem.lockInfo.text = tipText
    local state = true
    if fightId ~= 0 then
        state = FightPointPassManager.IsFightPointPass(fightId)
    end

    if state and PlayerManager.level >= levelNeed then
        canEnter = true
        --CheckRedPointStatus(RedPointType.NormalExplore_OpenMap)
        if (RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "normal" .. itemData.MapId) == "0") then
            viewCacheItem.normalRedPoint:SetActive(true)
        else
            viewCacheItem.normalRedPoint:SetActive(false)
        end
    else
        viewCacheItem.normalRedPoint:SetActive(false)
        canEnter = false
    end
    viewCacheItem.lockMask:SetActive(not canEnter)

    -- 进入副本
    viewCacheItem.btnEnter:SetActive(canEnter)
    Util.AddOnceClick(viewCacheItem.btnEnter, function()
        if canEnter then
            if BagManager.GetItemCountById(27) <= 0 and CarbonManager.GetNormalState(itemData.MapId)then
                PopupTipPanel.ShowTipByLanguageId(10379)
            else
                -- UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.CARBON, itemData.Id)
                UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CARBON, itemData.Id)
                MapManager.curMapId = itemData.Id
            end
            RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "normal" .. itemData.MapId, 1)
            CheckRedPointStatus(RedPointType.NormalExplore_OpenMap)
            CheckRedPointStatus(RedPointType.NormalExplore_GetStarReward)
            viewCacheItem.normalRedPoint:SetActive(false)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(10359) .. fightId .. GetLanguageStrById(10360) .. levelNeed)
        end
    end)

    if (CarbonManager.CarbonInfo[carbonId]) then
        for i = 1, #CarbonManager.CarbonInfo[carbonId].stars do
            local star = CarbonManager.CarbonInfo[carbonId].stars[i]
            if star ~= 0 then
                -- true
                viewCacheItem.starList[i].sprite=Util.LoadSprite("ui_1xing")
                --newObjToParent(starPre, starRoot)
                --hasGetStarNumber = hasGetStarNumber + 1
            else
                viewCacheItem.starList[i].sprite=Util.LoadSprite("r_Dungeon_kongxinji")
            end
        end
    else
        for i=1,3 do
            viewCacheItem.starList[i].sprite=Util.LoadSprite("r_Dungeon_kongxinji")
        end
    end
end



--刷新星级奖励
function PlotCarbonPanel:RefreshRewardShow()
    this.rewardDetail:SetActive(true)
    this.bottom:SetActive(true)
    local mapNums = GameDataBase.SheetBase.GetKeys(ChallengeStarBox)
    for k, v in ConfigPairs(ChallengeStarBox) do
        if (k < #mapNums) then
            if (CarbonManager.hasGetRewardCostStar < ChallengeStarBox[1].StarNum) then
                local itemdata = {}
                table.insert(itemdata, v.Reward[1][1])
                table.insert(itemdata, v.Reward[1][2])

                if not this.normalStarReward then 
                    local view = SubUIManager.Open(SubUIConfig.ItemView, this.itemContent.transform)
                    this.normalStarReward = view
                end
                this.normalStarReward:OnOpen(false, itemdata, 1)
                local itemdata2 = {}
                table.insert(itemdata2, v.ExtraReward[1][1])
                table.insert(itemdata2, v.ExtraReward[1][2])
                if not this.extralReward then 
                    local view2 = SubUIManager.Open(SubUIConfig.ItemView, this.itemContent2.transform)
                    this.extralReward = view2 
                end
                this.extralReward:OnOpen(false, itemdata2, 1)
                break
            end
            if (CarbonManager.hasGetRewardCostStar >= v.StarNum and CarbonManager.hasGetRewardCostStar < ChallengeStarBox[k + 1].StarNum) then
                --可领的奖励
                local itemdata = {}
                table.insert(itemdata, ChallengeStarBox[k + 1].Reward[1][1])
                table.insert(itemdata, ChallengeStarBox[k + 1].Reward[1][2])
                if not this.normalStarReward then 
                    local view = SubUIManager.Open(SubUIConfig.ItemView, this.itemContent.transform)
                    this.normalStarReward = view
                end
                this.normalStarReward:OnOpen(false, itemdata, 1)
                local itemdata2 = {} 
                table.insert(itemdata2, v.ExtraReward[1][1])
                table.insert(itemdata2, v.ExtraReward[1][2])
                if not this.extralReward then 
                    local view2 = SubUIManager.Open(SubUIConfig.ItemView, this.itemContent2.transform)
                    this.extralReward = view2
                end
                this.extralReward:OnOpen(false, itemdata2, 1)
            end
        else
            if (CarbonManager.hasGetRewardCostStar == v.StarNum) then
                --移除奖励
                this.rewardDetail:SetActive(false)
            end
        end
    end
    local starNumber = 0
    for k, v in ConfigPairs(ChallengeStarBox) do
        if (v.StarNum > CarbonManager.hasGetRewardCostStar) then
            starNumber = v.StarNum
            break
        end
    end

    local item = Util.GetGameObject(this.gameObject, "imgRoot/rewardDetail/item/ItemView/item")
    local item2 = Util.GetGameObject(this.gameObject, "imgRoot/rewardDetail/item2/ItemView/item")
    if (item ~= nil) then
        if ((hasGetStarNumber - CarbonManager.hasGetRewardCostStar) >= 3) then
            --this.getRewardBtn:SetActive(true)
            this.starText.text = string.format("<color=#ECB64C>%s</color>", hasGetStarNumber .. "/" .. (starNumber))
            this.getRewardBtn:GetComponent("Image").sprite = Util.LoadSprite("r_hero_button_001")
            this.getRewardRedPoint:SetActive(true)
            Util.SetGray(item, false)
            Util.SetGray(item2, false)
        else
            -- this.getRewardBtn:SetActive(false)
            this.starText.text = string.format("<color=#E25A57>%s</color>", hasGetStarNumber .. "/" .. (starNumber))
            this.getRewardBtn:GetComponent("Image").sprite = Util.LoadSprite("r_hero_button_003")
            this.getRewardRedPoint:SetActive(false)
            Util.SetGray(item, true)
            Util.SetGray(item2, true)
        end
    end
    if PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.EXTRA_STAR_REWARD) then
        this.unLockMask:SetActive(false)
        this.jumpBtn:SetActive(false)
    else
        this.unLockMask:SetActive(true)
        this.jumpBtn:SetActive(true)
        if(item2) then
            Util.SetGray(item2, true)
        end
    end
    Util.AddOnceClick(this.jumpBtn,function()
        JumpManager.GoJump(36004)
    end)
end

-- 刷新红点显示
function this.RefreshRedpot()
    for mapId, redpot in pairs(this.redpotList) do
        redpot:SetActive(CarbonManager.CheckEliteCarbonRedpot(mapId))
    end
end


--界面关闭时调用（用于子类重写）
function PlotCarbonPanel:OnClose()
   
end

--界面销毁时调用（用于子类重写）
function PlotCarbonPanel:OnDestroy()

    SubUIManager.Close(this.UpView)
    this.ScrollView = nil
    this.normalStarReward = nil
    this.extralReward = nil
end
function this.SetGridPosY()
    local num = jumpCarbonId % 100
    this.ScrollView:SetIndex(num)
end
--跳转显示新手提示圈
function this.ShowGuideGo(mapId)
    if(mapId and isJumpNewestId) then
        JumpManager.ShowGuide(UIName.PlotCarbonPanel,jumpNeedBtn[jumpCarbonId])
    end
    if(mapId==nil) then
        JumpManager.ShowGuide(UIName.PlotCarbonPanel,jumpIndexOne)
    end
end
return PlotCarbonPanel