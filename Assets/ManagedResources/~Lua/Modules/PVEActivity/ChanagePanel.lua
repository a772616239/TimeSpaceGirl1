ChanagePanel = quick_class("PVEActivityPanel")
local this = ChanagePanel
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local FoodsConfig = ConfigManager.GetConfig(ConfigName.FoodsConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

--难度背景
local difficultyBg = {
    GetPictureFont("cn2-X1_pve_nandu_01"),
    GetPictureFont("cn2-X1_pve_nandu_02"),
    GetPictureFont("cn2-X1_pve_nandu_03"),
    GetPictureFont("cn2-X1_pve_nandu_04")
}
--卡牌背景
local cardBg = {
    "cn2-X1_pve_bossdiban_01",
    "cn2-X1_pve_bossdiban_02",
    "cn2-X1_pve_bossdiban_03",
    "cn2-X1_pve_bossdiban_04"
}
--章节背景
local chapterBg = {
    "cn2-X1_pve_zhangjie_xuanzhong",
    "cn2-X1_pve_zhangjie_weixuanzhong",
}
local liveConfig --立绘信息
local liveObj --立绘
local checkpointItem = {} --关卡头像预制
local rewardList = {} --通关奖励
local disableList = {} --禁用列表
local taskList = {} --条件列表
local addGoList = {} --加成列表

local lastchapterBg --上次选中的章节背景
local lastSelectBg --上次选中的关卡背景
local lastSelectChapter --上次选择的章节
local lastSelectId --上次选择的关卡
local lastActivityId --上次的活动
local myParent

function this:InitComponent(go)
    this.gameObject = go

    this.name = Util.GetGameObject(this.gameObject, "bg/title/name/Text"):GetComponent("Text")
    --活动时间
    this.time = Util.GetGameObject(this.gameObject, "time/Text"):GetComponent("Text")
    --禁用
    this.disableGo = Util.GetGameObject(this.gameObject, "grid/disable")
    this.disable = Util.GetGameObject(this.gameObject, "grid/disable/disable/disableGrid")
    this.disablePre = Util.GetGameObject(this.gameObject, "grid/disable/disable/disableGrid/pre")
    --条件
    this.taskGo = Util.GetGameObject(this.gameObject, "grid/task")
    this.task = Util.GetGameObject(this.gameObject, "grid/task/task")
    this.taskPre = Util.GetGameObject(this.gameObject, "grid/task/task/pre")
    --加成
    this.addGo = Util.GetGameObject(this.gameObject, "grid/add")
    this.add = Util.GetGameObject(this.gameObject, "grid/add/add")
    this.addPre = Util.GetGameObject(this.gameObject, "grid/add/add/pre")
    this.addPro = Util.GetGameObject(this.gameObject, "grid/add/addPro")
    -- this.addProPre = Util.GetGameObject(this.gameObject, "grid/add/addPro/pre")
    --通关奖励
    this.reward = Util.GetGameObject(this.gameObject, "reward/Scroll View/Viewport/gird")
    --章节
    this.chapterScroll = Util.GetGameObject(this.gameObject, "chapterScroll")
    this.chapterPre = Util.GetGameObject(this.gameObject, "chapterScroll/pre")
    local chapterScrollV2 = this.chapterScroll:GetComponent("RectTransform").rect
    this.chapterScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.chapterScroll.transform, this.chapterPre, nil,
        Vector2.New(chapterScrollV2.width, chapterScrollV2.height), 2, 1, Vector2.New(5, 0))
    this.chapterScrollView.moveTween.MomentumAmount = 1
    this.chapterScrollView.moveTween.Strength = 2
    --关卡
    this.checkpointScroll = Util.GetGameObject(this.gameObject, "checkpointScroll")
    this.checkpointPre = Util.GetGameObject(this.gameObject, "checkpointScroll/pre")
    local checkpointScrollV2 = this.checkpointScroll:GetComponent("RectTransform").rect
    this.checkpointScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.checkpointScroll.transform, this.checkpointPre, nil,
        Vector2.New(checkpointScrollV2.width, checkpointScrollV2.height), 1, 1, Vector2.New(0, 5))
    this.checkpointScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(20, 0)
    this.checkpointScrollView.moveTween.MomentumAmount = 1
    this.checkpointScrollView.moveTween.Strength = 2
    --挑战
    this.btnChallenge = Util.GetGameObject(this.gameObject, "btnChallenge")
    --次数
    this.countObj = Util.GetGameObject(this.gameObject, "count")
    this.count = Util.GetGameObject(this.gameObject, "count/Text"):GetComponent("Text")
    --怪物信息
    this.cardBg =  Util.GetGameObject(this.gameObject, "bg/cardbg"):GetComponent("Image")
    this.power = Util.GetGameObject(this.gameObject, "bg/cardbg/power/power"):GetComponent("Text")
    this.liveMask = Util.GetGameObject(this.gameObject, "bg/cardbg/mask/root")

    this.move = Util.GetGameObject(this.gameObject, "bg/move"):GetComponent("RectTransform")
    --星数奖励
    this.btnStar = Util.GetGameObject(this.gameObject, "btnStar")
    this.btnStarRedPoint = Util.GetGameObject(this.gameObject, "btnStar/redpoint")

    this.btnScreen = Util.GetGameObject(this.gameObject, "btnScreen")
