require("Base/BasePanel")
RoleTalismanChangePopup = Inherit(BasePanel)
local this=RoleTalismanChangePopup
local type--1 穿装备  2 卸装备 3 替换装备
local curHeroData
local curEquipData
local nextEquipData
local openThisPanel
--初始化组件（用于子类重写）
function RoleTalismanChangePopup:InitComponent()

    this.btnBack= Util.GetGameObject(self.transform, "btnBack")

    this.bg1= Util.GetGameObject(self.transform, "GameObject/bg1")
    this.desc1= Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/Text"):GetComponent("Text")
    this.curEquipName=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/name/text"):GetComponent("Text")
    this.curEquipFrame=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/frame"):GetComponent("Image")
    this.curEquipIcon=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/icon"):GetComponent("Image")
    this.curEquipStar=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/star/starGrid")
    this.curMainProscroll=Util.GetGameObject(self.transform, "GameObject/bg1/mainProScroll")
    this.curMainProGrid=Util.GetGameObject(self.transform, "GameObject/bg1/mainProScroll/grid")
    this.curotherProscroll=Util.GetGameObject(self.transform, "GameObject/bg1/otherProScroll")
    this.otherProPre=Util.GetGameObject(self.transform, "GameObject/bg1/otherPro")
    this.otherProGrid=Util.GetGameObject(self.transform, "GameObject/bg1/otherProScroll/grid")
    this.curCastInfo=Util.GetGameObject(self.transform, "GameObject/bg1/castInfoObject/castInfo"):GetComponent("Text")
    this.castInfoObject=Util.GetGameObject(self.transform, "GameObject/bg1/castInfoObject")
    this.castInfoObject:SetActive(false)
    this.curEquipBtnDown=Util.GetGameObject(self.transform, "GameObject/bg1/btns/btnGrid/btnDown")
    this.curEquipBtnUp=Util.GetGameObject(self.transform, "GameObject/bg1/btns/btnGrid/btnUp")
    this.curEquipBtnUpStar=Util.GetGameObject(self.transform, "GameObject/bg1/btns/btnGrid/btnUpStar")
    this.curEquipText=Util.GetGameObject(self.transform, "GameObject/bg1/btns/curEquipText")
    this.qualityText=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/qualityText"):GetComponent("Text")
    this.powerNum1=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/powerNum"):GetComponent("Text")
    this.powerUPorDown1=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/powerUPorDown")

    this.bg2= Util.GetGameObject(self.transform, "GameObject/bg2")
    this.desc2= Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/Text"):GetComponent("Text")
    this.nextEquipName=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/name/text"):GetComponent("Text")
    this.nextEquipFrame=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/frame"):GetComponent("Image")
    this.nextEquipIcon=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/icon"):GetComponent("Image")
    this.nextEquipStar=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/star/starGrid")
    this.nextMainProscroll=Util.GetGameObject(self.transform, "GameObject/bg2/mainProScroll")
    this.nextMainProGrid=Util.GetGameObject(self.transform, "GameObject/bg2/mainProScroll/grid")
    this.nexttherProscroll=Util.GetGameObject(self.transform, "GameObject/bg2/otherProScroll")
    this.nextotherProPre=Util.GetGameObject(self.transform, "GameObject/bg2/otherPro")
    this.nextotherProGrid=Util.GetGameObject(self.transform, "GameObject/bg2/otherProScroll/grid")
    this.nextCastInfo=Util.GetGameObject(self.transform, "GameObject/bg2/castInfoObject/castInfo"):GetComponent("Text")
    this.nextInfoObject=Util.GetGameObject(self.transform, "GameObject/bg2/castInfoObject")
    this.nextInfoObject:SetActive(false)
    this.nextEtnChange=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnGrid/btnChange")
    this.nextEquipUpStar=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnGrid/btnUpStar")
    this.qualityText2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/qualityText"):GetComponent("Text")
    this.GameObject=Util.GetGameObject(self.transform, "GameObject")
    this.powerNum2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/powerNum"):GetComponent("Text")
    this.powerUPorDown2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/powerUPorDown")
end

