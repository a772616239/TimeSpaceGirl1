----- 公会副本 -----
local GuildTranscriptFormation = {}
local this = GuildTranscriptFormation
--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false
local hadClick = false
--local GetCurNodeInfo
this.nodeData = {}

--- 逻辑初始化
function this.Init(root, _nodeData)
    this.root = root
    this.nodeData = _nodeData
    this.InitView()
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_NORMAL
end
--- btn1点击回调事件
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
        else
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
            hadClick = false
            return
        end
        -- 编队为空
        if #FormationManager.formationList[FormationTypeDef.FORMATION_NORMAL].teamHeroInfos == 0 then
            PopupTipPanel.ShowTipByLanguageId(10702)
            hadClick = false
            return
        end

        if this.root.isSaveTeam then
            hadClick = false
            PopupTipPanel.ShowTipByLanguageId(10700)
            return
        end

        -- 战斗力判断
        -- GetCurNodeInfo = ExpeditionManager.GetCurNodeInfo()
        --if this.root.formationPower >= this.nodeData.bossTeaminfo.totalForce then
            this.StartFight()
        --else
        --    MsgPanel.ShowTwo("当前队伍战力小于推荐战力，战斗可能会有失败风险。确定是否要继续战斗？", function()
        --        hadClick = false
        --    end, function()
        --        this.StartFight()
        --    end, "取消", "确定"
        --    )
        --end
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

    MapManager.isCarbonEnter = false
    hadClick = false
    -- this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end

-- 开始战斗
function this.StartFight()
   GuildTranscriptManager.GuildChallengeRequest(0,function()
        this.root:ClosePanel()
    end)
end

return this