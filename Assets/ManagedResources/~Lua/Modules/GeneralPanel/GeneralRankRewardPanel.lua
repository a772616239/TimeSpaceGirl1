require("Base/BasePanel")
GeneralRankRewardPanel = Inherit(BasePanel)
local this = GeneralRankRewardPanel
local RewardList
local GloActConfig = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local arenaReward = ConfigManager.GetConfig(ConfigName.ArenaReward)
local godSetting = ConfigManager.GetConfig(ConfigName.GodSacrificeSetting)
local godRewardConfig = ConfigManager.GetConfig(ConfigName.GodSacrificeConfig)
local RewardConfig
local itemList = {}--优化itemView使用
local itemList2 = {}--优化itemView使用
local sorting = 0
local curRankType = 1
local tabNum = 1
local myrank = nil
local ActivityId = nil
local ConfigList = {
    [1] = ConfigManager.GetConfig(ConfigName.ActivityRankingReward),--一般奖励表
    [2] = ConfigManager.GetConfig(ConfigName.GodSacrificeConfig),--次元引擎奖励表
    [3] = ConfigManager.GetConfig(ConfigName.ArenaReward),--竞技场奖励表
}

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabImgData = {select = "cn2-x1_haoyou_biaoqian_xuanzhong", default = "cn2-x1_haoyou_biaoqian_weixuanzhong",}
local _TabData = {
    [1] = {txt = GetLanguageStrById(12422)},
    [2] = {txt = GetLanguageStrById(10107)},
}
local _TabData2 = {
    [1] = {txt = GetLanguageStrById(12423)},
    [2] = {txt = GetLanguageStrById(12424)},
}

--初始化组件（用于子类重写）
function GeneralRankRewardPanel:InitComponent()
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.tabbox = Util.GetGameObject(self.gameObject, "content/tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.myRank = Util.GetGameObject(self.gameObject, "content/myRank")
    this.myRankNum = Util.GetGameObject(self.gameObject, "content/myRank/num"):GetComponent("Text")

    local v2 = Util.GetGameObject(self.gameObject, "content/scrollRect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "content/scrollRect").transform,
        Util.GetGameObject(self.gameObject, "content/itemPre"), nil, Vector2.New(v2.width,v2.height), 1, 1, Vector2.New(10,10))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

end

--绑定事件（用于子类重写）
function GeneralRankRewardPanel:BindEvent()
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)

    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.mask, function()
        self:ClosePanel()
    end)
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local img = Util.GetGameObject(tab, "Image")
    local txt = Util.GetGameObject(tab, "Text")
    img:GetComponent("Image").sprite = Util.LoadSprite(_TabImgData[status])
    if index == 2 and status == "default" then
        img:GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
    end
    if curRankType == 2 then
        txt:GetComponent("Text").text = _TabData2[index].txt
    elseif curRankType == 3 then
        txt:GetComponent("Text").text = _TabData[index].txt
    end
end

-- tab改变回调事件
function this.OnTabChange(index)
    tabNum = index
    if curRankType == 2 then
        this.ShowRewardInfo()
        local type = tabNum == 1 and RANK_TYPE.GOLD_EXPER or RANK_TYPE.CELEBRATION_GUILD
        DynamicActivityManager.SheJiGetRankData(type,ActivityId,function(allRankData,myRankData)
            local rank = myRankData.rank > 0 and myRankData.rank or GetLanguageStrById(10041)
            -- this.text.text = GetLanguageStrById(10104)..rank
        end)
    elseif curRankType == 3 then
        this.ShowRewardInfo()
        -- this.text.text = GetLanguageStrById(12425)
        this.RefreshMyInfo()
    end
end

--添加事件监听（用于子类重写）
function GeneralRankRewardPanel:AddListener()
end

