require("Base/BasePanel")
MonsterCampPanel = Inherit(BasePanel)
local this = MonsterCampPanel
local orginLayer
local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)

--初始化组件（用于子类重写）
function MonsterCampPanel:InitComponent()
    orginLayer = 0
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.waveNum = Util.GetGameObject(self.gameObject, "Bg/waveImg/wave/waveText"):GetComponent("Text") --m5
    this.btnFight = Util.GetGameObject(self.gameObject, "Bg/btnFight")
    this.nextWave = Util.GetGameObject(self.gameObject, "Bg/btnWave")
    this.btnRank = Util.GetGameObject(self.gameObject, "Bg/btnRank")

    -- 跳过战斗
    this.battleJumpRoot = Util.GetGameObject(self.gameObject, "passBattle")
    this.battleToggleBg = Util.GetGameObject(this.battleJumpRoot, "Background")
    this.battleToggle = Util.GetGameObject(this.battleJumpRoot, "Background/Checkmark")

    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    this.effect = Util.GetGameObject(self.gameObject, "MonsterCampPanel_effect (1)")
    effectAdapte(Util.GetGameObject(this.effect, "lizi/ziti mask"))

    --怪物预览
    --this.nameTxt = Util.GetGameObject(self.gameObject, "Bg/name"):GetComponent("Text")
    --this.lvlTxt = Util.GetGameObject(self.gameObject, "Bg/lv"):GetComponent("Text")
    this.rewardList = Util.GetGameObject(self.gameObject, "Bg/reward/rewardlist")
    this.power=Util.GetGameObject(self.gameObject,"Bg/powerBg/power"):GetComponent("Text")

    this.rewardItemList = {}
    for i = 1, 8 do
        this.rewardItemList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.rewardList.transform)
        this.rewardItemList[i].gameObject:SetActive(false)
    end

    this.btnText = Util.GetGameObject(self.gameObject, "Bg/btnFight/Text"):GetComponent("Text")
    --4个妖怪头像
    this.monsterRoot = Util.GetGameObject(self.gameObject, "Bg/monsterRoot")
    this.monsterList = {}
    for i = 1, 6 do
        this.monsterList[i] = Util.GetGameObject(this.monsterRoot, "monterRoot/frame_" .. i)
    end
end

--绑定事件（用于子类重写）
function MonsterCampPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        -- UIManager.OpenPanel(UIName.MainPanel)
        PlayerManager.carbonType = 1
        UIManager.OpenPanel(UIName.CarbonTypePanelV2)
        self:ClosePanel()
    end)

    Util.AddClick(this.nextWave, function ()
        UIManager.OpenPanel(UIName.NextMonsterInfoPopup, function ()
            this.effect:SetActive(true)
        end)
        -- 隐藏特效
        this.effect:SetActive(false)
    end)

    Util.AddClick(this.btnFight, function ()

        -- 打到最高波次时提示
        if MonsterCampManager.monsterWave > MonsterCampManager.GetMaxNum() then
            PopupTipPanel.ShowTipByLanguageId(11397)
            return
        end

        -- if this.ShowTip() then
        --     return
        -- end

        if MonsterCampManager.monsterWave > 1 then
            if MonsterCampManager.GetBattleJump() then -- 跳过战斗
                this.GetQuickResult()

            else
                this.GoBattle()
            end
        else
            this.GoBattle()
        end
    end)

    Util.AddClick(this.btnRank, function ()
        UIManager.OpenPanel(UIName.CarbonScoreSortPanel, 2, function ()
            this.effect:SetActive(true)
        end)
        -- 隐藏特效
        this.effect:SetActive(false)
    end)

    Util.AddClick(this.battleJumpRoot, function ()
        if not MonsterCampManager.CheckBattleJump() then
            PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.MonsterCampJump))
            return
        end
        local isOn = MonsterCampManager.GetBattleJump()
        MonsterCampManager.SetBattleJump(not isOn)
        this.InitShow()
    end)
end

--添加事件监听（用于子类重写）
function MonsterCampPanel:AddListener()

end

--移除事件监听（用于子类重写）
function MonsterCampPanel:RemoveListener()

end


--界面打开时调用（用于子类重写）
function MonsterCampPanel:OnOpen(...)
    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)

    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.MonsterCamp })
    -- 初始化界面数据
    this.InitShow()
    this.ChangePreview()
end

function MonsterCampPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

--界面关闭时调用（用于子类重写）
function MonsterCampPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function MonsterCampPanel:OnDestroy()
    SubUIManager.Close(this.UpView)

end

