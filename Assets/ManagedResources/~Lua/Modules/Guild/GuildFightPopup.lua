require("Base/BasePanel")
local GuildFightPopup = Inherit(BasePanel)
local this = GuildFightPopup

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(168 / 255, 168 / 255, 167 / 255, 1),
                        select = Color.New(250 / 255, 227 / 255, 175 / 255, 1) }
local _TabSprite = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001"}
local _TabData = {
    [1] = { name = GetLanguageStrById(10550) },
    [2] = { name = GetLanguageStrById(10030) },
    [3] = { name = GetLanguageStrById(10080) },
}

local STAGE_STATUS = {
    UN_START = 1,
    DOING = 2,
    OVER = 3,
}
-- 头像管理
local _PlayerHeadList = {}
-- 物品管理
local _ItemViewList = {}
-- 状态配置
local _StatusConfig = {
    [STAGE_STATUS.UN_START] = {isShowBg = false, nameBg = "r_gonghui_jieduandi02", tip = GetLanguageStrById(10122),
           nameColor = Color.New(67/255, 59/255, 56/255, 1),
           tipColor = Color.New(68/255, 63/255, 60/255, 1),},
    [STAGE_STATUS.DOING] = {isShowBg = true, nameBg = "r_gonghui_jieduandi01", tip = GetLanguageStrById(10882),
           nameColor = Color.New(163/255, 99/255, 42/255, 1),
           tipColor = Color.New(210/255, 166/255, 109/255, 1),},
    [STAGE_STATUS.OVER] = {isShowBg = false, nameBg = "r_gonghui_jieduandi02", tip = GetLanguageStrById(10124),
           nameColor = Color.New(67/255, 59/255, 56/255, 1),
           tipColor = Color.New(148/255, 131/255, 93/255, 1),},
}

-- 帮助配置
local _HelpTypeConfig = {
    [GUILD_FIGHT_STAGE.DEFEND] = {type = HELP_TYPE.GuildDefend, title = GetLanguageStrById(10883)},
    [GUILD_FIGHT_STAGE.MATCHING] = {type = HELP_TYPE.GuildMatching, title = GetLanguageStrById(10884)},
    [GUILD_FIGHT_STAGE.ATTACK] = {type = HELP_TYPE.GuildAttack, title = GetLanguageStrById(10885)},
    [GUILD_FIGHT_STAGE.COUNTING] = {type = HELP_TYPE.GuildCounting, title = GetLanguageStrById(10886)},
}


--初始化组件（用于子类重写）
function GuildFightPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.tabbox = Util.GetGameObject(self.transform, "top")
    this.fightPanel = Util.GetGameObject(self.transform, "content/fight")
    this.rankPanel = Util.GetGameObject(self.transform, "content/rank")
    this.rewardPanel = Util.GetGameObject(self.transform, "content/reward")

    this.stageNode = {}
    this.stageNode[GUILD_FIGHT_STAGE.DEFEND] = Util.GetGameObject(this.fightPanel, "stage_1/bg")
    this.stageNode[GUILD_FIGHT_STAGE.MATCHING] = Util.GetGameObject(this.fightPanel, "stage_2/bg")
    this.stageNode[GUILD_FIGHT_STAGE.ATTACK] = Util.GetGameObject(this.fightPanel, "stage_3/bg")
    this.stageNode[GUILD_FIGHT_STAGE.COUNTING] = Util.GetGameObject(this.fightPanel, "stage_4/bg")

    this.myGuildInfo = Util.GetGameObject(this.fightPanel, "stage_2/bg/my")
    this.enemyGuildInfo = Util.GetGameObject(this.fightPanel, "stage_2/bg/enemy")

    --this.unstartPanel = Util.GetGameObject(this.fightPanel, "unstart")
    --this.  = Util.GetGameObject(this.fightPanel, "unstart/tip"):GetComponent("Text")
    this.unstartTime = Util.GetGameObject(this.fightPanel, "Time"):GetComponent("Text")


    this.rankScrollRoot = Util.GetGameObject(this.rankPanel, "scrollpos")
    this.rankItem = Util.GetGameObject(this.rankPanel, "scrollpos/mem")
    this.empty = Util.GetGameObject(this.rankPanel, "empty")

    this.rewardScrollRoot = Util.GetGameObject(this.rewardPanel, "scrollpos")
    this.rewardItem = Util.GetGameObject(this.rewardPanel, "scrollpos/reward")

    -- 帮助界面
    this.helpPanel = Util.GetGameObject(self.transform, "log")
    this.helpTitle = Util.GetGameObject(this.helpPanel, "bg/top/Title"):GetComponent("Text")
    this.helpContent = Util.GetGameObject(this.helpPanel, "bg/content")
    this.helpItem = Util.GetGameObject(this.helpPanel, "bg/content/Text")

