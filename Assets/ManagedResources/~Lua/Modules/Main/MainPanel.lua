require("Base/BasePanel")
MainPanel = Inherit(BasePanel)
local this = MainPanel
--local isPassChapter = {}
--  local endTime = 0
local GlobalActConfig = ConfigManager.GetConfig(ConfigName.GlobalActivity)
-- local ActGroupsConfig = ConfigManager.GetConfig(ConfigName.ActivityGroups)
-- local shopItemConfig = ConfigManager.GetConfig(ConfigName.StoreConfig)
-- local GlobalSysConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
local mainPlanePoint = ConfigManager.GetConfig(ConfigName.MainPlanePoint)
-- 主界面需要隐藏的功能
this.btnFunHide = {}
this.btnFunGray = {}
this.runHorseData = {}
this.operateIcon = {}
this.multiple = 0 --显示信息次数
this.isOpen = false
this.SystemInfo = ""
local orginLayer
this.patFaceCallList = Stack.New()
local timePressStarted
local curMianTaskData = {}
-- local canGetMsg = true
local moveTranList
--当前拖动的游戏物体
local dragGo = nil
--local isCanDragMsg = true
 local activitys = {}
 local activityTabs = {}
--  local activeSelfTabs = {}
local moveSceneList = {
    [1] = 1,
}
local isOpen = true --收/缩
local isStart = false --动画是否开启
local CrossService = false --跨服天梯是否解锁

--初始化组件（用于子类重写）
function this:InitComponent()
    orginLayer = 0
    self.bg = Util.GetGameObject(self.gameObject, "bg")
    self.sceneTran = Util.GetGameObject(self.gameObject, "scene"):GetComponent("RectTransform")
    self.bgTran = Util.GetGameObject(self.gameObject, "bg"):GetComponent("RectTransform")
    self.ctrl = Util.GetGameObject(self.gameObject, "scene/ctrl")

    ---------------RightDown----------------
    -- 邮件
    this.btnRoot = Util.GetGameObject(self.gameObject, "RightDown/btnRoot")
    this.btnYouJian = Util.GetGameObject(self.gameObject, "RightDown/btnRoot/btnYouJian")
    this.mailRedPoint = Util.GetGameObject(this.btnYouJian, "redPoint")

    -- 日常
    this.btnDailyMission = Util.GetGameObject(self.gameObject, "RightDown/btnRoot/btnDailyMission")
    this.DailyRedPoint = Util.GetGameObject(this.btnDailyMission, "redPoint")

    -- 好友
    this.btnFriend = Util.GetGameObject(self.gameObject, "RightDown/btnRoot/btnfriend")
    this.friendRed = Util.GetGameObject(this.btnFriend, "redPoint")

    -- 排行
    this.btnRank = Util.GetGameObject(self.gameObject, "RightDown/btnRoot/btnRank")
    this.rankRed = Util.GetGameObject(this.btnRank, "redPoint")

    ---------------LeftDown----------------
    this.leftDown = Util.GetGameObject(this.gameObject, "LeftDown")

    --手札
    this.btnBattlePass = Util.GetGameObject(this.gameObject, "LeftDown/btnZhanZhengXueYuan")
    this.btnBattlePassRedPoint = Util.GetGameObject(this.btnBattlePass, "redPoint")

    -------------------场景中的按钮------------------------
    -- 按钮
    local layer1 = Util.GetGameObject(this.gameObject, "scene/layer1")
    this.btnEquipInformationCenter = Util.GetGameObject(layer1, "btnEquipInformationCenter")--启明星科技
    this.btnShangdian = Util.GetGameObject(layer1, "btnShangdian")--超市
    this.btnheishi = Util.GetGameObject(layer1, "btnheishi")--黑市
    this.btnzhihuan = Util.GetGameObject(layer1, "btnzhihuan")--医院
    this.btnElementDrawCard = Util.GetGameObject(layer1, "btnElementDrawCard")--俱乐部
    this.btnRecruit = Util.GetGameObject(layer1, "btnRecruit")--猎头公司
    this.btnTower = Util.GetGameObject(layer1, "btnTower")--神之塔
    this.btnJingjichang = Util.GetGameObject(layer1, "btnJingjichang")--地下竞技场
    this.btnColorfulWorld = Util.GetGameObject(layer1, "btnColorfulWorld")--时空战场
    this.btnFenjie = Util.GetGameObject(layer1, "btnFenjie")--人事管理处
    this.btnhecheng = Util.GetGameObject(layer1, "btnhecheng")--实验室
    this.btnEquipCompound = Util.GetGameObject(layer1, "btnEquipCompound")--研究所
    this.btnInfiniteWar = Util.GetGameObject(layer1, "btnInfiniteWar")--无限战争

    this.operateIcon = {
        [FUNCTION_OPEN_TYPE.InvestigateCenter] = this:AddFuncItem(this.btnEquipInformationCenter, 1000),
        [FUNCTION_OPEN_TYPE.SHOP] = this:AddFuncItem(this.btnShangdian, 1000),
        [FUNCTION_OPEN_TYPE.BlackShop] = this:AddFuncItem(this.btnheishi, 1000),
        [FUNCTION_OPEN_TYPE.HeroExchange] = this:AddFuncItem(this.btnzhihuan, 700),
        [FUNCTION_OPEN_TYPE.ELEMENT_RECURITY] = this:AddFuncItem(this.btnElementDrawCard, 140),
        [FUNCTION_OPEN_TYPE.RECURITY] = this:AddFuncItem(this.btnRecruit, 140),
        [FUNCTION_OPEN_TYPE.CLIMB_TOWER] = this:AddFuncItem(this.btnTower, 75),
        [FUNCTION_OPEN_TYPE.ARENA] = this:AddFuncItem(this.btnJingjichang, 0),
        [FUNCTION_OPEN_TYPE.TRIAL] = this:AddFuncItem(this.btnColorfulWorld, -200),
        [FUNCTION_OPEN_TYPE.HERO_RESOLVE] = this:AddFuncItem(this.btnFenjie, -550),
        [FUNCTION_OPEN_TYPE.ASSEMBLE] = this:AddFuncItem(this.btnhecheng, -900),
        [FUNCTION_OPEN_TYPE.COMPOUND] = this:AddFuncItem(this.btnEquipCompound, -800),
        [FUNCTION_OPEN_TYPE.laddersChallenge] = this:AddFuncItem(this.btnInfiniteWar, 0),
    }

    this.operateNewText = {
        [FUNCTION_OPEN_TYPE.InvestigateCenter] = this:InsertNewText(this.btnEquipInformationCenter),
        [FUNCTION_OPEN_TYPE.SHOP] = this:InsertNewText(this.btnShangdian),
        [FUNCTION_OPEN_TYPE.BlackShop] = this:InsertNewText(this.btnheishi),
        [FUNCTION_OPEN_TYPE.HeroExchange] = this:InsertNewText(this.btnzhihuan),
        [FUNCTION_OPEN_TYPE.ELEMENT_RECURITY] = this:InsertNewText(this.btnElementDrawCard),
        [FUNCTION_OPEN_TYPE.RECURITY] = this:InsertNewText(this.btnRecruit),
        [FUNCTION_OPEN_TYPE.CLIMB_TOWER] = this:InsertNewText(this.btnTower),
        [FUNCTION_OPEN_TYPE.ARENA] = this:InsertNewText(this.btnJingjichang),
        [FUNCTION_OPEN_TYPE.TRIAL] = this:InsertNewText(this.btnColorfulWorld),
        [FUNCTION_OPEN_TYPE.HERO_RESOLVE] = this:InsertNewText(this.btnFenjie),
        [FUNCTION_OPEN_TYPE.ASSEMBLE] = this:InsertNewText(this.ASSEMBLE),
        [FUNCTION_OPEN_TYPE.COMPOUND] = this:InsertNewText(this.btnEquipCompound),
        [FUNCTION_OPEN_TYPE.laddersChallenge] = this:InsertNewText(this.btnInfiniteWar),
    }

    -- 红点
    this.rpShangdian = Util.GetGameObject(this.btnShangdian, "redPoint")--超市
    this.rpElementDrawCard = Util.GetGameObject(this.btnElementDrawCard, "redPoint")--俱乐部
    this.rpRecruit = Util.GetGameObject(this.btnRecruit, "redPoint")--猎头公司
    this.rpTower = Util.GetGameObject(this.btnTower,"redPoint") --神之塔
    this.rpJingjichang = Util.GetGameObject(this.btnJingjichang, "redPoint")--地下竞技场
    this.rpColorfulWorld = Util.GetGameObject(this.btnColorfulWorld, "redPoint")--时空战场
    this.rpFenjie = Util.GetGameObject(this.btnFenjie, "redPoint")--人事管理处
    this.rpEquipCompound = Util.GetGameObject(this.btnEquipCompound,"redPoint") --研究所
    this.rpBlackShop = Util.GetGameObject(this.btnheishi, "redPoint")--黑市

    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)
    this.ChatTipView = SubUIManager.Open(SubUIConfig.ChatTipView, self.transform, 1)
    this.GuideTaskView = SubUIManager.Open(SubUIConfig.GuideTaskView, self.transform, this.sortingOrder,this.btnRoot.transform,this.leftDown.transform)

    moveTranList = {}
    for i = 1, #moveSceneList do
        table.insert(moveTranList, Util.GetGameObject(self.gameObject, "scene/layer" .. i):GetComponent("RectTransform"))
    end

    -- 主线任务显示
    this.mainTask = Util.GetGameObject(self.gameObject, "RightDown/mainTask")
    -- this.titleText = Util.GetGameObject(self.gameObject, "RightDown/mainTask/progressLayout/titleText"):GetComponent("Text")
    -- this.progressText = Util.GetGameObject(self.gameObject, "RightDown/mainTask/progressLayout/progressText"):GetComponent("Text")
    -- this.getRewardButton = Util.GetGameObject(self.gameObject, "RightDown/mainTask/getRewardButton")
    this.mainTaskGRewardImage = Util.GetGameObject(self.gameObject, "RightDown/mainTask/getRewardButton/getRewardImage")
    this.mainTaskJumpImage = Util.GetGameObject(self.gameObject, "RightDown/mainTask/getRewardButton/jumpImage")
    this.mainTask:SetActive(false)-- 删除

    this.GuideEffectGo = poolManager:LoadAsset("GuideEffect", PoolManager.AssetType.GameObject)
    this.GuideEffectGo.transform:SetParent(this.mainTaskGRewardImage.transform)
    this.GuideEffectGo.transform.localPosition = Vector3.zero
    this.GuideEffectGo.transform.localScale = Vector3.one
    Util.GetGameObject(this.GuideEffectGo, "GameObject"):SetActive(false)
    this.GuideJumpEffectGo = poolManager:LoadAsset("GuideEffect", PoolManager.AssetType.GameObject)
    this.GuideJumpEffectGo.transform:SetParent(this.mainTaskJumpImage.transform)
    this.GuideJumpEffectGo.transform.localPosition = Vector3.zero
    this.GuideJumpEffectGo.transform.localScale = Vector3.one
    Util.GetGameObject(this.GuideJumpEffectGo, "GameObject"):SetActive(false)
    this.GuideJumpEffectGo:SetActive(false)
    this.btnFunHide[FUNCTION_OPEN_TYPE.DAILY_TASK] = this.btnDailyMission
    this.btnFunHide[FUNCTION_OPEN_TYPE.EMAIL] = this.btnYouJian
    this.btnFunHide[FUNCTION_OPEN_TYPE.GOODFRIEND] = this.btnFriend
    this.btnFunHide[FUNCTION_OPEN_TYPE.ALLRANKING] = this.btnRank

    ---------------RightUp----------------
    this.activityTabPrefab = Util.GetGameObject(self.gameObject, "activityTabPrefab")

    this.MiddleGrid = Util.GetGameObject(self.gameObject, "MiddleGrid")
    this.RightUpVertical = Util.GetGameObject(self.gameObject, "RightUpVertical")
    -- this.LeftUpVertical = Util.GetGameObject(self.gameObject, "LeftUpVertical")

    this.retractPos = Util.GetGameObject(self.gameObject, "RightUpVertical/retractPos")
    this.btnRetract = Util.GetGameObject(self.gameObject, "btnRetract")
    this.btnRetractIcon = Util.GetGameObject(self.gameObject, "btnRetract/icon"):GetComponent("Image")

    ---------------白天黑夜场景----------------
    this.dayScene = Util.GetGameObject(this.gameObject, "scene/layer1/mainSceneBack/Day")
    this.nightScene = Util.GetGameObject(this.gameObject, "scene/layer1/mainSceneBack/Night")

    -- 重新设置背景位置,使关联场景背景正确
    this:SetPos(self.bgTran.anchoredPosition)

    this.taskGuideFinger = Util.GetGameObject(this.GuideTaskView.gameObject, "button/tipButtom")--任务引导
    this.battleGuideFinger = Util.GetGameObject(this.BtView.gameObject, "Down/btnJieLing/tipButtom")--闯关引导
    
    local m_lan = PlayerPrefs.GetInt("multi_language", AppConst.originLan)
    Log("m_lan:"..m_lan)
    if m_lan == 10101 or m_lan==10201 then
         for i, v in pairs(this.operateIcon) do
            v.txt:SetActive(true)
        end
    else
        for i, v in pairs(this.operateIcon) do
            v.txt:SetActive(false)
        end

    end
