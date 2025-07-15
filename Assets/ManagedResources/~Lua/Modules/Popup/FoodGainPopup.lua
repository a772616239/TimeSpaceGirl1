require("Base/BasePanel")
local FoodGainPopup = Inherit(BasePanel)
local this = FoodGainPopup
local _StayItemList = {}
local _StepItemList = {}

--初始化组件（用于子类重写）
function FoodGainPopup:InitComponent()
    self.btnBack = Util.GetGameObject(self.gameObject, "bg/bg/btnBack")
    this.stayItem = Util.GetGameObject(self.gameObject, "stayItem")
    this.stepItem = Util.GetGameObject(self.gameObject, "item")
    this.stayRoot = Util.GetGameObject(self.gameObject, "bg/stayScroll/root")
    this.stepRoot = Util.GetGameObject(self.gameObject, "bg/stepScroll/root")
end

--绑定事件（用于子类重写）
function FoodGainPopup:BindEvent()
    Util.AddClick(self.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function FoodGainPopup:AddListener()
end

--移除事件监听（用于子类重写）
function FoodGainPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function FoodGainPopup:OnOpen(...)
    this.InitAllBuff()
end

-- 初始化人物身上的所有buff效果
function this.InitAllBuff()
    -- 关闭显示
    for _, item in ipairs(_StayItemList) do
        item:SetActive(false)
    end
    for _, item in ipairs(_StepItemList) do
        item:SetActive(false)
    end

    --
    local props = FoodBuffManager.GetBuffPropList()
    if not props then return end
    local stayIndex = 0
    local stepIndex = 0
    for _, prop in ipairs(props) do
        if prop.id ~= 6 and prop.id ~= 67 then
            if prop.step < 0 then
                if prop.value ~= 0 then
                    stayIndex = stayIndex + 1
                    local item = _StayItemList[stayIndex]
                    if not item then
                        item = newObjToParent(this.stayItem, this.stayRoot)
                        _StayItemList[stayIndex] = item
                    end
                    this.StayPropAdapter(item, prop)
                    item:SetActive(true)
                end
            else
                stepIndex = stepIndex + 1
                local item = _StepItemList[stepIndex]
                if not item then
                    item = newObjToParent(this.stepItem, this.stepRoot)
                    _StepItemList[stepIndex] = item
                end
                this.StepPropAdapter(item, prop)
                item:SetActive(true)
            end
        end
    end
end

-- 固定
function this.StayPropAdapter(item, prop)
    local name = Util.GetGameObject(item, "name"):GetComponent("Text")
    local value = Util.GetGameObject(item, "value"):GetComponent("Text")

    -- 显示内容
    local propInfo = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.id)
    local val = prop.value
    local express1 = val >= 0 and "+" or ""
    local express2 = ""
    if propInfo.Style == 2 then
        val = val / 100
        express2 = "%"
    end
    name.text = propInfo.Info
    value.text = express1..val..express2

end

-- 步数
function this.StepPropAdapter(item, prop)
    local icon = Util.GetGameObject(item, "Image"):GetComponent("Image")
    local leftStep = Util.GetGameObject(item, "buffName"):GetComponent("Text")
    local name = Util.GetGameObject(item, "buffDesc"):GetComponent("Text")
    local progress = Util.GetGameObject(item, "Process/Image"):GetComponent("Image")

    local propInfo = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.id)

    -- 图标
    if propInfo.BuffShow then
        local lastStr = ""
        if propInfo.IfBuffShow == 1 then
            lastStr = prop.value >= 0 and "_Up" or "_Down"
        end
        icon.sprite = Util.LoadSprite(propInfo.BuffShow .. lastStr)
    else

    end

    -- 剩余步数
    leftStep.text = prop.step
    progress.fillAmount = prop.step / prop.totalStep

    -- 显示内容
    local val = prop.value
    local express1 = val >= 0 and "+" or ""
    local express2 = ""
    if propInfo.Style == 2 then
        val = val / 100
        express2 = "%"
    end
    name.text = propInfo.Info .. express1..val..express2

end

--界面关闭时调用（用于子类重写）
function FoodGainPopup:OnClose()
end
--界面销毁时调用（用于子类重写）
function FoodGainPopup:OnDestroy()
    _StayItemList = {}
    _StepItemList = {}
end

return FoodGainPopup