end

local isInBattle
function this:BindEvent()
    Util.AddClick(this.btnChallenge, function ()
        if BattleManager.IsInBackBattle() then
            return
        end
        if PVEActivityManager.GetTime(lastActivityId) - GetTimeStamp() <= 0 then
            PopupTipPanel.ShowTipByLanguageId(10100)
            return
        end

        local alldata = PVEActivityManager.GetCheckpointList(lastSelectChapter)
        for i=1, #alldata do
            if alldata[i].config.Id == lastSelectId and alldata[i].cost then
                if BagManager.GetItemCountById(alldata[i].cost[1][1]) < alldata[i].cost[1][2] then
                    PopupTipPanel.ShowTipByLanguageId(11880)
                    return
                end
            end
        end

        if isInBattle then
            return
        end
        isInBattle = true
        PVEActivityManager.ChallengeCheckpoint(lastSelectId, 1, function (msg)
            this:OnShow(myParent, lastActivityId)
        end)
    end)

    Util.AddClick(this.btnStar, function ()
        UIManager.OpenPanel(UIName.StarRewardPanel, lastActivityId)
    end)

    Util.AddClick(this.btnScreen, function ()
        UIManager.OpenPanel(UIName.ClimbTowerEliteFilterStarPopup, 2, {lastActivityId})
    end)
    -- RedpotManager.BindObject(RedPointType.PVEStarReward, this.btnStarRedPoint, lastActivityId)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.RedPoint.PveStar, this.RefreshRedpoint)
    Game.GlobalEvent:AddEvent(GameEvent.PVE.Jump, this.Jump)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.RedPoint.PveStar, this.RefreshRedpoint)
    Game.GlobalEvent:RemoveEvent(GameEvent.PVE.Jump, this.Jump)
end

function this:OnSortingOrderChange()
end

-- 打开时调用
function this:OnOpen()
end

function this.RefreshRedpoint()
    this.btnStarRedPoint:SetActive(PVEActivityManager.SetPveStarRewardRedpoint(lastActivityId))
end

