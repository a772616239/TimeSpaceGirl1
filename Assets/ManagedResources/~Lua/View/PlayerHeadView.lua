local PlayerHeadView = {}

function PlayerHeadView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = PlayerHeadView })
    return b
end
--初始化组件（用于子类重写）
function PlayerHeadView:InitComponent()
    self.icon = Util.GetGameObject(self.gameObject, "icon")
    self.frame = Util.GetGameObject(self.gameObject, "frame")
    self.lvRoot = Util.GetGameObject(self.gameObject, "lvRoot")
    self.lv = Util.GetGameObject(self.gameObject, "lvRoot/lv")
end

--绑定事件（用于子类重写）
function PlayerHeadView:BindEvent()
    Util.AddOnceClick(self.icon, function ()
        if self.uid > 0 then
            UIManager.OpenPanel(UIName.PlayerInfoPopup, self.uid, self.ViewType, self.severID, self.typeId)
        end
    end)
end

--添加事件监听（用于子类重写）
function PlayerHeadView:AddListener()
end

--移除事件监听（用于子类重写）
function PlayerHeadView:RemoveListener()
end

--界面打开时调用（用于子类重写）
function PlayerHeadView:OnOpen(...)
    self:Reset()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PlayerHeadView:OnShow()
end

--界面关闭时调用（用于子类重写）
function PlayerHeadView:OnClose()
    self:Reset()
end

-- 设置头像
function PlayerHeadView:SetHead(headId,headStr)
    self.icon:SetActive(true)
    if headId ~= nil then
        self.icon:GetComponent("Image").sprite = GetPlayerHeadSprite(headId)
    elseif headStr ~= nil then
        self.icon:GetComponent("Image").sprite = Util.LoadSprite(headStr)
    end
end

-- 设置头像框
function PlayerHeadView:SetFrame(frameId,frameStr)
    self.frame:SetActive(true)
    if frameId ~= nil then
        self.frame:GetComponent("Image").sprite = GetPlayerHeadFrameSprite(frameId)
    elseif frameStr ~= nil then
        self.frame:GetComponent("Image").sprite = Util.LoadSprite(frameStr)
    end
end

-- 设置等级
function PlayerHeadView:SetLevel(level)
    self.lvRoot:SetActive(true)
    self.lv:GetComponent("Text").text = level
end

function PlayerHeadView:SetGray(isGray)
    Util.SetGray(self.gameObject, isGray)
end

function PlayerHeadView:Reset()
    Util.SetGray(self.gameObject, false)
    self.icon:SetActive(false)
    self.frame:SetActive(false)
    self.lvRoot:SetActive(false)
    self.icon:GetComponent("Image").raycastTarget = false
    self.uid = 0
    self.typeId = PlayerInfoType.None
    self.severID = 0
end

function PlayerHeadView:SetUID(uid)
    self.icon:GetComponent("Image").raycastTarget = true
    self.uid = uid
end

-- 设置节点父节点
function PlayerHeadView:SetParent(parent)
    if self.transform then
        self.transform:SetParent(parent.transform)
        self.parent = parent.transform
    end
end

-- 设置节点位置
function PlayerHeadView:SetPosition(v3)
    if not v3 then return end
    if self.transform then
        self.transform.localPosition = v3
    end
end

-- 设置节点缩放值
function PlayerHeadView:SetScale(v3)
    if type(v3) == "number" then
        v3 = Vector3.one * v3
    end
    if not v3 then return end
    if self.transform then
        self.transform.localScale = v3
    end
end

-- 设置另外的参数
function PlayerHeadView:SetSeverID(severID)
    self.severID = severID
end

function PlayerHeadView:SetClickedTypeId(typeId)
    self.typeId = typeId
end

function PlayerHeadView:SetViewType(type)
    self.ViewType = type
end

function PlayerHeadView:Recycle()
    SubUIManager.Close(self)
end
return PlayerHeadView