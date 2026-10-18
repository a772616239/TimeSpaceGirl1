--- 子物体管理器（动态加载）

SubUIManager = {}
local this = SubUIManager

local function createPanel(uiConfig, parent)
    local prefab = resMgr:LoadAsset(uiConfig.assetName)
    if prefab == nil then
        LogError("未找到Prefab:" .. uiConfig.assetName)
        return nil
    end
    local gameObject = GameObject.Instantiate(prefab, Vector3.zero, Quaternion.identity, parent)
    gameObject:SetActive(true)
    gameObject.name = uiConfig.name
    local transform = gameObject.transform
    local recTransform = transform:GetComponent("RectTransform")
    recTransform.anchoredPosition3D = Vector3.New(0, 0, 0)
    recTransform.sizeDelta = Vector2.New(0, 0)
    transform.localScale = Vector3.one
    return gameObject
end

function this.Open(config,parent,...)
    local view = reimport(config.script)
    local gameObject = createPanel(config,parent)
    if gameObject then
        PlayUIAnims(gameObject)
    end
    local sub = view:New(gameObject)
    sub.assetName = config.assetName
    -- 生命周期逐个隔离：子界面的错误不能中断父界面的初始化
    -- （MainPanel 曾因 ChatTipView:OnOpen 抛错，导致 moveTranList/引导节点全部没赋值、
    --   BindEvent 在拖动缩放处中断，最终整块主界面按钮无响应）
    if sub.Awake then
        MyPCall(function() sub:Awake() end)
    end
    if sub.InitComponent then
        MyPCall(function() sub:InitComponent() end)
    end
    if sub.BindEvent then
        MyPCall(function() sub:BindEvent() end)
    end
    if sub.AddListener then
        MyPCall(function() sub:AddListener() end)
    end
    if sub.Update then
        UpdateBeat:Add(sub.Update, sub)
    end
    if sub.OnOpen then
        local openArgs = {...}
        MyPCall(function() sub:OnOpen(unpack(openArgs)) end)
    end
    return sub
end

function this.Close(sub)
    if not sub then
        LogError("需检查 sub = nil!!!!")
        return
    end

    if sub.RemoveListener then
        sub:RemoveListener()
    end
    if sub.Update ~= nil then
        UpdateBeat:Remove(sub.Update, sub)
    end
    if sub.OnClose then
        sub:OnClose()
    end
end


return this