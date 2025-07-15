require("Base/BasePanel")
EliteCarbonPanel = Inherit(BasePanel)
local this = EliteCarbonPanel
local challengeConfig = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
local challengeMapConfig = ConfigManager.GetConfig(ConfigName.ChallengeMapConfig)
local levelDifficultyData = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local chooseDegreeId = 1
local degreeDetailText = 0
local itemList = {}
local missionList = {}
local missionListAll = {}
local heroCopyType = 3
local AttackList = {}
local sortIndex = 0
local missionListItem = {}
local difficultyDetail = { GetLanguageStrById(10351), GetLanguageStrById(10352), GetLanguageStrById(10353), GetLanguageStrById(10354) }
local jumpNeedBtn = {}
local jumpIndexOne = 0
local isJumpNewestId = false
-- 副本难度
local carbonType
local jumpCarbonId = 0
local _PanelType = {
    [1] = PanelType.Main,
    [2] = PanelType.Main,
    [3] = PanelType.EliteCarbon
}
--初始化组件（用于子类重写）
function EliteCarbonPanel:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition

    -- 图片设置相关
    this.leftLight = Util.GetGameObject(self.gameObject, "imgRoot/left/Image"):GetComponent("Image")
    this.rightLight = Util.GetGameObject(self.gameObject, "imgRoot/right/Image"):GetComponent("Image")
    this.carbonName = Util.GetGameObject(self.gameObject, "imgRoot/Name"):GetComponent("Image")
    this.bgIcon = Util.GetGameObject(self.gameObject, "imgRoot/bgIcon"):GetComponent("Image")
    this.maskIcon = Util.GetGameObject(self.gameObject, "imgRoot/maskImage"):GetComponent("Image")
    -- 选项
    this.itemPre = Util.GetGameObject(self.gameObject, "ViewRect/item")
    this.grid = Util.GetGameObject(self.gameObject, "ViewRect/grid")
    this.itemGrid = Util.GetGameObject(self.gameObject, "ViewRect/item/rewardRect/grid")
    this.viewRect = Util.GetGameObject(self.gameObject, "ViewRect")
    -- 挑战次数
    this.leftTimeTip = Util.GetGameObject(self.gameObject, "imgRoot/tip")
    this.leftTime = Util.GetGameObject(self.gameObject, "imgRoot/leftTime"):GetComponent("Text")
    this.btnBuy = Util.GetGameObject(self.gameObject, "imgRoot/btnBuy")

    -- 显示货币
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    --奖励显示
    this.degreeChoose = Util.GetGameObject(self.gameObject, "degreeChoose")
    this.btn1 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btn1")
    this.btn2 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btn2")
    this.btn3 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btn3")
    this.btn4 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btn4")
    this.chooseImage1 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btn1/chooseImage")
    this.chooseImage2 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btn2/chooseImage")
    this.chooseImage3 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btn3/chooseImage")
    this.chooseImage4 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btn4/chooseImage")
    this.closeBtn = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/btnBack")
    this.sureBtn = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/sureBtn")
    this.imgRoot = Util.GetGameObject(self.gameObject, "imgRoot")
    this.maskImage2 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/maskImage2")
    this.maskImage3 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/maskImage3")
    this.maskImage4 = Util.GetGameObject(self.gameObject, "degreeChoose/degreeChoosePanel/maskImage4")
    --奖励红点
    this.levelRewardPoint = Util.GetGameObject(this.btnGetReward, "redPoint")
    -- 设置循环滚动
    local v2 = this.viewRect:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.viewRect.transform,
            this.itemPre, nil, Vector2.New(-v2.x * 2, -v2.y * 2), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    this.ScrollViewRect = Util.GetGameObject(self.gameObject, "ViewRect/ScrollCycleView")
    this.ScrollViewGrid = Util.GetGameObject(self.gameObject, "ViewRect/ScrollCycleView/grid")
    this.viewCache = {}
end