--界面打开时调用（用于子类重写）
function this:OnShow(parent, activityId, isJump)
    myParent = parent
    isInBattle = false
    if not isJump then
        lastSelectId = nil
    end
    
    --无星数不显示奖励
    local activityGroups = ConfigManager.GetConfigDataByKey(ConfigName.ActivityGroups, "ActId", activityId)
    this.btnStar:SetActive(activityGroups.ActiveType ~= 30000)
    this.btnScreen:SetActive(activityGroups.ActiveType ~= 30000)

    local chapterList = PVEActivityManager.GetChapterData(activityId)
    if not lastSelectChapter or activityId ~= lastActivityId then
        lastSelectChapter = PVEActivityManager.GetShowChapterId(activityId)
        lastSelectId = nil
    end
    lastActivityId = activityId

    this.RefreshRedpoint()
    this.SetTitleAndTime()
    this.chapterScrollView:SetData(chapterList, function (index, go)
        this.SetChapterData(go, chapterList[index], index)
    end)
    for i = 1, #chapterList do
        if chapterList[i].Id == lastSelectChapter then
            this.chapterScrollView:SetIndex(i)
            local checkpointList = PVEActivityManager.GetCheckpointList(lastSelectChapter)
            for j = 1, #checkpointList do
                if lastSelectId then
                    if checkpointList[j].config.Id == lastSelectId then
                        this.checkpointScrollView:SetIndex(j)
                        break
                    end
                else
                    if checkpointList[j].config.Id == PVEActivityManager.GetUnlockCheckpointFormChapter(checkpointList[j].config.ChapterID) then
                        this.checkpointScrollView:SetIndex(j)
                        break
                    end
                end
            end
        end
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    PVEActivityManager.StopTimeDown()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    if liveObj then
        UnLoadHerolive(liveConfig, liveObj)
        Util.ClearChild(this.liveMask.transform)
        liveObj = nil
    end

    lastActivityId = nil
    lastSelectId = nil
    lastSelectChapter = nil
    lastchapterBg = nil
    lastSelectBg = nil
    checkpointItem = {}
    rewardList = {}
    disableList = {}
    taskList = {}
    addGoList = {}
end

--设置活动时间及倒计时
function this.SetTitleAndTime()
    this.name.text = GetLanguageStrById(ConfigManager.TryGetConfigDataByKey(ConfigName.ActivityGroups, "ActId", lastActivityId).Sesc)
    PVEActivityManager.RemainTimeDown(this.time.gameObject, this.time, PVEActivityManager.GetTime(lastActivityId) - GetTimeStamp())
end

--设置章节信息
function this.SetChapterData(go, data, index)
    local chapter = Util.GetGameObject(go, "chapter"):GetComponent("Text")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    chapter.text = string.format(GetLanguageStrById(22416), index)
    name.text = GetLanguageStrById(data.Name)
    go:GetComponent("Image").sprite = Util.LoadSprite(chapterBg[2])
    chapter.color = Color.New(255/255,255/255,255/255,0.8)
    name.color = Color.New(255/255,255/255,255/255,0.65)

    if data.Id == lastSelectChapter then
        this.SetChapterSelect(go)
        this.GetAllCheckpointData(data.Id)
    end

    --未解锁不显示
    if PVEActivityManager.CheckChapterIsUnlock(data.Id) == 0 and data.TabHide == 0 then
        go:SetActive(false)
    else
        go:SetActive(true)
    end

    Util.AddOnceClick(go, function ()
        if PVEActivityManager.CheckChapterIsUnlock(data.Id) == 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(22557))--未解锁
            return
        end
        lastSelectChapter = data.Id
        lastSelectId = nil
        this.SetChapterSelect(go)
        this.GetAllCheckpointData(data.Id)
    end)
end

--设置章节选中
function this.SetChapterSelect(go)
    if lastchapterBg then
        lastchapterBg:GetComponent("Image").sprite = Util.LoadSprite(chapterBg[2])
        Util.GetGameObject(lastchapterBg, "chapter"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,0.8)
        Util.GetGameObject(lastchapterBg, "name"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,0.65)
    end
    lastchapterBg = go
    go:GetComponent("Image").sprite = Util.LoadSprite(chapterBg[1])
    Util.GetGameObject(go, "chapter"):GetComponent("Text").color = Color.New(0/255,0/255,0/255,0.8)
    Util.GetGameObject(go, "name"):GetComponent("Text").color = Color.New(0/255,0/255,0/255,1)
end

