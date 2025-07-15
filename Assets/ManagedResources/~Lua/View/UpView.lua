UpView = {}
local ArenaSetting = ConfigManager.GetConfig(ConfigName.ArenaSetting)
local StoreTypeConfig = ConfigManager.GetConfig(ConfigName.StoreTypeConfig)
local _ItemMaxNum = 4
function UpView:New(gameObject)
    local u = {}
    u.gameObject = gameObject
    u.transform = gameObject.transform
    setmetatable(u, { __index = UpView })
    return u
end

--- 要显示加号的类型，有购买功能的物品要配置在这里显示 加号
local _ShowPlusType = {
    UpViewRechargeType.Energy,
    UpViewRechargeType.Gold,
    UpViewRechargeType.Yaoh,
    UpViewRechargeType.ChallengeTicket,
    UpViewRechargeType.SpiritTicket,
    UpViewRechargeType.GhostRing,
    UpViewRechargeType.EliteCarbonTicket,
    UpViewRechargeType.AdventureAlianInvasionTicket,
    UpViewRechargeType.SoulCrystal,
    UpViewRechargeType.DemonCrystal,
    UpViewRechargeType.GrowthAmulet,
    UpViewRechargeType.LightRing,
    UpViewRechargeType.MonsterCampTicket,
    UpViewRechargeType.StarFireBuLingStone,
    UpViewRechargeType.SpiritJade,
    UpViewRechargeType.BadgeGlory,
    UpViewRechargeType.GuildToken,
    UpViewRechargeType.StarSoul,
    UpViewRechargeType.FriendPoint,
    UpViewRechargeType.ChoasCoin,
    UpViewRechargeType.LuckyTreasure,
    UpViewRechargeType.AdvancedTreasure,
    UpViewRechargeType.Panacea,
    UpViewRechargeType.JYD,
    UpViewRechargeType.TopMatchCoin,
    UpViewRechargeType.FindFairy,
    UpViewRechargeType.FixforDan,
    UpViewRechargeType.ChinaHas,
    UpViewRechargeType.Iron,
    UpViewRechargeType.SummonStamps,
    UpViewRechargeType.ExchangeOfLicenses,
    UpViewRechargeType.Treasure,
    UpViewRechargeType.HitOut,
    UpViewRechargeType.Fight,
    UpViewRechargeType.Cross,
    UpViewRechargeType.War,
    UpViewRechargeType.Medal,
    UpViewRechargeType.WarWay,
    UpViewRechargeType.Intelligence,
    UpViewRechargeType.Part,
    UpViewRechargeType.Adjutantship,
    UpViewRechargeType.GeneralRecycle,
    UpViewRechargeType.AdvancedRecycle,
    UpViewRechargeType.LaddersChallenge,
    UpViewRechargeType.ChatHorn,

}

-- 判断是否显示加号
local function _IsShowPlus(_type)
    -- 魂晶特殊处理，在地图中不显示  +  号
    if _type == UpViewRechargeType.SoulCrystal and MapManager.isInMap then
        return false
    end
    -- 判断是否是可购买的类型
    for _, type in ipairs(_ShowPlusType) do
        if type == _type then
            return true
        end
    end
    return false
end


--- 红点类型注册
local _ViewRPType = {
    [UpViewRechargeType.Gold] = RedPointType.UpView_Gold
}
function UpView:_BindRP(rcType, redpot)
    local rpType = _ViewRPType[rcType]
    if not rpType then
        return
    end
    BindRedPointObject(rpType, redpot)
    if not self._BindData then
        self._BindData = {}
    end
    self._BindData[rpType] = redpot
end
function UpView:_ClearRP()
    if not self._BindData then return end
    for rpType, redpot in pairs(self._BindData) do
        ClearRedPointObject(rpType, redpot)
    end
    self._BindData = nil
end

--初始化组件（用于子类重写）
function UpView:InitComponent()
    self.leftRoot = Util.GetGameObject(self.gameObject, "LeftUp")
    self.rightRoot = Util.GetGameObject(self.gameObject, "RightUp")
    self.cnyList = {}
    self.cnyTime = {}

    -- 麻蛋的左边一个右边一个
    self.cnyLeft = {}
    self.timeLeft = {}
    self.cnyRight = {}
    self.timeRight = {}
    self.leftBtnList = {}
    self.rightBtnList = {}


    self.cnyListClick = {}
    for i = 1, _ItemMaxNum do
        self.cnyRight[i] = Util.GetGameObject(self.rightRoot, "cnyGrid/cny" .. i)
        self.rightBtnList[i] = Util.GetGameObject( self.rightRoot, "cnyGrid/cny" .. i .. "/btn")
        self.timeRight[i] = Util.GetGameObject(self.cnyRight[i], "time"):GetComponent("Text")

        self.cnyLeft[i] = Util.GetGameObject( self.leftRoot, "cnyGrid/cny" .. i)
        self.leftBtnList[i] = Util.GetGameObject( self.leftRoot, "cnyGrid/cny" .. i .. "/btn")
        self.timeLeft[i] = Util.GetGameObject(self.cnyLeft[i], "time"):GetComponent("Text")
    end

    self.itemList = PanelType.Main
