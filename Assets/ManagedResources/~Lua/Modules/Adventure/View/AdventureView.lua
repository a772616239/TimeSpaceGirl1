AdventureView = {}
require("Base/BasePanel")
local MonsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local RewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local roleEffect = 0
local canStartTime = {}
local boxRedPoint = 0
function AdventureView:New(gameObject, index, data, adventureMainPanel)
    local instance = {}
    instance.gameObject = gameObject
    instance.data = data
    instance.index = index
    instance.adventureMainPanel = adventureMainPanel
    instance.orginLayer = 0
    instance.transform = gameObject.transform
    setmetatable(instance, { __index = AdventureView })
    return instance
end

local NpcAnimDef = {
    idle = { name = "idle", y = 0 },
    moveLeft = { name = "move2", y = 180 },
    moveRight = { name = "move2", y = 0 },
    moveUp = { name = "move3", y = 0 },
    moveDown = { name = "move", y = 0 },
    lauch = { name = "lauch", y = 0 },
    jingya = { name = "jingya", y = 0 },
    touch = { name = "touch", y = 0 },
}

function AdventureView:PlayAnim(anim)
    local SkeletonGraphic = self.npc:GetComponent("SkeletonGraphic")
    SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, anim.y, 0)
    SkeletonGraphic.AnimationState:SetAnimation(0, anim.name, true)
end

function AdventureView:NPCMove(targetX, duration, func)
    local x = self.npc:GetComponent("RectTransform").anchoredPosition.x
    if x < targetX then
        Util.GetGameObject(roleEffect, "reward1Number"):GetComponent("RectTransform").localRotation = Vector3.New(0, 0, 0)
        Util.GetGameObject(roleEffect, "reward2Number"):GetComponent("RectTransform").localRotation = Vector3.New(0, 0, 0)
        self:PlayAnim(NpcAnimDef.moveRight)
    else
        Util.GetGameObject(roleEffect, "reward1Number"):GetComponent("RectTransform").localRotation = Vector3.New(0, 180, 0)
        Util.GetGameObject(roleEffect, "reward2Number"):GetComponent("RectTransform").localRotation = Vector3.New(0, 180, 0)
        self:PlayAnim(NpcAnimDef.moveLeft)
    end
    self.npc:GetComponent("RectTransform"):DOAnchorPosX(targetX, duration):SetEase(Ease.Linear):OnComplete(func)
end
function AdventureView:NPCEmoji(type, duration, func)
    if type == 1 then
        self:PlayAnim(NpcAnimDef.idle)
    elseif type == 2 then
        self:PlayAnim(NpcAnimDef.lauch)
    elseif type == 3 then
        self:PlayAnim(NpcAnimDef.jingya)
    elseif type == 4 then
        self:PlayAnim(NpcAnimDef.touch)
    end
    DoTween           .To(DG.Tweening.Core.DOGetter_float(function()
        return 0
    end), DG.Tweening.Core.DOSetter_float(function()
    end), 0, duration):SetEase(Ease.Linear):OnComplete(func)
    --self.npc:GetComponent("RectTransform"):DOAnchorPosY(0, duration):SetEase(Ease.Linear):OnComplete(func)
end

--
function AdventureView:TestAnim()
    self:NPCEmoji(1, 1, function()
        self:NPCMove(400, math.random(4, 6), function()
            self:NPCEmoji(math.random(1, 4), 1, function()
                self:NPCMove(-400, math.random(4, 6), function()
                    self:TestAnim()
                end)
            end)
        end)
    end)
end