--显示使用的美术资源路径
-- 1 -> 困难 ； 2 -> 英雄； 3 -> 史诗； 4 -> 传说
local resPath = {
    [3] = { portrait = "shixueguimo", fire = "r_Dungeon_huo_02", name = "r_Dungeon_jingying", bgIcon = "r_Dungeon_rendi_03", maskIcon = "r_Dungeon_renzhao_03" },
}

--绑定事件（用于子类重写）
function EliteCarbonPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        ClearRedPointObject(RedPointType.EpicExplore_GetReward)
        -- !!!! PS: 这里必须是主动打开副本选择界面，从地图中返回时，这个界面的上一级是地图界面，
        --  如果只是关闭自己，则会打开地图界面，不会打开副本选择界面，导致报错
        UIManager.OpenPanel(UIName.CarbonTypePanel)
        CallBackOnPanelOpen(UIName.CarbonTypePanel, function()
            UIManager.ClosePanel(UIName.EliteCarbonPanel)
        end)
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.Elite, this.helpPosition.x, this.helpPosition.y)
    end)
    -- 购买次数按钮
    Util.AddClick(this.btnBuy, this.RequestBuyChanllengeCount)
    ---英雄副本相关事件监听------------------------------------------------------------------------------------
    Util.AddClick(this.sureBtn, function()
        Util.GetGameObject(itemList[chooseDegreeId], "btnEnter/degreeBtn/degreeText"):GetComponent("Text").text = degreeDetailText
        Util.GetGameObject(itemList[chooseDegreeId], "btnEnter/degreeBtn/degreeImage"):GetComponent("Image").sprite = Util.LoadSprite(this.GetImageResource(degreeDetailText))
        CarbonManager.degreeDetailListText[chooseDegreeId] = degreeDetailText
        local index = this:GetMapId(missionListAll[sortIndex][1].Id)
        AttackList[chooseDegreeId].text = challengeConfig[missionListAll[sortIndex][index].Id].RecommendFightAbility
        --local coreGrid = Util.GetGameObject(itemList[chooseDegreeId], "rewardRect/grid")
        this.RefreshBoxReward(index)
        this.degreeChoose:SetActive(false)
        NetManager.DifficultMapRequest(missionListAll[sortIndex][index].MapId, index)
        CarbonManager.HeroCopyStateSetStr(PlayerManager.uid .. chooseDegreeId, degreeDetailText)
    end)

    Util.AddClick(this.closeBtn, function()
        this.degreeChoose:SetActive(false)
    end)
    Util.AddClick(this.btn1, function()
        degreeDetailText = GetLanguageStrById(10351)
        this.ChooseImage(degreeDetailText, 1)

    end)
    Util.AddClick(this.btn2, function()
        degreeDetailText = GetLanguageStrById(10352)
        this.ChooseImage(degreeDetailText, 1)
    end)
    Util.AddClick(this.btn3, function()
        degreeDetailText = GetLanguageStrById(10353)
        this.ChooseImage(degreeDetailText, 1)
    end)
    Util.AddClick(this.btn4, function()
        degreeDetailText = GetLanguageStrById(10354)
        this.ChooseImage(degreeDetailText, 1)
    end)

end

--根据难度读取图片名称
function this.GetImageResource(degreeDetailText)
    if (degreeDetailText == GetLanguageStrById(10351)) then
        return "r_Dungeon_jiandan"
    elseif (degreeDetailText == GetLanguageStrById(10352)) then
        return "r_Dungeon_putong"
    elseif (degreeDetailText == GetLanguageStrById(10353)) then
        return "r_Dungeon_kunnan"
    elseif (degreeDetailText == GetLanguageStrById(10354)) then
        return "r_Dungeon_lianyu"
    end
end