end

--绑定事件（用于子类重写）
function UpView:BindEvent()
    for idx, clickItem in ipairs(self.rightBtnList) do
        Util.AddOnceClick(clickItem, function()
            self:OnClick(idx)
        end)
    end

    for idx, clickItem in ipairs(self.leftBtnList) do
        Util.AddOnceClick(clickItem, function()
            self:OnClick(idx)
        end)
    end

end

--添加事件监听（用于子类重写）
function UpView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, self.UpdateGoldVal, self)
end

--移除事件监听（用于子类重写）
function UpView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, self.UpdateGoldVal, self)
end

---@param args table
-- args: {
--   showType = int,
--   panelType = int,
-- }
--界面打开时调用（用于子类重写）
function UpView:OnOpen(args)
    self.Pname = self.transform.parent.name --方便调试
    if args and args.panelType then
        self.itemList = args.panelType--storeTypeConfig->ResourvesBar数组
    end
    self:SetShowType(args)
    self:UpdateGoldVal()
    self:RefreshCountDown()
end

function UpView:OnSortingOrderChange(sortingOrder)
    local canvas = self.gameObject:GetComponent("Canvas")
    canvas.overrideSorting = true
    canvas.sortingOrder = sortingOrder
end

-- 关闭界面时调用
function UpView:OnClose()
    self:_ClearRP()

    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

function UpView:SetShowType(context)
    if context and context.showType then
        self.leftRoot:SetActive(context.showType == UpViewOpenType.ShowLeft)
        self.rightRoot:SetActive(context.showType == UpViewOpenType.ShowRight)
    else
        self.leftRoot:SetActive(true)
        self.rightRoot:SetActive(false)
    end

    if context and context.showType then
        if context.showType == UpViewOpenType.ShowLeft then
            self.cnyList = self.cnyLeft
            self.cnyTime = self.timeLeft
        else
            self.cnyList = self.cnyRight
            self.cnyTime = self.timeRight
        end
    else
        self.cnyList = self.cnyLeft
        self.cnyTime = self.timeLeft
    end

end

function UpView:UpdateGoldVal()
    -- 先清一遍红点
    self:_ClearRP()
    local panelShowItemList = self.itemList
    for i = 1, _ItemMaxNum do
        if panelShowItemList[i] then
            if self.cnyList[i].gameObject then
                self.cnyList[i]:SetActive(true)
                Util.GetGameObject(self.cnyList[i], "icon"):GetComponent("Image").sprite = SetIcon(panelShowItemList[i])
                -- Util.GetGameObject(self.cnyList[i], "addFlag"):SetActive(_IsShowPlus(panelShowItemList[i]))
                if panelShowItemList[i] == 20 then
                    -- Util.GetGameObject(self.cnyList[i], "addFlag"):SetActive(true)
                end
                if panelShowItemList[i] == 2 then
                    Util.GetGameObject(self.cnyList[i], "value"):GetComponent("Text").text = PrintWanNum(BagManager.GetTotalItemNum(panelShowItemList[i])) .. "/" .. PlayerManager.maxEnergy
                elseif panelShowItemList[i] == 44 then
                    Util.GetGameObject(self.cnyList[i], "value"):GetComponent("Text").text = PrintWanNum(BagManager.GetTotalItemNum(panelShowItemList[i])).."/"..PrivilegeManager.GetPrivilegeNumber(9)
                elseif panelShowItemList[i] == 53 then
                    Util.GetGameObject(self.cnyList[i], "value"):GetComponent("Text").text = PrintWanNum(BagManager.GetTotalItemNum(panelShowItemList[i])).."/"..MonsterCampManager.GetMaxCostItem()
                elseif panelShowItemList[i] == 87 then
                    Util.GetGameObject(self.cnyList[i], "value"):GetComponent("Text").text = PrintWanNum(BagManager.GetTotalItemNum(panelShowItemList[i]))
                else
                    Util.GetGameObject(self.cnyList[i], "value"):GetComponent("Text").text = PrintWanNum(BagManager.GetTotalItemNum(panelShowItemList[i]))
                end

                -- 绑定红点
                local redpot = Util.GetGameObject(self.cnyList[i], "redpot")
                redpot:SetActive(false)
                self:_BindRP(panelShowItemList[i], redpot)
            end
        else
            self.cnyList[i]:SetActive(false)
        end
    end
end

-- 刷新倒计时显示
function UpView:RefreshCountDown()
    local isCD = false
    for i = 1, _ItemMaxNum do
        local itemId = self.itemList[i]
        if itemId then
            local isRecover = AutoRecoverManager.IsAutoRecover(itemId)                      -- 是一个恢复型道具
            local isNotFull = isRecover and AutoRecoverManager.GetRecoverTime(itemId) > 0   -- 没有恢复满
            self.cnyTime[i].gameObject:SetActive(isRecover and isNotFull)
            if isRecover and isNotFull then isCD = true end
        end
    end

    -- 判断是否需要倒计时
    if isCD then
        if not self.timer then
            self.timer = Timer.New(function()
                self:UpdateTime()
            end, 1, -1, true)
            self.timer:Start()
        end
        self:UpdateTime()
    else
        if self.timer then
            self.timer:Stop()
            self.timer = nil
        end
    end

