require("Base/BasePanel")
LoadingPanel = Inherit(BasePanel)
local this = LoadingPanel

-- 加载链单步等待上限（秒）
-- 登录链的每一步都是一次"发请求 → 等响应 → 再走下一步"的同步往返，正常 RTT 200~400ms
-- （欧洲连亚洲服实测 230~300ms），网络层自己还有 5s×3 的重发。8s 已经远超正常上限，
-- 到点就视为该步卡死。
-- 注意：并行分组也算一格，所以 8s 是"整组最慢的那个"的上限，而不是组内每个成员各 8s。
local STEP_TIMEOUT = 8
-- 一次登录最多强制跳过几步。超过说明整条链路都不可用，此时一次性跳到末步进游戏，
-- 而不是让玩家盯着一个不动的百分比（原来没有任何超时，卡住就是永久卡住）。
local MAX_FORCE_STEPS = 6

-- 铭牌多语言贴片：底图九张只有中文版（资源表里没有 *_en），非中文时不能在铭牌上直接
-- 读出英文，所以改成「底图共用 + 铭牌区叠一张小贴片」。贴片由
-- scripts/image/loading_plate_overlay.py 生成，锚点是底图上的归一化矩形。
-- require 失败（老包里没有这张表）不能让整条登录链炸掉，所以 pcall 兜住降级成「只显示中文底图」。
local PlateGeom = nil
do
    local ok, ret = pcall(require, "Modules/Message/LoadingPlateGeom")
    if ok and type(ret) == "table" then
        PlateGeom = ret
    end
end

--把当前语言的铭牌贴片叠到底图对应位置。中文直接用底图原样（贴片本来就是为覆盖中文而生成的）。
local function ApplyLangPlate(picNode, pic)
    local plateNode = Util.GetGameObject(picNode, "plate")
    if plateNode == nil then return end
    plateNode:SetActive(false)

    if PlateGeom == nil or GetLan() == 0 then return end

    local key = string.format("cn2-X1_loading_0%d", pic)
    local geom = PlateGeom[key]
    if geom == nil then return end

    local sprite = Util.LoadSprite(GetPictureFont(key .. "_plate"))
    if sprite == nil then return end

    -- 用锚点而不是硬坐标：底图由 screenAdapte/aspect 拉伸，锚点跟着一起缩放才不会错位
    local rect = plateNode:GetComponent("RectTransform")
    rect.anchorMin = Vector2.New(geom.minX, geom.minY)
    rect.anchorMax = Vector2.New(geom.maxX, geom.maxY)
    rect.offsetMin = Vector2.New(0, 0)
    rect.offsetMax = Vector2.New(0, 0)
    plateNode:GetComponent("Image").sprite = sprite
    plateNode:SetActive(true)
end

--初始化组件（用于子类重写）
function LoadingPanel:InitComponent()
    this.Slider = Util.GetGameObject(self.gameObject, "Slider"):GetComponent("Slider")
    this.Tip = Util.GetGameObject(self.gameObject, "Slider/Image/LoadingText"):GetComponent("Text")
    this.tip = Util.GetGameObject(self.gameObject, "tip"):GetComponent("Text")
    this.oriBg = Util.GetGameObject(self.gameObject, "BG")
    this.NewBg = Util.GetGameObject(self.gameObject, "LoadBg")
    LoadingPanel.SetRandoBg()

    screenAdapte(Util.GetGameObject(self.gameObject, "bg1"))
    screenAdapte(Util.GetGameObject(self.gameObject, "bg2"))
end

local callList = {}
local retStrs = {}   --< 标记信息：下标 = 步骤号，值 = 步骤名（诊断/日志用）
local curIndex = 0
local lerp = 0
local maxIndex = 0
local stepWaitTime = 0   -- 当前步骤已等待时间（秒）
local forceCount = 0     -- 本次登录已强制跳过几步

-- 并行分组状态：一个分组算一格进度，组内 N 个请求同时发出，全部回包（或看门狗超时）后才推进
local groupActive = false    -- 当前正在等某个分组
local groupFiring = false    -- 正在循环发包（这期间不许收尾，否则后面的成员会发到串行队列里）
local groupRemaining = 0     -- 还没回包的成员数
local groupWaiters = 0       -- 调试用：分组里的成员数

local function update()
    lerp = math.clamp(lerp + Time.fixedDeltaTime * 15,0,1)
    this.Slider.value = this.Slider.value * (1-lerp) + curIndex * lerp
    this.Tip.text = string.format("%d",this.Slider.value/this.Slider.maxValue*100) .. "%"

    -- 看门狗：登录链只靠"回调推进"，某个响应永远不来（丢包 / 服务端未响应 / 回调里抛错）
    -- 就会永久停在一个百分比上，且没有任何提示。这里兜底强制推进。
    if curIndex > 0 and curIndex < maxIndex then
        stepWaitTime = stepWaitTime + Time.fixedDeltaTime
        if stepWaitTime > STEP_TIMEOUT then
            LoadingPanel.ForceStep("timeout")
        end
    end
end

