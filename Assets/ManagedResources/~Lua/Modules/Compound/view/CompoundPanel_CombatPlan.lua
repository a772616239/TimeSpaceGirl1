local this = {}
local sortingOrder = 0
local CombatPlanPromotion = ConfigManager.GetConfig(ConfigName.CombatPlanPromotion)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

local addGos = {}
local promotionList = {}
local propertyList = {}
local selectPromotionPlan

function this:InitComponent(gameObject)
    --合成
    this.Compound = Util.GetGameObject(gameObject, "Compound")
    this.AddAllBtn = Util.GetGameObject(gameObject, "AddAllBtn")
    this.CompoundBtn = Util.GetGameObject(gameObject, "CompoundBtn")
    this.previewBtn = Util.GetGameObject(gameObject, "previewBtn")

    for i = 1, 5 do
        addGos[i] = Util.GetGameObject(gameObject, "titleGo/addBtn" .. tostring(i))
    end
    addGos[6] = Util.GetGameObject(gameObject, "titleGo/addBtnTop")

    this.ExpBar = Util.GetGameObject(gameObject, "ExpBar"):GetComponent("Slider")
    this.ExpBarText = Util.GetGameObject(gameObject, "ExpBar/Fill Area/Text"):GetComponent("Text")

    this.Consume = Util.GetGameObject(gameObject, "Consume")
    this.Percent = Util.GetGameObject(gameObject, "Consume/Percent"):GetComponent("Text")
    this.ConsumeCostImg = Util.GetGameObject(gameObject, "Consume/Image"):GetComponent("Image")
    this.ConsumeCostTxt = Util.GetGameObject(gameObject, "Consume/Cost"):GetComponent("Text")

    this.selectPlanDids = {}--选中精炼

    this.ToPreviewBtn = Util.GetGameObject(gameObject, "toPromotionBtn")

    --精炼
    this.PromotionPanel = Util.GetGameObject(gameObject, "PromotionPanel")
     for i = 1, 3 do
         local promotionItem = Util.GetGameObject(gameObject, "Promotion/Promotion"..i)
         local propertyItem = Util.GetGameObject(gameObject, "property/property"..i)
         table.insert(promotionList,promotionItem)
         table.insert(propertyList,propertyItem)
     end
    this.ringSelect = Util.GetGameObject(gameObject, "Promotion/ringSelect")
    -- this.rightBtn = Util.GetGameObject(gameObject, "Promotion/rightBtn")

    this.costs = Util.GetGameObject(gameObject, "costs")
    this.cost1 = Util.GetGameObject(this.costs, "item1")
    this.cost2 = Util.GetGameObject(this.costs, "item2")

    this.promotedBtn = Util.GetGameObject(gameObject, "promotedBtn")
end

