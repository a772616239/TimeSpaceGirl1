require("Base/BasePanel")
-- 使用炸弹跟召唤界面
TrialOpPanel = Inherit(BasePanel)
local this = TrialOpPanel
local callBack
local panelType = 0
local trialConfig = ConfigManager.GetConfig(ConfigName.TrialConfig)
local showDrop
local ctrlView = require("Modules/Map/View/MapControllView")
local go
local canCallBoss = true
-- 炸弹怪
-- local theBombBitch = "live2d_m_hypd_0003"
--初始化组件（用于子类重写）
function TrialOpPanel:InitComponent()

    -- this.btnCallBoss = Util.GetGameObject(self.gameObject, "UI_effect_shilian_tab/btnCallBoss")
    -- this.btnUseBomb = Util.GetGameObject(self.gameObject, "BombRoot/monsterRoot/btnUseBomb")
    --特效节点
    this.bossEffect = Util.GetGameObject(self.gameObject, "UI_effect_shilian_tab")
    -- this.bombRoot = Util.GetGameObject(self.gameObject, "BombRoot/monsterRoot")
    -- this.bombEffect = Util.GetGameObject(self.gameObject, "BombRoot/UI_effect_boom")
    -- 炮兵父节点
    -- this.live2dRoot = Util.GetGameObject(self.gameObject, "BombRoot/monsterRoot/live2dRoot")
    -- this.btnBack = Util.GetGameObject(self.gameObject, "BombRoot/monsterRoot/btnBack")
end

--绑定事件（用于子类重写）
function TrialOpPanel:BindEvent()
    -- Util.AddClick(this.btnUseBomb, this.UseBomb)
    -- Util.AddClick(this.btnBack, function ()
    --     self:ClosePanel()
    -- end)
end

--添加事件监听（用于子类重写）
function TrialOpPanel:AddListener()

end

--移除事件监听（用于子类重写）
function TrialOpPanel:RemoveListener()

end

-- 打开界面类型
-- 1 === 召唤boss
-- 2 == 使用炸弹
--界面打开时调用（用于子类重写）
function TrialOpPanel:OnOpen(type, func)
    panelType = type
    callBack = func
    this.InitBtnShow()
end

-- 初始化界面显示
function this.InitBtnShow()
    -- if panelType == 1 then
        this.bossEffect:SetActive(true)--进图显示召唤boss
        -- this.bombRoot:SetActive(false)
        -- 界面打开时删除所有小怪
        this.KillAllBitch()
        ctrlView.CallListPop()
        local timer1 = Timer.New(function ()
            this:ClosePanel()
            MapTrialManager.canMove = true
        end, 1.5)
        timer1:Start()
    -- elseif panelType == 2 then
    --     this.bossEffect:SetActive(false)
    --     this.bombRoot:SetActive(true)
    --     this.LoadTheBitch()
    -- end
end

-- function this.CallBoss()
--     if canCallBoss then
--         canCallBoss = false
--         MapManager.MapUpdateEvent(-1000, function ()
--             -- 初始化路径
--             ctrlView.CallListPop()
--             NetManager.RequestMapBoss(function (msg)

--                 local u, v = Map_Pos2UV(msg.monsterInfo.cellId)


--                 local pos = msg.monsterInfo.cellId
--                 local mapPoint = msg.monsterInfo.pointId
--                 MapTrialManager.bossType = msg.type
--                 Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointAdd, pos, mapPoint)

--                 -- 更新精气值
--                 MapTrialManager.isHaveBoss = true
--                 MapTrialManager.UpdatePowerValue(-1)
--                 this.bossEffect:SetActive(false)
--                 this.bombRoot:SetActive(false)
--                 TrialOpPanel:ClosePanel()
--                 MapTrialManager.canMove = true
--                 -- 打开召唤的类界面
--                 UIManager.OpenPanel(UIName.TrialBossTipPopup, msg.type)
--             end)
--         end)
--     end
-- end

-- function this.UseBomb()
--     this.bombRoot:SetActive(false)
--     this.bombEffect:SetActive(true)

--     --  等待特效播放完毕
--     local timer = Timer.New(function ()
--         this.I_Need_A_Bomb()
--     end, 1.5)
--     timer:Start()
-- end

-- 加载炮兵
-- function this.LoadTheBitch()
--     -- 加载炮兵
--     go = poolManager:LoadLive(theBombBitch, this.live2dRoot.transform, Vector3.one, Vector3.zero)
-- end

-- 向服务器请求使用炸弹
-- function this.I_Need_A_Bomb()
--     -- 非事件同步坐标位置
--     MapManager.MapUpdateEvent(-1000, function ()

--         NetManager.RequestUseBomb(function (msg)

--             ctrlView.CallListPop()
--             -- 更新背包数量
--             BagManager.DeleteTempBagCountById(43, 1)
--             this.KillAllBitch()
--             showDrop = function()
--                 UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 2, function ()
--                     -- 回复精气值
--                     MapTrialManager.UpdatePowerValue(msg.essenceValue)
--                 end)
--             end
--             TrialOpPanel:ClosePanel()
--         end)
--     end)
-- end

-- 弄死所有的小怪
function this.KillAllBitch()
    -- --杀死所有的小怪
    -- MapManager.isRemoving = true
    -- local pointData = trialConfig[MapTrialManager.curTowerLevel].MonsterPoint --MonsterPoint
    -- for i = 1, #pointData do
    --     local mapPointId = pointData[i][1]
    --     if mapPointId then

    --         MapManager.DeletePos(mapPointId)
    --     end
    -- end
    -- MapManager.isRemoving = false
end


--界面关闭时调用（用于子类重写）
function TrialOpPanel:OnClose()

    if callBack then callBack() end
    if showDrop then showDrop() end
    showDrop = nil
    callBack = nil
    -- 炮兵还在的话
    if go then
        poolManager:UnLoadLive(theBombBitch, go)
        go = nil
    end

    -- 重置状态
    this.bombRoot:SetActive(false)
    this.bombEffect:SetActive(false)
end

--界面销毁时调用（用于子类重写）
function TrialOpPanel:OnDestroy()

end

return TrialOpPanel