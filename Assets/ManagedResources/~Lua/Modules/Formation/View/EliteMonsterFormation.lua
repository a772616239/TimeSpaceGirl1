local EliteMonsterFormation = {}
local this = EliteMonsterFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = true
--- 逻辑初始化
function this.Init(root, monsterGroupId, func)
    this.root = root
    this.monsterGroupId = monsterGroupId
    this.fightEndCB = func
    this.InitView()
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationManager.curFormationIndex
end
--- btn1点击回调事件
function this.On_BtnLeft_Click()
    -- 编队为空
    if #FormationManager.formationList[FormationManager.curFormationIndex].teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10702)
        return
    end
    -- 怪物正确性检测
    local MonsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
    if this.monsterGroupId <= 1 or not MonsterGroup[this.monsterGroupId] then
        PopupTipPanel.ShowTip(GetLanguageStrById(10706) .. this.monsterGroupId .. GetLanguageStrById(10707))
        return
    end
    this.StartFight()
end

-- 初始化界面显示
function this.InitView()
    this.root.btnLeft:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10708)

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end

-- 开始战斗
function this.StartFight()
    -- 保存当前等级
    FightPointPassManager.oldLevel = PlayerManager.level
    NetManager.RequestFightEliteMonsterOutMap(function(msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.ELITE_MONSTER,
                function(result)
                    this.root:ClosePanel()
                    -- 战斗结束返回
                    if this.fightEndCB then this.fightEndCB(result.result) end
                end)
        end)
    end)
end

return this