end

local isRetract--收/缩
local isRetractStart = false --动画是否开启
--绑定事件（用于子类重写）
function this:BindEvent()
    self.trigger = Util.GetEventTriggerListener(self.ctrl)
    self.moveTween = self.bg:GetComponent(typeof(UITweenSpring))
    if not self.moveTween then
        self.moveTween = self.bg:AddComponent(typeof(UITweenSpring))
    end
    self.moveTween.enabled = false

    --确定拖动边界
    local uiRoot = UIManager.uiRoot.transform:Find("UIRoot")
    local uiRootRectTransform = uiRoot:GetComponent("RectTransform")
    local sizeDeltaY = uiRootRectTransform.sizeDelta.y
    local height = 2160 --主场景的图是按照这个尺寸来做的
    local scale = sizeDeltaY / height

    local scaleV3 = Vector3.New(scale, scale, 0)
    self.bgTran.localScale = scaleV3
    for i = 1, #moveSceneList do
        moveTranList[i].localScale = scaleV3
    end

    local boundary = (self.bgTran.rect.width * scale - uiRootRectTransform.sizeDelta.x) / 2
    self.leftBoundary = boundary
    self.rightBoundary = -boundary

    self.moveTween.OnUpdate = function (v2)
        this:MoveOffset(v2)
    end 
    self.moveTween.MomentumAmount = 1
    self.moveTween.Strength = 1

    self.trigger.onBeginDrag = self.trigger.onBeginDrag + self.handleOnBeginDrag
    self.trigger.onDrag = self.trigger.onDrag + self.handleOnDrag
    self.trigger.onEndDrag = self.trigger.onEndDrag + self.handleOnEndDrag

    --GM工具
    Util.AddClick(this.headPos, function()
        if AppConst.isOpenGM then
            UIManager.OpenPanel(UIName.GMPanel)
        else
            UIManager.OpenPanel(UIName.SettingPanel)
        end
    end)

    --猎头公司
    this:AddButtonEventTriggerListener(this.btnRecruit, function()
        this.FunctionClickEvent(FUNCTION_OPEN_TYPE.RECURITY, function ()
            UIManager.OpenPanel(UIName.RecruitPanel)
        end)
        this.ScenceBtnClick(FUNCTION_OPEN_TYPE.RECURITY)
    end)
    --俱乐部
    this:AddButtonEventTriggerListener(this.btnElementDrawCard, function()
        this.FunctionClickEvent(FUNCTION_OPEN_TYPE.ELEMENT_RECURITY, function ()
            UIManager.OpenPanel(UIName.CompoundHeroPanel)
        end)
        this.ScenceBtnClick(FUNCTION_OPEN_TYPE.ELEMENT_RECURITY)
    end)
    --实验室
    this:AddButtonEventTriggerListener(this.btnhecheng, function()
        this.FunctionClickEvent(FUNCTION_OPEN_TYPE.ASSEMBLE, function ()
            UIManager.OpenPanel(UIName.AssemblePanel)
        end)
    end)
    --医院
    this:AddButtonEventTriggerListener(this.btnzhihuan, function()
        this.FunctionClickEvent(FUNCTION_OPEN_TYPE.HeroExchange, function ()
            UIManager.OpenPanel(UIName.HeroExchangePanel)
        end)
    end)

    --地下竞技场
    this:AddButtonEventTriggerListener(this.btnJingjichang, function()
        -- JumpManager.GoJump(8001)
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
            UIManager.OpenPanel(UIName.ArenaMainPanel)
        else
            local tip = ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ARENA)
            PopupTipPanel.ShowTip(tip)
        end
        this.ScenceBtnClick(FUNCTION_OPEN_TYPE.ARENA)
    end)

    --时空战场
    this:AddButtonEventTriggerListener(this.btnColorfulWorld, function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TRIAL)
        or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.PEOPLE_MIRROR)
        or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MINSKBATTLE)
        or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALAMEIN_WAR) then
            PlayerManager.carbonType = 2
            UIManager.OpenPanel(UIName.CarbonTypePanelV2)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.TRIAL))
        end
    end)

    --人事管理处
    this:AddButtonEventTriggerListener(this.btnFenjie, function()
        JumpManager.GoJump(24001)
        this.ScenceBtnClick(FUNCTION_OPEN_TYPE.HERO_RESOLVE)
    end)

    --超市
    this:AddButtonEventTriggerListener(this.btnShangdian, function()
        JumpManager.GoJumpAppoint(JumpType.Store, {SHOP_TYPE.ITEM_SHOP})
        this.ScenceBtnClick(FUNCTION_OPEN_TYPE.SHOP)
    end)

    --黑市
    this:AddButtonEventTriggerListener(this.btnheishi, function()
        JumpManager.GoJump(7801)
        this.ScenceBtnClick(FUNCTION_OPEN_TYPE.SHOP)
    end)

    --研究所
    this:AddButtonEventTriggerListener(this.btnEquipCompound, function()
        if ActTimeCtrlManager.IsQualifiled(66) then
            UIManager.OpenPanel(UIName.CompoundPanel)
        end
        this.ScenceBtnClick(FUNCTION_OPEN_TYPE.COMPOUND)
    end)
 
    --神之塔
    this:AddButtonEventTriggerListener(this.btnTower, function()
        JumpManager.GoJump(8401)
    end)

    --启明星科技
    this:AddButtonEventTriggerListener(this.btnEquipInformationCenter, function ()
        JumpManager.GoJump(80011)
    end)

    --无限战争
    this:AddButtonEventTriggerListener(this.btnInfiniteWar, function ()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.laddersChallenge) then
            UIManager.OpenPanel(UIName.LaddersTypePanel)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.SystemOpenTip(FUNCTION_OPEN_TYPE.laddersChallenge))
        end
    end)

    --日常任务
    Util.AddClick(this.btnDailyMission, function()
        UIManager.OpenPanel(UIName.MissionDailyPanel)
    end)

    --邮件
    Util.AddClick(this.btnYouJian, function()
        UIManager.OpenPanel(UIName.MailMainPanel)
    end)

    --排行
    Util.AddClick(this.btnRank, function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALLRANKING) then
            local types = {}
            local activiteIds = {}
            for i = 1, #RankKingList do
                if RankKingList[i].isRankingMainPanelShow then
                    table.insert(types,RankKingList[i].rankType)
                    table.insert(activiteIds,RankKingList[i].activiteId)
                end
            end
            NetManager.RankFirstRequest(types,activiteIds,function (msg)
                UIManager.OpenPanel(UIName.RankingListMainPanel,msg)
            end)
        else
            local tip = ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ALLRANKING)
            PopupTipPanel.ShowTip(tip)
        end
        this.ScenceBtnClick(FUNCTION_OPEN_TYPE.ALLRANKING)
    end)

    -- 好友
    Util.AddClick(this.btnFriend, function()
        UIManager.OpenPanel(UIName.GoodFriendMainPanel)
    end)

    --手札
    Util.AddClick(this.btnBattlePass, function()
        UIManager.OpenPanel(UIName.BattlePassPanel)
    end)

    --收缩按钮
    Util.AddClick(this.btnRetract, function ()
        if isRetractStart then
            return
        end
        isStart = true
        if this.timeRetract then
            this.timeRetract:Stop()
            this.timeRetract = nil
        end
        if isOpen then
            isOpen = false
            -- this.MiddleGrid:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_GridClose")
            -- this.RightUpVertical:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_RightVerticalClose")
            -- this.LeftUpVertical:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_LeftVerticalClose")
            this.timeRetract = Timer.New(function ()
                this.MiddleGrid:SetActive(false)
                this.RightUpVertical:SetActive(false)
                -- this.LeftUpVertical:SetActive(false)
                this.timeRetract:Stop()
                this.btnRetractIcon.sprite = Util.LoadSprite("cn2-X1_zhucheng_huodong_zhankai")
                isStart = false
            end, 0.25, -1, true)
            this.timeRetract:Start()
        else
            isOpen = true
            this.MiddleGrid:SetActive(true)
            this.RightUpVertical:SetActive(true)
            -- this.LeftUpVertical:SetActive(true)
            -- this.MiddleGrid:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_GridOpen")
            -- this.RightUpVertical:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_RightVerticalOpen")
            -- this.LeftUpVertical:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_LeftVerticalOpen")
            this.timeRetract = Timer.New(function ()
                this.timeRetract:Stop()
                this.btnRetractIcon.sprite = Util.LoadSprite("cn2-X1_zhucheng_huodong_shouqi")
                isStart = false
            end, 0.25, -1, true)
            this.timeRetract:Start()
        end
    end)

    this.BindRedPoint()

    --[[
    -- --特权
    -- Util.AddClick(this.vipPrivilegeBtn, function()
    --     UIManager.OpenPanel(UIName.VipPanelV2)
    -- end)
    -- --逐胜之巅
    -- Util.AddClick(this.zhuShengBtn,function ()
    --     UIManager.OpenPanel(UIName.ArenaTopMatchPanel)
    -- end)
    -- --秘盒
    -- this:AddButtonEventTriggerListener(this.btnSecretBox, function()
    --     this.FunctionClickEvent(FUNCTION_OPEN_TYPE.SECRETBOX, function ()
    --         UIManager.OpenPanel(UIName.SecretBoxPanel)
    --     end)
    --     this.ScenceBtnClick(FUNCTION_OPEN_TYPE.SECRETBOX)
    -- end)
    -- -- 打开怪兽来袭界面t
    -- this:AddButtonEventTriggerListener(this.btnMonster, function()
    --     JumpManager.GoJump(1011)
    --     this.ScenceBtnClick(FUNCTION_OPEN_TYPE.MONSTER_COMING)
    -- end)
    -- -- 场景中的外敌
    -- this:AddButtonEventTriggerListener(this.btnWaiDi, function ()
    --     this.FunctionClickEvent(FUNCTION_OPEN_TYPE.FIGHT_ALIEN, function ()
    --         UIManager.OpenPanel(UIName.AlienMainPanel)
    --     end)

    --     this.ScenceBtnClick(FUNCTION_OPEN_TYPE.FIGHT_ALIEN)
    -- end)
    -- -- 异妖
    -- this:AddButtonEventTriggerListener(this.btnYiYao, function ()
    --     this.FunctionClickEvent(FUNCTION_OPEN_TYPE.DIFFER_DEMONS, function ()
    --         UIManager.OpenPanel(UIName.DiffMonsterPanel)
    --     end)

    --     this.ScenceBtnClick(FUNCTION_OPEN_TYPE.DIFFER_DEMONS)
    -- end)
    ]]
