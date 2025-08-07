require("Base/BasePanel")
SupremeHeroPopup = Inherit(BasePanel)
local this=SupremeHeroPopup
local artResConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local activityConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

local live2dResName = ""
local heroId = 0
local heroData = {}
local actIsOpen = false
local finishedNum = 0
local missionData = {}

local idList = {
    [1] = 30,
    [2] = 31,
    [3] = 32,
}

local orginLayer = 0
-- 界面是否可以关闭
local canClose = false


---剑影迷踪
--初始化组件（用于子类重写）
function SupremeHeroPopup:InitComponent()
    orginLayer = 0
    this.panel = Util.GetGameObject(self.gameObject,"Panel")
    this.middle = Util.GetGameObject(this.panel,"Middle")
    this.doneBtn = Util.GetGameObject(this.middle,"DoneBtn")
    this.btnText = Util.GetGameObject(this.doneBtn, "Text"):GetComponent("Text")
    --this.previewBtn = Util.GetGameObject(this.middle, "PreviewBtn")
    --this.taskProgress = Util.GetGameObject(this.middle, "di/TaskProgress"):GetComponent("Text")--完成进度
    --this.click = Util.GetGameObject(this.middle, "PreviewBtn/click")
    --this.clickName = Util.GetGameObject(this.middle, "PreviewBtn/di/Name"):GetComponent("Text")

    this.rewardTitle = {}--奖励要求
    this.rewardBtn = {}--奖励前往按钮
    --this.doneImg = {}
    this.rewardGetBtn = {}
    this.iconGrid = {}
    this.itemTitle = {}
    this.itemList = {}
    for i = 1, 3 do
        this.rewardTitle[i] = Util.GetGameObject(this.middle, "Reward/Panel".. i .."/Button_Get/Text"):GetComponent("Text")
        this.rewardBtn[i] = Util.GetGameObject(this.middle, "Reward/Panel".. i .."/Button_Go")
        this.rewardGetBtn[i] = Util.GetGameObject(this.middle, "Reward/Panel".. i .."/Button_Get")
        this.iconGrid[i] = Util.GetGameObject(this.middle, "Reward/Panel".. i .."/frame")
        --this.doneImg[i] = Util.GetGameObject(this.middle, "Reward/Panel".. i .. "/doneImg")
        this.itemTitle[i] =  Util.GetGameObject(this.middle, "Reward/Panel".. i .."/Image/Title"):GetComponent("Text")

    end

    this.activityTime = Util.GetGameObject(self.gameObject, "Panel/Middle/freshTime"):GetComponent("Text")--活动时间

    this.backBtn = Util.GetGameObject(self.gameObject, "Panel/btnBack")
	this.fanhuiBtn = Util.GetGameObject(self.gameObject, "Panel/fanhuiBtn")
    -- this.effectRoot = Util.GetGameObject(self.gameObject, "UI_effect_SupremeHeroPopup_praticle")

    -- effectAdapte(Util.GetGameObject(this.effectRoot, "normal/kuang01/biankuang01"))
    -- effectAdapte(Util.GetGameObject(this.effectRoot, "normal/kuang01/saoguang"))
    -- effectAdapte(Util.GetGameObject(this.effectRoot, "normal/kuang02/biankuang02"))
    -- effectAdapte(Util.GetGameObject(this.effectRoot, "normal/kuang02/saoguang02"))
    -- effectAdapte(Util.GetGameObject(this.effectRoot, "normal/kuang03/biankuang03"))
    -- effectAdapte(Util.GetGameObject(this.effectRoot, "normal/kuang03/saoguang03"))

    --this.LoadLive2D()
    this.hero = Util.GetGameObject(self.gameObject, "Panel/hero")
    this.progress = Util.GetGameObject(self.gameObject, "Panel/Middle/progress"):GetComponent("Text")
    local lang= GetCurLanguage()
    if lang ~= 10001 then
       this.hero.transform.localPosition = Vector3.New(338,266, 0)
    end
end

-- function SupremeHeroPopup:OnSortingOrderChange()
--     Util.AddParticleSortLayer(this.effectRoot, self.sortingOrder - orginLayer)
--     orginLayer = self.sortingOrder
-- end

-- function this.LoadLive2D()
--     -- 加载一个立绘
--     this.live2d = nil
--     local liveId = ActivityGiftManager.GetActivityDataById(42).Drawing
--     heroId = liveId or 10011
--     liveId = heroConfig[heroId].Live
--     this.clickName.text = GetLanguageStrById(heroConfig[heroId].ReadingName)
--     live2dResName = artResConfig[liveId].Name
-- end
-- function this.LoadLive2D()
--     -- 加载一个立绘
--     this.live2d = nil
--     local liveId = ActivityGiftManager.GetActivityDataById(42).Drawing
--     heroId = liveId or 10011
--     liveId = heroConfig[heroId].Live
--     this.clickName.text = heroConfig[heroId].ReadingName
--     live2dResName = artResConfig[liveId].Name
-- end

-- 注册三个跳转事件
local jumpEvnt = {
    [1] = function()
        JumpManager.GoJump(36006)
    end,
    [2] = function()
        JumpManager.GoJump(15001)
    end,
    [3] = function ()
        JumpManager.GoJump(36005)
    end,
}

