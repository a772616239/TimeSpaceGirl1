local this = {}
local sortingOrder = 0
local battlePassReward = ConfigManager.GetConfig(ConfigName.BattlePassReward)
local battlePassConfig = ConfigManager.GetConfig(ConfigName.BattlePassConfig)
local TabBox = require("Modules/Common/TabBox")
local typeIndex = {
    [0] = 1,
    [1] = 0,
    [2] = 2,
}
local type = {
    [0] = {color = Color.New(255/255,174/255,53/255,1),text = string.format("<color=#53360A>%s</color>",GetLanguageStrById(10023))},
    [1] = {color = Color.New(255/255,209/255,43/255,1),text = string.format("<color=#544307>%s</color>",GetLanguageStrById(10022))},
    [2] = {color = Color.New(255/255,209/255,43/255,1),text = string.format("<color=#FFFFFFFF>%s</color>",GetLanguageStrById(10350))},
}
local _TabData = {
    [1] = { default = "cn2-X1_shouzha_yeqian_01", select = "cn2-X1_shouzha_yeqianxuanzhong_01"},
    [2] = { default = "cn2-X1_shouzha_yeqian_02", select = "cn2-X1_shouzha_yeqianxuanzhong_02"},
    [3] = { default = "cn2-X1_shouzha_yeqian_03", select = "cn2-X1_shouzha_yeqianxuanzhong_03"},
    [4] = { default = "cn2-X1_shouzha_yeqian_04", select = "cn2-X1_shouzha_yeqianxuanzhong_04"},
    [5] = { default = "cn2-X1_shouzha_yeqian_05", select = "cn2-X1_shouzha_yeqianxuanzhong_05"},
    [6] = { default = "cn2-X1_shouzha_yeqian_06", select = "cn2-X1_shouzha_yeqianxuanzhong_06"},
    [7] = { default = "cn2-X1_shouzha_yeqian_07", select = "cn2-X1_shouzha_yeqianxuanzhong_07"},
    [8] = { default = "cn2-X1_shouzha_yeqian_08", select = "cn2-X1_shouzha_yeqianxuanzhong_08"},
    [9] = { default = "cn2-X1_shouzha_yeqian_09", select = "cn2-X1_shouzha_yeqianxuanzhong_09"},
    [10] = { default = "cn2-X1_shouzha_yeqian_10", select = "cn2-X1_shouzha_yeqianxuanzhong_10"},
    [11] = { default = "cn2-X1_shouzha_yeqian_11", select = "cn2-X1_shouzha_yeqianxuanzhong_11"},
    [12] = { default = "cn2-X1_shouzha_yeqian_12", select = "cn2-X1_shouzha_yeqianxuanzhong_12"},
    [13] = { default = "cn2-X1_shouzha_yeqian_13", select = "cn2-X1_shouzha_yeqianxuanzhong_13"},
}
this.pross = 0
local tabIndex = 1

function this:InitComponent(gameObject)
    this.panel = Util.GetGameObject(gameObject, "BattlePassPanel_Mission")
    this.backBtn = Util.GetGameObject(this.panel, "btnBg/BackBtn")
    this.bgScrol = Util.GetGameObject(this.panel, "bg/bgScrol")

    this.goals = Util.GetGameObject(this.panel, "bg/goals")

    --购买
    this.buyBattlePass = Util.GetGameObject(this.goals, "BuyBattlePass")
    --当前完成任务
    this.goalTxt = Util.GetGameObject(this.goals, "GoalTxt"):GetComponent("Text")
    this.targetReward = Util.GetGameObject(this.panel, "Passpre")

    --目标奖励
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.bgScrol.transform,
        this.targetReward, nil, Vector2.New(this.bgScrol.transform.rect.width, this.bgScrol.transform.rect.height), 2, 1, Vector2.New(5, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    --任务
    this.itemPre = Util.GetGameObject(this.panel, "itempre")
    this.tastScrol = Util.GetGameObject(this.panel, "Poor/Panel/scroll")
    local w = this.tastScrol.transform.rect.width
    local h = this.tastScrol.transform.rect.height

    -- this.scrollViewList = {}
    -- for i = 1, battlePassConfig[1].TaskTabCount, 1 do
    --     this.scrollViewList[i] = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.tastScrol.transform,
    --     this.itemPre, nil, Vector2.New(w, h), 1, 1, Vector2.New(0, 10))
    -- end

    this.scrollViewList = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.tastScrol.transform,
        this.itemPre, nil, Vector2.New(w, h), 1, 1, Vector2.New(0, 10))

    this.tabBox = Util.GetGameObject(this.panel, "Poor/Panel/TabBox")
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData)

    --奖励预览
    this.rewardPreview = Util.GetGameObject(this.panel, "bg/rewardPreview")
    this.reward1 = Util.GetGameObject(this.rewardPreview, "reward1")
    this.reward2 = Util.GetGameObject(this.rewardPreview, "reward2")
    this.rewardGoal = Util.GetGameObject(this.rewardPreview, "Text"):GetComponent("Text")

    --解锁
    this.unlock = Util.GetGameObject(this.panel, "Poor/Unlock")
    this.unlockBtn = Util.GetGameObject(this.unlock, "Button")
    this.taskPanel = Util.GetGameObject(this.panel, "Poor/Panel")
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, this.tabBoxData, curIndex)

    this.btnTaskAllReceive = Util.GetGameObject(this.panel, "btnBg/taskAllReceive")
