BtView = {}
local this = BtView
local bagPanelUI
local RoleListPanelUI
--- 静态数据
local static_openId = 0

local wordColors = {
    [0] = {fontColor = Color.New(1, 1, 1, 1), outLineColor = Color.New(0, 0, 0, 1)},
    [1] = {fontColor = Color.New(255 / 255, 244 / 255, 65 / 255, 1), outLineColor = Color.New(98 / 255, 55 / 255, 1 / 255, 1)},
}

function BtView:New(gameObject) 
    
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = BtView })
    return b
end

--初始化组件（用于子类重写）
function this:InitComponent()
    --basicPart
    self.BtnMainCity = Util.GetGameObject(self.gameObject, "Down/btnMainCity")
    self.BtnChengYuan = Util.GetGameObject(self.gameObject, "Down/btnChengYuan")
    self.BtnCangKu = Util.GetGameObject(self.gameObject, "Down/btnCangKu")
    self.BtnJieLing = Util.GetGameObject(self.gameObject, "Down/btnJieLing")
    self.BtnCarbon = Util.GetGameObject(self.gameObject, "Down/btnCarbon") -- 副本
    self.BtnGongHui = Util.GetGameObject(self.gameObject, "Down/btnGongHui")
    self.BtnTeQuan = Util.GetGameObject(self.gameObject, "Down/btnTeQuan")
    self.inBattle = Util.GetGameObject(self.BtnJieLing,"inBattle")
    self.btnChat = Util.GetGameObject(self.gameObject, "btnChat")
    self.textCountDown = Util.GetGameObject(self.gameObject, "Down/btnGongHui/textCountDown"):GetComponent("Text")

    -- 主城与副本的新字
    self.mainCityNew = Util.GetGameObject(self.BtnMainCity, "xin")
    self.carbonNew = Util.GetGameObject(self.BtnCarbon, "xin")
    self.btnText = {
        -- [PanelTypeView.Carbon] = self.carbonNew,
        [PanelTypeView.MainCity] = self.mainCityNew,
    }
    self.AnimRoot = Util.GetGameObject(self.gameObject, "Down")

    self._BtnConfig = {
        [PanelTypeView.MainCity] = {node = self.BtnMainCity, funcId = {49}, rpType = RedPointType.MainCity, clickFunc = self.OPenMainCity},
        [PanelTypeView.MemberPanel] = {node = self.BtnChengYuan, funcId = {23}, rpType = RedPointType.Role, clickFunc = self.OpenChengYuan},
        [PanelTypeView.BagPanel] = {node = self.BtnCangKu, funcId = {23}, rpType = RedPointType.Bag, clickFunc = self.OpenCangKu},
        [PanelTypeView.JieLing] = {node = self.BtnJieLing, funcId = {}, rpType = RedPointType.SecretTer, clickFunc = self.OpenJieling},
        [PanelTypeView.Carbon] = {node = self.BtnCarbon, funcId = {17, 18, 30, 46, 67}, rpType = RedPointType.ExploreMain, clickFunc = self.OpenCarbon},
        [PanelTypeView.GongHui] = {node = self.BtnGongHui, funcId = {4}, rpType = RedPointType.Guild, clickFunc = self.OpenGuild},
        -- [PanelTypeView.SupportPanel] = {node = self.BtnTeQuan, funcId = {79}, rpType = RedPointType.Support, clickFunc = self.OpenSupport},    --< 特权改支援
        [PanelTypeView.Logistics] = {node = self.BtnTeQuan, funcId = {79, 76, 90}, rpType = RedPointType.Logistics, clickFunc = self.OpenLogistics},    --< 特权改后勤
    }
end

-- 主城
function this:OPenMainCity()
    if not UIManager.IsOpen(UIName.MainPanel) then
        UIManager.OpenPanel(UIName.MainPanel)
        PlaySoundWithoutClick(SoundConfig.Sound_BattleStart_01)
    end
end
--打开英雄列表界面
function this:OpenChengYuan()
    if not UIManager.IsOpen(UIName.HeroMainPanel)  or (RoleListPanelUI and RoleListPanelUI.isFirstOpen == false)then
        HeroManager.heroListPanelSortID = 1
        HeroManager.heroListPanelProID = 0
        -- RoleListPanelUI = UIManager.OpenPanel(UIName.RoleListPanel)
        RoleListPanelUI = UIManager.OpenPanel(UIName.HeroMainPanel,1)
         PlaySoundWithoutClick(SoundConfig.Sound_n1_ui_sound_open_book)
    end
