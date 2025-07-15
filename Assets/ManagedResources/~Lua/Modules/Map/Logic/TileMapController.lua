require("Modules/Map/Logic/TileMapView")

--在地块表现数据类之上派生一层控制类
TileMapController = {}
local this = TileMapController
--保存触碰点，做双点缩放和单点移动判定
local _touch1, _touch2
-- 移动后产生的缓动效果
local _moveTween
--缩放的中心点
local _scalePoint = Vector2.zero
--事件系统
local _trigger
--缓动到目标的缩放大小
local _targetScale
--区分点击/拖动
local _isClicked

--委托实现
this.OnMove = nil
this.OnMoveEnd = nil
this.OnDispose = nil
this.OnShowTile = nil
this.OnClickTile = nil
this.OnLongClickTile = nil
this.OnScale = nil
this.OnLongClickShowPath = nil
--是否屏蔽拖动
this.IsShieldDrag = nil

--监听长按事件
local timePressStarted
local bLongPressTriggered
local timePressData
local longClickMapU
local longClickMapV
local update = function()
    if _isClicked then
        if Time.realtimeSinceStartup - timePressStarted > 0.4 then
            if not bLongPressTriggered then
                local uv = TileMapView.GetLiveTileInScreenPos(Input.mousePosition)
                if longClickMapU ~= uv[1] or longClickMapV ~= uv[2] then
                    longClickMapU = uv[1]
                    longClickMapV = uv[2]
                    if this.OnLongClickShowPath then
                        --this.OnLongClickShowPath(uv[1], uv[2])
                    end
                end
                bLongPressTriggered = true
            end
        end
    end
end

function this.Init(CtrlGO, go)
    _trigger = Util.GetEventTriggerListener(go)
    if _trigger then
        _trigger.onPointerDown = _trigger.onPointerDown + this.OnPointerDown
        _trigger.onPointerUp = _trigger.onPointerUp + this.OnPointerUp
        _trigger.onScroll = _trigger.onScroll + this.OnScrollMouse
        _trigger.onBeginDrag = _trigger.onBeginDrag + this.OnBeginDarg
        _trigger.onDrag = _trigger.onDrag + this.OnDrag
        _trigger.onEndDrag = _trigger.onEndDrag + this.OnEndDrag
    end

    _moveTween = CtrlGO:GetComponent(typeof(UITweenSpring))
    if not _moveTween then
        _moveTween = CtrlGO:AddComponent(typeof(UITweenSpring))
    end
    _moveTween.enabled = false
    _moveTween.OnUpdate = this.SetPosition
    _moveTween.OnMoveEnd = this.OnMapTweenEnd
    _moveTween.MomentumAmount = 0.5
    _moveTween.Strength = 50

    UpdateBeat:Add(update, this)
    this.SetScale(TileMapView.GetMapScale())
    _touch1, _touch2 = nil, nil
end

function this.Exit()
    if _trigger then
        _trigger.onPointerDown = _trigger.onPointerDown - this.OnPointerDown
        _trigger.onPointerUp = _trigger.onPointerUp - this.OnPointerUp
        _trigger.onScroll = _trigger.onScroll - this.OnScrollMouse
        _trigger.onBeginDrag = _trigger.onBeginDrag - this.OnBeginDarg
        _trigger.onDrag = _trigger.onDrag - this.OnDrag
        _trigger.onEndDrag = _trigger.onEndDrag - this.OnEndDrag
    end
    _moveTween = nil

    this.OnMove = nil
    this.OnMoveEnd = nil
    this.OnDispose = nil
    this.OnShowTile = nil
    this.OnClickTile = nil
    this.OnScale = nil

    this.IsShieldDrag = nil
    UpdateBeat:Remove(update, self)
end

function this.SetEnable(enabled)
    _trigger.enabled = enabled
    _touch1, _touch2 = nil, nil
end

function this.OnMapTweenEnd()
    this.SetPosition2(Vector3.zero, true)
end

function this.OnPointerDown(Pointgo, data)
    data:Use()
    if not _touch1 then
        _touch1 = data
    elseif not _touch2 and _touch1 ~= data then --当切出unity应用时，第一次点击将接收不到OnPointerUp事件
        _touch2 = data
    end
    if _touch1 and _touch2 then
        _moveTween.enabled = false
    end

    local b = (_touch1 and not _touch2) or (_touch2 and not _touch1)
    if b then
        timePressStarted = Time.realtimeSinceStartup
        timePressData = data
        bLongPressTriggered = false
    end
    _isClicked = b
end

function this.OnPointerUp(Pointgo, data)
    data:Use()
    if _touch1 == data then
        _touch1 = nil
    elseif _touch2 == data then
        _touch2 = nil
    end
    if not _touch1 and not _touch2 then
        if bLongPressTriggered then
            if this.OnLongClickTile then
                this.OnLongClickTile()
            end
        else
            if _isClicked then
                if this.OnClickTile then
                    local uv, fuv = TileMapView.GetLiveTileInScreenPos(data.position)
                    this.OnClickTile(uv[1], uv[2], fuv)
                end
            end
        end
    end
    _isClicked = false