--绑定事件（用于子类重写）
function RoleTalismanChangePopup:BindEvent()

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.curEquipBtnDown, function()
        NetManager.TalismanUnLoadOptRequest(curHeroData.dynamicId, {curEquipData.did}, function ()
            TalismanManager.SetTalismanUpHeroDid(curEquipData.did,"0")
            HeroManager.UpdateHeroSingleTalismanData(curHeroData.dynamicId,{curEquipData.did},2)
            openThisPanel:OnShowHeroAndTalisman()
            self:ClosePanel()
        end)
    end)
    Util.AddClick(this.curEquipBtnUp, function()
        NetManager.TalismanWearRequest(curHeroData.dynamicId, {curEquipData.did}, function ()
            TalismanManager.SetTalismanUpHeroDid(curEquipData.did,curHeroData.dynamicId)
            HeroManager.UpdateHeroSingleTalismanData(curHeroData.dynamicId,{curEquipData.did},1)
            openThisPanel:OnShowHeroAndTalisman()
            self:ClosePanel()
        end)
    end)
    Util.AddClick(this.nextEtnChange, function()
        NetManager.TalismanWearRequest(curHeroData.dynamicId, {nextEquipData.did}, function ()
            TalismanManager.SetTalismanUpHeroDid(curEquipData.did,"0")
            TalismanManager.SetTalismanUpHeroDid(nextEquipData.did,curHeroData.dynamicId)
            HeroManager.UpdateHeroSingleTalismanData(curHeroData.dynamicId,{nextEquipData.did},1)
            openThisPanel:OnShowHeroAndTalisman()
            self:ClosePanel()
        end)
    end)
    Util.AddClick(this.curEquipBtnUpStar, function()
        UIManager.OpenPanel(UIName.TalismanInfoPanel,curHeroData,curEquipData)
        self:ClosePanel()
    end)
    Util.AddClick(this.nextEquipUpStar, function()
        UIManager.OpenPanel(UIName.TalismanInfoPanel,curHeroData,nextEquipData)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RoleTalismanChangePopup:AddListener()

end

--移除事件监听（用于子类重写）
function RoleTalismanChangePopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RoleTalismanChangePopup:OnOpen(...)

    local data={...}
    openThisPanel=data[1]
    type=data[2]
    if type==1 or  type==2 then
        curHeroData=data[3]
        curEquipData=data[4]
    elseif type==3 then
        curHeroData=data[3]
        curEquipData=data[4]
        nextEquipData=data[5]
    end
end
function RoleTalismanChangePopup:OnShow()
    if type==1 then
        this.curEquipBtnUpStar:SetActive(curEquipData.star < TalismanManager.AllTalismanEndStar[curEquipData.id])
        this.curEquipText:SetActive(false)
        this.curEquipBtnDown:SetActive(false)
        this.curEquipBtnUp:SetActive(true)
        this.ShowCurEquipData(1)
        this.bg1:SetActive(true)
        this.bg2:SetActive(false)
    elseif type==2 then
        this.curEquipBtnUpStar:SetActive(curEquipData.star < TalismanManager.AllTalismanEndStar[curEquipData.id])
        this.curEquipText:SetActive(false)
        this.curEquipBtnDown:SetActive(true)
        this.curEquipBtnUp:SetActive(false)
        this.ShowCurEquipData(1)
        this.bg1:SetActive(true)
        this.bg2:SetActive(false)
    elseif type==3 then
        this.curEquipBtnUpStar:SetActive(false)
        this.nextEquipUpStar:SetActive(nextEquipData.star < TalismanManager.AllTalismanEndStar[nextEquipData.id])
        this.curEquipText:SetActive(true)
        this.curEquipBtnDown:SetActive(false)
        this.curEquipBtnUp:SetActive(false)
        this.ShowCurEquipData(2)
        this.NextCurEquipData()
        this.bg1:SetActive(true)
        this.bg2:SetActive(true)
    end
end
function this.ShowCurEquipData(index)
    local curWarForce = TalismanManager.CalculateWarForce(curEquipData.did,0)
    this.powerNum1.text = curWarForce
    this.desc1.text=curEquipData.itemConfig.ItemDescribe
    this.powerUPorDown1:SetActive(false)
    if(nextEquipData~=nil and index==2) then
        local nextWarForce = TalismanManager.CalculateWarForce(nextEquipData.did,0)
        if nextWarForce < curWarForce then
            this.powerUPorDown1:SetActive(true)
            this.powerUPorDown1:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[1])
        end
        if nextWarForce > curWarForce then
            this.powerUPorDown1:SetActive(true)
            this.powerUPorDown1:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[2])
        end
    end
    this.qualityText.text=GetStringByEquipQua(curEquipData.itemConfig.Quantity,GetQuaStringByEquipQua(curEquipData.itemConfig.Quantity))
    this.curEquipName.text=GetStringByEquipQua(curEquipData.itemConfig.Quantity,curEquipData.itemConfig.Name)
    this.curEquipFrame.sprite = Util.LoadSprite(curEquipData.frame)
    this.curEquipIcon.sprite = Util.LoadSprite(curEquipData.icon)
    SetHeroStars(this.curEquipStar, curEquipData.star)

    local curTalismanConFigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId", curEquipData.id, "Level", curEquipData.star)
    if curTalismanConFigData.OpenSkillRules[1] > 0 then
        this.castInfoObject.gameObject:SetActive(true)
        local cfg=ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, curTalismanConFigData.OpenSkillRules[1])
        this.curCastInfo.text=GetSkillConfigDesc(cfg)
    else
        this.curCastInfo.text=""
        this.castInfoObject.gameObject:SetActive(false)
    end
    --主属性
    Util.ClearChild(this.curMainProGrid.transform)
    if #curTalismanConFigData.Property>0 then --
        this.curMainProscroll:SetActive(true)
        for i = 1, #curTalismanConFigData.Property do
            local go = newObject(this.otherProPre)
            go.transform:SetParent(this.curMainProGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,curTalismanConFigData.Property[i][1])
            if proConFig then
                Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text =proConFig.Info
                Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "+"..GetEquipPropertyFormatStr(proConFig.Style,curTalismanConFigData.Property[i][2])
            end
        end
    else
        this.curMainProscroll:SetActive(false)
    end
    --副属性
    Util.ClearChild(this.otherProGrid.transform)
    if curTalismanConFigData.SpecialProperty and #curTalismanConFigData.SpecialProperty>0 then --
        this.curotherProscroll:SetActive(true)
        for i = 1, #curTalismanConFigData.SpecialProperty do
            local go = newObject(this.otherProPre)
            go.transform:SetParent(this.otherProGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,curTalismanConFigData.SpecialProperty[i][2])
            if proConFig then
                Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text =proConFig.Info.."("..HeroOccupationDef[curTalismanConFigData.SpecialProperty[i][1]]..")"
                Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "+"..GetEquipPropertyFormatStr(proConFig.Style,curTalismanConFigData.SpecialProperty[i][3])
            end
        end
    else
        this.curotherProscroll:SetActive(false)
    end

