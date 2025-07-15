require("Base/BasePanel")
FightRecordPopup = Inherit(BasePanel)
local this = FightRecordPopup
-- local fightPopup = require("Modules/Fight/FightRecordPopup")
local fightLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local isBattle = true
this.firstData = nil
this.scandData = nil
this.threeData = nil
--初始化组件（用于子类重写）
function FightRecordPopup:InitComponent()
    -- fightPopup:InitComponent(self.gameObject, this)
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "closeBtn")
    this.rewInfo1 = Util.GetGameObject(self.gameObject, "Bg/Grid/RewardInfoGroupPre1")
    this.rewInfo2 = Util.GetGameObject(self.gameObject, "Bg/Grid/RewardInfoGroupPre2")
    this.rewInfo3 = Util.GetGameObject(self.gameObject, "Bg/Grid/RewardInfoGroupPre3")
end

--绑定事件（用于子类重写）
function FightRecordPopup:BindEvent()
    Util.AddClick(this.btnClose,function ()
        UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    end)
    Util.AddClick(this.BackMask,function ()
        UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    end)
end

--添加事件监听（用于子类重写）
function FightRecordPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function FightRecordPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function FightRecordPopup:OnOpen(msg)

    if msg.levelData == nil or msg.levelData[1] == nil then
        this.btnClose = Util.GetGameObject(self.gameObject, "NoPeople"):SetActive(true)
        return
    end
    this.rewInfo1:SetActive(false)
    this.rewInfo2:SetActive(false)
    this.rewInfo3:SetActive(false)
    for key, value in pairs(msg.levelData) do
        if value.dataID ~= nil then
            if value.dataID == 1 then
                this.firstData = value
                this.rewInfo1:SetActive(true)
                -- Util.GetGameObject(this.rewInfo1, "desc"):GetComponent("Text").text=GetLanguageStrById(22291)..GetTimeMaoHaoStrBySeconds(value.playTime)
                Util.GetGameObject(this.rewInfo1, "desc"):GetComponent("Text").text = GetLanguageStrById(22292)..value.curFormationIndex
                Util.GetGameObject(this.rewInfo1, "Name"):GetComponent("Text").text = value.playName
                Util.GetGameObject(this.rewInfo1, "headPos/headIcon"):GetComponent("Image").sprite = GetPlayerHeadSprite(value.headId)
                Util.AddOnceClick(Util.GetGameObject(this.rewInfo1, "GoFightBtn"),function ()
                    if  isBattle  then
                        isBattle = false
                        BattleManager.GotoFight(function()
                            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                            FightRecordPopup.SetFightInfo(value)
                            local fightData = BattleManager.GetBattleServerData({fightData = value.fightData}, 0)
                            fightData.mapName = fightLevelConfig[FightPointPassManager.curOpenFight].BG
                            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                               isBattle = true
                            end)
                            end)
                        end)
                    end
                   
                end)
            end
            if value.dataID == 2 then
                this.scandData = value
                this.rewInfo2:SetActive(true)
                -- Util.GetGameObject(this.rewInfo2, "desc"):GetComponent("Text").text=GetLanguageStrById(22291)..GetTimeMaoHaoStrBySeconds(value.playTime)
                Util.GetGameObject(this.rewInfo2, "desc"):GetComponent("Text").text = GetLanguageStrById(22292)..value.curFormationIndex
                Util.GetGameObject(this.rewInfo2, "Name"):GetComponent("Text").text = value.playName
                Util.GetGameObject(this.rewInfo2, "headPos/headIcon"):GetComponent("Image").sprite = GetPlayerHeadSprite(value.headId)
                Util.AddOnceClick(Util.GetGameObject(this.rewInfo2, "GoFightBtn"),function ()
                    if  isBattle  then
                        isBattle = false
                        BattleManager.GotoFight(function()
                            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                            FightRecordPopup.SetFightInfo(value)
                            local fightData = BattleManager.GetBattleServerData({fightData = value.fightData}, 0)
                            fightData.mapName = fightLevelConfig[FightPointPassManager.curOpenFight].BG
                            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                                isBattle = true
                            end)
                            end)
                        end)
                    end
                end)
            end
            if value.dataID == 3 then
                this.threeData = value
                this.rewInfo3:SetActive(true)
                Util.GetGameObject(this.rewInfo3, "desc"):GetComponent("Text").text = GetLanguageStrById(22292)..value.curFormationIndex
                Util.GetGameObject(this.rewInfo3, "Name"):GetComponent("Text").text = value.playName
                Util.GetGameObject(this.rewInfo3, "headPos/headIcon"):GetComponent("Image").sprite = GetPlayerHeadSprite(value.headId)
                Util.AddOnceClick(Util.GetGameObject(this.rewInfo3, "GoFightBtn"),function ()
                    if  isBattle  then
                        isBattle = false
                        BattleManager.GotoFight(function()
                            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                            FightRecordPopup.SetFightInfo(value)
                            local fightData = BattleManager.GetBattleServerData({fightData = value.fightData}, 0)
                            fightData.mapName = fightLevelConfig[FightPointPassManager.curOpenFight].BG
                            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                                isBattle = true
                            end)
                            end)
                        end)
                    end
                    
                    
                    
                end)
            end
        end
    end
end

function FightRecordPopup.SetFightInfo(sData)
    
    local data = sData
    --> fightInfo
    local structA = {
        head = data.headId,
        headFrame = data.headFrame,
        name = data.playName,
        formationId = data.formationId or 1,
        investigateLevel=data.investigateLevel
    }
    local _monsterGroupId = G_MainLevelConfig[FightPointPassManager.curOpenFight].MonsterGroup
    local monsterShowId = GetMonsterGroupFirstEnemy(_monsterGroupId)
    local heroid = G_MonsterConfig[monsterShowId].MonsterId
    local image = GetResourcePath(G_HeroConfig[heroid].Icon)
    local structB = {
        head = tostring(image),
        headFrame = nil,
        name = nil,
        formationId = G_MonsterGroup[_monsterGroupId].Formation,
        investigateLevel=1
    }
    BattleManager.SetAgainstInfoData(BATTLE_TYPE.BACK, structA, structB)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightRecordPopup:OnShow()
    isBattle = true
end

--界面关闭时调用（用于子类重写）
function FightRecordPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function FightRecordPopup:OnDestroy()

end

return FightRecordPopup