require("Base/BasePanel")
XiaoYaoLuckyTurnTablePopup = Inherit(BasePanel)
local this=XiaoYaoLuckyTurnTablePopup

local _itemsList = {}
local itemViewList = {}
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local atrConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local rewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)
local id = 0
local num = 0
local rewardDatas = {}
function XiaoYaoLuckyTurnTablePopup:InitComponent()
    -- this.spLoader = SpriteLoader.New()
    this.titleText = Util.GetGameObject(self.transform, "Panel/bg/titleText"):GetComponent("Text")
    this.closeBtn = Util.GetGameObject(self.transform, "Panel/bg/closeBtn")

    this.itemsLayout = Util.GetGameObject(self.transform, "Panel/items")
    this.btn = Util.GetGameObject(self.transform, "start")

    this.remainTimes = Util.GetGameObject(self.transform, "Panel/remainTimes"):GetComponent("Text")
    this.remainTime = Util.GetGameObject(self.transform, "Panel/remainTime"):GetComponent("Text")

    for i = 1, this.itemsLayout.transform.childCount do
        _itemsList[i] = Util.GetGameObject(self.transform, "Panel/items/GameObject"..i)
    end
    this.mask = Util.GetGameObject(self.transform, "btnMsk")
end

function XiaoYaoLuckyTurnTablePopup:BindEvent()
    Util.AddClick(this.closeBtn,function()
        self:ClosePanel()
    end)
    Util.AddOnceClick(this.btn,function()
        this.btn:GetComponent("Button").interactable = false
        this.mask:SetActive(true)
        XiaoYaoManager.GameOperate(function(msg)
            --转起来
            --LogGreen("msg.location:"..msg.location.. "  msg.drop.itemlist[1].itemId: "..msg.drop.itemlist[1].itemId.."  msg.drop.itemlist[1].itemNum: "..msg.drop.itemlist[1].itemNum )
            id = msg.drop.itemlist[1].itemId
            num = msg.drop.itemlist[1].itemNum
            this:test(msg.location)           
        end)
    end)
end

--添加事件监听（用于子类重写）
function XiaoYaoLuckyTurnTablePopup:AddListener()

end

--移除事件监听（用于子类重写）
function XiaoYaoLuckyTurnTablePopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function XiaoYaoLuckyTurnTablePopup:OnOpen(...)
    this.titleText.text = GetLanguageStrById(50344)
end
function XiaoYaoLuckyTurnTablePopup:OnShow()
    this.mask:SetActive(false)
    this.remainTimes.text = GetLanguageStrById(12341)..XiaoYaoManager.luckyluckyTurnTableTimes
    if XiaoYaoManager.luckyluckyTurnTableTimes < 1 or XiaoYaoManager.luckyluckyTurnTableRemainTime - PlayerManager.serverTime < 1 then
        this:ClosePanel()
        return
    end 
    this:TimerDown()
    rewardDatas = {}
    local rewardDataGroups = XiaoYaoManager.luckyTurnTableRewards
    for i,v in ipairs(rewardDataGroups) do
        table.insert(rewardDatas,rewardGroup[v].ShowItem[1])  
    end
    --LogGreen("rewardDatas:"..#rewardDatas)
    for i,v in ipairs(rewardDatas) do
        local item = _itemsList[i]
        Util.GetGameObject(item,"Red"):SetActive(false)
        if not itemViewList[i] then
            itemViewList[i] = SubUIManager.Open(SubUIConfig.ItemView,Util.GetGameObject(item,"reward").transform)
        end
        itemViewList[i]:OnOpen(false,{v[1],v[2]},1.15,false)
    end
    Util.GetGameObject(_itemsList[1],"Red"):SetActive(true)
end

--加减速
function  XiaoYaoLuckyTurnTablePopup:test(itemId)
    local t = 1
    local thread=coroutine.start(function()
        --加速阶段
        if this.turnEffect2 then
            this.turnEffect2:Stop()
            this.turnEffect2 = nil
        end
        this.turnEffect2 = Timer.New(function()          
            this:tableTurnEffect(1/t)
            t=t+5
        end,0.2,10,true)
        this.turnEffect2:Start()
        coroutine.wait(3)
        --减速阶段
        if this.turnEffect2 then
            this.turnEffect2:Stop()
            this.turnEffect2 = nil
        end
        this.turnEffect2 = Timer.New(function()
            this:tableTurnEffect(1/t)
            t=t-3.3
        end,0.2,10,true)    
        this.turnEffect2:Start()
        coroutine.wait(3)       
        this:tableTurnEffect(0.4,itemId)
    end)
end

--设置速度
local index = 1
function  XiaoYaoLuckyTurnTablePopup:tableTurnEffect(speed,itemId)
    if this.turnEffect then 
        this.turnEffect:Stop()
        this.turnEffect = nil
    end
    this.turnEffect = Timer.New(function()   
        local red = Util.GetGameObject(_itemsList[index],"Red")
        red:SetActive(false)
        if index == 12 then--t归零
            index = 0
        end
        local redNext = Util.GetGameObject(_itemsList[index+1],"Red")
        redNext:SetActive(true)
            -- 音效
        -- SoundManager.PlaySound(SoundConfig.Sound_zp)
        -- SoundManager.PlaySound(SoundConfig.UI_Xingyunzhuanpan)
        index = index + 1
        --LogGreen("index == "..index)
        --检测最后的奖励
        if itemId and index == itemId then
            this.turnEffect:Stop()
            --游戏结束显示掉落
            Timer.New(function()      
                local data = TrialMiniGameManager.IdToNameIconNum(id,num)
                this.btn:GetComponent("Button").interactable = true
                PopupTipPanel.ShowColorTip(data[1],data[2],data[3]) 
                this.mask:SetActive(false)
                this:OnShow()
            end, 1,1,true):Start()
        end
    end,speed,-1,true)
    this.turnEffect:Start()
end
function this:TimerDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local timeDown = XiaoYaoManager.luckyluckyTurnTableRemainTime - PlayerManager.serverTime
    this.remainTime.text = GetLanguageStrById(11496)..TimeToHMS(timeDown)
    this.timer = Timer.New(function()
        if timeDown < 1 then
            XiaoYaoManager.UpdateLuckyTurnTables()
            this:ClosePanel()
           return 
        end
        timeDown = timeDown - 1
        this.remainTime.text = GetLanguageStrById(11496)..TimeToHMS(timeDown)
    end, 1, -1, true)
    self.timer:Start()
end
function  XiaoYaoLuckyTurnTablePopup:OnClose()
    Game.GlobalEvent:DispatchEvent(GameEvent.XiaoYao.RefreshEventShow)
    for index, value in ipairs(_itemsList) do
        local red = Util.GetGameObject(value,"Red")
        red:SetActive(false)
    end
    index = 1
    if this.turnEffect2 then
        this.turnEffect2:Stop()
        this.turnEffect2 = nil
    end
    if this.turnEffect then
        this.turnEffect:Stop()
        this.turnEffect = nil
    end
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function  XiaoYaoLuckyTurnTablePopup:OnDestroy()
    -- this.spLoader:Destroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    itemViewList = {}
    _itemsList = {}
    rewardDatas = {}
end

return this