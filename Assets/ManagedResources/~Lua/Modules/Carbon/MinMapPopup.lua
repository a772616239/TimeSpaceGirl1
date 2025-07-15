require("Base/BasePanel")
MinMapPopup = Inherit(BasePanel)
local this = MinMapPopup
local mapConfig = ConfigManager.GetConfig(ConfigName.ChallengeMapConfig)
local scaleVale = math.min(Screen.width/1080, Screen.height/1920)
local hasMsg = false

-- 格子数量
local gridWidth = 0
local gridHeight = 0

this.iconList = {}

-- 已经请求的服务器数据, 界面没销毁时不用在请求
this.roleXY = 0
this.points = {}

--初始化组件（用于子类重写）
function MinMapPopup:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "Frame/btnBack")
    this.iconPre = Util.GetGameObject(self.gameObject, "Frame/viewRect/iconPre")
    this.miniMap = Util.GetGameObject(self.gameObject, "Frame/viewRect/miniMap")
    this.dragView = SubUIManager.Open(SubUIConfig.DragView, self.gameObject.transform)
    this.dragView.transform:SetAsFirstSibling()

    -- 角色自己
    this.roleFrame = Util.GetGameObject(self.gameObject, "Frame/viewRect/role/frame"):GetComponent("Image")
    this.roleIcon = Util.GetGameObject(self.gameObject, "Frame/viewRect/role/icon"):GetComponent("Image")
    this.roleLv = Util.GetGameObject(self.gameObject, "Frame/viewRect/role/imgLv/lv"):GetComponent("Text")
    this.role = Util.GetGameObject(self.gameObject, "Frame/viewRect/role")
    this.btnRole = Util.GetGameObject(self.gameObject, "Frame/viewRect/role/btnRole")

    this.role:SetActive(false)
end

--绑定事件（用于子类重写）
function MinMapPopup:BindEvent()

    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)

    Util.AddOnceClick(this.dragView.gameObject, function()

        local curPos = this.miniMap:GetComponent("RectTransform").anchoredPosition
        if curPos.x < this.edgePos.x_pos.min or curPos.x > this.edgePos.x_pos.max or curPos.y < this.edgePos.y_pos.min or curPos.y > this.edgePos.y_pos.max then
            this.miniMap:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
        end
    end)

    Util.AddClick(this.btnRole, function ()

    end)
end

--添加事件监听（用于子类重写）
function MinMapPopup:AddListener()

end

--移除事件监听（用于子类重写）
function MinMapPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MinMapPopup:OnOpen(...)

    if not hasMsg then
        hasMsg = true
        if this.roleXY > 0 and #this.points > 0 then
            this.LoadMapData(this.points, function ()
                this.SetRoleInfo(this.roleXY)
            end)
        else
            NetManager.RequestMiniMapInfo(function (msg)
                this.roleXY = msg.myXY
                this.points = msg.points
                -- 加载数据
                this.LoadMapData(msg.points, function ()
                    this.SetRoleInfo(msg.myXY)
                end)
            end)
        end
    end
end

function this.LoadMapData(points, func)
    this.dragView:SetDragGO(this.miniMap)
    -- Get Map Size
    local mapData = mapConfig[EndLessMapManager.openMapId].Size
    gridWidth = mapData[1]
    gridHeight = mapData[2]

    -- Get Size
    local size = this.miniMap:GetComponent("RectTransform").sizeDelta
    local iconSize = this.iconPre:GetComponent("RectTransform").sizeDelta
    -- 边界分割加校验值
    this.width = size.x - iconSize.x
    this.height = size.y - iconSize.y

    -- 设置比例值
    this.x_leng = this.width / gridWidth
    this.y_leng =  this.height  / gridHeight

    --设置边界值
    this.edgePos = {}
    this.edgePos = {
        x_pos = {min = - 0.8 * this.width / scaleVale, max = this.width * 0.6 / scaleVale},  -- X_pos
        y_pos = {min = - 0.6 * this.height / scaleVale, max = this.height * 0.6 / scaleVale},
    }

    this.SetGridInfo(func, points)

end

function this.SetGridInfo(func, points)
    for i = 1, #points do
        if not this.iconList[i] then
            -- 设置位置
            local u, v = Map_Pos2UV(points[i].location)
            local icon = newObjToParent(this.iconPre, this.miniMap)
            this.SetIconPos(u, v, icon)

            -- 设置怪物信息
            local monsterIcon = Util.GetGameObject(icon, "icon"):GetComponent("Image")
            local lv = Util.GetGameObject(icon, "imgLv/lv"):GetComponent("Text")
            local btn = Util.GetGameObject(icon, "btnMonster")
            local mIcon, mLv = MonsterCampManager.GetIconByMonsterId(points[i].monsterId)

            monsterIcon.sprite = mIcon
            lv.text = mLv

            this.iconList[i] = icon

            Util.AddOnceClick(btn, function ()

            end)
        end
    end

    if func then func() end
end

function this.SetRoleInfo(pos)
    -- 设置位置
    local x, y = Map_Pos2UV(pos)
    this.role.transform:SetParent(this.miniMap.transform)
    this.role:SetActive(true)
    this.SetIconPos(x, y, this.role, true)

    this.roleFrame.sprite = GetPlayerHeadFrameSprite(PlayerManager.frame)
    this.roleIcon.sprite = GetPlayerHeadSprite(PlayerManager.head)
    this.roleLv = PlayerManager.level

end

function this.SetIconPos(u, v, iconGo, isRole)
    local new_x = this.x_leng * u - this.width / 2
    local new_y = this.height / 2 - this.y_leng * v
    local newPos = Vector3.New(new_x , new_y,0)
    iconGo.transform.localPosition = newPos
    if not isRole then
        iconGo.transform.localScale = Vector3.New(0.8, 0.8, 0.8) / scaleVale
    else
        iconGo.transform.localScale = Vector3.New(1, 1, 1) / scaleVale
    end
end

--界面关闭时调用（用于子类重写）
function MinMapPopup:OnClose()

    hasMsg = false
end

--界面销毁时调用（用于子类重写）
function MinMapPopup:OnDestroy()

    this.iconList = {}
    this.roleXY = 0
    this.points = {}

end

return MinMapPopup