end

function this:BindEvent()
    Util.AddOnceClick(this.backBtn, function()
        this.battlePanel.SwitchView(1)
    end)
    Util.AddOnceClick(this.unlockBtn, function() 
        this.battlePanel.Opendetail()
    end)
    Util.AddOnceClick(this.btnTaskAllReceive, function()
        NetManager.TakeLetterMissionRewardAllRequest(function(respond)    
            UIManager.OpenPanel(UIName.RewardItemPopup,respond.drop,1,function()
                for i = 1, #respond.missionIds do
                    TaskManager.SetTypeTaskState(TaskTypeDef.BattlePass,respond.missionIds[i],2)
                end

                this.RefreshAllTaskBtn()
                this.RefreshTaskAllReceiveState()
                this.RefreshPassData()

                CheckRedPointStatus(RedPointType.BattlePassMission)
            end)
        end)
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshPassData)
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshAllTaskBtn)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged,this.RefreshPassData)
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged,this.RefreshAllTaskBtn)
end

function this.TabAdapter(tab, index, status)
    local title = Util.GetGameObject(tab, "title"):GetComponent("Image")
    title.sprite = Util.LoadSprite(GetPictureFont(_TabData[index][status]))
    local select = Util.GetGameObject(tab, "select")
    select:SetActive(status == "Select")
end

function this.SwitchView(index)
    tabIndex = index
    if this.scrollData then
        this.scrollViewList:SetData(this.scrollData[index],function (_index,go)
            this.SetScrollData(go,this.scrollData[index][_index])
        end)
    end

end
function this:OnSortingOrderChange(_sortingOrder)
    -- this.rewardPreview:GetComponent("Canvas").sortingOrder = sortingOrder + 30
    this.goals:GetComponent("Canvas").sortingOrder = sortingOrder + 30
end

function this:OnShow(panel,_sortingOrder)
    sortingOrder = _sortingOrder
    this.battlePanel = panel
    this.RefreshPassData()

    -- tabIndex = 1
    this.RefreshAllTaskBtn()
    this.TabCtrl:ChangeTab(tabIndex)

    this:OnSortingOrderChange(sortingOrder)

    this.RefreshTaskAllReceiveState()
end

