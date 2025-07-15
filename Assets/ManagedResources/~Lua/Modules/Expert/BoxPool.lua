local BoxPool = quick_class("BoxPool")

local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local BoxPoolConfig = ConfigManager.GetConfig(ConfigName.BoxPoolConfig)
local effectList = {}
local itemList = {}
local boxPoolConfig = {}

function BoxPool:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.isJump = false
end

function BoxPool:InitComponent(go)
    self.btnJump = Util.GetGameObject(go, "btnJump")--跳过动画
    self.btnRefresh = Util.GetGameObject(go, "gird/btnRefresh")--刷新
    self.btnDraw = Util.GetGameObject(go, "gird/btnDraw")--抽取
    self.live = Util.GetGameObject(go, "live")
    self.livePos = Util.GetGameObject(go, "live/liveMask/pos")
    self.type1 = Util.GetGameObject(go, "type1")
    self.type2 = Util.GetGameObject(go, "type2")
    self.mask = Util.GetGameObject(go, "mask")
    self.banner = Util.GetGameObject(go, "banner")
    self.autoResetCount = Util.GetGameObject(go, "count/autoResetCount"):GetComponent("Text")
    self.manualResetCount = Util.GetGameObject(go, "count/manualResetCount"):GetComponent("Text")
    self.time = Util.GetGameObject(go, "time/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function BoxPool:BindEvent()
    Util.AddClick(self.btnJump, function ()
        self.isJump = not self.isJump
        Util.GetGameObject(self.btnJump, "Image"):SetActive(self.isJump)
    end)
    Util.AddClick(self.btnRefresh, function ()
        ActivityGiftManager.ResetBoxPoolInfo(false, function ()
            self:RefreshView()
        end)
    end)
    Util.AddClick(self.btnDraw, function ()
        self:ResetTimer()
        self:TrunOpen()
    end)

    BindRedPointObject(RedPointType.BoxPool, Util.GetGameObject(self.btnDraw, "redpoint"))
end

--添加事件监听（用于子类重写）
function BoxPool:AddListener()
end

--移除事件监听（用于子类重写）
function BoxPool:RemoveListener()
end

function BoxPool:OnOpen()
end

--界面打开时调用（用于子类重写）
function BoxPool:OnShow(sortingOrder)
    -- ActivityGiftManager.InitBoxPoolInfo(function ()
        boxPoolConfig = BoxPoolConfig[ActivityGiftManager.boxPoolId]
        Util.GetGameObject(self.btnJump, "Image"):SetActive(self.isJump)
        local config = ConfigManager.TryGetConfigDataByKey(ConfigName.AcitvityShow, "ActivityId", boxPoolConfig.ActivityId)
        if config and config.Hero and config.Hero[1] then
            self.live:SetActive(true)
            self.banner:SetActive(false)
            self.liveConfig = heroConfig[config.Hero[1]]
            if self.liveObg then
                UnLoadHerolive(self.liveConfig, self.liveObj)
                Util.ClearChild(self.livePos.transform)
                self.liveObj = nil
            end
            self.livePos:GetComponent("RectTransform").anchoredPosition = Vector2.New(config.HeroimgTransform[1][1],config.HeroimgTransform[1][2])
            self.liveObg = LoadHerolive(self.liveConfig, self.livePos.transform)
        else
            self.live:SetActive(false)
            self.banner:SetActive(true)
        end

        local data = ActivityGiftManager.TryGetActivityInfoByType(boxPoolConfig.ActivityId)
        -- PatFaceManager.RemainTimeDown2(self.time.gameObject, self.time, data.endTime - GetTimeStamp())
        CardActivityManager.TimeDown(self.time, data.endTime - GetTimeStamp())
        if not self.turnTimer then
            self.turnTimer = Timer.New(nil,1, -1,true)
        end

        self:RefreshView()
    -- end)

end

--界面关闭时调用（用于子类重写）
function BoxPool:OnClose()
    CardActivityManager.StopTimeDown()
end

--界面销毁时调用（用于子类重写）
function BoxPool:OnDestroy()
    if self.liveObg then
        UnLoadHerolive(self.liveConfig, self.liveObj)
        Util.ClearChild(self.live.transform)
        self.liveObj = nil
    end

    if self.thread then
        coroutine.stop(self.thread)
        self.thread = nil
    end
    if self.turnTimer then
        self.turnTimer:Stop()
        self.turnTimer = nil
    end

    ClearRedPointObject(RedPointType.BoxPool, Util.GetGameObject(self.btnDraw, "redpoint"))
end

function BoxPool:RefreshView()
    CheckRedPointStatus(RedPointType.BoxPoolCanDraw)
    CheckRedPointStatus(RedPointType.BoxPoolFreeTime)
    self:ResetTimer()
    local type = boxPoolConfig.PoolShowType--展示样式
    local LotterId = ActivityGiftManager.lotteryId --卡池ID
    self.poolData = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotteryRewardConfig,"Pool",LotterId)

    self.type1:SetActive(type == 1)
    self.type2:SetActive(type == 2)

    effectList = {}

    for i = 1, #self.poolData do
        local parent = Util.GetGameObject(self.gameObject, "type"..type.."/grid/pos"..i)
        local pos = Util.GetGameObject(parent, "pos")
        local num = Util.GetGameObject(parent, "Text"):GetComponent("Text")
        local effect = Util.GetGameObject(parent, "effect")
        if not itemList[i] then
            itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
        end
        itemList[i]:OnOpen(false, {self.poolData[i].Reward[1], self.poolData[i].Reward[2]}, 0.5)
        num.text = self.poolData[i].Reward[2]
        itemList[i]:ShowNum(false)
        local isMask = ActivityGiftManager.BoxPoolIsDraw(self.poolData[i].Id)
        Util.GetGameObject(parent, "mask"):SetActive(isMask)
        if not isMask then
            table.insert(effectList, {effect, self.poolData[i].Reward[1]})
        end
    end

    if type == 1 then
        local pos = Util.GetGameObject(self.gameObject, "type1/grandPrize")
        if not itemList[11] then
            itemList[11] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
        end
        itemList[11]:OnOpen(false, {self.poolData[1].Reward[1], self.poolData[1].Reward[2]}, 0.85)
        itemList[11]:ShowNum(false)
        itemList[11].gameObject:SetActive(true)
    else
        if itemList[11] then
            itemList[11].gameObject:SetActive(false)
        end
    end

    --消耗
    local costRefresh = boxPoolConfig.ManualResetCost--重置消耗
    if costRefresh and costRefresh[1][1] > 0 then
        Util.GetGameObject(self.btnRefresh, "item"):SetActive(true)
        Util.GetGameObject(self.btnRefresh, "item"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[costRefresh[1][1]].ResourceID))
        Util.GetGameObject(self.btnRefresh, "item/Text"):GetComponent("Text").text = costRefresh[1][2]
    else
        Util.GetGameObject(self.btnRefresh, "item"):SetActive(false)
    end

    local costDraw = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"Id",LotterId).CostItem--扭蛋消耗
    Util.GetGameObject(self.btnDraw, "item"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[costDraw[1][1]].ResourceID))
    Util.GetGameObject(self.btnDraw, "item/Text"):GetComponent("Text").text = costDraw[1][2]

    if boxPoolConfig.AutoReset[1] == 1 then
        if boxPoolConfig.AutoReset[2] == -1 or boxPoolConfig.AutoReset[2] == 0 then
            self.autoResetCount.gameObject:SetActive(false)
        else
            self.autoResetCount.gameObject:SetActive(true)
        end
    else
        self.autoResetCount.gameObject:SetActive(true)
    end
    if boxPoolConfig.ManualReset[1] == 1 then
        if boxPoolConfig.ManualReset[2] == -1 or boxPoolConfig.ManualReset[2] == 0 then
            self.manualResetCount.gameObject:SetActive(false)
            self.btnRefresh:SetActive(false)
        else
            self.manualResetCount.gameObject:SetActive(true)
            self.btnRefresh:SetActive(true)
        end
    else
        self.manualResetCount.gameObject:SetActive(true)
        self.btnRefresh:SetActive(true)
    end

    local time = boxPoolConfig.ManualReset[2] - ActivityGiftManager.manualResetCount
    self.autoResetCount.text = GetLanguageStrById(50188)..ActivityGiftManager.autoResetCount
    self.manualResetCount.text = GetLanguageStrById(50187)..time

    if ActivityGiftManager.BoxPoolFreeTime() then
        Util.GetGameObject(self.btnDraw, "Text"):GetComponent("Text").text = GetLanguageStrById(50186)
    else
        Util.GetGameObject(self.btnDraw, "Text"):GetComponent("Text").text = GetLanguageStrById(50189)
    end
