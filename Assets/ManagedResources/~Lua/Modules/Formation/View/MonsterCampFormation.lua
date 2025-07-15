----- 锁妖塔 -----
local MonsterCampFormation = {}
local this = MonsterCampFormation
local monsterCampConfig = ConfigManager.GetConfig(ConfigName.FloodConfig)

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false

--- 逻辑初始化
function this.Init(root)
    this.root = root
    this.InitView()
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.MONSTER_CAMP_ATTACK
end

--- btn1点击回调事件
function this.On_BtnLeft_Click()
    if this.root.order >= 1 then
        --保存编队
        FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
            FormationManager.formationList[this.root.curFormationIndex].teamPokemonInfos,nil,
            FormationManager.formationList[this.root.curFormationIndex].formationId)
    else
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
        return
    end

    -- 判断编队
    if #FormationManager.formationList[FormationTypeDef.FORMATION_NORMAL].teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10702)
        return
    end

    -- 判断是否够那个啥
    -- local itemNum = BagManager.GetItemCountById(53) 
    -- if itemNum <= 0 then
    --    -- PopupTipPanel.ShowTip("道具不足，请购买!")
    --     UIManager.OpenPanel(UIName.QuickPurchasePanel,{ type = UpViewRechargeType.MonsterCampTicket })
    --     return
    -- end

    this.StraightBattle()
end

function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    -- this.root.failText:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10709)

    -- local costTip = this.root.costTip
    -- costTip:SetActive(true)
    -- costTip.transform:SetParent(this.root.btn_1.transform)
    -- costTip.transform.localPosition = Vector3.New(0, -60, 0)
    -- Util.GetGameObject(costTip, "vigorImage"):SetActive(false)
    -- Util.GetGameObject(costTip, "vigorNum"):SetActive(false)
    -- Util.GetGameObject(costTip, "text2"):SetActive(true)

    -- local icon = Util.GetGameObject(costTip, "actionImage")
    -- local num = Util.GetGameObject(costTip, "actionNum")
    -- icon:SetActive(true)
    -- num:SetActive(true)
    -- -- 消耗数量
    -- Util.GetGameObject(costTip, "text2"):GetComponent("Text").text = "消耗"
    -- icon:GetComponent("Image").sprite = SetIcon(53)
    -- num:GetComponent("Text").text = "×" .. 1

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.MonsterCamp })
end

function this.StartFight()
    local isSkip = MonsterCampManager.GetBattleJump()
    if not isSkip then
        this.StraightBattle()
    else
        -- 请求战斗结果
        NetManager.GetMonsterFightResult(MonsterCampManager.monsterWave, FormationTypeDef.FORMATION_NORMAL, function (msg)
            if msg.result == 0 then
                UIManager.OpenPanel(UIName.BattleFailPopup, nil, false, UIName.MonsterCampPanel)
            else
                local result = {}
                result.drop = msg.enventDrop
                UIManager.OpenPanel(UIName.BattleWinPopup, nil, false, 5, result, true, true)
                MonsterCampManager.monsterWave = MonsterCampManager.monsterWave + 1
            end
        end)
    end
end

function this.StraightBattle()
    local MonsterGroupId = monsterCampConfig[MonsterCampManager.monsterWave].Monster
    NetManager.RequestMonsterCampFight(MonsterCampManager.monsterWave, function (msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.MONSTER_CAMP, function (result)
                if result.result == 0 then

                else
                    MonsterCampManager.monsterWave = MonsterCampManager.monsterWave + 1
                end

                -- 返回那个界面
                UIManager.OpenPanel(UIName.MonsterCampPanel)
            end)
        end)
    end)
end

return this