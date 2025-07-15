require("Base/BasePanel")
local MonsterShowPanel = Inherit(BasePanel)
local this = MonsterShowPanel
local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local monsterViewConfig = ConfigManager.GetConfig(ConfigName.MonsterViewConfig)
local rewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)

-- 特效播放完毕之前关闭界面会报错
local canClose = false
local showType = {
    [1] = {resPath = "y-ystx-ystx", text = GetLanguageStrById(10475)},
    [2] = {resPath = "r_shilian_shoulinglaixi", text = GetLanguageStrById(10476)},
    [3] = {resPath = "", text = GetLanguageStrById(10476)},
    [4] = {resPath = "r_guaji_waidiruqin", text = GetLanguageStrById(10477)},
}
this.panelType = 0

-- 英雄
local _HeroPosOffset = {0, -150}  -- 偏移
local _HeroScale = 0.7    -- 缩放
-- 怪物
local _MonsterPosOffset = {0, 0} -- 偏移
local _MonsterScale = 1 -- 缩放

local PANEL_TYPE = {
    ELITE = 1,
    BOSS = 2,
    MONSTER = 3,
    AdventureAlianInvasionBoss=4,
}



--初始化组件（用于子类重写）
function MonsterShowPanel:InitComponent()
    this.btnFight = Util.GetGameObject(self.gameObject, "btnFight")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.timePanel = Util.GetGameObject(self.gameObject, "time")
    this.timeTxt = Util.GetGameObject(self.gameObject, "time/time"):GetComponent("Text")
    this.nameTxt = Util.GetGameObject(self.gameObject, "name"):GetComponent("Text")
    this.lvlTxt = Util.GetGameObject(self.gameObject, "lv"):GetComponent("Text")
    this.hpPanel = Util.GetGameObject(self.gameObject, "hp")
    this.hpTxt = Util.GetGameObject(self.gameObject, "hp/hp"):GetComponent("Text")
    this.liveRoot = Util.GetGameObject(self.gameObject, "liveroot")
    this.rewardPanel = Util.GetGameObject(self.gameObject, "reward")
    this.rewardList = Util.GetGameObject(self.gameObject, "reward/rewardlist")
    this.Third = Util.GetGameObject(self.gameObject, "Third")
    this.rewardtip=Util.GetGameObject(self.gameObject, "reward/rewardtip"):GetComponent("Text")
    -- 提示的图片类型
    this.tipImg = Util.GetGameObject(self.gameObject, "Third/image/ziti"):GetComponent("Image")
    -- 按钮文字
    this.btnText = Util.GetGameObject(self.gameObject, "btnFight/Text"):GetComponent("Text")
    this.hpPanel:SetActive(false)
    this.timePanel:SetActive(false)

    -- 兽潮相关
    this.waveNum = Util.GetGameObject(self.gameObject, "wave"):GetComponent("Text")
    this.monsterRoot = Util.GetGameObject(self.gameObject, "monsterRoot")
    -- 4个妖怪头像
    this.monsterList = {}
    for i = 1, 5 do
        this.monsterList[i] = Util.GetGameObject(this.monsterRoot, "monterRoot/frame_" .. i)
    end

end

--绑定事件（用于子类重写）
function MonsterShowPanel:BindEvent()
    -- 返回按钮
    Util.AddClick(this.btnBack, function()
        if this.panelType == PANEL_TYPE.AdventureAlianInvasionBoss then
            this:ClosePanel()
        else
            if canClose then
                -- 关闭当前界面
                if this.closeCallBack then this.closeCallBack() end
            end
        end

        if this.panelType == PANEL_TYPE.MONSTER then
            if this.closeCallBack then this.closeCallBack() end
            self:ClosePanel()
        end
    end)

    -- 战斗
    Util.AddClick(this.btnFight, function()
        if this.panelType ~= PANEL_TYPE.MONSTER then
            -- 试炼副本等待战斗面板打开后才关闭界面
            if this.panelType == PANEL_TYPE.BOSS then
                CallBackOnPanelOpen(UIName.BattlePanel, function ()
                    this:ClosePanel()
                end)
            else
                this:ClosePanel()
            end
        end


        if this.func then
            this.func()
        end
    end)
end

--添加事件监听（用于子类重写）
function MonsterShowPanel:AddListener()
end

--移除事件监听（用于子类重写）
function MonsterShowPanel:RemoveListener()
end

-- 根据不同的参数类型来显示不同的界面效果
-- 默认不传或者是1，显示为精英怪的数据
-- 参数类型2为试炼副本内的普通Boss怪
-- 参数类型3为兽潮怪物
-- 执行两个回调。第一个是挑战的回调， 第二个是点击关闭的回调
--界面打开时调用（用于子类重写）
function MonsterShowPanel:OnOpen(monsterGroupId, func, closeCallBack, isShowWarning, panelType)
    this.monsterGroupId = monsterGroupId
    this.func = func
    this.closeCallBack = closeCallBack
    this.panelType = panelType
    -- 播放强敌来袭特效
    if isShowWarning then
        this.Third:SetActive(true)
        Timer.New(function ()
            this.Third:SetActive(false)
            canClose = true
        end, 1.5):Start()
    end
    -- 初始化组件显示
    this.InitCompShow(panelType)
    -- 初始化界面显示
    this.InitPanelShow(panelType or 1)