end
-- 计时器回调方法
function UpView:UpdateTime()
    for i = 1, _ItemMaxNum do
        local itemId = self.itemList[i]
        if itemId then
            local isRecover = AutoRecoverManager.IsAutoRecover(itemId)          -- 是一个恢复型道具
            if isRecover then
                local RemainTime = AutoRecoverManager.GetRecoverTime(itemId)
                if RemainTime >= 0 then
                    local _, _hour, _min, _sec = TimeToHMS(RemainTime)
                    local timeStr = string.format("%02d:%02d:%02d", _hour, _min, _sec)
                    --RemainTime > 3600 and string.format("%02d:%02d", _hour, _min) or string.format("%02d:%02d", _min, _sec)
                    self.cnyTime[i].text = timeStr
                else
                    self.cnyTime[i].text = ""
                end
            end
        end
    end

end

function UpView:OnClick(index)
    local panelShowItemList = {}
    local reChargeType = self.itemList[index]
    if reChargeType == 20 then
        --UIManager.OpenPanel(UIName.OperatingPanel,{tabIndex =1,extraParam =2})
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, 20)--元素神符
    end
    self:RechargeType(reChargeType)
end

function UpView:RechargeType(_type)
    if  _type == UpViewRechargeType.Energy or
            _type == UpViewRechargeType.Gold or
            _type == UpViewRechargeType.ChallengeTicket or
            _type == UpViewRechargeType.GhostRing or
            _type == UpViewRechargeType.EliteCarbonTicket or
            _type == UpViewRechargeType.LightRing or
            _type == UpViewRechargeType.AdventureAlianInvasionTicket or
            _type == UpViewRechargeType.MonsterCampTicket or
            _type == UpViewRechargeType.ChatHorn
    then
        --功能快捷购买
        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = _type })
    elseif _type == UpViewRechargeType.DemonCrystal then
        if ActTimeCtrlManager.IsQualifiled(36) then
            UIManager.OpenPanel(UIName.MainRechargePanel, 1)
        else
            local data = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalSystemConfig, "IsIDdSame", 36)[1]
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10775),data.OpenRules[2]))
        end
    elseif _type == UpViewRechargeType.SoulCrystal then
        -- 充值商店
        if not MapManager.isInMap then
            -- if not ShopManager.IsActive(SHOP_TYPE.SOUL_STONE_SHOP) then
            --     PopupTipPanel.ShowTipByLanguageId(10438)
            
            --     return
            -- end
            UIManager.OpenPanel(UIName.MainRechargePanel, 1)
        end
    elseif _type == UpViewRechargeType.GrowthAmulet or
            _type == UpViewRechargeType.Yaoh or
            _type == UpViewRechargeType.Panacea or
            _type == UpViewRechargeType.JYD or
            _type == UpViewRechargeType.LuckyTreasure or
            _type == UpViewRechargeType.AdvancedTreasure or
            _type == UpViewRechargeType.StarFireBuLingStone or
            _type == UpViewRechargeType.FixforDan or
            _type == UpViewRechargeType.FriendPoint or
            _type == UpViewRechargeType.Iron or
            _type == UpViewRechargeType.ChinaHas or
            _type == UpViewRechargeType.FindFairy or
            _type == UpViewRechargeType.StarSoul or
            _type == UpViewRechargeType.ChoasCoin or
            _type == UpViewRechargeType.SpiritJade   or
            _type == UpViewRechargeType.BadgeGlory or
            _type == UpViewRechargeType.TopMatchCoin or
            _type == UpViewRechargeType.GuildToken or
            _type == UpViewRechargeType.SpiritTicket or
            _type == UpViewRechargeType.SummonStamps or
            _type == UpViewRechargeType.ExchangeOfLicenses or
            _type == UpViewRechargeType.Treasure or
            _type == UpViewRechargeType.HitOut or
            _type == UpViewRechargeType.Fight or
            _type == UpViewRechargeType.Cross or
            _type == UpViewRechargeType.War or
            _type == UpViewRechargeType.Medal or
            _type == UpViewRechargeType.WarWay or
            _type == UpViewRechargeType.Intelligence or
            _type == UpViewRechargeType.Part or
            _type == UpViewRechargeType.Adjutantship or
            _type == UpViewRechargeType.GeneralRecycle or
            _type == UpViewRechargeType.AdvancedRecycle or
            _type == UpViewRechargeType.LaddersChallenge or
            _type == UpViewRechargeType.ChatHorn or
            _type == 1002 or -- 盲盒密钥
            _type == 1003 or -- 盲盒积分
            _type == 6000115 or _type == 6000116 or-- 先驱相关
            _type == 10421 or _type == 10422 or _type == 10423 or _type == 10426 or _type == 10427 or _type == 10428 or--主角相关
            _type == 1012
    then
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _type)
    end
end

return UpView