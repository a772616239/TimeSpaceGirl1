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
    if sub.Awake then
        sub:Awake()
    end
    if sub.InitComponent then
        sub:InitComponent()
    end
    if sub.BindEvent then
        sub:BindEvent()
    end
    if sub.AddListener then
        sub:AddListener()
    end
    if sub.Update then
        UpdateBeat:Add(sub.Update, sub)
    end
    if sub.OnOpen then
        sub:OnOpen(...)
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