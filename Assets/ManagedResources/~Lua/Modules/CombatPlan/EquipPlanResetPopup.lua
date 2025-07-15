require("Base/BasePanel")
EquipPlanResetPopup = Inherit(BasePanel)
local this = EquipPlanResetPopup
local WarWaySkillConfig = ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)

--初始化组件（用于子类重写）
function EquipPlanResetPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.transform, "BackMask")
    this.btnClose = Util.GetGameObject(self.transform, "btnClose")

    this.Frame = Util.GetGameObject(self.transform, "bg/PlanInfo/Frame")
    this.icon = Util.GetGameObject(self.transform, "bg/PlanInfo/icon")
    this.PlanName = Util.GetGameObject(self.transform, "bg/PlanInfo/PlanName")

    this.ResetBtn = Util.GetGameObject(self.transform, "bg/DownBtn/ResetBtn")
    this.SaveBtn = Util.GetGameObject(self.transform, "bg/DownBtn/SaveBtn")
    this.helpBtn = Util.GetGameObject(self.transform, "bg/helpBtn")

    this.pro = Util.GetGameObject(self.transform, "bg/pro")

    this.CostPart = Util.GetGameObject(self.transform, "bg/CostPart")

    this.CurCPro = Util.GetGameObject(self.transform, "bg/CurInfo/CPro")
    this.ResCPro = Util.GetGameObject(self.transform, "bg/ResetInfo/CPro")
    this.random = Util.GetGameObject(self.transform, "bg/ResetInfo/random")

    this.CurScrollPro = Util.GetGameObject(self.transform, "bg/CurInfo/CPro/ScrollPro")
    this.ResScrollPro = Util.GetGameObject(self.transform, "bg/ResetInfo/CPro/ScrollPro")


    local w = this.CurScrollPro.transform.rect.width
    local h = this.CurScrollPro.transform.rect.height
    this.CurScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.CurScrollPro.transform, this.pro, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(5, 0))
    this.CurScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.CurScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.CurScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.CurScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.CurScrollView.moveTween.MomentumAmount = 1
    this.CurScrollView.moveTween.Strength = 2

    w = this.ResScrollPro.transform.rect.width
    h = this.ResScrollPro.transform.rect.height
    this.ResScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ResScrollPro.transform, this.pro, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(5, 0))
    this.ResScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.ResScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ResScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ResScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ResScrollView.moveTween.MomentumAmount = 1
    this.ResScrollView.moveTween.Strength = 2
    
    this.LuckyShow = Util.GetGameObject(self.transform, "bg/LuckyShow")
    this.ExpBar = Util.GetGameObject(self.transform, "bg/LuckyShow/ExpBar"):GetComponent("Slider")
    this.ExpBarText = Util.GetGameObject(self.transform, "bg/LuckyShow/ExpBar/Fill Area/Text"):GetComponent("Text")
    this.Prompt = Util.GetGameObject(self.transform, "bg/LuckyShow/Prompt")
end

--绑定事件（用于子类重写）
function EquipPlanResetPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.helpBtn, function()
    end)
end

--添加事件监听（用于子类重写）
function EquipPlanResetPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.CombatPlan.RebuildPlan, this.SetLucky, this)
end

--移除事件监听（用于子类重写）
function EquipPlanResetPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.CombatPlan.RebuildPlan, this.SetLucky, this)
end

--界面打开时调用（用于子类重写）
function EquipPlanResetPopup:OnOpen(...)
    local args = {...}
    this.planDid = args[1]

    this.tempPlanData = nil
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function EquipPlanResetPopup:OnShow()
    this.planData = CombatPlanManager.GetPlanData(this.planDid)
    self:SetIcon(this.planData)
    self:SetProUI(this.CurScrollView, this.CurCPro, this.planData)
    this.UpdateReSetUI()
    this:SetLucky()
end

function EquipPlanResetPopup:SetIcon(_planData)
    local planData = _planData
    
    local combatPlanData = G_CombatPlanConfig[planData.combatPlanId]

    this.Frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(CombatPlanManager.SetQuality(combatPlanData.Quality)))
    this.PlanName:GetComponent("Text").text = GetStringByEquipQua(CombatPlanManager.SetQuality(combatPlanData.Quality), GetLanguageStrById(combatPlanData.Name))
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(combatPlanData.Icon)
end

