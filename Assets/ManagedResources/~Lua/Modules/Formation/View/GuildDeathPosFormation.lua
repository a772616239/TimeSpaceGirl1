----- 公会战 -----
local GuildDeathPosFormation = {}
local this = GuildDeathPosFormation
local guildWarConfig = ConfigManager.GetConfig(ConfigName.GuildWarConfig)
local curIndex = 0 --当前阵索引
local name, formationId
local inBattle

--- 逻辑初始化
function this.Init(root,...)
    local args = {...}
    curIndex = args[1]
    this.root = root
    this.root.bg:SetActive(true)
    this.InitView()

    name = args[2]
    formationId = args[3]
    inBattle = false
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_NORMAL
end

--- 关闭界面事件
function this.OnCloseBtnClick()
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    this.root:ClosePanel()
end

function this.InitView()
    this.root.btnLeft:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10743)
    this.root.btnRight:SetActive(true)
    if this.root.isSaveTeam then
        this.root.btnRightTxt.text = GetLanguageStrById(10726)
    else
        this.root.btnRightTxt.text = GetLanguageStrById(10708)
    end
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end

function this.On_BtnRight_Click()
    if ActTimeCtrlManager.FuncTimeJudge(FUNCTION_OPEN_TYPE.GUILD_BATTLE) then
        if PlayerManager.familyId == 0 then--没有公会
            PopupTipPanel.ShowTip(GetLanguageStrById(10405))
            return
        end
    else
        PopupTipPanel.ShowTip(GetLanguageStrById(10550)..GetLanguageStrById(12731))
        return
    end

    if this.root.order >= 1 then
        --保存编队
        FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
        {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
        adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
        nil,
        this.root.choosedFormationId)
    else
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
        return
    end
    if this.root.isSaveTeam then
        PopupTipPanel.ShowTipByLanguageId(10700)
        return
    end
    if BattleManager.IsInBackBattle() then
        return
    end
    if inBattle then
        return
    end
    inBattle = true
    NetManager.ChallengeDeathPathRequest(curIndex, function(msg)
        local structA = {
            head = PlayerManager.head,
            headFrame = PlayerManager.headFrame,
            name = PlayerManager.nickName,
            formationId = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_NORMAL).formationId,
            investigateLevel = FormationCenterManager.GetInvestigateLevel()
        }
        local structB = {
            head = nil,
            headFrame = nil,
            name = name,
            formationId = formationId,
            investigateLevel = 1,
        }
        BattleManager.SetAgainstInfoData(BATTLE_TYPE.BACK, structA, structB)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg)
            GuildBattleManager.drop = msg.drop
            GuildBattleManager.damage = msg.damage
            GuildBattleManager.historyMax = msg.historyMax
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.DEATH_POS, function()
                GuildBattleManager.challengeCount = GuildBattleManager.challengeCount + 1
                if GuildBattleManager.challengeCount < 0 then
                    GuildBattleManager.challengeCount = 0
                end
                this.root:ClosePanel()
                PopupTipPanel.ShowTipByLanguageId(10732)
            end)
        end)
    end)
end

return this