--根据选择的难度不同刷新奖励物品显示
function this.RefreshBoxReward(index, i, Id, isRefresh)
    if (isRefresh == true) then
        sortIndex = i
        chooseDegreeId = Id
    end
    local shows = missionListAll[sortIndex][index].CoreItem
    --ClearChild(coreGrid)
    local viewNums = this.viewCache[itemList[chooseDegreeId]].views
    if (#viewNums > #shows) then
        for i = 1, #viewNums - #shows do
            this.viewCache[itemList[chooseDegreeId]].views[i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            this.viewCache[itemList[chooseDegreeId]].views[i + #viewNums - #shows]:OnOpen(false, { shows[i], 0 }, 0.75)
        end
    end
    if (#viewNums < #shows) then
        for i = 1, #shows - #viewNums do
            this.viewCache[itemList[chooseDegreeId]].views[#viewNums + i]:Open(false, { shows[i], 0 }, 0.75)
        end
        for i = 1, #shows do
            this.viewCache[itemList[chooseDegreeId]].views[i].gameObject:SetActive(true)
            this.viewCache[itemList[chooseDegreeId]].views[i]:OnOpen(false, { shows[i], 0 }, 0.75)
        end
    end
    if (#viewNums == #shows) then
        for i = 1, #shows do
            this.viewCache[itemList[chooseDegreeId]].views[i].gameObject:SetActive(true)
            this.viewCache[itemList[chooseDegreeId]].views[i]:OnOpen(false, { shows[i], 0 }, 0.75)
        end
    end
end

--跳转刷新选择难度
--chooseDegreeId为当前的地图Id（不是MapId）
function this.JumpChooseRefresh(chooseDegreeId)
    local degreeDetailText=this:GetDifficultyText(chooseDegreeId).difficultyName
    local sortIndex=this:GetDifficultyText(chooseDegreeId).difficultyType
    local idFinal=tonumber(math.floor(chooseDegreeId/10).."1")
    Util.GetGameObject(itemList[idFinal], "btnEnter/degreeBtn/degreeText"):GetComponent("Text").text = degreeDetailText
    Util.GetGameObject(itemList[idFinal], "btnEnter/degreeBtn/degreeImage"):GetComponent("Image").sprite = Util.LoadSprite(this.GetImageResource(degreeDetailText))
    CarbonManager.degreeDetailListText[idFinal] = degreeDetailText
    local index = this:GetMapId(missionListAll[sortIndex][1].Id)
    AttackList[idFinal].text = challengeConfig[missionListAll[sortIndex][index].Id].RecommendFightAbility
    --local coreGrid = Util.GetGameObject(itemList[chooseDegreeId], "rewardRect/grid")
    this.RefreshBoxReward(index)
    this.degreeChoose:SetActive(false)
    NetManager.DifficultMapRequest(missionListAll[sortIndex][index].MapId, index)
    CarbonManager.HeroCopyStateSetStr(PlayerManager.uid .. idFinal, degreeDetailText)
end








--勾选控制
function this.ChooseImage(chooseDegreeText, type)
    local degreeText = 0
    --type=1代表点击难度选择按钮时，难度文本显示的数据
    --type=2代表不点击按钮打开页面时，难度文本的数据
    if (type == 1) then
        degreeText = chooseDegreeText
    else
        degreeText = Util.GetGameObject(itemList[chooseDegreeId], "btnEnter/degreeBtn/degreeText"):GetComponent("Text").text
    end
    this.chooseImage1:SetActive(degreeText == GetLanguageStrById(10351))
    this.chooseImage2:SetActive(degreeText == GetLanguageStrById(10352))
    this.chooseImage3:SetActive(degreeText == GetLanguageStrById(10353))
    this.chooseImage4:SetActive(degreeText == GetLanguageStrById(10354))
    if (degreeText == GetLanguageStrById(10351)) then
        degreeDetailText = GetLanguageStrById(10351)
    elseif (degreeText == GetLanguageStrById(10352)) then
        degreeDetailText = GetLanguageStrById(10352)
    elseif (degreeText == GetLanguageStrById(10353)) then
        degreeDetailText = GetLanguageStrById(10353)
    elseif (degreeText == GetLanguageStrById(10354)) then
        degreeDetailText = GetLanguageStrById(10354)
    end
end

-- 请求购买挑战次数
function this.RequestBuyChanllengeCount()
    UIManager.OpenPanel(UIName.CarbonBuyCountPopup, 1)
end

--添加事件监听（用于子类重写）
function EliteCarbonPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Map.OnRefreshStarReward, this.RefreshRewardShow)
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshRedpot)
end

--移除事件监听（用于子类重写）
function EliteCarbonPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.OnRefreshStarReward, this.RefreshRewardShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshRedpot)
end

--界面打开时调用（用于子类重写）
function EliteCarbonPanel:OnOpen(_jumpCarbonId)
    if _jumpCarbonId then
        jumpCarbonId = _jumpCarbonId
    else
        jumpCarbonId = 0
    end
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = _PanelType[CarbonManager.difficulty] })
    sortIndex = 0
end

function EliteCarbonPanel:OnShow()
    carbonType = 3
    sortIndex = 0
    this.grid:SetActive(true)
    this.imgRoot:SetActive(true)
    this.viewRect:SetActive(true)
    this.ScrollViewRect:SetActive(true)
    --设置页面头部显示
    this.InitImageShow()
    this.EliteCarbonDataShow()
    this.RefreshRedpot()
    this.viewRect:GetComponent("RectTransform").sizeDelta = Vector2.New(1079.9, 1431)
    this.viewRect:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, -195.3)
    --页面跳转，调节Item显示位置
    if jumpCarbonId ~= 0 then
        --jumpCarbonId = CarbonManager.NeedLockId(jumpCarbonId, carbonType)
        this.SetGridPosY()
        isJumpNewestId = true
    end
