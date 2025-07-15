require("Base/BasePanel")
AdjutantFuncPopup = Inherit(BasePanel)
local this = AdjutantFuncPopup

local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local adjutantChatConfig = ConfigManager.GetConfig(ConfigName.AdjutantChatConfig)
local adjutantConfig = ConfigManager.GetConfig(ConfigName.AdjutantConfig)
local adjutantHandselConfig = ConfigManager.GetConfig(ConfigName.AdjutantHandselConfig)
local adjutantSkillConfig = ConfigManager.GetConfig(ConfigName.AdjutantSkillConfig)
local adjutantTeachConfig = ConfigManager.GetConfig(ConfigName.AdjutantTeachConfig)

local _levelFinish = true
local _isAutoLevelUp = false
local _autoLevelUpIntervalTime = 0.1
local _lastLevelUpTime = 0
local _tabIdx = 1


local subModel = {
    [1] = {script = require("Modules/Adjutant/AdjutantFuncChat"), nodeName = "connectPart"},
    [2] = {script = require("Modules/Adjutant/AdjutantFuncSkill"), nodeName = "skillPart"},
    [3] = {script = require("Modules/Adjutant/AdjutantFuncHandsel"), nodeName = "giftPart"},
    [4] = {script = require("Modules/Adjutant/AdjutantFuncTeach"), nodeName = "trainPart"},
}
local subModelNodes = {}

--初始化组件（用于子类重写）
function AdjutantFuncPopup:InitComponent()
    this.BgMask = Util.GetGameObject(self.gameObject, "BgMask")
	this.backBtn = Util.GetGameObject(self.gameObject, "backBtn")

    for i, model in ipairs(subModel) do
        subModelNodes[i] = Util.GetGameObject(self.gameObject, model.nodeName)
        model.script:InitComponent(subModelNodes[i])
        
    end
end

--绑定事件（用于子类重写）
function AdjutantFuncPopup:BindEvent()

    Util.AddClick(this.BgMask, function()
        self:ClosePanel()
    end)
	
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)

    -- --长按升级按下状态
    -- this._onPointerDown = function(Pointgo, data)
    --     _isAutoLevelUp = true
    -- end
    -- --长按升级抬起状态
    -- this._onPointerUp = function(Pointgo, data)
    --     _isAutoLevelUp = false
    -- end
    -- this.upLvTrigger.onPointerDown = this.upLvTrigger.onPointerDown + this._onPointerDown
    -- this.upLvTrigger.onPointerUp = this.upLvTrigger.onPointerUp + this._onPointerUp

    for _, model in ipairs(subModel) do
        model.script:BindEvent()
    end
end

--添加事件监听（用于子类重写）
function AdjutantFuncPopup:AddListener()
    for _, model in ipairs(subModel) do
        model.script:AddListener()
    end
end

--移除事件监听（用于子类重写）
function AdjutantFuncPopup:RemoveListener()
    for _, model in ipairs(subModel) do
        model.script:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function AdjutantFuncPopup:OnOpen(...)
    local args = {...}
    this.openType = args[1]
    this.adjutantId = args[2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AdjutantFuncPopup:OnShow()

    this:Init()

    -- FixedUpdateBeat:Add(this.OnUpdate, self)--长按方法注册

    _levelFinish = true
    _isAutoLevelUp = false
    _lastLevelUpTime = 0

    for i, model in ipairs(subModel) do
        if this.openType == i then
            model.script:OnShow(this.adjutantId)
        end
    end
end

function AdjutantFuncPopup:Init()
    for i, node in ipairs(subModelNodes) do
        node:SetActive(this.openType == i)
    end
end


function AdjutantFuncPopup.OnUpdate()
    if _isAutoLevelUp and Time.realtimeSinceStartup - _lastLevelUpTime > _autoLevelUpIntervalTime and _levelFinish then
        _lastLevelUpTime = Time.realtimeSinceStartup
        AdjutantFuncPopup.LevelUp()
    end
end

--界面关闭时调用（用于子类重写）
function AdjutantFuncPopup:OnClose()
    FixedUpdateBeat:Remove(this.OnUpdate, self)--长按方法注册

    for _, model in ipairs(subModel) do
        --if this.openType == _ then
            model.script:OnClose()
        --end
    end
    AdjutantManager.CheckAllRedPoint()
    AdjutantPanel:OnShow()
    CheckRedPointStatus(RedPointType.Adjutant)
end

--界面销毁时调用（用于子类重写）
function AdjutantFuncPopup:OnDestroy()
    for _, model in ipairs(subModel) do
        model.script:OnDestroy()
    end
end

return AdjutantFuncPopup