end
--打开仓库界面
function this:OpenCangKu()
    -- if true then
    --     UIManager.OpenPanel(UIName.HeroMonumentPanel)
    --     return
    -- end
    if not UIManager.IsOpen(UIName.BagPanel) or (bagPanelUI and bagPanelUI.isFristOpen == false) then
        bagPanelUI =  UIManager.OpenPanel(UIName.BagPanel)
         PlaySoundWithoutClick(SoundConfig.Sound_UI_Bag)
    end
end

-- 挂机界面
function this:OpenJieling()
    UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    PlaySoundWithoutClick(SoundConfig.Sound_BattleStart_04)
end
-- 打开副本选择界面
function this:OpenCarbon()
    PlayerManager.carbonType = 1
    UIManager.OpenPanel(UIName.CarbonTypePanelV2)
     PlaySoundWithoutClick(SoundConfig.Sound_BattleStart_01)
end
function this:OpenGuild()
    JumpManager.GoJump(4001)
end
function this:OpenVIP()
    UIManager.OpenPanel(UIName.VipPanelV2)
end
--> 后勤
function this:OpenLogistics()
    UIManager.OpenPanel(UIName.LogisticsMainPanel)
    PlaySoundWithoutClick(SoundConfig.Sound_BattleStart_01)
end

--绑定事件（用于子类重写）
function this:BindEvent()    
    for pt, data in pairs(self._BtnConfig) do
        Util.AddClick(data.node, function()
            --if self.panelType == pt then return end 
            --> map out 问题
            Game.GlobalEvent:DispatchEvent(GameEvent.TrialMap.BtViewOut)

            self:OnBtnClick(pt)
        end)
        -- 绑定红点
        if data.rpType then
            BindRedPointObject(data.rpType, Util.GetGameObject(data.node,"redPoint"))
        end
    end

    Util.AddClick(self.btnChat, function ()
        UIManager.OpenPanel(UIName.ChatPanel)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnLevelChange, self.RefreshBtnState, self)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, self.RefreshBtnState, self)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionClose, self.RefreshBtnState, self)
    Game.GlobalEvent:AddEvent(GameEvent.Formation.OnFormationChange, self.RefreshRedPoint, self)
    Game.GlobalEvent:AddEvent(GameEvent.Battle.OnBattleUIEnd, self.BattleEnd, self)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnLevelChange, self.RefreshBtnState, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnFunctionOpen, self.RefreshBtnState, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnFunctionClose, self.RefreshBtnState, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnFormationChange, self.RefreshRedPoint, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Battle.OnBattleUIEnd, self.BattleEnd, self)
end
function this:RefreshRedPoint()
    CheckRedPointStatus(RedPointType.Role)
    CheckRedPointStatus(RedPointType.LineupRecommend)
    CheckRedPointStatus(RedPointType.HeroTab)
end

function this:BattleEnd()
    self.inBattle:SetActive(BattleManager.IsInBackBattle())
end

---@param context table
-- context: {
--   sortOrder = int,
--   panelType = int,
-- }
--界面打开时调用（用于子类重写）
function this:OnOpen(context)

    if context then
        self:SetOrderStatus(context)
        self:SetSelectTarget(context)
    end

    -- 刷新显示状态
    self:RefreshBtnState()
    self:BattleEnd()
end

function this:RefreshBtnState()
    -- 
    for pt, data in pairs(self._BtnConfig) do
        local isOpen = self:CheckIsOpen(pt)
        Util.SetGray(data.node, not isOpen)
        Util.GetGameObject(data.node, "lock"):SetActive(not isOpen)
    end

    self:InitNewOpenShow()
    self:CheckMainCityNew()
    self:SetAnimState()
    self:CheckGuildCooling()
end

