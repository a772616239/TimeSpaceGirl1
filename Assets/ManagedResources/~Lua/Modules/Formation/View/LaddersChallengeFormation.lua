----- 跨服竞技场 -----
local LaddersChallengeFormation = {}
local this = LaddersChallengeFormation

local hadClick = false

--- 逻辑初始化
function this.Init(root, teamId,challengeUid,challengeRank,myCurrentRank)
    this.root = root
    this.teamId = teamId
    this.challengeUid = challengeUid
    this.challengeRank = challengeRank
    this.myCurrentRank = myCurrentRank
    this.InitView()
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.LADDERS_DEFEND
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end
function this.On_BtnRight_Click()
    if not hadClick then
        hadClick = true
        -- if this.root.order >= 1 then
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
        -- else
        --     PopupTipPanel.ShowTip(GetLanguageStrById(10702))
        --     hadClick = false
        --     return
        -- end
    end
end

-- 初始化界面显示
function this.InitView()
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10743)
    -- if this.root.isSaveTeam then
        this.root.btnRightTxt.text = GetLanguageStrById(10726)
    -- else
    --     this.root.btnRightTxt.text = GetLanguageStrById(10708)
    -- end
    MapManager.isCarbonEnter = false

    hadClick = false

    FormationManager.curFormationIndex = FormationTypeDef.LADDERS_DEFEND
end

-- 开始战斗
function this.StartFight()
    LaddersArenaManager.ExecuteFight(this.teamId,this.challengeUid,this.challengeRank,this.myCurrentRank, function(msg)
        this.root:ClosePanel()
    end)
end

return this