--刷新进度表
function this.RefreshPassData()
    this.passReward = {}
    local passData
    NetManager.BattlePassRequest(function(msg)
        if PrivilegeManager.GetPrivilegeOpenStatusById(92001) then
            this.buyBattlePass:SetActive(false)
            this.unlock:SetActive(false)
            this.taskPanel:GetComponent("RectTransform").offsetMax = Vector2.New(0,0)
        else
            this.buyBattlePass:SetActive(true)
            this.unlock:SetActive(true)
            this.taskPanel:GetComponent("RectTransform").offsetMax = Vector2.New(0,-145)
        end
        local v2 = Vector2.New(this.tastScrol.transform.rect.width,this.tastScrol.transform.rect.height)

        this.scrollViewList.gameObject:GetComponent("RectTransform").sizeDelta = v2

        passData = msg
        this.pross = msg.pross
        this.goalTxt.text = msg.pross
        for index, value in ConfigPairs(battlePassReward) do
            local data = {}
            data[1] = value
            if passData then
                for pindx, pvalue in ipairs(passData.info) do
                    if pvalue.missionId == value.Id then
                        data[2] = pvalue
                    end
                end
            end
            this.passReward[value.Id] = data
        end
        this.ScrollView:SetData(this.passReward,function (index,go)
            this.PassScroll(go,this.passReward[index],index)
        end)
        if passData and passData.info then
            this.ScrollView:SetIndex(#passData.info)
        end
    end)
end

--刷新整体任务表
function this.RefreshAllTaskBtn()
    this.taskData = TaskManager.GetTypeTaskList(TaskTypeDef.BattlePass)

    this.scrollData = {}
    local redPointList = {}
    for i = 1, Util.GetGameObject(this.tabBox,"box").transform.childCount do
        redPointList[i] = Util.GetGameObject(Util.GetGameObject(this.tabBox,"box").transform:GetChild(i-1).gameObject,"Redpot")
        redPointList[i]:SetActive(false)
    end
    for index, value in ipairs(this.taskData) do
        if not this.scrollData[ConfigManager.GetConfigData(ConfigName.BattlePassTask, value.missionId).Tab] then
            this.scrollData[ConfigManager.GetConfigData(ConfigName.BattlePassTask, value.missionId).Tab] = {}
        end
        table.insert(this.scrollData[ConfigManager.GetConfigData(ConfigName.BattlePassTask, value.missionId).Tab],value)
        if value.state == 1 then
            redPointList[ConfigManager.GetConfigData(ConfigName.BattlePassTask, value.missionId).Tab]:SetActive(true)
        end
    end
    for i = 1, #this.scrollData, 1 do
        this.scrollData[i] = this.SortData(this.scrollData[i])
    end

    this.RefreshTaskAllReceiveState()
    this.SwitchView(tabIndex)
end

--刷新任务列表数据
function this.SetScrollData(pre,data)
    if pre == nil or data == nil then
        return
    end
    this.SetActive(pre,true)
    local value = ConfigManager.GetConfigData(ConfigName.BattlePassTask, data.missionId)
    local activityRewardGo = pre
    local sConFigData = value
    --任务标题
    local titleText = Util.GetGameObject(activityRewardGo, "title"):GetComponent("Text")
    titleText.text = GetLanguageStrById(value.Desc)
    --进度
    local missionText = Util.GetGameObject(activityRewardGo, "mission"):GetComponent("Text")
    missionText.text = data.progress.."/"..value.Values[2][1]
    --奖励
    local reward = Util.GetGameObject(activityRewardGo, "reward")
    --进度条
    local slider = Util.GetGameObject(activityRewardGo, "Slider")
    slider:GetComponent("Slider").value = data.progress/value.Values[2][1]

    if not itemGrid then
        itemGrid = {}
    end
    if not itemGrid[pre] then
        itemGrid[pre] = SubUIManager.Open(SubUIConfig.ItemView,reward.transform)
    end
    itemGrid[pre]:OnOpen(false, sConFigData.Reward[1], 0.55, false)

    --领取或者前往
    local receiveOrGo = Util.GetGameObject(activityRewardGo, "receiveOrGo")
    --0-未完成，1-完成未领取  2-已领取
    local state = data.state
    --红点
    this.SetActive(Util.GetGameObject(receiveOrGo.gameObject, "redPoint"),state == 1)
    this.SetActive(slider,value.ShowProgress == 1)
    this.SetActive(missionText.gameObject,value.ShowProgress == 1)
    --领取或者前往按钮
    local receiveOrGoBtn = Util.GetGameObject(receiveOrGo, "Button")
    Util.GetGameObject(receiveOrGoBtn, "Text"):GetComponent("Text").text = type[state].text
    receiveOrGoBtn:GetComponent("Image").color = type[state].color

    this.SetActive(Util.GetGameObject(receiveOrGo, "Button").gameObject,state ~= 2)
    this.SetActive(Util.GetGameObject(receiveOrGo, "received").gameObject,state == 2)

    Util.AddOnceClick(receiveOrGoBtn, function()
        if state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.BattlePass,sConFigData.Id, function(respond)    
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1,function ()
                    this.RefreshAllTaskBtn()
                    CheckRedPointStatus(RedPointType.BattlePassMission)
                end)
            end)
        elseif state == 0 then
            if sConFigData.Jump then
                JumpManager.GoJump(sConFigData.Jump)
            end
        end
    end)
end

