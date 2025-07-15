
local this = {}

local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local adjutantHandselConfig = ConfigManager.GetConfig(ConfigName.AdjutantHandselConfig)

--初始化组件（用于子类重写）
function this:InitComponent(parentNode)
    this.parentNode = parentNode
    this.slider = Util.GetGameObject(parentNode, "Slider"):GetComponent("Slider")
    this.leftbtn = Util.GetGameObject(parentNode, "Slider/leftbtn")
    this.rightbtn = Util.GetGameObject(parentNode, "Slider/rightbtn")
    this.count = Util.GetGameObject(parentNode, "Slider/count"):GetComponent("Text")
    
    this.ATK = Util.GetGameObject(parentNode, "ATK")
    this.HP = Util.GetGameObject(parentNode, "HP")
    this.UsedTimes = Util.GetGameObject(parentNode, "UsedTimes"):GetComponent("Text")
    this.Icon = Util.GetGameObject(parentNode, "Item/Icon")

    this.SureBtn = Util.GetGameObject(parentNode, "SureBtn")
    this.SureBtnRedpot = Util.GetGameObject(parentNode, "SureBtn/Redpot")
    this.Item = Util.GetGameObject(parentNode, "Item")
    this.SliderGo = Util.GetGameObject(parentNode, "Slider")
    this.MaxPic = Util.GetGameObject(parentNode, "MaxPic")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddSlider(this.slider.gameObject, function(go, value)
        this.OnSliderValueChange(value)
    end)

    Util.AddClick(this.leftbtn, function()
        local curCount = this.slider.value
        if curCount <= 1 then return end
        this.slider.value = curCount - 1
    end)
    Util.AddClick(this.rightbtn, function()
        local curCount = this.slider.value
        if curCount >= this.maxNum then return end
        this.slider.value = curCount + 1
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function this:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()
    self.adjutantId = AdjutantManager.GetCurSelectAdjutantId()

    this:UpdateUI()
    BindRedPointObject(RedPointType.Adjutant_Btn_Handsel,this.SureBtnRedpot)
end

function this:UpdateUI()
    CheckRedPointStatus(RedPointType.Adjutant_Btn_Chat)
    self.data = AdjutantManager.GetOneAdjutantDataById(self.adjutantId)
    this.usedTimes = self.data.handselNum
    this.handselData = adjutantHandselConfig[1]
    this.addProTimes = math.floor(this.usedTimes / this.handselData.Bout)
    local adjutantChatData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantChatConfig, "AdjutantId", self.adjutantId, "Lvl", self.data.chatLevel)
    
    this.upLimitTimes = adjutantChatData.UpgradeLimit
    this.canUseTimesMax = this.upLimitTimes - this.usedTimes
    
    local materialTimes = BagManager.GetItemCountById(this.handselData.ConsumeItem[1]) / this.handselData.ConsumeItem[2]
    this.maxNum = math.min(this.canUseTimesMax, materialTimes)

    
    this.Icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[this.handselData.ConsumeItem[1]].ResourceID))
    ItemImageTips(this.handselData.ConsumeItem[1], this.Icon)

    this.slider.enabled = this.maxNum > 1
    this.slider.maxValue = this.maxNum
    this.slider.minValue = 0
    this.slider.value = this.maxNum > 0 and 1 or 0


    local proid1 = this.handselData.PropertyAdd[1][1]
    local proid2 = this.handselData.PropertyAdd[2][1]
    local id1, provalue1 = AdjutantManager.GetOnePro(proid1, self.adjutantId, 2)
    local id2, provalue2 = AdjutantManager.GetOnePro(proid2, self.adjutantId, 2)
  
    Util.GetGameObject(this.ATK, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(propertyConfig[proid1].Icon))
    Util.GetGameObject(this.HP, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(propertyConfig[proid2].Icon))
    Util.GetGameObject(this.ATK, "name"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[proid1].Info)
    Util.GetGameObject(this.ATK, "value"):GetComponent("Text").text = "+" .. GetPropertyFormatStr(propertyConfig[proid1].Style, provalue1)
    Util.GetGameObject(this.HP, "name"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[proid2].Info)
    Util.GetGameObject(this.HP, "value"):GetComponent("Text").text = "+" .. GetPropertyFormatStr(propertyConfig[proid2].Style, provalue2)

    this.UsedTimes.text = GetLanguageStrById(22300) .. this.usedTimes .. "/" .. this.upLimitTimes

    if this.usedTimes >= AdjutantManager.GetMaxLimit(self.adjutantId, 3) then
        this.SureBtn:SetActive(false)
        this.Item:SetActive(false)
        this.SliderGo:SetActive(false)
        this.MaxPic:SetActive(true)
        return
    else
        this.SureBtn:SetActive(true)
        this.Item:SetActive(true)
        this.SliderGo:SetActive(true)
        this.MaxPic:SetActive(false)
    end

    Util.AddOnceClick(this.SureBtn, function()
        local count = this.slider.value
        if count == 0 then
            PopupTipPanel.ShowTipByLanguageId(22301)
            return
        end
        local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        NetManager.GetAdjutantHandsel(self.adjutantId, count, function()
            NetManager.GetAllAdjutantInfo(function()    --< 需要重拉下数据 目前和后端这么定
                self:UpdateUI()
                RefreshPower(oldPower)
                CheckRedPointStatus(RedPointType.Adjutant_Btn_Handsel)
                -- local data = AdjutantManager.GetOneAdjutantDataById(AdjutantManager.GetCurSelectAdjutantId())
                -- if data and AdjutantPanel then
                --     AdjutantPanel.FreshData(data)
                -- end
            end)
        end)
    end)

    this.SureBtnRedpot:SetActive(AdjutantManager.IsHandselEnough(self.adjutantId))
end

function this.OnSliderValueChange(value)
    this.count.text = value
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    ClearRedPointObject(RedPointType.Adjutant_Btn_Handsel,this.SureBtnRedpot)
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

return this