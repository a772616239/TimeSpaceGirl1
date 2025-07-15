local PoolItemBase = require("Modules/Common/Pool/PoolItemBase")
local PlayerHead = quick_class("PlayerHead", PoolItemBase)

-- 对象创建时回调（只会调用一次）
function PlayerHead:OnCreate()
    self.icon = Util.GetGameObject(self.gameObject, "icon")
    self.frame = Util.GetGameObject(self.gameObject, "frame")
    self.lvRoot = Util.GetGameObject(self.gameObject, "lvRoot")
    self.lv = Util.GetGameObject(self.gameObject, "lvRoot/lv")
end
-- 对象使用时回调（会重复调用）
function PlayerHead:OnUse()
    self:Reset()
end
-- 对象回收时回调（会重复调用）
function PlayerHead:OnRecycle()
end
-- 对象销毁时回调（只会调用一次）
function PlayerHead:OnDestroy()
end

-- 设置头像
function PlayerHead:SetHead(headId)
    self.icon:SetActive(true)
    self.icon:GetComponent("Image").sprite = GetPlayerHeadSprite(headId)
end

-- 设置头像框
function PlayerHead:SetFrame(frameId)
    self.frame:SetActive(true)
    self.frame:GetComponent("Image").sprite = GetPlayerHeadFrameSprite(frameId)
end

-- 设置等级
function PlayerHead:SetLevel(level)
    self.lvRoot:SetActive(true)
    self.lv:GetComponent("Text").text = level
end

-- 设置等级
function PlayerHead:SetGray(isGray)
    Util.SetGray(self.gameObject, isGray)
end

function PlayerHead:Reset()
    Util.SetGray(self.gameObject, false)
    self.icon:SetActive(false)
    self.frame:SetActive(false)
    self.lvRoot:SetActive(false)
end

return PlayerHead