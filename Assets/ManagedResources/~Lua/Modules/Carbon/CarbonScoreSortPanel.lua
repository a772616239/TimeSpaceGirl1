require("Base/BasePanel")
CarbonScoreSortPanel = Inherit(BasePanel)
local this=CarbonScoreSortPanel
local mapRankInfo={}
local listGo={}
local trialInfoList = {}
local pokemonGridGoList={}
local carbonId = 0
local callBack = nil
-- 名次对应的数字  m5
local rankNumRes = {
    [1] = "cn2-X1_tongyong_diyi",
    [2] = "cn2-X1_tongyong_dier",
    [3] = "cn2-X1_tongyong_disan",
    [4] = "cn2-X1_jingjichang_shujudiban_06", --空白图
}

-- 界面类型
local PANEL_TYPE = {
    TRIAL_RANK = 1,
    MONSTER_CAMP_RANK = 2,
}

-- 坐标位置的配置
local PosConfig = {

}



-- 头像对象管理
local _PlayerHeadList = {}


--初始化组件（用于子类重写）
function CarbonScoreSortPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.gameObject, "mask")
	self.BackBtn = Util.GetGameObject(self.gameObject, "BackBtn")
    this.carbonRank = Util.GetGameObject(self.gameObject, "Bg")
    this.trialRank = Util.GetGameObject(self.gameObject, "TrailRank")
    this.mapAreaPre=Util.GetGameObject(self.gameObject, "Bg/mapAreaPre")
    this.grid=Util.GetGameObject(self.gameObject, "Bg/scroll/materialGrid")
    this.passSort=Util.GetGameObject(self.gameObject, "Bg/endGo/passSort"):GetComponent("Text")
    this.passTime=Util.GetGameObject(self.gameObject, "Bg/endGo/passTime"):GetComponent("Text")
    -- this.btnBack = Util.GetGameObject(self.gameObject, "TrailRank/btnBack")
    for i = 1, 10 do
        listGo[i] = Util.GetGameObject(self.gameObject, "Bg/scroll/grid/mapAreaPre"..i)
    end

    -- ================== 试炼副本 ===========================
    -- 角色个人信息
    this.myRankImg = Util.GetGameObject(this.trialRank, "myRecord/infoDetail"):GetComponent("Image")
    this.myRank = Util.GetGameObject(this.trialRank, "myRecord/infoDetail/Text"):GetComponent("Text")
    this.myMaxLevel = Util.GetGameObject(this.trialRank, "myRecord/bottomInfo/myLevel"):GetComponent("Text")
    -- this.myFastestTime = Util.GetGameObject(this.trialRank, "myRecord/bottomInfo/myTime"):GetComponent("Text")
    this.myRankHead = Util.GetGameObject(this.trialRank, "myRecord/head")
    this.myName = Util.GetGameObject(this.trialRank, "myRecord/name"):GetComponent("Text")

    this.scrollRoot = Util.GetGameObject(this.trialRank, "scrollRoot")
    this.rankItem = Util.GetGameObject(this.trialRank, "rankItem")

    -- =====================================================
    --个人详情
    this.playerInfoShow=Util.GetGameObject(self.gameObject, "playerInfoShow")
    this.playerInfoShowMask=Util.GetGameObject(self.gameObject, "playerInfoShow/mask")
    this.headBox=Util.GetGameObject(self.gameObject, "playerInfoShow/headBox"):GetComponent("Image")
    this.playerInfoShowLv=Util.GetGameObject(self.gameObject, "playerInfoShow/headBox/lv/lv"):GetComponent("Text")
    this.playerInfoShowName=Util.GetGameObject(self.gameObject, "playerInfoShow/headBox/name"):GetComponent("Text")
    this.playerInfoShowPower=Util.GetGameObject(self.gameObject, "playerInfoShow/headBox/name (1)"):GetComponent("Text")
    this.pokemonGrid=Util.GetGameObject(self.gameObject, "playerInfoShow/pokemonScroll/grid")
    this.heroPre=Util.GetGameObject(self.gameObject, "playerInfoShow/heroPre")
    this.heroGrid=Util.GetGameObject(self.gameObject, "playerInfoShow/rect/grid")

    for i = 1, 10 do
        pokemonGridGoList[i] = Util.GetGameObject(self.gameObject, "playerInfoShow/pokemonScroll/grid/item ("..i..")")
    end

    -- 需要设置的组件
    -- 兽潮
    -- this.monsterTitleRoot = Util.GetGameObject(self.gameObject, "TrailRank/monsterTitleRoot")
    this.monsterRecord = Util.GetGameObject(self.gameObject, "TrailRank/monsterMyRecord")
    this.monsterRank = Util.GetGameObject(self.gameObject, "TrailRank/monsterMyRecord/myRank"):GetComponent("Text")
    this.monsterWave = Util.GetGameObject(self.gameObject, "TrailRank/monsterMyRecord/myWave"):GetComponent("Text")
    this.monsterScroll = Util.GetGameObject(self.gameObject, "TrailRank/monsterView")
    this.monsterItem = Util.GetGameObject(self.gameObject, "TrailRank/monsterItem")
    this.noneImage=Util.GetGameObject(self.gameObject,"TrailRank/NoneImage")

    -- 试炼副本
    this.trailRecord = Util.GetGameObject(self.gameObject, "TrailRank/myRecord")
    this.trailTitleRoot = Util.GetGameObject(self.gameObject, "TrailRank/infoRoot")

    -- this.title = Util.GetGameObject(self.gameObject, "TrailRank/title"):GetComponent("Text")

