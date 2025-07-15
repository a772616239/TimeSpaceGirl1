local AdventureFormation = {}
local this = AdventureFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = true

--- 逻辑初始化
function this.Init(root, areaId)
    this.root = root
    this.areaId = areaId
    this.InitView()
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationManager.curFormationIndex
end

--- btn1点击回调事件
function this.On_Btn1_Click()
    -- 编队为空
    if #FormationManager.formationList[FormationManager.curFormationIndex].teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10702)
        return
    end

    -- 获取敌方数据
    local MonsterGroupId = AdventureManager.Data[this.areaId].systemBoss
    local MonsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
    if MonsterGroupId <= 1 or not MonsterGroup[MonsterGroupId] then
        PopupTipPanel.ShowTip(GetLanguageStrById(10706) .. MonsterGroupId .. GetLanguageStrById(10707))
        return
    end

    -- 开始战斗
    FightPointPassManager.oldLevel = PlayerManager.level
    AdventureManager.AdventurnChallengeRequest(this.areaId, this.root.curFormationIndex, 0, function()
        this.root:ClosePanel()
        local triggerCallBack
        triggerCallBack = function (panelType, panel)
            if panelType == UIName.AdventureMainPanel then --监听到AdventureMainPanel重新打开，再抛对应事件，否则接收不到
                if(AdventureManager.fightResult==1) then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.MonsterSayInfo,this.areaId)
                end
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, triggerCallBack)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, triggerCallBack)
    end)
end
--
function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btn_1:SetActive(true)
    this.root.btn_1_lab.text = GetLanguageStrById(10708)
    -- 进入副本显示设置
    MapManager.isCarbonEnter = false

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.AdventureTimes })
end


return this