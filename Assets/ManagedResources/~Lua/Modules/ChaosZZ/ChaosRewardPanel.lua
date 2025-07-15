--混乱之治奖励相关
local this = {}
local sortingOrder = 0
function this:InitComponent(gameObject)
    --topinfo
   -- this.titleBg = Util.GetGameObject(gameObject, "Top/TitleBg"):GetComponent("Image")
    this.gameObject = Util.GetGameObject(gameObject, "RewardPanel")
    
    this.scroll = Util.GetGameObject(this.gameObject, "Content/Panel/MyBattleScrollView")
    this.prefab = Util.GetGameObject(this.gameObject, "Content/RewardItem")
    local v2 = this.scroll.transform.rect
    --阵营
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(5, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    --每日
    this.scroll2 = Util.GetGameObject(this.gameObject, "Content/Panel/MyBattleScrollView2")
    this.scrollViewEvery = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll2.transform,
    this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(5, 5))
    this.scrollViewEvery.moveTween.MomentumAmount = 1
    this.scrollViewEvery.moveTween.Strength = 2

    --rank 
    this.scroll3 = Util.GetGameObject(this.gameObject, "Content/Panel/MyBattleScrollView3")
    this.scrollViewRank = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll3.transform,
    this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(5, 5))
    this.scrollViewRank.moveTween.MomentumAmount = 1
    this.scrollViewRank.moveTween.Strength = 2

    this.campItemList ={}  --camp  Item
    this.everyDayItemList ={}  --everyDay  Item
    this.rankItemList ={}  --Rank  Item
    this.myRewardList ={}  --Rank  Item
    this.campBtn =Util.GetGameObject(this.gameObject, "Top/switchBtn/CampBtn")
    this.campBtnSelect =Util.GetGameObject(this.gameObject, "Top/switchBtn/CampBtn/Select")
    this.everyDayBtn=Util.GetGameObject(this.gameObject, "Top/switchBtn/EveryDayRankBtn")
    this.everyDayBtnSelect=Util.GetGameObject(this.gameObject, "Top/switchBtn/EveryDayRankBtn/Select")

    this.rankBtn=Util.GetGameObject(this.gameObject, "Top/switchBtn/RankBtn")
    this.rankBtnSelect=Util.GetGameObject(this.gameObject, "Top/switchBtn/RankBtn/Select")

    --myRewardItems
    this.myContent=Util.GetGameObject(this.gameObject, "Bottom/myReward/content") 
    this.item1=Util.GetGameObject(this.gameObject, "Bottom/myReward/content/RewardItem1") 
    this.item2=Util.GetGameObject(this.gameObject, "Bottom/myReward/content/RewardItem2") 
    this.item3=Util.GetGameObject(this.gameObject, "Bottom/myReward/content/RewardItem3") 
    -- myInfo  2A2333
    this.myRankIcon=Util.GetGameObject(this.gameObject, "Bottom/myReward/RankIcon/rank"):GetComponent("Image")
    this.myRankText=Util.GetGameObject(this.gameObject, "Bottom/myReward/RankIcon/rankText/Text"):GetComponent("Text")
    this.tips=Util.GetGameObject(this.gameObject, "Bottom/myReward/Tips")
    this.rankTips=Util.GetGameObject(this.gameObject, "Bottom/myReward/Tips/BottomText"):GetComponent("Text")
    this.myRankIcon.gameObject:SetActive(false)
     this.myRankText.gameObject:SetActive(false)
     this.tips.gameObject:SetActive(false)
end
--显示items  index 对应type
function this:SetScroll(data)
    this.scroll2.gameObject:SetActive(false)   
    this.scroll.gameObject:SetActive(true)    
    this.scroll3.gameObject:SetActive(false)     
    this.scrollView:SetData(data, function(index, root)
        this:SetScrollItem(root, data[index], index)
    end)
end

function this:SetScrollEvery(data)
    this.scroll2.gameObject:SetActive(true)   
    this.scroll.gameObject:SetActive(false)    
    this.scroll3.gameObject:SetActive(false)     
    this.scrollViewEvery:SetData(data, function(index, root)
        this:SetScrollItem(root, data[index], index)
    end)
