require("Base/BasePanel")
local EliteMonsterPanel = Inherit(BasePanel)
local this = EliteMonsterPanel
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
function EliteMonsterPanel:InitComponent()
    this.btnFight = Util.GetGameObject(self.gameObject, "btnFight")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    -- this.timeTxt = Util.GetGameObject(self.gameObject, "time/time"):GetComponent("Text")
    this.nameTxt = Util.GetGameObject(self.gameObject, "name"):GetComponent("Text")
    this.lvlTxt = Util.GetGameObject(self.gameObject, "lv"):GetComponent("Text")
    this.hpPanel = Util.GetGameObject(self.gameObject, "hp")
    this.hpTxt = Util.GetGameObject(self.gameObject, "hp/hp"):GetComponent("Text")
    this.liveRoot = Util.GetGameObject(self.gameObject, "liveroot")
    this.rewardPanel = Util.GetGameObject(self.gameObject, "reward")
    this.rewardList = Util.GetGameObject(self.gameObject, "reward/rewardlist")
    this.Third = Util.GetGameObject(self.gameObject, "Third")
    this.hpPanel:SetActive(true)
    this.rewardPanel:SetActive(true)
end

--绑定事件（用于子类重写）
function EliteMonsterPanel:BindEvent()
    -- 返回按钮
    Util.AddClick(this.btnBack, function()
        -- 关闭当前界面
        this:ClosePanel()
        -- 副本内，结束事件点触发
        if this._PanelType == 2 then
            Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
        end
    end)

    -- 战斗
    Util.AddClick(this.btnFight, function()
        -- 获取当前精英怪
        local monsterGroupId = EliteMonsterManager.GetMonsterGroupId()
        if not monsterGroupId then
            PopupTipPanel.ShowTipByLanguageId(10474)
            return
        end

        if this._PanelType == 1 then
            -- 副本外，打开编队界面
            UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.ELITE_MONSTER, monsterGroupId, function(result)
                -- 如果赢了或者精英怪已经不在了
                if result == 1 or not EliteMonsterManager.HasEliteMonster() then
                    -- 清空精英怪
                    EliteMonsterManager.ClearEliteMonster()
                    -- 关闭界面
                    this:ClosePanel()
                end
            end)

        elseif this._PanelType == 2 then
            -- 副本里直接通过副本方式进行战斗
            BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.DAILY_CHALLENGE, monsterGroupId)
            MapManager.MapBattleExecute(monsterGroupId, nil, function (result)
                -- 战斗胜利删除地图点
                if result.result == 1 then
                    -- 清空精英怪
                    EliteMonsterManager.ClearEliteMonster()
                    -- 结束事件点触发
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, MapManager.curTriggerPos)
                    Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
                end
                -- Timer.New(
                -- function()
                --                         -- 刷新数据
                --     CarbonManager.InitQuickFightData(monsterGroupId, nil, result)
                -- end,
                -- 0.2
                -- ):Start()
            end)
            this:ClosePanel()
        end
    end)
end

--添加事件监听（用于子类重写）
function EliteMonsterPanel:AddListener()
end

--移除事件监听（用于子类重写）
function EliteMonsterPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function EliteMonsterPanel:OnOpen(panelType, isShowWarning)
    this._PanelType = panelType

    -- 播放强敌来袭特效
    if isShowWarning then
        this.Third:SetActive(true)
        Timer.New(function ()
            this.Third:SetActive(false)
        end, 1.5):Start()
    end
end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function EliteMonsterPanel:OnShow()
    -- 基础信息
    local monsterGroupId = EliteMonsterManager.GetMonsterGroupId()
    if not monsterGroupId then return end

    -- 获取数据
    local monsterId = monsterGroup[monsterGroupId].Contents[1][1]
    local monsterInfo = monsterConfig[monsterId]

    -- 加载立绘
    this.LoadLive(monsterInfo.MonsterId)

    -- 基础内容
    this.lvlTxt.text = "Lv."..monsterInfo.Level
    this.nameTxt.text = GetLanguageStrById(monsterInfo.ReadingName)
    this.hpTxt.text = monsterInfo.Hp

    -- 刷新时间显示
    -- local leftTime = EliteMonsterManager.GetLeftTime()
    -- this.timeTxt:GetComponent("Text").text = TimeToHMS(leftTime)
    -- 开始吧
    this.TimeUpdate()
    if not self._TimeCounter then
        self._TimeCounter = Timer.New(this.TimeUpdate, 1, -1, true)
        self._TimeCounter:Start()
    end

    -- 奖励展示
    local rewardId = monsterGroup[monsterGroupId].Rewardgroup[1]
    this.GridAdapter(this.rewardList, rewardId)

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

    -- liveNode = poolManager:LoadLive(liveName, this.liveRoot.transform,
    --         Vector3.one * liveScale, livePos)

    -- local SkeletonGraphic = liveNode:GetComponent("SkeletonGraphic")
    -- local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    -- SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    -- poolManager:SetLiveClearCall(liveName, liveNode, function ()
    --     SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    -- end)
end

-- update
function this.TimeUpdate()
    -- local leftTime = EliteMonsterManager.GetLeftTime()
    -- this.timeTxt:GetComponent("Text").text = TimeToMS(leftTime)
end

-- 数据匹配
function this.GridAdapter(grid, rewardGroupId)
    Util.ClearChild(grid.transform)
    local itemDataList = rewardGroup[rewardGroupId].ShowItem
    for i = 1, #itemDataList do
        local view = SubUIManager.Open(SubUIConfig.ItemView,grid.transform)
        local item = {itemDataList[i][1], 0}
        view:OnOpen(false, item, 1.1, false)
    end
end

--界面关闭时调用（用于子类重写）
function EliteMonsterPanel:OnClose()
    if liveNode then
        poolManager:UnLoadLive(liveName, liveNode)
        liveNode = nil
    end
    if self._TimeCounter then
        self._TimeCounter:Stop()
        self._TimeCounter = nil
    end
end

--界面销毁时调用（用于子类重写）
function EliteMonsterPanel:OnDestroy()
end

return EliteMonsterPanel