require("Base/BasePanel")
LoadingPanel = Inherit(BasePanel)
local this = LoadingPanel

-- 加载链单步等待上限（秒）
-- 登录链的每一步都是一次"发请求 → 等响应 → 再走下一步"的同步往返，正常 RTT 200~400ms
-- （欧洲连亚洲服实测 230~300ms），网络层自己还有 5s×3 的重发。8s 已经远超正常上限，
-- 到点就视为该步卡死。
local STEP_TIMEOUT = 8
-- 一次登录最多强制跳过几步。超过说明整条链路都不可用，此时一次性跳到末步进游戏，
-- 而不是让玩家盯着一个不动的百分比（原来没有任何超时，卡住就是永久卡住）。
local MAX_FORCE_STEPS = 6

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
    if LoadingSprite ~= nil then
        this.oriBg:SetActive(false)
        this.NewBg:SetActive(true)
        Util.GetGameObject(this.NewBg, "pic"):GetComponent("Image").sprite = LoadingSprite
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

-- 直接跳到末步进游戏（网络整体不可用时的兜底，避免无限空转）
function LoadingPanel.SkipToEnd()
    if #callList < 1 then return end
    LogError(string.format("[Loading] 连续强制跳过 %d 步，直接进入游戏，剩余步骤不再等待", forceCount))
    lerp = 0
    stepWaitTime = 0
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

    -- 关键：放弃这次挂起的请求并清空网络层队列头，否则后续步骤的请求会被堵在发送队列里发不出去
    if Network and Network.AbortPending then
        MyPCall(function() Network:AbortPending() end)
    end

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
    callList = {}
    retStrs = {}
    curIndex = 0
    maxIndex = 0
    stepWaitTime = 0
    forceCount = 0
end

return LoadingPanel
