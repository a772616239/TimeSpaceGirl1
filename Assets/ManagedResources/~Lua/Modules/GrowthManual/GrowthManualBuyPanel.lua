require("Base/BasePanel")
GrowthManualBuyPanel = Inherit(BasePanel)
local this = GrowthManualBuyPanel
--传入特效层级

local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local count = 0 

local rewardStateData = {}
local treasureState--礼包状态
local rewardData--表内活动数据
local rewardData1--表内活动数据
local curType = 0
local type = {
    [1] = {name = GetLanguageStrById(22605),id = 5001,goodsType = GoodsTypeDef.FindBaby},   
}

local id = 0



--初始化组件（用于子类重写）
function GrowthManualBuyPanel:InitComponent()    
    this.mask = Util.GetGameObject(this.gameObject, "mask")
	this.btnBack = Util.GetGameObject(this.gameObject, "content/closeBtn")
    this.dealBtn = Util.GetGameObject(this.gameObject, "content/Button_Buy")    
    this.dealBtnText = Util.GetGameObject(this.dealBtn, "Text"):GetComponent("Text")   
    -- this.Content = Util.GetGameObject(this.gameObject, "rewardPart/Viewport/Content")
    -- this.box1 = Util.GetGameObject(this.Content, "scroll/box")
    this.box2 = Util.GetGameObject(this.gameObject, "content/Image_Content/ScrollView/Viewport/Content")
    -- this.tip = Util.GetGameObject(this.gameObject, "content/Image_Content/Text_Content"):GetComponent("Text")
    this.taskList = {}
end

--绑定事件（用于子类重写）
function GrowthManualBuyPanel:BindEvent()
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddOnceClick(this.dealBtn,function()
        if AppConst.isSDKLogin then
            PayManager.Pay({Id = id}, function(id)
                this:RechargeSuccessFunc()
            end)
        else
            NetManager.RequestBuyGiftGoods(id,function(id)
                this:RechargeSuccessFunc()
            end)
        end
    end)
end

function GrowthManualBuyPanel:OnSortingOrderChange()
end

function GrowthManualBuyPanel:OnOpen()
    curType = 1

    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    local globalActivityConfig = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activityId)

    id = globalActivityConfig.CanBuyRechargeId[1]
end

-- 打开，重新打开时回调
function GrowthManualBuyPanel:OnShow()         
    if curType == 1 then
        -- rewardData = GrowthManualManager.GetAllRewardData()

        rewardData = GrowthManualManager.GetUnlockReward()

        this:showRewardQinglong()
        -- this.tip.text = GetLanguageStrById(22606)
        -- this.dealBtnIma.gameObject:SetActive(true)
        -- this.dealBtnText.gameObject:SetActive(false)
        local config = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,id)
        this.dealBtnText.text = MoneyUtil.GetMoney(config.Price)
    end
end

--充值成功
function GrowthManualBuyPanel:RechargeSuccessFunc()
    PopupTipPanel.ShowTipByLanguageId(11987)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    OperatingManager.RefreshGiftGoodsBuyTimes(type[curType].goodsType,id)
    if curType == 1 then
        Game.GlobalEvent:DispatchEvent(GameEvent.TreasureOfHeaven.RechargeQinglongSerectSuccess, false, false)
    end
    this:ClosePanel()
end

--直接/间接奖励
function GrowthManualBuyPanel:showRewardQinglong()
    local indirect = {}
    -- for i = 1, #rewardData do
    --     local reward = rewardData[i]
    --     for j = 1,#reward.Reward do 
    --         local id = reward.Reward[j].item[1]
    --         local num = reward.Reward[j].item[2]
    --         if reward.Reward[j].type == 2 then
    --             if not indirect[id] then
    --                 indirect[id] = 0
    --             end
    --             indirect[id] = indirect[id] + num
    --         end
    --     end
    -- end

    for i = 1, #rewardData do
        indirect[i] = {rewardData[i][1], rewardData[i][2]}
    end

    this:SetItem(indirect)
end

function GrowthManualBuyPanel:SetItem(indirect)
    for i = 1,#this.taskList do
        this.taskList[i].gameObject:SetActive(false)
    end
    local index = 1 
    for key, value in pairs(indirect) do
        if not this.taskList[index] then
            local item = SubUIManager.Open(SubUIConfig.ItemView, this.box2.transform)
            this.taskList[index] = item
        end
        this.taskList[index].gameObject:SetActive(true)
        this.taskList[index].gameObject.transform:SetParent(this.box2.transform)
        this.taskList[index].gameObject:GetComponent("RectTransform").localPosition = Vector3.zero
        this.taskList[index]:OnOpen(false,{value[1], value[2]}, 0.7)
        index = index + 1
    end
end

function GrowthManualBuyPanel:AddListener()
end

function GrowthManualBuyPanel:RemoveListener()
end

--界面关闭时调用（用于子类重写）
function GrowthManualBuyPanel:OnClose()
    for i = 1,#this.taskList do
        SubUIManager.Close(this.taskList[i])
    end
    Util.ClearChild(this.box2.transform)
    this.taskList = {}
end

--界面销毁时调用（用于子类重写）
function GrowthManualBuyPanel:OnDestroy()    
    this.taskList = {}
end

return this