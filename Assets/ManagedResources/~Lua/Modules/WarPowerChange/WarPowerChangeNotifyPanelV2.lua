--[[
 * @ClassName WarPowerChangeNotifyPanelV2
 * @Description 战力升级提醒
 * @Date 2019/9/10 9:54
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class WarPowerChangeNotifyPanelV2
---传参方式为context表内包含属性传入
---isShowBg 是否显示背景、战力文字
---isShowOldNum 是否显示旧战力数字
---pivot 设置pivot
---pos 设置pos

local WarPowerChangeNotifyPanelV2 = quick_class("WarPowerChangeNotifyPanelV2", BasePanel)
local isChanging = false
local content --内容
local duration=0.7 --持续时长
local isShowBg=true --默认显示背景战力
local isShowOldNum=true --默认显示旧战力
local pivot=Vector2.New(0.5,0.5) --默认pivot

function WarPowerChangeNotifyPanelV2:InitComponent()
    self.bg = Util.GetGameObject(self.transform, "bg")
    self.powerIcon=Util.GetGameObject(self.transform,"bg/powerValue/powerIcon")
    self.powerValue = Util.GetGameObject(self.transform, "bg/powerValue"):GetComponent("Text")
    self.powerValueElement=self.powerValue:GetComponent("LayoutElement")

    self.changeUp = Util.GetGameObject(self.transform.gameObject, "bg/powerValue/powerIcon/Up")
    self.changeDown = Util.GetGameObject(self.transform.gameObject, "bg/powerValue/powerIcon/Down")

    self.changeValueUp = Util.GetGameObject(self.powerValue.gameObject, "changeValueUp"):GetComponent("Text")
    self.changeValueDown = Util.GetGameObject(self.powerValue.gameObject, "changeValueDown"):GetComponent("Text")

    self.countNumber = 0

    --self.cacheData = {}
end

function WarPowerChangeNotifyPanelV2:OnOpen(_context)
    self.countNumber = self.countNumber + 1
    content=_context
    --table.insert(self.cacheData, context)
    --if self.thread then
    --    return
    --end
    --local progress = function()
    --    while #self.cacheData > 0 do
    --        local context = table.remove(self.cacheData, 1)
    --        self:SetValue(context)
    --        coroutine.wait(0.05)
    --        --coroutine.yield(self.thread)
    --    end
    --    self.cacheData = {}
    --    coroutine.wait(0.5)
    --    self:ClosePanel()
    --end
    --self.thread = coroutine.start(progress)
    --背景显隐
    if content.isShowBg~=nil then
        isShowBg=content.isShowBg
    end
    self.bg:GetComponent("Image").enabled=isShowBg
    self.powerIcon.gameObject:SetActive(isShowBg)
    --旧战力显隐
    if content.isShowOldNum~=nil then
        isShowOldNum=content.isShowOldNum
    end
    self.powerValue.enabled=isShowOldNum
    --设置pivot
    if content.pivot then
        self.bg.transform.pivot=content.pivot
    else
        self.bg.transform.pivot= Vector2.New(0.5,0.5)
    end
    --设置位置
    
    if content.pos then
        self:SetPos(content.pos)
    else
        self:SetPos(Vector3.New(0,189.2,0))
    end
    self:SetValue(content)
end

function WarPowerChangeNotifyPanelV2:SetValue(context)
    if context.duration then duration=context.duration end --若存在时长控制 设置持续时长
    self.countNumber = self.countNumber - 1
    local changeValue = context.newValue - context.oldValue
    self.powerValue.text = context.oldValue
    -- self.powerValueElement.preferredWidth=#tostring(context.newValue)*60 --控制宽度 --n1
    -- self.changeValueDown.transform.localPosition = Vector3.New(240 + string.len(context.oldValue) * 30, -6.23, 0)
    -- self.changeValueUp.transform.localPosition = Vector3.New(240 + string.len(context.oldValue) * 30, -6.23, 0)

    self.changeValueUp.gameObject:SetActive(changeValue > 0)
    self.changeValueDown.gameObject:SetActive(changeValue < 0)
    self.changeUp:SetActive(changeValue > 0)
    self.changeDown:SetActive(changeValue < 0)

    if self.tweener then
        self.tweener:Kill()
    end
    if isChanging then
        if changeValue > 0 then
            self.changeValueUp.text = changeValue
        else
            self.changeValueDown.text = -changeValue
        end
        self:DelayClose()
        return
    end


    self.tweener = DoTween.To(DG.Tweening.Core.DOGetter_int(function()
        return 0
    end),DG.Tweening.Core.DOSetter_int(function(progress)
        if changeValue > 0 then
            self.changeValueUp.text = progress
        else
            self.changeValueDown.text = -progress
        end
    end), changeValue, duration):SetEase(Ease.Linear)
       :OnComplete(function()
        --if self.thread then
        --    coroutine.resume(self.thread)
        --end

        --if self.countNumber == 0 then
        --    self:ClosePanel()
        --end
        self:DelayClose()
    end)
    isChanging = true
 end
function WarPowerChangeNotifyPanelV2:DelayClose()
    if self.closeTweener then
        self.closeTweener:Kill()
    end
    self.closeTweener = DoTween.To(DG.Tweening.Core.DOGetter_int(function() return 0 end),
            DG.Tweening.Core.DOSetter_int(function(progress)end),
            0, 0.3):OnComplete(function()
        isChanging = false
        if self.countNumber == 0 then
            self:ClosePanel()
        end
    end)
end

function WarPowerChangeNotifyPanelV2:OnClose()
    self.countNumber = 0
    isShowBg=true
    isShowOldNum=true
    --self:Reset()
end

--function WarPowerChangeNotifyPanelV2:Reset()
--    if self.thread then
--        coroutine.stop(self.thread)
--    end
--    self.thread = nil
--end
function WarPowerChangeNotifyPanelV2:SetPos(v3)
    self.bg.transform.localPosition=v3
end

return WarPowerChangeNotifyPanelV2