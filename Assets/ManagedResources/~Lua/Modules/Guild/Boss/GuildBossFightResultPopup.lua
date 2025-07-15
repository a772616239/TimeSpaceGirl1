require("Base/BasePanel")
local GuildBossFightResultPopup = Inherit(BasePanel)
local this = GuildBossFightResultPopup

-- 初始化组件
function this:InitComponent()
    this.btnBack = Util.GetGameObject(this.transform, "btnBack")

    this.boxIcon = Util.GetGameObject(this.transform, "box/icon"):GetComponent("Image")
    this.boxLevel = Util.GetGameObject(this.transform, "box/lv"):GetComponent("Text")
    this.boxProgress = Util.GetGameObject(this.transform, "box/progress/Fill")
    this.boxDamage = Util.GetGameObject(this.transform, "box/progress/Text"):GetComponent("Text")


    this.btnResult = Util.GetGameObject(this.transform, "btnResult")

    this.scrollContent = Util.GetGameObject(this.transform, "scrollRoot/ScrollView/Content")

    this.rewardList = {
        Util.GetGameObject(this.transform, "List/cny1"),
        Util.GetGameObject(this.transform, "List/cny2"),
    } 

    this.resultState = Util.GetGameObject(this.transform, "state"):GetComponent("Text")
    this.resultStateIcon = Util.GetGameObject(this.transform, "state/icon"):GetComponent("Image")
end

-- 绑定事件
function this:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
        if this.func then this.func() end
    end)
    Util.AddClick(this.btnResult, function()
        UIManager.OpenPanel(UIName.DamageResultPanel, 1)
    end)
end

-- 
function this:OnOpen(stayReward, randomReward, damage, func)
    -- 
    this.stayReward = BagManager.GetTableByBackDropData(stayReward)
    this.randomReward = BagManager.GetTableByBackDropData(randomReward)
    this.damage = damage
    this.func = func
    
    this.RefreshStayRewardShow()
    this.RefreshRandomRewardShow()
    this.RefreshBoxShow()
    this.RefreshDamageChangeState()
end

-- 伤害变化显示
function this.RefreshDamageChangeState()
    local oldDamage = GuildBossManager.GetMyMaxBossHurt()
    if oldDamage < this.damage then
        this.resultState.text = GetLanguageStrById(11012)
        this.resultState.color = UIColor.GREEN
        this.resultStateIcon.gameObject:SetActive(true)
        this.resultStateIcon.sprite = Util.LoadSprite("r_hero_zhanlishangsheng_png")
    elseif oldDamage > this.damage then
        this.resultState.text = GetLanguageStrById(11013)
        this.resultState.color = UIColor.RED
        this.resultStateIcon.gameObject:SetActive(true)
        this.resultStateIcon.sprite = Util.LoadSprite("r_hero_zhanlixiajiang_png")
    elseif oldDamage == this.damage then
        this.resultState.text = GetLanguageStrById(11014)
        this.resultState.color = UIColor.GRAY
        this.resultStateIcon.gameObject:SetActive(false)
    end

    GuildBossManager.SetMyMaxBossHurt(this.damage)
    GuildBossManager.SetLastHurt(this.damage)
end

-- 常驻奖励
function this.RefreshStayRewardShow()    
    for index, reward in pairs(this.stayReward) do
        local item = this.rewardList[index]
        if item then
            local icon = Util.GetGameObject(item, "icon"):GetComponent("Image")
            local value = Util.GetGameObject(item, "value"):GetComponent("Text")
            icon.sprite = Util.LoadSprite(reward.icon)
            value.text = reward.num
        end
    end
end


-- 随机奖励
local _ItemList = {}
function this.RefreshRandomRewardShow()    
    for _, item in ipairs(_ItemList) do
        item.gameObject:SetActive(false)
    end
    for index, reward in pairs(this.randomReward) do
        local item = _ItemList[index]
        if not item then
            _ItemList[index] = SubUIManager.Open(SubUIConfig.ItemView,this.scrollContent.transform)
            item = _ItemList[index]
        end
        item:OnOpen(true, reward, 1, false, false, false, this.selfsortingOrder)
        item.gameObject:SetActive(true)
    end
end


-- 刷新宝箱显示
function this.RefreshBoxShow()
    local bossRewardConfig = ConfigManager.GetConfig(ConfigName.GuildBossRewardConfig)
    local curLevel, curLevelData, nextLevelData 
    for level, data in ConfigPairs(bossRewardConfig) do
        if data.Damage > this.damage then
            nextLevelData = data
            break
        end
        curLevel = level
        curLevelData = data
    end
    this.boxIcon.sprite = GuildBossManager.GetBoxSpriteByLevel(curLevel or 0)
    this.boxLevel.text = curLevel or 0
    this.boxDamage.text = this.damage.."/"..nextLevelData.Damage

    local curLevelDamage = not curLevelData and 0 or curLevelData.Damage
    local rate = (this.damage - curLevelDamage)/(nextLevelData.Damage - curLevelDamage)
    this.boxProgress.transform.localScale = Vector3.New(rate, 1, 1)
end



function this:OnClose()
    -- 回收节点
    for _, node in ipairs(_ItemList) do
        SubUIManager.Close(node)
    end
    _ItemList = {}

end
function this:OnDestroy()
end

return this