end

local index = 1--转盘下标
function BoxPool:TrunOpen()
    ActivityGiftManager.ResetBoxPoolInfo(true, function (drop)
        if self.isJump then
            UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function ()
                self:RefreshView()
            end)
        else
            local pos = self:GetPos(drop)

            -- 最后一个不要动画
            if #effectList <= 1 then
                self.mask:SetActive(false)
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function ()
                    effectList[pos][1]:SetActive(false)
                    self:RefreshView()
                end)
                return
            end

            self.mask:SetActive(true)
            self:DrawEffect(0.05)
            self.turnTimer:Start()
            self.thread = coroutine.start(function()
                coroutine.wait(1)
                self:DrawEffect(0.1)
                coroutine.wait(0.5)
                self:DrawEffect(0.5, pos, function()
                    Timer.New(function()
                        self.mask:SetActive(false)
                        UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function ()
                            effectList[pos][1]:SetActive(false)
                            self:RefreshView()
                        end)
                    end, 0.6, 1, true):Start()
                end)
            end)
        end
    end)
end

function BoxPool:DrawEffect(time, pos, func)
    self.turnTimer:Reset(function()
        if index > #effectList then
            index = 1
        end
        for i = 1, #effectList do
            effectList[i][1]:SetActive(index == i)
        end
        if index == pos then
            self.turnTimer:Stop()
            if func then
                func()
            end
        end

        index = index + 1
    end, time, -1, true)
end

function BoxPool:ResetTimer()
    self.mask:SetActive(false)
    if self.thread then
        coroutine.stop(self.thread)
    end
    if self.turnTimer then
        self.turnTimer:Stop()
    end
end

function BoxPool:GetPos(drop)
    local IsContain = function (id)
        for i = 1, #self.poolData do
            for i = 1, #effectList do
                if id == effectList[i][2] then
                    return i
                end
            end
        end
    end

    local pos
    if drop.itemlist and #drop.itemlist > 0 then
        local id = drop.itemlist[1].itemId
        pos = IsContain(id)
    end
    if drop.equipId and #drop.equipId > 0 and pos == nil then
        local id = drop.equipId[1].id
        pos = IsContain(id)
    end
    if drop.plan and #drop.plan > 0 and pos == nil then
        local id = drop.plan[1].combatPlanId
        pos = IsContain(id)
    end
    if drop.medal and #drop.medal > 0 and pos == nil then
        local id = drop.medal[1].id
        pos = IsContain(id)
    end
    if drop.Hero and #drop.Hero > 0 and pos == nil then
        local id = drop.Hero[1].heroId
        pos = IsContain(id)
    end

    return pos
end

return BoxPool