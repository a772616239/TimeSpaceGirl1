require("Modules/Map/Logic/TileMapData")

local MapConst = {
    tileWidth = 256,
    tileHeight = 256,
    bgWidth = 1024,
    bgHeight = 1024,
    boxEffect = "UI_effect_TanSuo_BianKuang",
    choosedMask = "r_map_bushu_001",
    darkMask = "r_map_newMask",
}

TileMapView = {}
local this = TileMapView
-- 是否显示迷雾
this.isShowFog = false

this.PIXELS_PER_UNIT = 100 --设置sprite的pixelsPerUnit值

this.IndexU = 0
this.IndexV = 0
this.fogSize = 0

this.ViewCameraTran = nil
this.ViewCameraPos = Vector3.zero
this.OnInit = nil --初始化完成后的回调

local transform

local ViewCamera

local _mapData

local _mapScale = 1
local _minScale
local _fogSpritesCache
local _fogMasksCache
local _fogMasks2Cache

local _uBuff
local _vBuff
local _uScale
local _vScale
local _defaultTileSize = Vector2.New(MapConst.tileWidth, MapConst.tileHeight)
local _defaultBGSize = Vector2.New(MapConst.bgWidth / this.PIXELS_PER_UNIT, MapConst.bgHeight / this.PIXELS_PER_UNIT)
local _tileSize

local _tileLivePool
local _tileClearPool

local _tileUMaxNum
local _tileVMaxNum

local EffectGroup
local _bgEffect
local EffectGroup2
local uiRoot

local _tilesGroup
local _tileBGsGroup
local _bg

local IsAwaked
local IsInit

local _screenWidth = Screen.width
local _screenHeight = Screen.height