end

-- 添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnChangeName, this.RefreshChangeName)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, this.InitFuncShow)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionClose, this.InitFuncShow)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivityBtn)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnPatFaceRedRefresh, this.RefreshShowPatPaceActivity)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnEnemyListChanged, this.OnAlienListChanged)
    Game.GlobalEvent:AddEvent(GameEvent.EightDay.GetRewardSuccess, this.RefreshEightGiftPreview)
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.RefreshEightGiftPreview)
    -- Game.GlobalEvent:AddEvent(GameEvent.Questionnaire.OnQuestionnaireChange, this.OnQuestionnaireCallBack)
    -- Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityProgressStateChange, this.RefreshGiftBtnShow)
    -- Game.GlobalEvent:AddEvent(GameEvent.Player.OnPlayerLvChange, this.RefreshPlayerInfoShow)
    Game.GlobalEvent:AddEvent(GameEvent.MianGuide.RefreshGuide, this.ShowGuide)
    Game.GlobalEvent:AddEvent(GameEvent.Battle.OnBattleUIEnd, this.RefreshInBattle)
    Game.GlobalEvent:AddEvent(GameEvent.Main.ActivityRefresh, this.RefreshActivityShow)
end

-- 移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnChangeName, this.RefreshChangeName)
    Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnFunctionOpen, this.InitFuncShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnFunctionClose, this.InitFuncShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivityBtn)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnPatFaceRedRefresh, this.RefreshShowPatPaceActivity)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnEnemyListChanged, this.OnAlienListChanged)
    Game.GlobalEvent:RemoveEvent(GameEvent.EightDay.GetRewardSuccess, this.RefreshEightGiftPreview)
    Game.GlobalEvent:RemoveEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.RefreshEightGiftPreview)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityProgressStateChange, this.RefreshGiftBtnShow)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Questionnaire.OnQuestionnaireChange, this.OnQuestionnaireCallBack)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnPlayerLvChange, this.RefreshPlayerInfoShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.MianGuide.RefreshGuide, this.ShowGuide)
    Game.GlobalEvent:RemoveEvent(GameEvent.Battle.OnBattleUIEnd, this.RefreshInBattle)
    Game.GlobalEvent:RemoveEvent(GameEvent.Main.ActivityRefresh, this.RefreshActivityShow)
end

-- 改变层级
function this:OnSortingOrderChange()
    self.sceneTran.gameObject:GetComponent("Canvas").sortingOrder = self.sortingOrder - 4
    Util.AddParticleSortLayer(this.sceneTran.gameObject, self.sortingOrder - orginLayer)
    -- Util.AddParticleSortLayer(this.vipPrivilegeBtn, self.sortingOrder - orginLayer)

    if orginLayer < 100 then
        Util.AddParticleSortLayer(self.GuideEffectGo, self.sortingOrder)
        Util.AddParticleSortLayer(self.GuideJumpEffectGo, self.sortingOrder)
    else
        Util.AddParticleSortLayer(self.GuideEffectGo, self.sortingOrder - orginLayer)
        Util.AddParticleSortLayer(self.GuideJumpEffectGo, self.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder

    this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })

    Util.GetGameObject(this.battleGuideFinger,"icon"):GetComponent("Canvas").sortingOrder = self.canvas.sortingOrder + 55
    Util.SetParticleSortLayer(Util.GetGameObject(this.battleGuideFinger,"icon/ring"), self.canvas.sortingOrder + 55)
    Util.SetParticleSortLayer(Util.GetGameObject(this.battleGuideFinger,"icon/glow"), self.canvas.sortingOrder + 55)
    Util.SetParticleSortLayer(Util.GetGameObject(this.battleGuideFinger,"icon/diliang"), self.canvas.sortingOrder + 55)
    Util.GetGameObject(this.taskGuideFinger,"icon"):GetComponent("Canvas").sortingOrder = self.canvas.sortingOrder + 55
    Util.SetParticleSortLayer(Util.GetGameObject(this.taskGuideFinger,"icon/ring"), self.canvas.sortingOrder + 55)
    Util.SetParticleSortLayer(Util.GetGameObject(this.taskGuideFinger,"icon/glow"), self.canvas.sortingOrder + 55)
    Util.SetParticleSortLayer(Util.GetGameObject(this.taskGuideFinger,"icon/diliang"), self.canvas.sortingOrder + 55)
end

function this:OnOpen()
    activitys = DynamicActivityManager.GetActivityTableDataByPageInde(0)

    this.CreatActivity()

    PVEActivityManager.InfoList()
end

--界面打开时调用（用于子类重写）
function this:OnShow()
    if Time.timeScale ~= 1 then
        Time.timeScale = 1
    end

    if not isOpen then
        isStart = true
        if this.timeRetract then
            this.timeRetract:Stop()
            this.timeRetract = nil
        end
        isOpen = true
        this.MiddleGrid:SetActive(true)
        this.RightUpVertical:SetActive(true)
        -- this.LeftUpVertical:SetActive(true)
        this.MiddleGrid:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_GridOpen")
        this.RightUpVertical:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_RightVerticalOpen")
        -- this.LeftUpVertical:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_LeftVerticalOpen")
        this.timeRetract = Timer.New(function ()
            this.timeRetract:Stop()
            this.btnRetractIcon.sprite = Util.LoadSprite("cn2-X1_zhucheng_huodong_shouqi")
            isStart = false
        end, 0.25, -1, true)
        this.timeRetract:Start()
    end
    
    timePressStarted = Time.realtimeSinceStartup
    SoundManager.PlayMusic(SoundConfig.BGM_Main)

    this.PlayerHeadFrameView:OnShow(true)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
    this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.MainCity })
    this.GuideTaskView:RefreshAgainRequest()
    this.RefreshInBattle()

    -- ArenaTopMatchManager.RequestTopMatchBaseInfo()--巅峰赛数据
    -- NetManager.CarChallengeProgressIndication()--梦魇入侵数据
    -- PlayerManager.RefreshreceivedList()

    -- 刷新功能显示
    this.InitFuncShow()
    this.RefreshActivityShow()
    this.RetractShow()


    -- 主界面time创建
    -- endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.SupremeHero)
    this.TimeFormat()
    if not this._TimeCounter then
        this._TimeCounter = Timer.New(this.TimeFormat, 1, -1, true)
        this._TimeCounter:Start()
    end

    -- if AdventureManager.drop ~= nil and AdventureManager.offlineTime ~= 0 then
    --     if AdventureManager.isFirstEnterGetReward and #AdventureManager.drop.itemlist > 0 then
    --         UIManager.OpenPanel(UIName.AdventureProgressPopup)
    --         AdventureManager.isFirstEnterGetReward = false
    --     end
    -- end

    -- 开始定时刷新聊天数据
    this.ChatTipView:StartCheck()

    if GuideManager.IsInMainGuide() or UIManager.IsOpen(UIName.GuidePanel) then
    else
        if PlayerManager.level >= 10 and VipManager.GetVipLevel() == 0 then
            --读取本地是否弹过
            local isEject = PlayerPrefs.GetInt(PlayerManager.uid .. "FirstRechargePanelisEject") == 0
            if isEject then
                PlayerPrefs.SetInt(PlayerManager.uid .. "FirstRechargePanelisEject", 1)
                UIManager.OpenPanel(UIName.FirstRechargePanel)
            end
        end
    end

    -- 刷新拍脸
    local patBool = true
    local patFaceAllData = PatFaceManager.GetPatFaceAllDataTabs()
    if patFaceAllData and #patFaceAllData > 0 and not UIManager.IsOpen(UIName.PatFacePanel) then
        if FirstRechargeManager.IsShowFirstChatge() then
            FirstRechargeManager.PlayerPrefsSetStrItemId(1)
            --发送埋点数据
            patBool = false
            UIManager.OpenPanel(UIName.FirstRechargePanel,nil,function()
            end)
        end
    end
    if AdventureManager.fightAreaMax then
        AdventureManager.GetIsMaxTime()
    end
    if patFaceAllData and #patFaceAllData > 0 and not UIManager.IsOpen(UIName.PatFacePanel) and patBool == true then
        if PatFaceManager.GetPatFaceback() == 1 then
            PatFaceManager.PatFaceback(0)
            PatFaceManager.OpenPatFaceLS()
        end
    end

    GuildManager.CheckGuildTip()-- 检测公会tip

    this.CheckRedPoint()

    AircraftCarrierManager.InitTimer()

    this.SetMainIconPos()

    this.btnBattlePass:SetActive(ActTimeCtrlManager.SingleFuncState(107))
    this.ShowGuide()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    -- 关闭定时刷新数据
    this.ChatTipView:StopCheck()
    PatFaceManager.isLogin = false
    --if patFaceCallList then
    --    patFaceCallList:Clear()
    --end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    for k,v in ipairs(activitys) do
        -- if v.RpType > 0 then
        --     if v.RpType == 21000 then
        --         ClearRedPointObject(RedPointType.AdjutantActivity, activityTabs[k].redpot)
        --     else
        --         ClearRedPointObject(v.RpType, activityTabs[k].redpot)
        --     end
        --     activityTabs[k].go.gameObject:SetActive(false)
        -- end
        if v.RpType > 0 then
            if v.Id == 178 then
                ClearRedPointObject(RedPointType.AdjutantActivity, activityTabs[k].redpot)
            elseif v.Id == 1000 then
                ClearRedPointObject(RedPointType.EightTheLogin_2, activityTabs[k].redpot)
            elseif v.Id == 15 then
                ClearRedPointObject(RedPointType.IncentivePlan, activityTabs[k].redpot)
            else
                ClearRedPointObject(v.RpType, activityTabs[k].redpot)
            end
        elseif v.RpType == -1 then
            if v.Id == 801 then
                ClearRedPointObject(RedPointType.ValuePack, activityTabs[k].redpot)
            elseif v.Id == 1500 then
                ClearRedPointObject(RedPointType.ThousandDraw, activityTabs[k].redpot)
            elseif v.Id  == 300 then
                ClearRedPointObject(RedPointType.Challenge, activityTabs[k].redpot)
            elseif v.Id == 1201 then
                ClearRedPointObject(RedPointType.NightmareInvasion, activityTabs[k].redpot)
            elseif v.Id == 400 then
                ClearRedPointObject(RedPointType.CardActivity, activityTabs[k].redpot)
            elseif v.Id == 9017 then
                BindRedPointObject(RedPointType.Chaos_MainIcon, activityTabs[k].redpot)
            else
                ClearRedPointObject(RedPointType.PatFace, activityTabs[k].redpot)
            end
        end
        activityTabs[k].go.gameObject:SetActive(false)
    end
    activitys = {}
    activityTabs = {}
    -- activeSelfTabs = {}
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.BtView)
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.HorseRaceLampView)
    SubUIManager.Close(this.ChatTipView)
    SubUIManager.Close(this.GuideTaskView)
    -- 清除红点
    this.ClearRedPoint()
    -- 计时器
    if this._TimeCounter then
        this._TimeCounter:Stop()
        this._TimeCounter = nil
    end