end

--绑定事件（用于子类重写）
function CarbonScoreSortPanel:BindEvent()

    Util.AddClick(self.playerInfoShowMask, function ()
        this.playerInfoShow:SetActive(false)
    end)

    Util.AddClick(self.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this.InitShowData()
        self:ClosePanel()
    end)
	    Util.AddClick(self.BackBtn, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this.InitShowData()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function CarbonScoreSortPanel:AddListener()

end

--移除事件监听（用于子类重写）
function CarbonScoreSortPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function CarbonScoreSortPanel:OnOpen(panelType, func)

    -- 生成循环滚动组件
    this.InitScrollView(panelType)
    this.InitShowData()
    this.SetItemShow(panelType)
    -- 根据界面类型显示数据
    if panelType == PANEL_TYPE.TRIAL_RANK then
        this.GetTrialRankInfo()
    elseif panelType == PANEL_TYPE.MONSTER_CAMP_RANK then
        this.GetMonsterFightRankInfo()
    end
    callBack = func
end

--- ---------    组件显示的初始化 --------------------------------------
function this.SetItemShow(panelType)
    local str = ""
    str = panelType == PANEL_TYPE.TRIAL_RANK and GetLanguageStrById(12247) or GetLanguageStrById(10314)
    --this.title.text = str

    -- this.monsterTitleRoot:SetActive(true)--两个排行用的一个titleroot

    this.trailRecord:SetActive(panelType == PANEL_TYPE.TRIAL_RANK)
    -- this.trailTitleRoot:SetActive(panelType == PANEL_TYPE.TRIAL_RANK)
    this.scrollRoot:SetActive(panelType == PANEL_TYPE.TRIAL_RANK)

    -- this.monsterTitleRoot:SetActive(panelType == PANEL_TYPE.MONSTER_CAMP_RANK)
    this.monsterRecord:SetActive(panelType == PANEL_TYPE.MONSTER_CAMP_RANK)
    this.monsterScroll:SetActive(panelType == PANEL_TYPE.MONSTER_CAMP_RANK)

end

function this.InitScrollView(panelType)
    local rootHight = 0
    local width = 0
    local scrollRoot
    local item
    if panelType == PANEL_TYPE.TRIAL_RANK then
        rootHight = this.scrollRoot.transform.rect.height
        width = this.scrollRoot.transform.rect.width
        scrollRoot = this.scrollRoot
        item = this.rankItem
    elseif panelType == PANEL_TYPE.MONSTER_CAMP_RANK then
        rootHight = this.monsterScroll.transform.rect.height
        width = this.monsterScroll.transform.rect.width
        scrollRoot = this.monsterScroll
        item = this.monsterItem
    end

    -- 设置位置

    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, scrollRoot.transform,
            item, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0,10))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    --this.ScrollView.gameObject:GetComponent("RectTransform").sizeDelta = Vector2.New(0, 0)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end



