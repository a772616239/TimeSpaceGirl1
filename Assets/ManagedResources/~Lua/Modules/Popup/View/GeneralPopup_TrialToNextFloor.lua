----- 试炼进入下一层 -----
local this = {}
local showType
local eventId
local showValues
local options
local eventConfig = ConfigManager.GetConfig(ConfigName.EventPointConfig)

function this:InitComponent(gameObject)
    this.bodyText = Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.btnSure = Util.GetGameObject(gameObject,"ConfirmBtn")
    this.btnCancel = Util.GetGameObject(gameObject,"CancelBtn")
end

function this:BindEvent()
    Util.AddClick(this.btnCancel,function()
        local optionId = eventConfig[eventId].Option[2]
        Timer.New(function()
            -- 刷新数据
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
        end, 0.1):Start()
        OptionBehaviourManager.JumpEventPoint(eventId, optionId, UIManager.GetOpenPanel(UIName.GeneralPopup))
    end)

    Util.AddClick(this.btnSure,function()
        local optionId = eventConfig[eventId].Option[1]
        OptionBehaviourManager.JumpEventPoint(eventId, optionId,UIManager.GetOpenPanel(UIName.GeneralPopup))
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(this,_showType, _eventId, _showValues, _options)
    showType = _showType
    eventId = _eventId
    showValues = _showValues
    options = _options
end

function this:OnClose()
    Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
end

function this:OnDestroy()
end

return this