--移除事件监听（用于子类重写）
function GeneralRankRewardPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GeneralRankRewardPanel:OnOpen(Type,myRank,activityId)
    curRankType = Type
    ActivityId = activityId or nil
    myrank = tonumber(myRank)
    RewardConfig = ConfigList[Type]
    this.ShowRewardInfo()
    this.SetMyRank()

    --竞技场和社稷大典的特殊处理
    if curRankType ==  3 then
        this.TabCtrl:Init(this.tabbox, _TabData)
        this.RefreshMyInfo()
    end
    if curRankType ==  2 then
        this.TabCtrl:Init(this.tabbox, _TabData2)
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GeneralRankRewardPanel:OnShow()
end

function GeneralRankRewardPanel:OnSortingOrderChange()
    for i, v in pairs(itemList) do
        for j = 1, #v do
            v[j]:SetEffectLayer(self.sortingOrder)
        end
    end
    for i, v in pairs(itemList2) do
        for j = 1, #v do
            v[j]:SetEffectLayer(self.sortingOrder)
        end
    end

    sorting = self.sortingOrder
end

function this.SetMyRank()
    if myrank and myrank > 0 then
        this.myRank:SetActive(false)
        this.myRankNum.text = GetLanguageStrById(10104)..myrank
    else
        this.myRank:SetActive(false)
    end
end

--如果是竞技场的话显示下面一堆的东西
function this.RefreshMyInfo()
    local sortNumTabs = {}
    local rewardList = {}
    local myInfo = Util.GetGameObject(this.arenaBottom, "myInfo")
    local norank = Util.GetGameObject(this.arenaBottom, "myInfo/myrank")
    norank:SetActive(false)
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(myInfo, "sortNum/sortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if myrank and myrank > 0 then
        if myrank < 4 then
            sortNumTabs[myrank]:SetActive(true)
        else
            sortNumTabs[4]:SetActive(true)
            Util.GetGameObject(sortNumTabs[4], "rankNumberText"):GetComponent("Text").text = myrank
        end

        if not itemList2 then
            itemList2 = {}
        end
        for i = 1, #itemList2 do
            itemList2[i].gameObject:SetActive(false)
        end

        --获取奖励
        if curRankType == 3 then--竞技场
            for k,value in ConfigPairs(arenaReward) do
                if myrank <= 3 then
                    if tabNum == 1 then
                        rewardList = arenaReward[myrank].DailyReward
                    elseif tabNum == 2 then
                        rewardList = arenaReward[myrank].SeasonReward
                    end
                elseif myrank > 3 then
                    if myrank >= value.MinRank and myrank <= value.MaxRank then
                        if tabNum == 1 then
                            rewardList = value.DailyReward
                        elseif tabNum == 2 then
                            rewardList = value.SeasonReward
                        end
                    end
                end
            end
        elseif curRankType == 2 then--社稷大典排行
            local configList = {}
            configList = ConfigManager.GetAllConfigsDataByKey(ConfigName.GodSacrificeConfig,"RewardType",tabNum)
            for i = 1, #configList do
                if myrank <= 3 then
                    rewardList = configList[myrank].RankingReward
                elseif myrank > 3 then
                    if myrank >= configList[i].MinRank and myrank <= configList[i].MaxRank then
                        rewardList = configList[i].RankingReward
                    end
                end
            end
        end

        --显示奖励
        for i = 1, #rewardList do
            if itemList2[i] then
                itemList2[i]:OnOpen(false, rewardList[i], 0.9,false,false,false,sorting)
            else
                itemList2[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(myInfo, "content").transform)
                itemList2[i]:OnOpen(false,  rewardList[i], 0.9,false,false,false,sorting)
            end
            itemList2[i].gameObject:SetActive(true)
        end
    else
        norank:SetActive(true)
        norank:GetComponent("Text").text = GetLanguageStrById(10041)
    end
end

function this.ShowRewardInfo()
    RewardList = {}
    if curRankType == 1 then--活动类的排行榜
        for _, configInfo in ConfigPairs(RewardConfig) do
            if configInfo.ActivityId == ActivityId then
                table.insert(RewardList,configInfo)
            end
        end

        this.ScrollView:SetData(RewardList, function (index, go)
            this.ActivityRewardSingleShow(go, RewardList[index])
        end)

    elseif curRankType == 3 then--非活动类的排行榜（竞技场）
        for _, configInfo in ConfigPairs(RewardConfig) do
            table.insert(RewardList,configInfo)
        end

        this.ScrollView:SetData(RewardList, function (index, go)
            this.ActivityRewardSingleShow(go, RewardList[index])
        end)

    elseif curRankType == 2 then--次元引擎
        local configList = {}
        configList = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.GodSacrificeConfig,"ActivityId",ActivityId,"RewardType",tabNum)
        this.ScrollView:SetData(configList, function (index, go)
            this.ActivityRewardSingleShow(go, configList[index])
        end)
    end
 end