end


-- 设置页面头部显示
function this.InitImageShow()
    this.leftLight.sprite = Util.LoadSprite((resPath[carbonType].fire))
    this.rightLight.sprite = Util.LoadSprite((resPath[carbonType].fire))
    this.carbonName.sprite = Util.LoadSprite((resPath[carbonType].name))
    this.bgIcon.sprite = Util.LoadSprite((resPath[carbonType].bgIcon))
end

--精英副本数据显示
function this.EliteCarbonDataShow()
    --ClearChild(this.grid)
    -- 清空红点对象
    this.redpotList = {}
    --当前难度副本数量
    local mission = CarbonManager.GetCarBonMission()
    if #mission > 1 then
        table.sort(mission, function(a, b)
            if b then
                return a.Id < b.Id
            end
        end)
    end
    --已获得星星数
    --hasGetStarNumber = 0
    this:OnHeroData(mission)
    mission = missionList

    this.ScrollView:SetData(mission, function(index, item1)

        local shows = mission[index].CoreItem
        if this.viewCache[item1] then
            for i = 1, #shows do
                this.viewCache[item1].views[i]:OnOpen(false, { shows[i], 0 }, 0.75)
            end
            this:ScrollEliteCarbonDataShow(item1, mission[index], index, this.viewCache[item1])
        else
            local viewCacheItem = { views = {} }
            for i = 1, #shows do
                local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(item1, "rewardRect/grid"))
                view:OnOpen(false, { shows[i], 0 }, 0.75)
                viewCacheItem.views[i] = view
            end
            this.viewCache[item1] = viewCacheItem
            this:ScrollEliteCarbonDataShow(item1, mission[index], index, this.viewCache[item1])
        end
    end)

    --this.viewRect:GetComponent("RectTransform").sizeDelta = Vector2.New(1079.9, 1431)
    --this.viewRect:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, -195.3)
    --实例化任务数量(副本的公共方法)

    --英雄副本显示
    this:OnHeroCopyData(mission)
end