function this:BindEvent()
    Util.AddClick(this.AddAllBtn, function()
        local isSuccess = this:AllAdd()
        if isSuccess then
            this:UpdateAddUI()
        else
            PopupTipPanel.ShowTipByLanguageId(22408)
        end
    end)

    Util.AddClick(this.CompoundBtn, function()
        if #this.selectPlanDids < 1 then
            PopupTipPanel.ShowTipByLanguageId(22405)
            return
        end
        if #this.selectPlanDids < 2 then
            PopupTipPanel.ShowTipByLanguageId(22406)
            return
        end

        local planData = CombatPlanManager.GetPlanData(this.selectPlanDids[1])
        local compoundConfig = ConfigManager.GetConfigDataByKey(ConfigName.CombatPlanConfig, "Quality", planData.quality)
        
        if PlayerManager.level < compoundConfig.PlayerLevelLimit then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(22407), compoundConfig.PlayerLevelLimit))
            return
        end

        -- cost
        local idx = 1
        if #this.selectPlanDids >= 2 then
            idx = #this.selectPlanDids - 1
        end
        local itemid = compoundConfig.SuccessRateShow[idx][2]
        local itemnum = compoundConfig.SuccessRateShow[idx][3]

        local ownNum = BagManager.GetItemCountById(itemid)
        if ownNum < itemnum then
            PopupTipPanel.ShowTipByLanguageId(11812)
            return
        end

        if planData.quality > 3 and #this.selectPlanDids < 5 then
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Currency, GetLanguageStrById(50231), function ()
                CombatPlanManager.CompoundPlan(this.selectPlanDids, planData.quality, function(msg)
                    if msg.result > 0 then
                        local plan = msg.plan
                        if plan.combatPlanId == 0 then
                            --魂力值满
                            PopupTipPanel.ShowTip(GetLanguageStrById(50266))
                            plan = msg.expPlan
                        else
                            local _plan = {}
                            _plan.id = msg.plan.id
                            _plan.combatPlanId = msg.plan.combatPlanId
                            _plan.property = {}
                            for i = 1, #msg.plan.property do
                                _plan.property[i] = {}
                                _plan.property[i].id = msg.plan.property[i].id
                                _plan.property[i].value = msg.plan.property[i].value
                            end
                            _plan.skill = {}
                            for i = 1, #msg.plan.skill do
                                _plan.skill[i] = msg.plan.skill[i]
                            end
                            _plan.quality = G_CombatPlanConfig[_plan.combatPlanId].Quality
                            _plan.isLocked = msg.plan.isLocked
                            _plan.promotionLevel = msg.plan.promotionLevel

                            local drop = {}
                            drop.plan = {}
                            drop.plan[1] = _plan
                            UIManager.OpenPanel(UIName.RewardItemPopup, drop,1,function()
                            end)
                        end

                        CombatPlanManager.UpdateSinglePlanData(plan)
                    else
                        --失败经验补偿
                        local selectData = CombatPlanManager.GetPlanData(this.selectPlanDids[1])
                        local FailReturn = G_CombatPlanConfig[selectData.combatPlanId].FailReturn
                        local num = 0
                        for k,v in pairs(FailReturn) do
                           if v[1] == #this.selectPlanDids and v[2] == 6000110 then
                              num = v[3]
                              break
                           end
                        end
                        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(23005),num))
                    end

                    CombatPlanManager.DelSinglePlanDatas(this.selectPlanDids)

                    this.selectPlanDids = {}
                    this:UpdateAddUI()
                    -- 删除plan数据
                    CombatPlanManager.RequestEgData()
                end)
            end)
        else
            CombatPlanManager.CompoundPlan(this.selectPlanDids, planData.quality, function(msg)
                if msg.result > 0 then
                    local plan = msg.plan
                    if plan.combatPlanId == 0 then
                        --魂力值满
                        PopupTipPanel.ShowTip(GetLanguageStrById(50266))
                        plan = msg.expPlan
                    else
                        PopupTipPanel.ShowTip(GetLanguageStrById(22409))
                        local _plan = {}
                        _plan.id = msg.plan.id
                        _plan.combatPlanId = msg.plan.combatPlanId
                        _plan.property = {}
                        for i = 1, #msg.plan.property do
                            _plan.property[i] = {}
                            _plan.property[i].id = msg.plan.property[i].id
                            _plan.property[i].value = msg.plan.property[i].value
                        end
                        _plan.skill = {}
                        for i = 1, #msg.plan.skill do
                            _plan.skill[i] = msg.plan.skill[i]
                        end
                        _plan.quality = G_CombatPlanConfig[_plan.combatPlanId].Quality
                        _plan.isLocked = msg.plan.isLocked
                        _plan.promotionLevel = msg.plan.promotionLevel
    
                        local drop = {}
                        drop.plan = {}
                        drop.plan[1] = _plan
                        UIManager.OpenPanel(UIName.RewardItemPopup, drop,1,function()
                        end)
                    end
    
                    CombatPlanManager.UpdateSinglePlanData(plan)
                else
                    local selectData = CombatPlanManager.GetPlanData(this.selectPlanDids[1])
                    local FailReturn = G_CombatPlanConfig[selectData.combatPlanId].FailReturn
                    local num = 0
                    for k,v in pairs(FailReturn) do
                       if v[1] == #this.selectPlanDids and v[2] == 6000110 then
                          num = v[3]
                          break
                       end
                    end
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(23005),num))
                end
    
                CombatPlanManager.DelSinglePlanDatas(this.selectPlanDids)
    
                this.selectPlanDids = {}
                this:UpdateAddUI()
                -- 删除plan数据
                CombatPlanManager.RequestEgData()
            end)
        end
    end)

    Util.AddClick(this.previewBtn, function()
       UIManager.OpenPanel(UIName.WarWayPreviewPopup)
    end)

    --打开精炼面板
    Util.AddClick(this.ToPreviewBtn, function()
        local canPromotionList = CombatPlanManager.GetAllCanPromotionPlans()
        if #canPromotionList > 0 then
            this.parentPanel.btnBack.gameObject:SetActive(false)
            this.parentPanel.btnBack2.gameObject:SetActive(true)
            this.Compound:SetActive(false)
            this.PromotionPanel:SetActive(true)
            this.PromotedCondition()
            this.PromotedLight(-1)
            this.PromotedInfo()
        else
            PopupTipPanel.ShowTipByLanguageId(23030)
        end
    end)

    --精炼
    Util.AddClick(this.promotedBtn, function()
        if selectPromotionPlan ~= nil then
            MsgPanel.ShowTwo(GetLanguageStrById(23031), nil, function()
                NetManager.CombatPlanUpgradeRequest(selectPromotionPlan.id,function(msg)
                    this.tempPlanData = CombatPlanManager.GetPlanData(selectPromotionPlan.id)
                    CombatPlanManager.CopyValue(this.tempPlanData, msg.plan)
                    this.PromotedInfo(this.tempPlanData)
                    PopupTipPanel.ShowTipByLanguageId(23032)
                end)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(23033)
        end
    end)

    --选择精炼
    Util.AddClick(this.ringSelect, function()
        UIManager.OpenPanel(UIName.CombatPlanPromotedSelectPopup, self,selectPromotionPlan)
    end)

    BindRedPointObject(RedPointType.ResearchInstitute_RingCompound, Util.GetGameObject(this.AddAllBtn,"redpoint"))
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.CombatPlan.CompoundPlanExpPush, this.SetExp, this)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.CombatPlan.CompoundPlanExpPush, this.SetExp, this)
end