function EquipPlanResetPopup:SetProUI(scrollView, cProGo, _planData)
    local planData = _planData
    --> pro
    scrollView:SetData(planData.property, function(index, root)
        EquipPlanResetPopup.SetRemouldPro(root, planData.property[index])
    end)
    scrollView:SetIndex(1)

    --> skill
    for i = 1, 2 do
        local skillgo = Util.GetGameObject(cProGo, "method" .. tostring(i))
        local skillid = planData.skill[i]
        if skillid then
            skillgo:SetActive(true)
            local skillConfig = G_PassiveSkillConfig[skillid]
            Util.GetGameObject(skillgo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
            -- Util.GetGameObject(skillgo, "Name"):GetComponent("Text").text = GetLanguageStrById(skillConfig.Name)
            Util.GetGameObject(skillgo, "Name"):GetComponent("Text").text = this.SetNameColor(GetLanguageStrById(skillConfig.Name),WarWaySkillConfig[skillid].Level)
            Util.AddOnceClick(Util.GetGameObject(skillgo, "frame"),function()
                local skillData = {}
                skillData.skillConfig = skillConfig
                skillData.lock = true
                local PassiveSkillConfig = G_PassiveSkillLogicConfig[skillid]
                UIManager.OpenPanel(UIName.SkillInfoPopup,skillData,1,10,1,1,PassiveSkillConfig.Level)
            end)  
        else
            skillgo:SetActive(false)
        end
    end
end

function EquipPlanResetPopup.SetRemouldPro(go, data)
    local proData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", data.id)
    Util.GetGameObject(go, "proName"):GetComponent("Text").text = GetLanguageStrById(proData.Info)
    local txt = Util.GetGameObject(go, "proVale"):GetComponent("Text")
    if proData.Style == 1 then               --< 绝对值
        txt.text = "+"..GetPropertyFormatStr(1, data.value)
    elseif proData.Style == 2 then           --< 百分比
        txt.text = "+"..GetPropertyFormatStr(2, data.value)
    end

    Util.GetGameObject(go, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(proData.Icon))
end

function EquipPlanResetPopup.UpdateReSetUI()
    local combatPlanData = G_CombatPlanConfig[this.planData.combatPlanId]
    local enough = true
    for i = 1, 2 do
        local itemId = combatPlanData.Cost[i][1]
        local itemData = G_ItemConfig[itemId]
        local bagNum = BagManager.GetItemCountById(itemId)
        Util.GetGameObject(this.CostPart, "cost" .. i .. "/frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemData.Quantity))
        Util.GetGameObject(this.CostPart, "cost" .. i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
        -- if itemId == 14 then
        --     if bagNum >= combatPlanData.Cost[i][2] then
        --         Util.GetGameObject(this.CostPart, "cost" .. i .. "/Num"):GetComponent("Text").text = PrintWanNum(bagNum) .."/"..combatPlanData.Cost[i][2]
        --     else
        --         Util.GetGameObject(this.CostPart, "cost" .. i .. "/Num"):GetComponent("Text").text = string.format("<color=#FF6868>%s</color>",PrintWanNum(bagNum)).."/"..combatPlanData.Cost[i][2]
        --     end
        -- else
            if bagNum >= combatPlanData.Cost[i][2] then
                Util.GetGameObject(this.CostPart, "cost" .. i .. "/Num"):GetComponent("Text").text = PrintWanNum(bagNum) .."/"..combatPlanData.Cost[i][2]
            else
                Util.GetGameObject(this.CostPart, "cost" .. i .. "/Num"):GetComponent("Text").text = string.format("<color=#FF6868>%s</color>",PrintWanNum(bagNum)).."/"..combatPlanData.Cost[i][2]
            end
        -- end

        if bagNum < combatPlanData.Cost[i][2] then
            enough = false
        end

        ItemImageTips(itemId, Util.GetGameObject(this.CostPart, "cost" .. i .. "/icon"))
    end

    Util.AddOnceClick(this.ResetBtn, function()
        if enough then
            CombatPlanManager.RebuildPlan(this.planDid, function(msg)
                this.tempPlanData = CombatPlanManager.CreateEmptyTable()
                CombatPlanManager.CopyValue(this.tempPlanData, msg.plan)

                this.UpdateReSetUI()
                this:SetProUI(this.ResScrollView, this.ResCPro, this.tempPlanData)

                CombatPlanManager.RequestEgData()
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10455)
        end
    end)

    if this.tempPlanData then
        --> 重铸数据获取完
        this.random:SetActive(false)
        this.ResCPro:SetActive(true)

        this.SaveBtn:SetActive(true)
        Util.AddOnceClick(this.SaveBtn, function()
            local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            CombatPlanManager.RebuildConfirmPlan(this.planDid, function()
                this.planData = CombatPlanManager.GetPlanData(this.planDid)
                CombatPlanManager.CopyValue(this.planData, this.tempPlanData)
                this.tempPlanData = nil

                this:SetProUI(this.CurScrollView, this.CurCPro, this.planData)
                this.UpdateReSetUI()
                RefreshPower(oldPower)
                Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnPlayRingChange)
            end)
        end)
    else
        this.random:SetActive(true)
        this.ResCPro:SetActive(false)
        this.SaveBtn:SetActive(false)
    end
end

function EquipPlanResetPopup:SetLucky()
    local planData = CombatPlanManager.GetPlanData(this.planDid)
    local combatPlanConfig = G_CombatPlanConfig[planData.combatPlanId]
    
    if combatPlanConfig.RecastCount == 0 then
        this.LuckyShow:SetActive(false)
    else
        this.LuckyShow:SetActive(true)
        local useTimes = 0
        for i = 1, #CombatPlanManager.luckyNum do
            if CombatPlanManager.luckyNum[i].id == combatPlanConfig.Quality then
                useTimes = CombatPlanManager.luckyNum[i].value
                break
            end
        end
        this.ExpBar.value = useTimes / combatPlanConfig.RecastCount
        this.ExpBarText.text = useTimes .. "/" .. combatPlanConfig.RecastCount

        this.Prompt:GetComponent("Text").text = string.format(GetLanguageStrById(22411), combatPlanConfig.RecastCount - useTimes)
    end
end

function this.SetNameColor(_name,_level)
    if _level == 1 then
        return string.format("<color=#9fff88>%s</color>",_name)
    elseif _level == 2 then
        return string.format("<color=#88e4ff>%s</color>",_name)
    elseif _level == 3 then
        return string.format("<color=#f088ff>%s</color>",_name)
    elseif _level == 4 then
        return string.format("<color=#ffba88>%s</color>",_name)
    elseif _level == 5 then
        return string.format("<color=#ff6868>%s</color>",_name)
    else
        return _name
    end
end

--界面关闭时调用（用于子类重写）
function EquipPlanResetPopup:OnClose()
    this.tempPlanData = nil

    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnRefreshRing)
end

--界面销毁时调用（用于子类重写）
function EquipPlanResetPopup:OnDestroy()

end

return EquipPlanResetPopup