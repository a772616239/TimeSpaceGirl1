--[[
    战斗暂停锁（纯逻辑，不依赖 Unity / Timer，可离线单测）

    为什么要有这个文件：
      战斗暂停原来是 BattleManager 里的 IsPlay 三态（0 停战 / 1 播放 / 2 暂停），
      PauseBattle / ResumeBattle 都是幂等的「置位」。全项目 15+ 个暂停源
      （回合剧情、助战/替补入场、大招特写、技能 PV、战斗位移、支援/副官/航母演出、
       宠物技、新手引导、退出确认…）共用这一个布尔位，于是必然出现两类症状：

        ① 该停的没停 —— A 暂停中，B 也暂停（被吞掉），B 先 Resume
           ⇒ 战斗在 A 的演出/遮罩底下继续跑；
        ② 该恢复的停死 —— Resume 挂在 tween / DelayFunc 的 OnComplete 上，
           单位中途被移除（阵亡、替补、战斗结束）时回调永不执行 ⇒ 永久暂停。

      现在改成「按 owner 记的引用计数锁」：
        · 同一 owner 上锁 N 次要释放 N 次（幂等配对，不会一放全放）；
        · 所有 owner 都释放，才真正把状态置回「播放」；
        · ReleaseOwner 用于「回调确定不会再执行」的路径（tween 被 Kill、单位 Dispose）。

    用法（BattleManager 已代理，业务代码照旧调 BattleManager.PauseBattle）：
        local lock = BattlePauseLock.New()
        lock:Start()                 -- 开战：0 -> 1
        lock:Pause("guide")          -- 1 -> 2
        lock:Pause("story")          -- 仍 2，两个源各持一把
        lock:Resume("story")         -- 仍 2（guide 还持着）
        lock:Resume("guide")         -- -> 1
        lock:Stop()                  -- -> 0 并清空所有锁
]]

BattlePauseLock = {}
local Lock = BattlePauseLock
local mt = { __index = Lock }

-- 状态：0 = 未开战/已停战，1 = 播放中，2 = 暂停（至少一个 owner 持锁）
local STATE_STOPPED = 0
local STATE_PLAYING = 1
local STATE_PAUSED  = 2

Lock.STATE_STOPPED = STATE_STOPPED
Lock.STATE_PLAYING = STATE_PLAYING
Lock.STATE_PAUSED  = STATE_PAUSED

local DEFAULT_OWNER = "default"

function BattlePauseLock.New()
    return setmetatable({
        state = STATE_STOPPED,
        owners = {},   -- owner -> 引用计数
        order = {},    -- 上锁顺序（只为调试输出，不影响逻辑）
    }, mt)
end

function Lock:GetState()
    return self.state
end

function Lock:IsPlaying()
    return self.state == STATE_PLAYING
end

function Lock:IsPaused()
    return self.state == STATE_PAUSED
end

function Lock:IsCanOperate()
    return self.state ~= STATE_STOPPED
end

function Lock:HasOwner(owner)
    return owner ~= nil and self.owners[owner] ~= nil
end

function Lock:GetOwnerCount(owner)
    return self.owners[owner or DEFAULT_OWNER] or 0
end

function Lock:OwnerCount()
    local n = 0
    for _ in pairs(self.owners) do
        n = n + 1
    end
    return n
end

-- 调试用："story, guide x2"
function Lock:OwnersStr()
    local parts = {}
    for _, owner in ipairs(self.order) do
        local n = self.owners[owner]
        if n then
            parts[#parts + 1] = n > 1 and string.format("%s x%d", owner, n) or owner
        end
    end
    return #parts > 0 and table.concat(parts, ", ") or "(none)"
end

function Lock:ClearOwners()
    self.owners = {}
    self.order = {}
end

-- 开战：只有从「停战」进入才生效，避免战斗中重入把暂停状态抹掉
function Lock:Start()
    if self.state == STATE_STOPPED then
        self.state = STATE_PLAYING
        return true
    end
    return false
end

-- 停战：清空所有锁，下次开战从干净状态开始
function Lock:Stop()
    self.state = STATE_STOPPED
    self:ClearOwners()
end

-- 上锁。未开战（state==0）时忽略，与旧实现一致（旧 PauseBattle 只在 IsPlay==1 时生效）
-- 返回 true 表示这把锁真的记上了
function Lock:Pause(owner)
    if self.state == STATE_STOPPED then
        return false
    end
    owner = owner or DEFAULT_OWNER
    local n = self.owners[owner] or 0
    self.owners[owner] = n + 1
    if n == 0 then
        self.order[#self.order + 1] = owner
    end
    self.state = STATE_PAUSED
    return true
end

-- 上锁，但同一 owner 只记一把（幂等）。
-- 用于「同一时刻只可能有一个实例」的源：新手引导（GuideManager/GuidePanel 共用一个逻辑状态）、
-- 结算冻结。这类源如果按计数记，引导多派发一次暂停就多一把锁，而 Resume 只来一次 ⇒ 卡死。
-- 配套：释放时用 ReleaseOwner 一次清干净，不要用 Resume 扣计数。
function Lock:PauseOnce(owner)
    if self.state == STATE_STOPPED then
        return false
    end
    owner = owner or DEFAULT_OWNER
    if self.owners[owner] then
        return false
    end
    return self:Pause(owner)
end

-- 释放一次自己的锁；别的源还持有就继续保持暂停
-- 返回 true 表示这次释放真的抵掉了一把锁
function Lock:Resume(owner)
    owner = owner or DEFAULT_OWNER
    local n = self.owners[owner]
    if n == nil then
        return false
    end
    if n <= 1 then
        self:ReleaseOwner(owner)
    else
        self.owners[owner] = n - 1
        self:_SyncState()
    end
    return true
end

-- 强制释放某个源的全部计数。
-- 用在「回调确定不会再执行」的路径：tween 被 Kill、DelayFunc 被 ClearDelayFunc、
-- 单位 Dispose —— 这些情况下配对的 Resume 永远不会来，不强制释放就是永久暂停。
function Lock:ReleaseOwner(owner)
    if not owner or self.owners[owner] == nil then
        return false
    end
    self.owners[owner] = nil
    for i = #self.order, 1, -1 do
        if self.order[i] == owner then
            table.remove(self.order, i)
        end
    end
    self:_SyncState()
    return true
end

-- 批量强制释放前缀匹配的 owner（RoleView 的每单位锁用 role:<addr>:<kind> 命名）
function Lock:ReleaseOwnerPrefix(prefix)
    if not prefix then
        return 0
    end
    local hit = {}
    for owner in pairs(self.owners) do
        if string.sub(owner, 1, #prefix) == prefix then
            hit[#hit + 1] = owner
        end
    end
    for _, owner in ipairs(hit) do
        self:ReleaseOwner(owner)
    end
    return #hit
end

function Lock:_SyncState()
    if self.state == STATE_STOPPED then
        return
    end
    local any = false
    for _ in pairs(self.owners) do
        any = true
        break
    end
    self.state = any and STATE_PAUSED or STATE_PLAYING
end

return Lock