--检测公会是否有加入冷却
function this:CheckGuildCooling()
    local thawStamp = MyGuildManager.ExitTimeStamp + (tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,511).Value) * 3600)
    local timeDown =  math.ceil(thawStamp - GetTimeStamp());
    
    if timeDown <= 0 then 
        self.textCountDown.gameObject:SetActive(false)
        return
    end

    if not self.textCountDown or not GetTimeStamp() or self.timer then return end


    self.textCountDown.gameObject:SetActive(true)
    self.textCountDown.text = TimeToHM(timeDown)

    self.timer = Timer.New(function()
        self.textCountDown.text = TimeToHM(timeDown)
        timeDown = timeDown - 1
        if timeDown <= 0 then
            self.timer:Stop()
            self.timer = nil
            self.textCountDown.gameObject:SetActive(false)
        end
    end, 1, -1, true)
    self.timer:Start()
end

-- 检测是否开启
function this:CheckIsOpen(pt)
    -- if pt == PanelTypeView.GongHui then
    --     return false --公会尚未开启
    -- end

    local isOpen = false
    local data = self._BtnConfig[pt]
    if #data.funcId ~= 0 then
        for _, id in ipairs(data.funcId) do
            if ActTimeCtrlManager.SingleFuncState(id) then
                isOpen = true
                break
            end
        end
    else
        isOpen = true
    end
    return isOpen
end

-- 按钮点击事件
function this:OnBtnClick(pt)
    local isOpen = self:CheckIsOpen(pt)
    if isOpen then
        local btnFunc = self._BtnConfig[pt].clickFunc
        if btnFunc then
            btnFunc(self)
        end
    else
        local str = ""
        if pt == PanelTypeView.Carbon then
            str = ActTimeCtrlManager.CarbonOpenTip()
        else
            local id = self._BtnConfig[pt].funcId[1]
            str = ActTimeCtrlManager.GetFuncTip(id)
        end
        PopupTipPanel.ShowTip(str)
    end
end

-- 初始化新字显示, 先只检查副本
function this:InitNewOpenShow()
    -- local isOpen = FunctionOpenMananger.GetRootState(PanelTypeView.Carbon)
    -- Util.GetGameObject(self.BtnCarbon.transform, "xin"):SetActive(isOpen)
end

-- 检测主城
function this:CheckMainCityNew()
    -- local isOpen = FunctionOpenMananger.GetRootState(PanelTypeView.MainCity)
    -- Util.GetGameObject(self.BtnMainCity.transform, "xin"):SetActive(isOpen)
end

function this:SetAnimState()
    -- local mainCityOpen = FunctionOpenMananger.GetRootState(PanelTypeView.MainCity)
    -- local carbonOpen = FunctionOpenMananger.GetRootState(PanelTypeView.Carbon)
    -- local isUseAnim = mainCityOpen or carbonOpen
    -- if isUseAnim then
    --     PlayUIAnim(self.AnimRoot)
    -- else
    --     PlayUIAnimBack(self.AnimRoot)
    -- end
end
--界面关闭时调用（用于子类重写）
function this:OnClose()
    for pt, data in pairs(self._BtnConfig) do
        if data.rpType then
            ClearRedPointObject(data.rpType, Util.GetGameObject(data.node,"redPoint"))
        end
    end

    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end

    bagPanelUI = nil
    RoleListPanelUI = nil
end


--设定层级
function this:SetOrderStatus(context)
    if not context.sortOrder then
        return
    end
    self.transform:GetComponent("Canvas").sortingOrder = context.sortOrder + 1
end

function this:OnSortingOrderChange(sortingOrder)
    self.transform:GetComponent("Canvas").sortingOrder = sortingOrder + 1
end

--设定选中
function this:SetSelectTarget(context)
    if not context.panelType then
        return
    end
    self.panelType = context.panelType
    for pt, selectInfo in pairs(self._BtnConfig) do
        Util.GetGameObject(selectInfo.node, "btnSelect"):SetActive(pt == context.panelType)
        local text = Util.GetGameObject(selectInfo.node, "Text")
        if pt == context.panelType then
            text:GetComponent("Text").color = wordColors[1].fontColor
            text:GetComponent("Outline").effectColor = wordColors[1].outLineColor
        else
            text:GetComponent("Text").color = wordColors[0].fontColor
            text:GetComponent("Outline").effectColor = wordColors[0].outLineColor
        end
    end
    FightPointPassManager.isOutFight = context.panelType == PanelTypeView.JieLing

end

return BtView