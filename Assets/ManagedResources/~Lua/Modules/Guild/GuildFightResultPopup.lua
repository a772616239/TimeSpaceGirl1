require("Base/BasePanel")
local GuildFightResultPopup = Inherit(BasePanel)
local this = GuildFightResultPopup

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(168 / 255, 168 / 255, 167 / 255, 1),
                        select = Color.New(250 / 255, 227 / 255, 175 / 255, 1) }
local _TabSprite = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001"}
local _TabData = {
    [1] = { name = GetLanguageStrById(10890) },
    --[2] = { name = "个人战绩" },
    --[3] = { name = "战绩奖励" },
}
-- 头像管理
local _PlayerHeadList = {}
-- 物品管理
local _ItemViewList = {}

--初始化组件（用于子类重写）
function GuildFightResultPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.tabbox = Util.GetGameObject(self.transform, "top")

    this.resultPanel = Util.GetGameObject(self.transform, "content/result")
    this.rankPanel = Util.GetGameObject(self.transform, "content/rank")
    this.rewardPanel = Util.GetGameObject(self.transform, "content/reward")

    this.myGuild = Util.GetGameObject(this.resultPanel, "my")
    this.enemyGuild = Util.GetGameObject(this.resultPanel, "enemy")
    this.myAllStar = Util.GetGameObject(this.resultPanel, "my/starNum"):GetComponent("Text")
    this.enemyAllStar = Util.GetGameObject(this.resultPanel, "enemy/starNum"):GetComponent("Text")
    this.myResult = Util.GetGameObject(this.resultPanel, "my/result"):GetComponent("Image")
    this.enemyResult = Util.GetGameObject(this.resultPanel, "enemy/result"):GetComponent("Image")

    this.pingText = Util.GetGameObject(this.resultPanel, "ping")
    this.levelText = Util.GetGameObject(this.resultPanel, "level/Text"):GetComponent("Text")
    this.expSlider = Util.GetGameObject(this.resultPanel, "level/Slider"):GetComponent("Slider")
    this.expText = Util.GetGameObject(this.resultPanel, "level/Slider/Text"):GetComponent("Text")
    this.uplevel = Util.GetGameObject(this.resultPanel, "level/up")
    this.uplevelText = Util.GetGameObject(this.resultPanel, "level/up/Text"):GetComponent("Text")

    this.allGetStar = Util.GetGameObject(this.resultPanel, "allgetstar/Text"):GetComponent("Text")
    this.getStar = {}
    this.getStar[1] = Util.GetGameObject(this.resultPanel, "houseget/Text"):GetComponent("Text")
    this.getStar[2] = Util.GetGameObject(this.resultPanel, "storeget/Text"):GetComponent("Text")
    this.getStar[3] = Util.GetGameObject(this.resultPanel, "logoget/Text"):GetComponent("Text")

    this.allLoseStar = Util.GetGameObject(this.resultPanel, "alllosestar/Text"):GetComponent("Text")
    this.loseStar = {}
    this.loseStar[1] = Util.GetGameObject(this.resultPanel, "houselose/Text"):GetComponent("Text")
    this.loseStar[2] = Util.GetGameObject(this.resultPanel, "storelose/Text"):GetComponent("Text")
    this.loseStar[3] = Util.GetGameObject(this.resultPanel, "logolose/Text"):GetComponent("Text")



    this.rankScrollRoot = Util.GetGameObject(this.rankPanel, "scrollpos")
    this.rankItem = Util.GetGameObject(this.rankPanel, "scrollpos/mem")
    this.empty = Util.GetGameObject(this.rankPanel, "empty")

    this.rewardScrollRoot = Util.GetGameObject(this.rewardPanel, "scrollpos")
    this.rewardItem = Util.GetGameObject(this.rewardPanel, "scrollpos/reward")

end

--绑定事件（用于子类重写）
function GuildFightResultPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
end

--添加事件监听（用于子类重写）
function GuildFightResultPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.ResultDataUpdate, this.RefreshResultShow)
end

--移除事件监听（用于子类重写）
function GuildFightResultPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.ResultDataUpdate, this.RefreshResultShow)
end

