HorseRaceLampView = {}
require("Base/BasePanel")
require("Base/Stack")
HorseRaceLampView = Inherit(BasePanel)
--初始化组件（用于子类重写）
function HorseRaceLampView:InitComponent()
    --跑马灯
    self.titleInfo = Util.GetGameObject(self.gameObject, "bgImage/mask/titleInfo")
    self.horseMask = Util.GetGameObject(self.gameObject, "bgImage/mask")
end

--绑定事件（用于子类重写）
function HorseRaceLampView:BindEvent()
end

--添加事件监听（用于子类重写）
function HorseRaceLampView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.HorseRace.ShowHorseRace, self.CheckShow, self)
end

--移除事件监听（用于子类重写）
function HorseRaceLampView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.HorseRace.ShowHorseRace, self.CheckShow, self)
end

--
function HorseRaceLampView:CheckShow()
    -- 已关闭
    if not self.IsOpen then return end
    -- 正在跑
    if self.IsRunning then return end
    -- 显示
    self:ShowHorse()
end

--频道跑马灯
function HorseRaceLampView:ShowHorse()
    local race = HorseRaceManager.GetRaceData()
    if not race then
        self.IsRunning = false
        return
    end
    self.IsRunning = true
    self.gameObject:SetActive(true)
    -- self.titleInfo:GetComponent("Text").text = race.content
    self.titleInfo:GetComponent("Text").text = GetMailConfigDesc(race.content, race.chatparms)
    local runDistance = self.horseMask.transform.rect.width + self.titleInfo:GetComponent("Text").preferredWidth
    local startPosX = runDistance/2
    local stopPosX = -runDistance/2
    local costTime = runDistance / race.speed--ChatManager.horseRunSpeed
    self.titleInfo.transform.localPosition = Vector2.New(startPosX, self.titleInfo.transform.localPosition.y)
    self.titleInfo:GetComponent("RectTransform"):DOLocalMoveX(stopPosX, costTime, false):SetEase(Ease.Linear):OnComplete(function()
        if not self.IsOpen then return end
        self.gameObject:SetActive(false)
        self:ShowHorse()
    end)
end



--界面打开时调用（用于子类重写）
function HorseRaceLampView:OnOpen(...)
    self.IsOpen = true
    self.gameObject:SetActive(false)
end

-- 关闭界面时调用
function HorseRaceLampView:OnClose()
    self.IsOpen = false
end


return HorseRaceLampView