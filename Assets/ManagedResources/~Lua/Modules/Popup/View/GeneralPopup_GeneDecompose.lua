----- 基因分解弹窗 -----
local this = {}
local parent
local MotherShipPlaneConfig = ConfigManager.GetConfig(ConfigName.MotherShipPlaneConfig)--基因（主角技能）配置表
local count = 0
local item

function this:InitComponent(gameObject)
    this.btnCancel = Util.GetGameObject(gameObject, "btnCancel")
    this.btnConfirm = Util.GetGameObject(gameObject, "btnConfirm")
    this.itemGrid = Util.GetGameObject(gameObject, "itemGrid")
    this.btnReduce = Util.GetGameObject(gameObject, "btnReduce")
    this.btnAdd = Util.GetGameObject(gameObject, "btnAdd")
    this.slider = Util.GetGameObject(gameObject, "Slider"):GetComponent("Slider")
    this.num = Util.GetGameObject(gameObject, "num"):GetComponent("Text")
end

function this:BindEvent()
    Util.AddClick(this.btnCancel, function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.btnConfirm,function()
        if count <= 0 then
            return
        end
        local configId = AircraftCarrierManager.GetSingleSkillData(this.selectId).cfgId
        NetManager.MotherShipPlanSellRequest(configId, count, function (msg)
            AircraftCarrierManager.GetLeadData(function()
                AircraftCarrierManager.GetAllPlaneReq(function()
                    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnRefreshRune)
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
                end)
            end)
        end)
        parent:ClosePanel()
    end)
    Util.AddClick(this.btnAdd,function()
        this.SetCount(count + 1)
    end)
    Util.AddClick(this.btnReduce,function()
        this.SetCount(count - 1)
    end)
    Util.AddSlider(this.slider.gameObject, function(go, value)
        this.SetCount(value)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent, ...)
    parent = _parent
    local args = {...}
    this.selectId = args[1]
    this.SetCount(1)
end

function this:OnClose()
end

function this:OnDestroy()
    item = nil
end

function this.SetCount(value)
    local configId = AircraftCarrierManager.GetSingleSkillData(this.selectId).cfgId
    local GetItem = MotherShipPlaneConfig[configId].GetItem
    if not item then
        item = SubUIManager.Open(SubUIConfig.ItemView, this.itemGrid.transform)
    end
    local num = AircraftCarrierManager.GetSkillSimilarCount(configId, this.selectId) + 1
    this.slider.maxValue = num

    if value < 1 then value = 1 end
    if value > num then value = num end
    count = value
    this.slider.value = value
    this.num.text = value.."/"..num
    item:OnOpen(false, {GetItem[1], GetItem[2]*value}, 0.9)
end

return this