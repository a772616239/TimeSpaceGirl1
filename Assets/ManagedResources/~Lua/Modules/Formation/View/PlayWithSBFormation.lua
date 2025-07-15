----- 好友切磋 -----
local PlayWithSBFormation = {}
local this = PlayWithSBFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = true

function this.Init(root, uid, tname, _teamInfo)
    this.root = root
    this.uid = uid
    this.tname = tname
    this.teamInfo = _teamInfo
    this.InitView()
end

-- 界面显示刷新
function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10742)
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationManager.curFormationIndex
end
--- 提交按钮点击事件
function this.On_BtnLeft_Click()
    if this.root.order>= 1 then
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

    --> fightInfo
    local structA = nil
    local structB = {
        head = this.teamInfo.head,
        headFrame = this.teamInfo.headFrame,
        name = this.teamInfo.name,
        formationId = this.teamInfo.teamFormation or 1,
        investigateLevel = this.teamInfo.investigateLevel
    }
    BattleManager.SetAgainstInfoData(BATTLE_TYPE.BACK, structA, structB)

    -- 请求开始挑战
    PlayerManager.RequestPlayWithSomeOne(this.uid, FormationTypeDef.FORMATION_NORMAL, this.tname, function()
        this.root:ClosePanel()
    end)
end

return this