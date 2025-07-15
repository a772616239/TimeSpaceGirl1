require("Base/BasePanel")
BattleOfMinskHurtSortPopup = Inherit(BasePanel)
local this = BattleOfMinskHurtSortPopup
local sorting = 0
local _PlayerHeadList = {}
local sortImage = {
    "cn2-X1_tongyong_diyi",
    "cn2-X1_tongyong_dier",
    "cn2-X1_tongyong_disan"
}
local gridImage = {
    "cn2-X1_tongyong_fenlan_weixuanzhong",
    "cn2-X1_tongyong_fenlan_yixuanzhong"
}

--初始化组件（用于子类重写）
function BattleOfMinskHurtSortPopup:InitComponent()
    this.rankBtn = Util.GetGameObject(self.gameObject, "box/rank")
    this.rewardBtn = Util.GetGameObject(self.gameObject, "box/reward")
    this.rankSelect = Util.GetGameObject(self.gameObject, "box/rankSelect")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    this.RankPanel = Util.GetGameObject(self.gameObject, "RankPanel")
    this.myRank = Util.GetGameObject(this.RankPanel, "myRank")
    this.rankPre = Util.GetGameObject(this.RankPanel, "ItemPrefab")
    this.rankScroll = Util.GetGameObject(this.RankPanel, "scroll")
    local rankv2 = this.rankScroll:GetComponent("RectTransform").rect
    this.RankScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rankScroll.transform,
        this.rankPre, nil, Vector2.New(rankv2.width, rankv2.height), 1, 1, Vector2.New(0,10))
    this.RankScrollView.moveTween.MomentumAmount = 1
    this.RankScrollView.moveTween.Strength = 1

    this.RewardPanel = Util.GetGameObject(self.gameObject, "RewardPanel")
    this.myReward = Util.GetGameObject(this.RewardPanel, "myReward")
    this.rewardPre = Util.GetGameObject(this.RewardPanel, "ItemPrefab")
    this.rewardScroll = Util.GetGameObject(this.RewardPanel, "scroll")
    local rewardv2 = this.rewardScroll:GetComponent("RectTransform").rect
    this.RewardScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rewardScroll.transform,
        this.rewardPre, nil, Vector2.New(rewardv2.width, rewardv2.height), 1, 1, Vector2.New(0,10))
    this.RewardScrollView.moveTween.MomentumAmount = 1
    this.RewardScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function BattleOfMinskHurtSortPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)

    Util.AddClick(this.rankBtn, function()
        this.ShowRankOrRewardPanel(1)

    end)
    Util.AddClick(this.rewardBtn, function()
        this.ShowRankOrRewardPanel(2)
    end)
end

--添加事件监听（用于子类重写）
function BattleOfMinskHurtSortPopup:AddListener()
end

--移除事件监听（用于子类重写）
function BattleOfMinskHurtSortPopup:RemoveListener()
end

function BattleOfMinskHurtSortPopup:OnSortingOrderChange()
    sorting = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function BattleOfMinskHurtSortPopup:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BattleOfMinskHurtSortPopup:OnShow()
    this.ShowRankOrRewardPanel(1)
end

function this.ShowRankOrRewardPanel(index)
    this.RankPanel:SetActive(index == 1)
    this.RewardPanel:SetActive(index == 2)
    this.rankBtn:SetActive(index == 2)
    this.rankSelect:SetActive(index == 1)
    Util.GetGameObject(this.rewardBtn, "deffect"):SetActive(index == 1)
    Util.GetGameObject(this.rewardBtn, "select"):SetActive(index == 2)

    this.rewardBtn:GetComponent("Image").sprite = Util.LoadSprite(gridImage[index])
    if index == 1 then
        NetManager.RequestRankInfo(RANK_TYPE.GUILD_CAR_DELEAY_SINGLE, function(msg)
            local userRanks = msg.ranks
            if #userRanks > 0 then
                this.RankScrollView:SetData(userRanks, function (index, go)
                    this.RankDataShow(go, userRanks[index],index)
                end)
            end
            this.MyRankDataShow(this.myRank, msg.myRankInfo, msg.myRankInfo.rank)
        end)
    elseif index == 2 then
        this.ShowCurRewardData()
        NetManager.RequestRankInfo(RANK_TYPE.GUILD_CAR_DELEAY_SINGLE, function(msg)
            this.MyRewardDataShow(msg)
        end)
    end
end

--------------------------------------排行--------------------------------------
--显示排名
function this.RankDataShow(go, userInfo, index)
    if userInfo == nil then
        return
    end
    this.playerHead = Util.GetGameObject(go, "head")
    this.playerName = Util.GetGameObject(go, "name"):GetComponent("Text")
    this.playerForce = Util.GetGameObject(go, "force"):GetComponent("Text")
    this.playerBestForce = Util.GetGameObject(go, "bestForce"):GetComponent("Text")

    if not _PlayerHeadList[go] then
        _PlayerHeadList[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.playerHead.transform)
    end
    _PlayerHeadList[go]:Reset()
    _PlayerHeadList[go]:SetScale(Vector3.one * 0.6)
    _PlayerHeadList[go]:SetHead(userInfo.head)
    _PlayerHeadList[go]:SetFrame(userInfo.headFrame)
    _PlayerHeadList[go]:SetLevel(userInfo.level)
    _PlayerHeadList[go]:SetUID(userInfo.uid)

    this.playerName.text = userInfo.userName
    local force = 0
    if userInfo.rankInfo.param1 > 0 then
        force = userInfo.rankInfo.param1
    end
    this.playerForce.text = force
    this.playerBestForce.text = userInfo.rankInfo.param2

    this.SetSortNum(go, index)
