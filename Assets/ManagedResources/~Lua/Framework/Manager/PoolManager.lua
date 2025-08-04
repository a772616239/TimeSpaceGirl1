--region *.lua
--Date
--此文件由[BabeLua]插件自动生成
PoolManager = quick_class("PoolManager")

PoolManager.AssetType = {
    MediaUI = 1,
    MediaBg = 2,
    Texture = 3,
    GameObject = 4,
    Other = 5,
}

PoolManager.AssetTypeGo = {
    GameObject = 1,
    GameObjectFrame = 2,
}

PoolManager.mClearTime_Idle = 100
PoolManager.mClearTime_Busy = 10
PoolManager.mMaxPoolSize = 60
PoolManager.enableRecycle = true

function PoolManager:ctor()
    self:init()
end

function PoolManager:Update()
    self.mFrameTimer = self.mFrameTimer + 1
    if PoolManager.enableRecycle
            and self.mFrameTimer % self.mClearTime == 0 then
        self:RemoveEarliesItem()
    end
end

function PoolManager:init()
    self.mPoolTable = {}
    self.mLiveTable = {}
    self.mSpineTable = {}
    self.mFrameTable = {}
    self.mPoolNode = GameObject("PoolNode")
    GameObject.DontDestroyOnLoad(self.mPoolNode)
    self.mPoolTrans = self.mPoolNode.transform
    self.mPoolNode:SetActive(false)
    self.mFrameTimer = 0
    --清理间隔
    self.mClearTime = PoolManager.mClearTime_Idle
    self.mPoolSize = PoolManager.mMaxPoolSize

    LateUpdateBeat:Add(self.Update,self)
end

function PoolManager:onDestroy()
    for outIndex,gameData in pairs(self.mPoolTable) do
        if gameData.resList then
            for _,data in ipairs(gameData.resList) do
                if gameData.useInstantiate then
                    GameObject.DestroyImmediate(data)
                end
            end
            gameData.resList = {}
        end
        resMgr:UnLoadAsset(outIndex)
        gameData.refCount = 0
    end
    self.mPoolTable = {}
    GameObject.DestroyImmediate(self.mPoolNode)
end

function PoolManager:SetRecycleState( state)

    PoolManager.enableRecycle = state
end

--[[
    预加载资源

]]
function PoolManager:PreLoadAsset(resName,num, assetType, func)
    local tempTable = self.mPoolTable[resName]
    if tempTable == nil then
        tempTable = {}
        tempTable.resList = {}
        tempTable.useFrame = 0
        tempTable.refCount = 0
        tempTable.useInstantiate = false
        self.mPoolTable[resName] = tempTable
    end

    resMgr:LoadAssetAsync(resName,function(name,Obj)
        if Obj ~= nil then
            local index = 1
            local resObj = nil

            if assetType == PoolManager.AssetType.GameObject then
                while  index <= num do

                    resObj = GameObject.Instantiate(Obj)
                    resObj:SetActive(true)
                    resObj.transform:SetParent(self.mPoolTrans)
                    tempTable.useInstantiate = true

                    table.insert(tempTable.resList,resObj)
                    index = index + 1
                    tempTable.refCount = tempTable.refCount + 1
                end
            else
                table.insert(tempTable.resList,Obj)
                tempTable.refCount = tempTable.refCount + 1
            end
            tempTable.activeTime = self.mFrameTimer
        end
        if func then
            func()
        end
    end)

end

