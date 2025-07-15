-- local HeavenUnlockExtraRewardPanel = quick_class("HeavenUnlockExtraRewardPanel", BasePanel)
require("Base/BasePanel")
local HeavenUnlockExtraRewardPanel = Inherit(BasePanel)
local this = HeavenUnlockExtraRewardPanel

local rewardStateData = {}
local treasureState--礼包状态
local rewardData--表内活动数据




--初始化组件（用于子类重写）
function HeavenUnlockExtraRewardPanel:InitComponent()
    this.btnBack = Util.GetGameObject(this.transform, "frame/bg/closeBtn")
    this.btnBack2 = Util.GetGameObject(this.transform, "frame")
    this.dealBtn = Util.GetGameObject(this.transform, "frame/bg/dealBtn")
    this.Content = Util.GetGameObject(this.transform, "rewardPart/Viewport/Content")
    this.box1 = Util.GetGameObject(this.Content, "box1")
    this.box2 = Util.GetGameObject(this.Content, "box2")
    this.taskList = {}


end



--绑定事件（用于子类重写）
function HeavenUnlockExtraRewardPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.btnBack2, function()
        this:ClosePanel()
    end)
    Util.AddOnceClick(this.dealBtn,function()
        if AppConst.isSDKLogin then
                PayManager.Pay({Id = 106},function()
                    this:RechargeSuccessFunc()
                end)
        else
            NetManager.RequestBuyGiftGoods(106,function()
                this:RechargeSuccessFunc()
            end)
        end
    end)
end

function HeavenUnlockExtraRewardPanel:OnSortingOrderChange()
end

--界面打开时调用（用于子类重写）
function HeavenUnlockExtraRewardPanel:OnOpen(...)
end

-- 打开，重新打开时回调
function HeavenUnlockExtraRewardPanel:OnShow()

    rewardStateData = TreasureOfHeavenManger.GetState()
    rewardData = TreasureOfHeavenManger.GetAllRewardData()

    HeavenUnlockExtraRewardPanel:showReward()

end

--充值成功
function HeavenUnlockExtraRewardPanel:RechargeSuccessFunc()
    PopupTipPanel.ShowTipByLanguageId(11987)
    FirstRechargeManager.RefreshAccumRechargeValue(106)
    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.TreasureOfHeaven,106)

    TreasureOfHeavenManger.SetTreasureState()
    Game.GlobalEvent:DispatchEvent(GameEvent.TreasureOfHeaven.RechargeSuccess)
    this:ClosePanel()

end

--直接/间接奖励
function HeavenUnlockExtraRewardPanel:showReward()

    local direct = {}
    local indirect ={}

    for i = 1, #rewardData do
        if rewardStateData[i].state == 1 then--已达成但不能领取的
            -- body
            local reward = rewardData[i]
            local k1 = reward.TreasureReward[1][1]
            local v1 = reward.TreasureReward[1][2]
            local k2 = reward.TreasureReward[2][1]
            local v2 = reward.TreasureReward[2][2]

            if not direct[k1] then
                direct[k1] = 0
            end
            direct[k1] = direct[k1] + v1

            if not direct[k2] then
                direct[k2] = 0
            end
            direct[k2] = direct[k2] + v2

        elseif rewardStateData[i].state == 0 then--未达成且不能领取的
            local reward = rewardData[i]
            local k1 = reward.TreasureReward[1][1]
            local v1 = reward.TreasureReward[1][2]
            local k2 = reward.TreasureReward[2][1]
            local v2 = reward.TreasureReward[2][2]

            if not indirect[k1] then
                indirect[k1] = 0
            end
            indirect[k1] = indirect[k1] + v1

            if not indirect[k2] then
                indirect[k2] = 0
            end
            indirect[k2] = indirect[k2] + v2
        end
        
    end

    if #this.taskList == 0 then
        for key, value in pairs(direct) do
            local item = SubUIManager.Open(SubUIConfig.ItemView, this.box1.transform)
            item:OnOpen(false,{key, value},0.9)
            table.insert(this.taskList,{key, value})
        end

        for key, value in pairs(indirect) do
            local item = SubUIManager.Open(SubUIConfig.ItemView, this.box2.transform)
            item:OnOpen(false,{key, value},0.9)
            table.insert(this.taskList,{key, value})
        end
    end
end


--界面关闭时调用（用于子类重写）
function HeavenUnlockExtraRewardPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function HeavenUnlockExtraRewardPanel:OnDestroy()
end

return HeavenUnlockExtraRewardPanel