function AdventureView:Init()
    Util.GetGameObject(self.gameObject, "rewardBoxRedPoint"):SetActive(false)
    canStartTime[self.index] = self.index
    roleEffect = poolManager:LoadLive("live2d_npc_map", Util.GetTransform(self.transform, "haveAttackunLock/live2d_npc_map_Parent"),
            Vector3.New(0.26, 0.25, 1), Vector3.New(-250, -120, 0))
    self.npc = roleEffect
    self:TestAnim()
    local effect = poolManager:LoadAsset("UI_effect_TanSuo_BaoXiang", PoolManager.AssetType.GameObject)
    effect.transform:SetParent(Util.GetTransform(self.transform, "haveAttackunLock"))
    effect.transform.localScale = Vector3.New(2, 1.6, 2)
    effect.transform.localPosition = Vector3.New(821, 124, 0)
    effect:SetActive(true)
    Util.GetGameObject(self.transform, "haveAttackunLock/reward1Number").transform:SetParent(roleEffect.transform)
    Util.GetGameObject(self.transform, "haveAttackunLock/reward2Number").transform:SetParent(roleEffect.transform)
    self.rewardBox1 = Util.GetGameObject(effect, "idle1")
    self.rewardBox2 = Util.GetGameObject(effect, "idle2")
    self.rewardBox3 = Util.GetGameObject(effect, "idle3")
    self.hasReward = Util.GetGameObject(effect, "open")
    local headIcon = Util.GetGameObject(self.gameObject, "haveNotAttackunLock/invadeBossQuality/invadeBossIcon"):GetComponent("Image")
    local MonsterGroupId = AdventureManager.Data[self.index].systemBoss
    local monsterId = ConfigManager.GetConfigData(ConfigName.MonsterGroup, MonsterGroupId).Contents[1][1]
    local monsterInfo = ConfigManager.GetConfigData(ConfigName.MonsterConfig, monsterId)
    local heroInfo = ConfigManager.GetConfigData(ConfigName.HeroConfig, monsterInfo.MonsterId)
    -- bossQuality.sprite = Util.LoadSprite(GetQuantityImageByquality(monsterInfo.Quality))
    if heroInfo then
        headIcon.sprite = Util.LoadSprite(GetResourcePath(heroInfo.Icon))
    end
    Util.AddOnceClick(Util.GetGameObject(self.gameObject, "haveAttackunLock/upLevelBtn"), function()
        RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. self.data.areaName .. self.data.areaLevel, 1)
        UIManager.OpenPanel(UIName.AdventureUpLevelPanel, self.index)
        CheckRedPointStatus(RedPointType.SecretTer_Uplevel)
    end)
    Util.AddOnceClick(Util.GetGameObject(self.gameObject, "haveAttackunLock/bossAppear/bossAppearbtn"), function()
        RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. self.data.areaName, 1)
        ResetServerRedPointStatus(RedPointType.SecretTer_Boss)
        UIManager.OpenPanel(UIName.AdventureAlianInvasionPanel)
    end)
    Util.AddOnceClick(Util.GetGameObject(self.gameObject, "haveNotAttackunLock/invadeBossQuality/invadeBossIcon"), function()
        UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.ADVENTURE, self.index)
        --AdventureManager.isAttackBoosSuccess[i]=true
    end)

    Util.AddOnceClick(self.rewardBox1, function()
        Util.GetGameObject(self.adventureMainPanel.transform, "btnBack"):GetComponent("Button").enabled = false
        AdventureManager.Data[self.index].stateTime = 0
        self.hasReward:SetActive(true)
        self.timerEffect = Timer.New(function()
            self.hasReward:SetActive(false)
            AdventureManager.GetAventureRewardRequest(2, self.index, false, false)
            self.timerEffect:Stop()
            Util.GetGameObject(self.adventureMainPanel.transform, "btnBack"):GetComponent("Button").enabled = true
        end, 1.5, -1, true)
        self.timerEffect:Start()

    end)
    Util.AddOnceClick(self.rewardBox2, function()
        Util.GetGameObject(self.adventureMainPanel.transform, "btnBack"):GetComponent("Button").enabled = false
        AdventureManager.Data[self.index].stateTime = 0
        self.hasReward:SetActive(true)
        self.timerEffect = Timer.New(function()
            self.hasReward:SetActive(false)
            AdventureManager.GetAventureRewardRequest(2, self.index, false, false)
            self.timerEffect:Stop()
            Util.GetGameObject(self.adventureMainPanel.transform, "btnBack"):GetComponent("Button").enabled = true
        end, 1.5, -1, true)
        self.timerEffect:Start()
    end)
    Util.AddOnceClick(self.rewardBox3, function()
        Util.GetGameObject(self.adventureMainPanel.transform, "btnBack"):GetComponent("Button").enabled = false
        AdventureManager.Data[self.index].stateTime = 0
        self.hasReward:SetActive(true)
        self.timerEffect = Timer.New(function()
            AdventureManager.GetAventureRewardRequest(2, self.index, false, false)
            self.hasReward:SetActive(false)
            self.timerEffect:Stop()
            Util.GetGameObject(self.adventureMainPanel.transform, "btnBack"):GetComponent("Button").enabled = true
        end, 1.5, -1, true)
        self.timerEffect:Start()
    end)
    --self.timer = Timer.New(function()
    --    Util.GetGameObject(roleEffect, "reward1Number"):GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 536.8)
    --    Util.GetGameObject(roleEffect, "reward2Number"):GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 536.8)
    --    Util.GetGameObject(roleEffect, "reward1Number"):SetActive(true)
    --    Util.GetGameObject(roleEffect, "reward1Number"):GetComponent("RectTransform"):DOAnchorPosY(800, 1):SetEase(Ease.Linear):OnComplete(function()
    --        Util.GetGameObject(roleEffect, "reward1Number"):SetActive(false)
    --        Util.GetGameObject(roleEffect, "reward2Number"):SetActive(true)
    --        Util.GetGameObject(roleEffect, "reward2Number"):GetComponent("RectTransform"):DOAnchorPosY(800, 1):SetEase(Ease.Linear):OnComplete(function()
    --            Util.GetGameObject(roleEffect, "reward2Number"):SetActive(false)
    --        end)
    --    end)
    --end, 60, -1, true)
    --self.timer:Start()
