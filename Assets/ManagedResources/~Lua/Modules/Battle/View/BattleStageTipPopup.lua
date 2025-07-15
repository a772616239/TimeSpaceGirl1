require("Base/BasePanel")
local BattleStageTipPopup = Inherit(BasePanel)
local this = BattleStageTipPopup



local _StageConfig = {
    [1] = {ImgName = "r_zhandou_duiwei", title = GetLanguageStrById(10263)},
    [2] = {ImgName = "r_zhandou_jieduan01", title = GetLanguageStrById(10264)},
    [3] = {ImgName = "r_zhandou_jieduan02", title = GetLanguageStrById(10265)},
    [4] = {ImgName = "r_zhandou_jieduan03", title = GetLanguageStrById(10266)},
}

local _DeltaTime = 0.5

--初始化组件（用于子类重写）
function BattleStageTipPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.title = Util.GetGameObject(self.transform, "bgImage/Title"):GetComponent("Text")
    this.btnLeft = Util.GetGameObject(self.transform, "bgImage/left")
    this.btnRight = Util.GetGameObject(self.transform, "bgImage/right")
    this.ImgList = {
        [0] = Util.GetGameObject(self.transform, "bgImage/Image/Image_1"),
        [1] = Util.GetGameObject(self.transform, "bgImage/Image/Image_2")
    }
end

--绑定事件（用于子类重写）
function BattleStageTipPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
        if this._CloseCallBack then
            this._CloseCallBack()
        end
    end)

    Util.AddClick(this.btnLeft, function()
        this.MoveLastStage()
    end)
    Util.AddClick(this.btnRight, function()
        this.MoveNextStage()
    end)
end

--添加事件监听（用于子类重写）
function BattleStageTipPopup:AddListener()
    BattleLogic.Event:AddEvent(BattleEventName.BattleEnd, this.OnBattleEnd)
end

--移除事件监听（用于子类重写）
function BattleStageTipPopup:RemoveListener()
    BattleLogic.Event:RemoveEvent(BattleEventName.BattleEnd, this.OnBattleEnd)
end

-- 战斗结束关闭界面
function this.OnBattleEnd()
    this:ClosePanel()
    if this._CloseCallBack then
        this._CloseCallBack()
    end
end

--界面打开时调用（用于子类重写）
function BattleStageTipPopup:OnOpen(closeCB)
    this._CloseCallBack = closeCB
    this._CurStage = 1
    this._CurImgIndex = 0
    this.ImgList[this._CurImgIndex].transform.localPosition = Vector2.New(0, 0)
    this.ImgList[this._CurImgIndex]:GetComponent("Image").sprite = Util.LoadSprite(_StageConfig[this._CurStage].ImgName)
    this.ImgList[this._CurImgIndex]:GetComponent("Image").color = Color.New(1, 1, 1, 1)
    this.ImgList[(this._CurImgIndex + 1) % 2].transform.localPosition = Vector2.New(0, 0)
    this.ImgList[(this._CurImgIndex + 1) % 2]:GetComponent("Image").color = Color.New(1, 1, 1, 0)
    this.btnLeft:SetActive(this._CurStage > 1)
    this.btnRight:SetActive(this._CurStage < #_StageConfig)

    this.title.text = _StageConfig[this._CurStage].title
end

function this.SetStage(stage)
    this._CurStage = stage + 1
    this._CurImgIndex = 0
    this.ImgList[this._CurImgIndex].transform.localPosition = Vector2.New(0, 0)
    this.ImgList[this._CurImgIndex]:GetComponent("Image").sprite = Util.LoadSprite(_StageConfig[this._CurStage].ImgName)
    this.ImgList[this._CurImgIndex]:GetComponent("Image").color = Color.New(1, 1, 1, 1)
    this.ImgList[(this._CurImgIndex + 1) % 2].transform.localPosition = Vector2.New(0, 0)
    this.ImgList[(this._CurImgIndex + 1) % 2]:GetComponent("Image").color = Color.New(1, 1, 1, 0)
    this.btnLeft:SetActive(this._CurStage > 1)
    this.btnRight:SetActive(this._CurStage < #_StageConfig)
    this.title.text = _StageConfig[this._CurStage].title
end

-- 移动至下个阶段
function this.MoveNextStage()
    if this.IsMoving then return end

    if this._CurStage >= #_StageConfig then

        return
    end
    local nextStage = this._CurStage + 1
    local nextImgIndex = (this._CurImgIndex + 1) % 2
    local curImg = this.ImgList[this._CurImgIndex]
    local nextImg = this.ImgList[nextImgIndex]

    nextImg:GetComponent("Image").sprite = Util.LoadSprite(_StageConfig[nextStage].ImgName)

    this.IsMoving = true
    curImg:GetComponent("Image"):DOFade(0, _DeltaTime):SetEase(Ease.Linear)
    nextImg:GetComponent("Image"):DOFade(1, _DeltaTime):SetEase(Ease.Linear):OnComplete(function()
        this._CurImgIndex = nextImgIndex
        this._CurStage = nextStage
        this.IsMoving = false
        this.btnLeft:SetActive(this._CurStage > 1)
        this.btnRight:SetActive(this._CurStage < #_StageConfig)
        this.title.text = _StageConfig[this._CurStage].title
    end)

end

-- 移动至上个阶段
function this.MoveLastStage()
    if this.IsMoving then return end

    if this._CurStage <= 1 then

        return
    end

    local lastStage = this._CurStage - 1
    local lastImgIndex = (this._CurImgIndex + 1) % 2

    local curImg = this.ImgList[this._CurImgIndex]
    local lastImg = this.ImgList[lastImgIndex]

    lastImg:GetComponent("Image").sprite = Util.LoadSprite(_StageConfig[lastStage].ImgName)

    this.IsMoving = true
    curImg:GetComponent("Image"):DOFade(0, _DeltaTime):SetEase(Ease.Linear)
    lastImg:GetComponent("Image"):DOFade(1, _DeltaTime):SetEase(Ease.Linear):OnComplete(function()
        this._CurImgIndex = lastImgIndex
        this._CurStage = lastStage
        this.IsMoving = false
        this.btnLeft:SetActive(this._CurStage > 1)
        this.btnRight:SetActive(this._CurStage < #_StageConfig)
        this.title.text = _StageConfig[this._CurStage].title
    end)
end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BattleStageTipPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function BattleStageTipPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function BattleStageTipPopup:OnDestroy()
end

return BattleStageTipPopup