end

--显示我的排名
function this.MyRankDataShow(go, myInfo, index)
    local playerHead = Util.GetGameObject(go, "head")
    local playerName = Util.GetGameObject(go, "name"):GetComponent("Text")
    local playerForce = Util.GetGameObject(go, "force"):GetComponent("Text")
    local playerBestForce = Util.GetGameObject(go, "bestForce"):GetComponent("Text")

    if not _PlayerHeadList[go] then
        _PlayerHeadList[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView,playerHead.transform)
    end
    _PlayerHeadList[go]:Reset()
    _PlayerHeadList[go]:SetScale(Vector3.one * 0.6)
    _PlayerHeadList[go]:SetHead(PlayerManager.head)
    _PlayerHeadList[go]:SetFrame(PlayerManager.frame)
    _PlayerHeadList[go]:SetLevel(PlayerManager.level)
    _PlayerHeadList[go]:SetUID(PlayerManager.uid)

    playerName.text = PlayerManager.nickName
    local force = 0
    if myInfo.param1 > 0 then
        force = myInfo.param1 
    end
    playerForce.text = force
    playerBestForce.text = myInfo.param2

    this.SetSortNum(go, index)
end

--设置排名
function this.SetSortNum(go, index)
    local sortNum1 = Util.GetGameObject(go, "SortNum/SortNum1")
    local sortNum2 = Util.GetGameObject(go, "SortNum/SortNum2")
    sortNum1:SetActive(index < 4 and index > 0)
    sortNum2:SetActive(index > 3 or index < 1)

    if sortNum1.activeSelf then
        sortNum1:GetComponent("Image").sprite = Util.LoadSprite(sortImage[index])
    else
        if index < 0 then
            Util.GetGameObject(sortNum2, "TitleText"):GetComponent("Text").text = GetLanguageStrById(10094)
        else
            Util.GetGameObject(sortNum2, "TitleText"):GetComponent("Text").text = index
        end
    end
end

--------------------------------------奖励--------------------------------------
local rewardList = {}
local itemList = {}
local myRewardItemList = {}
--显示奖励
function this.ShowCurRewardData()
    rewardList = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.WorldBossRewardConfig)) do
        if configInfo.Type == 2 then
            table.insert(rewardList,configInfo)
        end
    end
    this.RewardScrollView:SetData(rewardList, function (index, go)
        this.RewardDataShow(go, rewardList[index], index)
    end)
end

function this.MyRewardDataShow(msg)
    this.SetSortNum(this.myReward, msg.myRankInfo.rank)

    local myrewardConfig = nil
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.WorldBossRewardConfig)) do
        if configInfo.Type == 2 then
            table.insert(rewardList,configInfo)
            if not myrewardConfig and msg.myRankInfo.rank <= configInfo.Section[2] and msg.myRankInfo.rank >= configInfo.Section[1] then
                myrewardConfig = configInfo
            end
        end
    end
    if not myrewardConfig then
        myrewardConfig = rewardList[#rewardList]
    end
    --我自己的排名展示
    for i = 1, #myRewardItemList do
        myRewardItemList[i].gameObject:SetActive(false)
    end
    for i = 1, #myrewardConfig.Reward do
        if myRewardItemList[i] then
            myRewardItemList[i]:OnOpen(false, myrewardConfig.Reward[i], 0.55,false,false,false,sorting)
        else
            myRewardItemList[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.myReward, "rewardGrid").transform)
            myRewardItemList[i]:OnOpen(false, myrewardConfig.Reward[i], 0.55,false,false,false,sorting)
        end
        myRewardItemList[i].gameObject:SetActive(true)
    end
end

function this.RewardDataShow(go, rewardConfig, index)
    if not itemList[go.name] then
        itemList[go.name] = {}
    end
    for i = 1, #itemList[go.name] do
        itemList[go.name][i].gameObject:SetActive(false)
    end
    for i = 1, #rewardConfig.Reward do
        if itemList[go.name][i] then
            itemList[go.name][i]:OnOpen(false, rewardConfig.Reward[i], 0.55,false,false,false,sorting)
        else
            itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "rewardGrid").transform)
            itemList[go.name][i]:OnOpen(false, rewardConfig.Reward[i], 0.55,false,false,false,sorting)
        end
        itemList[go.name][i].gameObject:SetActive(true)
    end

    this.SetSortNum2(go, index, rewardConfig.Section)
end

--设置排名
function this.SetSortNum2(go, index, section)
    local sortNum1 = Util.GetGameObject(go, "SortNum/SortNum1")
    local sortNum2 = Util.GetGameObject(go, "SortNum/SortNum2")
    sortNum1:SetActive(index < 4 and index > 0)
    sortNum2:SetActive(index > 3 or index < 1)

    if sortNum1.activeSelf then
        sortNum1:GetComponent("Image").sprite = Util.LoadSprite(sortImage[index])
        Util.GetGameObject(go, "Text"):GetComponent("Text").text = string.format(GetLanguageStrById(50157), index)
    else
        if section then
            local str = "+"
            if section[2] > 1000 then
                str = section[1] .. "+"
            elseif section[2] > 1 then
                str = section[1] .. "~" .. section[2]
            end
            Util.GetGameObject(go, "Text"):GetComponent("Text").text = str
        else
            Util.GetGameObject(sortNum2, "TitleText"):GetComponent("Text").text = index > 0 and index or GetLanguageStrById(10094)
        end
    end
end

--界面关闭时调用（用于子类重写）
function BattleOfMinskHurtSortPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function BattleOfMinskHurtSortPopup:OnDestroy()
end

return BattleOfMinskHurtSortPopup