--界面打开时调用（用于子类重写）
function GuildFightResultPopup:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFightResultPopup:OnShow()
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

    this.resultPanel:SetActive(index == 1)
    this.rankPanel:SetActive(index == 2)
    this.rewardPanel:SetActive(index == 3)

    if index == 1 then
        this.RefreshResultShow()
    elseif index == 2 then
        GuildFightManager.RequestGuildFightAttackLogData(0, function()
            this.RefreshRankShow()
        end)
    elseif index == 3 then
        this.RefreshRewardShow()
    end
end

function this.RefreshResultShow()
    if this._CurIndex ~= 1 then return end
    local resultData = GuildFightManager.GetGuildFightResultData()
    if not resultData then return end

    -- 判断等级显示
    local curLevel = resultData.level
    local getExp = resultData.getExp
    local curExp = resultData.curExp
    if curExp < getExp then
        this.uplevel:SetActive(true)
        this.levelText.text = curLevel - 1
        this.uplevelText.text = curLevel
    else
        this.uplevel:SetActive(false)
        this.levelText.text = curLevel
    end
    local levelMaxExp = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, curLevel).Exp
    this.expSlider.value = curExp/levelMaxExp
    this.expText.text = string.format("%s<color=#00ff00ff>(+%s)</color>/%s", curExp, getExp, levelMaxExp)

    -- 所有获取的星数
    local index = 0
    local allGetStar = 0
    for _, txt in ipairs(this.getStar) do
        index = index + 1
        local star = resultData.star[index]
        local exStar = resultData.extraStar[index]
        txt.text = star + exStar--string.format("%d<color=#57c88a>(+%d)</color>", star + exStar, exStar)
        allGetStar = allGetStar + star + exStar
    end
    this.myAllStar.text = allGetStar
    this.allGetStar.text = allGetStar
    -- 所有失去的星数
    local allLoseStar = 0
    for _, txt in ipairs(this.loseStar) do
        index = index + 1
        local star = resultData.star[index]
        local exStar = resultData.extraStar[index]
        txt.text = star + exStar--string.format("%d<color=#e25b58>(-%d)</color>", star + exStar, exStar)
        allLoseStar = allLoseStar + star + exStar
    end
    this.enemyAllStar.text = allLoseStar
    this.allLoseStar.text = allLoseStar

    -- 判断胜负
    local result = 0
    if allGetStar > allLoseStar then
        result = 1
        this.myResult.sprite = Util.LoadSprite("UI_effect_JJC_JieSuan_ShengLi_png")
        this.enemyResult.sprite = Util.LoadSprite("UI_effect_JJC_JieSuan_ShiBai_png")
    elseif allGetStar < allLoseStar then
        result = -1
        this.myResult.sprite = Util.LoadSprite("UI_effect_JJC_JieSuan_ShiBai_png")
        this.enemyResult.sprite = Util.LoadSprite("UI_effect_JJC_JieSuan_ShengLi_png")
    end
    this.myResult.gameObject:SetActive(result ~= 0)
    this.enemyResult.gameObject:SetActive(result ~= 0)
    this.pingText:SetActive(result == 0)

    -- 敌方数据显示
    local enemyGuildData = GuildFightManager.GetEnemyBaseData()
    this.GuildBaseInfoAdapter(this.enemyGuild, enemyGuildData)
    -- 我方数据显示
    local myGuildData = GuildFightManager.GetMyBaseData()
    this.GuildBaseInfoAdapter(this.myGuild, myGuildData)
end

-- 公会基础数据匹配
function this.GuildBaseInfoAdapter(node, data)
    local nameText = Util.GetGameObject(node, "name"):GetComponent("Text")
    local levelText = Util.GetGameObject(node, "level"):GetComponent("Text")
    local logoSpr = Util.GetGameObject(node, "icon"):GetComponent("Image")

    nameText.text = data.name
    levelText.text = data.level
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


--界面关闭时调用（用于子类重写）
function GuildFightResultPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildFightResultPopup:OnDestroy()
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

end

return GuildFightResultPopup