local _offsetAngle = 0 --偏移角度 取值范围(-45f,45f）
local _offsetAngleValue = math.cos(math.rad(_offsetAngle))
local _offsetScale --计算地块缓存个数的参数

local _fogOffset
local _bgW
local _bgH
local _mapConfig = ConfigManager.GetConfig(ConfigName.ChallengeMapConfig)
local _mapId
local _spriteBG

local _lastViewCameraPos

local lastU, lastV

function this.AwakeInit(go, mapId, wakeCells, tileV2)
    transform = go.transform
    _mapId = mapId
    wakeCells = wakeCells or {}
    _defaultTileSize = tileV2 or Vector2.New(MapConst.tileWidth, MapConst.tileHeight)

    IsInit = false
    IsAwaked = false

    this.ViewCameraTran = transform:Find("CameraPos#")
    local vcrt = this.ViewCameraTran:Find("Camera")
    if vcrt then
        ViewCamera = vcrt:GetComponent("Camera")
    end
    _spriteBG = transform:Find("BG#/spriteBG"):GetComponent(typeof(UnityEngine.SpriteRenderer))

    ViewCamera.orthographic = true

    this.SetCameraPos(Vector3.New(this.ViewCameraTran.localPosition.x, this.ViewCameraTran.localPosition.y, -50))
    _tileLivePool = {}
    _tileClearPool = {}

    IsAwaked = true

    local x = _screenWidth / _screenHeight
    local n
    if x >= 1 then
        n = math.sin(math.rad(_offsetAngle)) * x + math.cos(math.rad(_offsetAngle))
    else
        n = math.sin(math.rad(_offsetAngle)) / x + math.cos(math.rad(_offsetAngle))
    end
    _offsetScale = n * n * _offsetAngleValue

    this.RefreshBuffSize()

    --加载地图图块数据
    
    if not _mapConfig[_mapId] then
        LogError("表里面没有地图id:".._mapId)
        _mapId = 4001
    end
    local maxU, maxV = _mapConfig[_mapId].Size[1], _mapConfig[_mapId].Size[2]
    _mapData = TileMapData.New(maxU, maxV)

    _tileUMaxNum = _mapData.uLen
    _tileVMaxNum = _mapData.vLen

    local u, v
    for i=1, #wakeCells do
        u, v = Map_Pos2UV(wakeCells[i])
        _mapData:UpdateFogArea(u, v, this.fogSize)
    end

    for j=1, _mapData.vLen do
        for i=1, _mapData.uLen do
            _mapData:GetMapData(i, j).nearVal = 1
        end
    end
    _tileSize = Vector2.New(_defaultTileSize.x / this.PIXELS_PER_UNIT, _defaultTileSize.y / this.PIXELS_PER_UNIT)
end

function this.SetSpriteBG(sprite)
    _spriteBG.sprite = Util.LoadSprite(sprite)
end

function this.Exit()
    _fogSpritesCache = nil
    _tileLivePool = nil
    _tileClearPool = nil
    ViewCamera = nil
    _bg = nil
    _tilesGroup = nil
    _tileBGsGroup = nil
    if _spriteBG then
        _spriteBG.sprite = nil
        _spriteBG = nil
    end
end

function this.GetMapData()
    return _mapData
end

function this.GetMapScale()
    return _mapScale
end

function this.GetMapMinScale()
    return _minScale
end

function this.GetUIPos(v3)
    return ViewCamera:WorldToScreenPoint(v3) - Vector3.New(_screenWidth/2,_screenHeight/2,0)
end

function this.SetMapScale(val)
    if ViewCamera then
        _mapScale = val
        ViewCamera.orthographicSize = _screenHeight / this.PIXELS_PER_UNIT / 2 / _mapScale
        this.RefreshBuffSize()
    end
end

function this.RefreshBuffSize()
    _uScale = _screenWidth / _defaultTileSize.x / _mapScale / 2 * _offsetScale
    _vScale = _screenHeight / _defaultTileSize.y / _mapScale / 2 * _offsetScale
    _uBuff = math.ceil(_uScale)
    _vBuff = math.ceil(_vScale)
    this.UpdateBaseData()
end

function this.SetCameraPos(v3)
    this.ViewCameraPos = v3
    Util.SetLocalPosition(this.ViewCameraTran, v3.x, v3.y, v3.z)
end

function this.GetCamera()
    return ViewCamera
end

function this.CameraMove(deltaPos)
    if ViewCamera then
        this.SetCameraPos(this.ViewCameraPos + ViewCamera:ScreenToWorldPoint(Vector3.New(_screenWidth / 2 - deltaPos.x, _screenHeight / 2 - deltaPos.y, 0))
                - ViewCamera.transform.position)
    end
end

function this.CameraTween(u, v, duration, onEnd)
    if ViewCamera then
        local v3 = this.GetLiveTilePos(u, v)
        v3.z = this.ViewCameraPos.z
        local tmpV3 = this.ViewCameraPos
        local isEnd = false
        DoTween.To(DG.Tweening.Core.DOGetter_UnityEngine_Vector3( function () return this.ViewCameraPos end),
                DG.Tweening.Core.DOSetter_UnityEngine_Vector3(function (v3)
                    if isEnd then return end
                    this.SetCameraPos(v3)
                    this.UpdateBaseData()
                    if tmpV3 ~= this.ViewCameraPos then
                        tmpV3 = this.ViewCameraPos
                    else --当镜头没有动时，立刻结束并返回回调
                        isEnd = true
                        if onEnd then onEnd() end
                    end
                end), v3, duration):SetEase(Ease.Linear):OnComplete(function ()
            if not isEnd then
                if onEnd then onEnd() end
            end
        end )
    end
end

function this.CameraScale(screenPoint, scale)
    if ViewCamera and _mapScale ~= scale then
        this.SetMapScale(math.clamp(scale, _minScale, 2))
        local mousePos = ViewCamera:ScreenToWorldPoint(Vector3.New(screenPoint.x, screenPoint.y, 0))
        local mousePos2 = ViewCamera:ScreenToWorldPoint(Vector3.New(screenPoint.x, screenPoint.y, 0))
        this.SetCameraPos(this.ViewCameraPos - (mousePos2 - mousePos))
    end
end

function this.IsOutArea(u, v)
    return u < 1 or v < 1 or u > _tileUMaxNum or v > _tileVMaxNum
end

function this.GetLiveTileInScreenPos(insPos)
    if ViewCamera then
        local logicPos = this.MapPos2ScreenPos(ViewCamera:ScreenToWorldPoint(insPos) - transform.position)
        local arr = { math.round(logicPos.x), -math.round(logicPos.y) }
        return arr, logicPos
    end
    return nil
end

function this.GetLiveTile(u, v)
    local key = Map_UV2Pos(u, v)
    if _tileLivePool[key] then
        return _tileLivePool[key].tileGo
    end
    return nil
end

function this.GetLiveTilePos(u, v)
    return this.DrawTilePos(u, v)
end

function this.GetTileData(u, v)
    if this.IsOutArea(u, v) then
        return nil
    end
    return _mapData:GetMapData(u, v)
end

function this.UpdateWarFog(u, v, fogSize)
    _mapData:UpdateFogArea(u, v, fogSize)
    for j = math.max(1, this.IndexV - _vBuff), math.min(this.IndexV + _vBuff, _tileVMaxNum) do
        for i = math.max(1, this.IndexU - _uBuff), math.min(this.IndexU + _uBuff, _tileUMaxNum) do
            if this.CheckDraw(u, v) and _tileLivePool[Map_UV2Pos(i, j)] then
                local tileGoList = _tileLivePool[Map_UV2Pos(i, j)]
                local data = this.GetTileData(i, j)

                if math.abs(i-u) + math.abs(j-v) <= fogSize then
                    data.nearVal = 0
                else
                    data.nearVal = 1
                end

                if data.isOpen and not tileGoList.isOpen then
                    local pos = Map_UV2Pos(i, j)
                    local delayTime = 0
                    if lastU == u then
                        delayTime = math.abs(i-u) * 0.1
                    else
                        delayTime = math.abs(j-v) * 0.1
                    end

                    Timer.New(function ()
                        if not _tileLivePool or not _tileLivePool[pos] then
                            return
                        end
                        if this.isShowFog then
                            local go = poolManager:LoadAsset(MapConst.boxEffect, PoolManager.AssetType.GameObject)
                            local transform = go.transform
                            transform:SetParent(_bg)
                            transform.position = tileGoList.tileGoTran.position
                            transform.localScale = Vector3.New(_defaultTileSize.x / MapConst.tileWidth, _defaultTileSize.y / MapConst.tileHeight, 1)

                            Timer.New(function ()
                                if not _tileLivePool or not _tileLivePool[pos] then
                                    return
                                end
                                if _tileLivePool[pos] then
                                    local u, v = Map_Pos2UV(pos)
                                    this.DrawTileBG(_tileLivePool[pos], this.GetTileData(u, v))
                                end
                                poolManager:UnLoadAsset(MapConst.boxEffect, go, PoolManager.AssetType.GameObject)
                            end, 0.3):Start()
                        end
                    end, delayTime):Start()

                    -- 不显示迷雾直接刷新
                    if not this.isShowFog then
                        if _tileLivePool[pos] then
                            local u, v = Map_Pos2UV(pos)
                            this.DrawTileBG(_tileLivePool[pos], this.GetTileData(u, v))
                        end
                    end
                else
                    this.DrawTileBG(tileGoList, data)
                end
            end
        end
    end
    lastU, lastV = u, v
end

local pathCache = {}
function this.ShowPath(u, v, targetU, targetV, funcCanPass)
    this.ClearPath()
    if this.IsOutArea(targetU, targetV) then return end
    local list = _mapData:FindPath(_mapData:GetMapData(u, v), _mapData:GetMapData(targetU, targetV), funcCanPass)
    if list == nil or #list <= 1 then
        return nil
    end
    local data
    for i=1, #list do
        list[i].val = 1
        local pos = Map_UV2Pos(list[i].u, list[i].v)
        table.insert(pathCache, pos)
        data = _tileLivePool[pos]
        if data then
            this.DrawTileSprite(data, list[i])
        end
    end
    return list
end

function this.ClearPathTile(u, v)
    local data
    for i=1, #pathCache do
        if pathCache[i] == Map_UV2Pos(u, v) then
            data = this.GetTileData(u, v)
            data.val = 0
            if _tileLivePool[pathCache[i]] then
                this.DrawTileSprite(_tileLivePool[pathCache[i]], data)
            end
            table.remove(pathCache, i)
            break
        end
    end
end

function this.ClearPath()
    local data
    local u, v
    for i=1, #pathCache do
        u, v = Map_Pos2UV(pathCache[i])
        data = this.GetTileData(u, v)
        data.val = 0
        if _tileLivePool and _tileLivePool[pathCache[i]] then
            this.DrawTileSprite(_tileLivePool[pathCache[i]], data)
        end
    end
    pathCache = {}
end

function this.CreateNewTileGO()
    local tileGoList = {}
    local tileGo = GameObject("tileItem#")
    tileGo.transform:SetParent(_tilesGroup, false)
    tileGo.transform.localPosition = Vector3.New(0,0,-5)
    tileGo.transform.localScale = Vector3.New(_defaultTileSize.x / MapConst.tileWidth, _defaultTileSize.y / MapConst.tileHeight, 1)

    --local tile = GameObject("tile#")
    local tileSR = tileGo:AddComponent(typeof(UnityEngine.SpriteRenderer))
    --tile.transform:SetParent(tileGo.transform, false)
    --tile.transform.localPosition = Vector3.New(0,0,-5)
    --tile.transform.localScale = Vector3.one


    local tilebg = GameObject("tilebg#")
    local tilebgSR = tilebg:AddComponent(typeof(UnityEngine.SpriteRenderer))
    tilebg.transform:SetParent(_tileBGsGroup, false)
    tilebg.transform.localPosition = Vector3.New(0,0,-2)
    tilebg.transform.localScale = Vector3.one
    --tilebg:SetActive(false)

    --local tilebgTmp = GameObject("tilebgTmp#")
    --local tilebgTmpSR = tilebgTmp:AddComponent(typeof(UnityEngine.SpriteRenderer))
    --tilebgTmp.transform:SetParent(tileGo.transform, false)
    --tilebgTmp.transform.localPosition = Vector3.New(0,0,-1)
    --tilebgTmp.transform.localScale = Vector3.one

    tileGoList.tileGo = tileGo
    tileGoList.tileGoTran = tileGo.transform

    tileGoList.tileSR = tileSR
    tileGoList.tileSRTran = tilebg.transform
    tileGoList.tilebgSR = tilebgSR
    --tileGoList.tilebgTmpSR = tilebgTmpSR

    return tileGoList
end

function this.Draw(u, v, data)
    local tileGoList
    local uv = Map_UV2Pos(u, v)
    if #_tileClearPool > 0 then
        for k, v in pairs(_tileClearPool) do
            if v.tileUV == uv then
                tileGoList = v
                table.remove(_tileClearPool, k)
                break
            end
        end
        if not tileGoList then
            if not _tileClearPool[1] then
                tileGoList = this.CreateNewTileGO()
            else
                tileGoList = _tileClearPool[1]
                table.remove(_tileClearPool,1)
            end
        end
    else
        tileGoList = this.CreateNewTileGO()
    end

    if tileGoList.tileUV ~= uv then
        tileGoList.tileUV = uv
        tileGoList.tileU = u
        tileGoList.tileV = v

        local v3 = this.DrawTilePos(u, v)
        Util.SetLocalPosition(tileGoList.tileGoTran, v3.x, v3.y, v3.z)
        Util.SetLocalPosition(tileGoList.tileSRTran, v3.x, v3.y, v3.z)
    end
    _tileLivePool[uv] = tileGoList
    this.DrawTileBG(tileGoList, data)
    this.DrawTileSprite(tileGoList, data)
end

--矩形排列算法（以左上角为原点建立u，v坐标）
function this.DrawTilePos(u, v)
    return Quaternion.Euler(0,0, _offsetAngle) * Vector3.New(u * _tileSize.x, v * -_tileSize.y, 0) * _offsetAngleValue
end

function this.DrawBGPos(u, v)
    return Quaternion.Euler(0,0, _offsetAngle) * Vector3.New(u * _defaultBGSize.x, v * -_defaultBGSize.y, 0) * _offsetAngleValue
end

function this.DrawTileSprite(tileGoList, data)
    if not data then return false end
    if tileGoList.tileSpriteType ~= data.val then
        tileGoList.tileSpriteType = data.val
        tileGoList.tileSR.sprite = data.val == 1 and Util.LoadSprite(MapConst.choosedMask) or nil
    end
end

local function uvMask(u, v)
    u = u % 2 == 0 and 2 or u % 2
    v = v % 3 == 0 and 3 or v % 3
    return u + (v-1) * 2
end

function this.DrawTileBG(tileGoList, data)
    if not data then return end
    if this.isShowFog then
        tileGoList.tilebgSR.sprite = _fogSpritesCache[uvMask(tileGoList.tileU, tileGoList.tileV)]
    end

    if data.isOpen then
        local n = 0
        local checkNear = function(u, v, add)
            if this.IsOutArea(u, v) then return end
            if not _mapData:GetMapData(u, v).isOpen then
                n = n + add
            end
        end
        checkNear(tileGoList.tileU, tileGoList.tileV+1, 4)
        checkNear(tileGoList.tileU+1, tileGoList.tileV, 2)
        checkNear(tileGoList.tileU, tileGoList.tileV-1, 1)
        checkNear(tileGoList.tileU-1, tileGoList.tileV, 8)
        if this.isShowFog then
            tileGoList.tilebgSR.sprite = _fogMasksCache[n]
            if n == 0 then
                checkNear(tileGoList.tileU-1, tileGoList.tileV+1, 1)
                checkNear(tileGoList.tileU+1, tileGoList.tileV+1, 2)
                checkNear(tileGoList.tileU-1, tileGoList.tileV-1, 8)
                checkNear(tileGoList.tileU+1, tileGoList.tileV-1, 4)

                tileGoList.tilebgSR.sprite = _fogMasks2Cache[n]
            end
        end
    end
    tileGoList.isOpen = data.isOpen
    --tileGoList.tilebgTmpSR.sprite = data.nearVal == 1 and Util.LoadSprite(MapConst.darkMask) or nil
end

function this.Init()
    if not IsAwaked then return end
    --没有载入Info
    if _defaultTileSize == Vector2.zero then return end

    if not _fogSpritesCache then
        _fogMasksCache = {}
        _fogMasks2Cache = {}
        _fogSpritesCache = {}

        for i = 1, 256 do
            _fogSpritesCache[i] = Util.LoadSprite("N1_img_yuanzheng_miwu"..i)
        end

        for i = 1, 15 do
            --_fogMasksCache[i] = Util.LoadSprite("shadow_"..i)
        end
        for i = 1, 15 do
            --_fogMasks2Cache[i] = Util.LoadSprite("shadow_angle_"..i)
        end

    end

    --加载背景图
    if not _bg then
        _bg = transform:Find("BG#")
        _bg:SetParent(transform, false)

        _bgW = _mapConfig[_mapId].TileSize[1] / this.PIXELS_PER_UNIT / 2
        _bgH = _mapConfig[_mapId].TileSize[2] / this.PIXELS_PER_UNIT / 2

        local offsetX = math.ceil((_mapConfig[_mapId].TileSize[1]-_mapData.uLen*_defaultTileSize.x)/_defaultTileSize.x/2)
        local offsetY = math.ceil((_mapConfig[_mapId].TileSize[2]-_mapData.vLen*_defaultTileSize.y)/_defaultTileSize.y/2)
       
       
        _fogOffset = Vector2.New(offsetX, offsetY)

        _minScale = math.max(_screenHeight, _screenWidth) / math.min(_mapConfig[_mapId].TileSize[1], _mapConfig[_mapId].TileSize[2])
        this.SetMapScale(math.max(1080/1280, _minScale))

        local count = 0
        local childCount = _bg.childCount

        for i=1, childCount-1 do
            local go = _bg:GetChild(i)
            local sr = go.gameObject:GetComponent(typeof(UnityEngine.SpriteRenderer))
            if not sr then
                sr = go.gameObject:AddComponent(typeof(UnityEngine.SpriteRenderer))
            end
            sr.sprite = nil
        end
        for j=1, _mapConfig[_mapId].BGSize[2] do
            for i=1, _mapConfig[_mapId].BGSize[1] do
                count = count + 1
                local go = _bg:Find(string.format("BGItem#%d_%d",i, j))
                if not go then
                    go = GameObject(string.format("BGItem#%d_%d",i, j)).transform
                    go:SetParent(_bg, false)
                    go.localScale = Vector3.one
                end
                go.localPosition = this.DrawBGPos(i, j) + Vector3.New(-_bgW - _defaultBGSize.x / 2, _bgH + _defaultBGSize.y / 2, 0)
                local sr = go.gameObject:GetComponent(typeof(UnityEngine.SpriteRenderer))
                if not sr then
                    sr = go.gameObject:AddComponent(typeof(UnityEngine.SpriteRenderer))
                end
                sr.sprite = Util.LoadSprite(_mapConfig[_mapId].BGPath.."_"..count)
            end
        end


        local v2 = this.ScreenPos2MapPos(Vector2.New(_tileUMaxNum / 2 + 0.5, _tileVMaxNum / 2 + 0.5))
        local offsetX = _mapConfig[_mapId].Offset[1]
        local offsetY = _mapConfig[_mapId].Offset[2]
        --local offsetX = 0
        --local offsetY = 0
        _bg.localPosition = Vector3.New(v2.x + offsetX / this.PIXELS_PER_UNIT, v2.y + offsetY / this.PIXELS_PER_UNIT, 1)
        _bg.localScale = Vector3.one
    end

    ViewCamera.orthographicSize = _screenHeight / this.PIXELS_PER_UNIT / 2 / _mapScale

    if not IsInit then
        if _mapData then
            this.DrawTiles()
            IsInit = true
            this.OnInitComplete()
        end
    end

    this.UpdateBaseData()
end


function this.UpdateFunc()
    --防止运行时，rotation被更改
    transform.rotation = Quaternion.identity

    if IsInit then
        this.ClearTiles()
        this.DrawTiles()
    end
end

function this.IsUpdatePos()
    return _lastViewCameraPos ~= this.ViewCameraPos
end

function this.UpdateBaseData()
    if IsInit then
        --计算相机位置  边界检查
        this.BoundsCheck()
        if _lastViewCameraPos == this.ViewCameraPos then return end
        _lastViewCameraPos = this.ViewCameraPos
        --计算index
        local logicPos = this.MapPos2ScreenPos(Vector2.New(this.ViewCameraPos.x, this.ViewCameraPos.y))
        local lastIndexU = this.IndexU
        local lastIndexV = this.IndexV

        --边界显示检查
        this.IndexU = math.clamp(math.round(logicPos.x), 1, _tileUMaxNum)
        this.IndexV = math.clamp(-math.round(logicPos.y), 1, _tileVMaxNum)

        if lastIndexU and lastIndexV then
            if lastIndexU ~= this.IndexU or lastIndexV ~= this.IndexV then
                this.UpdateFunc()
            end
        end
    end
end

function this.ClearTiles()
    local u, v
    for k, go in pairs(_tileLivePool) do
        u, v = Map_Pos2UV(k)
        if go then
            if not this.CheckDraw(u, v) or u < this.IndexU - _uBuff or u > this.IndexU + _uBuff or v < this.IndexV - _vBuff or v > this.IndexV + _vBuff then
                _tileLivePool[k] = nil
                table.insert(_tileClearPool, go)
            end
        end
    end
end

function this.DrawTiles()
    if not _tilesGroup then
        _tilesGroup = transform:Find("tilesGroup#")
        _tileBGsGroup = transform:Find("tileBGsGroup#")
        EffectGroup = transform:Find("effectGroup#")
        _bgEffect = EffectGroup:Find("effect")
        _bgEffect.localPosition = Vector3.New(_tileSize.x * _tileUMaxNum / 2, -_tileSize.y * _tileVMaxNum / 2, 0)
        EffectGroup2 = transform:Find("effectGroup2#")
        uiRoot = transform:Find("uiObj#")
        uiRoot.gameObject:GetComponent("Canvas").worldCamera = ViewCamera
        uiRoot.gameObject:GetComponent("RectTransform").sizeDelta = Vector2.New(_mapConfig[_mapId].TileSize[1], _mapConfig[_mapId].TileSize[2])
        --uiRoot.transform.localPosition = _bg.localPosition

        while _tilesGroup.childCount > 0 do
            GameObject.DestroyImmediate(_tilesGroup:GetChild(0).gameObject)
        end

        while _tileBGsGroup.childCount > 0 do
            GameObject.DestroyImmediate(_tileBGsGroup:GetChild(0).gameObject)
        end
    end
    
    for v = math.max(1, this.IndexV - _vBuff), math.min(this.IndexV + _vBuff, _tileVMaxNum) do
        for u = math.max(1, this.IndexU - _uBuff), math.min(this.IndexU + _uBuff, _tileUMaxNum) do
            if this.CheckDraw(u, v) and not _tileLivePool[Map_UV2Pos(u, v)] then
                this.Draw(u, v, this.GetTileData(u, v))
            end
        end
    end
end

function this.CheckDraw(u, v)
    if _offsetAngle == 0 then return true end

    local v3 = this.ScreenPos2MapPos(Vector2.New(u, v))
    local v32 = this.ScreenPos2MapPos(Vector2.New(this.IndexU, this.IndexV))

    local checkWidth = (_screenWidth / this.PIXELS_PER_UNIT / _mapScale + _tileSize.x * 2) / 2
    local checkHeight = (_screenHeight / this.PIXELS_PER_UNIT / _mapScale + _tileSize.y * 2) / 2

    return math.abs(v3.x - v32.x) < checkWidth  and math.abs(v3.y - v32.y) < checkHeight
end

function this.BoundsCheck()
    local v3 = this.ViewCameraPos
    v3.x = math.clamp(v3.x, _bg.localPosition.x - _bgW + _uScale * _tileSize.x,
            _bg.localPosition.x + _bgW - _uScale * _tileSize.x)
    v3.y = math.clamp(v3.y, _bg.localPosition.y - _bgH + _vScale * _tileSize.y,
            _bg.localPosition.y + _bgH - _vScale * _tileSize.y)
    this.SetCameraPos(v3)
end

function this.IsOutBounds(v3)
    return v3.x < _bg.localPosition.x - _bgW + _uScale *  _tileSize.x or
            v3.x > _bg.localPosition.x + _bgW - _uScale *  _tileSize.x or
            v3.y < _bg.localPosition.y - _bgH + _vScale *  _tileSize.y or
            v3.y > _bg.localPosition.y + _bgH - _vScale *  _tileSize.y
end

function this.MapPos2ScreenPos(v2)
    local v3 = Quaternion.Euler(0,0, _offsetAngle) * Vector3.New(v2.x, v2.y, 0)
    return Vector2.New(v3.x / _tileSize.x, v3.y / _tileSize.y) / _offsetAngleValue
end

function this.ScreenPos2MapPos(v2)
    local v3 = Quaternion.Euler(0,0, _offsetAngle) * Vector3.New(v2.x * _tileSize.x, v2.y * -_tileSize.y, 0) * _offsetAngleValue
    return Vector2.New(v3.x, v3.y)
end

function this.OnInitComplete()
    if this.OnInit then
        this.OnInit()
    end
end