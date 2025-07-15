require("Base/BasePanel")
local AlienRankRewardPopup = Inherit(BasePanel)
local this = AlienRankRewardPopup
--初始化组件（用于子类重写）
function AlienRankRewardPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.rankView = Util.GetGameObject(self.transform, "rank")
    this.rewardView = Util.GetGameObject(self.transform, "reward")
    this.rankContentGrid = Util.GetGameObject(self.transform, "rank/scrollRect")
    this.rankItem = Util.GetGameObject(self.transform, "rank/item")
    this.rewardContentGrid = Util.GetGameObject(self.transform, "reward/scrollRect/grid")
    this.rewardItem = Util.GetGameObject(self.transform, "reward/item")
    this.myRank = Util.GetGameObject(self.transform, "rank/bottom/bg/myRank")
    this.injuryTotal = Util.GetGameObject(self.transform, "rank/bottom/bg/injuryTotal")
end

--绑定事件（用于子类重写）
function AlienRankRewardPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function AlienRankRewardPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnInjureRank, this.RefreshRankShow)
end

--移除事件监听（用于子类重写）
function AlienRankRewardPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnInjureRank, this.RefreshRankShow)
end

--界面打开时调用（用于子类重写）
function AlienRankRewardPopup:OnOpen(viewType)
    this._ViewType = viewType
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AlienRankRewardPopup:OnShow()
    this.rankView:SetActive(this._ViewType == "rank")
    this.rewardView:SetActive(this._ViewType == "reward")
    if this._ViewType == "rank" then
        AdventureManager.GetAdventurnInjureRankRequest()
    elseif this._ViewType == "reward" then
        this.RefreshRewardShow()
    end
end

-- 刷新排行界面显示
function this.RefreshRankShow()
    -- 我的信息显示
    if type(AdventureManager.myInfo) ~= "table" or AdventureManager.myInfo.rank <= 0 then
        this.myRank:GetComponent("Text").text = GetLanguageStrById(10041)
        this.injuryTotal:GetComponent("Text").text="0"
    else
        this.myRank:GetComponent("Text").text = AdventureManager.myInfo.rank
        this.injuryTotal:GetComponent("Text").text = AdventureManager.myInfo.hurt
    end

    if not this.rankSV then
        local rootWidth = this.rankContentGrid.transform.rect.width
        local rootHight = this.rankContentGrid.transform.rect.height
        this.rankSV = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rankContentGrid.transform,
                this.rankItem, nil, Vector2.New(rootWidth, rootHight), 1, 1, Vector2.New(0, 0))
        this.rankSV.moveTween.Strength = 2
    end
    this.rankSV:SetData(AdventureManager.adventureRankItemInfo, function(index, item)
        local itemData = AdventureManager.adventureRankItemInfo[index]
        this.InjureRankDataAdapter(item, itemData, index)
    end)
end
--冒险伤害排行榜循环滚动加载数据
function this.InjureRankDataAdapter(item, data, rank)
    --设置表现背景
    if AdventureManager.myInfo.rank==rank then
        Util.GetGameObject(item,"selfBg").gameObject:SetActive(true)
    else
        Util.GetGameObject(item,"selfBg").gameObject:SetActive(false)
    end
    -- 排名
    local rankBg = Util.GetGameObject(item, "rankImage"):GetComponent("Image")
    local rankLab = Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text")
    if rank > 0 and rank <= 3 then
        rankBg.sprite = Util.LoadSprite("r_playerrumble_paiming_0"..rank)
        rankBg:SetNativeSize()
        rankLab.gameObject:SetActive(false)
    else
        rankBg.sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        rankBg.transform.sizeDelta = Vector2.New(120, 120)
        rankLab.text = rank
        rankLab.gameObject:SetActive(true)
    end

    Util.GetGameObject(item, "userHeadQuality/userHeadIcon"):GetComponent("Image").sprite = GetPlayerHeadSprite(data.head)
    Util.GetGameObject(item, "userHeadQuality/headFrame"):GetComponent("Image").sprite = GetPlayerHeadFrameSprite(data.headFrame)
    Util.GetGameObject(item, "userHeadQuality/Image/levelText"):GetComponent("Text").text = data.level
    Util.GetGameObject(item, "userHeadQuality/userNameText"):GetComponent("Text").text = data.name
    Util.GetGameObject(item, "injuryNumber"):GetComponent("Text").text = data.hurt
end

-- 刷新奖励显示
local _RewardItem = {}
local _ItemList = {}
function this.RefreshRewardShow()
    for index = 1, #AdventureManager.minRank do
        local item = _RewardItem[index]
        if not item then
            item = newObjToParent(this.rewardItem, this.rewardContentGrid)
            _RewardItem[index] = item
            item:SetActive(true)
        end
        -- 排名
        local rankBg = Util.GetGameObject(item, "rankImage"):GetComponent("Image")
        local rankLab = Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text")
        local minRank = AdventureManager.minRank[index]
        local maxRank = AdventureManager.maxRank[index]
        if minRank > 0 and minRank <= 3 then
            rankBg.sprite = Util.LoadSprite("r_playerrumble_paiming_0"..minRank)
            rankBg:SetNativeSize()
            rankLab.gameObject:SetActive(false)
        else
            rankBg.sprite = Util.LoadSprite("r_hero_zhuangbeidi")
            if minRank == maxRank then
                rankLab.text = minRank
                rankBg:SetNativeSize()
            elseif index == #AdventureManager.minRank then
                rankLab.text = minRank.."+"
                rankBg.transform.sizeDelta = Vector2.New(320, 152)
            else
                rankLab.text = minRank  .. "-" .. maxRank
                rankBg.transform.sizeDelta = Vector2.New(320, 152)
            end
            rankLab.gameObject:SetActive(true)
        end

        -- 奖励
        local content = Util.GetTransform(item, "content").transform
        for index2, reward in ipairs(AdventureManager.dailyReward[index]) do
            if not _ItemList[index] then
                _ItemList[index] = {}
            end
            local view = _ItemList[index][index2]
            if not view then
                view = SubUIManager.Open(SubUIConfig.ItemView, content)
                _ItemList[index][index2] = view
            end
            view:OnOpen(false, reward, 0.8)
        end
    end
end

--界面关闭时调用（用于子类重写）
function AlienRankRewardPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function AlienRankRewardPopup:OnDestroy()

    for _, list in ipairs(_ItemList) do
        for _, item in ipairs(list) do
            SubUIManager.Close(item)
        end
    end
    _ItemList = {}
    _RewardItem = {}

    this.rankSV = nil
end

return AlienRankRewardPopup