require("Base/BasePanel")
ClimbTowerBattleReportPopup = Inherit(BasePanel)
local this = ClimbTowerBattleReportPopup

--初始化组件（用于子类重写）
function ClimbTowerBattleReportPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "btnClose")

    this.ReportFast = Util.GetGameObject(self.gameObject, "bg/ReportFast")
    this.ReportLowest = Util.GetGameObject(self.gameObject, "bg/ReportLowest")
    this.ReportMine = Util.GetGameObject(self.gameObject, "bg/ReportMine")

    this.ReportMineShareBtn = Util.GetGameObject(self.gameObject, "bg/ReportMine/ShareBtn")
    this.Channel = Util.GetGameObject(self.gameObject, "bg/Channel")
    this.bgClick = Util.GetGameObject(self.gameObject, "bg/Channel/bgClick")
    this.GuildChannel = Util.GetGameObject(self.gameObject, "bg/Channel/GuildChannel")
    this.WorldChannel = Util.GetGameObject(self.gameObject, "bg/Channel/WorldChannel")
    this.TransnationalChannel = Util.GetGameObject(self.gameObject, "bg/Channel/TransnationalChannel")
    
end

--绑定事件（用于子类重写）
function ClimbTowerBattleReportPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.ReportMineShareBtn, function()
        this.Channel:SetActive(true)
    end)

    Util.AddClick(this.bgClick, function()
        this.Channel:SetActive(false)
    end)
    Util.AddClick(this.GuildChannel, function()
        
    end)
    Util.AddClick(this.WorldChannel, function()
        
    end)
    Util.AddClick(this.TransnationalChannel, function()
        
    end)
end

--添加事件监听（用于子类重写）
function ClimbTowerBattleReportPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function ClimbTowerBattleReportPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function ClimbTowerBattleReportPopup:OnOpen(...)
    local args = {...}
    this.towerTier = args[1]
    this.climbTowerType = args[2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerBattleReportPopup:OnShow()
    this.Channel:SetActive(false)


    this.reportDataFast = ClimbTowerManager.GetReportDataByDataId(ClimbTowerManager.ReportId.FastTime)
    this.ReportFast:SetActive(not not this.reportDataFast)
    this.reportDataLowest = ClimbTowerManager.GetReportDataByDataId(ClimbTowerManager.ReportId.LowestPower)
    this.ReportLowest:SetActive(not not this.reportDataLowest)
    this.reportDataMine = ClimbTowerManager.GetReportDataByDataId(ClimbTowerManager.ReportId.Mine)
    this.ReportMine:SetActive(not not this.reportDataMine)

    if this.reportDataFast then
        self:FillReportUI(this.ReportFast, this.reportDataFast, ClimbTowerManager.ReportId.FastTime)
    end
    if this.reportDataLowest then
        self:FillReportUI(this.ReportLowest, this.reportDataLowest, ClimbTowerManager.ReportId.LowestPower)
    end
    if this.reportDataMine then
        self:FillReportUI(this.ReportMine, this.reportDataMine, ClimbTowerManager.ReportId.Mine)
    end
    
end

function ClimbTowerBattleReportPopup:FillReportUI(go, sData, ReportId)
    local headpos = Util.GetGameObject(go, "headBox/headpos")
    local name = Util.GetGameObject(go, "headBox/name"):GetComponent("Text")
    local PassRound = Util.GetGameObject(go, "PassRound"):GetComponent("Text")

    local LookBtn = Util.GetGameObject(go, "LookBtn")
    Util.AddOnceClick(LookBtn, function()
        BattleManager.GotoFight(function()
            local data = sData
            --> fightInfo
            local structA = {
                head = data.headId,
                headFrame = data.headFrame,
                name = data.playName,
                formationId = data.formationId or 1,
                investigateLevel = data.investigateLevel
            }
            --> 此处有climb类型 todo
            local monsterGroupId = nil
            if this.climbTowerType == ClimbTowerManager.ClimbTowerType.Normal then
                monsterGroupId = G_VirtualBattle[this.towerTier].Monster
            end
            local _monsterGroupId = monsterGroupId
            local monsterShowId = GetMonsterGroupFirstEnemy(_monsterGroupId)
            local heroid = G_MonsterConfig[monsterShowId].MonsterId
            local image = GetResourcePath(G_HeroConfig[heroid].Icon)
            local structB = {
                head = tostring(image),
                headFrame = nil,
                name = nil,
                formationId = G_MonsterGroup[_monsterGroupId].Formation,
                investigateLevel = 1
            }
            
            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                BattleManager.SetAgainstInfoData(BATTLE_TYPE.BACK, structA, structB)
                local fightData = BattleManager.GetBattleServerData({fightData = sData.fightData}, 0)
                fightData.mapName = "Map4"
                UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function () end)
            end)
        end)
        
    end)

    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[ReportId] then
        this.playerHead[ReportId] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    this.playerHead[ReportId]:SetHead(sData.headId)
    -- this.playerHead[ReportId]:SetFrame(PlayerManager.frame)

    name.text = sData.playName

    if ReportId == ClimbTowerManager.ReportId.LowestPower then  --< 显示战力
        PassRound.text = string.format(GetLanguageStrById(12521), sData.curFormationIndex)
    else
        PassRound.text = string.format(GetLanguageStrById(12533), sData.playTime or 0)
    end
end

--界面关闭时调用（用于子类重写）
function ClimbTowerBattleReportPopup:OnClose()
    if this.playerHead then
        for _, v in pairs(this.playerHead) do
            v:Recycle()
        end
        this.playerHead = {}
    end
end

--界面销毁时调用（用于子类重写）
function ClimbTowerBattleReportPopup:OnDestroy()

end

return ClimbTowerBattleReportPopup