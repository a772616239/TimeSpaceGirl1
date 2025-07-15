require("Base/BasePanel")
local GuildBossTipPanel = Inherit(BasePanel)
local this = GuildBossTipPanel

local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)

local _TitleConfig = {
    [1] = GetLanguageStrById(11024),
    [2] = GetLanguageStrById(11023),
}
function this:InitComponent()
    this.btnBack = Util.GetGameObject(this.transform, "tipImage/btnClose")
    this.title = Util.GetGameObject(this.transform, "tipImage/title"):GetComponent("Text")
    this.contentPanel = Util.GetGameObject(this.transform, "tipImage/content")

    this.rewardPanel = Util.GetGameObject(this.contentPanel, "Reward")
    this.rewardContent = Util.GetGameObject(this.rewardPanel, "Content"):GetComponent("Text")
    this.rewardItemList ={
        Util.GetGameObject(this.rewardPanel, "List/cny1"),
        Util.GetGameObject(this.rewardPanel, "List/cny2"),
    } 

    this.sweepPanel = Util.GetGameObject(this.contentPanel, "Sweep")
    this.sweepDamage = Util.GetGameObject(this.sweepPanel, "Damage"):GetComponent("Text")
    this.sweepBoxIcon = Util.GetGameObject(this.sweepPanel, "cny1/icon"):GetComponent("Image")
    this.sweepBoxLevel = Util.GetGameObject(this.sweepPanel, "cny1/value"):GetComponent("Text")

    this.btnList = {
        Util.GetGameObject(this.transform, "tipImage/box/btn1"),
        Util.GetGameObject(this.transform, "tipImage/box/btn2"),
        Util.GetGameObject(this.transform, "tipImage/box/btn3"),
    }

end

function this:BindEvent()
    -- 返回按钮
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        -- 关闭当前界面
        this:ClosePanel()
    end)


end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.GuildBoss.OnLastDamageChanged, this.OnShow, this)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildBoss.OnLastDamageChanged, this.OnShow, this)
end

-- 打开时调用
function this:OnOpen(panelType)
    this._PanelType = panelType
end
-- 
function this:OnShow()
    this.title.text = _TitleConfig[this._PanelType]
    this.rewardPanel:SetActive(this._PanelType == 1)
    this.sweepPanel:SetActive(this._PanelType == 2)
    if this._PanelType == 1 then
        GuildBossManager.RequestGuildBossAttackLog(this.RefreshRewardShow)
        -- this.RefreshRewardShow()
    elseif this._PanelType == 2 then
        this.RefreshSweepShow()
    end
end

-- 刷新奖励显示
local formatStr = GetLanguageStrById(11025)
function this.RefreshRewardShow()
    -- 基础信息
    local monsterGroupId = GuildBossManager.GetBossGroupId()
    local monsterId = monsterGroup[monsterGroupId].Contents[1][1]
    local monsterInfo = monsterConfig[monsterId]

    local dataList = GuildBossManager.GetBossAttackLog()
    if not dataList or not dataList[1] then 
        this.rewardContent.text = GetLanguageStrById(11026)
        this.rewardItemAdapter(0)
    else
        -- 获取目前公会种伤害最高数值
        local maxDamage = dataList[1].rankInfo.param1
        local userName = dataList[1].userName
        -- 当前奖励
        this.rewardContent.text = string.format(formatStr, userName, GetLanguageStrById(monsterInfo.ReadingName), maxDamage)
        this.rewardItemAdapter(maxDamage)
    end
    -- 
    this.RefreshBtnShow()
end

-- 奖励物品数据匹配
function this.rewardItemAdapter(damage)
    local showlist = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).BossReward
    local index = 1
    for _, reward in pairs(showlist) do
        local id = reward[1]
        local num = reward[2]
        local item = this.rewardItemList[index]
        if item then
            local icon = Util.GetGameObject(item, "icon"):GetComponent("Image")
            local value = Util.GetGameObject(item, "value"):GetComponent("Text")
            icon.sprite = SetIcon(id)
            value.text = math.floor(num * damage)
        end
        index = index + 1
    end
end

-- 刷新扫荡界面显示
function this.RefreshSweepShow()
    -- 获取伤害数值
    local maxDamage = GuildBossManager.GetLastHurt()
    this.sweepDamage.text = maxDamage
    
    local curLevel, curLevelData = GuildBossManager.GetCurBossRewardLevel(maxDamage)
    if not curLevel then
        this.sweepBoxIcon.sprite = GuildBossManager.GetBoxSpriteByLevel(0)
        this.sweepBoxLevel.text = 0
    else
        this.sweepBoxIcon.sprite = GuildBossManager.GetBoxSpriteByLevel(curLevel)
        this.sweepBoxLevel.text = curLevel
    end

    this.RefreshBtnShow()
end

function this.RefreshBtnShow()
    if this._PanelType == 1 then
        this.btnList[1]:SetActive(true)
        this.btnList[2]:SetActive(false)
        this.btnList[3]:SetActive(false)
        Util.GetGameObject(this.btnList[1], "Text"):GetComponent("Text").text = GetLanguageStrById(10508)
        Util.AddOnceClick(this.btnList[1], function()
            this:ClosePanel()
        end)

    elseif this._PanelType == 2 then
        this.btnList[1]:SetActive(true)
        this.btnList[2]:SetActive(false)
        this.btnList[3]:SetActive(false)
        Util.GetGameObject(this.btnList[1], "Text"):GetComponent("Text").text = GetLanguageStrById(11027)
        Util.AddOnceClick(this.btnList[1], function()
            GuildBossManager.RequestSweepBoss(function(msg)
                local _fightData = BattleManager.GetBattleServerData({fightData = msg.fightData})
                BattleRecordManager.SetBattleRecord(_fightData)
                UIManager.OpenPanel(UIName.GuildBossFightResultPopup, msg.Drop, msg.randomDrop, msg.hurt)
            end)
        end)
    end
end

-- 销毁时调用
function this:OnDestroy()
    
end

return this