------------------ 兽潮来袭排行 --------------------------------------------
function this.GetMonsterFightRankInfo()
    NetManager.RequestRankInfo(RANK_TYPE.MONSTER_RANK, function (msg)

        this.SetPlayerInfo(msg)
        this.SetOtherPlayerInfo(msg)
    end)
end

-- 玩家自己的排行
function this.SetPlayerInfo(msg)
    local myWave = msg.myRankInfo.param1
    local myRank = msg.myRankInfo.rank

    if myRank == -1 then
        this.monsterRank.text = GetLanguageStrById(10041)
        this.monsterWave.text = GetLanguageStrById(10041)
    elseif myRank > 0 then
        this.monsterRank.text = tostring(myRank)
        this.monsterWave.text = myWave
    end
end
-- 其他玩家的排行
function this.SetOtherPlayerInfo(msg)
    if #msg.ranks == 0 or not msg.ranks then
        
        this.noneImage:SetActive(true) 
        return 
    end

    local rankFunc = function (index, item)
        this.RefreshMonsterRankInfo(item, msg.ranks[index], msg.myRankInfo.rank)
    end

    this.ScrollView:SetData(msg.ranks, rankFunc)

end

-- 滚动组件的初始化
function this.InitShowData()
    local rankFunc = function () end
    local initData = {}
    this.ScrollView:SetData(initData, rankFunc)
end

-- 刷新数据条
function this.RefreshMonsterRankInfo(item, data,myRank)
    -- 获取需要设置的组件
    local numImg = Util.GetGameObject(item, "Image/sortImage"):GetComponent("Image")
    local numText = Util.GetGameObject(numImg.gameObject, "Text"):GetComponent("Text")
    local head = Util.GetGameObject(item, "Image/head")
    local roleName = Util.GetGameObject(item, "Image/textRoot/name"):GetComponent("Text")
    local waveNum = Util.GetGameObject(item, "Image/textRoot/waveNum"):GetComponent("Text")

    --设置表现背景
    -- if myRank == data.rankInfo.rank then
    --     Util.GetGameObject(item,"selfBg").gameObject:SetActive(true)
    -- else
    --     Util.GetGameObject(item,"selfBg").gameObject:SetActive(false)
    -- end
    local roleRank = data.rankInfo.rank
    -- 设置排行文字
    local resPath = ""
    if roleRank <= 3 then
        resPath = rankNumRes[roleRank]
        numText.gameObject:SetActive(false)
    -- else
    --     resPath = rankNumRes[4]
    --     numText.gameObject:SetActive(true)
    end

    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetHead(data.head)
    _PlayerHeadList[item]:SetFrame(data.headFrame)
    _PlayerHeadList[item]:SetLevel("Lv." .. data.level)
    _PlayerHeadList[item]:SetScale(Vector3.one*0.7)

    numImg.sprite = Util.LoadSprite(resPath)
    numText.text = roleRank
    roleName.text = data.userName
    waveNum.text = GetLanguageStrById(10311) .. data.rankInfo.param1 .. GetLanguageStrById(10316)
end
-------------------  试炼排行----------------------------------------------
-- 初始化数据显示
function this.GetTrialRankInfo()
    NetManager.RequestRankInfo(RANK_TYPE.TRIAL_RANK, function (msg)
        this.SetPlayerRankInfo(msg)
        this.SetRoleRank(msg)
    end)
end

