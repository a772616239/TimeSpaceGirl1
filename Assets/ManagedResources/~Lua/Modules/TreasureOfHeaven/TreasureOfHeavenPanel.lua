require("Base/BasePanel")
local TreasureOfHeavenPanel = Inherit(BasePanel)
local this = TreasureOfHeavenPanel
local curScore = 0--当前分数
local rewardStateData = {}
local treasureState = nil
local rewardData--表内活动数据

--初始化组件（用于子类重写）
function TreasureOfHeavenPanel:InitComponent()
    --topBar/btnBack
    this.btnBack = Util.GetGameObject(this.transform, "bg/btnBack")
    this.buyBtn = Util.GetGameObject(this.transform, "bg/topBar/buyBtn")
    this.Text1 = Util.GetGameObject(this.buyBtn, "buy")
    this.Text2 = Util.GetGameObject(this.buyBtn, "hadbuy")
    this.tips = Util.GetGameObject(this.transform, "bg/topBar/tips"):GetComponent("Text")
    this.time = Util.GetGameObject(this.transform, "bg/topBar/tips/actTime"):GetComponent("Text")
    this.quesBtn = Util.GetGameObject(this.transform, "bg/quesBtn")
    this.helpPosition=this.quesBtn:GetComponent("RectTransform").localPosition
    --Content
    this.scoreText = Util.GetGameObject(this.transform, "bg/pageContent/bg/score/number"):GetComponent("Text")
    this.treasureList = Util.GetGameObject(this.transform, "bg/pageContent/treasureList")
    this.itemPre = Util.GetGameObject(this.treasureList, "itemPro")

    --设置滚动条
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.treasureList.transform,this.itemPre,nil,Vector2.New(1080, 1130),1,1,Vector2.New(0, 7)) --m5
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2


end

--绑定事件（用于子类重写）
function TreasureOfHeavenPanel:BindEvent()
    Util.AddClick(this.btnBack,function()
        this:ClosePanel()
    end)
    Util.AddClick(this.quesBtn,function()
        
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.TreasureOfHeaven,this.helpPosition.x,this.helpPosition.y)
    end)
end

function TreasureOfHeavenPanel:OnSortingOrderChange()
end

--添加事件监听（用于子类重写）
function TreasureOfHeavenPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TreasureOfHeaven.RechargeSuccess, self.refresh,self)
end

--移除事件监听（用于子类重写）
function TreasureOfHeavenPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TreasureOfHeaven.RechargeSuccess, self.refresh,self)
end

--界面打开时调用（用于子类重写）
function TreasureOfHeavenPanel:OnOpen(...)
    --初始化数据
   
end

-- 打开，重新打开时回调
function TreasureOfHeavenPanel:OnShow()
    this.tips.text = GetLanguageStrById(11988)
    this.time.text=TimeToDHMS(TreasureOfHeavenManger.GetLimitTime()-GetTimeStamp())
    TreasureOfHeavenPanel:ShowTime()
    TreasureOfHeavenPanel:refresh()
end

function TreasureOfHeavenPanel:refresh()
    rewardData = TreasureOfHeavenManger.GetAllRewardData()
    treasureState = TreasureOfHeavenManger.GetTreasureState()--秘宝礼包状态 0:可购买  1:已购买
    rewardStateData = TreasureOfHeavenManger.GetState()--任务状态
    if #rewardStateData <= 0 then
        NetManager.TreasureOfHeavenScoreRequest(function(msg)
            curScore = TreasureOfHeavenManger.GetScore()--当前分数
            rewardStateData = TreasureOfHeavenManger.GetState()--任务状态

            TreasureOfHeavenPanel:topBar()
            TreasureOfHeavenPanel:showTaskList()
         end)
    else
        curScore = TreasureOfHeavenManger.GetScore()--当前分数
        TreasureOfHeavenPanel:topBar()
        TreasureOfHeavenPanel:showTaskList()
    end
end

--topBar按钮状态
function TreasureOfHeavenPanel:topBar()
    --设置礼包购买按钮状态
    this.buyBtn:GetComponent("Button").interactable = treasureState == 0
    this.Text1.gameObject:SetActive(treasureState == 0)
    this.Text2.gameObject:SetActive(treasureState == 1)

    if treasureState == 0 then
        Util.AddOnceClick(this.buyBtn,function()
            UIManager.OpenPanel(UIName.HeavenUnlockExtraRewardPanel)
        end)
    end

    this.scoreText.text = curScore
end


--任务列表
function TreasureOfHeavenPanel:showTaskList()
    this.ScrollView:SetData(rewardData,function(index, rewardItem)
        TreasureOfHeavenPanel:SingleTask(rewardItem, rewardData[index])
    end)

    --定位打开界面时位置
    local t = 0
    if treasureState == 0 then
        for i = 1, #rewardStateData do
            if rewardStateData[i].state == 0 then
                t = i
                break
            end
        end
    elseif treasureState == 1 then
        for i = 1, #rewardStateData do
            if rewardStateData[i].state == 1 or rewardStateData[i].state == 0 then
                t = i
                break
            end
        end
    end
    this.ScrollView:SetIndex(t-2)
end

