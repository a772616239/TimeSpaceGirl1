require("Modules/Map/Logic/TileMapView")
MapAgent = {}
MapAgent.__index = MapAgent

local mapNpcOp = "UI_effect_DiTu_agent"
local mapNpc = "live2d_npc_map"
local mapNpc2 = "live2d_npc_map_nv"
local npc, scale
function MapAgent.New(isSelf, agentData, Ctrl)
    local instance = {}
    setmetatable(instance, MapAgent)

    instance.isSelf = isSelf
    instance.agentData = agentData

    local u, v = Map_Pos2UV(agentData.curXY)

    --instance.posData = TileMapView.GetMapData():GetMapData(u, v)
    instance.leader = poolManager:LoadAsset(mapNpcOp, PoolManager.AssetType.GameObject)
    instance.leader:SetActive(false)
    Util.GetGameObject(instance.leader, "root/ui"):GetComponent("Canvas").worldCamera = TileMapView.GetCamera()
    local v3 = TileMapView.GetLiveTilePos(u, v)
    instance.leader.transform.localPosition = Vector3(v3.x, v3.y, v3.z - 10)
    instance.leader.transform.localScale = Vector3.one * 1.5

    npc = NameManager.roleSex == ROLE_SEX.BOY and mapNpc or mapNpc2
    scale = NameManager.roleSex == ROLE_SEX.BOY and Vector3.one or Vector3.one * 0.5

    instance.NpcGO = poolManager:LoadLive(mapNpc, Util.GetTransform(instance.leader, "root/ui/roleRoot"), scale, Vector3.zero)
    instance.NpcGO.name = "npc"
    instance.SkeletonGraphic = Util.GetGameObject(instance.leader, "root/ui/roleRoot/npc"):GetComponent("SkeletonGraphic")
    instance.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    instance.SkeletonGraphic.transform.localEulerAngles = Vector3.zero

    instance.leader:SetActive(true)
    PlayUIAnim(instance.leader, function ()
        TileMapView.UpdateWarFog(u, v, 2)
        PlayUIAnim(Util.GetGameObject(instance.leader, "root/ui/arrow"))
    end)
    instance.leader.transform:SetParent(Ctrl.transform)

    instance.fightEffect = Util.GetGameObject(instance.leader, "root/ui/quickBattleEffect")

    instance:RefreshOption(isSelf)
    instance:AddListener()
    instance:OnRefreshFormationHp()
    instance:RefreshPos(u, v)

    return instance
end

function MapAgent:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.BuffAdd, self.OnBuffAdd, self)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.BuffChange, self.OnBuffChange, self)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.BuffRemove, self.OnBuffRemove, self)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.HPChange, self.OnRefreshFormationHp, self)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.MineralChange, self.OnRefreshMineral, self)
end

--移除事件监听（用于子类重写）
function MapAgent:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.BuffAdd, self.OnBuffAdd, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.BuffChange, self.OnBuffChange, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.BuffRemove, self.OnBuffRemove, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.HPChange, self.OnRefreshFormationHp, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.MineralChange, self.OnRefreshMineral, self)
end

function MapAgent:RefreshOption(isSelf)
    --坐标显示
    self.PosText = Util.GetGameObject(self.leader, "root/ui/pos"):GetComponent("Text")
    --行动力显示
    self.energyProImg = Util.GetGameObject(self.leader, "root/ui/actionProgress/progress")
    self.energyMaxText = Util.GetGameObject(self.leader, "root/ui/actionProgress/maxEnergy")
    self.energyText = Util.GetGameObject(self.energyMaxText, "energy")

    self.NpcCloseOpBtn = Util.GetGameObject(self.leader, "root/ui/optionCancelBtn")
    self.NpcOption = Util.GetGameObject(self.leader, "root/ui/roleOption")

    -- 总血量显示
    self.roleYellowHp = Util.GetGameObject(self.leader, "root/ui/blood/hpYellow"):GetComponent("Image")
    self.roleRedHp = Util.GetGameObject(self.leader, "root/ui/blood/hpRed"):GetComponent("Image")
    self.mineralNum = Util.GetGameObject(self.leader, "root/ui/blood/mineral/Text"):GetComponent("Text")
    self.mineralNum.text = tostring(self.agentData.mineral)

    Util.GetGameObject(self.leader, "root/ui/camp/text"):GetComponent("Text").text = self.agentData.userName
    Util.GetGameObject(self.leader, "root/ui/camp/text2"):GetComponent("Text").text = self.agentData.userName

    Util.GetGameObject(self.leader, "root/ui/camp/text"):SetActive(isSelf)
    Util.GetGameObject(self.leader, "root/ui/camp/text2"):SetActive(not isSelf)
    Util.GetGameObject(self.leader, "root/ui/camp/dead"):SetActive(false)

    self.NpcOption:SetActive(false)
    self.NpcCloseOpBtn:SetActive(false)

    Util.AddOnceClick(self.NpcCloseOpBtn, function()
        self.NpcCloseOpBtn:SetActive(false)
        self.NpcOption:SetActive(false)
        --this.btnTeamRoot:SetActive(false)
        self.DragCtrl:SetActive(true)
    end)


    Util.AddOnceClick(Util.GetGameObject(self.NpcOption, "beibao"), function()  -- 背包
        UIManager.OpenPanel(UIName.MapBagPopup)
    end)
    Util.AddOnceClick(Util.GetGameObject(self.NpcOption, "jiacheng"), function()  -- 加成
        UIManager.OpenPanel(UIName.FoodGainPopup)
    end)
    Util.AddOnceClick(Util.GetGameObject(self.NpcOption, "shiwu"), function()  -- 加成
        PopupTipPanel.ShowTipByLanguageId(11335)
    end)
    Util.AddOnceClick(Util.GetGameObject(self.NpcOption, "duiyuan"), function()  -- 队员
        UIManager.OpenPanel(UIName.MapFormationInfoPopup)
    end)
