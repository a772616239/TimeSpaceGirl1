local Expert = quick_class("Expert")
local this = Expert
local expertRewardGrid = {}--七种达人 + 周卡 限时兑换
local expertRewardItemsGrid = {}
local expertRewardTabs = {}
local activeIndext = 0

function Expert:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

local bannerList = {
    [13] = "cn2-X1_jingyinghuodong_banner_01",--慷慨解囊
    [10] = "cn2-X1_jingyinghuodong_banner_02",--快速作战
    [19] = "cn2-X1_jingyinghuodong_banner_03",--巡逻
    [20] = "cn2-X1_jingyinghuodong_banner_04",--轮盘
    [27] = "cn2-X1_jingyinghuodong_banner_05",--异端之战
    [21] = "cn2-X1_jingyinghuodong_banner_06",--精锐小队
    [7] = "cn2-X1_jingyinghuodong_banner_07",--每日累充
    -- [] = "cn2-X1_jingyinghuodong_banner_08",--累充  --(不在此活动集合 ContinuityRecharge)
    -- [] = "cn2-X1_jingyinghuodong_banner_09",--折扣
    -- [23] = "cn2-X1_jingyinghuodong_banner_10",--升级  --(不在此活动集合 UpLvRewardGrid)
}

--初始化组件（用于子类重写）
function Expert:InitComponent(gameObject)
    this.rewardBtn = Util.GetGameObject(gameObject, "rewardBtn")
    this.sortBtn = Util.GetGameObject(gameObject, "sortBtn")
    this.timeGo = Util.GetGameObject(gameObject, "time")
    this.time = Util.GetGameObject(gameObject, "time/Text"):GetComponent("Text")
    this.banner = Util.GetGameObject(gameObject, "banner"):GetComponent("Image")

    this.expertRewardGridGo =  Util.GetGameObject(gameObject, "rect/rect/grid")
    for i = 1, 10 do
        expertRewardGrid[i] = Util.GetGameObject(this.expertRewardGridGo, "rewardPre" .. i)
        local curexpertRewardItemsGri = {}
        for j = 1, 4 do
            curexpertRewardItemsGri[j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(expertRewardGrid[i], "content").transform)
            end
        expertRewardItemsGrid[i] = curexpertRewardItemsGri
    end

    this.content = Util.GetGameObject(gameObject, "rect"):GetComponent("RectTransform")
    this.firstReward = Util.GetGameObject(gameObject, "firstReward")
    this.grid = Util.GetGameObject(gameObject, "firstReward/gird")
end

--绑定事件（用于子类重写）
function Expert:BindEvent()
    Util.AddClick(this.rewardBtn, function()
        local activityId = ActivityGiftManager.IsActivityTypeOpen(NumExChange[activeIndext])
        UIManager.OpenPanel(UIName.ExpertRewardSortPanel,activityId,2, NumExChange[activeIndext])
    end)
    Util.AddClick(this.sortBtn, function()
        local t = NumExChange[activeIndext]
        local _name = NumExChangeRankName[activeIndext]
        local rank = {bgImage = "", name = _name ,Id = 42, rankType = RANK_TYPE.GOLD_EXPER, activiteId = t, isRankingMainPanelShow = false, nameImage = ""}
        UIManager.OpenPanel(UIName.RankingSingleListPanel,rank)
    end)
end

--添加事件监听（用于子类重写）
function Expert:AddListener()
end

--移除事件监听（用于子类重写）
function Expert:RemoveListener()
end

local sortingOrder = 0
--界面打开时调用（用于子类重写）
function Expert:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function Expert:OnShow(index,_sortingOrder)
    sortingOrder = _sortingOrder
    this:OnShowData(index)
end

function Expert:OnSortingOrderChange(cursortingOrder)
    for i, v in pairs(expertRewardItemsGrid) do
        for j = 1, #v do
            v[j]:SetEffectLayer(cursortingOrder)
        end
    end
end