end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MonsterShowPanel:OnShow()
    -- 基础信息
    local monsterGroupId = this.monsterGroupId
    if not monsterGroupId then return end

    -- 获取数据
    local monsterData = monsterGroup[monsterGroupId]

    if not monsterData then

    end

    local monsterId = monsterData.Contents[1][1]
    local monsterInfo = monsterConfig[monsterId]

    -- 加载立绘
    this.LoadLive(monsterInfo.MonsterId)

    -- 基础内容
    this.lvlTxt.text = "Lv."..monsterInfo.Level
    this.nameTxt.text = GetLanguageStrById(monsterInfo.ReadingName)

    -- 奖励展示
    -- 兽潮直接读表
    if this.panelType ~= PANEL_TYPE.MONSTER then
        local rewardId = monsterData.Rewardgroup[1]
        this.GridAdapter(this.rewardList, rewardId)
    end

    -- 加载货币
    if this.panelType == PANEL_TYPE.MONSTER then
        if not this.UpView then
            this.UpView = SubUIManager.Open(SubUIConfig.UpView, MonsterShowPanel.gameObject.transform)
            this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.MonsterCamp })
        end
    end

end

function this.InitCompShow(panelType)
    --精英怪特有
    this.timePanel:SetActive(panelType == PANEL_TYPE.ELITE)
    this.hpPanel:SetActive(panelType == PANEL_TYPE.ELITE)

    -- 兽潮特有
    this.waveNum.gameObject:SetActive(false)
    this.monsterRoot:SetActive(panelType == PANEL_TYPE.MONSTER)
    this.rewardtip.text=GetLanguageStrById(10479)
end


function this.InitPanelShow(panelType)
    if panelType ~= PANEL_TYPE.MONSTER then
        this.tipImg.sprite = Util.LoadSprite(showType[panelType].resPath)
        this.tipImg:SetNativeSize()
        this.btnText.text = showType[panelType].text
    elseif panelType == PANEL_TYPE.MONSTER then
        this.btnText.text = showType[panelType].text
        this.waveNum.text = GetLanguageStrById(10311) .. MonsterCampManager.monsterWave .. GetLanguageStrById(10316)
        -- 显示4只小怪头像
        this.ShowMonsterIcon()
    end

end

-- 设置显示小怪
function this.ShowMonsterIcon()
    local monsterInfo, mainInfo = MonsterCampManager.GetCurMonsterInfo()
    -- 初始化隐藏
    for i = 1, 5 do
        this.monsterList[i]:SetActive(false)
    end


    for i = 1, #monsterInfo.icon do
        Util.GetGameObject(this.monsterList[i], "icon"):GetComponent("Image").sprite = monsterInfo.icon[i]
        this.monsterList[i]:SetActive(true)
    end

    -- 设置奖励
    this.SetRewardShow(this.rewardList, monsterInfo.rewardShow)
end

function this.SetRewardShow(grid, rewardData)
    Util.ClearChild(grid.transform)
    for i = 1, #rewardData do
        local item = {}
        local itemId = rewardData[i][1]
        item[#item + 1] = itemId
        item[#item + 1] = rewardData[i][2]
        local view = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
        view:OnOpen(false, item, 1.1, false)
    end
end

local liveName, liveNode
-- 加载立绘
function this.LoadLive(monsterViewId)
    local liveScale =nil
    local livePos = nil
    if monsterViewId > 10000 then
        local monsterViewInfo = ConfigManager.GetConfigData(ConfigName.HeroConfig, monsterViewId)
        if not monsterViewInfo then return end
        liveName = GetResourcePath(monsterViewInfo.Live)
        liveScale = monsterViewInfo.Scale * _HeroScale
        livePos = Vector3.New(monsterViewInfo.Position[1] + _HeroPosOffset[1], monsterViewInfo.Position[2] + _HeroPosOffset[2], 0)
    else
        local monsterViewInfo = ConfigManager.GetConfigData(ConfigName.MonsterViewConfig, monsterViewId)
        if not monsterViewInfo then return end
        liveName = GetResourcePath(monsterViewInfo.Live)
        liveScale = monsterViewInfo.enemy_liveScale * _MonsterScale
        livePos = Vector3.New(monsterViewInfo.offset[1] + _MonsterPosOffset[1], monsterViewInfo.offset[2] + _MonsterPosOffset[2], 0)
    end

    liveNode = poolManager:LoadLive(liveName, this.liveRoot.transform,
            Vector3.one * liveScale, livePos)

    local SkeletonGraphic = liveNode:GetComponent("SkeletonGraphic")
    local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    poolManager:SetLiveClearCall(liveName, liveNode, function ()
        SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    end)
end

-- 数据匹配
function this.GridAdapter(grid, rewardGroupId)
    if not rewardGroupId then
     
    end
    Util.ClearChild(grid.transform)
    local itemDataList = rewardGroup[rewardGroupId].ShowItem
    if not rewardGroup[rewardGroupId].ShowItem then

    end
    for i = 1, #itemDataList do
        local view = SubUIManager.Open(SubUIConfig.ItemView,grid.transform)
        local item = {itemDataList[i][1], 0}
        view:OnOpen(false, item, 1.1, false)
    end
end

--界面关闭时调用（用于子类重写）
function MonsterShowPanel:OnClose()
    if liveNode then
        poolManager:UnLoadLive(liveName, liveNode)
        liveNode = nil
    end
    canClose = false
end

--界面销毁时调用（用于子类重写）
function MonsterShowPanel:OnDestroy()
    this.monsterList = {}
    if this.panelType == PANEL_TYPE.MONSTER then
        SubUIManager.Close(this.UpView)
        this.UpView = nil
    end
end

return MonsterShowPanel