local itemsList={}
--单个任务
function TreasureOfHeavenPanel:SingleTask(rewardItem, rewardSingleData)
    local scoreLevel = Util.GetGameObject(rewardItem, "scoreLevel"):GetComponent("Text")
    local pos1 = Util.GetGameObject(rewardItem, "itemPos_1")
    local pos3 = Util.GetGameObject(rewardItem, "itemPos_3")
    local pos4 = Util.GetGameObject(rewardItem, "itemPos_4")

    if not itemsList[rewardItem] then
        local item1 = SubUIManager.Open(SubUIConfig.ItemView, pos1.transform)
        local item3 = SubUIManager.Open(SubUIConfig.ItemView, pos3.transform)
        local item4 = SubUIManager.Open(SubUIConfig.ItemView, pos4.transform)
        itemsList[rewardItem] ={item1,item3,item4}
    end

    scoreLevel.text = rewardSingleData.Integral
    itemsList[rewardItem][1]:OnOpen(false, {rewardSingleData.Reward[1][1], rewardSingleData.Reward[1][2]}, 0.8, false)
    itemsList[rewardItem][2]:OnOpen(false, {rewardSingleData.TreasureReward[1][1], rewardSingleData.TreasureReward[1][2]}, 0.8, false)
    itemsList[rewardItem][3]:OnOpen(false, {rewardSingleData.TreasureReward[2][1], rewardSingleData.TreasureReward[2][2]}, 0.8, false)

    --初始化按钮状态
    TreasureOfHeavenPanel:InitButtonState(rewardItem, rewardSingleData)
end
--初始化按钮状态
function TreasureOfHeavenPanel:InitButtonState(rewardItem, rewardSingleData)

    local btnDeal = Util.GetGameObject(rewardItem, "btnDeal")
    local get = Util.GetGameObject(rewardItem, "btnDeal/get")
    local getAgain = Util.GetGameObject(rewardItem, "btnDeal/getAgain")
    local unfinished = Util.GetGameObject(rewardItem, "btnDeal/unfinished")
    local finished = Util.GetGameObject(rewardItem, "finished")
    local redPoint = Util.GetGameObject(rewardItem, "btnDeal/redPoint")
    --当前任务领取情况
    local state = rewardStateData[rewardSingleData.Id].state
    --判断
    if curScore >= rewardSingleData.Integral then
        if (state == -1) then
            btnDeal.gameObject:SetActive(false)
            get.gameObject:SetActive(false)
            getAgain.gameObject:SetActive(false)
            unfinished.gameObject:SetActive(false)
            finished.gameObject:SetActive(true)
        elseif (state == 1) then
            btnDeal.gameObject:SetActive(true)
            get.gameObject:SetActive(false)
            getAgain.gameObject:SetActive(true)
            unfinished.gameObject:SetActive(false)
            finished.gameObject:SetActive(false)
        else --rewardSingleData.state == 0
            btnDeal.gameObject:SetActive(true)
            get.gameObject:SetActive(true)
            getAgain.gameObject:SetActive(false)
            unfinished.gameObject:SetActive(false)
            finished.gameObject:SetActive(false)
        end
    else
        btnDeal.gameObject:SetActive(true)
        get.gameObject:SetActive(false)
        getAgain.gameObject:SetActive(false)
        unfinished.gameObject:SetActive(true)
        finished.gameObject:SetActive(false)
    end
    --添加点击事件
    Util.AddOnceClick(btnDeal,function()
        TreasureOfHeavenPanel:OnBtnDealClicked(rewardItem,rewardSingleData)
    end)

    --红点状态
    redPoint:SetActive(TreasureOfHeavenManger.RedPointState(rewardStateData[rewardSingleData.Id],treasureState))

end


--按钮事件
function TreasureOfHeavenPanel:OnBtnDealClicked(rewardItem,rewardSingleData)

    local btnDeal = Util.GetGameObject(rewardItem, "btnDeal")
    local get = Util.GetGameObject(rewardItem, "btnDeal/get")
    local getAgain = Util.GetGameObject(rewardItem, "btnDeal/getAgain")
    local unfinished = Util.GetGameObject(rewardItem, "btnDeal/unfinished")
    local finished = Util.GetGameObject(rewardItem, "btnDeal/finished")

    if curScore >= rewardSingleData.Integral then--分数达到要求
        if (rewardStateData[rewardSingleData.Id].state == 0 and treasureState == 0) or--任务未领取+礼包未购买
        (rewardStateData[rewardSingleData.Id].state == 1 and treasureState == 1) or--任务已领取+礼包已购买
        (rewardStateData[rewardSingleData.Id].state == 0 and treasureState == 1)then--任务未领取+礼包已购买
            NetManager.GetTreasureOfHeavenRewardRequest(rewardStateData[rewardSingleData.Id].id,function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1)
                --需要刷新界面
                if treasureState == 0 then--判断是否已经购买了礼包
                    TreasureOfHeavenManger.SetSingleRewardState(rewardStateData[rewardSingleData.Id].id,1)
                else
                    TreasureOfHeavenManger.SetSingleRewardState(rewardStateData[rewardSingleData.Id].id,-1)
                end
                TreasureOfHeavenPanel:refresh()--刷新界面
            end)
        elseif rewardStateData[rewardSingleData.Id].state == 1 and treasureState == 0 then----任务已领取+礼包未购买（弹出购买界面）
            UIManager.OpenPanel(UIName.HeavenUnlockExtraRewardPanel)
        end
    else--分数未达到要求
        PopupTipPanel.ShowTipByLanguageId(11989)
    end
end

function TreasureOfHeavenPanel:ShowTime()
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    local t = TreasureOfHeavenManger.GetLimitTime()
    local time
    self.localTimer = Timer.New(function()
        time = t-GetTimeStamp()
        if t-GetTimeStamp() <= 0  then
            time = 0
            t = TreasureOfHeavenManger.GetLimitTime()
            treasureState = nil
            TreasureOfHeavenPanel:refresh()
        end
        this.time.text=TimeToDHMS(time)
    end,1,-1,true)
    self.localTimer:Start()
end

--界面关闭时调用（用于子类重写）
function TreasureOfHeavenPanel:OnClose()
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end

--界面销毁时调用（用于子类重写）
function TreasureOfHeavenPanel:OnDestroy()
    rewardStateData = {}
end

return TreasureOfHeavenPanel