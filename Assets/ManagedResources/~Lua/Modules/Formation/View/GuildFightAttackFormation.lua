local GuildFightAttackFormation = {}
local this = GuildFightAttackFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false

function this.Init(root, uid)
    this.root = root
    this._memId = uid
    this.InitView()
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK
end
--- 提交按钮点击事件
function this.On_BtnLeft_Click()
    local formation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK)
    if #formation.teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10733)
        return
    end

    local leftCount = GuildFightManager.GetLeftAttackCount()
    if not leftCount or leftCount <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10734)
        return
    end
    BattleManager.GotoFight(function()
        GuildFightManager.RequestAttack(this._memId, function(msg)
            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                -- 进入战斗
                local fightData = BattleManager.GetBattleServerData({fightData = msg.data}, 1)
                local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function()
                    this.root:ClosePanel()
                    UIManager.OpenPanel(UIName.GuildGetStarPopup, msg.starCount)
                end)
                battlePanel:SetResult(msg.result)
            end)
        end)
    end)
end

-- 界面显示刷新
function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10737)

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end

return this