PlayerLiveView = {}
local this=PlayerLiveView
--立绘对象
local rideLive
local playerLive
local titleLive
--立绘资源名字
local rideLiveStr = ""
local playerLiveStr = ""
local titleLiveStr = ""
--立绘动画控制
local rideLivSkeletonGraphic
local playerLiveSkeletonGraphic
local titleLiveSkeletonGraphic
-- 设置角色行走方向
local WALK_DIR = {
    RIGHT = {animation = "move2", y = 0},
    LEFT = {animation = "move2", y = 180},
    UP = {animation = "move3", y = 0},
    DOWN = {animation = "move", y = 0},
}
function PlayerLiveView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = PlayerLiveView })
    return b
end
--初始化组件（用于子类重写）
function PlayerLiveView:InitComponent()

    self.liveParent = Util.GetGameObject(self.gameObject, "liveParent")
    self.rideLive = Util.GetGameObject(self.gameObject, "liveParent/rideLive")
    self.playerLive = Util.GetGameObject(self.gameObject, "liveParent/playerLive")
    self.titleLive = Util.GetGameObject(self.gameObject, "liveParent/titleLive")
end

--绑定事件（用于子类重写）
function PlayerLiveView:BindEvent()

end

--添加事件监听（用于子类重写）
function PlayerLiveView:AddListener()

end

--移除事件监听（用于子类重写）
function PlayerLiveView:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PlayerLiveView:OnOpen()
    self:OnShowLive()
end

--加载三个立绘（称号 坐骑 皮肤）
function PlayerLiveView:OnShowLive()

    self.rideLive:SetActive(false)
    self.playerLive:SetActive(false)
    self.titleLive:SetActive(false)
    --PlayerManager.ride = 0--80301
    --PlayerManager.decrotion = 80201
    --PlayerManager.designation = 0--80101
    if rideLive then
        poolManager:UnLoadLive(rideLiveStr, rideLive, PoolManager.AssetType.GameObject)
        rideLive = nil
    end
    if playerLive then
        poolManager:UnLoadLive(playerLiveStr, playerLive, PoolManager.AssetType.GameObject)
        playerLive = nil
    end
    if titleLive then
        poolManager:UnLoadLive(titleLiveStr, titleLive, PoolManager.AssetType.GameObject)
        titleLive = nil
    end
    if PlayerManager.ride and PlayerManager.ride > 0 then
        self.rideLive:SetActive(true)
        rideLiveStr = GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,PlayerManager.ride).Live)
        rideLive = poolManager:LoadLive(rideLiveStr, self.rideLive.transform, Vector3.one, Vector3.zero)
        rideLivSkeletonGraphic = rideLive:GetComponent("SkeletonGraphic")
        if rideLivSkeletonGraphic then
            --rideLivSkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        end
    end
    if PlayerManager.skin and PlayerManager.skin > 0 then
        self.playerLive:SetActive(true)
        playerLiveStr = "live2d_npc_map"--GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,PlayerManager.decrotion).Live)
        playerLive = poolManager:LoadLive(playerLiveStr, self.playerLive.transform, Vector3.one, Vector3.zero)
        playerLiveSkeletonGraphic = playerLive:GetComponent("SkeletonGraphic")
        if playerLiveSkeletonGraphic then
            playerLiveSkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        end
    end
    if PlayerManager.designation and PlayerManager.designation > 0 then
        self.titleLive:SetActive(true)
        titleLiveStr = GetResourcePath(ConfigManager.GetConfigData(ConfigName.PlayerAppearance,PlayerManager.designation).Live)
        titleLive = poolManager:LoadLive(titleLiveStr, self.titleLive.transform, Vector3.one, Vector3.zero)
        titleLiveSkeletonGraphic = titleLive:GetComponent("SkeletonGraphic")
        if titleLiveSkeletonGraphic then
            --titleLiveSkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        end
    end
end

--设置位置
function PlayerLiveView:SelectRenPos(ChapterRolePosition,localScaleVer,_parent)
    if self.liveParent then
        self.liveParent:SetActive(true)
        if _parent then
            self.liveParent.transform:SetParent(_parent.transform)
        end
        self.liveParent.transform.localScale = Vector3.New(localScaleVer[1],localScaleVer[2],1)
        self.liveParent:GetComponent("RectTransform").anchoredPosition3D = Vector3.New(ChapterRolePosition[1], ChapterRolePosition[2], 10)
    end
end

-- 走动 传  起始位置 和 目标位置
function PlayerLiveView:SetRoleWalk(_pos,_tagerPos,_fun)
    local pos = _pos
    local targetPos = _tagerPos
    local speed = 5 -- 越大越慢  到时候 会读表
    self.liveParent.transform:DOLocalMove(targetPos, speed / 5, false):OnStart(function ()
        PlayerLiveView:SetRoleDirAction(targetPos.x, targetPos.y, pos.x, pos.y)
    end):OnUpdate(function() --TODO:测试速度

    end):OnComplete(function ()

        if rideLive then
            rideLivSkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        else
            playerLiveSkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        end
        if _fun then
            _fun()
            _fun = nil
        end
    end):SetEase(Ease.Linear)
end

function PlayerLiveView:SetRoleDirAction(targetU, targetV, u0, v0)
    local dU =  targetU - u0
    local dV =  targetV - v0
    if dU > 0 then
        PlayerLiveView:SetWalkDir(WALK_DIR.RIGHT)
    elseif dU < 0 then
        PlayerLiveView:SetWalkDir(WALK_DIR.LEFT)
    elseif dV < 0 then
        PlayerLiveView:SetWalkDir(WALK_DIR.UP)
    elseif dV > 0 then
        PlayerLiveView:SetWalkDir(WALK_DIR.DOWN)
    end
end

function PlayerLiveView:SetWalkDir(dir)
    if rideLive then
        rideLivSkeletonGraphic.transform.localEulerAngles = Vector3.New(0, dir.y, 0)
        rideLivSkeletonGraphic.AnimationState:SetAnimation(0, dir.animation, true)
    else
        playerLiveSkeletonGraphic.transform.localEulerAngles = Vector3.New(0, dir.y, 0)
        playerLiveSkeletonGraphic.AnimationState:SetAnimation(0, dir.animation, true)
    end
end
--界面销毁时调用（用于子类重写）
function PlayerLiveView:OnClose()

    if rideLive then
        poolManager:UnLoadLive(rideLiveStr, rideLive, PoolManager.AssetType.GameObject)
        rideLive = nil
    end
    if playerLive then
        poolManager:UnLoadLive(playerLiveStr, playerLive, PoolManager.AssetType.GameObject)
        playerLive = nil
    end
    if titleLive then
        poolManager:UnLoadLive(titleLiveStr, titleLive, PoolManager.AssetType.GameObject)
        titleLive = nil
    end
end

return PlayerLiveView