require("Modules/Map/Logic/TileMapView")
require("Modules/Map/Config/MapConfig")

local MapPointConfig = ConfigManager.GetConfig(ConfigName.MapPointConfig)
MapPointView = {}
MapPointView.__index = MapPointView

local function TestCreatePoint(iconId, self)
    local go = poolManager:LoadAsset("UI_MapPoint", PoolManager.AssetType.GameObject)
    go.name = "EventPoint"
    go:SetActive(false)
    Util.GetGameObject(go, "shadow"):SetActive(true)
    local live
    -- 设置立绘的初始动画,宝箱特殊处理
    if not MapPointView:IsEffectRes(iconId) then
        live = MapPointView:InitLiveSet(live, iconId, go)
    else -- 当前是个大宝箱
        live = MapPointView:InitEffectSet(live, iconId, go)
    end

    self.resPath = "UI_MapPoint"
    self.go = go
    Util.GetGameObject(self.go, "root"):SetActive(true)
    Util.GetGameObject(self.go, "shadow"):SetActive(true)
    self.livePath = MapFloatingConfig[iconId].name
    self.live = live
    -- 事件点图标ID
    self.iconId = iconId
end

-- =====================  地图点资源的加载 =======
-- 立绘资源的初始化加载
function MapPointView:InitLiveSet(live, iconId, go)
    self.live2d = Util.GetTransform(go, "root/heroicon")
    LogYellow("### cell.Icon")
    self.live2d:GetComponent("Image").sprite= Util.LoadSprite(MapFloatingConfig[iconId].name)
    self.live2d:GetComponent("RectTransform").localScale=MapFloatingConfig[iconId].scale
    self.live2d:GetComponent("RectTransform").localPosition=MapFloatingConfig[iconId].position
    -- self.live2d = poolManager:LoadLive(MapFloatingConfig[iconId].name, Util.GetTransform(go, "root"),
    --         MapFloatingConfig[iconId].scale, MapFloatingConfig[iconId].position)
    -- local skeleton = self.live2d:GetComponent("SkeletonGraphic")
    -- self.oAnim = function()
    --     if ANIMATION[iconId] and ANIMATION[iconId].animation[1] and skeleton.AnimationState then
    --         skeleton.AnimationState:SetAnimation(0, ANIMATION[iconId].animation[1], true)
    --     end
    -- end
    -- skeleton.AnimationState.Complete = skeleton.AnimationState.Complete + self.oAnim

    --poolManager:SetLiveClearCall(MapFloatingConfig[iconId].name, self.live2d, function ()
    --    if self.live2d and skeleton and skeleton.AnimationState then
    --        skeleton.AnimationState.Complete = skeleton.AnimationState.Complete - oAnim
    --    end
    --end)
    return self.live2d
end

-- 特效资源的加载
function MapPointView:InitEffectSet(live, iconId, go)
    self.effectLive = Util.GetTransform(go, "root/heroicon")
    LogYellow("### cell.Icon")
    self.effectLive:GetComponent("RectTransform").localScale=MapFloatingConfig[iconId].scale
    self.effectLive:GetComponent("RectTransform").localPosition=MapFloatingConfig[iconId].position
    self.effectLive:GetComponent("Image").sprite= Util.LoadSprite(MapFloatingConfig[iconId].name)

    return self.effectLive
end

-- 判断是否是特效资源
function MapPointView:IsEffectRes(iconId)
    if not isEffect[iconId] then
        return false
    else
        return isEffect[iconId]
    end
end

-- ============================================
function MapPointView.New(u, v, pointId)
    local instance = {}
    setmetatable(instance, MapPointView)
    local cell = MapPointConfig[pointId]
    if not cell then
        
        return
    end
    instance.cell = cell
    instance.u = u
    instance.v = v
    if cell.Style == 8 then --阻挡点不处理
        TileMapView.GetTileData(u, v).val = 2
        
        return
    elseif cell.Style == 2 then --矿
    elseif cell.Style == 7 then --宝箱
    elseif cell.Style == 3 then --出生地
        MapManager.curMapBornPos = Map_UV2Pos(u, v)
    elseif cell.Style == 4 then --传送门
    elseif cell.Style == 10 then -- 桥
        TileMapView.GetTileData(u, v).val = 2
    elseif cell.Style == 1 then
        TileMapView.GetTileData(u, v).val = 2
    end


    MapPointView.hadExit = false
    MapPointView.hadDispose = false
    TestCreatePoint(cell.Icon, instance)
    return instance