end

function this.OnBeginDarg(Pointgo, data)
    if (_touch1 and not _touch2) or (_touch2 and not _touch1) then
        if _touch1 == data then
            _moveTween.enabled = true
            _moveTween.Momentum = Vector3.zero
            _moveTween.IsUseCallBack = false
        end
        _isClicked = false
    end
    data:Use()
end

function this.OnDrag(Pointgo, data)
    if _touch1 or _touch2 then
        if _touch1 and _touch2 then --双点缩放
            local distance = Vector2.Distance(_touch1.position, _touch2.position)
            local distance1 = Vector2.Distance(_touch1.pressPosition, _touch2.pressPosition)
            if distance1 <= 0 then
                return
            end

            _scalePoint = Vector2.Lerp(_touch1.position, _touch2.position, 0.5)
            local scale = TileMapView.GetMapScale() - (distance1 - distance) / Screen.width / 10
            this.SetScale(scale)
        else --单点移动
            if bLongPressTriggered then
                local uv = TileMapView.GetLiveTileInScreenPos(data.position)
                if longClickMapU ~= uv[1] or  longClickMapV ~= uv[2] then
                    longClickMapU = uv[1]
                    longClickMapV = uv[2]
                    if this.OnLongClickShowPath then
                        this.OnLongClickShowPath(uv[1], uv[2])
                    end
                end
            else
                if this.IsShieldDrag() then return end
                _moveTween:LerpMomentum(data.delta)
                this.SetPosition(data.delta)
            end
        end
    end
    data:Use()
end

function this.OnEndDrag(Pointgo, data)
    if not _touch1 and not _touch2 then --移动增加缓动效果
        if this.IsShieldDrag() then return end
        this.SetPosition2(data.delta, true)
        _moveTween.IsUseCallBack = true
    elseif _touch1 and not _touch2 then --限定缩放范围
        _targetScale = TileMapView.GetMapScale()
    end
    data:Use()
end

function this.OnScrollMouse(Pointgo, data)
    _scalePoint = data.position
    this.SetScale(TileMapView.GetMapScale() + data.scrollDelta.y / TileMapView.PIXELS_PER_UNIT)
end

function this.SetPosition(delta)
    this.SetPosition2(delta, false)
end

function this.SetPosition2(delta, invokeCall)
    TileMapView.CameraMove(Vector2.New(math.floor(delta.x), math.floor(delta.y)))
    TileMapView.UpdateBaseData()

    if this.OnMove then
        this.OnMove(TileMapView.IndexU, TileMapView.IndexV)
    end

    if invokeCall and this.OnMoveEnd then
        this.OnMoveEnd(TileMapView.IndexU, TileMapView.IndexV)
    end
end

function this.SetCameraPosition(diamond, isWorldPos, invokeCall)
    if isWorldPos then
        Util.SetPosition(TileMapView.ViewCameraTran, diamond.x, diamond.y, TileMapView.ViewCameraPos.z)
        TileMapView.SetCameraPos(TileMapView.ViewCameraPos)
    else
        TileMapView.SetCameraPos(Vector3.New( diamond.x, diamond.y, TileMapView.ViewCameraPos.z))
    end
    TileMapView.UpdateBaseData()
    TileMapView.UpdateFunc()
    if this.OnMove then
        this.OnMove(TileMapView.IndexU, TileMapView.IndexV)
    end
    if invokeCall and this.OnMoveEnd then
        this.OnMoveEnd(TileMapView.IndexU, TileMapView.IndexV)
    end
end

function this.DrawTile(tileGo, u, v, type)
    TileMapView.DrawTile(tileGo, u, v, type)
    if this.OnShowTile then
        this.OnShowTile(u, v, type)
    end
end

function this.SetScale(scale)
    TileMapView.CameraScale(_scalePoint, scale)

    if this.OnScale then
        this.OnScale(scale)
    end
end

function this.OnDestroy()
    if this.OnDispose then
        this.OnDispose()
    end
end

--定位到指定UV
function this.LocateToUV(u, v)
    _moveTween.enabled = false
    _moveTween.Momentum = Vector3.zero
    this.SetCameraPosition(TileMapView.ScreenPos2MapPos(Vector2.New(u, v)), false, true)
end

--点击地图
function this.OnClickMapTile(screenPos)
    local uv = TileMapView.GetLiveTileInScreenPos(screenPos)
    if bLongPressTriggered then
        
        if this.OnLongClickTile then
            this.OnLongClickTile()
        end
    else
        if this.OnClickTile then
            this.OnClickTile(uv[1], uv[2])
        end
    end
end