end
function this:SetScrollRank(data)
    this.scroll2.gameObject:SetActive(false)   
    this.scroll.gameObject:SetActive(false)    
    this.scroll3.gameObject:SetActive(true)     
    this.scrollViewRank:SetData(data, function(index, root)
        this:SetScrollItem(root, data[index], index)
    end)
end
function this:SetScrollItem(go, data, index)
   -- local rewardConfig = ChaosManager:GetRewardConfigConfigData()

    local  rewards = data
    if rewards.Type ~= 4 and rewards.Type~=2 then
        this:SetLeftRankImg(go,rewards.Param1,rewards.Param2)
    elseif rewards.Type == 4 then
       -- Log("_______________id " ..rewards.Id.."    "..rewards.Param3[1][1])--.. "    parm3"..rewards.Param3)
        this:SetLeftRankImg(go,rewards.Param2,rewards.Param3[1][1])

    end
    
    local itemGroup =Util.GetGameObject(go, "content")
 
    if rewards.Type == 1 then
       --滚动条复用重设itemview
        if this.campItemList[go] then
            for i = 1, 4 do
                this.campItemList[go][i].gameObject:SetActive(false)
            end
            for i = 1, #rewards.Reward do
                if this.campItemList[go][i] then
                    this.campItemList[go][i]:OnOpen(false, {rewards.Reward[i][1],rewards.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                    this.campItemList[go][i].gameObject:SetActive(true)
                end
            end
        else
            this.campItemList[go] = {}
            for i = 1, 4 do
                this.campItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
                this.campItemList[go][i].gameObject:SetActive(false)
            end
            for i = 1, #rewards.Reward do
                this.campItemList[go][i]:OnOpen(false, {rewards.Reward[i][1],rewards.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.campItemList[go][i].gameObject:SetActive(true)
            end
        end  
        this.rankTips.text = GetLanguageStrById(50374)
     elseif rewards.Type == 3 then
        --滚动条复用重设itemview
        if this.everyDayItemList[go] then
            for i = 1, 4 do
                this.everyDayItemList[go][i].gameObject:SetActive(false)
            end
            for i = 1, #rewards.Reward do
                if this.everyDayItemList[go][i] then
                    this.everyDayItemList[go][i]:OnOpen(false, {rewards.Reward[i][1],rewards.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                    this.everyDayItemList[go][i].gameObject:SetActive(true)
                end
            end
        else
            this.everyDayItemList[go] = {}
            for i = 1, 4 do
                this.everyDayItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
                this.everyDayItemList[go][i].gameObject:SetActive(false)
            end
            for i = 1, #rewards.Reward do
                this.everyDayItemList[go][i]:OnOpen(false, {rewards.Reward[i][1],rewards.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.everyDayItemList[go][i].gameObject:SetActive(true)
            end
        end 
        this.rankTips.text = GetLanguageStrById(50373)
    elseif rewards.Type == 4 then 
        --滚动条复用重设itemview
        if this.rankItemList[go] then
            for i = 1, 4 do
                this.rankItemList[go][i].gameObject:SetActive(false)
            end
            for i = 1, #rewards.Reward do
                if this.rankItemList[go][i] then
                    this.rankItemList[go][i]:OnOpen(false, {rewards.Reward[i][1],rewards.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                    this.rankItemList[go][i].gameObject:SetActive(true)
                end
            end
        else
            this.rankItemList[go] = {}
            for i = 1, 4 do
                this.rankItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
                this.rankItemList[go][i].gameObject:SetActive(false)
            end
            for i = 1, #rewards.Reward do
                this.rankItemList[go][i]:OnOpen(false, {rewards.Reward[i][1],rewards.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.rankItemList[go][i].gameObject:SetActive(true)
            end
        end 
        this.rankTips.text = GetLanguageStrById(50374)
    end
    

end
--设置左边信息 
function this:SetLeftRankImg(go,max,min)
    local rankImg = Util.GetGameObject(go, "RankImg"):GetComponent("Image")
    local rankText = Util.GetGameObject(go, "rankText")
    if max == min then
        rankText.gameObject:SetActive(false)
        rankImg.gameObject:SetActive(true)
        rankImg.sprite = this:GetRankImg(min)
    else
        rankText.gameObject:SetActive(true)
        rankImg.gameObject:SetActive(false)
        
        local minText = Util.GetGameObject(go, "rankText/MinText"):GetComponent("Text")
        local maxText = Util.GetGameObject(go, "rankText/MaxText"):GetComponent("Text")
        minText.text= max
        maxText.text = min
    end
end
--设置我的排名 
function this:SetMyRankReward(type,number)
     local config = ChaosManager:GetRewardConfigConfigData()
     local data = {}
     if type == 3 then
        for _, configInfo in ConfigPairs(config) do
            if configInfo.Type == 3 then
                table.insert(data,configInfo)
            end
        end
     end
     if type == 1 then
        for _, configInfo in ConfigPairs(config) do
            if configInfo.Type == 1 then
                table.insert(data,configInfo)
            end
        end
     end
     if type == 4 then
        for _, configInfo in ConfigPairs(config) do
            if configInfo.Type == 4 and configInfo.Param1 == ChaosManager.addCamp then
                table.insert(data,configInfo)
            end
        end
     end
     if type == 4 then
        for _key, _value in pairs(data) do
            if number >= _value.Param2 and number<=_value.Param3[1][1]  then
                  if #this.myRewardList ~=0 then
                        for i = 1,  #this.myRewardList do
                            destroy(this.myRewardList[i].gameObject);
                        end
                  end
                        for i = 1, 4 do
                            this.myRewardList[i] = SubUIManager.Open(SubUIConfig.ItemView, self.myContent.transform)
                            this.myRewardList[i].gameObject:SetActive(false)
                        end
                    for i = 1, #_value.Reward do
                        this.myRewardList[i]:OnOpen(false, {_value.Reward[i][1],_value.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                        this.myRewardList[i].gameObject:SetActive(true)
                    end
            end
         end
     else
        for key, value in pairs(data) do
            if number >= value.Param1 and number<=value.Param2  then
                  if #this.myRewardList ~=0 then
                        for i = 1,  #this.myRewardList do
                            destroy(this.myRewardList[i].gameObject);
                        end
                  end
                        for i = 1, 4 do
                            this.myRewardList[i] = SubUIManager.Open(SubUIConfig.ItemView, self.myContent.transform)
                            this.myRewardList[i].gameObject:SetActive(false)
                        end
                    for i = 1, #value.Reward do
                        this.myRewardList[i]:OnOpen(false, {value.Reward[i][1],value.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                        this.myRewardList[i].gameObject:SetActive(true)
                    end
            end
         end
     end
    
     this.myRankIcon.gameObject:SetActive(true)
     this.myRankText.gameObject:SetActive(false)
     this.tips.gameObject:SetActive(true)
     if number == 1 then
        this.myRankIcon.sprite = Util.LoadSprite("cn2-X1_tongyong_diyi")
     elseif number == 2 then
        this.myRankIcon.sprite = Util.LoadSprite("cn2-X1_tongyong_dier")
     elseif number == 3 then
        this.myRankIcon.sprite = Util.LoadSprite("cn2-X1_tongyong_disan")
     elseif  number == 0 then
        -- local RankText=Util.GetGameObject(this.gameObject, "Bottom/myReward/RankIcon/rankText")
        -- RankText:SetActive(true)
        -- body
        this.myRankIcon.gameObject:SetActive(false)
        this.myRankText.gameObject:SetActive(true)
        this.myRankText.text = "未上榜"
        this.tips.gameObject:SetActive(false)
     else
        local RankText=Util.GetGameObject(this.gameObject, "Bottom/myReward/RankIcon/rankText")
        RankText:SetActive(true)
        this.myRankText.gameObject:SetActive(true)
        this.myRankIcon.gameObject:SetActive(false)
        this.myRankText.text = number
     end
end

function this:GetRankImg(index)
    if index == 1 then
     return   Util.LoadSprite("cn2-X1_tongyong_diyi")  
    elseif index == 2 then
      return  Util.LoadSprite("cn2-X1_tongyong_dier")  
    elseif index == 3 then
       return Util.LoadSprite("cn2-X1_tongyong_disan")  
    end
    return nil
end
function this:BindEvent()
    Util.AddClick(this.campBtn, function()
        if ChaosManager:GetIsOpen() then
            this:RefreshRankData(1)
        end
        
    end)
    Util.AddClick(this.everyDayBtn, function()
        if ChaosManager:GetIsOpen() then
            NetManager.CampWarRankingListInfoGetReq(1,function (msg)
                if msg.rankingListInfo then
                    this:RefreshRankData(3,msg.rankingListInfo.selfRank)
                else
                    Log("排行榜返回msg.rankingListInfo   nil")
                end
            end)
        end
       
       
    end)
    Util.AddClick(this.rankBtn, function()
        if ChaosManager:GetIsOpen() then
            NetManager.CampWarRankingListInfoGetReq(2,function (msg)
                if msg.rankingListInfo then
                    --Log("msg.rankingListInfo.SelfRank          "..msg.rankingListInfo.selfRank)
                    --Log("msg.rankingListInfo.selfScore          "..msg.rankingListInfo.selfScore)
                    this:RefreshRankData(4,msg.rankingListInfo.selfRank)
                else
                    Log("排行榜返回msg.rankingListInfo   nil")
                end
            end) 
        end 
    end)
end
function this:RefreshRankData(index,myrank)
    this:SwitchBtns(index)
    this:SwitchView(index)
    if index == 1 then
        this:SetMyRankReward(index,ChaosManager.MyCampRank)
    else
        this:SetMyRankReward(index,myrank)
    end
end
function this:SwitchView(index)
    local rewardConfig =  ChaosManager:GetRewardConfigConfigData()
    local data = {}
    
    for _, configInfo in ConfigPairs(rewardConfig) do
        if index == 1 then
            if configInfo.Type == 1 then
                table.insert(data,configInfo)
            end
        end
        if index == 3 then
            if configInfo.Type == 3 then
                table.insert(data,configInfo)
            end
        end
        
        if index == 4  then
            if configInfo.Type == 4 and configInfo.Param1 == ChaosManager.addCamp then
                table.insert(data,configInfo)
            end
        end
    end

    if index == 1 then
        this:SetScroll(data)
    elseif index == 3 then
        this:SetScrollEvery(data)
    elseif index == 4 then
        this:SetScrollRank(data)
    end
   
end
--按钮状态切换
function this:SwitchBtns(index)
    if index == 1 then
        this.everyDayBtnSelect:SetActive(false)
        this.rankBtnSelect:SetActive(false)
        this.campBtnSelect:SetActive(true)
        this:SetBtnShowLayer(1)
    elseif index==3 then
        this.everyDayBtnSelect:SetActive(true)
        this.rankBtnSelect:SetActive(false)
        this.campBtnSelect:SetActive(false)
        this:SetBtnShowLayer(3)
    elseif index==4 then
        this.everyDayBtnSelect:SetActive(false)
        this.rankBtnSelect:SetActive(true)
        this.campBtnSelect:SetActive(false)
        this:SetBtnShowLayer(4)
    end
end
--1 阵营   2每日  3
function this:SetBtnShowLayer(index)
    if index ==1 then
        this.campBtn.transform:SetSiblingIndex(2)
        this.everyDayBtn.transform:SetSiblingIndex(1)
        this.rankBtn.transform:SetSiblingIndex(0)
    elseif index == 3 then
        this.campBtn.transform:SetSiblingIndex(0)
        this.everyDayBtn.transform:SetSiblingIndex(2)
        this.rankBtn.transform:SetSiblingIndex(1)
    elseif index==4 then
        this.campBtn.transform:SetSiblingIndex(1)
        this.everyDayBtn.transform:SetSiblingIndex(0)
        this.rankBtn.transform:SetSiblingIndex(2)
    end
end
function this:RefreshView()
    this:RefreshRankData(1)
    -- NetManager.CampWarRankingListInfoGetReq(1,function (msg)
    --      this:SwitchView(1)
    --      this:SwitchBtns(1)
    --      if msg.rankingListInfo then
    --         --Log("msg.rankingListInfo.SelfRank          "..msg.rankingListInfo.selfRank)
    --         --Log("msg.rankingListInfo.selfScore          "..msg.rankingListInfo.selfScore)
    --         this:SetMyRankReward(msg.rankingListInfo.selfRank)
    --      else
    --         Log("排行榜返回msg.rankingListInfo   nil")
    --      end
    -- end)
end
function this:AddListener()
   
end

function this:RemoveListener()
  
end
function this:OnDestroy()

end

return this
