require("Base/BasePanel")
TrialBossTipPopup = Inherit(BasePanel)
local this = TrialBossTipPopup
-- 显示图片类型的枚举
local PIC_TYPE = {
    BOMB = 2,  -- 遇到炸弹
    GAIN = 3,  -- 增益
    SHOP = 4,  -- 试炼商店
    MAP_SHOP = 5, -- 云游商店
    ELITE_MONSTER = 6, -- 大怪
    FIGHT_STRAT = 7, -- 血战开始
    FIGHT_END = 8,  -- 血战结束

}

--初始化组件（用于子类重写）
function TrialBossTipPopup:InitComponent()

    this.aniRoot = Util.GetGameObject(self.gameObject, "tipRoot")
    this.bombTip = Util.GetGameObject(this.aniRoot, "bomb")
    this.shopTip = Util.GetGameObject(this.aniRoot, "shop")
    this.gainTip = Util.GetGameObject(this.aniRoot, "gain")
    this.imgLeft = Util.GetGameObject(this.aniRoot, "img")
    this.imgRight = Util.GetGameObject(this.aniRoot, "img (1)")
    this.mapShop = Util.GetGameObject(this.aniRoot, "mapShop")
    this.eliteMonster = Util.GetGameObject(this.aniRoot, "elitemonster")
    this.fightStart = Util.GetGameObject(this.aniRoot, "fightStart")
    this.fightEnd = Util.GetGameObject(this.aniRoot, "fightEnd")

end



--绑定事件（用于子类重写）
function TrialBossTipPopup:BindEvent()

end

--添加事件监听（用于子类重写）
function TrialBossTipPopup:AddListener()

end

--移除事件监听（用于子类重写）
function TrialBossTipPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function TrialBossTipPopup:OnOpen(type)

   
    if not type or type == 1 then
        return
    end
    this.SetShow(type)

end

function this.SetShow(type)
    this.bombTip:SetActive(type == PIC_TYPE.BOMB)
    this.shopTip:SetActive(type == PIC_TYPE.SHOP)
    this.gainTip:SetActive(type == PIC_TYPE.GAIN)
    local show = type == PIC_TYPE.BOMB or type == PIC_TYPE.SHOP or type == PIC_TYPE.GAIN
    this.imgLeft:SetActive(show)
    this.imgRight:SetActive(show)
    this.mapShop:SetActive(type == PIC_TYPE.MAP_SHOP)
    this.eliteMonster:SetActive(type == PIC_TYPE.ELITE_MONSTER)
    this.fightStart:SetActive(type == PIC_TYPE.FIGHT_STRAT)
    this.fightEnd:SetActive(type == PIC_TYPE.FIGHT_END)

    -- 設置動畫
    PlayUIAnim(this.aniRoot, function ()
        Timer.New(function ()
            PlayUIAnimBack(this.aniRoot, function ()
                local timer
                timer = Timer.New(function ()
                    TrialBossTipPopup:ClosePanel()
                end, 2)
                timer:Start()
            end)
        end, 0.5):Start()
    end)
end

--界面关闭时调用（用于子类重写）
function TrialBossTipPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function TrialBossTipPopup:OnDestroy()

end

return TrialBossTipPopup