function LoadingPanel.SetRandoBg()
    math.randomseed(os.time()) 
    local pic = math.random(1, 9)
    local loadingSprit2 = "cn2-X1_loading_0%s"
    local loadingSprit = GetPictureFont(loadingSprit2)
    -- LogError(loadingSprit)
    local loadspr = string.format(loadingSprit,pic)
    local LoadingSprite = Util.LoadSprite(loadspr)
    -- 只有中文版底图时回落 _zh：图上跟语言有关的只有铭牌两行，由 ApplyLangPlate 叠贴片覆盖，
    -- 不必为每种语言再出一张 684x2048 的大图（九张 × 语言数，包里扛不住）。
    if LoadingSprite == nil then
        LoadingSprite = Util.LoadSprite(loadspr .. "_zh")
    end
    if LoadingSprite ~= nil then
        this.oriBg:SetActive(false)
        this.NewBg:SetActive(true)
        local picNode = Util.GetGameObject(this.NewBg, "pic")
        picNode:GetComponent("Image").sprite = LoadingSprite
        ApplyLangPlate(picNode, pic)
    else
        this.NewBg:SetActive(false)
        this.oriBg:SetActive(true)
    end
    NetManager.CampSimpleInfoGetReq(function ()end)
    NetManager.CampWarInfoGetReq(function ()end)
end

function LoadingPanel.AddStep(func)
    table.insert(callList, func)
    maxIndex = #callList
end

-- 并行分组：{ groupName = "...", members = { {name=..., fire=function(cb) end}, ... } }
-- 组内请求同时发出，只等最慢的一个，把 N 个 RTT 压成 1~2 个。
function LoadingPanel.AddStepGroup(entry)
    table.insert(callList, entry)
    maxIndex = #callList
end

-- 清掉分组状态（跳过 / 超时 / 登录结束都要调，否则下一链的第一个请求会被当成并行请求）
function LoadingPanel.ResetGroup()
    if groupActive and Network and Network.EndParallelBatch then
        MyPCall(function() Network:EndParallelBatch() end)
    end
    groupActive = false
    groupFiring = false
    groupRemaining = 0
    groupWaiters = 0
end

-- 一个成员回包了（每个成员只会被计一次，重复回调由 cb 里的 finished 挡住）
function LoadingPanel.StepDone()
    if not groupActive then return end
    groupRemaining = groupRemaining - 1
    if groupRemaining > 0 then return end
    if groupFiring then return end   -- 还在发包循环里，等循环结束再收尾
    LoadingPanel.FinishGroup()
end

-- 并行请求报错：C# 侧已经把它自己的回调摘掉了，这里只当作"该成员失败"，
-- 绝不能推进整条链（否则会连环跳步，把没回来数据的步骤跳过）
function LoadingPanel.GroupMemberFailed(msg)
    if not groupActive then return end
    -- 还在发包循环里：报错不可能是组内成员的回包（回包是异步的），这是服务端推的错误码
    -- （典型是"连接中"91000834），忽略，别白扣一个成员名额。
    if groupFiring then
        LogError(string.format("[Loading] 并行分组 %s 发包期间收到错误码 %s，忽略",
            tostring(retStrs[curIndex]), tostring(msg and msg.errCode)))
        return
    end
    LogError(string.format("[Loading] 并行分组 %s 有成员报错（errCode=%s, 剩余 %d 个未回包）",
        tostring(retStrs[curIndex]), tostring(msg and msg.errCode), groupRemaining))
    LoadingPanel.StepDone()
end

function LoadingPanel.FinishGroup()
    if not groupActive then return end
    groupActive = false
    groupFiring = false
    groupRemaining = 0
    groupWaiters = 0
    if Network and Network.EndParallelBatch then
        MyPCall(function() Network:EndParallelBatch() end)
    end
    LoadingPanel.OnStep()
end

-- 执行一个并行分组：N 个请求一口气发出去，回包各自记账
function LoadingPanel.RunGroup(entry)
    local members = entry.members or {}
    groupWaiters = #members
    groupRemaining = #members
    groupActive = true
    groupFiring = true
    stepWaitTime = 0

    -- 让网络层把这一段里发出的请求（含成员回调里再发的后续请求）都走并发通道，不占串行槽位
    if Network and Network.BeginParallelBatch then
        MyPCall(function() Network:BeginParallelBatch() end)
    end

    for i = 1, #members do
        local m = members[i]
        local finished = false
        local cb = function()
            if finished then return end
            finished = true
            LoadingPanel.StepDone()
        end
        local ok, err = pcall(m.fire, cb)
        if not ok then
            -- 发包就抛错：这个成员判失败，别让整组等到超时
            LogError(string.format("[Loading] 并行成员 %s 发包异常：%s", tostring(m.name), tostring(err)))
            if not finished then
                finished = true
                groupRemaining = groupRemaining - 1
            end
        end
    end

    groupFiring = false
    -- 全部是同步回调（例如未开放的功能/本地缓存）时，这里直接收尾
    if groupActive and groupRemaining <= 0 then
        LoadingPanel.FinishGroup()
    end
end