end

local isCanShowMainTaskJumpEffect = true
function this:Update()
    if curMianTaskData and curMianTaskData.state == 0 then
        if isCanShowMainTaskJumpEffect then
            if Time.realtimeSinceStartup - timePressStarted > 5 then
                isCanShowMainTaskJumpEffect = false
                this.GuideJumpEffectGo:SetActive(true)
            end
        end
        if Input.GetMouseButtonDown(0) then
            timePressStarted = Time.realtimeSinceStartup
            isCanShowMainTaskJumpEffect = true
            this.GuideJumpEffectGo:SetActive(false)
        end
    end
end

function this:AddFuncItem(btnGO, pos)
    return {go = btnGO, open = Util.GetGameObject(btnGO, "open"), lock = Util.GetGameObject(btnGO, "lock"), pos = pos,txt=Util.GetGameObject(btnGO, "Text")}
end

function this:InsertNewText(btn)
    local xinText = Util.GetGameObject(btn, "new")
    return xinText
end

function this:handleOnBeginDrag(eventData)
    dragGo = self
    this.moveTween.enabled = true
    this.moveTween.Momentum = Vector3.zero
    this.moveTween.IsUseCallBack = false
end

function this:handleOnDrag(eventData)
    this.moveTween:LerpMomentum(eventData.delta)
    this:MoveOffset(eventData.delta)
end

function this:handleOnEndDrag(eventData)
    dragGo = nil
    this.moveTween.IsUseCallBack = true
    this:MoveOffset(eventData.delta)
end

--相对于当前位置移动 检查边界
function this:MoveOffset(v2)
    local av2 = this.bgTran.anchoredPosition
    local dv2 = Vector2.New(math.clamp(v2.x + av2.x, this.rightBoundary, this.leftBoundary), av2.y)
    if v2.x + av2.x < this.rightBoundary or v2.x + av2.x > this.leftBoundary then
        self.moveTween:Rebound(1, 0.1)
    end
    this:SetPos(dv2)
end

--移动到指定位置 检查边界
function this:MoveToPos(v2)
    local dv2 = Vector2.New(math.clamp(v2.x, this.rightBoundary, this.leftBoundary), v2.y)
    this:SetPos(dv2)
end

--设置位置 不会检查边界
function this:SetPos(v2)
    self.bgTran.anchoredPosition = Vector2.New(v2.x, 0)
    for i = 1, #moveSceneList do
        moveTranList[i].anchoredPosition = Vector2.New(v2.x, 0)
    end
end

--按钮增加拖动和点击
function this:AddButtonEventTriggerListener(go, onClick)
    local trigger = Util.GetEventTriggerListener(go)
    trigger.onBeginDrag = trigger.onBeginDrag + this.handleOnBeginDrag
    trigger.onDrag = trigger.onDrag + this.handleOnDrag
    trigger.onEndDrag = trigger.onEndDrag + this.handleOnEndDrag
    trigger.onPointerClick = trigger.onPointerClick + function()
        if go == dragGo then --已经拖动,就不用执行点击了
            return
        end
        if onClick ~= nil then
            onClick()
        end
    end
end

-- 创建活动
function this.CreatActivity()
    ActivityGiftManager.SetRedState(0)
    local localMiddleGrid=nil
    local localRightGrid=nil
    this.RightUpVertical.gameObject:SetActive(false)
    this.MiddleGrid.gameObject:SetActive(false)
    for k,v in ipairs(activitys) do
        repeat
        if not activityTabs[k] then 
            activityTabs[k] = {}
            local root
            if v.ShowType == 1  then
                root = this.RightUpVertical
                localRightGrid=this.RightUpVertical
            elseif v.ShowType == 2 then
                root = this.MiddleGrid
                localMiddleGrid = this.MiddleGrid
            elseif v.ShowType == 3 then
                root = this.RightUpVertical
                localRightGrid=this.RightUpVertical
            else
                break
            end
            activityTabs[k].go = newObjToParent(this.activityTabPrefab,root)
            -- local img_2 = Util.GetGameObject(activityTabs[k].go, "Image_2")
            activityTabs[k].img = Util.GetGameObject(activityTabs[k].go, "icon/img"):GetComponent("Image")
            activityTabs[k].timeImg = Util.GetGameObject(activityTabs[k].go, "Image_1")
            activityTabs[k].timeText = Util.GetGameObject(activityTabs[k].timeImg, "time"):GetComponent("Text")
            activityTabs[k].redpot = Util.GetGameObject(activityTabs[k].go, "redPoint")
            activityTabs[k].name = Util.GetGameObject(activityTabs[k].go, "Image_2/name"):GetComponent("Text")
            -- local ver1 = img_2:GetComponent("RectTransform")
            -- LayoutRebuilder.ForceRebuildLayoutImmediate(ver1)
            -- local ver2 = activityTabs[k].go:GetComponent("RectTransform")
            -- LayoutRebuilder.ForceRebuildLayoutImmediate(ver2)
        end

        activityTabs[k].go.gameObject.name = "tab"..v.Id
        activityTabs[k].go.gameObject:SetActive(false)
        if v.ShowTime == 0 then
            activityTabs[k].timeImg.gameObject:SetActive(false)
        else
            activityTabs[k].timeImg.gameObject:SetActive(true)
        end

        this.BindBtnRedPoint(activityTabs[k].redpot, v)
        
        --设置图片文字
        if v.ActiveType > 0 then
            local activityId = ActivityGiftManager.IsActivityTypeOpen(v.ActiveType)
            if activityId and activityId > 0 and ActivityGiftManager.IsQualifiled(v.ActiveType) and v.ActiveType ~= 42 then
                local tempConfig = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.ActivityGroups, "ActId", GlobalActConfig[activityId].ShowArt, "PageType", 0, "ActiveType", v.ActiveType)
                if not tempConfig then
                    tempConfig = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.ActivityGroups, "ActId", activityId, "PageType", 0, "ActiveType", v.ActiveType)
                end
                if tempConfig then
                    activityTabs[k].img.sprite = Util.LoadSprite(tempConfig.Icon[1])
                    activityTabs[k].name.text = GetLanguageStrById(tempConfig.Sesc)
                else
                    activityTabs[k].img.sprite = Util.LoadSprite(v.Icon[1])
                    activityTabs[k].name.text = GetLanguageStrById(v.Sesc)
                end
            else
                activityTabs[k].img.sprite = Util.LoadSprite(v.Icon[1])
                activityTabs[k].name.text = GetLanguageStrById(v.Sesc)
            end
        else
            activityTabs[k].img.sprite = Util.LoadSprite(v.Icon[1])
            activityTabs[k].name.text = GetLanguageStrById(v.Sesc)
        end
        activityTabs[k].img:SetNativeSize()

        Util.AddOnceClick(activityTabs[k].go,function()
            if v.ActiveType > 0 then
                this:TabBtnAction(v.ActiveType, 1, v)
            elseif v.FunType > 0 then
                this:TabBtnAction(v.FunType, 2, v)
            else
                this:TabBtnAction(v.ActId, 0, v)
            end
            if v.ActiveType == ActivityTypeDef.DailyRecharge then
                local state = DailyRechargeManager.DailyRechargeExist()
                activityTabs[k].go:SetActive(state)
            end

            this.CloseGuide()
        end)
        until true
    end
    -- if (localMiddleGrid )then
    --     local ver1 = this.MiddleGrid:GetComponent("RectTransform")
    --     LayoutRebuilder.ForceRebuildLayoutImmediate(ver1)
    --     -- local ver1 = this.MiddleGrid.gameObject
    --     -- ver1:SetActive(false)
    --     -- ver1:SetActive(true)
    -- end
    -- if (localRightGrid )then
    --     local ver1 = this.RightUpVertical:GetComponent("RectTransform")
    --     LayoutRebuilder.ForceRebuildLayoutImmediate(ver1)
    --     -- local ver1 = this.RightUpVertical.gameObject
    --     -- ver1:SetActive(false)
    --     -- ver1:SetActive(true)
    -- end
    this.RightUpVertical.gameObject:SetActive(true)
    this.MiddleGrid.gameObject:SetActive(true)
end

--绑定活动按钮红点
function this.BindBtnRedPoint(redpoint, data)
     Log("BindBtnRedPoint data.RpType = " .. data.RpType.. " data.Id = " .. data.Id)
    if data.RpType > 0 then
       
        if data.Id == 178 then
            BindRedPointObject(RedPointType.AdjutantActivity, redpoint)
        elseif data.Id == 1000 then
            BindRedPointObject(RedPointType.EightTheLogin_2, redpoint)
        elseif data.Id == 15 then
            BindRedPointObject(RedPointType.IncentivePlan, redpoint)
        else
            BindRedPointObject(data.RpType, redpoint)
        end
    elseif data.RpType == -1 then
        if data.Id == 801 then
            BindRedPointObject(RedPointType.ValuePack, redpoint)
        elseif data.Id == 1500 then
            BindRedPointObject(RedPointType.ThousandDraw, redpoint)
        elseif data.Id == 300 then
            BindRedPointObject(RedPointType.Challenge, redpoint)
        elseif data.Id == 1201 then
            BindRedPointObject(RedPointType.NightmareInvasion, redpoint)
        elseif data.Id == 400 then
            BindRedPointObject(RedPointType.CardActivity, redpoint)
        elseif data.Id == 9015 then
            redpoint:SetActive(false)
        elseif data.Id == 9017 then
            BindRedPointObject(RedPointType.Chaos_MainIcon, redpoint)
        else
            BindRedPointObject(RedPointType.PatFace, redpoint)
        end
    end
end

