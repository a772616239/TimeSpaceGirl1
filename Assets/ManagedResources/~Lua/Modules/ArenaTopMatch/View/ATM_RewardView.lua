local ATM_RewardView = {}
local this = ATM_RewardView
local rewardView = require("Modules/ArenaTopMatch/ArenaTopMatchPanel")
local itemList = {}
---巅峰战奖励
--初始化组件（用于子类重写）
function ATM_RewardView:InitComponent()
    this.btnClose = Util.GetGameObject(self.gameObject,"backBtn")
    this.itemPre = Util.GetGameObject(self.gameObject,"ItemPre")
    this.scorllRoot = Util.GetGameObject(self.gameObject,"ScorllRoot")
    local rootHight = this.scorllRoot.transform.rect.height
    local rootWidth = this.scorllRoot.transform.rect.width
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scorllRoot.transform,
            this.itemPre, nil, Vector2.New(rootWidth, rootHight), 1, 1, Vector2.New(0, 5))
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    --this.ScrollView.gameObject:GetComponent("RectTransform").sizeDelta = Vector2.New(0, 0)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 3

    this.itemList = {}
    this.cursortingOrder = 0
end

--绑定事件（用于子类重写）
function ATM_RewardView:BindEvent()
    Util.AddClick(this.btnClose, function ()
        rewardView.SetRewardViewClose(5)
    end)
end

--添加事件监听（用于子类重写）
function ATM_RewardView:AddListener()
end

--移除事件监听（用于子类重写）
function ATM_RewardView:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ATM_RewardView:OnOpen(...)
    this.RefreshRewardInfo()
end

--界面关闭时调用（用于子类重写）
function ATM_RewardView:OnClose()
end

--界面销毁时调用（用于子类重写）
function ATM_RewardView:OnDestroy()
    itemList = {}
end

--防特效穿透
function ATM_RewardView:OnSortingOrderChange(cursortingOrder)
    this.cursortingOrder = cursortingOrder
    for i, v in pairs(this.itemList) do
        for j = 1, #this.itemList[i] do
            this.itemList[i][j]:SetEffectLayer(cursortingOrder)
        end
    end
end

--刷新奖励信息
function this.RefreshRewardInfo()
    local rewardData = ArenaTopMatchManager.GetRewardData()
    this.scrollView:SetData(rewardData,function(index,root)
        this.SetNodeShow(root,rewardData[index])
    end)
    this.scrollView:SetIndex(1)
end

-- 设置排名所需要的数字框
-- local function SetRewardNumFrame(rankNum)
--     local resPath = rankNumRes[rankNum]
--     local icon = Util.LoadSprite(resPath)
--     return icon
-- end
-- local TitleColor = {
--     Color.New(177/255,91/255,90/255,1),Color.New(169/255,132/255,105/255,1),
--     Color.New(161/255,105/255,168/255,1),Color.New(97/255,124/255,154/255,1)
-- }
local rankNumRes = {
    [1] = "cn2-X1_tongyong_diyi",
    [2] = "cn2-X1_tongyong_dier",
    [3] = "cn2-X1_tongyong_disan",
    [4] = "cn2-X1_jingjichang_shujudiban_06",
}
--设置节点显示
function this.SetNodeShow(root, data)
    -- local content = Util.GetGameObject(root,"Content")
    -- local rankBg = Util.GetGameObject(root,"SortNum/SortBg"):GetComponent("RectTransform")
    -- local rankImage = Util.GetGameObject(root,"SortNum/SortBg"):GetComponent("Image")
    -- local rankText = Util.GetGameObject(root,"SortNum/SortBg/SortText"):GetComponent("Text")
    -- local rankImage = Util.GetGameObject(root,"SortNum/SortBg/Image_Sort"):GetComponent("Image")

    -- if data.Id > 3 then
    --     rankText.gameObject:SetActive(true)
    --     rankImage.gameObject:SetActive(false)
    --     rankText.text = GetLanguageStrById(data.TitleDesc)
    --     rankText.color = data.Id >= 4 and TitleColor[4] or TitleColor[data.Id]
    -- else
    --     rankText.gameObject:SetActive(false)
    --     rankImage.gameObject:SetActive(true)
    --     rankImage.sprite = SetRewardNumFrame(data.Id)
    -- end
    -- if this.itemList[root] then
    --     for i = 1, 5 do
    --         this.itemList[root][i].gameObject:SetActive(false)
    --     end
    --     for i = 1, #data.SeasonReward do
    --         if this.itemList[root][i] then
    --             this.itemList[root][i]:OnOpen(false, {data.SeasonReward[i][1],data.SeasonReward[i][2]}, 0.9,false,false,false,this.cursortingOrder)
    --             this.itemList[root][i].gameObject:SetActive(true)
    --         end
    --     end
    -- else
    --     this.itemList[root] = {}
    --     for i = 1, 5 do
    --         this.itemList[root][i] = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
    --         this.itemList[root][i].gameObject:SetActive(false)
    --     end
    --     for i = 1, #data.SeasonReward do
    --         this.itemList[root][i]:OnOpen(false, {data.SeasonReward[i][1],data.SeasonReward[i][2]}, 0.9,false,false,false,this.cursortingOrder)
    --         this.itemList[root][i].gameObject:SetActive(true)
    --     end
    -- end
    local rankImage = Util.GetGameObject(root, "RankIcon/rank"):GetComponent("Image")
    local rankImage2 = Util.GetGameObject(root, "RankIcon/rankText")
    local rank = Util.GetGameObject(root, "rank"):GetComponent("Text")

    if data.Id <= 3 and data.Id > 0 then
        rankImage.gameObject:SetActive(true)
        rankImage2:SetActive(false)
        rankImage.sprite = Util.LoadSprite(rankNumRes[data.Id])
    elseif data.Id > 3 then
        rankImage.gameObject:SetActive(false)
        rankImage2:SetActive(true)
    end
    rank.text = string.format(GetLanguageStrById(50157), data.Id)

    for i = 1, 2 do
        Util.GetGameObject(root, "rewardNum"..i):GetComponent("Text").text = data.SeasonReward[i][2]
    end

    for i = 1, 2 do
        if not itemList[i] then
            itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(this.gameObject, "reward"..i.."/Pos").transform)
            itemList[i]:OnOpen(false, {data.SeasonReward[i][1], 1}, 0.8)
            itemList[i]:ShowNum(false)
        end
    end
end

return ATM_RewardView