end

function AdventureView:Close()
    self.timer1:Stop()
end

function AdventureView:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.rewardBox1, self.adventureMainPanel.sortingOrder - self.orginLayer)
    Util.AddParticleSortLayer(self.rewardBox2, self.adventureMainPanel.sortingOrder - self.orginLayer)
    Util.AddParticleSortLayer(self.rewardBox3, self.adventureMainPanel.sortingOrder - self.orginLayer)
    Util.AddParticleSortLayer(self.hasReward, self.adventureMainPanel.sortingOrder - self.orginLayer)
    self.orginLayer = self.adventureMainPanel.sortingOrder
end

function AdventureView:OnRefreshData()
    if (self.data.areaLevel ~= 3) then
        if (PlayerManager.level >= self.data.OpenLevel[self.data.areaLevel + 1]) then
            Util.GetGameObject(self.gameObject, "haveAttackunLock/upLevelBtn"):SetActive(true)
        else
            Util.GetGameObject(self.gameObject, "haveAttackunLock/upLevelBtn"):SetActive(false)
            Util.GetGameObject(self.gameObject, "haveAttackunLock/upLevelRedPoint"):SetActive(false)
        end
    end
    if (self.data.areaLevel == 3) then
        Util.GetGameObject(self.gameObject, "haveAttackunLock/upLevelBtn"):SetActive(false)
    end
    if (AdventureManager.adventureStateInfoList1[self.index] ~= nil) then
        Util.GetGameObject(self.gameObject, "Image4"):SetActive(true)
        Util.GetGameObject(self.gameObject, "Image4/Text"):GetComponent("Text").text = self.data.areaName
        Util.GetGameObject(self.gameObject, "Image4/levelText"):GetComponent("Text").text = self.data.areaLevel .. GetLanguageStrById(10072)
        self.data.isAttackBoosSuccess = 1
        --self.data.areaLevel=AdventureManager.adventureStateInfoList[i].level
    else
        Util.GetGameObject(self.gameObject, "Image4/Text"):GetComponent("Text").text = ""
        Util.GetGameObject(self.gameObject, "Image4/levelText"):GetComponent("Text").text = ""
    end

    --等级达到区域解锁要求但未击败Boss的状态
    if (PlayerManager.level >= self.data.OpenLevel[1]) then
        Util.GetGameObject(self.gameObject, "haveNotAttackunLock/redPoint"):SetActive(true)
        Util.GetGameObject(self.gameObject, "haveAttackunLock"):SetActive(false)
        Util.GetGameObject(self.gameObject, "haveNotAttackunLock"):SetActive(true)
        Util.GetGameObject(self.gameObject, "lock"):SetActive(false)
        local bosssName = GetLanguageStrById(MonsterConfig[MonsterGroup[self.data.systemBoss].Contents[1][1]].ReadingName)
        --local bosssName=MonsterConfig[bossId].ReadingName
        local boosLevel = MonsterConfig[MonsterGroup[self.data.systemBoss].Contents[1][1]].Level
        Util.GetGameObject(self.gameObject, "haveNotAttackunLock/bossBgImage/bossNameText"):GetComponent("Text").text = GetLanguageStrById(10074) .. string.format("<color=#F5C66CFF>%s</color>", bosssName) .. GetLanguageStrById(10075)
        Util.GetGameObject(self.gameObject, "haveNotAttackunLock/invadeBossQuality/Image/Text"):GetComponent("Text").text = boosLevel
    end
    --等级达到区域解锁要求并成功击败Boss的状态
    if (PlayerManager.level >= self.data.OpenLevel[1] and self.data.isAttackBoosSuccess == 1) then
        Util.GetGameObject(self.gameObject, "haveAttackunLock"):SetActive(true)
        Util.GetGameObject(self.gameObject, "haveNotAttackunLock"):SetActive(false)
        Util.GetGameObject(self.gameObject, "lock"):SetActive(false)
        Util.GetGameObject(self.gameObject, "Image4/Text"):GetComponent("Text").text = self.data.areaName
        Util.GetGameObject(self.gameObject, "Image4/levelText"):GetComponent("Text").text = self.data.areaLevel .. GetLanguageStrById(10072)
        local reward1Name = GetLanguageStrById(itemConfig[RewardGroup[self.data.baseRewardGroup[1][self.data.areaLevel]].ShowItem[1][1]].Name)
        local reward2Name = GetLanguageStrById(itemConfig[RewardGroup[self.data.baseRewardGroup[1][self.data.areaLevel]].ShowItem[2][1]].Name)

        local reward1Number = RewardGroup[self.data.baseRewardGroup[1][self.data.areaLevel]].ShowItem[1][2]
        local reward2Number = RewardGroup[self.data.baseRewardGroup[1][self.data.areaLevel]].ShowItem[2][2]

        Util.GetGameObject(roleEffect, "reward1Number/Text"):GetComponent("Text").text = GetLanguageStrById(10076) .. reward1Name .. "×" .. reward1Number
        Util.GetGameObject(roleEffect, "reward2Number/Text"):GetComponent("Text").text = GetLanguageStrById(10076) .. reward2Name .. "×" .. reward2Number
        --进入游戏时宝箱状态和外敌状态的控制
        if (AdventureManager.adventureStateInfoList1[self.index] ~= nil) then
            if (AdventureManager.adventureStateInfoList1[self.index].adventureBossSimpleInfo[1] ~= nil and self.data.bossRemainTime > 0) then
                Util.GetGameObject(self.gameObject, "haveAttackunLock/bossAppear"):SetActive(true)
            end
        end
    end
    if (PlayerManager.level < self.data.OpenLevel[1]) then
        Util.GetGameObject(self.gameObject, "haveAttackunLock"):SetActive(false)
        Util.GetGameObject(self.gameObject, "haveNotAttackunLock"):SetActive(false)
        Util.GetGameObject(self.gameObject, "lock"):SetActive(true)
        Util.GetGameObject(self.gameObject, "lock/unLockLevelText"):GetComponent("Text").text = ""
    end