-- 设置玩家数据
function this.SetPlayerRankInfo(msg)

    local playerHead
    this.myName.text=PlayerManager.nickName
    playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.myRankHead.transform)
    playerHead:Reset()
    playerHead:SetScale(Vector3.one * 0.7)
    playerHead:SetHead(PlayerManager.head)
    playerHead:SetFrame(PlayerManager.frame)

    local rank = msg.myRankInfo.rank
    local maxLevel = msg.myRankInfo.param1
    -- local minTime = msg.myRankInfo.param2

    this.myRankImg.enabled = true
    if rank <= 3 and rank > 0 then
        this.myRankImg.sprite = Util.LoadSprite(rankNumRes[rank])
        this.myRank.text = rank
    elseif rank < 0 then
        this.myRank.text = GetLanguageStrById(10041)
        this.myRankImg.enabled = false
    else
        this.myRank.text = rank
        this.myRankImg.sprite = Util.LoadSprite(rankNumRes[4])
    end

    rank = rank <= 0 and GetLanguageStrById(10041) or rank
    maxLevel = maxLevel <= 0 and 0 or maxLevel
    -- if maxLevel <= 0 or  minTime <= 0 then
    --     minTime = GetLanguageStrById(10318)
    -- else
    --     minTime = SetTimeFormation(minTime)
    -- end

    this.myMaxLevel.text = maxLevel .. GetLanguageStrById(10319)

    -- if rank > 3 then
    --     this.myRankImg.enabled = false
    -- else
    --     this.myRankImg.enabled = true
    -- end

    -- this.myFastestTime.text = minTime
end

--  设置玩家排行
function this.SetRoleRank(msg)
    if #msg.ranks == 0 or not msg.ranks then
     
     return
     end

    local rankFunc = function (index, item)
        this.RefreshRankData(item, msg.ranks[index], msg.myRankInfo.rank)
    end


    --if  MapTrialManager.curPage <= 1 then
    --    -- 重置排行列表
        this.ScrollView:SetData(msg.ranks, rankFunc)
    --else
    --    -- 刷新排行列表
    --    this.ScrollView:RefreshData(msg.towerRanks, rankFunc)
    --end

end

-- 刷新排行的数据
function this.RefreshRankData(item, info,userRank)
    --设置表现背景
    -- if userRank==info.rankInfo.rank then
    --     Util.GetGameObject(item,"selfBg").gameObject:SetActive(true)
    -- else
    --     Util.GetGameObject(item,"selfBg").gameObject:SetActive(false)
    -- end
    -- 获取需要设置的组件
    local numImg = Util.GetGameObject(item, "Image/sortImage"):GetComponent("Image")
    local numText = Util.GetGameObject(numImg.gameObject, "Text"):GetComponent("Text")
    local head = Util.GetGameObject(item, "Image/head")
    local roleName = Util.GetGameObject(item, "Image/textRoot/name"):GetComponent("Text")
    -- local roleMinTime = Util.GetGameObject(item, "Image/textRoot/passTime"):GetComponent("Text")
    local roleMaxLevel = Util.GetGameObject(item, "Image/textRoot/maxLevel"):GetComponent("Text")
    local power = Util.GetGameObject(item, "Image/power/text"):GetComponent("Text")

    power.text = tostring(info.rankInfo.powerValue)
    local roleRank = info.rankInfo.rank
    -- 设置排行文字
    local resPath = ""
    if roleRank <= 3 then
        resPath = rankNumRes[roleRank]
        numText.gameObject:SetActive(false)
    else
        resPath = rankNumRes[4]
        numText.gameObject:SetActive(true)
    end

    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetHead(info.head)
    _PlayerHeadList[item]:SetFrame(info.headFrame)
    _PlayerHeadList[item]:SetLevel("Lv." .. info.level)
    _PlayerHeadList[item]:SetScale(Vector3.one*0.7)

    numImg.sprite = Util.LoadSprite(resPath)
    numText.text = roleRank
    roleName.text = info.userName
    -- roleMinTime.text = SetTimeFormation(info.rankInfo.param2)
    roleMaxLevel.text = info.rankInfo.param1
end












