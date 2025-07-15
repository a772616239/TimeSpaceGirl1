require("Base/BasePanel")
BattleOfMinskBuyCountPopup = Inherit(BasePanel)
local this = BattleOfMinskBuyCountPopup
local WorldBossSetting = ConfigManager.GetConfig(ConfigName.WorldBossSetting)
--初始化组件（用于子类重写）
function BattleOfMinskBuyCountPopup:InitComponent()
    this.tip = Util.GetGameObject(self.gameObject, "buttom/content/text1/Image/text2"):GetComponent("Text")
    this.item = Util.GetGameObject(self.gameObject, "buttom/content/text1/Image"):GetComponent("Image")

    this.btnLeft = Util.GetGameObject(self.gameObject, "buttom/op/btnLeft")
    this.btnRight = Util.GetGameObject(self.gameObject, "buttom/op/btnRight")
end

--绑定事件（用于子类重写）
function BattleOfMinskBuyCountPopup:BindEvent()
    Util.AddClick(this.btnLeft, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.btnRight, function()
        NetManager.MINSK_BATTLE_BUYCOUNT_REQUEST(function()
            GuildCarDelayManager.GetBuyChallengeCountData()
            Game.GlobalEvent:DispatchEvent(GameEvent.Guild.CarDelayProgressChanged)
            UIManager.ClosePanel(UIName.BattleOfMinskBuyCountPopup)
            -- UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_CAR_DELEAY)
        end)
    end)
end

--添加事件监听（用于子类重写）
function BattleOfMinskBuyCountPopup:AddListener()
end

--移除事件监听（用于子类重写）
function BattleOfMinskBuyCountPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BattleOfMinskBuyCountPopup:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BattleOfMinskBuyCountPopup:OnShow(...)
    local count = GuildCarDelayManager.BuyCount
    this.price = WorldBossSetting[GuildCarDelayManager.bossIndexId].BuyPrice[count+1][2]
    this.tip.text = this.price .. GetLanguageStrById(23082)
end

--界面层级发生改变（用于子类重写）
function BattleOfMinskBuyCountPopup:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function BattleOfMinskBuyCountPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function BattleOfMinskBuyCountPopup:OnDestroy()
end


return BattleOfMinskBuyCountPopup