function Expert:OnShowData(index)
    activeIndext = index

    self.rewardBtn:SetActive(false)
    self.sortBtn:SetActive(false)
    this.content.offsetMax = Vector2.New(0,-500)
    this.firstReward:SetActive(false)
    
    local globalActive = ConfigManager.GetConfigData(ConfigName.GlobalActivity, ActivityGiftManager.GetOpenExpertIdByActivityType(NumExChange[activeIndext]))
    if globalActive and globalActive.OpenRanking == 1 then
        this.rewardBtn:SetActive(true)
        this.sortBtn:SetActive(true)

        --排行第一可获得的奖励
        this.firstReward:SetActive(true)
        this.content.offsetMax = Vector2.New(0,-720)
        local rewardConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ActivityRankingReward, "ActivityId", ActivityGiftManager.GetOpenExpertIdByActivityType(NumExChange[activeIndext]), "MinRank", 1)
        Util.ClearChild(this.grid.transform)
        for i = 1, #rewardConfig.RankingReward do
            local go = SubUIManager.Open(SubUIConfig.ItemView, this.grid.transform)
            go:OnOpen(false, {rewardConfig.RankingReward[i][1], rewardConfig.RankingReward[i][2]}, 0.65)
        end
    end
    expertRewardTabs = ActivityGiftManager.GetActivityTypeInfo(NumExChange[activeIndext])
    this.banner.sprite = Util.LoadSprite(GetPictureFont(bannerList[activeIndext]))

    for i = 1, math.max(#expertRewardTabs.mission, #expertRewardGrid) do
        local go = expertRewardGrid[i]
        if not go then
            go = newObject(expertRewardGrid[1])
            go.transform:SetParent(this.expertRewardGridGo.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            expertRewardGrid[i] = go
        end
        go.gameObject:SetActive(false)
    end
    --时间倒计时
    if NumExChange[activeIndext] == ActivityTypeDef.AccumulativeRechargeExper then--今日累计充值特殊判断
        CardActivityManager.TimeDown(this.time, CalculateSecondsNowTo_N_OClock(24))
    else
        CardActivityManager.TimeDown(this.time, expertRewardTabs.endTime - GetTimeStamp())
    end
    this:WarPowerRewardTabsChangState()
    this:WarPowerRewardTabsSort(expertRewardTabs.mission)

    for i = 1, #expertRewardTabs.mission do
        this:ActivityRewardSingleShow(i, expertRewardTabs.mission[i])
    end
end

function Expert:WarPowerRewardTabsChangState()
    for i = 1, #expertRewardTabs.mission do
        local conFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig,expertRewardTabs.mission[i].missionId)
        local value = 0
        --限时累计活动特殊数值读取处理
        if NumExChange[activeIndext] == ActivityTypeDef.AccumulativeRechargeExper then
            value = conFigData.Values[1][1]
        else
            value = conFigData.Values[2][1]
        end
        if expertRewardTabs.mission[i].state == 0 then
            if NumExChange[activeIndext] == ActivityTypeDef.UpStarExper
                or NumExChange[activeIndext] == ActivityTypeDef.Talisman
                or NumExChange[activeIndext] == ActivityTypeDef.SoulPrint
                or NumExChange[activeIndext] == ActivityTypeDef.EquipExper
                or NumExChange[activeIndext] == ActivityTypeDef.FindTreasureExper
            then--进阶因为每个都不一样 特殊判断
                if expertRewardTabs.mission[i].progress < value then
                    expertRewardTabs.mission[i].state = 10
                else
                    expertRewardTabs.mission[i].state = 0
                end
            else
                --AccumulativeRechargeExper 后端*1000了  特殊处理，改为充值积分，需要除100
                local value_a = 0
                if NumExChange[activeIndext] == ActivityTypeDef.AccumulativeRechargeExper then
                    value_a = math.floor(expertRewardTabs.value / 100)
                else
                    value_a = expertRewardTabs.value
                end

                if value_a < value then
                    expertRewardTabs.mission[i].state = 10
                else
                    expertRewardTabs.mission[i].state = 0
                end
            end
        elseif expertRewardTabs.mission[i].state == 1 then
            expertRewardTabs.mission[i].state = 20
        end
    end
end

function Expert:WarPowerRewardTabsSort(missions)
    table.sort(missions,function(a,b)
        if a.state < b.state then
            return a.state < b.state
        elseif a.state == b.state then
            return a.missionId < b.missionId
        end
    end)
end

--活动奖励2
function Expert:ActivityRewardSingleShow(index, data)
    local item = expertRewardGrid[index]
    item:SetActive(true)
    local sConFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig, data.missionId)

    for i = 1, math.max(#sConFigData.Reward, #expertRewardItemsGrid[index]) do
        local go = expertRewardItemsGrid[index][i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "content").transform)
            expertRewardItemsGrid[index][i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #sConFigData.Reward do
        expertRewardItemsGrid[index][i].gameObject:SetActive(true)
        expertRewardItemsGrid[index][i]:OnOpen(false, sConFigData.Reward[i], 0.55, false, false, false, sortingOrder)
    end

    Util.GetGameObject(item, "title/Text"):GetComponent("Text").text = GetLanguageStrById(sConFigData.ContentsShow)
    local slider = Util.GetGameObject(item, "title/slider/Image"):GetComponent("Image")
    local progress = Util.GetGameObject(item, "progress")
    local btn = Util.GetGameObject(item, "btn")
    local redpoint = Util.GetGameObject(item, "btn/redPoint")
    local finished = Util.GetGameObject(item, "finished")

    btn:SetActive(data.state ~= 20)
    redpoint:SetActive(data.state == 0)
    progress:SetActive(data.state == 10)
    finished:SetActive(data.state == 20)

    if data.state == 0 then
        Util.GetGameObject(btn, "Text"):GetComponent("Text").text = UIBtnText.get
        btn:GetComponent("Image").color = UIColorNew.YELLOW
        Util.AddOnceClick(btn, function()
            NetManager.GetActivityRewardRequest(data.missionId, expertRewardTabs.activityId, function(drop)
                UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                    this:OnShowData(activeIndext)
                end)
            end)
        end)
    elseif data.state == 10 then
        Util.GetGameObject(btn, "Text"):GetComponent("Text").text = UIBtnText.go
        btn:GetComponent("Image").color = UIColorNew.ORANGE
        Util.AddOnceClick(btn, function()
            local id = sConFigData.Jump[1]
            if id == 27001 then
                if ShopManager.SetMainRechargeJump() then
                    id = 36006
                else
                    id = 36008
                end
            end
            JumpManager.GoJump(id)
        end)
    end

    --设置进度
    local value = 0
    --限时累计活动特殊数值读取处理
    if NumExChange[activeIndext] == ActivityTypeDef.AccumulativeRechargeExper then
        value = sConFigData.Values[1][1]
    else
        value = sConFigData.Values[2][1]
    end

    if NumExChange[activeIndext] == ActivityTypeDef.UpStarExper
        or NumExChange[activeIndext] == ActivityTypeDef.Talisman
        or NumExChange[activeIndext] == ActivityTypeDef.SoulPrint
        or NumExChange[activeIndext] == ActivityTypeDef.EquipExper
        or NumExChange[activeIndext] == ActivityTypeDef.FindTreasureExper
    then
        progress:GetComponent("Text").text = data.progress .. "/" .. value
        slider.fillAmount = data.progress/value
    else
        local _progress = 0
        if NumExChange[activeIndext] == ActivityTypeDef.AccumulativeRechargeExper then
            _progress = math.floor(expertRewardTabs.value / 100)
        else
            _progress = expertRewardTabs.value
        end
        progress:GetComponent("Text").text = _progress .. "/" .. value
        slider.fillAmount = _progress/value
    end
end

--界面关闭时调用（用于子类重写）
function Expert:OnClose()
    CardActivityManager.StopTimeDown()
end

--界面销毁时调用（用于子类重写）
function Expert:OnDestroy()
    sortingOrder = 0
end

return Expert