end

--绑定事件（用于子类重写）
function GuildFightPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    for stage, node in pairs(this.stageNode) do
       Util.AddClick(node, function()
           this.helpPanel:SetActive(true)
           this.RefreshLogShow(stage)
       end)
    end

    Util.AddClick(this.helpPanel, function()
        this.helpPanel:SetActive(false)
    end)

    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
end

--添加事件监听（用于子类重写）
function GuildFightPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.FightBaseDataUpdate, this.RefreshFightPanelShow)
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.EnemyBaseDataUpdate, this.RefreshFightBothInfo)
end

--移除事件监听（用于子类重写）
function GuildFightPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.FightBaseDataUpdate, this.RefreshFightPanelShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.EnemyBaseDataUpdate, this.RefreshFightBothInfo)
end

--界面打开时调用（用于子类重写）
function GuildFightPopup:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFightPopup:OnShow()
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(1)
    end
end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Img"):GetComponent("Image").sprite = Util.LoadSprite(_TabSprite[status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    -- 设置显示
    this._CurIndex = index

    this.fightPanel:SetActive(index == 1)
    this.rankPanel:SetActive(index == 2)
    this.rewardPanel:SetActive(index == 3)

    if index == 1 then
        this.RefreshFightPanelShow()
    elseif index == 2 then
        GuildFightManager.RequestGuildFightAttackLogData(0, function()
            this.RefreshRankShow()
        end)
    elseif index == 3 then
        this.RefreshRewardShow()
    end
end

-- 刷新公会战信息
function this.RefreshFightPanelShow()
    this.RefreshStageShow()
    --this.RefreshFightBothInfo()
end
-- 刷新公会战阶段提示信息
function this.RefreshStageShow()
    this._CountTimeTip = nil
    local guildFightData = GuildFightManager.GetGuildFightData()
    local _CurStage = guildFightData.type
    local _IsShowTime = _CurStage == GUILD_FIGHT_STAGE.UN_START or _CurStage == GUILD_FIGHT_STAGE.EMPTEY
    -- 判断公会战是否开始
    if _IsShowTime then
        -- 开始吧
        this._TimeUpdate()
        if not this._TimeCounter then
            this._TimeCounter = Timer.New(this._TimeUpdate, 1, -1, true)
            this._TimeCounter:Start()
        end
    end

    -- tip 显示
    for stage, node in ipairs(this.stageNode) do
        local tip = Util.GetGameObject(node, "tip"):GetComponent("Text")
        local namebg = Util.GetGameObject(node, "namebg"):GetComponent("Image")
        local name = Util.GetGameObject(namebg.gameObject, "name"):GetComponent("Text")
        local bg = node:GetComponent("Image")
        -- 判断状态
        local status = STAGE_STATUS.UN_START
        if _CurStage > stage then
            status = STAGE_STATUS.OVER
        elseif _CurStage == stage then
            status = STAGE_STATUS.DOING
        end

        local config = _StatusConfig[status]
        bg.enabled = config.isShowBg
        namebg.sprite = Util.LoadSprite(config.nameBg)
        name.color = config.nameColor
        tip.text = config.tip
        tip.color = config.tipColor

        if status == STAGE_STATUS.DOING then
            -- 开始吧
            this._CountTimeTip = tip
            this._TimeUpdate()
            if not this._TimeCounter then
                this._TimeCounter = Timer.New(this._TimeUpdate, 1, -1, true)
                this._TimeCounter:Start()
            end
        end

        --
        --if stage == GUILD_FIGHT_STAGE.MATCHING then
        --    -- 没有敌方数据
        --    local enemyGuildData = GuildFightManager.GetEnemyBaseData()
        --    namebg.gameObject:SetActive(enemyGuildData == nil)
        --end
    end
end

