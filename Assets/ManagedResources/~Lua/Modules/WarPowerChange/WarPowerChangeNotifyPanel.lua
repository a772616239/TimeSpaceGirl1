--[[
 * @Classname WarPowerChangeNotifyPanel
 * @Description 战力变化提醒
 * @Date 2019/5/10 11:20
 * @Created by MagicianJoker
--]]

require("Base/BasePanel")
require("Base/Stack")
---@class WarPowerChangeNotifyPanel
WarPowerChangeNotifyPanel = Inherit(BasePanel)
local itemListPrefab = Stack.New()

local PowerChangeIconDef = {
    "r_hero_shengji", --战力提升
    "r_hero_xiajiang" --战力下降
}

function WarPowerChangeNotifyPanel:InitComponent()
    self.item = Util.GetGameObject(self.transform, "item")
    self.item.gameObject:SetActive(false)

    self.itemCache = Util.GetGameObject(self.transform, "itemCache")

end

--{oldValue = oldWarPowerValue,newValue = newWarPowerValue}
function WarPowerChangeNotifyPanel:OnOpen(context)
    self:SetItemValue(context)
end

function WarPowerChangeNotifyPanel:SetItemValue(context)
    local go = itemListPrefab:Peek()
    if not go then
        go = newObjToParent(self.item, self.itemCache.transform)
        itemListPrefab:Push(go)
    end
    go = itemListPrefab:Pop()
    go.transform:SetParent(self.itemCache.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero
    go.gameObject:SetActive(true)
    local powerText = Util.GetGameObject(go, "powerValue"):GetComponent("Text")
    local changeValueDown = Util.GetGameObject(go, "changeValueDown")
    local changeValueUp = Util.GetGameObject(go, "changeValueUp")
    changeValueDown.transform.localPosition = Vector3.New(240 + string.len(context.oldValue)*30,-6.23,0)
    changeValueUp.transform.localPosition = Vector3.New(240 + string.len(context.oldValue)*30,-6.23,0)
    local chaZhi = context.newValue - context.oldValue
    DoTween.To(DG.Tweening.Core.DOGetter_int( function () return 0 end),
            DG.Tweening.Core.DOSetter_int(function (progress)
                if chaZhi > 0 then
                    changeValueUp:SetActive(true)
                    changeValueDown:SetActive(false)
                    changeValueUp:GetComponent("Text").text = progress
                else
                    changeValueUp:SetActive(false)
                    changeValueDown:SetActive(true)
                    changeValueDown:GetComponent("Text").text = -progress
                end
            end), context.newValue - context.oldValue, 0.5):SetEase(Ease.Linear)
    powerText.text = context.oldValue
    Util.GetGameObject(go, "upOrDownIcon"):GetComponent("Image").sprite = Util.LoadSprite(context.oldValue > context.newValue and PowerChangeIconDef[2] or PowerChangeIconDef[1])
    Util.GetGameObject(go, "changeValue"):GetComponent("Text").text = math.abs(context.newValue - context.oldValue)
    Timer.New(function ()
        go.transform:SetParent(self.itemCache.transform)
        itemListPrefab:Push(go)
        go.gameObject:SetActive(false)
    end, 1):Start()
    --go.transform:DOLocalMoveY(550, 1, false):OnComplete(function()
    --    go.transform:SetParent(self.itemCache.transform)
    --    itemListPrefab:Push(go)
    --    go.gameObject:SetActive(false)
    --end)
end

return WarPowerChangeNotifyPanel