require("Base/BasePanel")
LeadRAndDPanel = Inherit(BasePanel)
local this = LeadRAndDPanel
local MotherShipPlaneBlueprint = ConfigManager.GetConfig(ConfigName.MotherShipPlaneBlueprint)
local MotherShipResearchPlus = ConfigManager.GetConfig(ConfigName.MotherShipResearchPlus)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local researchType = 0

--初始化组件（用于子类重写）
function LeadRAndDPanel:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.mask = Util.GetGameObject(this.gameObject, "mask")

    this.lv = Util.GetGameObject(this.gameObject, "Lv")
    this.speed = Util.GetGameObject(this.gameObject, "speed")

    this.btnUpLv = Util.GetGameObject(this.gameObject, "btnUpLv")--升级
    this.speedup = Util.GetGameObject(this.gameObject, "speedup")--加速
    this.research = Util.GetGameObject(this.gameObject, "research")--研究

    this.btnRAndD = Util.GetGameObject(this.gameObject, "research/btnRAndD")--开始研究
    this.RAndDValue = Util.GetGameObject(this.gameObject, "research/RAndDValue"):GetComponent("Text")
    this.probability = Util.GetGameObject(this.gameObject, "research/probability"):GetComponent("Text")

    this.btnAccelerate = Util.GetGameObject(this.gameObject, "speedup/btnAccelerate")--加速
    this.progress = Util.GetGameObject(this.gameObject, "speedup/progress"):GetComponent("Text")--研发值
    this.add = Util.GetGameObject(this.gameObject, "speedup/add"):GetComponent("Text")--增加
    this.slider = Util.GetGameObject(this.gameObject, "speedup/Slider"):GetComponent("Slider")--进度条

    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})

    this.upLvRedpoint = Util.GetGameObject(this.btnUpLv, "redpoint")--升级红点

    this.surplusTime = Util.GetGameObject(this.gameObject, "speedup/surplusTime"):GetComponent("Text")--剩余时间
    this.maxLv = Util.GetGameObject(this.gameObject, "maxLv")--满级
end

--绑定事件（用于子类重写）
function LeadRAndDPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function ()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnUpLv, function ()
        local lv = AircraftCarrierManager.GetMaxRresearchLv()
        if type(lv) == "string" then
            PopupTipPanel.ShowTipByLanguageId(11993)
            return
        end
        UIManager.OpenPanel(UIName.LeadUpLevelPanel)
    end)

    Util.AddClick(this.btnRAndD, function ()
        local pos
        for i = 1, 3 do
            local item = Util.GetGameObject(this.research, "grid").transform:GetChild(i-1).gameObject
            if item:GetComponent("Toggle").isOn then
                pos = i
            end
        end
        AircraftCarrierManager.StartResearch(pos, researchType, function ()
            this:OnShow()
        end)
    end)

    Util.AddClick(this.btnAccelerate, function ()
        local pos
        for i = 1, 3 do
            local item = Util.GetGameObject(this.speedup, "grid").transform:GetChild(i-1).gameObject
            if item:GetComponent("Toggle").isOn then
                pos = i
            end
        end
        AircraftCarrierManager.ResearchSpeedUp(pos, researchType, 0, function ()
            this:OnShow()
        end)
    end)
    RedpotManager.BindObject(RedPointType.Lead_SpeedLvUp, this.upLvRedpoint)
end

--添加事件监听（用于子类重写）
function LeadRAndDPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Lead.RefreshProgress, this.SetProgress)
    Game.GlobalEvent:AddEvent(GameEvent.Lead.ResearchOver, this.OnShow)
    Game.GlobalEvent:AddEvent(GameEvent.Lead.ResearchLvUp, this.SetSpeed)
end

--移除事件监听（用于子类重写）
function LeadRAndDPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.RefreshProgress, this.SetProgress)
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.ResearchOver, this.OnShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.ResearchLvUp, this.SetSpeed)
end

--界面打开时调用（用于子类重写）
function LeadRAndDPanel:OnOpen(type)
    researchType = type or 0
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeadRAndDPanel:OnShow()
    this.btnUpLv:SetActive(type(AircraftCarrierManager.GetMaxRresearchLv()) ~= "string")
    this.maxLv:SetActive(type(AircraftCarrierManager.GetMaxRresearchLv()) == "string")
    this.SetSpeed()
    if researchType == 0 then
        if AircraftCarrierManager.LeadData.normal.curItemId == 0 then
            this.SetResearch()
        else
            this.SetSpeedUp()
        end
    else
        if AircraftCarrierManager.LeadData.privilege.curItemId == 0 then
            this.SetResearch()
        else
            this.SetSpeedUp()
        end
    end
    CheckRedPointStatus(RedPointType.Lead_SpeedLvUp)
end

--界面关闭时调用（用于子类重写）
function LeadRAndDPanel:OnClose()
    ClearRedPointObject(RedPointType.Lead_SpeedLvUp)
end

local researchItemList = {}--研究道具
local speedupItemList = {}--加速道具
--界面销毁时调用（用于子类重写）
function LeadRAndDPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    researchItemList = {}
    speedupItemList = {}
end