local sortingOrder = 0
function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end

function this:OnShow(...)
    sortingOrder = 0
    local arg = {...}
    this.parentPanel = arg[1]
    this.Compound:SetActive(true)
    this.PromotionPanel:SetActive(false)

    self:UpdateAddUI()

    if this.parentPanel.isRefresh then
        local canPromotionList = CombatPlanManager.GetAllCanPromotionPlans()
        if #canPromotionList > 0 then
            this.parentPanel.btnBack.gameObject:SetActive(false)
            this.parentPanel.btnBack2.gameObject:SetActive(true)
            this.Compound:SetActive(false)
            this.PromotionPanel:SetActive(true)
            this.PromotedCondition()
            this.PromotedLight(-1)
            this.PromotedInfo()
        else
            PopupTipPanel.ShowTipByLanguageId(23030)
        end
    end

    CheckRedPointStatus(RedPointType.ResearchInstitute_RingCompound)

    CombatPlanManager.RequestEgData(function()
    end)
end

function this:UpdateAddUI()
    CheckRedPointStatus(RedPointType.ResearchInstitute_RingCompound)
    local compoundPlanQuality = 0
    for i = 1, 5 do
        local planGo = addGos[i]
        local icon = Util.GetGameObject(planGo, "frame/icon")
        -- local add = Util.GetGameObject(planGo, "add")
        local frame = Util.GetGameObject(planGo, "frame")
        if this.selectPlanDids[i] then
            -- add:SetActive(false)
            frame:SetActive(true)

            local planData = CombatPlanManager.GetPlanData(this.selectPlanDids[i])
            compoundPlanQuality = planData.quality
            local planConfig = G_CombatPlanConfig[planData.combatPlanId]
            local qualityid = CombatPlanManager.SetQuality(planConfig.Quality)
            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(qualityid))
            icon:GetComponent("Image").sprite = Util.LoadSprite(planConfig.Icon)

            Util.AddOnceClick(icon, function()
                UIManager.OpenPanel(UIName.CombatPlanTipsPopup, 3, nil, nil, nil, nil, nil, planData)
            end)
        else
            -- add:SetActive(true)
            frame:SetActive(false)
            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
            Util.AddOnceClick(planGo, function()
                UIManager.OpenPanel(UIName.CombatPlanCompoundSelectPopup, self)
            end)
        end
    end

    local compoundGo = addGos[6]
    local compoundIcon = Util.GetGameObject(compoundGo, "icon")
    if compoundPlanQuality == 0 then
        compoundGo:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
        compoundIcon:SetActive(false)
        this.Consume:SetActive(false)
    else
        compoundIcon:SetActive(true)
        this.Consume:SetActive(true)
        local qualityid = CombatPlanManager.SetQuality(compoundPlanQuality)
        compoundGo:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(qualityid+1))
        local compoundConfig = ConfigManager.GetConfigDataByKey(ConfigName.CombatPlanConfig, "Quality", compoundPlanQuality + 1)
        compoundIcon:GetComponent("Image").sprite = Util.LoadSprite(compoundConfig.Icon)

        --cost
        local compoundConfigShow = ConfigManager.GetConfigDataByKey(ConfigName.CombatPlanConfig, "Quality", compoundPlanQuality)
        local idx = 1
        if #this.selectPlanDids >= 2 then
            idx = #this.selectPlanDids - 1
        end
        local itemid = compoundConfigShow.SuccessRateShow[idx][2]
        local itemnum = compoundConfigShow.SuccessRateShow[idx][3]
        local percent = compoundConfigShow.SuccessRateShow[idx][4]

        this.Percent.text = percent / 10000 * 100 .. "%"
        this.ConsumeCostImg.sprite = Util.LoadSprite(GetResourcePath(G_ItemConfig[itemid].ResourceID))
        this.ConsumeCostTxt.text = PrintWanNum4(itemnum)
    end

    this:SetExp()
