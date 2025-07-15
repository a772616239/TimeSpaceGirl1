require("Base/BasePanel")
WarWayLevelUpPopup = Inherit(BasePanel)
local this = WarWayLevelUpPopup

local WarWaySkillConfig = ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)
local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
--初始化组件（用于子类重写）
function WarWayLevelUpPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "btnClose")

    this.ForgetBtn = Util.GetGameObject(self.gameObject, "bg/Btns/ForgetBtn")
    this.ResetBtn = Util.GetGameObject(self.gameObject, "bg/Btns/ResetBtn")
    this.LevelUpBtn = Util.GetGameObject(self.gameObject, "bg/Btns/LevelUpBtn")

    this.CurWarWay = Util.GetGameObject(self.gameObject, "bg/CurWarWay")
    this.UpWarWay = Util.GetGameObject(self.gameObject, "bg/UpWarWay")
    this.CostPart = Util.GetGameObject(self.gameObject, "bg/CostPart")
    this.Top = Util.GetGameObject(self.gameObject, "bg/Top")

    this.NeedStar = Util.GetGameObject(self.gameObject, "bg/NeedStar")
end

--绑定事件（用于子类重写）
function WarWayLevelUpPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.ForgetBtn, function()
        --这个传过去的玩家能力id应该是当前的，而不是用升级之前的id，要不然就会发生视图层和模型层数据不一致的问题
        local curWarWaySlotId= this.heroData[string.format("warWaySlot%dId", this.slot)]
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.WarWayForget, this.heroData, this.slot, curWarWaySlotId, self)
    end)

    Util.AddClick(this.ResetBtn, function()
        
    end)
    Util.AddClick(this.LevelUpBtn, function()
        if self.isEnoughMaterials then
            local warWaySlotId = this.heroData[string.format("warWaySlot%dId", this.slot)]
            local warWayConfig = WarWaySkillConfig[warWaySlotId]
            local cost = WarWaySkillConfig[warWaySlotId+1]

            if warWayConfig.Level < 4 then
                if this.heroData.star < cost.TankStarLimit then
                    PopupTipPanel.ShowTipByLanguageId(12506)
                else
                    NetManager.WarWayLearning(this.heroData.dynamicId, warWaySlotId, this.slot, function(msg)
                        local nextId = tonumber(tostring(warWayConfig.WarWayGroup) .. tostring(warWayConfig.Level + 1))
                        HeroManager.UpdateWarWayData(this.heroData.dynamicId, this.slot, nextId, true)
                        RoleInfoPanel:UpdatePanelData()
                        self:UpdateUI()
                    end)
                end
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10455)
        end
    end)
end

--添加事件监听（用于子类重写）
function WarWayLevelUpPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function WarWayLevelUpPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function WarWayLevelUpPopup:OnOpen(...)
    local args = {...}
    this.heroData = args[1]
    this.slot = args[2]
    this.warWaySlotId = args[3]

    self.isEnoughMaterials = true
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function WarWayLevelUpPopup:OnShow()
    self:UpdateUI()
end

function WarWayLevelUpPopup:UpdateUI()
    local warWaySlotId = this.heroData[string.format("warWaySlot%dId", this.slot)]
    local warWayConfig = WarWaySkillConfig[warWaySlotId]
    --local cost=WarWaySkillConfig[warWaySlotId+1]

    local function setIcon(go, warWayConfig)
        Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(warWayConfig.Image))
        local passiveConfig = PassiveSkillConfig[warWayConfig.SkillId]
        Util.GetGameObject(go, "Name"):GetComponent("Text").text = GetLanguageStrById(passiveConfig.Name)
        Util.GetGameObject(go, "Desc"):GetComponent("Text").text = GetLanguageStrById(passiveConfig.Desc)

        Util.AddOnceClick(Util.GetGameObject(go, "frame"), function()
            UIManager.OpenPanel(UIName.CommonInfoPopup, CommonInfoType.WarWay, Util.GetGameObject(go, "frame"), warWayConfig.ID)
        end)
    end

    setIcon(this.CurWarWay, warWayConfig)

    this.NeedStar:SetActive(false)
    if warWayConfig.Level >= 4 then
        --> max
        this.UpWarWay:SetActive(false)
        this.CostPart:SetActive(false)
        this.LevelUpBtn:SetActive(false)
        this.Top:SetActive(true)
        
        return
    else
        this.UpWarWay:SetActive(true)
        this.CostPart:SetActive(true)
        this.LevelUpBtn:SetActive(true)
        this.Top:SetActive(false)
    end

    local nextId = tonumber(tostring(warWayConfig.WarWayGroup) .. tostring(warWayConfig.Level + 1))
    local warWayConfigNext = WarWaySkillConfig[nextId]
    setIcon(this.UpWarWay, warWayConfigNext)

    --> materials
    for i = 1, 2 do --< 目前支持俩
        local costgo = Util.GetGameObject(this.CostPart, "cost" .. tostring(i))
        if #warWayConfigNext.UpgradeCost >= i then
            local itemid = warWayConfigNext.UpgradeCost[i][1]
            local itemnum = warWayConfigNext.UpgradeCost[i][2]

            local icon = Util.GetGameObject(costgo, "icon")
            local Name = Util.GetGameObject(costgo, "Name")
            local Num = Util.GetGameObject(costgo, "Num")
            local frame = Util.GetGameObject(costgo, "frame")

            local itemData = ItemConfig[itemid]
            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemData.Quantity))
            icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
            Name:GetComponent("Text").text = GetLanguageStrById(itemData.Name)
            local ownNum = BagManager.GetItemCountById(itemid)
            Num:GetComponent("Text").text = GetNumUnenoughColor(ownNum, itemnum, PrintWanNum2(ownNum), PrintWanNum2(itemnum))
            ItemImageTips(itemid, icon)
            if ownNum < itemnum then
                self.isEnoughMaterials = false
            end

            costgo:SetActive(true)
        else
            costgo:SetActive(false)
        end
    end

    
    if warWayConfigNext.TankStarLimit == 0 then
    else
        this.NeedStar:SetActive(true)
        if this.heroData.star >= warWayConfigNext.TankStarLimit then
            this.NeedStar:GetComponent("Text").text = string.format("<color=#00FF00FF>%s</color>", GetLanguageStrById(50340) .. this.heroData.star .. "/" .. warWayConfigNext.TankStarLimit)
        else
            this.NeedStar:GetComponent("Text").text = string.format("<color=#FF0000FF>%s</color>", GetLanguageStrById(50340) .. this.heroData.star .. "/" .. warWayConfigNext.TankStarLimit)
        end
    end
    
end

--界面关闭时调用（用于子类重写）
function WarWayLevelUpPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function WarWayLevelUpPopup:OnDestroy()

end

return WarWayLevelUpPopup