function this:TabBtnAction(id, actType, data)
    if actType == 1 then
        if id == ActivityTypeDef.FirstRecharge then
            UIManager.OpenPanel(UIName.FirstRechargePanel)
        elseif id == ActivityTypeDef.SevenDayCarnival then
            UIManager.OpenPanel(UIName.SevenDayCarnivalPanelV2,SevenDayCarnivalManager.GetPriorityDayNumber())
        elseif id == ActivityTypeDef.WarPowerSort then
            UIManager.OpenPanel(UIName.WarPowerSortPanel)
        elseif id == ActivityTypeDef.DailyRecharge or id == ActivityTypeDef.DailyRecharge_2 then
            UIManager.OpenPanel(UIName.DailyRechargePanel)
        elseif id == ActivityTypeDef.Pray then
            UIManager.OpenPanel(UIName.PrayMainPanel)
        elseif id == ActivityTypeDef.DemonSlayer then
            UIManager.OpenPanel(UIName.DemonSlayerPanel)
        elseif id == ActivityTypeDef.TreasureOfSomeBody then
            UIManager.OpenPanel(UIName.GrowthManualPanel,2,1)
        elseif id == ActivityTypeDef.TreasureStore then
            ActivityGiftManager.SetRedState(1)
            CheckRedPointStatus(RedPointType.MunitionsMerchant)
            UIManager.OpenPanel(UIName.TreasureStorePopup, ActivityTypeDef.TreasureStore)
        elseif id == ActivityTypeDef.DynamicAct then
            local dynamicAct = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct)
            local curindex = 1
            if dynamicAct then
                curindex = GlobalActConfig[dynamicAct].ShowArt
            end
            UIManager.OpenPanel(UIName.DynamicActivityPanel,curindex)
        elseif id == ActivityTypeDef.SupremeHero then
            UIManager.OpenPanel(UIName.SupremeHeroPopup)
        elseif id == ActivityTypeDef.NiuZhuan then
            UIManager.OpenPanel(UIName.NiuZhuanQianKunPanel)
        elseif id == ActivityTypeDef.NiuQi then            
            UIManager.OpenPanel(UIName.NiuQiChongTianPanel,data)
        elseif id == ActivityTypeDef.FuXingGaoZhao then
            UIManager.OpenPanel(UIName.FuXingGaoZhaoPanel)
        elseif id == ActivityTypeDef.EightDayGift then
            UIManager.OpenPanel(UIName.EightDayGiftPanel)
        elseif id == 78 then
            local tabIndex = 7
            if ActivityGiftManager.IsQualifiled(ActivityTypeDef.LifeMemebr) and not not ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LifeMemebr) then
                tabIndex = 12
            end
            UIManager.OpenPanel(UIName.OperatingPanel,{tabIndex = tabIndex, extraParam = 2, showType = 2})
        elseif id == ActivityTypeDef.AdjutantCurrent then
            UIManager.OpenPanel(UIName.AdjutantActivityPanel)
        elseif id == ActivityTypeDef.SignInDays then
            UIManager.OpenPanel(UIName.SignInDays)
        elseif id == ActivityTypeDef.FestivalActivity then
            UIManager.OpenPanel(UIName.FestivalActivityPanel)
        elseif id == ActivityTypeDef.ArtilleryDrills then
            UIManager.OpenPanel(UIName.ArtilleryDrillsPanel)
        elseif id == 50000 then
            UIManager.OpenPanel(UIName.CardActivityPanel)
        elseif id == FUNCTION_OPEN_TYPE.Questionnaire then
            local url = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "Hanbok_Questionnaire_URL").Value
            UnityEngine.Application.OpenURL(url)
        elseif id == FUNCTION_OPEN_TYPE.OpenServiceGift then
            UIManager.OpenPanel(UIName.OpenServiceGiftPanel)
        elseif id == 6001 then
            UIManager.OpenPanel(UIName.TreasureStorePopup, ActivityTypeDef.OpenServiceShop)
        end
    elseif actType == 2 then
        if id == FUNCTION_OPEN_TYPE.SERVER_START_GIFT then
            UIManager.OpenPanel(UIName.CourtesyDressPanel)
        elseif id == JumpType.recharge then 
            UIManager.OpenPanel(UIName.MainRechargePanel)
        elseif id == JumpType.ChaosZz then 
            --混乱之治
                NetManager.CampSimpleInfoGetReq(function (msg)
                    if msg.camp~=0 then
                        NetManager.CampWarInfoGetReq(function (msg)
                            UIManager.OpenPanel(UIName.ChaosMainPanel,msg)
                        end)
                    else
                        UIManager.OpenPanel(UIName.ChaosSelectCampPanel,msg)
                    end
                end)
        elseif id == FUNCTION_OPEN_TYPE.EXPERT then
            UIManager.OpenPanel(UIName.ExpertPanel)
        elseif id == JumpType.Welfare then
            UIManager.OpenPanel(UIName.OperatingPanel)
        elseif id == FUNCTION_OPEN_TYPE.LUCKYTURN then
            UIManager.OpenPanel(UIName.LuckyTurnTablePanel)
        elseif id == FUNCTION_OPEN_TYPE.Achiecement then
            UIManager.OpenPanel(UIName.AchievementPanel)
        elseif id == FUNCTION_OPEN_TYPE.GUILD_BATTLE then
            JumpManager.GoJump(75001)
        elseif id == FUNCTION_OPEN_TYPE.ARENA then
            UIManager.OpenPanel(UIName.ArenaTopMatchPanel)
        elseif id == 105 then
            UIManager.OpenPanel(UIName.UpGradePackagePanel)
        elseif id == 94 then
            local tabIndex = 7
            if ActivityGiftManager.IsQualifiled(ActivityTypeDef.LifeMemebr) and not not ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LifeMemebr) then
                tabIndex = 12
            end
            UIManager.OpenPanel(UIName.OperatingPanel,{tabIndex = tabIndex, extraParam = 2, showType = 2})
        elseif id == 95 then
            UIManager.OpenPanel(UIName.TimeLimitSkinPanel)
        elseif id == FUNCTION_OPEN_TYPE.ValuePack then
            UIManager.OpenPanel(UIName.ValuePackPanel)
        elseif id == JumpType.MinskBattle then
            JumpManager.GoJump(76001)
        elseif id == JumpType.TopMatch then
            JumpManager.GoJump(57001)
        elseif id == FUNCTION_OPEN_TYPE.ThousandDraw then
            UIManager.OpenPanel(UIName.ThousandDrawPanel)
        elseif id == FUNCTION_OPEN_TYPE.laddersChallenge then
            NetManager.RequestArenaRankData(1, function()
                UIManager.OpenPanel(UIName.LaddersMainPanel)
            end)
        elseif id == FUNCTION_OPEN_TYPE.PVEActivity then
            UIManager.OpenPanel(UIName.PVEActivityPanel)
        end
    else
    end
end

-- 刷新功能显示
function this.InitFuncShow(funcType)
    --判断开服有礼是否全部领完
    -- if not funcType or funcType == FUNCTION_OPEN_TYPE.SERVER_START_GIFT then
    --     -- if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SERVER_START_GIFT) then
    --     --     if not ActivityGiftManager.onlineOpen and not ActivityGiftManager.sevenDayOpen and not ActivityGiftManager.chapterOpen then
    --     --     else
    --     --     end
    --     -- else
    --     -- end
    --     if funcType == FUNCTION_OPEN_TYPE.SERVER_START_GIFT then
    --         return
    --     end
    -- end

    -- 需要显示隐藏的功能检测
    if funcType then
        if this.btnFunHide[funcType] then
            ActTimeCtrlManager.SetFuncLockState(this.btnFunHide[funcType], funcType, false)
            return
        end
    else
        for i, v in pairs(this.btnFunHide) do
            ActTimeCtrlManager.SetFuncLockState(v, i, false)
        end
    end

    -- 新版解锁图标
    if funcType then
        if this.operateIcon[funcType] then
            local isOpen
            if funcType == FUNCTION_OPEN_TYPE.TRIAL then
                isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TRIAL)
                    or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.PEOPLE_MIRROR)
                    or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MINSKBATTLE)
                    or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALAMEIN_WAR)
            -- elseif funcType == FUNCTION_OPEN_TYPE.laddersChallenge then
            --     isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.laddersChallenge)
            --         and CrossService
            else
                isOpen = ActTimeCtrlManager.SingleFuncState(funcType)
            end

            Util.SetGray(this.operateIcon[funcType].lock,true)
            Util.SetGray(Util.GetGameObject(this.operateIcon[funcType].lock.transform.parent, "Text"), true)
            this.operateIcon[funcType].lock:SetActive(not isOpen)
            this.operateIcon[funcType].open:SetActive(isOpen)
            return
        end
    else
        for i, v in pairs(this.operateIcon) do
            local isOpen
            if i == FUNCTION_OPEN_TYPE.TRIAL then
                isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TRIAL)
                    or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.PEOPLE_MIRROR)
                    or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MINSKBATTLE)
                    or ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALAMEIN_WAR)
            -- elseif i == FUNCTION_OPEN_TYPE.laddersChallenge then
            --     isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.laddersChallenge)
            --         and CrossService
            else
                isOpen = ActTimeCtrlManager.SingleFuncState(i)
            end
            Util.SetGray(Util.GetGameObject(v.lock.transform.parent, "Text"), not isOpen)
            v.lock:SetActive(not isOpen)
            v.open:SetActive(isOpen)
        end
    end
end