end

function this:AllAdd()
    local allPlans = CombatPlanManager.GetAllCanCompoundPlans()
    local arrByQuality = {{}, {}, {}, {}}   -- 只能前四品质
    for i = 1, #allPlans do
        local qa = allPlans[i].quality
        table.insert(arrByQuality[qa], allPlans[i])
    end

    local quality = 0
    for i = 1, 4 do
        if #arrByQuality[i] >= 2 then
            quality = i
            break
        end
    end
    
    if quality == 0 then
        return false
    else
        this.selectPlanDids = {}
        for i = 1, #arrByQuality[quality] do
            if i <= 5 then
                table.insert(this.selectPlanDids, arrByQuality[quality][i].id)
            end
        end
        return true
    end
end

function this:SetExp()
    this.ExpBar.value = CombatPlanManager.compoundExp / 1000
    this.ExpBarText.text = CombatPlanManager.compoundExp .. "/" .. 1000
end

-- 精炼信息
function this.PromotedInfo(data)
    selectPromotionPlan = data
    if selectPromotionPlan ~= nil then
        if data.promotionLevel == 0 and data.quality == 6 then
            selectPromotionPlan = nil
            this.PromotedLight(-1)--条件置灰
        else
            this.PromotedLight(data.promotionLevel)--条件置灰
        end
    else
        this.PromotedLight(-1)--条件置灰
    end

    local ringSelectIcon = Util.GetGameObject(this.ringSelect, "icon")
    local ringSelectAdd = Util.GetGameObject(this.ringSelect, "add")
    ringSelectIcon:SetActive(false)
    ringSelectAdd:SetActive(false)
    if selectPromotionPlan ~= nil then
        ringSelectIcon:SetActive(true)
        local quality = CombatPlanManager.SetQuality(data.quality)
        this.ringSelect:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(quality))
        ringSelectIcon:GetComponent("Image").sprite = Util.LoadSprite(G_CombatPlanConfig[data.combatPlanId].Icon)
    else
        this.ringSelect:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
        ringSelectAdd:SetActive(true)
    end
end

--晋级对应高亮和消耗
function this.PromotedLight(num)
    local lv = num
    for i = 1, 3 do
        Util.SetGray(promotionList[i].gameObject,i > lv)
        Util.SetGray(propertyList[i].gameObject,i > lv)
        Util.GetGameObject(promotionList[i],"refine"):SetActive(i <= lv)
    end
    if lv == -1 then
        this.costs:SetActive(false)
        return
    else
        this.costs:SetActive(true)
    end
    local cost = CombatPlanPromotion[lv + 1].UpgradeCost

    this.cost1:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(ItemConfig[cost[1][1]].Quantity))
    Util.GetGameObject(this.cost1,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[cost[1][1]].ResourceID))
    if BagManager.GetItemCountById(cost[1][1]) >= cost[1][2] then
        Util.GetGameObject(this.cost1,"num"):GetComponent("Text").text = string.format("%s/%s",BagManager.GetItemCountById(cost[1][1]),cost[1][2])
    else
        Util.GetGameObject(this.cost1,"num"):GetComponent("Text").text = string.format("<color=#FF6868>%s</color>/%s",BagManager.GetItemCountById(cost[1][1]),cost[1][2])
    end
    ItemImageTips(cost[1][1], this.cost1)

    this.cost2:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(ItemConfig[cost[2][1]].Quantity))
    Util.GetGameObject(this.cost2,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[cost[2][1]].ResourceID))
    if BagManager.GetItemCountById(cost[2][1]) >= cost[2][2] then
        Util.GetGameObject(this.cost2,"num"):GetComponent("Text").text = string.format("%s/%s",BagManager.GetItemCountById(cost[2][1]),cost[2][2] )
    else
        Util.GetGameObject(this.cost2,"num"):GetComponent("Text").text = string.format("<color=#FF6868>%s</color>/%s",BagManager.GetItemCountById(cost[2][1]),cost[2][2] )
    end
    ItemImageTips(cost[2][1], this.cost2)
end

--精炼对应奖励
function this.PromotedCondition()
    for i = 1, 3 do
        local data = Util.GetGameObject(propertyList[i], "Text")
        data:GetComponent("Text").text = GetLanguageStrById(CombatPlanPromotion[i].EffectDes)
    end
end

function this:OnClose()
    this.selectPlanDids = {}
end

function this:OnDestroy()
    propertyList = {}
    promotionList = {}

    ClearRedPointObject(RedPointType.ResearchInstitute_RingCompound)
end

return this