end

function AdventureView:SetRewordBoxStatus(index, i)
    if (index == 1) then
        self.rewardBox1:SetActive(false)
        self.rewardBox2:SetActive(true)
        self.rewardBox3:SetActive(false)
    elseif (index == 2) then
        self.rewardBox1:SetActive(false)
        self.rewardBox2:SetActive(false)
        self.rewardBox3:SetActive(true)
    elseif (index == 3) then
        self.rewardBox1:SetActive(true)
        self.rewardBox2:SetActive(false)
        self.rewardBox3:SetActive(false)
    elseif (index == 4) then
        self.rewardBox1:SetActive(false)
        self.rewardBox2:SetActive(false)
        self.rewardBox3:SetActive(false)

    end
    if (index == 5) then
        Util.GetGameObject(self.gameObject, "rewardBoxRedPoint"):SetActive(true)
    else
        Util.GetGameObject(self.gameObject, "rewardBoxRedPoint"):SetActive(false)
    end
end
function AdventureView:UpdataBossShowState(i)
    local isCanShowUpLevelPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. self.data.areaName .. self.data.areaLevel)
    if (self.data.areaLevel ~= 3) then
        if (isCanShowUpLevelPoint == "0" and PlayerManager.level >= self.data.OpenLevel[self.data.areaLevel + 1]) then
            Util.GetGameObject(self.gameObject, "haveAttackunLock/upLevelRedPoint"):SetActive(true)
        else
            Util.GetGameObject(self.gameObject, "haveAttackunLock/upLevelRedPoint"):SetActive(false)
        end
    else
        Util.GetGameObject(self.gameObject, "haveAttackunLock/upLevelRedPoint"):SetActive(false)
    end
    local isCanShowBossPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. self.data.areaName)
    --外敌Boss出现的状态
    if (self.data.bossRemainTime <= 0) then
        if (#self.data.adventureBossRemaindTimeArray > 1) then
            table.remove(self.data.adventureBossRemaindTimeArray, 1)
            self.data.bossRemainTime = self.data.adventureBossRemaindTimeArray[1]
            --self.data.durationTime=self.data.adventureBossRemaindTimeArray[1]
        end
        Util.GetGameObject(self.gameObject, "haveAttackunLock/bossAppear"):SetActive(false)
       -- Util.GetGameObject(self.gameObject, "haveAttackunLock/bossAppear/alienInvasionRedPoint"):SetActive(false)
        RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. self.data.areaName, 0)
    elseif (self.data.bossRemainTime > 0 and isCanShowBossPoint == "0") then
        Util.GetGameObject(self.gameObject, "haveAttackunLock/bossAppear"):SetActive(true)
        --Util.GetGameObject(self.gameObject, "haveAttackunLock/bossAppear/alienInvasionRedPoint"):SetActive(true)
        --self.adventureMainPanel.alienInvasionRedPoint:SetActive(true)
    elseif (self.data.bossRemainTime > 0 and isCanShowBossPoint ~= "0") then
        --Util.GetGameObject(self.gameObject, "haveAttackunLock/bossAppear/alienInvasionRedPoint"):SetActive(false)
    end
end

function AdventureView:UpdataRewardPopUpState(i)


end

return AdventureView