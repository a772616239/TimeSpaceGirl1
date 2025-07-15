BuffView ={}
BuffView.__index = BuffView

function BuffView.New(go, buff, icon)
    local instance = {}
    setmetatable(instance, BuffView)

    instance.go = go
    instance.buff = buff
    instance.levelText = Util.GetGameObject(go, "level"):GetComponent("Text")
    instance.layerText = Util.GetGameObject(go, "layer"):GetComponent("Text")
    instance.roundText = Util.GetGameObject(go, "round"):GetComponent("Text")
    instance.duration = buff.duration

    instance.icon = go:GetComponent("Image")
    instance.icon.sprite = Util.LoadSprite(icon)
    instance.icon.color = Color.New(1,1,1,1)

    if buff.layer and buff.cover then
        instance.levelText.text = tostring(buff.layer)
        instance.count = buff.layer
    else
        instance.levelText.text = ""
        instance.count = 1
    end
    instance.layerText.text = ""
    instance.roundText.text = ""
    instance.hideFlag = false
    instance:SetRound(buff)

    Util.GetGameObject(go, "round"):SetActive(false)
    --> 怒气显示层数 todo
    if buff.type == BuffName.Brand and (buff.flag == 4 or buff.flag == 5) then
        Util.GetGameObject(go, "level"):SetActive(true)
    else
        Util.GetGameObject(go, "level"):SetActive(false)
    end

    return instance
end

function BuffView:Dispose()
    BattlePool.RecycleItem(self.go, BATTLE_POOL_TYPE.BUFF_VIEW)
end

function BuffView:SetCount(count)
    -- if self.tweener then
    --     self.tweener:Kill()
    --     self.icon.color = Color.New(1,1,1,1)
    -- end
    if not count then
        count = self.count
    end

    if not self.buff.cover then
        if count == 1 then --只有1个独立buff，不显示数字
            self.layerText.text = ""
            self.count = 1
        else
            self.layerText.text = tostring(count)
            self.count = count
        end
    end
end

function BuffView:SetLayer(buff)
    -- if self.tweener then
    --     self.tweener:Kill()
    --     self.icon.color = Color.New(1,1,1,1)
    -- end
    self.buff = buff
    if buff.layer and buff.cover then
        self.levelText.text = tostring(buff.layer)
    end
end

function BuffView:SetRound(buff)
    -- body
    self.buff = buff
    self.roundText.text = ""
    if buff.roundDuration then
        local leftRound = buff.roundDuration - buff.roundPass
        if leftRound > 0 then
            self.roundText.text = tostring(leftRound)
        end
    end
end

function BuffView:Update()
    -- if self.buff.frameDuration > 0 then
    --     local num = (self.buff.frameDuration - self.buff.framePass) / BattleLogic.GameFrameRate
    --     if num < 1 and self.count == 1 and not self.hideFlag then --当不可叠加的buff只剩一个且持续时间小于1秒时，播闪烁效果
    --         self.hideFlag = true
    --         self.tweener = self.icon:DOFade(0, 0.2):OnComplete(function ()
    --             self.tweener = self.icon:DOFade(1, 0.2):OnComplete(function ()
    --                 self.tweener = self.icon:DOFade(0, 0.2):OnComplete(function ()
    --                     self.tweener = self.icon:DOFade(1, 0.2):OnComplete(function ()
    --                         self.tweener = self.icon:DOFade(0, 0.2)
    --                     end)
    --                 end)
    --             end)
    --         end)
    --     end
    -- end
end