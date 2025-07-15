local ShengYiTianJiang = quick_class("ShengYiTianJiang")
local allData={}
local itemsGrid = {}--item重复利用
local this=ShengYiTianJiang
local parent = {}
local properTypeConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local rechargeConfigId = 0
local rechargeData = {}
local fakeId = 0
this.LiveObj = nil
function ShengYiTianJiang:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function ShengYiTianJiang:InitComponent(gameObject)
    this.time = Util.GetGameObject(gameObject, "time/times"):GetComponent("Text")
    this.buyBtn = Util.GetGameObject(gameObject, "layout/buyBtn")
    this.reviewBtn = Util.GetGameObject(gameObject, "layout/reviewBtn")
    this.scrollItem = Util.GetGameObject(gameObject, "scroller/grid")
    this.proPertyText = Util.GetGameObject(gameObject, "layout/proPertyText"):GetComponent("Text")
    this.buytimes = Util.GetGameObject(gameObject, "layout/buytimes"):GetComponent("Text")
    this.liveRoot = Util.GetGameObject(gameObject, "bg/liveRoot")
    this.skinName = Util.GetGameObject(gameObject, "title/name"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function ShengYiTianJiang:BindEvent()
    Util.AddClick(this.buyBtn,function()
        if rechargeData.buyTimes >= rechargeData.dynamicBuyTimes then
            return
        end
    --直购商品
    PayManager.Pay(rechargeConfigId, function(id)
        this.RechargeSuccessFunc(id)
    end) end)
    Util.AddClick(this.reviewBtn,function() 
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fdata, fseed = BattleManager.GetFakeBattleData(fakeId)
            local testFightData = {
            fightData = fdata,
            fightSeed = fseed,
            fightType = 0,
            maxRound = 20
            }
            UIManager.OpenPanel(UIName.BattlePanel, testFightData, BATTLE_TYPE.Test)
        end)
    end)
end
function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    this:OnShowData()
end
--添加事件监听（用于子类重写）
function ShengYiTianJiang:AddListener()
end

--移除事件监听（用于子类重写）
function ShengYiTianJiang:RemoveListener()
end

local sortingOrder = 0
--界面打开时调用（用于子类重写）
function ShengYiTianJiang:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ShengYiTianJiang:OnShow(_sortingOrder,_parent)
    parent = _parent
    sortingOrder = _sortingOrder
    this:OnShowData()
    ShengYiTianJiang:SetTime()
end
function ShengYiTianJiang:OnShowData()
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.ShenYiTianJiang)
    local activityConfig = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activityId)
    rechargeConfigId = activityConfig.CanBuyRechargeId[1]
    allData = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,rechargeConfigId)
    if not itemsGrid then
        itemsGrid = {}
    end
    for k,v in ipairs(itemsGrid) do       
        v.gameObject:SetActive(false)
    end
    for k,v in ipairs(allData.RewardShow) do       
        if not itemsGrid[k] then
            itemsGrid[k] = SubUIManager.Open(SubUIConfig.ItemView,this.scrollItem.transform)
        end
        itemsGrid[k].gameObject:SetActive(true)
        itemsGrid[k]:OnOpen(false, {v[1],v[2]}, 1,false,false,false,sortingOrder)
    end
    local strs = string.split(activityConfig.ExpertDec,'#') 
    local skinId = tonumber(strs[1]) 
    fakeId = tonumber(strs[2]) 
    local skinConfig = ConfigManager.GetConfigDataByKey(ConfigName.HeroSkin,"Type",skinId)
    if this.LiveObj then
        poolManager:UnLoadLive(this.LiveObj.name,this.LiveObj)
        this.LiveObj = nil
    end 
    this.proPertyText.text = GetLanguageStrById(12415)
    if not skinConfig then
    else
        
        this.LiveObj = poolManager:LoadLive(GetResourcePath(skinConfig.Live),this.liveRoot.transform, Vector3.one * skinConfig.Scale, Vector3.New(skinConfig.Position[1], skinConfig.Position[2], 0))
        this.skinName.text = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.HeroConfig,skinConfig.HeroId).ReadingName)
        local heroSkinSingleProVal = {}
        for _,v in ipairs(skinConfig.MonomerProperty) do
            if not heroSkinSingleProVal[v[1]] then
                heroSkinSingleProVal[v[1]] = 0
            end
            heroSkinSingleProVal[v[1]] = heroSkinSingleProVal[v[1]] + v[2]
        end       
        for k,v in pairs(heroSkinSingleProVal) do
            this.proPertyText.text = this.proPertyText.text..properTypeConfig[k].Info.."+"..GetPropertyFormatStr(properTypeConfig[k].Style,v)
        end
    end

    rechargeData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.DirectPurchaseGift, rechargeConfigId)
    if rechargeData then
        this.buytimes.text = string.format(GetLanguageStrById(12341) ,(rechargeData.dynamicBuyTimes - rechargeData.buyTimes))
    else
        
    end
end

function ShengYiTianJiang:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.ShenYiTianJiang)
    local timeDown = endTime - GetTimeStamp()
    this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    self.timer = Timer.New(function()
        timeDown = timeDown - 1
        if timeDown < 1 then
            self.timer:Stop()
            self.timer = nil
            this.time.text = GetLanguageStrById(12321)..TimeToDHMS(0)
        end
        this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function ShengYiTianJiang:OnClose()

end

--界面销毁时调用（用于子类重写）
function ShengYiTianJiang:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    if this.LiveObj then
        poolManager:UnLoadLive(this.LiveObj.name,this.LiveObj)
        this.LiveObj = nil
    end
    sortingOrder = 0
    itemsGrid = {}
end

function ShengYiTianJiang:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

return ShengYiTianJiang