function PoolManager:LoadAsset(resName, assetType)
    local tempTable = self.mPoolTable[resName]
    if tempTable == nil then
        tempTable = {}
        tempTable.resList = {}
        tempTable.preLoadCount = 0
        tempTable.usedFrame = 0
        tempTable.useInstantiate = false
        tempTable.refCount = 0
        self.mPoolTable[resName] = tempTable
    end
    
    
    
    local resObj = nil
    if #tempTable.resList > 0 then
        resObj = tempTable.resList[#tempTable.resList]
        --只有GameObject需要被回收,其他类型的资源只用缓存
        if assetType == PoolManager.AssetType.GameObject then
            table.remove(tempTable.resList,#tempTable.resList)
        end
    else
        local _obj = resMgr:LoadAsset(resName)
        if _obj == nil then
           
            resMgr:UnLoadAsset(resName)
            return nil
        end

        if assetType == PoolManager.AssetType.GameObject then
            resObj = GameObject.Instantiate(_obj)
            resObj:SetActive(true)
            tempTable.useInstantiate = true
        else
            resObj = _obj
            --缓存非GameObject资源
            table.insert(tempTable.resList,resObj)
        end

    end
    tempTable.refCount = tempTable.refCount + 1
    tempTable.activeTime = self.mFrameTimer
    return resObj
end

function PoolManager:LoadAssetAsync(resName, assetType, callBack)
    local tempTable = self.mPoolTable[resName]
    if tempTable == nil then
        tempTable = {}
        tempTable.resList = {}
        tempTable.preLoadCount = 0
        tempTable.usedFrame = 0
        tempTable.useInstantiate = false
        tempTable.refCount = 0
        self.mPoolTable[resName] = tempTable
    end

    resMgr:LoadAssetAsync(resName, function(name,Obj)
        local resObj = nil
        if Obj ~= nil then
            

            if assetType == PoolManager.AssetType.GameObject then
                resObj = GameObject.Instantiate(Obj)
                resObj:SetActive(true)
                tempTable.useInstantiate = true
            else
                resObj = Obj
                --缓存非GameObject资源
                table.insert(tempTable.resList,resObj)
            end

            tempTable.refCount = tempTable.refCount + 1
            tempTable.activeTime = self.mFrameTimer
        end
        if callBack then
            callBack(Obj, resObj)
        end
    end)
end

--[[
    resName
    res:real res Object
]]
function PoolManager:UnLoadAsset(resName,res, assetType)    
    local pool = self.mPoolTable[resName]
    if pool == nil or pool.resList == nil then
        return
    end

    --if assetType ~= PoolManager.AssetType.Texture
    --        and assetType ~= PoolManager.AssetType.MediaBg
    --        and assetType ~= PoolManager.AssetType.MediaUI
    --then
    if assetType == PoolManager.AssetType.GameObject
           and res~=nil and not IsNull(res.transform)
    then
        res.transform:SetParent(self.mPoolTrans)
        if #pool.resList <= 5 then
            table.insert(pool.resList,res)
        else
            GameObject.DestroyImmediate(res)
        end
    end
    pool.refCount = pool.refCount -1
end

function PoolManager:RemoveEarliesItem()
    local poolCount = table.nums(self.mPoolTable)
    
    
    if poolCount < self.mPoolSize then
        self.mClearTime = PoolManager.mClearTime_Idle
        return
    end
    self.mClearTime = PoolManager.mClearTime_Busy
    --logWarn("Pool Update --" .. poolCount .. " -- " .. self.mFrameTimer)

    local earliestTime = 2147483647
    local removedResName = nil
    local removedIndex = -1
    local index = 1
    local pool = nil
    for k,v in pairs(self.mPoolTable) do

        if v.refCount < 1 then
            if v.activeTime ~= nil
                    and  v.activeTime < earliestTime
            then
                earliestTime = v.activeTime
                removedResName = k
                removedIndex = index
                pool = v
            end
        end
        index = index +1
    end

    if removedResName == nil or pool == nil then
        if self.mPoolSize < PoolManager.mMaxPoolSize then
            self.mPoolSize = PoolManager.mMaxPoolSize
        end
        return
    end

    if pool.useInstantiate then
        if pool.useInstantiate
                and pool.resList ~= nil
                and table.nums( pool.resList ) > 0
        then
            for _,data in ipairs(pool.resList) do
                if data ~= nil then
                    GameObject.DestroyImmediate(data)
                end
            end
        end
        pool.resList = nil
    end
    --table.remove(self.mPoolTable)
    self.mPoolTable[removedResName] = nil
    resMgr:UnLoadAsset(removedResName)
    --logWarn("Remove Pool item:" .. removedResName)
    --logWarn("Objects in Pool!!!" .. table.nums(self.mPoolTable))


    -- local poolCount1 = table.nums(self.mPoolTable)
    
    
end

function PoolManager:ClearPool()
    self.mPoolSize = 0
    self.mClearTime = 1
end

function PoolManager:LoadLive(liveName, parent, scaleV3, posV3, onClear)
    local testLive = self:LoadAsset(liveName, PoolManager.AssetType.GameObject)
    if testLive then
        testLive.transform:SetParent(parent)
        testLive.transform.localScale = scaleV3
        testLive.transform.localPosition = posV3
        testLive.name = liveName
        testLive:SetActive(true)
        local SkeletonGraphic = testLive:GetComponent("SkeletonGraphic")
        SkeletonGraphic.color = Color.New(1,1,1,1)
    end
    if not self.mLiveTable[liveName] then
        self.mLiveTable[liveName] = {}
    end
    table.insert(self.mLiveTable[liveName], {live = testLive, call = onClear})
    return testLive
end

--设置清理回调，当live对象被回收到对象池中，触发清理回调
function PoolManager:SetLiveClearCall(resName, res, onClear)
    if self.mLiveTable[resName] then
        local item
        for i=1, #self.mLiveTable[resName] do
            item = self.mLiveTable[resName][i]
            if item.live == res then
                item.call = onClear
                break
            end
        end
    end
end

function PoolManager:UnLoadLive(resName, res)
    self:UnLoadAsset(resName, res, PoolManager.AssetType.GameObject)
    if self.mLiveTable[resName] then
        local item
        for i=1, #self.mLiveTable[resName] do
            item = self.mLiveTable[resName][i]
            if item.live == res then
                if item.call then
                    item.call()
                end
                table.remove(self.mLiveTable[resName], i)
                break
            end
        end
    end
end

---加载SkeletonAnimation脚本的Spine
function PoolManager:LoadSpine(liveName, parent, scaleV3, posV3, onClear)
    local testLive = self:LoadAsset(liveName, PoolManager.AssetType.GameObject)
    if testLive then
        testLive.transform:SetParent(parent)
        testLive.transform.localScale = scaleV3
        testLive.transform.localPosition = posV3
        testLive.name = liveName
        testLive:SetActive(true)
    end
    if not self.mSpineTable[liveName] then
        self.mSpineTable[liveName] = {}
    end
    table.insert(self.mSpineTable[liveName], {live = testLive, call = onClear})
    return testLive
end

--设置清理回调，当Spine对象被回收到对象池中，触发清理回调
function PoolManager:SetSpineClearCall(resName, res, onClear)
    if self.mSpineTable[resName] then
        local item
        for i=1, #self.mSpineTable[resName] do
            item = self.mSpineTable[resName][i]
            if item.live == res then
                item.call = onClear
                break
            end
        end
    end
end

function PoolManager:UnLoadSpine(resName, res)
    self:UnLoadAsset(resName, res, PoolManager.AssetType.GameObject)
    if self.mSpineTable[resName] then
        local item
        for i=1, #self.mSpineTable[resName] do
            item = self.mSpineTable[resName][i]
            if item.live == res then
                if item.call then
                    item.call()
                end
                table.remove(self.mSpineTable[resName], i)
                break
            end
        end
    end
end


function PoolManager:LoadFrameTank(frameName, parent, scaleV3, posV3, onClear, isDown, isReset)
    local go = self:LoadAsset(frameName, PoolManager.AssetType.GameObject)
    local turretAnimation = nil
    local Eff_Rotation = nil
    local smoke = nil
    local tank = nil
    local dead = nil
    
    if go then
        
        go.transform:SetParent(parent)
        go.transform.localScale = scaleV3
        go.transform.localPosition = posV3
        go.name = frameName
        go:SetActive(true)

        
        local size = Util.GetGameObject(go.transform, "size")

        local EmptyObj = Util.GetGameObject(size.transform, "beHit")
        if EmptyObj == nil then
            EmptyObj = newObject(resMgr:LoadAsset("EmptyObj"))
            EmptyObj.transform:SetParent(size.transform)
            EmptyObj.name = "beHit"
        end
        EmptyObj.transform.localPosition = Vector3.zero
        EmptyObj.transform.localScale = Vector3.one

        if isDown then
            local down = Util.GetGameObject(go.transform, "down")
            if not down then
                LogError("tank up or down not found!!!")
            end
            down:SetActive(true)

            
            local turret = Util.GetGameObject(down.transform, "turret")
            turret:SetActive(true)
            Util.GetGameObject(down.transform, "hall"):SetActive(true)
            turretAnimation = turret:GetComponent("ImageAnimation")
            Eff_Rotation = Util.GetGameObject(down.transform, "Eff_Rotation")
            smoke = Util.GetGameObject(down.transform, "n1_eff_tank_smoke_down")
            dead = Util.GetGameObject(down.transform, "crash")
            tank = down
            local trackRender = Util.GetGameObject(down.transform, "markRender")
            if trackRender then
                trackRender:SetActive(false)
            end
        else
            local up = Util.GetGameObject(go.transform, "up")
            if not up then
                LogError("tank up or down not found!!!")
            end
            up:SetActive(true)

            local turret = Util.GetGameObject(up.transform, "turret")
            turret:SetActive(true)
            Util.GetGameObject(up.transform, "hall"):SetActive(true)
            turretAnimation = turret:GetComponent("ImageAnimation")
            Eff_Rotation = Util.GetGameObject(up.transform, "Eff_Rotation")
            smoke = Util.GetGameObject(up.transform, "n1_eff_tank_smoke_up")
            dead = Util.GetGameObject(up.transform, "crash")
            tank = up
        end
        dead:SetActive(false)
        smoke:SetActive(false)

        if isReset then
            
        end
        
        Util.SetColor(go, Color.New(1, 1, 1, 1))
    end
    if not self.mFrameTable[frameName] then
        self.mFrameTable[frameName] = {}
    end
    table.insert(self.mFrameTable[frameName], {frame = go, call = onClear})
    return go, turretAnimation, Eff_Rotation, smoke, tank, dead
end


function PoolManager:LoadFrame(frameName, parent, scaleV3, posV3, onClear)
    local go = self:LoadAsset(frameName, PoolManager.AssetType.GameObject)
    if go then
        go.transform:SetParent(parent)
        go.transform.localScale = scaleV3
        go.transform.localPosition = posV3
        go.name = frameName
        go:SetActive(true)
    end
    if not self.mFrameTable[frameName] then
        self.mFrameTable[frameName] = {}
    end
    table.insert(self.mFrameTable[frameName], {frame = go, call = onClear})
    return go
end

function PoolManager:SetFrameClearCall(resName, res, onClear)
    if self.mFrameTable[resName] then
        local item
        for i=1, #self.mFrameTable[resName] do
            item = self.mFrameTable[resName][i]
            if item.frame == res then
                item.call = onClear
                break
            end
        end
    end
end

function PoolManager:UnLoadFrame(resName, res)
    self:UnLoadAsset(resName, res, PoolManager.AssetType.GameObject)
    if self.mFrameTable[resName] then
        local item
        for i=1, #self.mFrameTable[resName] do
            item = self.mFrameTable[resName][i]
            if item.frame == res then
                if item.call then
                    item.call()
                end
                table.remove(self.mFrameTable[resName], i)
                break
            end
        end
    end
end

--卸载对应游戏内存池的资源
--[[
    resName:  可选
]]
function PoolManager:UnLoadGameAsset(resName)
    for outIndex, gameData in pairs(self.mPoolTable) do
        local tempIndex = 1
        for index, assetData in pairs(gameData) do
            if not resName or resName == index then
                if assetData.resList then
                    for _,data in ipairs(assetData.resList) do
                        if assetData.useInstantiate then
                            GameObject.DestroyImmediate(data)
                        end
                    end
                end
                if assetData.game then
                    for i = 1, assetData.refCount do
                        resMgr:UnLoadAsset(assetData.game, index)
                    end
                end

                assetData.refCount = 0
                assetData.resList = {}
                --                    deleteTable[#deleteTable + 1] = tempIndex
            end
            tempIndex = tempIndex + 1
        end
    end

end


--endregion
