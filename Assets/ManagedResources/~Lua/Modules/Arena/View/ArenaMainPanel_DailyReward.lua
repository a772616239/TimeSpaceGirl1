local ArenaMainPanel_DailyReward = {}
local DAILYREWARD=1
local SEASONREWARD=2
local myViewList={}

local lastRewardIndex = 1

local rewardItemView1
local rewardItemView2
local goList={}

local rewardMyItemView1
local rewardMyItemView2

--初始化组件（用于子类重写）
function ArenaMainPanel_DailyReward:InitComponent()
    
end

--刷新奖励信息
function ArenaMainPanel_DailyReward:SetList(arenaRewardKey, reward)
    --奖励物品
    if not rewardItemView1 then
        local Image_Reward1 = Util.GetGameObject(self.gameObject, "Image_Reward1/Pos")
        local Image_Reward2 = Util.GetGameObject(self.gameObject, "Image_Reward2/Pos")
        rewardItemView1 = SubUIManager.Open(SubUIConfig.ItemView, Image_Reward1.transform)
        rewardItemView2 = SubUIManager.Open(SubUIConfig.ItemView, Image_Reward2.transform)
    end

    rewardItemView1:OnOpen(false, {reward[1][1][1]}, 0.65)
    rewardItemView2:OnOpen(false, {reward[1][2][1]}, 0.65)

    self.item = Util.GetGameObject(self.gameObject, "item")

    for i = 1, #arenaRewardKey do
        local go

        if i <= #goList then
            go = goList[i]
        else
            go = newObject(self.item)
            goList[i] = go
            go:SetActive(true)

            go.transform:SetParent(Util.GetTransform(self.gameObject, "rewardlist/Viewport"))
            go.transform.localScale = Vector3.one
        end

        if i==1 then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.maxRank[i]
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rankText"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_diyi")
        elseif i==2 then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.maxRank[i]
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rankText"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_dier")
        elseif i==3 then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.maxRank[i]
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rankText"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_disan")
        else
            Util.GetGameObject(go, "rank"):SetActive(false)
            Util.GetGameObject(go, "rankText"):SetActive(true)
            if ArenaManager.minRank[i] == ArenaManager.maxRank[i] then
                Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.maxRank[i]
            else
                if ArenaManager.maxRank[i] == 999999 then
                    Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.minRank[i].."+"
                else
                    Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.minRank[i].."-"..ArenaManager.maxRank[i]
                end
            end
        end

        Util.GetGameObject(go, "Text_RewardNum1"):GetComponent("Text").text = reward[i][1][2]
        Util.GetGameObject(go, "Text_RewardNum2"):GetComponent("Text").text = reward[i][2][2]
    end
end

--刷新自己信息
function ArenaMainPanel_DailyReward:SetMy(reward)
    local myReward = Util.GetGameObject(self.gameObject, "myReward")
    self.rank = Util.GetGameObject(myReward, "RankIcon/rankText/Text"):GetComponent("Text")
    self.rankIcon = Util.GetGameObject(myReward, "RankIcon/rank")
    self.desc=Util.GetGameObject(myReward, "tip (1)")
    if(ArenaManager.MyRank.rank ~= -1) then
        if ArenaManager.MyRank.rank == 1 then
            self.rank.gameObject:SetActive(false)
            self.rankIcon:SetActive(true)
            self.rankIcon:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_diyi")
        elseif ArenaManager.MyRank.rank == 2 then
            self.rank.gameObject:SetActive(false)
            self.rankIcon:SetActive(true)
            self.rankIcon:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_dier")
        elseif ArenaManager.MyRank.rank == 3 then
            self.rank.gameObject:SetActive(false)
            self.rankIcon:SetActive(true)
            self.rankIcon:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_disan")
        else
            self.rank.gameObject:SetActive(true)
            self.rankIcon:SetActive(false)
            self.rank.text = ArenaManager.MyRank.rank
        end

        self.desc:SetActive(true)

        for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.ArenaReward)) do
                if configInfo~=nil then
                    if ArenaManager.MyRank.rank <= configInfo.MaxRank and ArenaManager.MyRank.rank >= configInfo.MinRank then
                    self.ArenaRewardData = configInfo
                end
            end
        end

        if not rewardMyItemView1 then
            local Image_Reward1 = Util.GetGameObject(myReward, "Image_Reward1/Pos")
            local Image_Reward2 = Util.GetGameObject(myReward, "Image_Reward2/Pos")
            rewardMyItemView1 = SubUIManager.Open(SubUIConfig.ItemView, Image_Reward1.transform)
            rewardMyItemView2 = SubUIManager.Open(SubUIConfig.ItemView, Image_Reward2.transform)
        end

        rewardMyItemView1:OnOpen(false, {reward[self.ArenaRewardData.Id][1][1]}, 0.55)
        rewardMyItemView2:OnOpen(false, {reward[self.ArenaRewardData.Id][2][1]}, 0.55)

        Util.GetGameObject(myReward, "Text_RewardNum1"):GetComponent("Text").text = reward[self.ArenaRewardData.Id][1][2]
        Util.GetGameObject(myReward, "Text_RewardNum2"):GetComponent("Text").text = reward[self.ArenaRewardData.Id][2][2]
    else
        self.rank.gameObject:SetActive(true)
        self.rankIcon:SetActive(false)
        self.rank.text = GetLanguageStrById(10041)
        self.desc:SetActive(false)
        Util.GetGameObject(myReward, "Text_RewardNum1"):SetActive(false)
        Util.GetGameObject(myReward, "Text_RewardNum2"):SetActive(false)
    end
