require("Base/BasePanel")
FightMiddleChoosePanel = Inherit(BasePanel)
local mainLevelSettingConfig = ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)
local orginLayer
local mapGO = {}
local index = 0
local difficulBtnGO = {}

local curSmallFightId = 0
local curMiddleFightId =0
local difficultType = FightDifficultyState.SimpleLevel
local difficultImage={[1] = "m5_img_touming",[2] = "m5_img_zhangjie_tiaozhan",[3] = "m5_img_zhangjie_kunnan",[4] = "m5_img_zhangjie_diyu",
                      [5] = "m5_img_zhangjie_emeng",}
-- 小地图
local fightMap = require("Modules/Fight/View/FightMiddleChooseMapView")
local isPlayAni = false
local func  = nil
--初始化组件（用于子类重写）
function FightMiddleChoosePanel:InitComponent()

    fightMap:InitComponent(self.gameObject)
    --self.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    orginLayer = 0
    self.btnBack = Util.GetGameObject(self.gameObject, "mapParent/btnBack")
    self.tialeImage = Util.GetGameObject(self.gameObject, "mapParent/tialeImage"):GetComponent("Image")
    self.effect = Util.GetGameObject(self.gameObject, "UI_effect_FightMiddleChoosePanel_cloud")
end

--绑定事件（用于子类重写）
function FightMiddleChoosePanel:BindEvent()

    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
end
function FightMiddleChoosePanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end
--界面打开时调用（用于子类重写）
function FightMiddleChoosePanel:OnOpen(smallFightId,_isPlayAni,_func)

    isPlayAni = _isPlayAni or false
    func = _func
    curSmallFightId = smallFightId
    curMiddleFightId = math.floor(smallFightId/1000)
    difficultType = smallFightId%10
    if isPlayAni then
        self.btnBack:GetComponent("Button").enabled=false
    end
    --self.upView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    SoundManager.PlaySound(SoundConfig.Sound_WorldMap)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightMiddleChoosePanel:OnShow()

    -- 加载地图数据
    fightMap:Init(curSmallFightId,isPlayAni,self)
    self:OnRefreshMiddleClick()
    self.tialeImage.sprite = Util.LoadSprite(difficultImage[difficultType])
end
function FightMiddleChoosePanel:OnRefreshBackClick()
    self.btnBack:GetComponent("Button").enabled=true
end
function FightMiddleChoosePanel:OnRefreshMiddleClick()

    for i = 1, FightPointPassManager.maxChapterNum do
        fightMap.AddPointFunc(i, function ()
            local ChapterSate = FightPointPassManager.GetDifficultAndChapter(difficultType,i)
            if ChapterSate == SingleFightState.Pass then
                if not FightPointPassManager.IsChapterClossState() and i == curMiddleFightId then--是否播放章节状态   特殊判断
                    UIManager.OpenPanel(UIName.FightPointPassMainPanel)
                else
                    PopupTipPanel.ShowTipByLanguageId(10580)
                end
            elseif  ChapterSate == SingleFightState.NoPass or  ChapterSate == SingleFightState.Open then
                if not FightPointPassManager.IsChapterClossState() and i == math.floor(FightPointPassManager.curOpenFight/1000) then--是否播放章节状态   特殊判断
                    PopupTipPanel.ShowTipByLanguageId(10581)
                else
                    UIManager.OpenPanel(UIName.FightPointPassMainPanel)
                end
            elseif  ChapterSate == SingleFightState.NoOpen then
                PopupTipPanel.ShowTipByLanguageId(10581)
            end
        end)
    end
end
--界面关闭时调用（用于子类重写）
function FightMiddleChoosePanel:OnClose()

    fightMap:Dispose()
    if func then
        func()
        func = nil
    end
end

--界面销毁时调用（用于子类重写）
function FightMiddleChoosePanel:OnDestroy()

end

return FightMiddleChoosePanel