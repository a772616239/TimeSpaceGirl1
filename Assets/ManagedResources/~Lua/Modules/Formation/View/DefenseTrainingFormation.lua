----- 防守训练 -----
local DefenseTrainingFormation = {}
local this = DefenseTrainingFormation
-- local VirtualBattle = ConfigManager.GetConfig(ConfigName.VirtualBattle)

local hadClick = false
--- 逻辑初始化
function this.Init(root, fightId)
    this.root = root
    this.fightId = fightId
    this.InitView()
    this.ChangeFormation = true
    if DefenseTrainingManager.teamLock then--此功能只能上阵一次 需重置解除
        this.ChangeFormation = not (DefenseTrainingManager.teamLock == 1)
    end
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.DEFENSE_TRAINING
end

function this.On_BtnLeft_Click()
    this.root.SetOneKeyGo()
end

function this.On_BtnRight_Click()
    if not this.ChangeFormation then
        return
    end
    if not hadClick then
        hadClick = true
        if this.root.order >= 1 then
            if DefenseTrainingManager.teamLock == 0 then--可编队状态保存
                --保存编队
                FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
                {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
                adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
                nil,
                this.root.choosedFormationId)
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
    this.root.btnRightTxt.text = GetLanguageStrById(10708)
    MapManager.isCarbonEnter = false

    -- local costTip = this.root.costTip
    -- costTip:SetActive(false)
    hadClick = false

    FormationManager.curFormationIndex = FormationTypeDef.DEFENSE_TRAINING
end

-- 开始战斗
function this.StartFight()
    -- if this.fightId%5 == DefenseTrainingManager.todayStartFightId%5 and DefenseTrainingManager.curBuffId == 0 then
    --     UIManager.OpenPanel(UIName.DefenseTrainingBuffPopup, this.fightId)
    --     this.root:ClosePanel()
    -- else
    --     DefenseTrainingManager.ExecuteFight(this.fightId, function()
    --         this.root:ClosePanel()
    --     end)
    -- end
    DefenseTrainingManager.ExecuteFightBefore(this.root)
end

return this