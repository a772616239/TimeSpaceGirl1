local AdventureBossFormation = {}
local this = AdventureBossFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = true

--- 逻辑初始化
function this.Init(root, bossData)
    this.root = root
    this.bossData = bossData
    this.InitView()
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationManager.curFormationIndex
end

--- btn1点击回调事件
function this.On_BtnLeft_Click()
    if #FormationManager.formationList[FormationManager.curFormationIndex].teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10702)
        return
    end
    if AdventureManager.IsEnemyKilled(this.bossData.bossId) then
        PopupTipPanel.ShowTipByLanguageId(10703)
        return
    end

    -- 判断物品是否足够
    if BagManager.GetItemCountById(UpViewRechargeType.AdventureAlianInvasionTicket) < 1 then
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.AdventureAlianInvasionTicket })
        return
    end

    -- 判断是否符合跳过战斗的条件
    local isSkip = this.root.passBattle0:GetComponent("Toggle").isOn and 1 or 0
   
    if isSkip == 1 and not AdventureManager.IsUnlockBattlePass() then
        PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.SkipFight))
        --PopupTipPanel.ShowTip("特权等级不足，无法跳过战斗！")
        PlayerPrefs.SetInt(PlayerManager.uid.."PassBattle0_Toggle_IsOn",1)
        return
    end

    --- 开始战斗
    AdventureManager.GetAdventurenBossChallengeRequest(this.bossData, this.root.curFormationIndex, 1, isSkip, function(fightResult)
        -- 成功击杀关闭编队界面
        if fightResult == 1 then
            this.root:ClosePanel()
        end
    end)
end
--- btn2点击回调事件
function this.On_BtnRight_Click()
    -- 判断编队
    if #FormationManager.formationList[FormationManager.curFormationIndex].teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10702)
        return
    end
    if AdventureManager.IsEnemyKilled(this.bossData.bossId) then
        PopupTipPanel.ShowTipByLanguageId(10703)
        return
    end

    -- 判断挑战券是否足够
    if BagManager.GetItemCountById(UpViewRechargeType.AdventureAlianInvasionTicket) < 5 then
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.AdventureAlianInvasionTicket })
        return
    end

    -- 判断是否可以快速挑战5次
    if not AdventureManager.IsUnlockBattlePass() then
        PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.SkipFight))
        --PopupTipPanel.ShowTip("特权等级不足，无法挑战五次！")
        return
    end

    -- 开始挑战
    AdventureManager.GetAdventurenBossChallengeRequest(this.bossData, this.root.curFormationIndex, 5, 1, function(fightResult)
        -- 成功击杀关闭编队界面
        if fightResult == 1 then
            this.root:ClosePanel()
        end
    end)
end

--- passBattle点击回调事件
-- function this.On_PassBattle0_Click()
--     local isSkip = this.root.passBattle0:GetComponent("Toggle").isOn and 1 or 0
--     if isSkip == 0 then
--         PlayerPrefs.SetInt(PlayerManager.uid.."PassBattle0_Toggle_IsOn",0)
--     else
--         PlayerPrefs.SetInt(PlayerManager.uid.."PassBattle0_Toggle_IsOn",1)
--     end
--     --if not AdventureManager.IsUnlockBattlePass() then
--     --    PopupTipPanel.ShowTip("特权等级不足，无法跳过战斗！")
--     --end
-- end
--
function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(true)
    this.root.btnRight:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10704)
    this.root.btnRightTxt.text = GetLanguageStrById(10705)

    if not AdventureManager.IsUnlockBattlePass() then--如果不是特权
        -- this.root.passBattle0:SetActive(false)
        -- this.root.passBattle0:GetComponent("Toggle").isOn = false

        -- this.root.passBattle1:SetActive(true)
        --- 显示跳过战斗属性·
        --this.root.passBattle0:SetActive(true)
        -- this.root.passBattle1.transform:SetParent(this.root.btn_1.transform)
        -- this.root.passBattle1.transform.localPosition = Vector3.New(0, -80, 0)
        Util.AddOnceClick(this.root.passBattle1,function ()
            PopupTipPanel.ShowTip((PRIVILEGE_TYPE.SkipFight))
           -- PopupTipPanel.ShowTip("特权等级不足，无法跳过战斗！")
        end)
    else
        -- this.root.passBattle1:SetActive(false)
        -- this.root.passBattle0:SetActive(true)

        if not PlayerPrefs.HasKey(PlayerManager.uid.."PassBattle0_Toggle_IsOn") then--检查注册表是否存在该键
            PlayerPrefs.SetInt(PlayerManager.uid.."PassBattle0_Toggle_IsOn",1)
        end

        if PlayerPrefs.GetInt(PlayerManager.uid.."PassBattle0_Toggle_IsOn") == 1 then
            -- this.root.passBattle0:GetComponent("Toggle").isOn = true
        else
            -- this.root.passBattle0:GetComponent("Toggle").isOn = false
        end
        -- this.root.passBattle0.transform:SetParent(this.root.btn_1.transform)
        -- this.root.passBattle0.transform.localPosition = Vector3.New(0, -80, 0)
    end

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.AdventureTimes })
end

return this