end

-- 点击角色
function MapAgent:OnClick()
    --self.NpcCloseOpBtn:SetActive(true)
    --self.NpcOption:SetActive(true)
    --this.DragCtrl:SetActive(false)
end

--事件监听-------------
function MapAgent:OnBuffAdd(buff)
    if buff.target ~= self.agentData.playerUid then return end
   
    if buff.type == 3 then

        self.fightEffect:SetActive(true)
    elseif buff.type == 4 then

        Util.GetGameObject(self.leader, "root/ui/camp/dead"):SetActive(true)
    end
end

function MapAgent:OnBuffChange(buff)
    if buff.target ~= self.agentData.playerUid then return end
   
end

function MapAgent:OnBuffRemove(buff)
    if buff.target ~= self.agentData.playerUid then return end
   
    if buff.type == 3 then
        self.fightEffect:SetActive(false)
    elseif buff.type == 4 then
        Util.GetGameObject(self.leader, "root/ui/camp/dead"):SetActive(false)
    end
end
--事件监听结束-------------
function MapAgent:RefreshPos(u, v)
    local v3 = TileMapView.GetLiveTilePos(u, v)
    self.leader.transform.localPosition = Vector3.New(v3.x, v3.y, v3.z - 10)
    self.posData = TileMapView.GetMapData():GetMapData(u, v)
    self.PosText.text = string.format("(%d, %d)", u, v)
    self.agentData.curXY = Map_UV2Pos(u, v)
end

-- 初始化角色血条
function MapAgent:InitRoleHp(relife)
    self.roleYellowHp.gameObject:SetActive(relife)
    self.roleRedHp.gameObject:SetActive(not relife)
    if relife then
        self.roleYellowHp.fillAmount = 1
        self.roleRedHp.fillAmount = 1
    else
        self.roleYellowHp.fillAmount = 0
        self.roleRedHp.fillAmount = 0
    end
end

function MapAgent:OnRefreshFormationHp(id, hp)
    if id ~= self.agentData.playerUid then return end
    self.roleYellowHp.fillAmount = hp / self.agentData.maxHp
end

function MapAgent:OnRefreshMineral(id, mineral)
    if id ~= self.agentData.playerUid then return end
    self.mineralNum.text = tostring(mineral)
end

-- 设置角色行走方向
local WALK_DIR = {
    RIGHT = {animation = "move2", y = 0},
    LEFT = {animation = "move2", y = 180},
    UP = {animation = "move3", y = 0},
    DOWN = {animation = "move", y = 0},
}

function MapAgent:SetRoleDirAction(u, v, isBack)
    local dU = isBack and self.posData.u - u or u - self.posData.u
    local dV = isBack and self.posData.v - v or v - self.posData.v

    if dU > 0 then
        self:SetWalkDir(WALK_DIR.RIGHT)
    elseif dU < 0 then
        self:SetWalkDir(WALK_DIR.LEFT)
    elseif dV < 0 then
        self:SetWalkDir(WALK_DIR.UP)
    elseif dV > 0 then
        self:SetWalkDir(WALK_DIR.DOWN)
    end
    SoundManager.PlaySound(SoundConfig.Sound_FootStep..math.random(1,7))
end

function MapAgent:SetWalkDir(dir)
    if not self.curDir or self.curDir ~= dir then
        self.curDir = dir
        self.SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, dir.y, 0)
        self.SkeletonGraphic.AnimationState:SetAnimation(0, dir.animation, true)
    end
end

function MapAgent:SetRoleBattleAction()
    self.SkeletonGraphic.AnimationState:SetAnimation(0, "jingya", false)
    self.SkeletonGraphic.transform.localEulerAngles = Vector3.zero
end

-- 设置角色的位置
function MapAgent:SetRolePos(lastPos)
    if lastPos ~= 0 then
        local u, v = Map_Pos2UV(lastPos)
        local v3 = TileMapView.GetLiveTilePos(u, v)

        self:SetRoleDirAction(u, v, false)

        self.leader.transform.localPosition = Vector3.New(v3.x, v3.y, v3.z - 10)
        self.posData = TileMapView.GetMapData():GetMapData(u, v)
        local v3 = self.leader.transform.localPosition
        v3.z = TileMapView.ViewCameraPos.z
        TileMapView.SetCameraPos(v3)
        TileMapView.UpdateBaseData()
    end
end

function MapAgent:PlayerIdle()
    self.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    self.SkeletonGraphic.transform.localEulerAngles = Vector3.zero
    self.curDir = nil
end

function MapAgent:Dispose()
    self:RemoveListener()
    poolManager:UnLoadLive(mapNpc, self.NpcGO)
    poolManager:UnLoadAsset(mapNpcOp, self.leader, PoolManager.AssetType.GameObject)
    self.leader = nil
end