--刷新进度数据
function this.PassScroll(go, data, index)
    go:SetActive(true)
    if not itemsGrid1 then
        itemsGrid1 = {}
    end
    if not itemsGrid2 then
        itemsGrid2 = {}
    end
    local item1 = Util.GetGameObject(go, "reward1/itemMask/item")
    if not itemsGrid1[go] then
        itemsGrid1[go] = SubUIManager.Open(SubUIConfig.ItemView,item1.transform)
    end
    local item2 = Util.GetGameObject(go, "reward2/itemMask/item")
    if not itemsGrid2[go] then
        itemsGrid2[go] = SubUIManager.Open(SubUIConfig.ItemView,item2.transform)
    end

    itemsGrid1[go]:OnOpen(false, data[1].FreeReward, 0.65, false, false, false, sortingOrder + 10)
    itemsGrid2[go]:OnOpen(false, data[1].BattleReward, 0.65, false, false, false, sortingOrder + 10)

    local lvLock2 = Util.GetGameObject(go, "reward2/lvlock")--vip等级锁
    this.SetActive(Util.GetGameObject(go,"reward1/numBg"), Util.GetGameObject(item1,"ItemView/item/num").activeSelf)
    this.SetActive(Util.GetGameObject(go,"reward2/numBg"), Util.GetGameObject(item2,"ItemView/item/num").activeSelf)
    local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(92001)--是否进阶
    local lock1 = Util.GetGameObject(go, "reward1/lock")--普遍锁
    local lock2 = Util.GetGameObject(go, "reward2/lock")--进阶锁
    local getbtn1 = Util.GetGameObject(go, "reward1/getbtn")--普通领取
    local getbtn2 = Util.GetGameObject(go, "reward2/getbtn")--进阶领取
    local received1 = Util.GetGameObject(go, "reward1/received")--普通已领取
    local received2 = Util.GetGameObject(go, "reward2/received")--进阶已领取
    local Slider1 = Util.GetGameObject(go, "Slider1")

    --需要完成的任务数
    Util.GetGameObject(go, "num"):GetComponent("Text").text = data[1].TaskCount

    this.RefreshRightReward(data[1].TaskCount)

    --设置普通状态
    local setState = function(state)
        this.SetActive(Util.GetGameObject(go,"reward1/mask"), not state)

        if data[2] then
            local isCan = data[2].takTime == 0
            this.SetActive(received1,not isCan)
            this.SetActive(getbtn1,isCan and state)
            this.SetActive(lock1,not isCan and state and not received1.activeSelf)
        else
            this.SetActive(received1,false)
            this.SetActive(getbtn1,state)
            this.SetActive(lock1,false)
        end
    end

    --设置进阶状态
    local setVipState = function(state)
        this.SetActive(Util.GetGameObject(go,"reward2/mask"), not state)
        this.SetActive(lvLock2, data[1].NeedVIP ~= 0)

        local isVip = VipManager.GetVipLevel() >= data[1].NeedVIP--如果玩家VIP >= 奖励需要的VIP
        if data[2] then
            local isCan = data[2].viptakTime == 0--若奖励可领取
            this.SetActive(received2,not isCan)
            this.SetActive(getbtn2,isVip and isCan and isActive and state)
            if not PrivilegeManager.GetPrivilegeOpenStatusById(92001) then
                this.SetActive(lock2, true)
            else
                this.SetActive(lock2,not isVip and isCan and state and not received2.activeSelf)
            end
        else
            this.SetActive(getbtn2,isVip and isActive and state == 0)
            this.SetActive(lock2, not isActive)
            this.SetActive(received2,false)
        end
    end

    local state = false
    if this.pross >= data[1].TaskCount then
        state = true
    end

    setState(state)
    setVipState(state)

    --设置进度条
    local value = 0
    if this.pross > data[1].TaskCount then
        value = 1
    elseif this.pross == data[1].TaskCount then
        value = 0.5 + 0.04
    else
        value = 0
    end
    Util.GetGameObject(Slider1, "Fill Area/Fill"):GetComponent("Image").fillAmount = value

    -- Util.AddOnceClick(go, function()
    --     if this.pross >= data[1].TaskCount then
    --         this.RewardAllReceive()
    --     end
    -- end)
    Util.AddOnceClick(getbtn1, function()
        if this.pross >= data[1].TaskCount then
            this.RewardAllReceive()
        end
    end)
    Util.AddOnceClick(getbtn2, function()
        if this.pross >= data[1].TaskCount then
            this.RewardAllReceive()
        end
    end)
