require("Base/BasePanel")
GuildTranscriptMainPopup = Inherit(BasePanel)
local this = GuildTranscriptMainPopup
local guildCheckpointConfig
local guildCheckpointRank = ConfigManager.GetConfig(ConfigName.GuildCheckpointRank)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local itemList = {}--优化itemView使用
local sorting = 0
--初始化组件（用于子类重写）
function GuildTranscriptMainPopup:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    this.scroll = Util.GetGameObject(self.gameObject, "content1/scrollRect")
    local rect = this.scroll:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        Util.GetGameObject(self.gameObject, "content1/itemPre"), nil, Vector2.New(rect.width,rect.height), 1, 1, Vector2.New(0,5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

    this.Reward1 = Util.GetGameObject(self.gameObject, "content1/reward1/icon"):GetComponent("Image")
    this.Reward2 = Util.GetGameObject(self.gameObject, "content1/reward2/icon"):GetComponent("Image")
end

--绑定事件（用于子类重写）
function GuildTranscriptMainPopup:BindEvent()
    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildTranscriptMainPopup:AddListener()

end

--移除事件监听（用于子类重写）
function GuildTranscriptMainPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function GuildTranscriptMainPopup:OnOpen(chapterId)
    this.ShowTitleChapterInfo(chapterId)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildTranscriptMainPopup:OnShow()

end
function GuildTranscriptMainPopup:OnSortingOrderChange()
    for i, v in pairs(itemList) do
        for j = 1, #v do
            v[j]:SetEffectLayer(self.sortingOrder)
        end
    end
    sorting = self.sortingOrder
end
function this.ShowTitleChapterInfo(chapterId)
    guildCheckpointConfig = {}
    --guildCheckpointRank
    for _, configInfo in ConfigPairs(guildCheckpointRank) do
        if configInfo.GuildCheckpoint == chapterId then
            table.insert(guildCheckpointConfig,configInfo)
        end
    end
    this.ScrollView:SetData(guildCheckpointConfig, function (index, go)
         this.ActivityRewardSingleShow(go, guildCheckpointConfig[index],index)
     end)    
 end

local rewardItemView1
local rewardItemView2
--排名奖励2
function this.ActivityRewardSingleShow(activityRewardGo,rewardData,index)
    activityRewardGo:SetActive(true)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] = Util.GetGameObject(activityRewardGo, "SortNum/SortNum"..i)
        sortNumTabs[i]:SetActive(false)
    end

    if rewardData.MaxRank == rewardData.MinRank then
        if rewardData.MinRank < 4 then
            Util.GetGameObject(activityRewardGo, "rankNumberText"):GetComponent("Text").text = rewardData.MaxRank
            sortNumTabs[rewardData.MaxRank]:SetActive(true)
        else
            sortNumTabs[4]:SetActive(true)
            Util.GetGameObject(activityRewardGo, "rankNumberText"):GetComponent("Text").text = rewardData.MinRank
        end
    else
        sortNumTabs[4]:SetActive(true)
        if rewardData.MinRank < 0 then
            Util.GetGameObject(activityRewardGo, "rankNumberText"):GetComponent("Text").text = rewardData.MaxRank .."+"
        else
            Util.GetGameObject(activityRewardGo, "rankNumberText"):GetComponent("Text").text = rewardData.MaxRank .."~"..  rewardData.MinRank
        end
    end
    if not itemList[activityRewardGo.name] then
        itemList[activityRewardGo.name] = {}
    end
    for i = 1, #itemList[activityRewardGo.name] do
        itemList[activityRewardGo.name][i].gameObject:SetActive(false)
    end
    for i = 1, #rewardData.RankingReward do
        if itemList[activityRewardGo.name][i] then
            itemList[activityRewardGo.name][i]:OnOpen(false, rewardData.RankingReward[i], 0.3,false,false,false,sorting)
        else
            itemList[activityRewardGo.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(activityRewardGo, "content").transform)
            itemList[activityRewardGo.name][i]:OnOpen(false,  rewardData.RankingReward[i], 0.3,false,false,false,sorting)

            Util.GetGameObject(activityRewardGo,"reward" .. i):GetComponent("Text").text = tonumber(rewardData.RankingReward[i][2])
        end
        itemList[activityRewardGo.name][i].gameObject:SetActive(false)
    end
    
    if this.Reward1.sprite == nil then
        this.Reward1.sprite = Util.LoadSprite(GetResourcePath(itemConfig[rewardData.RankingReward[1][1]].ResourceID))
    end
    if this.Reward2.sprite == nil then
        this.Reward2.sprite = Util.LoadSprite(GetResourcePath(itemConfig[rewardData.RankingReward[2][1]].ResourceID))
    end
end
--界面关闭时调用（用于子类重写）
function GuildTranscriptMainPopup:OnClose()
   
end

--界面销毁时调用（用于子类重写）
function GuildTranscriptMainPopup:OnDestroy()
    itemList = {}
end

return GuildTranscriptMainPopup