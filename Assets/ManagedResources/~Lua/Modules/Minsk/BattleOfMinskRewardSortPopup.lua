require("Base/BasePanel")
BattleOfMinskRewardSortPopup = Inherit(BasePanel)
local this = BattleOfMinskRewardSortPopup
local rewardList = {}
local itemList = {}
local myDemonsItemList = {}
local sorting = 0
--初始化组件（用于子类重写）
function BattleOfMinskRewardSortPopup:InitComponent()
    this.rewardPre = Util.GetGameObject(self.gameObject, "ItemPre")
    local v2 = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "scroll").transform,
            this.rewardPre, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(50,-8  ))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.BackBtn = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.mySortNum = Util.GetGameObject(self.gameObject, "Record/SortNum")
    this.myDemons = Util.GetGameObject(self.gameObject, "Record/Demons")
end

--绑定事件（用于子类重写）
function BattleOfMinskRewardSortPopup:BindEvent()
    Util.AddClick(this.BackBtn, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function BattleOfMinskRewardSortPopup:AddListener()
end

--移除事件监听（用于子类重写）
function BattleOfMinskRewardSortPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BattleOfMinskRewardSortPopup:OnOpen(_curIndex)
    curIndex = _curIndex or 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BattleOfMinskRewardSortPopup:OnShow()
    this.ShowCurIndexRewardData()
    NetManager.RequestRankInfo(RANK_TYPE.GUILD_CAR_DELEAY_SINGLE, function(msg)
        this.SetRankDataShow(msg)
        --repeated UserRank ranks = 1;
        --optional RankInfo myRankInfo = 2;
    end)
end
function BattleOfMinskRewardSortPopup:OnSortingOrderChange()
    sorting = self.sortingOrder
end


function this.SetRankDataShow(msg)
        local sortNumTabs = {}
        for i = 1, 4 do
            sortNumTabs[i] =  Util.GetGameObject(this.mySortNum, "SortNum ("..i..")")
            sortNumTabs[i]:SetActive(false)
        end
        if msg.myRankInfo.rank < 4 and msg.myRankInfo.rank > 0 then
            sortNumTabs[msg.myRankInfo.rank]:SetActive(true)
        else
            sortNumTabs[4]:SetActive(true)
            Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = msg.myRankInfo.rank > 0 and msg.myRankInfo.rank or GetLanguageStrById(10094)
        end
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
    for i = 1, #myDemonsItemList do
        myDemonsItemList[i].gameObject:SetActive(false)
    end
    for i = 1, #myrewardConfig.Reward do
        if myDemonsItemList[i] then
            myDemonsItemList[i]:OnOpen(false, myrewardConfig.Reward[i], 0.8,false,false,false,sorting)
        else
            myDemonsItemList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.myDemons.transform)
            myDemonsItemList[i]:OnOpen(false, myrewardConfig.Reward[i], 0.8,false,false,false,sorting)
        end
        myDemonsItemList[i].gameObject:SetActive(true)
    end
end
--显示奖励
function this.ShowCurIndexRewardData()
    --curIndex
    rewardList = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.WorldBossRewardConfig)) do
        if configInfo.Type == 2 then
            table.insert(rewardList,configInfo)
        end
    end
    this.ScrollView:SetData(rewardList, function (index, go)
        this.SingleRewardDataShow(go, rewardList[index],index)
    end)
end
function this.SingleRewardDataShow(go,rewardConfig,index)
    if not itemList[go.name] then
        itemList[go.name] = {}
    end
    for i = 1, #itemList[go.name] do
        itemList[go.name][i].gameObject:SetActive(false)
    end
    for i = 1, #rewardConfig.Reward do
        if itemList[go.name][i] then
            itemList[go.name][i]:OnOpen(false, rewardConfig.Reward[i], 0.8,false,false,false,sorting)
        else
            itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "Demons").transform)
            itemList[go.name][i]:OnOpen(false, rewardConfig.Reward[i], 0.8,false,false,false,sorting)
        end
        itemList[go.name][i].gameObject:SetActive(true)
    end
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(go, "SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if index < 4 then
        sortNumTabs[rewardConfig.Section[1]]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        local str = "+"
        if rewardConfig.Section[2] > 1 then
            str = "-"..rewardConfig.Section[2]
        end
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rewardConfig.Section[1]..str
    end
end
--界面关闭时调用（用于子类重写）
function BattleOfMinskRewardSortPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function BattleOfMinskRewardSortPopup:OnDestroy()
    itemList = {}
    myDemonsItemList = {}
end

return BattleOfMinskRewardSortPopup