--绑定事件（用于子类重写）
function SupremeHeroPopup:BindEvent()
    --返回按钮
    Util.AddClick(this.backBtn,function()
        if not canClose then return end
        self:ClosePanel()
    end)
	Util.AddClick(this.fanhuiBtn,function()
        if not canClose then return end
        self:ClosePanel()
    end)
    --完成按钮
    Util.AddClick(this.doneBtn,function()
        if actIsOpen then
            if this.GetRewardState() == 2 then
                NetManager.GetActivityRewardRequest(0, ActivityTypeDef.SupremeHero, function (drop)
                    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
                    for i = 1, #missionData do
                        missionData[i] = 3
                    end
                    Util.SetGray(this.doneBtn, true)
                    this.doneBtn:GetComponent("Button").enabled = false
                    this.btnText.text = GetLanguageStrById(10350)
                    CheckRedPointStatus(RedPointType.SupremeHero)
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10029)
        end
    end)
    --预览按钮
    -- Util.AddClick(this.previewBtn,function()
    --     UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroId, heroData.Star)
    -- end)
    --各任务前往按钮
    for i = 1, #this.rewardBtn do
        Util.AddClick(this.rewardBtn[i],function()
            if  this.GetMissionState(i) == 0 then
                Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceClear)
                jumpEvnt[i]()
                self:ClosePanel()
            end
        end)
    end
    -- Util.AddClick(this.click, function()
    --     UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroId, heroData.Star)
    -- end)
end

--添加事件监听（用于子类重写）
function SupremeHeroPopup:AddListener()
end

--移除事件监听（用于子类重写）
function SupremeHeroPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
local fun = nil
function SupremeHeroPopup:OnOpen(_fun)
    fun = _fun
end

function SupremeHeroPopup:OnShow()
    --actIsDone = false
    --初始化静态显示数据
    this.InitShow()

    canClose = false
    this.effectTime = nil
    this.effectTime = Timer.New(function ()
        canClose = true
    end, 1.2)
    this.effectTime:Start()
end

function this.InitShow()
    ActivityGiftManager.isFirstForSupremeHero = true
    CheckRedPointStatus(RedPointType.SupremeHero)
    heroData = heroConfig[heroId]
    -- 获取任务完成状态
    local total = 3
    finishedNum, missionData = ActivityGiftManager.GetTaskData()
    this.progress.text = GetLanguageStrById(50324) .. " " .. finishedNum.."/"..total
    this.SetMissionData()
    actIsOpen = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SupremeHero) > 0

    Util.SetGray(this.doneBtn, this.GetRewardState() ~= 2)
    this.doneBtn:GetComponent("Button").enabled = this.IsMissionDone()
    local textList = {
        [1] = GetLanguageStrById(10366),--未完成
        [2] = GetLanguageStrById(10022),--领取
        [3] = GetLanguageStrById(10350),--已领取
    }
    this.btnText.text = textList[this.GetRewardState()]
    -- 设置图标显示
    this.SetIconAndTitle()

    Util.ClearChild(this.hero.transform)
    this.heroGo = SubUIManager.Open(SubUIConfig.ItemView, this.hero.transform)
    this.heroGo:OnOpen(false, {10020, 0}, 1)

    -- 开始倒计时
    local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.SupremeHero)
    this.activityTime.text = ""
    if not this.timer then
        this.timer = Timer.New(function ()
            if endTime - PlayerManager.serverTime > 0 then
                this.activityTime.text = TimeToHMS(endTime - PlayerManager.serverTime)
            else
                this.activityTime.text = GetLanguageStrById(10124)
                Util.SetGray(this.doneBtn, true)
                this.doneBtn:GetComponent("Button").enabled = false
                this.timer:Stop()

            end
        end, 1, -1, true)
    end
    this.timer:Start()
end

function  this.SetIconAndTitle()
    for i = 1, 3 do
        local actData = activityConfig[idList[i]]
        this.itemTitle[i].text = GetLanguageStrById(actData.ContentsShow)
        if actData.ExtraParm == 0 then
            return
        end

        local itemId = actData.ExtraParm

        if not this.itemList[i] then
            this.itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.iconGrid[i].transform)
        end

        this.itemList[i]:OnOpen(false, {itemId, 0}, 0.75)
    end
end

-- 活动是否完成
function this.IsMissionDone()
    return finishedNum == 3
end

function this.SetMissionData()
    local data = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SupremeHero)
    for i = 1, 3 do
        this.rewardBtn[i]:SetActive(this.GetMissionState(i) == 0)
        this.rewardGetBtn[i]:SetActive(this.GetMissionState(i) ~= 0)
        this.rewardTitle[i].text=GetLanguageStrById(22603)
        Util.SetGray(this.rewardGetBtn[i],true)
        if i == 3 then
            if this.GetMissionState(i) == 1 then
                this.rewardTitle[i].text = GetLanguageStrById(10022)
                Util.SetGray(this.rewardGetBtn[i],false)           
                Util.AddOnceClick(this.rewardGetBtn[i],function()
                    NetManager.GetActivityRewardRequest(data.mission[i].missionId, data.activityId,function(drop)
                        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                            this.InitShow()
                        end)
                    end)
                end)
            end
        end
    end
end

function this.GetMissionState(index)
    return missionData[index]
end

function this.GetRewardState()
    if not this.IsMissionDone() then
        return 1
    else
        local doneNum = 0
        for i = 1, 3 do
            if missionData[i] == 2 then
                doneNum = doneNum + 1
            end
        end

        local state = doneNum == 3 and 3 or 2
        return state
    end
end

--界面关闭时调用（用于子类重写）
function SupremeHeroPopup:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end

    if this.effectTime then
        this.effectTime:Stop()
        this.effectTime = nil
    end

    if PlayerPrefs.GetInt(PlayerManager.uid .. "SUPREME") == 0 then
        PlayerPrefs.SetInt(PlayerManager.uid .. "SUPREME", 1)
    end
    if fun then
        fun()
        fun = nil
    end
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用（用于子类重写）
function SupremeHeroPopup:OnDestroy()
    this.itemList = {}
end

return SupremeHeroPopup