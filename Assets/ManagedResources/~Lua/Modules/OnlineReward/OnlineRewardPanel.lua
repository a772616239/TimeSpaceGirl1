require("Base/BasePanel")
local OnlineRewardPanel = Inherit(BasePanel)
local this = OnlineRewardPanel
local itemPreList = {} --item预设容器
local orginLayer = 0
local allOnlineReward = {}

function OnlineRewardPanel:InitComponent()
    this.closeBtn = Util.GetGameObject(this.gameObject,"BackMask")    
    this.preViewBtn = Util.GetGameObject(this.gameObject,"show/bg/Image/preview")
    this.hour = Util.GetGameObject(this.gameObject,"show/timeCount/hour"):GetComponent("Text")
    this.min = Util.GetGameObject(this.gameObject,"show/timeCount/min"):GetComponent("Text")
    this.sec = Util.GetGameObject(this.gameObject,"show/timeCount/sec"):GetComponent("Text")
    this.receiveAllBtn = Util.GetGameObject(this.gameObject,"show/receiveAllBtn")
end

function OnlineRewardPanel:showReward()
    ActivityGiftManager.onlineData = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)) do
        --获取在线礼包数据
        if v.ActivityId == ActivityTypeDef.OnlineGift then
            table.insert(ActivityGiftManager.onlineData, v)
        end
    end
    table.sort(ActivityGiftManager.onlineData, function(a, b)
        return a.Id < b.Id
    end)
    for i = 1,#ActivityGiftManager.onlineData do
        this.root = Util.GetGameObject(this.gameObject,"show/bg/Grid/RewardView"..i.."/root")
        if not itemPreList[i] then
            itemPreList[i] = SubUIManager.Open(SubUIConfig.ItemView,this.root.transform)
        end
        local itemDatas = {ActivityGiftManager.onlineData[i].Reward[1][1], ActivityGiftManager.onlineData[i].Reward[1][2]}
        itemPreList[i]:OnOpen(false, itemDatas, 0.75,false, false, false, self.sortingOrder)

        local name = Util.GetGameObject(this.gameObject,"show/bg/Grid/RewardView"..i .."/name"):GetComponent("Text")
        local itemSId =  tonumber(itemDatas[1])
        local itemDataConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemSId)
        local itemName = GetLanguageStrById(itemDataConFig.Name)
        name.text = itemName

        Util.GetGameObject(itemPreList[i].gameObject, "item/num"):SetActive(false)
        local itemNum = tonumber(itemDatas[2]) or 0
        local num = Util.GetGameObject(this.gameObject,"show/bg/Grid/RewardView"..i .."/num"):GetComponent("Text")
        num.text = PrintWanNum(itemNum)

        itemPreList[i]:ResetNameSize(Vector3.New(0,-95,0),Vector3.New(1.3,1.3,1))
    end
    OnlineRewardPanel:OnShowActivityData()
end

