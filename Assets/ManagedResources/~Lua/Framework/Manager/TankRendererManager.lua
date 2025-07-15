TankRendererManager = {}
local this = TankRendererManager

function TankRendererManager.Initialize()
    if this.root then
        return 
    end
    local resObj = resMgr:LoadAsset("TankRendererRoot")   
    this.root = GameObject.Instantiate(resObj)
    GameObject.DontDestroyOnLoad(this.root)
    this.renderList = {}
    this.textureList = {}
    for i = 1, 9 do
        this.renderList[i] = Util.GetGameObject(this.root, "TankRenderer"..i.."/Canvas")
        this.textureList[i] = resMgr:LoadAsset("TankTexture"..i)
    end

    this.indexFlag = 0
    this.frameList = {}
end


-- 获取RenderTexture对象
--> deprecated
-- function TankRendererManager.GetFrameTexture(pos, frameName, scaleV3, posV3, onClear, isDown, isReset)

--     this.indexFlag = pos 

--     -- 回收老资源
--     local frameData = this.frameList[this.indexFlag]
--     if frameData then
--         poolManager:UnLoadFrame(frameData.name, frameData.node)
--         this.frameList[this.indexFlag] = nil
--     end
    
--     -- 创建新资源
--     local parent = this.renderList[this.indexFlag].transform
--     local RoleLiveGO, RoleImageAnimation, Eff_Rotation, smoke = poolManager:LoadFrameTank(frameName, parent, scaleV3, posV3, onClear, isDown, isReset)
--     this.frameList[this.indexFlag] = {
--         name = frameName,
--         node = RoleLiveGO
--     }
--     -- 
--     return this.textureList[this.indexFlag], this.frameList[this.indexFlag].node, this.indexFlag,
--     RoleImageAnimation, Eff_Rotation, smoke

-- end

function TankRendererManager.GetGoTexture(pos, goNode, scaleV3, posV3)

    this.indexFlag = pos 

    if this.renderList[this.indexFlag] then
        Util.ClearChild(this.renderList[this.indexFlag].transform)
    end

    -- 创建新资源
    local parent = this.renderList[this.indexFlag].transform
    local go = newObject(goNode)
    go:SetActive(true)
    go.transform:SetParent(parent)
    go.transform.localScale = scaleV3
    go.transform.localPosition = posV3

    this.frameList[this.indexFlag] = {
        node = go
    }
    -- 
    return this.textureList[this.indexFlag], this.frameList[this.indexFlag].node, this.indexFlag

end

function TankRendererManager.Dispose()
    GameObject.DestroyImmediate(this.root)
end
return TankRendererManager