--获取选中章节的关卡数据
function this.GetAllCheckpointData(id)
    for index, value in ipairs(checkpointItem) do
        value.gameObject:SetActive(false)
    end
    local alldata = PVEActivityManager.GetCheckpointList(id)
    this.checkpointScrollView:SetData(alldata, function (index, go)
        this.SetCheckpointData(go, alldata[index], index)
    end)

    for i = 1, #alldata do
        if alldata[i].config.Id == PVEActivityManager.GetUnlockCheckpointFormChapter(alldata[i].config.ChapterID) then
            this.checkpointScrollView:SetIndex(i)
        end
    end
end

--设置关卡信息
function this.SetCheckpointData(go, data, index)
    local select = Util.GetGameObject(go, "select")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local pos = Util.GetGameObject(go, "pos")
    local starGrid = Util.GetGameObject(go, "starGrid")
    local difficulty = Util.GetGameObject(go, "difficulty"):GetComponent("Image")
    local mask = Util.GetGameObject(go, "mask")

    starGrid:SetActive(data.config.StarShow == 1)
    select:SetActive(false)

    if data.config.StarShow then
        for i = 1, 3 do
            if data.starList ~= nil and i <= #data.starList then
                Util.GetGameObject(starGrid, "star"..i.."/Image"):SetActive(true)
            else
                Util.GetGameObject(starGrid, "star"..i.."/Image"):SetActive(false)
            end
        end
    end

    if not checkpointItem[go] then
        checkpointItem[go] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
    end
    checkpointItem[go]:OnOpen(false, {data.config.Enemy, 1}, 0.7)
    checkpointItem[go]:ClickEnable(false)
    checkpointItem[go]:ShowStar(false)

    name.text = GetLanguageStrById(data.config.Name)
    difficulty.sprite = Util.LoadSprite(difficultyBg[data.config.DifficultyShow])
    mask:SetActive(data.state == 0)

    if lastSelectId then
        if data.config.Id == lastSelectId then
            this.SetCheckpointSelect(select)
            this.SetInfo(data)
        end
    else
        if data.config.Id == PVEActivityManager.GetUnlockCheckpointFormChapter(data.config.ChapterID) then
            lastSelectId = data.config.Id
            this.SetCheckpointSelect(select)
            this.SetInfo(data)
        end
    end

    Util.AddOnceClick(go, function ()
        if PVEActivityManager.CheckCheckpointIsUnlock(data.config.Id) == 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(22557))--未解锁
            return
        end
        lastSelectId = data.config.Id
        this.SetCheckpointSelect(select)
        this.SetInfo(data)
    end)
end

--设置信息
function this.SetInfo(data)
    this.SetCardData(data)
    this.SetDisable(data.config)
    this.SetAdd(data.config)
    this.SetTask(data)
    this.SetReward(data)
    this.SetCost(data)
    this.MoveBg()
end

--设置关卡选中
function this.SetCheckpointSelect(select)
    if lastSelectBg then
        lastSelectBg:SetActive(false)
    end
    lastSelectBg = select
    select:SetActive(true)
end

--设置卡牌信息
function this.SetCardData(data)
    this.cardBg.sprite = Util.LoadSprite(cardBg[data.config.DifficultyShow])
    this.power.text = data.config.Power

    --立绘
    if liveObj then
        UnLoadHerolive(liveConfig, liveObj)
        Util.ClearChild(this.liveMask.transform)
        liveObj = nil
    end
    liveConfig = HeroConfig[data.config.Enemy]
    this.liveMask.transform.localPosition = Vector3.New(data.livePos[1], data.livePos[2], 0)
    liveObj = LoadHerolive(liveConfig, this.liveMask)

    this.countObj:SetActive(true)
    if data.config.RepeatTimes == -1 then--不可重复挑战
        -- this.count.text = GetLanguageStrById(50208)
        this.countObj:SetActive(false)
    elseif data.config.RepeatTimes == 0 then--重复挑战
        this.count.text = GetLanguageStrById(50209)
    else
        this.count.text = (data.config.RepeatTimes-data.challengeCount) .."/"..data.config.RepeatTimes
    end
end

