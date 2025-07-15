require("Base/BasePanel")
local MapFightResultPopup = Inherit(BasePanel)
local this = MapFightResultPopup

-- 头像对象管理
local _PlayerHeadList = {}

--初始化组件（用于子类重写）
function MapFightResultPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.scrollRoot = Util.GetGameObject(self.transform, "content/scrollRect")
    this.scrollItem = Util.GetGameObject(self.transform, "content/item")

    this.myRank = Util.GetGameObject(self.transform, "content/bottom/rank/myRank"):GetComponent("Text")
    this.myInjury = Util.GetGameObject(self.transform, "content/bottom/rank/injuryTotal"):GetComponent("Text")

end

--绑定事件（用于子类重写）
function MapFightResultPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
        UIManager.OpenPanel(UIName.TrialBossTipPopup, 8)
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.BackMain)
    end)
end

--添加事件监听（用于子类重写）
function MapFightResultPopup:AddListener()
end

--移除事件监听（用于子类重写）
function MapFightResultPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function MapFightResultPopup:OnOpen(...)
    if not this.ScrollView then
        local hight = this.scrollRoot.transform.rect.height
        local width = this.scrollRoot.transform.rect.width
        -- 设置循滚动组件
        this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,  this.scrollRoot.transform,
                this.scrollItem, nil, Vector2.New(width, hight), 1, 1, Vector2.New(0,0))
        this.ScrollView.moveTween.Strength = 2
    end

    local datalist = FightUIManager.GetPlayerInfo()
    this.ScrollView:SetData(datalist, function(index, go)
        this.RankAdapter(go, datalist[index], index)
    end)

    -- 我得信息展示
    local rank
    for index, data in ipairs(datalist) do
        if data.id == PlayerManager.uid then
            rank = index
            break
        end
    end
    this.myRank.text = rank
    this.myInjury.text = MatchDataManager.GetRewardScore()

end

-- 节点数据匹配
function this.RankAdapter(item, data, index)
    local rankImg = Util.GetGameObject(item, "rank"):GetComponent("Image")
    local rankTxt = Util.GetGameObject(item, "rank/Text"):GetComponent("Text")
    local headRoot = Util.GetGameObject(item, "head")
    local name = Util.GetGameObject(item, "name"):GetComponent("Text")
    local resNum = Util.GetGameObject(item, "res"):GetComponent("Text")
    local killNum = Util.GetGameObject(item, "kill"):GetComponent("Text")
    local score = Util.GetGameObject(item, "score"):GetComponent("Text")

    -- 排名
    local rank = index
    if rank <= 3 then
        rankImg.sprite = Util.LoadSprite("r_playerrumble_paiming_0"..rank)
        rankImg:SetNativeSize()
        rankTxt.gameObject:SetActive(false)
    else
        rankImg:GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        rankImg.transform.sizeDelta = Vector2.New(120, 120)
        rankTxt.text = rank
        rankTxt.gameObject:SetActive(true)
    end
    name.text = data.name
    resNum.text = data.nineralNum
    killNum.text = data.killNum

    local scoreData = FightUIManager.GetFightResultScoreData(data.id)
    local colorStr = scoreData.updateScore > 0 and "#00ff00" or "#ff0000"
    local updateStr = scoreData.updateScore >= 0 and "+"..scoreData.updateScore or scoreData.updateScore
    score.text = string.format("%d (<color=%s>%s</color>)", scoreData.score, colorStr, updateStr)


    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headRoot.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetHead(scoreData.head)
    _PlayerHeadList[item]:SetFrame(scoreData.headFrame)
    _PlayerHeadList[item]:SetLevel(scoreData.level)
    _PlayerHeadList[item]:SetScale(Vector3.one*0.6)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MapFightResultPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function MapFightResultPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function MapFightResultPopup:OnDestroy()
    this.ScrollView = nil
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}
end

return MapFightResultPopup