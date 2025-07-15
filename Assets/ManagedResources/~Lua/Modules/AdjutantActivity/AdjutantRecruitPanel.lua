local AdjutantRecruitPanel = quick_class("AdjutantRecruitPanel")
local allData = {}
local itemsGrid = {}--item重复利用
local this = AdjutantRecruitPanel
local parent
local GlobalActivity
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
this.thread = nil --协程

function AdjutantRecruitPanel:InitComponent(gameObject)
    this.itemPreList = {}
    this.itemList = {}
    -- this.time = Util.GetGameObject(gameObject, "time/Text"):GetComponent("Text")
    -- this.itemPre = Util.GetGameObject(gameObject, "ItemPre")
    -- this.item = Util.GetGameObject(gameObject, "Item")
    this.shop = Util.GetGameObject(gameObject,"Shop")
    this.grid = Util.GetGameObject(gameObject,"Grid")

    this.btn1 = Util.GetGameObject(gameObject,"btn1")
    this.btn1CostIcon = Util.GetGameObject(this.btn1,"icon"):GetComponent("Image")
    this.btn1CostNum = Util.GetGameObject(this.btn1,"num"):GetComponent("Text")

    this.btn2 = Util.GetGameObject(gameObject,"btn2")
    this.btn2CostIcon = Util.GetGameObject(this.btn2,"icon"):GetComponent("Image")
    this.btn2CostNum = Util.GetGameObject(this.btn2,"num"):GetComponent("Text")

    this.btn3 = Util.GetGameObject(gameObject,"btn3")
    this.btn3CostIcon = Util.GetGameObject(this.btn3,"icon"):GetComponent("Image")
    this.btn3CostNum = Util.GetGameObject(this.btn3,"num"):GetComponent("Text")

    -- this.cost = Util.GetGameObject(gameObject,"cost/icon"):GetComponent("Image")
    -- this.num = Util.GetGameObject(gameObject,"cost/num"):GetComponent("Text")
    -- this.costAdd = Util.GetGameObject(gameObject,"cost/addBtn")

    this.limit = Util.GetGameObject(gameObject, "limit/Text"):GetComponent("Text")

    this.mask = Util.GetGameObject(gameObject,"mask")
end

--绑定事件（用于子类重写）
function AdjutantRecruitPanel:BindEvent()
    Util.AddClick(this.btn1,function ()
        if BagManager.GetItemCountById(16) > 200 then
            NetManager.AdjutantActivityRecruit(AdjutantActivityManager.GetLayer(),0,function (msg)
                AdjutantActivityManager.SetLayer(msg.layer)
                AdjutantActivityManager.setBuyNum(msg.buyNum)
                -- UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                --     this:OnShowData()
                -- end)
                this.TrunOpen(msg.drop)
            end)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(10060))
        end
    end)
    Util.AddClick(this.btn2,function ()
        if BagManager.GetItemCountById(6000115) > 0 then
            NetManager.AdjutantActivityRecruit(AdjutantActivityManager.GetLayer(),1,function (msg)
                AdjutantActivityManager.SetLayer(msg.layer)
                AdjutantActivityManager.setBuyNum(msg.buyNum)
                -- UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function ()
                --     this:OnShowData()
                -- end)
                this.TrunOpen(msg.drop)
            end)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(10060))
        end
    end)
    Util.AddClick(this.btn3,function ()
        if BagManager.GetItemCountById(6000115) >= 5 then
            NetManager.AdjutantActivityRecruit(AdjutantActivityManager.GetLayer(),2,function (msg)
                AdjutantActivityManager.SetLayer(msg.layer)
                AdjutantActivityManager.setBuyNum(msg.buyNum)
                -- UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function () 
                --     this:OnShowData()                         
                -- end)
                this.TrunOpen(msg.drop)
            end)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(10060))
        end
    end)
    Util.AddClick(this.shop,function ()
        local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantRecruit)
        local data = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activityId)
        local shopData = ConfigManager.GetConfigData(ConfigName.StoreTypeConfig,data.ShopId[1])
        UIManager.OpenPanel(UIName.MapShopPanel,shopData.StoreType)
        -- UIManager.OpenPanel(UIName.MapShopPanel,GlobalActivity.ShopId[1])
    end)
    -- Util.AddClick(this.costAdd,function ()     
    --     JumpManager.GoJump(itemConfig.Jump[1]) 
    -- end)
end

--添加事件监听（用于子类重写）
function AdjutantRecruitPanel:AddListener()
end

--移除事件监听（用于子类重写）
function AdjutantRecruitPanel:RemoveListener()
end
local sortingOrder = 0

local effect = {}
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AdjutantRecruitPanel:OnShow(_sortingOrder,_parent)
    parent = _parent
    sortingOrder = _sortingOrder

    if not this.turnTimer then
        this.turnTimer = Timer.New(nil,1, -1,true)
    end
    NetManager.GetAdjutantActivityInfo(function(msg)
        AdjutantActivityManager.SetLayer(msg.layer)
        AdjutantActivityManager.setBuyNum(msg.buyNum)
        this:OnShowData()

        -- this:DrawEffect()
    end)
end

--界面打开时调用（用于子类重写）
function AdjutantRecruitPanel:OnOpen()
end

function AdjutantRecruitPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function AdjutantRecruitPanel:OnDestroy()
    sortingOrder = 0
    if this.thread then
        coroutine.stop(this.thread)
        this.thread = nil
    end
    if this.turnTimer then
        this.turnTimer:Stop()
        this.turnTimer = nil
    end
end

function AdjutantRecruitPanel:OnShowData()
    allData = {}
    -- allData = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.RechargeCommodityConfig, "ShowType", 23, "Type", GoodsTypeDef.DirectPurchaseGift)
    local curActId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantRecruit)
    local LayerPoolConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.LayerPoolConfig,"ActivityId",curActId)
    -- GlobalActivity = ConfigManager.GetConfigData(ConfigName.GlobalActivity,curActId)
    for i,v in pairs (LayerPoolConfigs) do
        local data = v
        table.insert(allData,data)
    end
    if allData then
        table.sort(allData,function (a,b)
            return a.Layer < b.Layer
        end)

        for i = 1, #allData do
            for j = 1, #allData[i].Reward do
                local pre
                if j == #allData[i].Reward then
                    pre = Util.GetGameObject(this.grid, "item/grid")
                else
                    pre = Util.GetGameObject(this.grid, "item" .. i .. "_" .. j .. "/grid")
                end
                local reward = allData[i].Reward[j]
                local state = allData[i].Layer > AdjutantActivityManager.GetLayer()
                
                if j ~= #allData[i].Reward or (not state and j == #allData[i].Reward) then
                    if pre.transform.childCount > 0 then
                        Util.ClearChild(pre.transform)
                    end
                    local item = SubUIManager.Open(SubUIConfig.ItemView, pre.transform)
                    item:OnOpen(false, reward, 0.7,false,false,false,sortingOrder)
                end

                if j ~= #allData[i].Reward then
                    Util.GetGameObject(pre.transform.parent.gameObject, "lock"):SetActive(state)
                end
            end
        end
    end

    for i = 1, #allData[AdjutantActivityManager.GetLayer()].LotteryId do
        local lotteryId = allData[AdjutantActivityManager.GetLayer()].LotteryId[i]
        local lotterySettingConfig = ConfigManager.GetConfigData(ConfigName.LotterySetting,lotteryId)
        local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig,lotterySettingConfig.CostItem[1][1])
        if i == 1 then
            this.btn1CostIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
            this.btn1CostNum.text = lotterySettingConfig.CostItem[1][2]
        elseif i == 2 then
            this.btn2CostIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
            this.btn2CostNum.text = lotterySettingConfig.CostItem[1][2]
        else
            this.btn3CostIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
            this.btn3CostNum.text = lotterySettingConfig.CostItem[1][2]
        end
    end
   
    local lotterySettingConfig = ConfigManager.GetConfigDataByKey(ConfigName.LotterySetting,"ActivityId",curActId)
    local privilegeConfig = ConfigManager.GetConfigData(ConfigName.PrivilegeTypeConfig,lotterySettingConfig.MaxTimes)
    this.limit.text = AdjutantActivityManager.GetBuyNum().."/"..privilegeConfig.Condition[1][2]
   
    effect = {}
    for i = 1, 7 do
        local item = this.grid.transform:GetChild(i - 1).gameObject
        if not Util.GetGameObject(item, "lock").activeSelf then
            table.insert(effect, Util.GetGameObject(item, "effect"))
        end
    end
end

local index = 1--转盘下标
function this.TrunOpen(drop)
    local pos
    if drop.itemlist and #drop.itemlist > 0 then
        local id = drop.itemlist[1].itemId
        for i = 1, #drop.itemlist do
            local _name = GetLanguageStrById(ItemConfig[drop.itemlist[1].itemId].Name)
            if _name == Util.GetGameObject(this.grid, "item/grid/ItemView/name"):GetComponent("Text").text then
                id = drop.itemlist[1].itemId
            end
        end
        local name = GetLanguageStrById(ItemConfig[id].Name)
        for i = 1, #effect do
            local txt = Util.GetGameObject(effect[i].transform.parent.gameObject, "ItemView/name"):GetComponent("Text").text
            if txt == name then
                pos = i
            end
        end
    end
    this.mask:SetActive(true)
    this:DrawEffect(0.05)
    this.turnTimer:Start()
    this.thread = coroutine.start(function()
        coroutine.wait(1)
        this:DrawEffect(0.1)
        coroutine.wait(0.5)
        this:DrawEffect(0.3)
        coroutine.wait(0.5)
        this:DrawEffect(0.5, pos, function()
            Timer.New(function()
                this.mask:SetActive(false)
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function ()
                    effect[pos]:SetActive(false)
                    this:OnShowData()
                end)
            end, 0.6, 1, true):Start()
        end)
    end)
end

function this:DrawEffect(time, pos, func)
    this.turnTimer:Reset(function()
        if #effect == 7 then
            if index == 6 and pos ~= 6 then
                index = 7
            end
        end
        if index > #effect then
            index = 1
        end
        for i = 1, #effect do
            effect[i]:SetActive(index == i)
        end
        if index == pos then
            this.turnTimer:Stop()
            if func then
                func()
            end
        end

        index = index + 1
    end, time, -1, true)
end

return AdjutantRecruitPanel