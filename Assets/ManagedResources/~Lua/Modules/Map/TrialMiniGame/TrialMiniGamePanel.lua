require("Base/BasePanel")
local BuffChoosePanel = Inherit(BasePanel)
local this = BuffChoosePanel
local _LogicConfig = {
    [13] = require("Modules/Map/TrialMiniGame/Logic/Game_13"),
    [14] = require("Modules/Map/TrialMiniGame/Logic/Game_14"),
    [15] = require("Modules/Map/TrialMiniGame/Logic/Game_15"),
    [16] = require("Modules/Map/TrialMiniGame/Logic/Game_16"),
    [17] = require("Modules/Map/TrialMiniGame/Logic/Game_17"),
    [18] = require("Modules/Map/TrialMiniGame/Logic/Game_18"),
}


--初始化组件（用于子类重写）
function BuffChoosePanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "mask")

    this._ViewConfig = {}
    for type, _ in pairs(_LogicConfig) do
        this._ViewConfig[type] = Util.GetGameObject(self.gameObject, "Game_"..type)
    end
end

--绑定事件（用于子类重写）
function BuffChoosePanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        -- this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function BuffChoosePanel:AddListener()
end

--移除事件监听（用于子类重写）
function BuffChoosePanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BuffChoosePanel:OnOpen(gameType, gameId, gameParams)
    this.logic = _LogicConfig[gameType]
    this.logic.Init(self, this._ViewConfig[gameType], gameType, gameId, gameParams)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BuffChoosePanel:OnShow()
    for index, value in pairs(this._ViewConfig) do
        value:SetActive(false)
    end
    -- this._ViewConfig[gameType]--再打开
    this.logic.Show()
end

--界面关闭时调用（用于子类重写）
function BuffChoosePanel:OnClose()
    this.logic.Close()
    TrialMiniGameManager.GameClose()
end

--界面销毁时调用（用于子类重写）
function BuffChoosePanel:OnDestroy()
    this.logic.Destroy()
end

return BuffChoosePanel