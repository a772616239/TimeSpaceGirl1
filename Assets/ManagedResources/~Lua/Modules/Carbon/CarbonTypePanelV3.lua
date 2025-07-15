require("Base/BasePanel")
CarbonTypePanelV3 = Inherit(BasePanel)
local this = CarbonTypePanelV3
local hasFresh = false
local orginLayer = 0
--初始化组件（用于子类重写）
function CarbonTypePanelV3:InitComponent()

    this.btnSenro = Util.GetGameObject(self.gameObject, "btnRoot/circle/root/DailyCarbonBtn")   -- 森罗
    this.btnXuanyuan = Util.GetGameObject(self.gameObject, "btnRoot/circle/root/eliteRoot")    -- 轩辕
    Util.GetGameObject(self.gameObject, "btnRoot/circle/root/normalRoot"):SetActive(false) 
    Util.GetGameObject(self.gameObject, "btnRoot/circle/root/trialRoot"):SetActive(false) 

    this.effect = Util.GetGameObject(self.gameObject, "CarbonTypePanel_effect")
    this.wind = Util.GetGameObject(self.gameObject, "CarbonTypePanel_effect/juneng_chenggong/GameObject")

    orginLayer = 0

    --头像、战力
    this.level = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/headBox/lvFrame/lv"):GetComponent("Text")
    this.playName = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/headBox/name"):GetComponent("Text")
    this.expSliderValue = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/headBox/exp"):GetComponent("Slider")
    this.headBox = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/headBox")
    this.headPos = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/headBox/headpos")
    this.headRedpot = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/headBox/redpot")
    this.teamPower = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/powerBtn/value"):GetComponent("Text")
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    -- 特权
    this.vipPrivilegeBtn = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/vipPrivilege/vipPrivilegeBtn")
    this.vipLevelText = Util.GetGameObject(this.vipPrivilegeBtn, "bg/vip"):GetComponent("Image")
    this.vipRedPoint = Util.GetGameObject(self.gameObject, "BgRoot/LeftUp/vipPrivilege/redPoint")
    screenAdapte(this.vipPrivilegeBtn)

    this.AnimRoot = Util.GetGameObject(self.gameObject, "btnRoot/circle/root")
end


local index = 1
--绑定事件（用于子类重写）
function CarbonTypePanelV3:BindEvent()
    BindRedPointObject(RedPointType.VipPrivilege, this.vipRedPoint)

    -- 森罗
    Util.AddClick(this.btnSenro, function()
        
    end)

    -- 轩辕
    Util.AddClick(this.btnXuanyuan, function()
        UIManager.OpenPanel(UIName.XuanYuanMirrorPanel)     
    end)

    Util.AddClick(this.headBox, function ()
        UIManager.OpenPanel(UIName.SettingPanel)
    end)
    BindRedPointObject(RedPointType.Setting, this.headRedpot)

    Util.AddClick(this.vipPrivilegeBtn, function()
        UIManager.OpenPanel(UIName.VipPanelV2)
    end)
end

function CarbonTypePanelV3:OnOpen()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
end

--界面打开时调用（用于子类重写）
function CarbonTypePanelV3:OnShow(...)
    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)
    -- 播放动画

    this.FreshPlayerInfo()
    this.SetPlayerHead()
    this.PlayScaleAnim()
end

-- 刷新玩家信息显示
function this.FreshPlayerInfo()
    this.vipLevelText.sprite = VipManager.SetVipLevelImg()
    this.level.text = PlayerManager.level
    this.expSliderValue.value = PlayerManager.exp / PlayerManager.userLevelData[PlayerManager.level].Exp
    this.playName.text = PlayerManager.nickName
    this.teamPower.text = FormationManager.GetFormationPower(FormationManager.curFormationIndex)
end

-- 设置头像
function this.SetPlayerHead()
    if not this.playerHead then
        this.playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.headPos.transform)
    end
    this.playerHead:SetHead(PlayerManager.head)
    this.playerHead:SetFrame(PlayerManager.frame)
    this.playerHead:SetScale(Vector3.one * 0.9)
    this.playerHead:SetPosition(Vector3.New(-5, 0, 0))

end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.wind, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.vipPrivilegeBtn, self.sortingOrder - orginLayer)

    orginLayer = self.sortingOrder
end

function this.PlayScaleAnim()
    local isOpen = FunctionOpenMananger.GetRootState(PanelTypeView.Carbon)
    if isOpen then
        PlayUIAnim(this.AnimRoot)
    else
        PlayUIAnimBack(this.AnimRoot)
    end
end

--界面关闭时调用（用于子类重写）
function CarbonTypePanelV3:OnClose()
end

--界面销毁时调用（用于子类重写）
function CarbonTypePanelV3:OnDestroy()  
    hasFresh = false
    SubUIManager.Close(this.UpView)
end

return CarbonTypePanelV3