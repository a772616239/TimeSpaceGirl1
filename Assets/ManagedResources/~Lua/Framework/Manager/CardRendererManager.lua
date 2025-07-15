CardRendererManager = {}
local this = CardRendererManager
local maxRender = 20
function CardRendererManager.Initialize()
    if this.root then
        return 
    end
    local resObj = resMgr:LoadAsset("CardRendererRoot")   
    this.root = GameObject.Instantiate(resObj)
    GameObject.DontDestroyOnLoad(this.root)
    this.renderList = {}
    this.textureList = {}
    for i = 1, 6 do
        this.renderList[i] = Util.GetGameObject(this.root, "CardRenderer"..i.."/Canvas")
        this.textureList[i] = resMgr:LoadAsset("CardTexture"..i)
    end

    this.indexFlag = 0
    this.liveList = {}
    this.usingList = {}
end


-- 获取RenderTexture对象
--- isReuse  是否可以复用已经存在的Texture
function CardRendererManager.GetSpineTexture(pos, liveName, scaleV3, posV3, isReuse, onClear)
    -- 可复用，判断之前是否存在
    -- if isReuse then
    --     local index = this.CheckIsExist(liveName)
    --     if index then
    --         return this.textureList[index], this.liveList[index].node
    --     end
    -- end
    -- flag
    this.indexFlag = pos --this.indexFlag + 1
    -- if this.indexFlag > 20 then
    --     this.indexFlag = 1
    -- end
    -- 回收老资源
    local liveData = this.liveList[this.indexFlag]
    if liveData then
        local liveName = liveData.name
        local liveNode = liveData.node
        poolManager:UnLoadLive(liveName, liveNode) 
        this.liveList[this.indexFlag] = nil
    end
    
    -- 创建新资源
    local parent = this.renderList[this.indexFlag].transform
    local liveNode = poolManager:LoadLive(liveName, parent, scaleV3, posV3 + Vector3(0, -120, 0), onClear) 
    this.liveList[this.indexFlag] = {
        name = liveName,
        node = liveNode
    }
    -- 
    return this.textureList[this.indexFlag], this.liveList[this.indexFlag].node, this.indexFlag
end

-- 判断是否存在
function this.CheckIsExist(liveName)
    for index, data in ipairs(this.liveList) do
        if data.name == liveName then
            return index
        end
    end
end


-- 检测是否正在使用
function this.CheckIsUsing(index)
    return this.usingList[index]
end
-- 设置是否正在使用
function this.SetUsing(index, isUsing)
    this.usingList[index] = isUsing
end
-- 清除使用列表
function this.ClearUsing()
    this.usingList = {}
end


function CardRendererManager.Dispose()
    GameObject.DestroyImmediate(this.root)
end
return CardRendererManager