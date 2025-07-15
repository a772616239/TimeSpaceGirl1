local PoZhenZhuXian = quick_class("PoZhenZhuXian")
local orginLayer = 0

function PoZhenZhuXian:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel.transform
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function PoZhenZhuXian:InitComponent(gameObject)

end

function PoZhenZhuXian:BindEvent()

end

function PoZhenZhuXian:OnShow(sortingOrder)

end



--- 将一段时间转换为天时分秒
function PoZhenZhuXian:TimeToDHMS(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    if day <= 0 and hour <= 0 then
        return string.format(GetLanguageStrById(12231),minute, sec)
    else
        return string.format(GetLanguageStrById(12232),day, hour)
    end
end


function PoZhenZhuXian:OnSortingOrderChange(_sortingOrder)
    orginLayer = _sortingOrder
end

function PoZhenZhuXian:OnHide()

end

return PoZhenZhuXian