--设置禁用
function this.SetDisable(data)
    for i = 1, #disableList do
        disableList[i].gameObject:SetActive(false)
    end
    if not data.LineRules then
        this.disableGo:SetActive(false)
        return
    end
    this.disableGo:SetActive(true)

    local list = {}
    for i = 0, 5 do
        local state = true
        for j = 1, #data.LineRules do
            if data.LineRules[j] == i then
                state = false
            end
        end
        if state then
            table.insert(list, i)
        end
    end

    for i = 1, #list do
        if not disableList[i] then
            disableList[i] = newObjToParent(this.taskPre, this.task.transform)
        end
        disableList[i].gameObject:SetActive(true)
        local icon = Util.GetGameObject(disableList[i], "mask/Image"):GetComponent("Image")
        icon.sprite = Util.LoadSprite(X1CampTabSelectPic[list[i]])
    end
end

--设置条件
function this.SetTask(data)
    for i = 1, #taskList do
        taskList[i].gameObject:SetActive(false)
    end
    if not data.config.StarCondServer or data.config.StarShow == 0 then
        this.taskGo:SetActive(false)
        return
    end
    this.taskGo:SetActive(true)

    for i = 1, #data.config.StarCondServer do
        if not taskList[i] then
            taskList[i] = newObjToParent(this.taskPre, this.task.transform)
        end
        taskList[i].gameObject:SetActive(true)
        local desc = Util.GetGameObject(taskList[i].gameObject, "Text"):GetComponent("Text")
        local str = GVM.GetTaskById(data.config.StarCondServer[i][1], unpack(data.config.StarCondServer[i], 2, #data.config.StarCondServer[i]))
        desc.text = str

        Util.GetGameObject(taskList[i].gameObject, "star/Image"):SetActive(false)
        if data.starList ~= nil and #data.starList > 0 then
            for j = 1, #data.starList do
                if data.config.StarCondServer[i][1] == data.starList[j] then
                    if #data.starList < #data.config.StarCondServer then
                        if i > #data.starList then
                            if data.config.StarCondServer[2][1] == data.config.StarCondServer[3][1] then
                            else
                                Util.GetGameObject(taskList[i].gameObject, "star/Image"):SetActive(true)
                            end
                        else
                            Util.GetGameObject(taskList[i].gameObject, "star/Image"):SetActive(true)
                        end
                    else
                        Util.GetGameObject(taskList[i].gameObject, "star/Image"):SetActive(true)
                    end
                end
            end
        end
    end
end

--设置加成
function this.SetAdd(data)
    if not data.BuffTarget then
        this.addGo:SetActive(false)
        this.addPro:GetComponent("Text").text = ""
        return
    end
    this.addGo:SetActive(true)

    local index = 1
    if data.BuffTarget[1][1] == 1 then--阵营
        if not addGoList[index] then
            addGoList[index] = newObjToParent(this.addPre, this.add)
        end
        addGoList[index]:SetActive(true)

        local img = Util.GetGameObject(addGoList[index], "Image"):GetComponent("Image")
        img.sprite = Util.LoadSprite("cn2-X1_tongyong_zhenying_02")
        img.gameObject:SetActive(true)

        index = index + 1
    elseif data.BuffTarget[1][1] == 2 then--卡牌
        if not addGoList[index] then
            addGoList[index] = newObjToParent(this.addPre, this.add)
        end
        addGoList[index]:SetActive(true)

        local pos = Util.GetGameObject(addGoList[index], "pos")
        Util.ClearChild(pos.transform)
        local itemView = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
        itemView:OnOpen(false, {data.BuffTarget[2][1], 1}, 0.55)
        index = index + 1
    end

    this.SetAddPro(data)
end

-- local buff
--设置加成效果
function this.SetAddPro(data)
    -- if buff then
    --     buff.gameObject:SetActive(false)
    -- end
    -- if not buff then
    --     buff = newObjToParent(this.addProPre, this.addPro)
    -- end
    -- buff.gameObject:SetActive(true)
    if not data.BuffId then
        this.addPro:GetComponent("Text").text = ""
    end
    local config = FoodsConfig[data.BuffId]
    this.addPro:GetComponent("Text").text = GetLanguageStrById(config.Desc)
    -- local title = Util.GetGameObject(buff, "title"):GetComponent("Text")
    -- local value = Util.GetGameObject(buff, "value"):GetComponent("Text")
end

--设置通关奖励
function this.SetReward(allData)
    local data = allData.config
    for i = 1, #rewardList do
        rewardList[i]:SetCorner(1, false)
        rewardList[i]:SetCorner(3, false)
        rewardList[i].gameObject:SetActive(false)
    end
    local index = 1
    if #allData.starList <= 0 then
        for i = 1, #data.FirstReward do
            if not rewardList[index] then
                rewardList[index] = SubUIManager.Open(SubUIConfig.ItemView, this.reward.transform)
            end
            rewardList[index]:OnOpen(false, data.FirstReward[i], 0.65)
            rewardList[index]:SetCorner(1, true)
            rewardList[index].gameObject:SetActive(true)
            index = index + 1
        end
    end

    if data.RepeatReward then
        for i = 1, #data.RepeatReward do
            if not rewardList[index] then
                rewardList[index] = SubUIManager.Open(SubUIConfig.ItemView, this.reward.transform)
            end
            rewardList[index]:OnOpen(false, data.RepeatReward[i], 0.65)
            rewardList[index].gameObject:SetActive(true)
            index = index + 1
        end
    end

    if data.RandomDropShow then
        for i = 1, #data.RandomDropShow do
            if not rewardList[index] then
                rewardList[index] = SubUIManager.Open(SubUIConfig.ItemView, this.reward.transform)
            end
            rewardList[index]:OnOpen(false, data.RandomDropShow[i], 0.65)
            rewardList[index]:SetCorner(3, true)
            rewardList[index].gameObject:SetActive(true)
            index = index + 1
        end
    end
end

--设置消耗
function this.SetCost(data)
    local cost = Util.GetGameObject(this.btnChallenge, "cost")
    local icon = Util.GetGameObject(this.btnChallenge, "cost/icon"):GetComponent("Image")
    local value = Util.GetGameObject(this.btnChallenge, "cost/Text"):GetComponent("Text")
    local txt = Util.GetGameObject(this.btnChallenge, "Text"):GetComponent("Text")
    local clearance = Util.GetGameObject(this.gameObject, "clearance")
    if data.cost then
        cost.gameObject:SetActive(true)
        icon.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[data.cost[1][1]].ResourceID))
        value.text = "x"..data.cost[1][2]
        myParent.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = {16, data.cost[1][1]}})
    else
        cost.gameObject:SetActive(false)
        myParent.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    end

    clearance:SetActive(false)
    this.btnChallenge:SetActive(true)
    txt.text = GetLanguageStrById(10334)
    Util.SetGray(this.btnChallenge, false)
    this.btnChallenge:GetComponent("Button").enabled = true
    if data.state == 2 then
        if data.config.RepeatTimes == -1 then--不可重复挑战
            clearance:SetActive(true)
            this.btnChallenge:SetActive(false)
        elseif data.config.RepeatTimes == 0 then--重复挑战
        else
            if data.config.RepeatTimes-data.challengeCount <= 0 then
                txt.text = GetLanguageStrById(50232)
                Util.SetGray(this.btnChallenge, true)
                this.btnChallenge:GetComponent("Button").enabled = false
            end
        end
    end
end

function this.MoveBg()
    this.move.gameObject:SetActive(true)
    if this.taskGo.gameObject.activeSelf then
        if this.addGo.gameObject.activeSelf then
            this.move.anchoredPosition = Vector2.New(0,710)
        else
            this.move.anchoredPosition = Vector2.New(0,500)
        end
    else
        if this.addGo.gameObject.activeSelf then
            this.move.anchoredPosition = Vector2.New(0,500)
        else
            this.move.gameObject:SetActive(false)
        end
    end
end

function this.Jump(chapter, checkpoint)
    lastSelectChapter = chapter
    lastSelectId = checkpoint
    this:OnShow(myParent, lastActivityId, true)
end

return this