end

--绑定事件（用于子类重写）
function ArenaMainPanel_DailyReward:BindEvent()
    Util.AddClick(Util.GetGameObject(self.gameObject, "tab/Button_Unselect1"), function ()
        ArenaMainPanel_DailyReward:SwitchRewardPanel(1)
    end)
    Util.AddClick(Util.GetGameObject(self.gameObject, "tab/Button_Unselect2"), function ()
        ArenaMainPanel_DailyReward:SwitchRewardPanel(2)
    end)
end

--切换周奖励和赛季奖励
function ArenaMainPanel_DailyReward:SwitchRewardPanel(index)
    lastRewardIndex = index

    local select = Util.GetGameObject(self.gameObject, "tab/Select")
    local Button_Unselect1 = Util.GetGameObject(self.gameObject, "tab/Button_Unselect1")
    local Button_Unselect2 = Util.GetGameObject(self.gameObject, "tab/Button_Unselect2")

    if index == 1 then
        select.transform.localPosition = Button_Unselect1.transform.localPosition
        Util.GetGameObject(select, "Button_Select/Text"):GetComponent("Text").text = Util.GetGameObject(Button_Unselect1, "Text"):GetComponent("Text").text
        Util.GetGameObject(select, "Button_Select/Image_Icon"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_jingjichang_richangjiangli")

        ArenaMainPanel_DailyReward:SetList(ArenaManager.arenaRewardKey, ArenaManager.dailyReward)
        ArenaMainPanel_DailyReward:SetMy(ArenaManager.dailyReward)
    else
        select.transform.localPosition = Button_Unselect2.transform.localPosition
        Util.GetGameObject(select, "Button_Select/Text"):GetComponent("Text").text = Util.GetGameObject(Button_Unselect2, "Text"):GetComponent("Text").text
        Util.GetGameObject(select, "Button_Select/Image_Icon"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_jingjichang_paihangjiangli")
        
        ArenaMainPanel_DailyReward:SetList(ArenaManager.arenaRewardKey, ArenaManager.seasonReward)
        ArenaMainPanel_DailyReward:SetMy(ArenaManager.seasonReward)
    end
end

--添加事件监听（用于子类重写）
function ArenaMainPanel_DailyReward:AddListener()
end

--移除事件监听（用于子类重写）
function ArenaMainPanel_DailyReward:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ArenaMainPanel_DailyReward:OnOpen(...)
    self:SwitchRewardPanel(lastRewardIndex)
end

--界面关闭时调用（用于子类重写）
function ArenaMainPanel_DailyReward:OnClose()
    rewardItemView1 = nil
    rewardItemView2 = nil
end

--界面销毁时调用（用于子类重写）
function ArenaMainPanel_DailyReward:OnDestroy()
    goList = {}
    rewardMyItemView1 = nil
    rewardMyItemView2 = nil
end

return ArenaMainPanel_DailyReward