require("Base/BasePanel")
--解锁关卡弹窗
UnlockCheckpointPopup = Inherit(BasePanel)
local this=UnlockCheckpointPopup
local fightLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)

local callBack = nil
local configID
local EffectOrginLayer = 0
local curChapterId = 0
--初始化组件（用于子类重写）
function UnlockCheckpointPopup:InitComponent()

    EffectOrginLayer = 0
    this.infoText=Util.GetGameObject(self.transform,"UI_effect_UnlockCheckpoint/banzi/InfoText"):GetComponent("Text")
    this.checkImage=Util.GetGameObject(self.transform,"UI_effect_UnlockCheckpoint/banzi/Checkpoint/Checkpoint"):GetComponent("Image")
    this.checkDiffImage=Util.GetGameObject(self.transform,"UI_effect_UnlockCheckpoint/banzi/Image/nandu"):GetComponent("Image")
    this.closeBtn=Util.GetGameObject(self.transform,"CloseBtn")
    this.btnGo=Util.GetGameObject(self.transform,"btnGo")
    this.effect_qian = Util.GetGameObject(self.transform,"UI_effect_UnlockCheckpoint/effect_qian")
    effectAdapte(Util.GetGameObject(this.effect_qian, "ziti mask"))
end
--绑定事件（用于子类重写）
function UnlockCheckpointPopup:BindEvent()

    Util.AddClick(this.closeBtn, function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.FightPointPassMainPanel, function() 
            -- 章节解锁时添加对话
            StoryManager.EventTrigger(curChapterId)
        end)
    end)
    Util.AddClick(this.btnGo, function()
        self:ClosePanel()
        --JumpManager.GoJump(26078)
        UIManager.OpenPanel(UIName.FightPointPassMainPanel, function() 
            -- 章节解锁时添加对话
            StoryManager.EventTrigger(curChapterId)
        end)
    end)
end

--添加事件监听（用于子类重写）
function UnlockCheckpointPopup:AddListener()

end

--移除事件监听（用于子类重写）
function UnlockCheckpointPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function UnlockCheckpointPopup:OnOpen(_configID,_callBack)

    configID = _configID
    callBack = _callBack
    local chapterId = math.floor(FightPointPassManager.lastPassFightId / 1000)

    curChapterId = fightLevelConfig[chapterId].EventId

    
end

function UnlockCheckpointPopup:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect_qian, self.sortingOrder - EffectOrginLayer)
    EffectOrginLayer = self.sortingOrder
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function UnlockCheckpointPopup:OnShow()

    local areaId=math.floor(configID/1000)
    local diff = configID%10
    local LevelSettingConFig = ConfigManager.GetConfigData(ConfigName.MainLevelSettingConfig,areaId)
    if LevelSettingConFig then
        this.checkImage.sprite = Util.LoadSprite(LevelSettingConFig.ChapterBg)
        this.checkImage:SetNativeSize()
        this.checkDiffImage.sprite = Util.LoadSprite(FightDifficultyStateZiSp[diff])
        local str = LevelSettingConFig.Name.."·"..NumToComplexFont[areaId]
        this.infoText.text = str--string.gsub(str,"-","\n-\n")
    end
    if UIManager.IsOpen(UIName.BattlePanel) then
        this.btnGo:SetActive(false)
    else
        this.btnGo:SetActive(true)
    end
end

--界面关闭时调用（用于子类重写）
function UnlockCheckpointPopup:OnClose()

    FightManager.isOpenLevelPat = false
    if callBack then
        callBack()
    end
    callBack = nil
end

--界面销毁时调用（用于子类重写）
function UnlockCheckpointPopup:OnDestroy()

end

return UnlockCheckpointPopup