-- 直接跳到末步进游戏（网络整体不可用时的兜底，避免无限空转）
function LoadingPanel.SkipToEnd()
    if #callList < 1 then return end
    LogError(string.format("[Loading] 连续强制跳过 %d 步，直接进入游戏，剩余步骤不再等待", forceCount))
    lerp = 0
    stepWaitTime = 0
    LoadingPanel.ResetGroup()
    curIndex = #callList - 1
    LoadingPanel.OnStep()
end

-- 强制推进当前步骤（超时 / 抛错兜底）
function LoadingPanel.ForceStep(reason)
    if not curIndex or curIndex >= maxIndex then return end
    local name = retStrs[curIndex] or ("step" .. tostring(curIndex))
    forceCount = forceCount + 1
    LogError(string.format("[Loading] 步骤 #%d(%d%%) %s 等待 %ds 未回调，强制跳过（%s，累计 %d 步）",
        curIndex, math.floor(curIndex / math.max(1, maxIndex) * 100), tostring(name),
        STEP_TIMEOUT, tostring(reason), forceCount))
    if groupActive then
        LogError(string.format("[Loading] 并行分组 %s 仍有 %d/%d 个成员未回包，放弃等待",
            tostring(name), groupRemaining, groupWaiters))
    end

    -- 关键：放弃这次挂起的请求并清空网络层队列头，否则后续步骤的请求会被堵在发送队列里发不出去
    if Network and Network.AbortPending then
        MyPCall(function() Network:AbortPending() end)
    end
    -- 分组状态必须清掉：否则下一格的请求会被当成并行请求发出去（不占串行槽位、也没人推进链）
    LoadingPanel.ResetGroup()

    if forceCount >= MAX_FORCE_STEPS then
        LoadingPanel.SkipToEnd()
        return
    end

    LoadingPanel.OnStep()
end

function LoadingPanel.OnStep()
    -- 已到最后一步：忽略重复/迟到的回调，避免越界推进（原实现会 table.insert(retStrs, nil)）
    if not curIndex or curIndex >= maxIndex then return end
    lerp = 0
    curIndex = curIndex + 1
    stepWaitTime = 0

    local func = callList[curIndex]
    if not func then
        LogError(string.format("[Loading] 步骤 #%d 缺失，加载链中断", curIndex))
        return
    end

    -- 并行分组：一格进度里发 N 个请求，等全部回包（或看门狗）才推进
    if type(func) == "table" then
        retStrs[curIndex] = func.groupName or ("group" .. tostring(curIndex))
        LoadingPanel.RunGroup(func)
        return
    end

    -- 单步抛错不能打断整条链（原来会一直停在这一步），记录后直接走下一步
    local ok, retStr = pcall(func)
    if not ok then
        LogError(string.format("[Loading] 步骤 #%d 执行异常（上一步=%s）：%s", curIndex,
            tostring(retStrs[curIndex - 1] or "start"), tostring(retStr)))
        retStrs[curIndex] = "error"
        LoadingPanel.OnStep()
        return
    end
    retStrs[curIndex] = retStr or ("step" .. tostring(curIndex))
end

-- 登录时有接口报错时执行，防止登录报错卡死导致进不去游戏的问题
function LoadingPanel.ErrorStep(msg)
    -- curIndex 只在 Start() 里才初始化：报错若发生在 LoadingPanel 打开之前（典型场景＝登录握手阶段被踢/顶号），
    -- 这里会拿 nil 去比较，抛 LuaException 打断 ReceiveErrorInfo 后续的踢号处理（Framework.Dispose + 重登），
    -- 表现就是客户端卡在 Loading 出不去。此处必须先判空。
    if not curIndex or curIndex >= maxIndex then return end

    -- 强制进入下一步
    LoadingPanel.OnStep()
end

function LoadingPanel.Start()
    if #callList <= 1 then
        return
    end
    UIManager.OpenPanel(UIName.LoadingPanel)
    UpdateBeat:Add(update)
    -- 每次登录都重置：这些原来是模块级变量，第二次登录（被顶号/掉线重登）会带着上一条链的残留值，
    -- 百分比和 maxIndex 全部对不上。
    lerp = 0
    curIndex = 0
    stepWaitTime = 0
    forceCount = 0
    retStrs = {}
    LoadingPanel.ResetGroup()
    maxIndex = #callList
    this.Slider.maxValue = #callList - 1
    this.Slider.value = curIndex
    this.Tip.text = curIndex .. "%"--GetLanguageStrById(11346)
    this.SetTip()

    LoadingPanel.OnStep()
end

function this.SetTip()
    local time = System.DateTime.Now
    local num = time.Second
    if num > 12 then
        num = math.modf(num/12)
        if num == 0 then
            num = 12
        end
    end
    this.tip.text = GetLanguageStrById(50100 + num)
end

function LoadingPanel.End()
    UpdateBeat:Remove(update)
    this:ClosePanel()
    LoadingPanel.ResetGroup()
    callList = {}
    retStrs = {}
    curIndex = 0
    maxIndex = 0
    stepWaitTime = 0
    forceCount = 0
end

return LoadingPanel