--面板刷新
function OnlineRewardPanel:OnShowActivityData()
    ActivityGiftManager.onlineData = {}
    allOnlineReward = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)) do
        --获取在线礼包数据
        if v.ActivityId == ActivityTypeDef.OnlineGift then
            table.insert(ActivityGiftManager.onlineData, v)
        end
    end
    table.sort(ActivityGiftManager.onlineData, function(a, b)
        return a.Id < b.Id
    end)
    for i = 1,#ActivityGiftManager.onlineData do
        local RewardView = Util.GetGameObject(this.gameObject,"show/bg/Grid/RewardView"..i)
        local redPoint = Util.GetGameObject(RewardView,"root/ItemView/redPoint")
        local flag = Util.GetGameObject(RewardView,"flag")
        local btn = Util.GetGameObject(RewardView,"btn")
        local effect = Util.GetGameObject(RewardView,"effect")

        local bg = RewardView:GetComponent("Image")
        local num = Util.GetGameObject(RewardView,"num"):GetComponent("Text")
        local frame = Util.GetGameObject(RewardView,"root/ItemView/item/frame"):GetComponent("Image")
        local icon = Util.GetGameObject(RewardView,"root/ItemView/item/icon"):GetComponent("Image")

        btn:SetActive(true)

        -- local onlineRewardEffect = Util.GetGameObject(RewardView, "root/ItemView/effects/UI_Effect_Kuang_JinSe")
        -- local onlineRewardEffect2 = Util.GetGameObject(RewardView, "root/ItemView/effects/UI_effect_WuCai_Kuang")

        if i <= ActivityGiftManager.currentTimeIndex then--达到领奖时长
            if ActivityGiftManager.onlineGetRewardState[ActivityGiftManager.onlineData[i].Id] == 0 then--奖励未领取
                redPoint:SetActive(true)
                this.SetItemBg(2,bg,num,frame,icon)
                flag:SetActive(false)
                effect:SetActive(true)

                if this.IsAvailableAchievement(ActivityGiftManager.onlineData[i].Id) then
                    table.insert(allOnlineReward,ActivityGiftManager.onlineData[i].Id)
                end

                Util.AddOnceClick(btn,function()
                    flag:SetActive(true)
                    redPoint:SetActive(false)
                    btn:SetActive(false)
                    this.SetItemBg(1,bg,num,frame,icon)
                    NetManager.GetActivityRewardRequest(ActivityGiftManager.onlineData[i].Id, ActivityTypeDef.OnlineGift, function(_drop)
                        local rewardItemPopup = UIManager.OpenPanel(UIName.RewardItemPopup, _drop, 1,function()
                            ActivityGiftManager.onlineGetRewardState[ActivityGiftManager.onlineData[i].Id] = 1
                            this.Refresh()
                            Game.GlobalEvent:DispatchEvent(GameEvent.OnlineGift.GetOnlineRewardSuccess)
                        end)

                        --获得英雄表现
                        if _drop.Hero ~= nil and #_drop.Hero > 0 then
                            local itemDataList = {}
                            local itemDataStarList = {}
                            rewardItemPopup.gameObject:SetActive(false)
                            this.gameObject:SetActive(false)
                            -- local box = Util.GetGameObject(this.gameObject.transform.parent,"FightPointPassMainPanel/Bg/getBoxReward/effect")
                            -- box:SetActive(false)
                            for i = 1, #_drop.Hero do
                                local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", _drop.Hero[i].heroId)
                                table.insert(itemDataList, heroData)
                                table.insert(itemDataStarList, _drop.Hero[i].star)
                            end
                            UIManager.OpenPanel(UIName.PublicGetHeroPanel,itemDataList,itemDataStarList,function ()
                                -- box:SetActive(true)
                                this.gameObject:SetActive(true)
                                rewardItemPopup.gameObject:SetActive(true)
                            end)
                        end
                    end)
                end)
            elseif ActivityGiftManager.onlineGetRewardState[ActivityGiftManager.onlineData[i].Id] == 1 then
                flag:SetActive(true)
                btn:SetActive(false)
                effect:SetActive(false)

                this.SetItemBg(1,bg,num,frame,icon)
            end
        else
            effect:SetActive(false)
            this.SetItemBg(2,bg,num,frame,icon)

            Util.AddOnceClick(btn,function()
                PopupTipPanel.ShowTipByLanguageId(11441)
            end)
        end
    end

    Util.SetGray(this.receiveAllBtn,#allOnlineReward == 0)
    this.receiveAllBtn:GetComponent("Button").enabled = (#allOnlineReward ~= 0)
end

--判断是否含有这个已完成的成就
function this.IsAvailableAchievement(id)
    for i = 1,#allOnlineReward do
        if allOnlineReward[i] == id then
            return false
        end
    end
    return true
end

function this.SetItemBg(type,bg,num,frame,icon,onlineRewardEffect,onlineRewardEffect2,isOpen)
    -- onlineRewardEffect:SetActive(isOpen)
    -- onlineRewardEffect2:SetActive(isOpen)
    if type == 1 then
        bg.sprite = Util.LoadSprite("cn2-X1_zaixianjiangli_jinglidiban_yilingqu")
        num.color = Color.New(255/255,255/255,255/255,128/255)
        frame.color = Color.New(255/255,255/255,255/255,64/255)
        icon.color = Color.New(255/255,255/255,255/255,64/255)
    elseif type == 2 then
        bg.sprite = Util.LoadSprite("cn2-X1_zaixianjiangli_jinglidiban")
        num.color = Color.New(255/255,255/255,255/255,153/255)
        frame.color = Color.New(255/255,255/255,255/255,255/255)
        icon.color = Color.New(255/255,255/255,255/255,255/255)
    end
end

--绑定事件（用于子类重写）
function OnlineRewardPanel:BindEvent()
    Util.AddClick(this.closeBtn,function()
        this:ClosePanel()
    end)

    Util.AddClick(this.receiveAllBtn,function()
        NetManager.GetActivityRewardAllRequest(ActivityTypeDef.OnlineGift, function(msg)
            local rewardItemPopup = UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function()
                for i = 1, #msg.missionIds do
                    ActivityGiftManager.onlineGetRewardState[msg.missionIds[i]] = 1
                end
                this.Refresh()
                Game.GlobalEvent:DispatchEvent(GameEvent.OnlineGift.GetOnlineRewardSuccess)
            end)
            --获得英雄表现
            if msg.drop.Hero ~= nil and #msg.drop.Hero > 0 then
                local itemDataList = {}
                local itemDataStarList = {}
                rewardItemPopup.gameObject:SetActive(false)
                this.gameObject:SetActive(false)
                -- local box = Util.GetGameObject(this.gameObject.transform.parent,"FightPointPassMainPanel/Bg/getBoxReward/effect")
                -- box:SetActive(false)
                for i = 1, #msg.drop.Hero do
                    local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", msg.drop.Hero[i].heroId)
                    table.insert(itemDataList, heroData)
                    table.insert(itemDataStarList, msg.drop.Hero[i].star)
                end
                UIManager.OpenPanel(UIName.PublicGetHeroPanel,itemDataList,itemDataStarList,function ()
                    -- box:SetActive(true)
                    this.gameObject:SetActive(true)
                    rewardItemPopup.gameObject:SetActive(true)
                end)
            end
        end)
    end)
end

--添加事件监听（用于子类重写）
function OnlineRewardPanel:AddListener()
end

--移除事件监听（用于子类重写）
function OnlineRewardPanel:RemoveListener()
end

function OnlineRewardPanel.Refresh()
    OnlineRewardPanel:showReward()
    OnlineRewardPanel:RemainTimeDown()
end

function OnlineRewardPanel:OnSortingOrderChange()
    --初试创建List中为0
    if #itemPreList ~= 0 then
        for i = 1,#itemPreList do
            itemPreList[i]:SetEffectLayer(self.sortingOrder)
        end
    end
end

--界面打开时调用（用于子类重写）
function OnlineRewardPanel:OnOpen(...)
end

-- 打开，重新打开时回调
function OnlineRewardPanel:OnShow()
    this.Refresh()
end

--界面关闭时调用（用于子类重写）
function OnlineRewardPanel:OnClose()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.OnlineGift.GetOnlineRewardSuccess)
end