-- 刷新公会战双方信息
function this.RefreshFightBothInfo()
    local guildFightData = GuildFightManager.GetGuildFightData()
    local _CurStage = guildFightData.type
    local _JoinType = guildFightData.joinType

    -- 轮空不显示敌方公会信息
    if _JoinType == 0 or _CurStage == GUILD_FIGHT_STAGE.UN_START or _CurStage == GUILD_FIGHT_STAGE.DEFEND then
        this.myGuildInfo:SetActive(false)
        this.enemyGuildInfo:SetActive(false)
        return
    end
    -- 没有敌方数据
    local enemyGuildData = GuildFightManager.GetEnemyBaseData()
    if not enemyGuildData then
        this.myGuildInfo:SetActive(false)
        this.enemyGuildInfo:SetActive(false)
        return
    end
    -- 显示
    this.myGuildInfo:SetActive(true)
    this.enemyGuildInfo:SetActive(true)
    -- 敌方数据显示
    this.GuildBaseInfoAdapter(this.enemyGuildInfo, enemyGuildData)
    -- 我方数据显示
    local myGuildData = GuildFightManager.GetMyBaseData()
    this.GuildBaseInfoAdapter(this.myGuildInfo, myGuildData)
end

-- 公会基础数据匹配
function this.GuildBaseInfoAdapter(node, data)
    local nameText = Util.GetGameObject(node, "name"):GetComponent("Text")
    local levelText = Util.GetGameObject(node, "level"):GetComponent("Text")
    local starText = Util.GetGameObject(node, "starNum"):GetComponent("Text")
    local logoSpr = Util.GetGameObject(node, "icon"):GetComponent("Image")

    nameText.text = data.name
    levelText.text = data.level
    -- 星星数量显示
    starText.text = data.totalStar

    local logoName = GuildManager.GetLogoResName(data.pictureId)
    logoSpr.sprite = Util.LoadSprite(logoName)
end


