require("Base/BasePanel")
SupportImprovePanel = Inherit(BasePanel)
local this = SupportImprovePanel

local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artifactSoulConfig = ConfigManager.GetConfig(ConfigName.ArtifactSoulConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local ArtifactLevelConfig = ConfigManager.GetConfig(ConfigName.ArtifactLevelConfig)

--初始化组件（用于子类重写）
function SupportImprovePanel:InitComponent()
    this.BackBtn = Util.GetGameObject(this.gameObject, "Bg/BackBtn")
    this.BackMask = Util.GetGameObject(this.gameObject, "BackMask")
    this.slider = Util.GetGameObject(this.gameObject, "Slider"):GetComponent("Slider")
    this.leftbtn = Util.GetGameObject(this.gameObject, "Slider/leftbtn")
    this.rightbtn = Util.GetGameObject(this.gameObject, "Slider/rightbtn")
    this.count = Util.GetGameObject(this.gameObject, "Slider/count"):GetComponent("Text")
    this.SureBtn = Util.GetGameObject(this.gameObject, "SureBtn")
    this.SureBtnRedPoint = Util.GetGameObject(this.gameObject, "SureBtn/Redpot")
    this.ATK = Util.GetGameObject(this.gameObject, "ATK")
    this.HP = Util.GetGameObject(this.gameObject, "HP")
    this.UsedTimes = Util.GetGameObject(this.gameObject, "UsedTimes"):GetComponent("Text")
    this.Icon = Util.GetGameObject(this.gameObject, "Item/Icon"):GetComponent("Image")
    this.IconBtn = Util.GetGameObject(this.gameObject, "Item/Icon")
end

--绑定事件（用于子类重写）
function SupportImprovePanel:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.SureBtn, function()
        if this.supportLv >= 3 then
            local count = this.slider.value
            if count <= 0 then
                PopupTipPanel.ShowTipByLanguageId(22301)
                return
            end

            local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            NetManager.GetSupportSoulUp(count, function(_msg)
                if _msg.result and _msg.result ~= 0 then
                    local oldlv = SupportManager.GetDataById("soulNum")
                    SupportManager.SetDataById("soulNum", oldlv + count)
                    PopupTipPanel.ShowTipByLanguageId(22302)
                    self:ClosePanel()

                    if SupportPanel then
                        SupportPanel.CheckRedPoint()
                    end
                    

                    FormationManager.FlutterPower(oldPower)

                end
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10598)
            return
        end
    end)

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

    Util.AddClick(this.IconBtn, function()
        local itemId=artifactSoulConfig[1].ConsumeItem[1]
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,itemId)
    end)
end

--添加事件监听（用于子类重写）
function SupportImprovePanel:AddListener()
    
end

--移除事件监听（用于子类重写）
function SupportImprovePanel:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function SupportImprovePanel:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SupportImprovePanel:OnShow()
    this.usedTimes = SupportManager.GetDataById("soulNum")
    this.soulData = artifactSoulConfig[1]
    this.addProTimes = math.floor(this.usedTimes / this.soulData.Bout)
    this.supportLv = SupportManager.GetDataById("level")

    -- -- 改良系统也是由支援武器等级升级进行激活强化的，
    -- -- 支援武器升级到3级后可进行强化，强化次数上限为15次，
    -- -- 支援武器升级到4级后可进行强化25次，之后支援武器每升一级则可提升强化上限次数25次。
    -- this.upLimitTimes = 15
    -- if this.supportLv == 3 then
    --     this.upLimitTimes = 15
    -- elseif this.supportLv == 4 then
    --     this.upLimitTimes = 25
    -- elseif this.supportLv >= 5 then
    --     this.upLimitTimes = (this.supportLv - 3)*25
    -- end

    
    
    local artifactConfig = ArtifactLevelConfig[this.supportLv]
    
    this.upLimitTimes = artifactConfig.SoulLimit

    this.canUseTimesMax = this.upLimitTimes - this.usedTimes
    
    
    local materialTimes = BagManager.GetItemCountById(this.soulData.ConsumeItem[1]) / this.soulData.ConsumeItem[2]
    this.maxNum = math.min(this.canUseTimesMax, materialTimes)

    
    
    
    

    
    this.Icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[this.soulData.ConsumeItem[1]].ResourceID))
    ItemImageTips(this.soulData.ConsumeItem[1], Util.GetGameObject(this.gameObject, "Item/Icon"))

    this.slider.enabled = this.maxNum > 1
    this.slider.maxValue = this.maxNum
    this.slider.minValue = 0
    this.slider.value = this.maxNum > 0 and 1 or 0

    SupportImprovePanel:UpdateUI()

    this.SureBtnRedPoint:SetActive(SupportManager.CheckImproveIsEnough())
end

function SupportImprovePanel:UpdateUI()
    local proid1 = this.soulData.PropertyAdd[1][1]
    local provalue1 = this.soulData.PropertyAdd[1][2]
    local proid2 = this.soulData.PropertyAdd[2][1]
    local provalue2 = this.soulData.PropertyAdd[2][2]
    provalue1 = provalue1 * this.addProTimes
    provalue2 = provalue2 * this.addProTimes
    
    this.ATK:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(propertyConfig[proid1].Icon))
    this.HP:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(propertyConfig[proid2].Icon))
    Util.GetGameObject(this.ATK, "Text"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[proid1].Info) .. "：+" .. GetPropertyFormatStr(propertyConfig[proid1].Style, provalue1)
    Util.GetGameObject(this.HP, "Text"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[proid2].Info) .. "：+" .. GetPropertyFormatStr(propertyConfig[proid2].Style, provalue2)

    this.UsedTimes.text = GetLanguageStrById(50356) .. this.usedTimes .. "/" .. this.upLimitTimes

end

function SupportImprovePanel.OnSliderValueChange(value)
    this.count.text = value
end

--界面关闭时调用（用于子类重写）
function SupportImprovePanel:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function SupportImprovePanel:OnDestroy()

end

return SupportImprovePanel