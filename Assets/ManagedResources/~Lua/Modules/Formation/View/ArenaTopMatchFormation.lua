local ArenaAttackFormation = {}
local this = ArenaAttackFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false
--不能上下阵  为true时 编队不能上下阵
-- this.ChangeFormation = false
local hadClick = false

function this.Init(root, closeFunc)
    this.root = root
    this.closeFunc = closeFunc
    this.InitView()
end

-- 界面显示刷新
function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10743)
    this.root.btnRightTxt.text = GetLanguageStrById(10726)

    hadClick = false
    -- 没开启或者开启没参赛都属于未参赛
    local isOpen = ArenaTopMatchManager.IsTopMatchActive()
    local baseData = ArenaTopMatchManager.GetBaseData()
    local isOver = baseData.progress == -2
    --1准备阶段 3战斗阶段
    if isOpen and not isOver then
        if baseData.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS
            or baseData.battleState == TOP_MATCH_TIME_STATE.OVER
            or baseData.battleState == TOP_MATCH_TIME_STATE.CLOSE
            or baseData.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_READY then
            this.ChangeFormation = true
        else
            this.ChangeFormation = false
        end
    else
        this.ChangeFormation = true
    end
end

-- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.ARENA_TOM_MATCH
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end
-- 提交按钮点击事件
function this.On_BtnRight_Click()
    if not this.ChangeFormation then
        PopupTipPanel.ShowTipByLanguageId(12555)
        return
    end
    --保存编队
    if not hadClick then
        hadClick = true
        if this.root.order >= 1 then
            --保存编队
            FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
                --[[FormationManager.formationList[this.root.curFormationIndex].teamPokemonInfos]]
                 {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
                  adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)}
                ,nil,
                this.root.choosedFormationId)
                -- this.OnCloseBtnClick()
        else
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
            hadClick = false
            return
        end
        -- 编队为空
        if #FormationManager.formationList[FormationTypeDef.ARENA_TOM_MATCH].teamHeroInfos == 0 then
            PopupTipPanel.ShowTipByLanguageId(10702)
            hadClick = false
            return
        end

        if this.root.isSaveTeam then
            hadClick = false
            PopupTipPanel.ShowTipByLanguageId(10700)
            return
        end
        this.OnCloseBtnClick()
    end
end

-- 返回按钮点击事件
function this.OnCloseBtnClick()
    this.root:ClosePanel()
    if this.closeFunc then
        this.closeFunc()
    end
end

return this