end

--奖励一键领取
function this.RewardAllReceive()
    NetManager.BattlePassGetRequest(0,4, function(respond)
        --获得英雄表现
        if respond.drop.Hero ~= nil and #respond.drop.Hero > 0 then
            local itemDataList = {}
            local itemDataStarList = {}
            Util.GetGameObject(this.panel, "bg"):SetActive(false)
            for i = 1, #respond.drop.Hero do
                local singHeroData = respond.drop.Hero[i]
                HeroManager.UpdateHeroDatas(singHeroData)
                local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", respond.drop.Hero[i].heroId)
                table.insert(itemDataList, heroData)
                table.insert(itemDataStarList, respond.drop.Hero[i].star)
            end
            UIManager.OpenPanel(UIName.PublicGetHeroPanel, itemDataList, itemDataStarList, function ()
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 2)
                Util.GetGameObject(this.panel, "bg"):SetActive(true)
            end)
        else
            UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 2)
            this.RefreshPassData()
        end
    end)
end

function this.SetActive(go, value)
    if go then
        if value and not go.activeSelf then
            go:SetActive(value)
        elseif not value and go.activeSelf then
            go:SetActive(value)
        end
    end
end

local minNun = 0
local maxNum = 1
--刷新右侧奖励预览
function this.RefreshRightReward(value)
    if value < minNun then
        minNun = value
        if minNun + 6 < maxNum then
            maxNum = minNun + 6
        end
    end
    if value > maxNum then
        maxNum = value
        if value > minNun + 6 then
            minNun = maxNum - 6
        end
    end
    if maxNum == 14 then maxNum = 12 end

    local item1 = Util.GetGameObject(this.reward1, "item")
    if not preview1 then
        preview1 = SubUIManager.Open(SubUIConfig.ItemView,item1.transform)
    end
    local item2 = Util.GetGameObject(this.reward2, "item")
    if not preview2 then
        preview2 = SubUIManager.Open(SubUIConfig.ItemView,item2.transform)
    end

    local value = 0
    local data = battlePassConfig[1].StageSection

    this.SetActive(this.rewardPreview, true)
    for i = 1, #data do
        if i == 1 then
            if maxNum < (data[i] - 1) * 2 then
                value = data[i]
            elseif maxNum > data[i] * 2 and maxNum <= (data[i + 1] - 1) * 2 then
                value = data[i + 1]
            end
        elseif i == (#data - 1) then
            if maxNum > data[i] * 2 then
                value = data[i]
                this.SetActive(this.rewardPreview, false)
            end
        else
            if maxNum > data[i] * 2 and maxNum <= (data[i + 1] - 1) * 2 then
                value = data[i + 1]
            end
        end
    end

    for i = 1, #data do
        if value == data[i] then
            this.rewardGoal.text = value * 2
            preview1:OnOpen(false, this.passReward[value][1].FreeReward, 0.65, false)
            preview2:OnOpen(false, this.passReward[value][1].BattleReward, 0.65, false)

            this.SetActive(Util.GetGameObject(this.reward1,"numBg"), Util.GetGameObject(this.reward1,"item/ItemView/item/num").activeSelf)
            this.SetActive(Util.GetGameObject(this.reward2,"numBg"), Util.GetGameObject(this.reward2,"item/ItemView/item/num").activeSelf)
        end
    end
end

--排序逻辑
function this.SortData(allData)
    if allData == nil then
        return
    end
    table.sort(allData, function(a,b)
        if typeIndex[a.state] == typeIndex[b.state] then
            if a.type == b.type then
                return a.missionId < b.missionId
            else
                return a.type < b.type
            end
        else
            return typeIndex[a.state] < typeIndex[b.state]
        end
    end)
    return allData
end
function this:OnClose()
end

function this:OnDestroy()
    preview1 = nil
    preview2 = nil
end

--刷新任务全部领取按钮状态
function this.RefreshTaskAllReceiveState()
    for i, v in ipairs(this.scrollData) do
        for index, value in ipairs(v) do
            if value.state == 1 then
                Util.SetGray(this.btnTaskAllReceive,false)
                return
            end
        end
    end
    Util.SetGray(this.btnTaskAllReceive,true)
end

return this