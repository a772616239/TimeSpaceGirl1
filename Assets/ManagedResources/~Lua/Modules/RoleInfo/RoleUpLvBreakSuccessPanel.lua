require("Base/BasePanel")
RoleUpLvBreakSuccessPanel = Inherit(BasePanel)
local this=RoleUpLvBreakSuccessPanel
--初始化组件（用于子类重写）
function RoleUpLvBreakSuccessPanel:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "mask")
    this.lvEndInfo=Util.GetGameObject(self.transform, "proInfo/lvEndText"):GetComponent("Text")
    this.upLvMaskPanleProAtk=Util.GetGameObject(self.transform,"proInfo/curPros/mainPro/curProVale"):GetComponent("Text")
    this.upLvMaskPanleProHp=Util.GetGameObject(self.transform,"proInfo/curPros/otherPro1/curProVale"):GetComponent("Text")
    this.upLvMaskPanleProPhyDef=Util.GetGameObject(self.transform,"proInfo/curPros/otherPro2/curProVale"):GetComponent("Text")
    this.upLvMaskPanleProSpdDef=Util.GetGameObject(self.transform,"proInfo/curPros/otherPro3/curProVale"):GetComponent("Text") --n1
    -- this.upLvMaskPanleProSpeed=Util.GetGameObject(self.transform,"proInfo/curPros/otherPro4/curProVale"):GetComponent("Text")
    this.upLvMaskPanleNextProAtk=Util.GetGameObject(self.transform,"proInfo/nextPros/mainPro/nextProVale"):GetComponent("Text")
    this.upLvMaskPanleNextProHp=Util.GetGameObject(self.transform,"proInfo/nextPros/otherPro1/nextProVale"):GetComponent("Text")
    this.upLvMaskPanleNextProPhyDef=Util.GetGameObject(self.transform,"proInfo/nextPros/otherPro2/nextProVale"):GetComponent("Text")
    this.upLvMaskPanleNextProSpdDef=Util.GetGameObject(self.transform,"proInfo/nextPros/otherPro3/nextProVale"):GetComponent("Text") --n1
    -- this.upLvMaskPanleNextProSpeed=Util.GetGameObject(self.transform,"proInfo/nextPros/otherPro4/nextProVale"):GetComponent("Text")

end

--绑定事件（用于子类重写）
function RoleUpLvBreakSuccessPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RoleUpLvBreakSuccessPanel:AddListener()

end

--移除事件监听（用于子类重写）
function RoleUpLvBreakSuccessPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RoleUpLvBreakSuccessPanel:OnOpen(...)

    local args = {...}
    local curHeroData=args[1]
    local nextHeroBreakId=args[2]
    local curHeroRankUpConfigOpenLevel=args[3]

    this.lvEndInfo.text=string.format(GetLanguageStrById(11867),string.format("<color=#ffcf2a>%s</color>",curHeroRankUpConfigOpenLevel))
    
    --计算面板属性old
    local oldLvAllAddProVal=HeroManager.CalculateHeroAllProValList(1,curHeroData.dynamicId,false)
    this.upLvMaskPanleProAtk.text=oldLvAllAddProVal[HeroProType.Attack]
    this.upLvMaskPanleProHp.text=oldLvAllAddProVal[HeroProType.Hp]
    this.upLvMaskPanleProPhyDef.text=oldLvAllAddProVal[HeroProType.PhysicalDefence]
    this.upLvMaskPanleProSpdDef.text=oldLvAllAddProVal[HeroProType.Speed] --n1
    -- this.upLvMaskPanleProSpeed.text= oldLvAllAddProVal[HeroProType.Speed]
    --计算面板属性cur
    local curLvAllAddProVal=HeroManager.CalculateHeroAllProValList(2,curHeroData.dynamicId,false,nextHeroBreakId,curHeroData.upStarId)
    this.upLvMaskPanleNextProAtk.text=curLvAllAddProVal[HeroProType.Attack]
    this.upLvMaskPanleNextProHp.text=curLvAllAddProVal[HeroProType.Hp]
    this.upLvMaskPanleNextProPhyDef.text=curLvAllAddProVal[HeroProType.PhysicalDefence]
    this.upLvMaskPanleNextProSpdDef.text=curLvAllAddProVal[HeroProType.Speed] --n1
    -- this.upLvMaskPanleNextProSpeed.text= curLvAllAddProVal[HeroProType.Speed]
end

--界面关闭时调用（用于子类重写）
function RoleUpLvBreakSuccessPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function RoleUpLvBreakSuccessPanel:OnDestroy()

end

return RoleUpLvBreakSuccessPanel