--界面销毁时调用（用于子类重写）
function OnlineRewardPanel:OnDestroy()
    itemPreList = {}
end

function OnlineRewardPanel:Time(t)
    if not t or t < 0 then
        return "00 00 00"
    end
    local _sec = t % 60
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local _hour = math.floor(allMin / 60)
    return string.format("%02d",_hour), string.format("%02d",_min),string.format("%02d", _sec)
end

--在线奖励刷新
--刷新倒计时显示
function OnlineRewardPanel:RemainTimeDown()
    self:RemainTimeDownUpdata()
    if ActivityGiftManager.currentTimeIndex == #ActivityGiftManager.onlineData then
        this.hour.text = "00"
        this.min.text = "00"
        this.sec.text = "00"
    end
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    self.timer = Timer.New(function()
        if NetManager.IsConnect() then--是否在线状态
            self:RemainTimeDownUpdata()
        end
        if ActivityGiftManager.currentTimeIndex == #ActivityGiftManager.onlineData then
            self.timer:Stop()
            self.timer = nil
            this.hour.text = "00"
            this.min.text = "00"
            this.sec.text = "00"
        end
    end, 1, -1, true)
    self.timer:Start()
end

function OnlineRewardPanel:RemainTimeDownUpdata()
    local timeNum = GetTimeStamp() - ActivityGiftManager.cuOnLineTimestamp
    local newSort = 0
    for i = 1, #ActivityGiftManager.onlineData do
        local curValue = ActivityGiftManager.onlineData[i].Values[1][1]*60
        local curSort = ActivityGiftManager.onlineData[i].Sort
        if ActivityGiftManager.onlineGetRewardState[ActivityGiftManager.onlineData[i].Id] == 0 then
            if math.floor(timeNum) >= curValue and newSort < curSort then
                newSort = curSort
            end
        elseif ActivityGiftManager.onlineGetRewardState[ActivityGiftManager.onlineData[i].Id] == 1 then
            newSort = curSort
        end
    end
    if newSort ~= ActivityGiftManager.currentTimeIndex then
        ActivityGiftManager.currentTimeIndex = newSort
        this:OnShowActivityData()--(ActivityGiftManager.onlineData, ActivityTypeDef.OnlineGift, ActivityGiftManager.onlineGetRewardState, ActivityGiftManager.currentTimeIndex)
    end
    if newSort < 12 then
        local hour,min,sec = OnlineRewardPanel:Time(ActivityGiftManager.onlineData[newSort+1].Values[1][1]*60-timeNum)
        this.hour.text = hour
        this.min.text = min
        this.sec.text = sec
    else
        this.hour.text = "00"
        this.min.text = "00"
        this.sec.text = "00"
    end
end

return OnlineRewardPanel