-- 获取排名
function this.RefreshRankShow()
    local rankList = GuildFightManager.GetGuildFightAttackLogData(0)
    if not rankList then return end
    -- 创建滚动
    if not this.rankScroll then
        local height = this.rankScrollRoot.transform.rect.height
        local width = this.rankScrollRoot.transform.rect.width
        this.rankScroll = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rankScrollRoot.transform,
                this.rankItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
        this.rankScroll.moveTween.Strength = 2
    end

    this.rankScroll:SetData(rankList, function(index, go)
        this.RankItemAdapter(go, rankList[index])
    end)
    this.rankScroll:SetIndex(1)
    this.empty:SetActive(#rankList == 0)
end

-- 排名节点数据匹配
function this.RankItemAdapter(node, data)
    local rank = Util.GetGameObject(node, "rank"):GetComponent("Image")
    local rankNum = Util.GetGameObject(node, "rank/num"):GetComponent("Text")
    local head = Util.GetGameObject(node, "head")
    local name = Util.GetGameObject(node, "name"):GetComponent("Text")
    local pos = Util.GetGameObject(node, "pos"):GetComponent("Text")
    local count = Util.GetGameObject(node, "count"):GetComponent("Text")
    local starNum = Util.GetGameObject(node, "num"):GetComponent("Text")


    -- 排名
    if data.rank <= 3 then
        rank.sprite = Util.LoadSprite("r_playerrumble_paiming_0"..data.rank)
        --rank:SetNativeSize()
        rankNum.gameObject:SetActive(false)
    else
        rank.sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        --rank.transform.sizeDelta = Vector2.New(120, 120)
        rankNum.gameObject:SetActive(true)
    end

    rankNum:GetComponent("Text").text = data.rank
    name:GetComponent("Text").text = data.name
    pos:GetComponent("Text").text = GUILD_GRANT_STR[data.position]
    count:GetComponent("Text").text = data.attackCount..GetLanguageStrById(10054)
    starNum:GetComponent("Text").text = data.starCount

    -- 头像
    if not _PlayerHeadList[node] then
        _PlayerHeadList[node] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    _PlayerHeadList[node]:Reset()
    _PlayerHeadList[node]:SetScale(Vector3.one * 0.6)
    _PlayerHeadList[node]:SetHead(data.head)
    _PlayerHeadList[node]:SetFrame(data.headFrame)


end

-- 刷新排名奖励
function this.RefreshRewardShow()
    local rewardList = GuildFightManager.GetGuildFightRewardData()
    if not rewardList then return end
    -- 创建滚动
    if not this.rewardScroll then
        local height = this.rewardScrollRoot.transform.rect.height
        local width = this.rewardScrollRoot.transform.rect.width
        this.rewardScroll = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rewardScrollRoot.transform,
                this.rewardItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
        this.rewardScroll.moveTween.Strength = 2
    end

    this.rewardScroll:SetData(rewardList, function(index, go)
        this.RewardItemAdapter(go, rewardList[index])
    end)
    this.rewardScroll:SetIndex(1)
end

-- 节点数据匹配
function this.RewardItemAdapter(item, data)
    local rank = Util.GetGameObject(item, "rank"):GetComponent("Image")
    local rankNum = Util.GetGameObject(item, "rank/num"):GetComponent("Text")
    local box = Util.GetGameObject(item, "box")

    -- 排名
    if data.RankMin <= 3 then
        rank.sprite = Util.LoadSprite("r_playerrumble_paiming_0"..data.RankMin)
        rankNum.gameObject:SetActive(false)
        rank.transform.sizeDelta = Vector2.New(100, 100)
    elseif data.RankMin == data.RankMax then
        rank.sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        rankNum.gameObject:SetActive(true)
        rank.transform.sizeDelta = Vector2.New(100, 100)
        rankNum.text = data.RankMin
    elseif data.RankMin ~= data.RankMax then
        rank.sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        rankNum.gameObject:SetActive(true)
        rank.transform.sizeDelta = Vector2.New(200, 100)
        rankNum.text = data.RankMin .. "~" .. data.RankMax
    end


    local itemDataList = {}
    local ss = string.split(data.Reward, "|")
    for i=1, #ss do
        local arr = string.split(ss[i], "#")
        for j = 1, #arr do
            arr[j] = tonumber(arr[j])
        end
        table.insert(itemDataList, arr)
    end

    for index, reward in ipairs(itemDataList) do
        if not _ItemViewList[item] then
            _ItemViewList[item] = {}
        end
        if not _ItemViewList[item][index] then
            _ItemViewList[item][index] = SubUIManager.Open(SubUIConfig.ItemView, box.transform)
        end
        _ItemViewList[item][index]:OnOpen(false,reward,0.7,false,false,false,this.selfsortingOrder)
    end
end


-- 计时显示
function this._TimeUpdate()
    local guildFightData = GuildFightManager.GetGuildFightData()
    local stage = guildFightData.type
    local startTime = guildFightData.startTime
    local curTime = GetTimeStamp()

    if stage == GUILD_FIGHT_STAGE.UN_START then
        local leftTime = startTime - curTime
        leftTime = leftTime < 0 and 0 or leftTime
        this.unstartTime.text = GetLanguageStrById(10887)..TimeToHMS(leftTime)

    elseif stage == GUILD_FIGHT_STAGE.EMPTEY then
        local roundEndTime = guildFightData.roundEndTime
        local leftTime = roundEndTime - curTime
        leftTime = leftTime < 0 and 0 or leftTime
        this.unstartTime.text = GetLanguageStrById(10888)..TimeToHMS(leftTime)
        --this._CountTimeTip.text = TimeToHMS(leftTime)
    else
        this.unstartTime.text = GetLanguageStrById(10889)
    end

    if this._CountTimeTip then
        local roundEndTime = guildFightData.roundEndTime
        local leftTime = roundEndTime - curTime
        leftTime = leftTime < 0 and 0 or leftTime
        this._CountTimeTip.text = string.format(_StatusConfig[STAGE_STATUS.DOING].tip, TimeToHMS(leftTime))
    end
end


-- 刷新公会日志
local _HelpItemList = {}
function this.RefreshLogShow(stageType)
    local config = _HelpTypeConfig[stageType]
    this.helpTitle.text = config.title
    local helpData = ConfigManager.GetConfigData(ConfigName.QAConfig, config.type)
    local str = GetLanguageStrById(helpData.content)
    str = string.gsub(str,"{","<color=#D48A07>")
    str = string.gsub(str,"}","</color>")
    local helpStrList = string.split(str, "|")
    local maxLen = math.max(#_HelpItemList, #helpStrList)
    for i = 1, maxLen do
        if not _HelpItemList[i] then
            _HelpItemList[i] = newObjToParent(this.helpItem, this.helpContent)
        end
        if not helpStrList[i] then
            _HelpItemList[i]:SetActive(false)
        else
            _HelpItemList[i]:SetActive(true)
            _HelpItemList[i]:GetComponent("Text").text = helpStrList[i]
            Util.GetGameObject(_HelpItemList[i], "line"):SetActive(i ~= #helpStrList)
        end
    end
end

--界面关闭时调用（用于子类重写）
function GuildFightPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildFightPopup:OnDestroy()
    if this._TimeCounter then
        this._TimeCounter:Stop()
        this._TimeCounter = nil
    end

    -- 滚动置空
    this.rankScroll = nil
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    --
    this.rewardScroll = nil
    _ItemViewList = {}

    --
    _HelpItemList = {}
end

return GuildFightPopup