--设置研究速度
function this.SetSpeed()
    local lv, nextLv, speed, nextSpeed = AircraftCarrierManager.GetMaxRresearchLv()
    Util.GetGameObject(this.lv, "cur"):GetComponent("Text").text = lv
    Util.GetGameObject(this.lv, "next"):GetComponent("Text").text = nextLv
    Util.GetGameObject(this.speed, "cur"):GetComponent("Text").text = string.format(GetLanguageStrById(22539), speed)
    Util.GetGameObject(this.speed, "next"):GetComponent("Text").text = string.format(GetLanguageStrById(22539), nextSpeed)
end

--选择研究
function this.SetResearch()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = {16, 10421, 10422, 10423}})
    this.research:SetActive(true)
    this.speedup:SetActive(false)
    for i = 1, 3 do
        local item = Util.GetGameObject(this.research, "grid").transform:GetChild(i-1).gameObject
        local chooseBg = Util.GetGameObject(item, "chooseBg")
        local pos = Util.GetGameObject(item, "pos")
        chooseBg:SetActive(item:GetComponent("Toggle").isOn)
        if not researchItemList[i] then
            researchItemList[i] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
        end
        researchItemList[i]:OnOpen(false, {MotherShipPlaneBlueprint[i].ItemId, BagManager.GetItemCountById(MotherShipPlaneBlueprint[i].ItemId)}, 1)
        researchItemList[i]:ShowNum(true)
        researchItemList[i]:ClickEnable(false)
        if item:GetComponent("Toggle").isOn then
            this.RAndDValue.text = string.format(GetLanguageStrById(22543), MotherShipPlaneBlueprint[i].ResearchDegree)
            this.probability.text = string.format(GetLanguageStrById(22542), GetLanguageStrById(MotherShipPlaneBlueprint[i].WeightsDes))
        end
        item:GetComponent("Toggle").onValueChanged:AddListener(function (state)
            if state then
                this.RAndDValue.text = string.format(GetLanguageStrById(22543), MotherShipPlaneBlueprint[i].ResearchDegree)
                this.probability.text = string.format(GetLanguageStrById(22542), GetLanguageStrById(MotherShipPlaneBlueprint[i].WeightsDes))
            end
        end)
    end
end

--加速
function this.SetSpeedUp()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = {16, 10426, 10427, 10428}})
    this.research:SetActive(false)
    this.speedup:SetActive(true)
    this.SetProgress(researchType)
    for i = 1, 3 do
        local item = Util.GetGameObject(this.speedup, "grid").transform:GetChild(i-1).gameObject
        local chooseBg = Util.GetGameObject(item, "chooseBg")
        local pos = Util.GetGameObject(item, "pos")
        local icon = Util.GetGameObject(item, "icon"):GetComponent("Image")
        local num = Util.GetGameObject(item, "num"):GetComponent("Text")
        chooseBg:SetActive(item:GetComponent("Toggle").isOn)
        if item:GetComponent("Toggle").isOn then
            this.SetFill(i)
        end
        if not speedupItemList[i] then
            speedupItemList[i] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
        end
        speedupItemList[i]:OnOpen(false, {MotherShipResearchPlus[i].CostItem[1], 0}, 1)
        speedupItemList[i]:ShowNum(false)

        local sprite
        local need
        if BagManager.GetItemCountById(MotherShipResearchPlus[i].CostItem[1]) >= MotherShipResearchPlus[i].CostItem[2] then
            sprite = GetResourcePath(ItemConfig[MotherShipResearchPlus[i].CostItem[1]].ResourceID)
            need = 1
        else
            sprite = GetResourcePath(ItemConfig[MotherShipResearchPlus[i].CostDiamond[1]].ResourceID)
            if BagManager.GetItemCountById(MotherShipResearchPlus[i].CostDiamond[1]) >= MotherShipResearchPlus[i].CostDiamond[2] then
                need = MotherShipResearchPlus[i].CostDiamond[2]
            else
                need = string.format("<color=#ff0000>%s</color>", MotherShipResearchPlus[i].CostDiamond[2])
            end
        end

        icon.sprite = Util.LoadSprite(sprite)
        num.text = need
        item:GetComponent("Toggle").onValueChanged:AddListener(function (state)
            if state then
                this.SetFill(i)
            end
        end)
    end
end

--设置研发值
function this.SetProgress(type, progress, surplusTime)
    if type ~= researchType then
        return
    end
    local data, max = AircraftCarrierManager.GetResearch(researchType)
    local time, surplus = AircraftCarrierManager.GetCurProgress(researchType)
    this.progress.text = (progress and progress or time).."/"..max
    this.slider.value = (progress and progress or time)/max
    this.surplusTime.text = string.format(GetLanguageStrById(22544), TimeToFelaxible(surplusTime and surplusTime or surplus))
end

function this.SetFill(i)
    this.add.text = "+"..MotherShipResearchPlus[i].AddResearchDegree
    local data, max = AircraftCarrierManager.GetResearch(researchType)
    local width = 610/max*MotherShipResearchPlus[i].AddResearchDegree
    Util.GetGameObject(this.slider.gameObject, "Fill Area/Fill/Image"):GetComponent("RectTransform").sizeDelta = Vector2.New(width, 28)
end

return LeadRAndDPanel