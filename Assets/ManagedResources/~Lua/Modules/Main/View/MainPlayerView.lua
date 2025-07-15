MainPlayerView = {}
MainPlayerView.__index = MainPlayerView

local mapNpcOp = "UI_MainPlayer"
function MainPlayerView.New(isSelf, root, rect, pos)
    local instance = {}
    setmetatable(instance, MainPlayerView)

    instance.isSelf = isSelf
    instance.leader = poolManager:LoadAsset(mapNpcOp, PoolManager.AssetType.GameObject)
    instance.roleRootTran = Util.GetTransform(instance.leader, "roleRoot")

    instance.leader:SetActive(true)
    instance.leader.transform:SetParent(root.transform)
    instance.leader.transform.localPosition = Vector3.zero
    instance.leader.transform.localScale = Vector3.one

    local sex, npc, scale
    if isSelf then
        instance.NameText = Util.GetGameObject(instance.leader, "name/text"):GetComponent("Text")
        Util.GetGameObject(instance.leader, "name/text"):SetActive(true)
        Util.GetGameObject(instance.leader, "name/text2"):SetActive(false)
        sex = NameManager.roleSex
    else
        instance.NameText = Util.GetGameObject(instance.leader, "name/text2"):GetComponent("Text")
        Util.GetGameObject(instance.leader, "name/text"):SetActive(false)
        Util.GetGameObject(instance.leader, "name/text2"):SetActive(true)
        sex = math.random(0,1)
    end
    instance.NameText.text = PlayerManager.nickName

    npc = ConfigManager.GetConfigDataByKey(ConfigName.PlayerRole, "Role", sex).LiveAnimName
    scale = sex == ROLE_SEX.BOY and 1 or 0.5

    instance.NpcGO = poolManager:LoadAsset(npc, PoolManager.AssetType.GameObject)
    instance.NpcGO:SetActive(true)
    instance.NpcGO.transform:SetParent(instance.roleRootTran)
    instance.NpcGO.transform.localPosition = Vector3.zero
    instance.NpcGO.transform.localScale = Vector3.one * 1.3 * scale
    instance.NpcGO.name = "npc"
    instance.SkeletonGraphic = Util.GetGameObject(instance.leader, "roleRoot/npc"):GetComponent("SkeletonAnimation")
    instance.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    instance.SkeletonGraphic.transform.localEulerAngles = Vector3.zero

    instance.rect = rect
    instance.leader:GetComponent("RectTransform").anchoredPosition = pos
    instance.lastPos = pos

    instance:SetRolePosZ(pos)
    instance:AddListener()

    return instance
end

function MainPlayerView:AddListener()

end

--移除事件监听（用于子类重写）
function MainPlayerView:RemoveListener()

end

-- 点击角色
function MainPlayerView:OnClick()
end


-- 设置角色行走方向
local WALK_DIR = {
    RIGHT = {animation = "move2", y = 0},
    LEFT = {animation = "move2", y = 180},
    UP = {animation = "move3", y = 0},
    DOWN = {animation = "move", y = 0},
}


function MainPlayerView:SetAutoMove()
    if self.isSelf then return end
    local x = math.random(self.rect.xMin, self.rect.xMax)
    local y = math.random(self.rect.yMin, self.rect.yMax)

    self:SetRolePos(Vector2.New(x, y), math.random(10, 100), function ()
        self:SetAutoMove()
    end)
end

function MainPlayerView:SetName()
    self.NameText.text = PlayerManager.nickName
end

function MainPlayerView:SetWalkDir(dir)
    if not self.curDir or self.curDir ~= dir then
        self.curDir = dir
        self.SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, dir.y, 0)
        self.SkeletonGraphic.AnimationState:SetAnimation(0, dir.animation, true)
    end
end

--通过设置z值动态设定live2d层级
function MainPlayerView:SetRolePosZ(pos)
    local v3 = self.roleRootTran.localPosition
    self.roleRootTran.localPosition = Vector3.New(v3.x, v3.y, 10 * (pos.y - self.rect.yMin) / (self.rect.yMax - self.rect.yMin))
end

-- 设置角色的位置
function MainPlayerView:SetRolePos(pos, delay, func)
    if self.tweener then
        self.tweener:Kill()
        self.lastPos = self.leader:GetComponent("RectTransform").anchoredPosition
    end
    local delay = delay or 0
    local dX = pos.x - self.lastPos.x
    local dY = pos.y - self.lastPos.y
    local dis = Vector2.Distance(pos, self.lastPos)
    local leaderTran = self.leader:GetComponent("RectTransform")
    local ov2 = leaderTran.anchoredPosition

    self.tweener = DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 0 end),
            DG.Tweening.Core.DOSetter_float(function (progress)
                local v2 = Vector2.Lerp(ov2, pos, progress)
                leaderTran.anchoredPosition = v2
                self:SetRolePosZ(v2)
            end), 1, dis / 200):SetEase(Ease.Linear):SetDelay(delay):SetEase(Ease.Linear):OnComplete(function ()
        self.lastPos = pos
        self:PlayerIdle()
        if func then
            func()
        end
    end):OnStart(function ()
        if math.abs(dX) >= math.abs(dY) then
            if dX > 0 then
                self:SetWalkDir(WALK_DIR.RIGHT)
            else
                self:SetWalkDir(WALK_DIR.LEFT)
            end
        else
            if dY > 0 then
                self:SetWalkDir(WALK_DIR.UP)
            else
                self:SetWalkDir(WALK_DIR.DOWN)
            end
        end
    end)
end

function MainPlayerView:PlayerIdle()
    self.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    self.SkeletonGraphic.transform.localEulerAngles = Vector3.zero
    self.curDir = nil
end

function MainPlayerView:Dispose()
    self:RemoveListener()
    poolManager:UnLoadLive(mapNpc, self.NpcGO)
    poolManager:UnLoadAsset(mapNpcOp, self.leader, PoolManager.AssetType.GameObject)
    self.leader = nil
    if self.tweener then
        self.tweener:Kill()
    end
end