end

function MapPointView:OnShow()
    self.go:SetActive(true)
end

-- 初始化事件点的显示状态
function MapPointView:InitEventPointShow()
    local isHide = false
    if self.cell.isHidden == 2 or self.cell.isHidden == 3 then
        isHide = true
    else
        isHide = false
    end
    return isHide
end

-- 在视野范围内刷新隐藏类型为1的点
function MapPointView:CanSeePoint()
    local isShow = self.cell.isHidden ~= 2 and self.cell.isHidden ~= 3
    self.go:SetActive(isShow)
end

-- 事件点触发时显示隐藏类型为2的点
function MapPointView:ShowHidePoint()
    local isShow = self.cell.isHidden ~= 3
    self.go:SetActive(isShow)
end

-- 是否显示战力
function MapPointView:ShowAtkNum(num, state, teamPower)
    local atkGo = Util.GetGameObject(self.go, "atk/Image/Text")
    local root = Util.GetGameObject(self.go, "atk")
    if not num or num <= 0 then
        root:SetActive(false)
    else
        if teamPower and teamPower  > 0 then
            local str = ""
            if teamPower < num then
                str =  string.format("<color=#FF0014FF>%s</color>", tostring(num))
            else
                str = tostring(num)
            end
            atkGo:GetComponent("Text").text = str
        else
            atkGo:GetComponent("Text").text = num
        end
        root:SetActive(state)
    end
end



-- 是否显示刷新点的倒计时
function MapPointView:ShowFreshTime(state)
    Util.GetGameObject(self.go, "freshTime"):SetActive(state)
end

-- 是否显示对话
function MapPointView:ShowDialogue(state)
    Util.GetGameObject(self.go, "Dialogue"):SetActive(state)
end

--- 设置对话文字内容以及方向性
--- @param pos 设置对话框的上下左右
function MapPointView:SetDialogueDir(pos, angle)
    local diaRoot = Util.GetGameObject(self.go, "Dialogue")
    local strRoot = Util.GetGameObject(self.go, "Dialogue/Text")
    diaRoot.transform.localEulerAngles = angle
    strRoot.transform.localEulerAngles = angle
    diaRoot.transform.localPosition = pos
end

-- 设置对话内容
function MapPointView:SetDialogueStr(str)
    local diaText = Util.GetGameObject(self.go, "Dialogue/Text"):GetComponent("Text")
    diaText.text = str
end


function MapPointView:OnRemovePoint()
    if self.cell.Style == 10 or self.cell.Style == 8 then
        TileMapView.GetTileData(self.u, self.v).val = 0
    end
    -- 宝箱的销毁有点特殊
    if self.iconId == 8 and not self.hadExit then
        self.live:SetActive(false)
        -- Util.GetGameObject(self.live, "idle1"):SetActive(false)
        -- Util.GetGameObject(self.live, "open"):SetActive(true)
        -- Util.GetGameObject(self.go, "shadow"):SetActive(false)
        self.timer = Timer.New(function ()
            if not self.hadExit then
                self:Dispose()
            end
        end, 2)
        self.timer:Start()
    else
        self:Dispose()
    end
end

-- 设置事件点动画
function MapPointView:SetPointAnimation(iconId, index)
    -- 特效资源无动画
    if MapPointView:IsEffectRes(iconId) then return end
    -- local skeleton = self.live:GetComponent("SkeletonGraphic")
    -- local animation = ANIMATION[iconId]
    if animation then
        local aniName = ANIMATION[iconId].animation[index]
        if aniName then
            skeleton.AnimationState:SetAnimation(0, aniName, false)
        end
    else
        
    end
end

function MapPointView:Dispose()
    self.hadExit = true
    -- 特效资源的销毁
    Util.GetGameObject(self.go, "root"):SetActive(false)
    Util.GetGameObject(self.go, "shadow"):SetActive(false)
    if MapPointView:IsEffectRes(self.iconId) then
        if self.live and not self.hadDispose then
            self.hadDispose = true
            poolManager:UnLoadAsset(self.livePath, self.live, PoolManager.AssetType.GameObject)
            -- self.live:SetActive(false)
            self.live=nil
        end
        
    else
        if self.live then
            -- self.live:SetActive(false)
            self.live = nil
        end
    end
    if self.go then
        poolManager:UnLoadAsset(self.resPath, self.go, PoolManager.AssetType.GameObject)
        self.go = nil
    end
    self.effectLive = nil
    self.live2d = nil

end