--一般奖励-单列
function this.ActivityRewardSingleShow(go, data)
    go:SetActive(true)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(go, "sortNum/sortNum"..i)
        sortNumTabs[i]:SetActive(false)
    end

    if data.MaxRank == data.MinRank then
        if data.MinRank < 4 then
            sortNumTabs[data.MaxRank]:SetActive(true)
        else
            sortNumTabs[4]:SetActive(true)
            Util.GetGameObject(sortNumTabs[4], "rankNumberText"):GetComponent("Text").text = data.MinRank
        end
    else
        sortNumTabs[4]:SetActive(true)
        if data.MaxRank > 100 then
            Util.GetGameObject(sortNumTabs[4], "rankNumberText"):GetComponent("Text").text = data.MinRank-1 .."+"
        else
            Util.GetGameObject(sortNumTabs[4], "rankNumberText"):GetComponent("Text").text = data.MinRank.."-"..data.MaxRank
        end
    end
    if not itemList[go.name] then
        itemList[go.name] = {}
    end
    for i = 1, #itemList[go.name] do
        itemList[go.name][i].gameObject:SetActive(false)
    end

    if curRankType == 2 then
        if data.BasLineScore > 0 then
            Util.GetGameObject(go, "Text"):GetComponent("Text").text = GetLanguageStrById(50207)..data.BasLineScore
        else
            Util.GetGameObject(go, "Text"):GetComponent("Text").text = ""
        end
    else
        Util.GetGameObject(go, "Text"):GetComponent("Text").text = ""
    end

    if curRankType == 3 then--判断是否是竞技场
        if tabNum == 1 then
            for i = 1, #data.DailyReward do
                if itemList[go.name][i] then
                    itemList[go.name][i]:OnOpen(false, data.DailyReward[i], 0.6,false,false,false,sorting)
                else
                    itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "content").transform)
                    itemList[go.name][i]:OnOpen(false,  data.DailyReward[i], 0.6,false,false,false,sorting)
                end
                itemList[go.name][i].gameObject:SetActive(true)
            end
        elseif tabNum == 2 then
            for i = 1, #data.SeasonReward do
                if itemList[go.name][i] then
                    itemList[go.name][i]:OnOpen(false, data.SeasonReward[i], 0.6,false,false,false,sorting)
                else
                    itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "content").transform)
                    itemList[go.name][i]:OnOpen(false,  data.SeasonReward[i], 0.6,false,false,false,sorting)
                end
                itemList[go.name][i].gameObject:SetActive(true)
            end
        end
    else
        for i = 1, #data.RankingReward do
            if itemList[go.name][i] then
                itemList[go.name][i]:OnOpen(false, data.RankingReward[i], 0.6,false,false,false,sorting)
            else
                itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "content").transform)
                itemList[go.name][i]:OnOpen(false, data.RankingReward[i], 0.6,false,false,false,sorting)
            end
            itemList[go.name][i].gameObject:SetActive(true)
        end
    end
end

--界面关闭时调用（用于子类重写）
function GeneralRankRewardPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function GeneralRankRewardPanel:OnDestroy()
    itemList = {}
    itemList2 = {}
end

return GeneralRankRewardPanel