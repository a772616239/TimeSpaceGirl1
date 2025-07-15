----- 闪电出击 -----
local BlitzStrikeFormation = {}
local this = BlitzStrikeFormation
-- local VirtualBattle = ConfigManager.GetConfig(ConfigName.VirtualBattle)

local hadClick = false
--- 逻辑初始化
function this.Init(root, fightId)
    this.root = root
    this.fightId = fightId
    this.InitView()
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.BLITZ_STRIKE
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end

function this.On_BtnRight_Click()
    if not hadClick then
        hadClick = true
        if this.root.order >= 1 then
            --保存编队
            FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
            {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
            adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
            nil,
            this.root.choosedFormationId)
            if this.root.isSaveTeam then
                hadClick = false
                PopupTipPanel.ShowTipByLanguageId(10700)
                return
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10702)
            hadClick = false
            return
        end

        this.StartFight()
    end
end

-- 初始化界面显示
function this.InitView()
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10743)
    if this.root.isSaveTeam then
        this.root.btnRightTxt.text = GetLanguageStrById(10726)
    else
        this.root.btnRightTxt.text = GetLanguageStrById(10708)
    end

    hadClick = false
    MapManager.isCarbonEnter = false
    FormationManager.curFormationIndex = FormationTypeDef.BLITZ_STRIKE
end

-- 开始战斗
function this.StartFight()
    local data = BlitzStrikeManager.StageData
    --> fightInfo
    local structA = nil
    local structB = {
        head = data.head,
        headFrame = data.headFrame,
        name = data.name,
        formationId = data.team.formationId or 1,
        investigateLevel = data.investigateLevel
    } 
    BattleManager.SetAgainstInfoData(BATTLE_TYPE.BLITZ_STRIKE, structA, structB)

    BlitzStrikeManager.ExecuteFight(this.fightId, function()
        this.root:ClosePanel()

        if BlitzStrikePreFightPopup then
            BlitzStrikePreFightPopup:ClosePanel()
        end
    end)
end

return this