require("Modules/Map/Logic/TileMapView")
GuildMemberView = {}
GuildMemberView.__index = GuildMemberView

local mapNpcOp = "UI_effect_DiTu_member"
function GuildMemberView.New(isSelf, curXY, name, gPos, sex, Ctrl)
    local instance = {}
    setmetatable(instance, GuildMemberView)

    instance.isSelf = isSelf

    local u, v = GuildMap_Pos2UV(curXY)

    instance.posData = TileMapView.GetMapData():GetMapData(u, v)
    instance.leader = poolManager:LoadAsset(mapNpcOp, PoolManager.AssetType.GameObject)
    instance.leader:SetActive(false)
    Util.GetGameObject(instance.leader, "root/ui"):GetComponent("Canvas").worldCamera = TileMapView.GetCamera()

    instance.name = name
    instance.mapNpc = ConfigManager.GetConfigDataByKey(ConfigName.PlayerRole, "Role", sex).LiveAnimName
    local scale = sex == ROLE_SEX.BOY and 1 or 0.5
    instance.NpcGO = poolManager:LoadAsset(instance.mapNpc, PoolManager.AssetType.GameObject)
    instance.NpcGO:SetActive(true)
    instance.NpcGO.transform:SetParent(Util.GetTransform(instance.leader, "root"))
    instance.NpcGO.transform.localPosition = Vector3.New(0,0, -1)
    instance.NpcGO.transform.localScale = Vector3.one * 30 * scale
    instance.NpcGO.name = "npc"
    Util.SetParticleSortLayer(instance.NpcGO, 0)

    instance.SkeletonGraphic = Util.GetGameObject(instance.leader, "root/npc"):GetComponent("SkeletonAnimation")
    instance.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    instance.SkeletonGraphic.transform.localEulerAngles = Vector3.zero

    --instance.leader.transform:SetParent(Ctrl.transform)
    instance.leader.transform:SetParent(Util.GetTransform(Ctrl, "effectGroup2#"))
    instance.leader:SetActive(true)

    local v3 = TileMapView.GetLiveTilePos(u, v)
    instance.leader.transform.localScale = Vector3.one
    instance.leader.transform.localPosition = Vector3(v3.x, v3.y, v3.z - v)

    instance.PosText = Util.GetGameObject(instance.leader, "root/ui/pos/text"):GetComponent("Text")

    if isSelf then
        Util.GetGameObject(instance.leader, "root/ui"):GetComponent("Canvas").sortingOrder = 5
        instance.NameText = Util.GetGameObject(instance.leader, "root/ui/name/text"):GetComponent("Text")
    else
        Util.GetGameObject(instance.leader, "root/ui"):GetComponent("Canvas").sortingOrder = 0
        instance.NameText = Util.GetGameObject(instance.leader, "root/ui/name/text2"):GetComponent("Text")
    end
    Util.GetGameObject(instance.leader, "root/ui/name/text"):SetActive(isSelf)
    Util.GetGameObject(instance.leader, "root/ui/name/text2"):SetActive(not isSelf)

    instance.guildPosIcon = Util.GetGameObject(instance.leader, "root/ui/name/root/Image"):GetComponent("Image")
    instance:SetGuildPos(gPos)

    instance.NameText.text = name

    instance:AddListener()
    instance:RefreshPos(u, v)

    return instance
end

function GuildMemberView:AddListener()

end

--移除事件监听（用于子类重写）
function GuildMemberView:RemoveListener()

end

-- 点击角色
function GuildMemberView:OnClick()
end

--事件监听结束-------------
function GuildMemberView:RefreshPos(u, v)
    self.posData = TileMapView.GetMapData():GetMapData(u, v)
    self.PosText.text = string.format("(%d, %d)", u, v)
end

-- 设置角色行走方向
local WALK_DIR = {
    RIGHT = {animation = "move2", y = 0},
    LEFT = {animation = "move2", y = 180},
    UP = {animation = "move3", y = 0},
    DOWN = {animation = "move", y = 0},
}

function GuildMemberView:SetRoleDirAction(dU, dV, isBack)
    -- local dU = isBack and self.posData.u - u or u - self.posData.u
    -- local dV = isBack and self.posData.v - v or v - self.posData.v

    if dU > 0 and math.abs(dU) > math.abs(dV) then
        self:SetWalkDir(WALK_DIR.RIGHT)
    elseif dU < 0 and math.abs(dU) > math.abs(dV)  then
        self:SetWalkDir(WALK_DIR.LEFT)
    elseif dV > 0 and math.abs(dV) > math.abs(dU)  then
        self:SetWalkDir(WALK_DIR.UP)
    elseif dV < 0 and math.abs(dV) > math.abs(dU) then
        self:SetWalkDir(WALK_DIR.DOWN)
    end
    SoundManager.PlaySound(SoundConfig.Sound_FootStep..math.random(1,7))
end

function GuildMemberView:SetWalkDir(dir)
    if not self.curDir or self.curDir ~= dir then
        self.curDir = dir
        self.SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, dir.y, 0)
        self.SkeletonGraphic.AnimationState:SetAnimation(0, dir.animation, true)
    end
end

function GuildMemberView:PlayerIdle()
    self.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    self.SkeletonGraphic.transform.localEulerAngles = Vector3.zero
    self.curDir = nil
end

function GuildMemberView:Dispose()
    self:RemoveListener()
    if self.mapNpc then
        poolManager:UnLoadLive(self.mapNpc, self.NpcGO)
        self.mapNpc = nil
    end
    poolManager:UnLoadAsset(mapNpcOp, self.leader, PoolManager.AssetType.GameObject)
    self.leader = nil
end

-- 设置职位显示
GuildMemberView.GPosToSprite = {
    [GUILD_GRANT.MASTER] = "r_gonghui_toubiao_01",
    [GUILD_GRANT.ADMIN] = "r_gonghui_toubiao_02",
}
function GuildMemberView:SetGuildPos(gPos)
    if not gPos or gPos == GUILD_GRANT.MEMBER then
        self.guildPosIcon.gameObject:SetActive(false)
    else
        self.guildPosIcon.gameObject:SetActive(true)
        self.guildPosIcon.sprite = Util.LoadSprite(GuildMemberView.GPosToSprite[gPos])
    end

end