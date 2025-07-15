local ArenaAttackFormation = {}
local this = ArenaAttackFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false

function this.Init(root, enemyIndex)
    this.root = root
    this.enemyIndex = enemyIndex
    this.InitView()
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_ARENA_ATTACK
end
--- 提交按钮点击事件
function this.On_BtnLeft_Click()
    local isSkip = 0--ArenaManager.IsSkipFight() and 1 or 0
    if this.root.order >= 1 then
        --保存编队
        FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
        FormationManager.formationList[this.root.curFormationIndex].teamPokemonInfos)
    else
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10701), 1))
        return
    end
    -- 请求开始挑战
    ArenaManager.RequestArenaChallenge(this.enemyIndex, isSkip, function()
        this.root:ClosePanel()
    end)
end

--- passBattle点击回调事件
function this.On_PassBattle0_Click(isOn)
    ArenaManager.SetIsSkipFight(isOn)
end
-- 界面显示刷新
function this.InitView()
    this.root.bg:SetActive(true)
    this.root.btnLeft:SetActive(this.enemyIndex > 0)
    this.root.btnLeftTxt.text = GetLanguageStrById(10709)

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Arena })

    -- local costTip = this.root.costTip
    -- costTip:SetActive(this.enemyIndex > 0)
    -- costTip.transform:SetParent(this.root.btn_1.transform)
    -- costTip.transform.localPosition = Vector3.New(0, -60, 0)
    -- Util.GetGameObject(costTip, "vigorImage"):SetActive(false)
    -- Util.GetGameObject(costTip, "vigorNum"):SetActive(false)
    -- local tip = Util.GetGameObject(costTip, "text2")
    -- local itemIcon = Util.GetGameObject(costTip, "actionImage")
    -- local itemNumLab = Util.GetGameObject(costTip, "actionNum")
    -- tip:SetActive(true)
    -- itemIcon:SetActive(true)
    -- itemNumLab:SetActive(true)

    --- 根据传入的下标隐藏某些东东
    if this.enemyIndex > 0 then
        --- 显示跳过战斗属性
        -- if ArenaManager.CheckSkipFight() then
        --     this.root.passBattle0:SetActive(true)
        --     this.root.passBattle0.transform:SetParent(this.root.bottom.transform)
        --     this.root.passBattle0.transform.localPosition = Vector3.New(400, 10, 0)
        --     this.root.passBattle0:GetComponent("Toggle").isOn = ArenaManager.IsSkipFight()
        -- else
        --     this.root.passBattle1:SetActive(true)
        --     this.root.passBattle1.transform:SetParent(this.root.bottom.transform)
        --     this.root.passBattle1.transform.localPosition = Vector3.New(400, 10, 0)
        --     Util.AddOnceClick(this.root.passBattle1, function()
        --         PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.ArenaJump))
        --     end)
        -- end
        --- 判断是否有免费次数
        local leftTimes, allTimes = ArenaManager.GetArenaChallengeTimes()
        if leftTimes > 0 then
            -- tip:GetComponent("Text").text = string.format(GetLanguageStrById(10710), leftTimes, allTimes)
            -- itemIcon:SetActive(false)
            -- itemNumLab:SetActive(false)
            return
        end

        --- 显示消耗物品
        local itemId, needNum = ArenaManager.GetArenaChallengeCost()
        -- tip:GetComponent("Text").text = GetLanguageStrById(10216)
        -- itemIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig, itemId).ResourceID))
        -- itemNumLab:GetComponent("Text").text = "X"..needNum
    else
        -- tip:SetActive(false)
        -- itemIcon:SetActive(false)
        -- itemNumLab:SetActive(false)
    end
end




return this