--- ---------------- 这是之前的副本排行----------------
function this.OnShowPanelData()

    -- 根据时间战力再排一次
    if #mapRankInfo > 1 then
        table.sort(mapRankInfo, function (a, b)
            if a.time == b.time then
                return a.forces > b.forces
            else
                return a.time < b.time
            end
        end)
    end

    for i = 1, 10 do
        if i<=#mapRankInfo then
           
            listGo[i]:SetActive(true)
            Util.GetGameObject(listGo[i], "headBox/lv/lv"):GetComponent("Text").text ="Lv." ..  mapRankInfo[i].level
            Util.GetGameObject(listGo[i], "headBox/name"):GetComponent("Text").text = mapRankInfo[i].name
            Util.GetGameObject(listGo[i], "time"):GetComponent("Text").text =GetTimeMaoHaoStrBySeconds(mapRankInfo[i].time)
            --Util.GetGameObject(listGo[i], "headBox"):GetComponent("Image").sprite = Util.LoadSprite(mapRankInfo[i].head)
            Util.AddOnceClick(Util.GetGameObject(listGo[i], "headBox"), function()
                this.playerInfoShow:SetActive(true)
                --this.headBox.sprite = Util.LoadSprite(mapRankInfo[i].head)
                this.playerInfoShowLv.text = "Lv." .. mapRankInfo[i].level
                this.playerInfoShowName.text = mapRankInfo[i].name
                this.playerInfoShowPower.text = GetLanguageStrById(10320)..mapRankInfo[i].forces
               
                for w = 1, 10 do
                    pokemonGridGoList[w]:SetActive(false)
                    for k =1 , #mapRankInfo[i].pokemonIds do
                        if mapRankInfo[i].pokemonIds[k]==w then
                            pokemonGridGoList[w]:SetActive(true)
                        end
                    end
                end
                Util.ClearChild(this.heroGrid.transform)
                for j = 1, #mapRankInfo[i].heroIds do
                    local heroConfigData = ConfigManager.GetConfigData(ConfigName.HeroConfig, mapRankInfo[i].heroIds[j])
                    local go = newObject(this.heroPre)
                    go.transform:SetParent(this.heroGrid.transform)
                    go.transform.localScale = Vector3.one
                    go.transform.localPosition = Vector3.zero
                    go:SetActive(true)
                    Util.GetGameObject(go,"frame"):GetComponent("Image").sprite=Util.LoadSprite(GetHeroQuantityImageByquality(heroConfigData.Quality))
                    --Util.GetGameObject(go, "lv/Text"):GetComponent("Text").text = mapRankInfo[i].heroIds[j].level
                    Util.GetGameObject(go,"icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(heroConfigData.Icon))
                    Util.GetGameObject(go, "pro/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfigData.ProfessionResourceId))
                end
            end)
        else

           
            listGo[i]:SetActive(false)
        end
    end
    this.passSort.text=GetLanguageStrById(10321)
    if CarbonManager.CarbonInfo[carbonId] then
        this.passTime.text=GetLanguageStrById(10322) .. SetTimeFormation(CarbonManager.CarbonInfo[carbonId].leastTime)
    else
        this.passTime.text=GetLanguageStrById(10323)
    end
    -- 在前10的排名 ，重新赋值一次
    --if #mapRankInfo > 1 then
    --    table.sort(mapRankInfo, function (a, b)return a<b end)
    --end


    for i = 1, #mapRankInfo do
        if mapRankInfo[i].uid==PlayerManager.uid then
            this.passSort.text=GetLanguageStrById(10104)..i
            this.passTime.text=GetLanguageStrById(10324).. GetTimeMaoHaoStrBySeconds(mapRankInfo[i].time)
            break
        end
    end
end
--界面关闭时调用（用于子类重写）
function CarbonScoreSortPanel:OnClose()
    if callBack then callBack() end
    this.noneImage:SetActive(false)
end

--界面销毁时调用（用于子类重写）
function CarbonScoreSortPanel:OnDestroy()
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}
    this.ScrollView = nil
end

return CarbonScoreSortPanel