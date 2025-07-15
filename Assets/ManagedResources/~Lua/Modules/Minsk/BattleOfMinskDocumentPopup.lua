require("Base/BasePanel")
BattleOfMinskDocumentPopup = Inherit(BasePanel)
local this = BattleOfMinskDocumentPopup
local WorldBossConfig = ConfigManager.GetConfig(ConfigName.WorldBossConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)

--初始化组件（用于子类重写）
function BattleOfMinskDocumentPopup:InitComponent()
    this.name = Util.GetGameObject(self.gameObject, "bg/name"):GetComponent("Text")
    this.content = Util.GetGameObject(self.gameObject, "bg/content"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.live = Util.GetGameObject(self.gameObject, "bg/live")
end

--绑定事件（用于子类重写）
function BattleOfMinskDocumentPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function BattleOfMinskDocumentPopup:AddListener()
end

--移除事件监听（用于子类重写）
function BattleOfMinskDocumentPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BattleOfMinskDocumentPopup:OnOpen(...)
    local arg = {...}
    this.id = arg[1]
    this.config = heroConfig[WorldBossConfig[this.id].Boss]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BattleOfMinskDocumentPopup:OnShow()
    this.content.text = string.format(GetLanguageStrById(WorldBossConfig[this.id].BossDes))
    this.name.text = GetLanguageStrById(WorldBossConfig[this.id].Name)
    if not this.liveObj then
        this.liveObj = LoadHerolive(this.config, this.live)
    end
end

function BattleOfMinskDocumentPopup:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function BattleOfMinskDocumentPopup:OnClose()
    if this.liveObj and this.config then
        UnLoadHerolive(this.config, this.live)
        this.liveObj = nil
    end
end

--界面销毁时调用（用于子类重写）
function BattleOfMinskDocumentPopup:OnDestroy()

end

return BattleOfMinskDocumentPopup