end
function this.NextCurEquipData()
    this.powerNum2.text=TalismanManager.CalculateWarForce(nextEquipData.did,0)
    this.powerUPorDown2:SetActive(false)
    if(TalismanManager.CalculateWarForce(nextEquipData.did,0)>TalismanManager.CalculateWarForce(curEquipData.did,0)) then
        this.powerUPorDown2:SetActive(true)
        this.powerUPorDown2:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[1])
    end
    if(TalismanManager.CalculateWarForce(nextEquipData.did,0)<TalismanManager.CalculateWarForce(curEquipData.did,0)) then
        this.powerUPorDown2:SetActive(true)
        this.powerUPorDown2:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[2])
    end
    this.qualityText2.text=GetStringByEquipQua(nextEquipData.itemConfig.Quantity,GetQuaStringByEquipQua(nextEquipData.itemConfig.Quantity))
    this.nextEquipName.text=GetStringByEquipQua(nextEquipData.itemConfig.Quantity,nextEquipData.itemConfig.Name)
    this.desc2.text=nextEquipData.itemConfig.ItemDescribe
    this.nextEquipFrame.sprite = Util.LoadSprite(nextEquipData.frame)
    this.nextEquipIcon.sprite = Util.LoadSprite(nextEquipData.icon)
    SetHeroStars(this.nextEquipStar, nextEquipData.star)




    local nextTalismanConFigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId", nextEquipData.id, "Level", nextEquipData.star) --
    if nextTalismanConFigData.OpenSkillRules[1] >0 then
        this.nextInfoObject.gameObject:SetActive(true)
        local cfg=ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, nextTalismanConFigData.OpenSkillRules[1])
        this.nextCastInfo.text=GetSkillConfigDesc(cfg)
    else
        this.nextCastInfo.text=""
        this.nextInfoObject.gameObject:SetActive(false)
    end
    --主属性
    Util.ClearChild(this.nextMainProGrid.transform)
    if #nextTalismanConFigData.Property>0 then --
        this.nextMainProscroll:SetActive(true)
        for i = 1, #nextTalismanConFigData.Property do
            local go = newObject(this.otherProPre)
            go.transform:SetParent(this.nextMainProGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,nextTalismanConFigData.Property[i][1])
            if proConFig then
                Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text =proConFig.Info
                Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "+"..GetEquipPropertyFormatStr(proConFig.Style,nextTalismanConFigData.Property[i][2])
            end
        end
    else
        this.nextMainProscroll:SetActive(false)
    end
    --副属性
    Util.ClearChild(this.nextotherProGrid.transform)
    if nextTalismanConFigData.SpecialProperty and #nextTalismanConFigData.SpecialProperty>0 then --
        this.nexttherProscroll:SetActive(true)
        for i = 1, #nextTalismanConFigData.SpecialProperty do
            local go = newObject(this.otherProPre)
            go.transform:SetParent(this.nextotherProGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,nextTalismanConFigData.SpecialProperty[i][2])
            if proConFig then
                Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text =proConFig.Info.."("..HeroOccupationDef[nextTalismanConFigData.SpecialProperty[i][1]]..")"
                Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "+"..GetEquipPropertyFormatStr(proConFig.Style,nextTalismanConFigData.SpecialProperty[i][3])
            end
        end
    else
        this.nexttherProscroll:SetActive(false)
    end
end
--界面关闭时调用（用于子类重写）
function RoleTalismanChangePopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function RoleTalismanChangePopup:OnDestroy()

end

return RoleTalismanChangePopup