require("Base/BasePanel")
local GuildBossPanel = Inherit(BasePanel)
local this = GuildBossPanel
local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local monsterViewConfig = ConfigManager.GetConfig(ConfigName.MonsterViewConfig)
local rewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)

-- 英雄
local _HeroPosOffset = {0, -150}  -- 偏移
local _HeroScale = 0.7    -- 缩放
-- 怪物
local _MonsterPosOffset = {0, 0} -- 偏移
local _MonsterScale = 1 -- 缩放


--初始化组件（用于子类重写）
function GuildBossPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    -- this.timeTxt = Util.GetGameObject(self.gameObject, "time/time"):GetComponent("Text")
    -- this.nameTxt = Util.GetGameObject(self.gameObject, "name"):GetComponent("Text")
    -- this.lvlTxt = Util.GetGameObject(self.gameObject, "lv"):GetComponent("Text")
    this.liveRoot = Util.GetGameObject(self.gameObject, "liveroot")
    this.rewardPanel = Util.GetGameObject(self.gameObject, "reward")
    this.rewardList = Util.GetGameObject(self.gameObject, "reward/scroll/Viewport/Content")
    this.rewardPanel:SetActive(true)
    
    -- this.hpPanel = Util.GetGameObject(self.gameObject, "hp")
    -- this.hpTxt = Util.GetGameObject(self.gameObject, "hp/hp"):GetComponent("Text")
    -- this.hpPanel:SetActive(false)
    -- this.Third = Util.GetGameObject(self.gameObject, "Third")

    this.btnLog = Util.GetGameObject(self.transform, "btnLog")
    this.btnReward = Util.GetGameObject(self.transform, "btnReward")
    Util.GetGameObject(self.gameObject, "btnFight"):SetActive(false)


    this.btnFight_1 = Util.GetGameObject(self.transform, "btnFight")
    this.btnBox = Util.GetGameObject(self.transform, "btnbox")
    this.btnFight_2 = Util.GetGameObject(self.transform, "btnbox/btn_1")
    this.btnSweep = Util.GetGameObject(self.transform, "btnbox/btn_2")

    this.countLab = Util.GetGameObject(self.transform, "Count"):GetComponent("Text")

    this.skillRoot = Util.GetGameObject(self.transform, "skillRoot/root")
    this.skillItem = Util.GetGameObject(this.skillRoot, "skill")

    this.btnHelp = Util.GetGameObject(self.transform, "btnHelp")
end

--绑定事件（用于子类重写）
function GuildBossPanel:BindEvent()
    -- 返回按钮
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        -- 关闭当前界面
        this:ClosePanel()
    end)

    -- 奖励界面
    Util.AddClick(this.btnReward, function()
        UIManager.OpenPanel(UIName.GuildBossTipPopup, 1)
    end)
    -- boss伤害排名
    Util.AddClick(this.btnLog, function()
        UIManager.OpenPanel(UIName.GuildBossLogPopup)
    end)
    -- 战斗
    local function fightFunc()
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD_BOSS) then
            PopupTipPanel.ShowTipByLanguageId(10778)
            return
        end
        local leftTimes = GuildBossManager.GetLeftAttackTimes()
        if leftTimes <= 0 then
            PopupTipPanel.ShowTipByLanguageId(11018)
            return 
        end
        UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.GUILD_BOSS)
    end
    Util.AddClick(this.btnFight_1, fightFunc)
    Util.AddClick(this.btnFight_2, fightFunc)

    -- 扫荡
    Util.AddClick(this.btnSweep, function()
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD_BOSS) then
            PopupTipPanel.ShowTipByLanguageId(10778)
            return
        end
        local _, _, usedTimes = GuildBossManager.GetLeftAttackTimes()
        if usedTimes == 0 then
            PopupTipPanel.ShowTipByLanguageId(11020)
            return 
        end
        UIManager.OpenPanel(UIName.GuildBossTipPopup, 2)
    end)

    Util.AddClick(this.btnHelp, function()
        local helpPosition = this.btnHelp:GetComponent("RectTransform").localPosition
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.GuildBoss, helpPosition.x, helpPosition.y)
    end)
end

--添加事件监听（用于子类重写）
function GuildBossPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.GuildBoss.OnBaseDataChanged, this.OnShow, this)
end

--移除事件监听（用于子类重写）
function GuildBossPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildBoss.OnBaseDataChanged, this.OnShow, this)
end

--界面打开时调用（用于子类重写）
function GuildBossPanel:OnOpen()
    -- 检测红点
    GuildBossManager.SetGuildBossChecked()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildBossPanel:OnShow()
    -- 基础信息
    local monsterGroupId = GuildBossManager.GetBossGroupId()
    if not monsterGroupId then return end

    -- 获取数据
    local monsterId = monsterGroup[monsterGroupId].Contents[1][1]
    local monsterInfo = monsterConfig[monsterId]

    -- 加载立绘
    this.LoadLive(monsterInfo.MonsterId)

    -- 基础内容
    -- this.lvlTxt.text = "Lv."..monsterInfo.Level
    -- this.nameTxt.text = monsterInfo.ReadingName
    -- this.hpTxt.text = monsterInfo.Hp

    -- 刷新时间显示
    -- local leftTime = EliteMonsterManager.GetLeftTime()
    -- this.timeTxt:GetComponent("Text").text = TimeToHMS(leftTime)
    -- 开始吧
    -- this.TimeUpdate()
    -- if not self._TimeCounter then
    --     self._TimeCounter = Timer.New(this.TimeUpdate, 1, -1, true)
    --     self._TimeCounter:Start()
    -- end

    -- 奖励展示
    local bossId = GuildBossManager.GetBossId()
    local rewardList = ConfigManager.GetConfigData(ConfigName.GuildBossConfig, bossId).Reward
    this.GridAdapter(this.rewardList, rewardList)

    -- 刷新技能显示
    this.RefreshSkillShow()

    -- 刷新按钮显示
    this.RefreshBtnShow()
