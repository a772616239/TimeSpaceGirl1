require("Base/BasePanel")
FightLevelSwitchPopup = Inherit(BasePanel)
local this = FightLevelSwitchPopup
local fightAnimRes = "live2d_guaji_yuguai"
local fightLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)

local fightSkeleton
local count = 1
local isAnimActive = false
local chooseAnim = 0

local fightAnim = {
    [2] = "diban",
    [3] = "xiaoguai",
    [4] = "bnoss",
    [1] = "idle",
}


--初始化组件（用于子类重写）
function FightLevelSwitchPopup:InitComponent()
    isAnimActive = false
    this.switchPanel = Util.GetGameObject(self.gameObject, "SwitchAnim")
    this.fightInfoRoot = Util.GetGameObject(self.gameObject, "Image")
    this.fightText = Util.GetGameObject(this.fightInfoRoot, "info"):GetComponent("Text")

    this.animGo = poolManager:LoadLive(fightAnimRes, this.switchPanel.transform, Vector3.one, Vector3.one)
    fightSkeleton = this.animGo:GetComponent("SkeletonGraphic")

    local idle = function()
    if not isAnimActive then return end
        if count == 2 then

        else
            fightSkeleton.AnimationState:SetAnimation(0, fightAnim[chooseAnim], false)
            count = count + 1

            this.animTimer = nil
            this.animTimer = Timer.New(function ()
                isAnimActive = false
                count = 1
                fightSkeleton.AnimationState:SetAnimation(0, fightAnim[1], false)
                this.SetAnimPanelState(false)
                
                UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.STORY, FightPointPassManager.curOpenFight)
                --- Spine动画在播放过程中所依赖的物体被隐藏，此时动画机会中断，再次激活时会先继续播放上次的动画
                --- 然后再执行当前设置的动画，idle动画0.33秒放完

                self:InitAnimation()
            end, 1)
            this.animTimer:Start()

            -- 第一个动画播放完毕之后
            local isBoss = FightPointPassManager.IsFightBoss()
            this.PlayInfoAnim(false, isBoss)
            local sound = isBoss and SoundConfig.Sound_FightArea_Boss or SoundConfig.Sound_FightArea_Monster
            SoundManager.PlaySound(sound, AUDIO_FADE_TYPE.FADE_OUT_NOT_IN, AUDIO_RUN_TYPE.CONC, nil, 20)
        end
    end
    
    fightSkeleton.AnimationState.Complete = fightSkeleton.AnimationState.Complete + idle
    poolManager:SetLiveClearCall(fightAnimRes, this.animGo, function()
        fightSkeleton.AnimationState.Complete = fightSkeleton.AnimationState.Complete - idle
    end)

end


function this.SetAnimPanelState(isShow)
    local offset = isShow and 0 or 2000
    this.switchPanel.transform.localPosition = Vector3.New(offset, 0, 0 )
end

--绑定事件（用于子类重写）
function FightLevelSwitchPopup:BindEvent()

end

--添加事件监听（用于子类重写）
function FightLevelSwitchPopup:AddListener()

end

--移除事件监听（用于子类重写）
function FightLevelSwitchPopup:RemoveListener()

end

function FightLevelSwitchPopup:OnOpen(playAni)
    if playAni then 
        this.PlayInfoAnim(true, false)
        count = 1
        local curName = fightLevelConfig[FightPointPassManager.curOpenFight].Name

        this.fightText.text = curName
        this.switchPanel:SetActive(true)
        this.SetAnimPanelState(true)
        fightSkeleton.AnimationState:SetAnimation(0, fightAnim[2], false)
        isAnimActive = true
        local isBoss = FightPointPassManager.IsFightBoss()
        chooseAnim = isBoss and 4 or 3
    end
end



-- 小怪 258 boss 570
-- 播放那个动画
function this.PlayInfoAnim(isInit, isBoss)
    if isInit then
        this.fightInfoRoot.transform.localPosition = Vector3.New(0, -187, 0)
        this.fightInfoRoot:SetActive(false)
    else
        this.fightInfoRoot:SetActive(true)
        local targetPos = Vector3.zero
        targetPos = isBoss and Vector3.New(0, 570, 0) or Vector3.New(0, 288, 0)
        this.fightInfoRoot:GetComponent("RectTransform"):DOAnchorPos(targetPos, 0.3, false):OnComplete(function ()
        end)

        this.fightInfoRoot:GetComponent("Image"):DOFade(1, 0.3):OnComplete(function ()

        end)
    end
end

function this:InitAnimation()
    UIManager.OpenPanel(UIName.FightLevelSwitchPopup, false)
    Timer.New(function() 
        UIManager.ClosePanel(UIName.FightLevelSwitchPopup)
    end, 0.33):Start()
end

--界面打开时调用（用于子类重写）
function FightLevelSwitchPopup:OnShow(...)
    
end

function FightLevelSwitchPopup:OnSortingOrderChange()

end

--界面关闭时调用（用于子类重写）
function FightLevelSwitchPopup:OnClose()
    this.PlayInfoAnim(true, false)
end

--界面销毁时调用（用于子类重写）
function FightLevelSwitchPopup:OnDestroy()
    poolManager:UnLoadLive(fightAnimRes, this.animGo, PoolManager.AssetType.GameObject)


end

return FightLevelSwitchPopup