-- 时间格式化
function this.TimeFormat()
    for k, v in pairs(activitys) do
        local isShow = DynamicActivityManager.IsQualifiled(v.Id)
        if isShow then
            if v.ActId == 666 then
                local giftList = {}
                giftList = OperatingManager.GetInfoList()
                if #giftList > 0 then 
                    local time = giftList[1].endTime - GetTimeStamp() 
                    if time < 1 then
                        OperatingManager.RemoveItemInfoByType(GoodsTypeDef.DirectPurchaseGift, giftList[1].goodsId)
                        activityTabs[k].go.gameObject:SetActive(false)
                    else
                        activityTabs[k].go.gameObject:SetActive(true)
                        activityTabs[k].timeText.text = TimeToHMS(time)
                    end
                else
                    activityTabs[k].go.gameObject:SetActive(false)
                end
            elseif v.Id == 9017 then   --混乱之治
                if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ChaosZZ) then
                    local time = ActTimeCtrlManager.GetActLeftTime(FUNCTION_OPEN_TYPE.ChaosZZ)
                    activityTabs[k].go.gameObject:SetActive(true) 
                    if time >= 86400 then
                        activityTabs[k].timeText.text = TimeToDH(time)
                    else
                        activityTabs[k].timeText.text = TimeToHMS(time)
                    end
               else
                   activityTabs[k].go.gameObject:SetActive(false)
               end
            elseif v.ActId == 668 then
                -- 加入对月卡的判断
                local isMonthCardActive = OperatingManager.IsMonthCardActive()
                local isOpen_128 = OperatingManager.IsBaseOpen(GoodsTypeDef.MONTHCARD_128)
                local isOpen_328 = OperatingManager.IsBaseOpen(GoodsTypeDef.MONTHCARD_328)
                activityTabs[k].go.gameObject:SetActive(isMonthCardActive and (isOpen_128 or isOpen_328))
                -- if isMonthCardActive then
                    local cardType = nil
                    if isOpen_328 then
                        cardType = GoodsTypeDef.MONTHCARD_328
                    end
                    if not cardType and isOpen_128 then
                        cardType = GoodsTypeDef.MONTHCARD_128
                    end
                    if cardType then
                        local data = OperatingManager.GetGiftGoodsInfo(cardType)
                        if data then
                            local time = data.endTime - PlayerManager.serverTime
                            if time < 1 then
                                activityTabs[k].go.gameObject:SetActive(false)
                            else
                                activityTabs[k].go.gameObject:SetActive(true)
                                activityTabs[k].timeImg.gameObject:SetActive(false)
                                -- if OperatingManager.GetGoodsBuyTime(GoodsTypeDef.MONTHCARD_128) > 0 and OperatingManager.GetGoodsBuyTime(GoodsTypeDef.MONTHCARD_328) > 0 then
                                --     activityTabs[k].timeImg.gameObject:SetActive(false)
                                -- elseif time >= 86400 then
                                --     activityTabs[k].timeText.text = TimeToDH(time)
                                -- else
                                --     activityTabs[k].timeText.text = TimeToHMS(time)
                                -- end
                            end
                        end
                    end
                -- end
            elseif v.ActId == 667 then
                local limitSkinGift = OperatingManager.GetTimeLimitSkinInfoList()
                if not limitSkinGift then
                    activityTabs[k].go.gameObject:SetActive(false)
                else
                    local time = limitSkinGift.endTime - GetTimeStamp()
                    if time > 0 then
                        activityTabs[k].go.gameObject:SetActive(true)
                        activityTabs[k].timeText.text = TimeToFelaxible(time)
                        local canGet = BagManager.GetTotalItemNum(1221) > 0 and BagManager.GetTotalItemNum(1222) > 0 and 
                        BagManager.GetTotalItemNum(1223) > 0 and BagManager.GetTotalItemNum(1224) > 0
                        activityTabs[k].redpot:SetActive(canGet)
                    else
                        activityTabs[k].go.gameObject:SetActive(false)
                    end
                end
            elseif v.ActId == 6301 then
                local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FuXingGaoZhao)
                if ActData then
                    activityTabs[k].timeText.transform.parent.gameObject:SetActive(ActData.value == 0)
                    activityTabs[k].go.gameObject:SetActive(ActData.value ~= 2)
                    if ActData.value == 0 then
                        local data = string.split(ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig,"Id",109).Value,"#")
                        local time = ActData.startTime + tonumber(data[1])*86400 - GetTimeStamp()
                        activityTabs[k].timeText.text = TimeToFelaxible(time)
                        if time <= 0  then
                            activityTabs[k].go.gameObject:SetActive(false)
                        end
                    end
                else
                    activityTabs[k].go.gameObject:SetActive(false)
                end
            elseif v.ShowTime == 1 and activityTabs[k].go.gameObject.activeSelf then
                if v.ActiveType > 0 then
                    local isOpen = ActivityGiftManager.IsActivityTypeOpen(v.ActiveType)
                    -- LogError(tostring(not not isOpen)..v.ActiveType)
                    if isOpen and isOpen > 0 and ActivityGiftManager.IsQualifiled(v.ActiveType) then
                        if v.ActiveType == 42 then
                            if ActivityGiftManager.GetRewardState(42) ~= 3 then
                                local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.SupremeHero)
                                if endTime - PlayerManager.serverTime > 0 then
                                    local time = endTime - PlayerManager.serverTime
                                    if time>= 86400 then
                                        activityTabs[k].timeText.text = TimeToDH(time)
                                    else
                                        activityTabs[k].timeText.text = TimeToHMS(time)
                                    end
                                else
                                    activityTabs[k].go.gameObject:SetActive(false)
                                end
                            else
                                activityTabs[k].go.gameObject:SetActive(false)   
                            end
                        elseif v.FunType and v.FunType == 41 then
                            if v.Id == 209 then
                                activityTabs[k].go.gameObject:SetActive(DailyRechargeManager.DailyRechargeExist() and not Util.GetGameObject(this.RightUpVertical, "tab4").activeSelf)
                            else
                                activityTabs[k].go.gameObject:SetActive(DailyRechargeManager.DailyRechargeExist() and not Util.GetGameObject(this.RightUpVertical, "tab209").activeSelf)
                            end
                        elseif v.ActiveType == FUNCTION_OPEN_TYPE.Questionnaire then
                            activityTabs[k].go.gameObject:SetActive(true)
                        elseif v.ActiveType == FUNCTION_OPEN_TYPE.OpenServiceGift then
                            activityTabs[k].go.gameObject:SetActive(true)
                        elseif v.ActiveType == ActivityTypeDef.SignInDays then
                            activityTabs[k].go.gameObject:SetActive(true)
                        else
                            local info = ActivityGiftManager.GetActivityTypeInfo(v.ActiveType)
                            local extraTime = 0
                            if ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity,"Type",v.ActiveType).GapTime and ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity,"Type",v.ActiveType).GapTime > 0 then
                                extraTime = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity,"Type",v.ActiveType).GapTime*86400
                            end
                            local tempTime = info.endTime - GetTimeStamp()
                            if tempTime - extraTime > 0 then
                                activityTabs[k].timeText.text = TimeToFelaxible(tempTime - extraTime)
                            elseif tempTime > 0 and tempTime < extraTime then
                                activityTabs[k].timeText.text = TimeToFelaxible(tempTime)
                            else
                                activityTabs[k].go.gameObject:SetActive(false)
                            end
                        end
                    else
                        activityTabs[k].go.gameObject:SetActive(false)
                    end
                elseif v.FunType == FUNCTION_OPEN_TYPE.ARENA then
                    local isOpen = ActTimeCtrlManager.SingleFuncState(v.FunType)
                    local baseInfo = ArenaTopMatchManager.GetBaseData()
                    if not isOpen or not baseInfo or not baseInfo.battleStage or baseInfo.battleStage == TOP_MATCH_STAGE.OVER then
                        activityTabs[k].go.gameObject:SetActive(false)
                    elseif baseInfo.battleStage == TOP_MATCH_STAGE.CLOSE then
                        local startTime = ArenaTopMatchManager.GetTopMatchTime()
                        local tempTime = startTime - PlayerManager.serverTime
                        -- 当日五点开始显示
                        if tempTime > 0 and tempTime < 16 * 60 * 60 then
                            activityTabs[k].go.gameObject:SetActive(true)
                            activityTabs[k].timeText.text = GetLanguageStrById(11211)..TimeToHMS(tempTime)
                        else
                            activityTabs[k].go.gameObject:SetActive(false)
                        end
                    else
                        activityTabs[k].go.gameObject:SetActive(true)
                        activityTabs[k].timeText.text = GetLanguageStrById(11212)
                    end
                elseif v.FunType == FUNCTION_OPEN_TYPE.GUILD_BATTLE then
                    local timeDown = GuildBattleManager.overTime-GetTimeStamp()
                    if timeDown <= 0 then
                        activityTabs[k].go.gameObject:SetActive(false)
                    else
                        activityTabs[k].go.gameObject:SetActive(true)
                        activityTabs[k].timeText.text = TimeToHMS(timeDown)
                    end
                elseif v.FunType == FUNCTION_OPEN_TYPE.MINSKBATTLE then
                    if GuildCarDelayManager.endTime then
                        if GuildCarDelayManager.endTime - GetTimeStamp() > 0 then
                            activityTabs[k].timeText.text = TimeToHMS(GuildCarDelayManager.endTime - GetTimeStamp())
                            activityTabs[k].go.gameObject:SetActive(true)
                        else
                            activityTabs[k].go.gameObject:SetActive(false)
                        end
                    end
                elseif v.FunType == FUNCTION_OPEN_TYPE.TOP_MATCH then
                    local isActive = ArenaTopMatchManager.IsTopMatchActive()
                    if isActive then
                        local tmData = ArenaTopMatchManager.GetBaseData()
                        if tmData then
                            if tmData.progress == -1 then--即将开启
                                activityTabs[k].go.gameObject:SetActive(false)
                            elseif tmData.progress == -2 then--已结束
                                activityTabs[k].go.gameObject:SetActive(false)
                            else
                                local startTime, endTime = ArenaTopMatchManager.GetTopMatchTime()
                                local leftTime = endTime - GetTimeStamp()
                                if leftTime <= 0 then
                                    activityTabs[k].go.gameObject:SetActive(false)
                                else
                                    activityTabs[k].go.gameObject:SetActive(true)
                                    activityTabs[k].timeText.text = TimeToHMS(leftTime)
                                end
                            end
                        end
                    else
                        activityTabs[k].go.gameObject:SetActive(false)
                    end
                elseif v.FunType == FUNCTION_OPEN_TYPE.laddersChallenge then
                    if LaddersArenaManager.GetStage() ~= 2 or LaddersArenaManager.Enterable() == -1 then
                        activityTabs[k].go.gameObject:SetActive(false)
                    else
                        local peakednessTime= LaddersArenaManager.GetLeftTime()-435600 
                        if peakednessTime > 0 then
                            --九境巅峰时间定死为两天
                           
                            activityTabs[k].timeText.text = TimeToHMS(peakednessTime)
                            activityTabs[k].go.gameObject:SetActive(true)
                        else
                            activityTabs[k].go.gameObject:SetActive(false)
                        end
                    end
                elseif v.FunType == FUNCTION_OPEN_TYPE.PVEActivity then
                    if PVEActivityManager.ActivityList() and #PVEActivityManager.ActivityList() > 0 then
                        activityTabs[k].go.gameObject:SetActive(true)
                    else
                        activityTabs[k].go.gameObject:SetActive(false)
                    end
                elseif v.FunType == FUNCTION_OPEN_TYPE.ValuePack then
                else
                    activityTabs[k].go.gameObject:SetActive(false)
                end
            end
        else
            activityTabs[k].go.gameObject:SetActive(false)
        end
    end
end

--为限时折扣写的
function this:GetInfoList()
    local giftList = {}
    local infoList = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)--拿取所有类型5礼包信息(包含需要的礼包)
    local infoList2 = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig,"ShowType",21)
    for index, value in pairs(infoList) do
        for i = 1, #infoList2 do
            if infoList2[i].Id == value.goodsId then
                table.insert(giftList,value)
            end
        end
    end
    return giftList
end

--更改姓名刷新
function this.RefreshChangeName()
    if NameManager.GetRoleName() ~= "" then
        PlayerManager.nickName = NameManager.GetRoleName()
    end
end

--后台推送
function this.RefreshActivityBtn(context)
    for k, v in ipairs(activitys) do  
        local ishow = DynamicActivityManager.IsQualifiled(v.Id)
        if ishow then
            if v.ActiveType > 0 and v.ActiveType == context.type then 
                local activityId = ActivityGiftManager.IsActivityTypeOpen(v.ActiveType)      
                if activityId and activityId > 0 and ActivityGiftManager.IsQualifiled(v.ActiveType) then
                    if v.FunType and v.FunType == 41 then
                        if v.Id == 209 then
                            activityTabs[k].go.gameObject:SetActive(DailyRechargeManager.DailyRechargeExist() and not Util.GetGameObject(this.RightUpVertical, "tab4").activeSelf)
                        else
                            activityTabs[k].go.gameObject:SetActive(DailyRechargeManager.DailyRechargeExist() and not Util.GetGameObject(this.RightUpVertical, "tab209").activeSelf)
                        end
                    elseif v.ActiveType == 20000 then
                        local tempConfig = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.ActivityGroups,"ActId",GlobalActConfig[activityId].ShowArt,"PageType",0,"ActiveType:",v.ActiveType)
                        if not tempConfig then
                            tempConfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.ActivityGroups,"ActId",activityId,"PageType",0)
                        end
                        if tempConfig then
                            activityTabs[k].img.sprite = Util.LoadSprite(tempConfig.Icon[1])
                            activityTabs[k].name.text  = tempConfig.Sesc
                        end
                        activityTabs[k].go.gameObject:SetActive(context.status == 1)
                    end
                else
                    activityTabs[k].go.gameObject:SetActive(false)
                end
            elseif v.FunType > 0 and v.FunType == context.type then
                if ActTimeCtrlManager.SingleFuncState(v.FunType) then
                    if v.FunType and v.FunType == 41 then
                        if v.Id == 209 then
                            activityTabs[k].go.gameObject:SetActive(DailyRechargeManager.DailyRechargeExist() and not Util.GetGameObject(this.RightUpVertical, "tab4").activeSelf)
                        else
                            activityTabs[k].go.gameObject:SetActive(DailyRechargeManager.DailyRechargeExist() and not Util.GetGameObject(this.RightUpVertical, "tab209").activeSelf)
                        end
                    else
                        activityTabs[k].go.gameObject:SetActive(context.status == 1)
                    end
                else
                    activityTabs[k].go.gameObject:SetActive(false)
                end
            end
        else
            activityTabs[k].go.gameObject:SetActive(false)
        end
    end
    isRefeshIcon = true