end

-- 刷新技能显示
local _PassiveSkillItem = nil
local _SkillItemList = {}
function this.RefreshSkillShow()
    -- 基础信息
    local monsterGroupId = GuildBossManager.GetBossGroupId()
    if not monsterGroupId then return end
    -- 获取数据
    local monsterId = monsterGroup[monsterGroupId].Contents[1][1]
    local monsterInfo = monsterConfig[monsterId]

    -- 被动技能
    if not _PassiveSkillItem then
        _PassiveSkillItem = newObjToParent(this.skillItem, this.skillRoot)
    end
    if monsterInfo and monsterInfo.PassiveSkillList[1] then
        local pSkillId = monsterInfo.PassiveSkillList[1]
        local pSkillData = ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, pSkillId)
        this.SkillItemAdapter(_PassiveSkillItem, pSkillData)
        _PassiveSkillItem:SetActive(true)
    else
        _PassiveSkillItem:SetActive(false)
    end

    -- 主动技能
    local skillIdList = monsterInfo.SkillList
    for index, skillId in ipairs(skillIdList) do
        if not _SkillItemList[index] then
            _SkillItemList[index] = newObjToParent(this.skillItem, this.skillRoot)
        end
        if monsterInfo and monsterInfo.PassiveSkillList[1] then
            local skillData = ConfigManager.GetConfigData(ConfigName.SkillConfig, skillId)
            this.SkillItemAdapter(_SkillItemList[index], skillData)
            _SkillItemList[index]:SetActive(true)
        else
            _SkillItemList[index]:SetActive(false)
        end

    end
end
-- 技能节点数据匹配
function this.SkillItemAdapter(node, data)
    local icon = Util.GetGameObject(node, "icon"):GetComponent("Image")
    icon.sprite = Util.LoadSprite(GetResourcePath(data.Icon or 203011))

    -- 显示技能信息
    Util.AddOnceClick(node, function()
        UIManager.OpenPanel(UIName.MonsterSkillPopup, data)
    end)
end

-- 刷新按钮显示
function this.RefreshBtnShow()
    local leftTimes, allTimes, usedTimes = GuildBossManager.GetLeftAttackTimes()

    this.countLab.text = string.format(GetLanguageStrById(11021), leftTimes, allTimes)

    if usedTimes == 0 then
        this.btnFight_1:SetActive(true)
        Util.SetGray(this.btnFight_1, false)
        Util.GetGameObject(this.btnFight_1, "Text"):GetComponent("Text").text = GetLanguageStrById(10512)

        this.btnFight_2:SetActive(false)
        this.btnSweep:SetActive(false)

    elseif leftTimes == 0 then
        this.btnFight_1:SetActive(true)
        Util.SetGray(this.btnFight_1, true)
        Util.GetGameObject(this.btnFight_1, "Text"):GetComponent("Text").text = GetLanguageStrById(11022)

        this.btnFight_2:SetActive(false)
        this.btnSweep:SetActive(false)

    else
        this.btnFight_1:SetActive(false)
        Util.SetGray(this.btnFight_1, false)

        this.btnFight_2:SetActive(true)
        this.btnSweep:SetActive(true)
        Util.GetGameObject(this.btnFight_2, "btnLab"):GetComponent("Text").text = GetLanguageStrById(10512)
        Util.GetGameObject(this.btnSweep, "btnLab"):GetComponent("Text").text = GetLanguageStrById(11023)
    end

end


local liveName, liveNode
-- 加载立绘
function this.LoadLive(monsterViewId)
    if liveNode then return end
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

-- update
-- function this.TimeUpdate()
--     local leftTime = EliteMonsterManager.GetLeftTime()
--     -- this.timeTxt:GetComponent("Text").text = TimeToMS(leftTime)
-- end

-- 数据匹配
local _ItemViewList = {}
function this.GridAdapter(grid, itemDataList)
    -- Util.ClearChild(grid.transform)
    for _, itemView in ipairs(_ItemViewList) do
        itemView.gameObject:SetActive(false)
    end
    for i = 1, #itemDataList do
        if not _ItemViewList[i] then
            _ItemViewList[i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
        end
        local item = {itemDataList[i][1], 0}
        _ItemViewList[i]:OnOpen(false, item, 1, false)
        _ItemViewList[i].gameObject:SetActive(true)
    end
end

--界面关闭时调用（用于子类重写）
function GuildBossPanel:OnClose()
    if liveNode then
        poolManager:UnLoadLive(liveName, liveNode)
        liveNode = nil
    end
    -- if self._TimeCounter then
    --     self._TimeCounter:Stop()
    --     self._TimeCounter = nil
    -- end
    for _, node in ipairs(_ItemViewList) do
        SubUIManager.Close(node)
    end
    _ItemViewList = {}
end

--界面销毁时调用（用于子类重写）
function GuildBossPanel:OnDestroy()
    _PassiveSkillItem = nil
    _SkillItemList = {}
end

return GuildBossPanel