--英雄本循环滚动数据显示
function EliteCarbonPanel:ScrollEliteCarbonDataShow(item, itemData, index, viewCacheItem)
    -- 当前副本ID
    local carbonId = itemData.Id
    --local item = newObjToParent(this.itemPre, this.grid)
    item.name = "item" .. tostring(carbonId)
    -- 副本名称
    viewCacheItem.Name = Util.GetGameObject(item, "Image/Name"):GetComponent("Text")
    viewCacheItem.Name.text = itemData.Name
    Util.GetGameObject(item, "Image").gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(-277, 30.19)
    Util.GetGameObject(item, "atkNum").gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(-41, -61.3)
    -- 排名按钮
    --local btnDRange = Util.GetGameObject(item, "btnRoot/range")
    viewCacheItem.btnFeats = Util.GetGameObject(item, "btnRoot/feats")

    if challengeMapConfig[carbonId] then
        local ifRank = challengeMapConfig[carbonId].IfRank
        local isShow = false

        if ifRank == 0 then
            isShow = false
        else
            isShow = true
        end
        --btnDRange:SetActive(false)
        viewCacheItem.btnFeats:SetActive(true)
    end

    --Util.AddOnceClick(btnDRange, function()
    
    --    NetManager.MapGetRankInfoRequest(carbonId, function(_mapRankInfo)
    --        UIManager.OpenPanel(UIName.CarbonScoreSortPanel, _mapRankInfo, carbonId)
    --    end)
    --end)

    -- 功绩按钮
    Util.AddOnceClick(viewCacheItem.btnFeats, function()
        UIManager.OpenPanel(UIName.EliteCarbonAchievePanel, itemData.MapId, true, 1)
    end)
    -- 保存红点
    this.redpotList[itemData.MapId] = Util.GetGameObject(viewCacheItem.btnFeats, "redpot")

    -- 推荐战力
    viewCacheItem.adviceAtk = Util.GetGameObject(item, "atkNum"):GetComponent("Text")
    AttackList[itemData.Id] = viewCacheItem.adviceAtk
    viewCacheItem.adviceAtk.text = itemData.RecommendFightAbility
    -- 最快通关时间
    viewCacheItem.fastestTime = Util.GetGameObject(item, "time"):GetComponent("Text")
    if CarbonManager.CarbonInfo[carbonId] then
        local data = CarbonManager.CarbonInfo[carbonId]
        viewCacheItem.fastestTime.text = SetTimeFormation(data.leastTime)
    else
        viewCacheItem.fastestTime.text = "00:00"
    end

    -- 开启条件
    viewCacheItem.lockMask = Util.GetGameObject(item, "Mask")
    viewCacheItem.lockInfo = Util.GetGameObject(item, "Mask/condition"):GetComponent("Text")

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
        Util.GetGameObject(item, "btnEnter/normalRedPoint"):SetActive(false)
    else
        Util.GetGameObject(item, "btnEnter/degreeBtn/difficultyRedPoint"):SetActive(false)
        Util.GetGameObject(item, "btnEnter/normalRedPoint"):SetActive(false)
        canEnter = false
    end
    viewCacheItem.lockMask:SetActive(not canEnter)
    -- 进入副本
    viewCacheItem.btnEnter = Util.GetGameObject(item, "btnEnter")
    viewCacheItem.btnEnter:SetActive(canEnter)
   
    jumpNeedBtn[itemData.Id] = viewCacheItem.btnEnter
    if (index == 1) then
        jumpIndexOne = viewCacheItem.btnEnter
    end
    Util.AddOnceClick(viewCacheItem.btnEnter, function()
        if canEnter then
            local index1 = this:GetMapId(itemData.Id)
            CarbonManager.recommendFightAbility[missionListAll[index][index1].Id] = itemData.RecommendFightAbility
            UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.CARBON, missionListAll[index][index1].Id)
            MapManager.curMapId = missionListAll[index][index1].Id
            RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "hero" .. missionListAll[index][index1].Id, 1)
            CheckRedPointStatus(RedPointType.HeroExplore)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(10359) .. fightId .. GetLanguageStrById(10360) .. levelNeed)
        end
    end)
    -- 评星
    viewCacheItem.degreeBtn = Util.GetGameObject(item, "btnEnter/degreeBtn")
    itemList[itemData.Id] = item
    viewCacheItem.degreeBtn:SetActive(true)
    Util.AddOnceClick(viewCacheItem.degreeBtn, function()
        this.degreeChoose:SetActive(true)
        chooseDegreeId = itemData.Id
        sortIndex = index
        this.ChooseImage(0, 2, index)
        if CarbonManager.difficultyMask[itemData.MapId] == -1 then
            this.maskImage2:SetActive(true)
            this.maskImage3:SetActive(true)
            this.maskImage4:SetActive(true)
            this.btn1:SetActive(true)
            this.btn2:SetActive(false)
            this.btn3:SetActive(false)
            this.btn4:SetActive(false)
        elseif CarbonManager.difficultyMask[itemData.MapId] == 1 then
            this.maskImage2:SetActive(false)
            this.maskImage3:SetActive(true)
            this.maskImage4:SetActive(true)
            this.btn1:SetActive(true)
            this.btn2:SetActive(true)
            this.btn3:SetActive(false)
            this.btn4:SetActive(false)
        elseif CarbonManager.difficultyMask[itemData.MapId] == 2 then
            this.maskImage2:SetActive(false)
            this.maskImage3:SetActive(false)
            this.maskImage4:SetActive(true)
            this.btn1:SetActive(true)
            this.btn2:SetActive(true)
            this.btn3:SetActive(true)
            this.btn4:SetActive(false)
        elseif CarbonManager.difficultyMask[itemData.MapId] == 3 then
            this.maskImage2:SetActive(false)
            this.maskImage3:SetActive(false)
            this.maskImage4:SetActive(false)
            this.btn1:SetActive(true)
            this.btn2:SetActive(true)
            this.btn3:SetActive(true)
            this.btn4:SetActive(true)
        elseif CarbonManager.difficultyMask[itemData.MapId] == 4 then
            this.maskImage2:SetActive(false)
            this.maskImage3:SetActive(false)
            this.maskImage4:SetActive(false)
            this.btn1:SetActive(true)
            this.btn2:SetActive(true)
            this.btn3:SetActive(true)
            this.btn4:SetActive(true)
        end
    end)
    -- 核心奖励
    --local coreGrid = Util.GetGameObject(item, "rewardRect/grid")
    --local shows =mission[i].CoreItem
    --ClearChild(coreGrid)
    --for i = 1, #shows do
    --    local item = {}
    --    item[#item + 1] = shows[i]
    --    item[#item + 1] = 0
    --    local view = SubUIManager.Open(SubUIConfig.ItemView, coreGrid.transform)
    --    view:OnOpen(false, item, 0.75)
    --end
    local mission1 = CarbonManager.GetCarBonMission()
    for j = 1, #mission1 do
        local mapId = mission1[j].Id
        local isCanShowRedPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "hero" .. mapId)
        if (itemData.Id == mapId) then
            Util.GetGameObject(item, "btnEnter/degreeBtn/difficultyRedPoint"):SetActive(false)
        end
        if (isCanShowRedPoint == "0" and CarbonManager.CheckMapIdUnLock(mapId) and itemData.MapId == mission1[j].MapId) then
            Util.GetGameObject(item, "btnEnter/degreeBtn/difficultyRedPoint"):SetActive(true)
        end
    end
end



--英雄本
function EliteCarbonPanel:OnHeroData(mission)
    missionList = {}
    missionListItem = {}
    local index = 0
    missionListAll = {}
    local isCanInsert = true
    for i = 1, #mission do
        local carbonId = mission[i].Id
        isCanInsert = true
        if (challengeConfig[carbonId].Type == heroCopyType) then
            if (table.nums(missionList) < 1) then
                missionList[i] = mission[i]
            end
            for j, v in pairs(missionList) do
                if (v.MapId == mission[i].MapId) then
                    isCanInsert = false
                end
            end
            if (isCanInsert == true) then
                table.insert(missionList, mission[i])
            end
            index = index + 1
            table.insert(missionListItem, mission[i])
            if (index == 4) then
                index = 0
                table.insert(missionListAll, missionListItem)
                missionListItem = {}
            end
        end
    end
end

--英雄本
function EliteCarbonPanel:OnHeroCopyData(mission)
    if (table.nums(CarbonManager.degreeDetailListText) < 1) then
        for i = 1, #mission do
            --if (CarbonManager.CheckCarbonUnLock(mission[i].Id) == true) then
            for j, m in ipairs(CarbonManager.difficultyId) do
                if (mission[i].MapId == m.Id) then
                    CarbonManager.degreeDetailListText[mission[i].Id] = difficultyDetail[m.mapdifficulty]
                end
            end
            -- end
            if (CarbonManager.degreeDetailListText[mission[i].Id] == nil) then
                CarbonManager.degreeDetailListText[mission[i].Id] = GetLanguageStrById(10351)
            end
        end
    end
    for i, v in pairs(CarbonManager.degreeDetailListText) do
        Util.GetGameObject(itemList[i], "btnEnter/degreeBtn/degreeText"):GetComponent("Text").text = v
        Util.GetGameObject(itemList[i], "btnEnter/degreeBtn/degreeImage"):GetComponent("Image").sprite = Util.LoadSprite(this.GetImageResource(v))
    end
    for i = 1, #mission do
        local index = this:GetMapId(missionListAll[i][1].Id)
        AttackList[mission[i].Id].text = challengeConfig[missionListAll[i][index].Id].RecommendFightAbility
        CarbonManager.recommendFightAbility[mission[i].Id] = challengeConfig[missionListAll[i][index].Id].RecommendFightAbility
        --local coreGrid = Util.GetGameObject(itemList[mission[i].Id], "rewardRect/grid")
        --ClearChild(coreGrid)
        local shows = missionListAll[i][index].CoreItem
        this.RefreshBoxReward(index, i, mission[i].Id, true)
    end
end

-- 刷新红点显示
function this.RefreshRedpot()
    for mapId, redpot in pairs(this.redpotList) do
        redpot:SetActive(CarbonManager.CheckEliteCarbonRedpot(mapId))
    end
end


--界面关闭时调用（用于子类重写）
function EliteCarbonPanel:OnClose()

    jumpNeedBtn = {}
end

--界面销毁时调用（用于子类重写）
function EliteCarbonPanel:OnDestroy()

    SubUIManager.Close(this.UpView)
    this.ScrollView = nil
end

function EliteCarbonPanel:GetMapId(MapId)
    local index = 0
    if Util.GetGameObject(itemList[MapId], "degreeBtn/degreeText"):GetComponent("Text").text == nil then
        index = 1
    elseif (Util.GetGameObject(itemList[MapId], "degreeBtn/degreeText"):GetComponent("Text").text == GetLanguageStrById(10351)) then
        index = 1
    elseif (Util.GetGameObject(itemList[MapId], "degreeBtn/degreeText"):GetComponent("Text").text == GetLanguageStrById(10352)) then
        index = 2
    elseif (Util.GetGameObject(itemList[MapId], "degreeBtn/degreeText"):GetComponent("Text").text == GetLanguageStrById(10353)) then
        index = 3
    elseif (Util.GetGameObject(itemList[MapId], "degreeBtn/degreeText"):GetComponent("Text").text == GetLanguageStrById(10354)) then
        index = 4
    end
    return index
end

--根据Id获得选择的难度文字
function EliteCarbonPanel:GetDifficultyText(MapId)
    local mission = CarbonManager.GetCarBonMission()
    local difficultyName=0
    local difficultyNum=0
    for i,v in ipairs(mission) do
        if (v.Id == MapId) then
            if (v.DifficultType == 1) then
                difficultyName=GetLanguageStrById(10351)
            elseif (v.DifficultType == 2) then
                difficultyName=GetLanguageStrById(10352)
            elseif (v.DifficultType == 3) then
                difficultyName=GetLanguageStrById(10353)
            elseif (v.DifficultType == 4) then
                difficultyName=GetLanguageStrById(10354)
            end
        end
    end
    for i, v in ipairs(missionList) do
        if (math.floor(v.Id/10) == math.floor(MapId/10)) then
            difficultyNum=i
        end
    end
    return {difficultyName=difficultyName,difficultyType=difficultyNum}
end

function this.SetGridPosY()
    local num = jumpCarbonId % 100
    this.ScrollView:SetIndex(num)
end

--跳转显示新手提示圈
function this.ShowGuideGo(mapId)
   
    if (mapId and isJumpNewestId) then
        local idFinal=tonumber(math.floor(mapId/10).."1")
        JumpManager.ShowGuide(UIName.EliteCarbonPanel, jumpNeedBtn[idFinal])
    end
    if (mapId == nil) then
        JumpManager.ShowGuide(UIName.EliteCarbonPanel, jumpIndexOne)
    end
end

return EliteCarbonPanel