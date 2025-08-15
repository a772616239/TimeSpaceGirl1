
local PlayerHeadFrameView = {}

function PlayerHeadFrameView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = PlayerHeadFrameView })
    return b
end
--初始化组件（用于子类重写）
function PlayerHeadFrameView:InitComponent()

    self.expVaule = Util.GetGameObject(self.gameObject, "LeftUp/exp"):GetComponent("Slider")
    self.expVauleText = Util.GetGameObject(self.gameObject, "LeftUp/exp/Text"):GetComponent("Text")

    self.frame = Util.GetGameObject(self.gameObject, "LeftUp/headBox/frame"):GetComponent("Image")
    self.icon = Util.GetGameObject(self.gameObject, "LeftUp/headBox/icon"):GetComponent("Image")
    self.levelLv = Util.GetGameObject(self.gameObject, "LeftUp/headBox/lvFrame/lv"):GetComponent("Text")

    self.VIPLevel = Util.GetGameObject(self.gameObject, "LeftUp/VIPLevel"):GetComponent("Image")

    self.headBtn = Util.GetGameObject(self.gameObject, "LeftUp/headBox/headpos")

    self.power = Util.GetGameObject(self.gameObject, "LeftUp/powerBtn/value"):GetComponent("Text")
    self.name = Util.GetGameObject(self.gameObject, "LeftUp/name"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function PlayerHeadFrameView:BindEvent()
    Util.AddClick(self.headBtn, function()
        if AppConst.isOpenGM then
            -- if self.isOpen then
                UIManager.OpenPanel(UIName.GMPanel)
            -- else
            --     UIManager.OpenPanel(UIName.SettingPanel)
            -- end
        else
            UIManager.OpenPanel(UIName.SettingPanel)
        end
    end)
end

--添加事件监听（用于子类重写）
function PlayerHeadFrameView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Vip.OnVipRankChanged, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnPlayerLvChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:AddEvent(GameEvent.FormationCenter.OnFormationCenterLevelChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnHeadChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnHeadFrameChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:AddEvent(GameEvent.HeroGrade.OnHeroGradeChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnPowerChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnPlayNameChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnPlayRingChange, self.RefreshPlayerInfoShow, self)
end

--移除事件监听（用于子类重写）
function PlayerHeadFrameView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Vip.OnVipRankChanged, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnPlayerLvChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.FormationCenter.OnFormationCenterLevelChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnHeadChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnHeadFrameChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.HeroGrade.OnHeroGradeChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnPowerChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnPlayNameChange, self.RefreshPlayerInfoShow, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnPlayRingChange, self.RefreshPlayerInfoShow, self)
end

--界面打开时调用（用于子类重写）
function PlayerHeadFrameView:OnOpen(...)
    --self:RefreshPlayerInfoShow()
    --self:Reset()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PlayerHeadFrameView:OnShow(isOpen)
    self.isOpen = isOpen
    self:RefreshPlayerInfoShow()
end

function PlayerHeadFrameView:OnSortingOrderChange(sortingOrder)
    local canvas = self.gameObject:GetComponent("Canvas")
    canvas.overrideSorting = true
    canvas.sortingOrder = sortingOrder
end

--界面关闭时调用（用于子类重写）
function PlayerHeadFrameView:OnClose()
    --ClearRedPointObject(RedPointType.Setting, this.headRedpot)

    --self:Reset()
end
function PlayerHeadFrameView:RefreshPlayerInfoShow()
    -- Safely get level data
    local levelData = nil
    if PlayerManager and PlayerManager.userLevelData and PlayerManager.level then
        levelData = PlayerManager.userLevelData[PlayerManager.level]
    end
    if  not IsNull(PlayerManager.exp) then
         -- Handle exp display with fallbacks
        if self.expVaule and levelData then
            self.expVaule.value = PlayerManager.exp / levelData.Exp
        elseif self.expVaule then
            self.expVaule.value = 0  -- Fallback value
        end

        if self.expVauleText and levelData then
            self.expVauleText.text = PlayerManager.exp.."/".. levelData.Exp
        elseif self.expVauleText then
            self.expVauleText.text = PlayerManager.exp.."/0"  -- Fallback text
        end
    end


    -- Safe UI updates with nil checks
    if not IsNull(self.icon) then
        self.icon.sprite = GetPlayerHeadSprite(PlayerManager.head)
    end

    if not IsNull(self.frame) then
        self.frame.sprite = GetPlayerHeadFrameSprite(PlayerManager.frame)
    end

    if not IsNull(self.levelLv) then
        self.levelLv.text = "Lv." .. tostring(PlayerManager.level or 0)
    end

    if not IsNull(self.VIPLevel) then
        self.VIPLevel.sprite = VipManager.SetVipLevelImg()
    end

    if not IsNull(self.power) then
        -- Fixed to show clearance power
        self.power.text = FormationManager.GetFormationPower(1) 
        FormationManager.UserPowerChanged()
    end

    if not IsNull(self.name) then
        self.name.text = PlayerManager.nickName or ""
    end
end



function PlayerHeadFrameView:Recycle()
    SubUIManager.Close(self)
end
return PlayerHeadFrameView