end

--客户端自己Show刷新
function this.RefreshActivityShow()
    this.RefreshEightGiftPreview()
    for k, v in ipairs(activitys) do
        local isShow = DynamicActivityManager.IsQualifiled(v.Id)
        if isShow then
            if v.ActiveType < 1 and v.FunType < 1 then
                if v.ActId == 666 then
                    --限时折扣
                    local giftList = {}
                    giftList = OperatingManager.GetInfoList()
                    if #giftList > 0 then
                        local time = giftList[1].endTime - GetTimeStamp()
                        if time < 1 then
                            OperatingManager.RemoveItemInfoByType(GoodsTypeDef.DirectPurchaseGift, giftList[1].goodsId)
                            activityTabs[k].go.gameObject:SetActive(false)
                        else
                            activityTabs[k].go.gameObject:SetActive(true)
                        end
                    else
                        activityTabs[k].go.gameObject:SetActive(false)
                    end
                elseif v.ActId == 668 then
                    --超值基金
                    -- 加入对月卡的判断
                    local isMonthCardActive = OperatingManager.IsMonthCardActive()
                    local isOpen_128 = OperatingManager.IsBaseOpen(GoodsTypeDef.MONTHCARD_128)
                    local isOpen_328 = OperatingManager.IsBaseOpen(GoodsTypeDef.MONTHCARD_328)
                    activityTabs[k].go.gameObject:SetActive(isMonthCardActive and (isOpen_128 or isOpen_328))
                    if isMonthCardActive then
                        local cardType = nil
                        if isOpen_328 then
                            cardType = GoodsTypeDef.MONTHCARD_328
                        end
                        if not cardType and isOpen_128 then
                            cardType = GoodsTypeDef.MONTHCARD_328
                        end
                        if cardType then
                            local data = OperatingManager.GetGiftGoodsInfo(cardType)
                            if data then
                                local time = data.endTime - PlayerManager.serverTime
                                if time < 1 then
                                    activityTabs[k].go.gameObject:SetActive(false)
                                else
                                    activityTabs[k].go.gameObject:SetActive(true)
                                end
                            end
                        end
                    end
                end
            elseif v.ActiveType > 0 then
                local activityId = ActivityGiftManager.IsActivityTypeOpen(v.ActiveType)
                -- LogError(tostring(not not activityId)..v.ActiveType)
                if activityId and activityId > 0 and ActivityGiftManager.IsQualifiled(v.ActiveType) then
                    if v.ActiveType == 42 then
                        if ActivityGiftManager.GetRewardState(42) ~= 3 then
                            local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.SupremeHero)
                            if endTime - PlayerManager.serverTime > 0 then
                                activityTabs[k].go.gameObject:SetActive(true)
                                if GuideManager.IsInMainGuide() or UIManager.IsOpen(UIName.GuidePanel) then
                                else
                                    local isEject = PlayerPrefs.GetInt(PlayerManager.uid .. "SupremeHeroPopupisEject") == 0
                                    if isEject then
                                        PlayerPrefs.SetInt(PlayerManager.uid .. "SupremeHeroPopupisEject", 1)
                                        UIManager.OpenPanel(UIName.SupremeHeroPopup)
                                    end
                                end
                            else
                                activityTabs[k].go.gameObject:SetActive(false)
                            end
                        else
                            activityTabs[k].go.gameObject:SetActive(false)
                        end
                    elseif v.FunType and v.FunType == 41 then
                        if v.Id == 209 then
                            activityTabs[k].go.gameObject:SetActive(DailyRechargeManager.DailyRechargeExist() and not Util.GetGameObject(this.RightUpVertical, "tab4").activeSelf)
                        else
                            activityTabs[k].go.gameObject:SetActive(DailyRechargeManager.DailyRechargeExist() and not Util.GetGameObject(this.RightUpVertical, "tab209").activeSelf)
                        end
                    elseif v.ActiveType == FUNCTION_OPEN_TYPE.Questionnaire then
                        activityTabs[k].go.gameObject:SetActive(ActivityGiftManager.IsQualifiled(v.ActiveType))
                    elseif v.ActiveType == FUNCTION_OPEN_TYPE.OpenServiceGift then
                        activityTabs[k].go.gameObject:SetActive(ActivityGiftManager.IsQualifiled(v.ActiveType))
                        local data = ActivityGiftManager.GetActivityTypeInfo(FUNCTION_OPEN_TYPE.OpenServiceGift)
                        if data then
                            if data.mission[1].state == 1 then
                                activityTabs[k].go.gameObject:SetActive(false)
                            end
                        else
                            activityTabs[k].go.gameObject:SetActive(false)
                        end
                    elseif v.ActiveType == ActivityTypeDef.SignInDays then
                        activityTabs[k].go.gameObject:SetActive(true)
                    else
                        activityTabs[k].go.gameObject:SetActive(true)
                    end
                else
                    activityTabs[k].go.gameObject:SetActive(false)
                end
            elseif v.FunType > 0 then
                if ActTimeCtrlManager.SingleFuncState(v.FunType) then
                    if v.FunType == FUNCTION_OPEN_TYPE.TOP_MATCH then
                        local isActive = ArenaTopMatchManager.IsTopMatchActive()
                        if isActive then
                            local tmData = ArenaTopMatchManager.GetBaseData()
                            if tmData.progress == -1 then--即将开启
                                activityTabs[k].go.gameObject:SetActive(false)
                            elseif tmData.progress == -2 then--已结束
                                activityTabs[k].go.gameObject:SetActive(false)
                            else
                                activityTabs[k].go.gameObject:SetActive(true)
                            end
                        else
                            activityTabs[k].go.gameObject:SetActive(false)
                        end
                    elseif v.FunType == FUNCTION_OPEN_TYPE.ThousandDraw then
                        activityTabs[k].go.gameObject:SetActive(true)
                        NetManager.ThousandDrawInfo(function (msg)
                            activityTabs[k].go.gameObject:SetActive(msg.round > 0)
                        end)
                    elseif v.FunType == FUNCTION_OPEN_TYPE.laddersChallenge then
                        if LaddersArenaManager.GetStage() ~= 2 or LaddersArenaManager.Enterable() == -1 then
                            activityTabs[k].go.gameObject:SetActive(false)
                        else
                            activityTabs[k].go.gameObject:SetActive(true)
                        end
                    elseif v.FunType == FUNCTION_OPEN_TYPE.GUILD_BATTLE then
                        activityTabs[k].go.gameObject:SetActive(true)
                    elseif v.FunType == FUNCTION_OPEN_TYPE.PVEActivity then
                        if PVEActivityManager.ActivityList() and #PVEActivityManager.ActivityList() > 0 then
                            activityTabs[k].go.gameObject:SetActive(true)
                        else
                            activityTabs[k].go.gameObject:SetActive(false)
                        end
                    else
                        if activityTabs[k].go then
                            activityTabs[k].go.gameObject:SetActive(true)
                        end
                    end
                else
                    if activityTabs[k].go then
                        activityTabs[k].go.gameObject:SetActive(false)
                    end
                end
            else
                if activityTabs[k].go then
                    activityTabs[k].go.gameObject:SetActive(false)
                end
            end
        else
            if activityTabs[k].go then
                activityTabs[k].go.gameObject:SetActive(false)
            end
        end
    end
end

--刷新拍脸活动
function this.RefreshShowPatPaceActivity()
    PatFaceManager.RefreshPatface()
end

--外敌数据变化检测主界面npc显示状态
function this.OnAlienListChanged()
    this.InitFuncShow(FUNCTION_OPEN_TYPE.FIGHT_ALIEN)
end

--八日登录奖励预览
function this.RefreshEightGiftPreview()
    local state = false
    local getRewardState = ActivityGiftManager.sevenDayGetRewardState
    for i, v in pairs(getRewardState) do
        if v == 0 then
            state = true
        end
    end
end

--设置收缩按钮
function this.SetRetract()
    if this.timeRetract then
        this.timeRetract:Stop()
        this.timeRetract = nil
    end
    if isRetract then
        isRetract = false
        PlayerPrefs.SetInt(PlayerManager.uid.."isRetract", 1)
        this.RightUpGrid:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_GridClose")
        this.RightUpVertical:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_VerticalClose")
        this.timeRetract = Timer.New(function ()
            this.RightUpGrid:SetActive(false)
            this.RightUpVertical:SetActive(false)
            this.timeRetract:Stop()
            this.btnRetractIcon.sprite = Util.LoadSprite("cn2-X1_zhucheng_huodong_zhankai")
            isRetractStart = false
        end, 0.25, -1, true)
        this.timeRetract:Start()
    else
        isRetract = true
        PlayerPrefs.SetInt(PlayerManager.uid.."isRetract", 0)
        this.RightUpGrid:SetActive(true)
        this.RightUpVertical:SetActive(true)
        this.RightUpGrid:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_GridOpen")
        this.RightUpVertical:GetComponent("Animator"):Play("cn2-X1_UI_MainPanel_VerticalOpen")
        this.timeRetract = Timer.New(function ()
            this.timeRetract:Stop()
            this.btnRetractIcon.sprite = Util.LoadSprite("cn2-X1_zhucheng_huodong_shouqi")
            isRetractStart = false
        end, 0.25, -1, true)
        this.timeRetract:Start()
    end
end

--点击时检测功能
function this.FunctionClickEvent(funcId, callback)
    if not funcId or funcId == 0 or not callback then return end

    local isOpen = ActTimeCtrlManager.SingleFuncState(funcId)
    if isOpen then
        if callback then callback() end
    else
        PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(funcId))
    end
end

-- 所有按钮的额外点击事件
function this.ScenceBtnClick(funcId)
    if ActTimeCtrlManager.IsQualifiled(funcId) then
        if funcId == FUNCTION_OPEN_TYPE.GUILD then
            this.operateNewText[FUNCTION_OPEN_TYPE.GUILD]:SetActive(false)
            this.BtView:CheckMainCityNew()
        end
    end
    FunctionOpenMananger.CleadNewText(funcId)
end