function this.InitShow()
    this.effect:SetActive(true)
    this.waveNum.text = MonsterCampManager.monsterWave
    this.battleJumpRoot:SetActive(false)--MonsterCampManager.monsterWave > 1)

    if MonsterCampManager.CheckBattleJump() then
        this.battleToggleBg:GetComponent("Image").sprite = Util.LoadSprite("r_hero_renwukuang-001")
        this.battleToggle:SetActive(MonsterCampManager.GetBattleJump())
    else
        this.battleToggleBg:GetComponent("Image").sprite = Util.LoadSprite("r_renwu_suo_001")
    end
end

-- 购买温馨提示，亲，该充值了
function this.ShowTip()
    local itemNum = BagManager.GetItemCountById(53)
    if itemNum <= 0 then
        UIManager.OpenPanel(UIName.QuickPurchasePanel,{ type = UpViewRechargeType.MonsterCampTicket })
        return true
    else
        return false
    end
end

-- 直接请求战斗结果
function this.GetQuickResult()
    NetManager.GetMonsterFightResult(MonsterCampManager.monsterWave, FormationTypeDef.MONSTER_CAMP_ATTACK, function (msg)
        -- 设置战斗数据用于统计战斗
        
        local _fightData = BattleManager.GetBattleServerData({fightData = msg.fightData}, 0)
        BattleRecordManager.SetBattleRecord(_fightData)
        -- 判断战斗结果
        local haveRecord = BattleRecordManager.isHaveRecord()
        if msg.result == 0 then
            UIManager.OpenPanel(UIName.BattleFailPopup, nil, haveRecord)
        else
            local result = {}
            result.drop = msg.enventDrop
            UIManager.OpenPanel(UIName.BattleWinPopup, nil, false, 5, result, not haveRecord, nil, function()end)
            MonsterCampManager.monsterWave = MonsterCampManager.monsterWave + 1
            -- 刷新波次显示
            this.waveNum.text = MonsterCampManager.monsterWave
            this.ChangePreview()
        end
    end)
end

-- 正常战斗
function this.GoBattle()
    --屏蔽掉挑战进入怪物预览界面 直接进入编队 预览界面在本界面显示
    --UIManager.OpenPanel(UIName.MonsterShowPanel, MonsterCampManager.GetCurWaveMonsterGroupId(), function ()
    --    UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.MONSTER_CAMP)
    --end, function ()
    --    this.effect:SetActive(true)
    --end, false, 3)
    -- UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.MONSTER_CAMP)
    UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.MONSTER_CAMP)

    -- 隐藏特效
    this.effect:SetActive(false)
end

--改变预览
function this.ChangePreview()
    local monsterGroupId= MonsterCampManager.GetCurWaveMonsterGroupId()

    if not monsterGroupId then return end
    local monsterData = monsterGroup[monsterGroupId]
    if not monsterData then

    end
    local monsterId = monsterData.Contents[1][1]
    local monsterInfo = monsterConfig[monsterId]

    --this.nameTxt.text = monsterInfo.ReadingName
    --this.lvlTxt.text = "Lv."..monsterInfo.Level
    this.power.text=ConfigManager.GetConfigDataByKey(ConfigName.FloodConfig,"Monster",monsterId).Force--怪物战力走表 等策划配表
    this.btnText.text =GetLanguageStrById(10512)
    this.waveNum.text =MonsterCampManager.monsterWave
    -- 显示4只小怪头像
    this.ShowMonsterIcon()
end

-- 设置显示小怪
function this.ShowMonsterIcon()
    local monsterInfo, mainInfo = MonsterCampManager.GetCurMonsterInfo()
    -- 初始化隐藏
    for i = 1, 6 do
        this.monsterList[i]:SetActive(false)
    end
    
    for i = 1, #monsterInfo.icon do
        Util.GetGameObject(this.monsterList[i], "icon"):GetComponent("Image").sprite = monsterInfo.icon[i]
        Util.GetGameObject(this.monsterList[i],"lvRoot/lv"):GetComponent("Text").text=monsterInfo.level[i]
        this.monsterList[i]:SetActive(true)
    end

    -- 设置奖励
    this.SetRewardShow(monsterInfo.rewardShow)
end
function this.SetRewardShow(rewardData)
    for i = 1, 8 do
        this.rewardItemList[i].gameObject:SetActive(false)
    end

    for i = 1, #rewardData do
        local item = {}
        local itemId = rewardData[i][1]
        item[#item + 1] = itemId
        item[#item + 1] = rewardData[i][2]
        this.rewardItemList[i]:OnOpen(false, item, 1.1, false)
        this.rewardItemList[i].gameObject:SetActive(true)
    end
end

return MonsterCampPanel