-- 绑定红点
function this.BindRedPoint()
    BindRedPointObject(RedPointType.Mail, this.mailRedPoint)
    BindRedPointObject(RedPointType.DailyTaskMain, this.DailyRedPoint)
    BindRedPointObject(RedPointType.Shop, this.rpShangdian)
    BindRedPointObject(RedPointType.Arena, this.rpJingjichang)
    BindRedPointObject(RedPointType.Friend, this.friendRed)
    BindRedPointObject(RedPointType.RankingSort, this.rankRed)
    BindRedPointObject(RedPointType.Recruit, this.rpRecruit)
    BindRedPointObject(RedPointType.BattlePassMission,this.btnBattlePassRedPoint)
    BindRedPointObject(RedPointType.ClimbTower,this.rpTower)
    BindRedPointObject(RedPointType.SpaceTimeBattlefield,this.rpColorfulWorld)
    BindRedPointObject(RedPointType.ResearchInstitute,this.rpEquipCompound)
    BindRedPointObject(RedPointType.BlackShop, this.rpBlackShop)
    -- BindRedPointObject(RedPointType.VipPrivilege, this.vipRedPoint)
    -- BindRedPointObject(RedPointType.Setting, this.headRedpot)
    -- BindRedPointObject(RedPointType.Alien, this.rpAlien)
    -- BindRedPointObject(RedPointType.SecretBox, this.rpSecretBox)
    -- BindRedPointObject(RedPointType.DiffMonster, this.rpYiYao)
    -- BindRedPointObject(RedPointType.SupremeHero, this.supremeRedPoint)
    -- BindRedPointObject(RedPointType.LuckyTurn, this.luckyTurnRedPoint)
    -- BindRedPointObject(RedPointType.FindFairy, this.findFairyRedPoint)
    -- BindRedPointObject(RedPointType.Achievement_Main, this.AchievementRedPoint)
    -- BindRedPointObject(RedPointType.DynamicActivity, this.DynamicActivityRedPoint)
    -- BindRedPointObject(RedPointType.Adjutant, this.btnFuguanRedPoint)
end

-- 清除红点
function this.ClearRedPoint()
    ClearRedPointObject(RedPointType.Mail, this.mailRedPoint)
    ClearRedPointObject(RedPointType.DailyTaskMain, this.DailyRedPoint)
    ClearRedPointObject(RedPointType.Shop, this.rpShangdian)
    ClearRedPointObject(RedPointType.Arena, this.rpJingjichang)
    ClearRedPointObject(RedPointType.Friend, this.friendRed)
    ClearRedPointObject(RedPointType.RankingSort, this.rankRed)
    ClearRedPointObject(RedPointType.Recruit, this.rpRecruit)
    ClearRedPointObject(RedPointType.BattlePassMission,this.btnBattlePassRedPoint)
    ClearRedPointObject(RedPointType.ClimbTower,this.rpTower)
    ClearRedPointObject(RedPointType.SpaceTimeBattlefield,this.rpColorfulWorld)
    ClearRedPointObject(RedPointType.ResearchInstitute,this.rpEquipCompound)
    ClearRedPointObject(RedPointType.BlackShop, this.rpBlackShop)
    -- ClearRedPointObject(RedPointType.VipPrivilege, this.vipRedPoint)
    -- ClearRedPointObject(RedPointType.Setting, this.headRedpot)
    -- ClearRedPointObject(RedPointType.SecretBox, this.rpSecretBox)
    -- ClearRedPointObject(RedPointType.Alien, this.rpAlien)
    -- ClearRedPointObject(RedPointType.DiffMonster, this.rpYiYao)
    -- ClearRedPointObject(RedPointType.SupremeHero, this.supremeRedPoint)
    -- ClearRedPointObject(RedPointType.LuckyTurn, this.luckyTurnRedPoint)
    -- ClearRedPointObject(RedPointType.FindFairy, this.findFairyRedPoint)
    -- ClearRedPointObject(RedPointType.Achievement_Main, this.AchievementRedPoint)
    -- ClearRedPointObject(RedPointType.DynamicActivity, this.DynamicActivityRedPoint)
    -- ClearRedPointObject(RedPointType.Adjutant, this.btnFuguanRedPoint)
end

-- 检测红点
function this.CheckRedPoint()
    CheckRedPointStatus(RedPointType.RankingSort)
    CheckRedPointStatus(RedPointType.ClimbTowerFreeTime)
    CheckRedPointStatus(RedPointType.BattlePassMission)
    CheckRedPointStatus(RedPointType.TreasureOfSl)
    CheckRedPointStatus(RedPointType.DynamicActTask)
    CheckRedPointStatus(RedPointType.Operating)
    CheckRedPointStatus(RedPointType.ThousandDraw)
    CheckRedPointStatus(RedPointType.BlackShop)
    CheckRedPointStatus(RedPointType.AdjutantActivity)
    CheckRedPointStatus(RedPointType.LifeMemeberEveryDay)
    CheckRedPointStatus(RedPointType.NightmareInvasion)
    CheckRedPointStatus(RedPointType.LifeMemeberFree)
    CheckRedPointStatus(RedPointType.CardActivity)
    CheckRedPointStatus(RedPointType.BoxPool)
    CheckRedPointStatus(RedPointType.OpenService)
    CheckRedPointStatus(RedPointType.Expert_UpLv)
    CheckRedPointStatus(RedPointType.Expert_AdventureExper)
    CheckRedPointStatus(RedPointType.Expert_AreaExper)
    CheckRedPointStatus(RedPointType.Expert_UpStarExper)
    CheckRedPointStatus(RedPointType.Expert_EquipExper)
    CheckRedPointStatus(RedPointType.Expert_FightExper)
    CheckRedPointStatus(RedPointType.Expert_EnergyExper)
    CheckRedPointStatus(RedPointType.Expert_AccumulativeRecharge)
    CheckRedPointStatus(RedPointType.Expert_Talisman)
    CheckRedPointStatus(RedPointType.Expert_SoulPrint)
    CheckRedPointStatus(RedPointType.Expert_WeekCard)
    CheckRedPointStatus(RedPointType.HERO_STAR_GIFT)
    CheckRedPointStatus(RedPointType.Expert_FindTreasure)
    CheckRedPointStatus(RedPointType.Expert_LuckyTurn)
    CheckRedPointStatus(RedPointType.Expert_Recruit)
    CheckRedPointStatus(RedPointType.Expert_SecretBox)
    CheckRedPointStatus(RedPointType.Expert_UpLv)
    CheckRedPointStatus(RedPointType.ContinuityRecharge)
    CheckRedPointStatus(RedPointType.OpenServiceShop)
end

--收缩按钮的显隐
function this.RetractShow()
    local isShowActivity = 0
    for i = 1, this.MiddleGrid.transform.childCount do
        if this.MiddleGrid.transform:GetChild(i - 1).gameObject.activeSelf then
            isShowActivity = isShowActivity + 1
        end
    end
    for i = 1, this.RightUpVertical.transform.childCount do
        if this.RightUpVertical.transform:GetChild(i - 1).gameObject.activeSelf then
            isShowActivity = isShowActivity + 1
        end
    end
    this.btnRetract:SetActive(isShowActivity > 1)
end

local isSunDay = false --是否是白天
--设置主界面按钮位置
function this.SetMainIconPos()
    local time = System.DateTime.Now.Hour
    if time >= 7 and time < 19 then
        isSunDay = true
    else
        isSunDay = false
    end

    this.dayScene:SetActive(isSunDay)
    this.nightScene:SetActive(not isSunDay)

    this.btnShangdian:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.SHOP)
    this.btnheishi:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.BlackShop)
    this.btnEquipInformationCenter:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.InvestigateCenter)
    this.btnzhihuan:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.HeroExchange)
    this.btnhecheng:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.ASSEMBLE)
    this.btnRecruit:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.RECURITY)
    this.btnFenjie:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.HERO_RESOLVE)
    this.btnColorfulWorld:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.TRIAL)
    this.btnElementDrawCard:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.ELEMENT_RECURITY)
    this.btnJingjichang:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.ARENA)
    this.btnEquipCompound:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.COMPOUND)
    this.btnTower:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.CLIMB_TOWER)
    this.btnInfiniteWar:GetComponent("RectTransform").localPosition = this.GetBtnPos(FUNCTION_OPEN_TYPE.laddersChallenge)
end
--获取按钮位置
function this.GetBtnPos(type)
    local pos
    local data = {}

    for index, value in ConfigPairs(mainPlanePoint) do
        if value.Type == type then
            data = value
        end
    end

    if isSunDay then
        pos = data.DayCoordinates
    else
        pos = data.NightCoordinates
    end

    return Vector3(pos[1],pos[2],0)
end

--弱引导
function this.ShowGuide()
    this.taskGuideFinger:SetActive(GuideManager.isShowGuide)
    this.battleGuideFinger:SetActive(false)
    GuideManager.isShowGuide = false
    if this.guideTimer then
        this.guideTimer:Stop()
        this.guideTimer = nil
    end
    local time = 5
    this.guideTimer = Timer.New(function()
        if time < 0 then
            if this.guideTimer then
                this.guideTimer:Stop()
                this.guideTimer = nil
            end

            local task, battle = GuideManager.RefreshGuide()
            this.taskGuideFinger:SetActive(task)
            this.battleGuideFinger:SetActive(battle)
            GuideManager.isShowGuide = battle
        end
        time = time - 1
        if GuideManager.IsInMainGuide() or UIManager.IsOpen(UIName.GuidePanel) then
            if this.guideTimer then
                this.guideTimer:Stop()
                this.guideTimer = nil
            end
        end
    end, 1, -1, true)
    this.guideTimer:Start()
end
--关闭弱引导
function this.CloseGuide()
    this.taskGuideFinger:SetActive(false)
    this.battleGuideFinger:SetActive(false)
    GuideManager.isShowGuide = false
    if this.guideTimer then
        this.guideTimer:Stop()
        this.guideTimer = nil
    end
end

--刷新战斗中图标
function this.RefreshInBattle()
    Util.GetGameObject(this.btnTower, "open/Inbattle"):SetActive(false)
    Util.GetGameObject(this.btnInfiniteWar, "open/Inbattle"):SetActive(false)
    Util.GetGameObject(this.btnJingjichang, "open/Inbattle"):SetActive(false)
    Util.GetGameObject(this.btnColorfulWorld, "open/Inbattle"):SetActive(false)
    if BattleManager.IsInBackBattle() then
        if BattleManager.battleType == BATTLE_TYPE.Climb_Tower or BattleManager.battleType == BATTLE_TYPE.Climb_Tower_Advance then
            Util.GetGameObject(this.btnTower, "open/Inbattle"):SetActive(true)
        elseif BattleManager.battleType == BATTLE_TYPE.Ladders_Challenge then
            Util.GetGameObject(this.btnInfiniteWar, "open/Inbattle"):SetActive(true)
        elseif BattleManager.battleType == BATTLE_TYPE.BACK then
            Util.GetGameObject(this.btnJingjichang, "open/Inbattle"):SetActive(true)
        elseif BattleManager.battleType == BATTLE_TYPE.DAILY_CHALLENGE or BattleManager.battleType == BATTLE_TYPE.GUILD_CAR_DELAY or BattleManager.battleType == BATTLE_TYPE.REDCLIFF or BattleManager.battleType == BATTLE_TYPE.ALAMEIN_WAR then
            Util.GetGameObject(this.btnColorfulWorld, "open/Inbattle"):SetActive(true)
        end
    end
end

return MainPanel