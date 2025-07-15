require("Base/BasePanel")
CompoundSelectListPopup = Inherit(BasePanel)
local this = CompoundSelectListPopup
local curSelectSoulPrint = {}
local curSelectAllSoulPrintIds = {}
local curSelectAllSoulPrint = {}
local targetSoulPrintSData = {}
local curIndex = 0
local openThisPanel
local equipSign = ConfigManager.GetConfig(ConfigName.EquipConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local curSelectGO
local isShowGou = false
--初始化组件（用于子类重写）
function CompoundSelectListPopup:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.BtnSure = Util.GetGameObject(self.transform, "btnSure")
    this.btnSelect = Util.GetGameObject(self.transform, "btnSelect")
    this.btnSelectImage = Util.GetGameObject(self.transform, "btnSelect/SelectImage")
    this.cardPre = Util.GetGameObject(self.gameObject, "equipPre")

    this.Scrollbar= Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,Util.GetGameObject(self.gameObject, "scroll").transform,
            this.cardPre, this.Scrollbar, Vector2.New(927.5, 1010), 1, 5, Vector2.New(19.32,15))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(6.78, 27)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function CompoundSelectListPopup:BindEvent()
    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BtnSure, function()
        self:ClosePanel()
        openThisPanel.UpdateCompoundPanel_SoulPrint(curSelectSoulPrint,curIndex)
    end)
    Util.AddClick(this.btnSelect, function()
        local isShowUpHero = SoulPrintManager.GetIsShowUpHeroSoulPrintPlayerPrefs()
        if tostring(isShowUpHero) == "0" then
            SoulPrintManager.SetIsShowUpHeroSoulPrintPlayerPrefs(1)
            this.btnSelectImage:SetActive(true)
        else
            SoulPrintManager.SetIsShowUpHeroSoulPrintPlayerPrefs(0)
            this.btnSelectImage:SetActive(false)
        end
        this.OnShowData()
    end)
end

--添加事件监听（用于子类重写）
function CompoundSelectListPopup:AddListener()
end

--移除事件监听（用于子类重写）
function CompoundSelectListPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function CompoundSelectListPopup:OnOpen(_openThisPanel,_curSelectAllSoulPrint,_curIndex,_targetSoulPrintSData)
    openThisPanel = _openThisPanel
    curSelectSoulPrint = _curSelectAllSoulPrint[_curIndex].equipSignConFig
    curSelectAllSoulPrint = _curSelectAllSoulPrint
    curIndex = _curIndex
    targetSoulPrintSData = _targetSoulPrintSData
    isShowGou = false
    curSelectGO = nil
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function CompoundSelectListPopup:OnShow()
    this.OnShowData()
end
function this.OnShowData()
    local isShowUpHero = SoulPrintManager.GetIsShowUpHeroSoulPrintPlayerPrefs()
    this.btnSelectImage:SetActive(tostring(isShowUpHero) == "1")
    local allBagSoulPrintDatas = SoulPrintManager.GetAllSoulPrint(tostring(isShowUpHero) == "1")
    local curBagSoulPrintDatas = {}
    for i = 1, #curSelectAllSoulPrint do
        if curSelectAllSoulPrint[i].state and i ~= _curIndex then
            if curSelectAllSoulPrintIds[curSelectAllSoulPrint[i].equipSignConFig.Id] then
                curSelectAllSoulPrintIds[curSelectAllSoulPrint[i].equipSignConFig.Id] = curSelectAllSoulPrintIds[curSelectAllSoulPrint[i].equipSignConFig.Id] + 1
            else
                curSelectAllSoulPrintIds[curSelectAllSoulPrint[i].equipSignConFig.Id] = 1
            end
        end
    end
    for i = 1, #allBagSoulPrintDatas do
        if equipSign[allBagSoulPrintDatas[i].id].Quality == targetSoulPrintSData.Formula[1][1] then
            if curSelectAllSoulPrintIds[allBagSoulPrintDatas[i].id] and curSelectAllSoulPrintIds[allBagSoulPrintDatas[i].id] > 0
                    and allBagSoulPrintDatas[i].upHero == ""  then
                curSelectAllSoulPrintIds[allBagSoulPrintDatas[i].id] = curSelectAllSoulPrintIds[allBagSoulPrintDatas[i].id] - 1
            else
                table.insert(curBagSoulPrintDatas,allBagSoulPrintDatas[i])
            end
        end
    end
    table.sort(curBagSoulPrintDatas, function(a,b) return a.id < b.id end)
    this.ScrollView:SetData(curBagSoulPrintDatas, function (index, go)
        this.SingleItemDataShow(go, curBagSoulPrintDatas[index])
    end)
    this.ShowSUreBtnState()
end
function this.SingleItemDataShow(_go,curBagSoulPrintData)
    local curequipSign = equipSign[curBagSoulPrintData.id]
    Util.GetGameObject(_go.transform,"frame"):GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByquality(curequipSign.Quality))
    --Util.GetGameObject(_go.transform,"icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(itemConfig[curBagSoulPrintData.id].ResourceID))
    Util.GetGameObject(_go.transform,"circleFrameBg"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[curequipSign.Id].Quantity].circleBg2)
    Util.GetGameObject(_go.transform,"circleFrameBg/Icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(itemConfig[curBagSoulPrintData.id].ResourceID))
    Util.GetGameObject(_go.transform,"circleFrameBg/circleFrame"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[curequipSign.Id].Quantity].circle)
    Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text=curequipSign.Name
    Util.GetGameObject(_go.transform, "Hero"):SetActive(curBagSoulPrintData.upHero ~= "")
    local curheroData = {}
    if curBagSoulPrintData.upHero ~= "" then
        curheroData = HeroManager.GetSingleHeroData(curBagSoulPrintData.upHero)
        if curheroData then
            Util.GetGameObject(_go.transform,"Hero/Icon"):GetComponent("Image").sprite=Util.LoadSprite(curheroData.icon)
        end
    end
    local choosed =Util.GetGameObject(_go.transform, "choosed")
    choosed:SetActive(curSelectSoulPrint.Id == curBagSoulPrintData.id and not isShowGou)
    --local redPoint =  Util.GetGameObject(_go.transform,"redPoint")
    if curSelectSoulPrint.Id == curBagSoulPrintData.id  and not isShowGou then
        curSelectGO = _go
        isShowGou = true
    end
    Util.AddLongPressClick(Util.GetGameObject(_go.transform,"frame"), function()
        UIManager.OpenPanel(UIName.SoulPrintPopUp,0,nil,curBagSoulPrintData.id,nil,nil)
    end, 0.5)
    Util.AddOnceClick(Util.GetGameObject(_go.transform,"frame"), function()
        if curBagSoulPrintData.upHero ~= "" then
            MsgPanel.ShowTwo(GetLanguageStrById(10424).. GetLanguageStrById(curheroData.heroConfig.ReadingName) ..GetLanguageStrById(10425)..curequipSign.Name ..GetLanguageStrById(10426), function ()
                return
            end , function()
                local pos = 0
                for i = 1, #curheroData.soulPrintList do
                    if curheroData.soulPrintList[i].equipId == curBagSoulPrintData.id then
                        pos = curheroData.soulPrintList[i].position
                    end
                end
                NetManager.SoulEquipUnLoadWearRequest(curBagSoulPrintData.upHero, curBagSoulPrintData.id,pos,function(msg)
                    HeroManager.DelSoulPrintUpHeroDynamicId(curBagSoulPrintData.upHero,curBagSoulPrintData.id)
                    this.SoulPrintClickShow(curequipSign,choosed,_go)
                end)
            end)
        else
            this.SoulPrintClickShow(curequipSign,choosed,_go)
        end
    end)
end
function this.SoulPrintClickShow(curequipSign,choosed,_go)
    if curSelectGO then
        Util.GetGameObject(curSelectGO.transform, "choosed"):SetActive(false)
    end
    curSelectSoulPrint = curequipSign
    choosed:SetActive(true)
    Util.GetGameObject(_go.transform, "Hero"):SetActive(false   )
    curSelectGO = _go
    this.ShowSUreBtnState()
end
function this.ShowSUreBtnState()
    if curSelectSoulPrint and curSelectSoulPrint.Id then
        Util.SetGray(this.BtnSure,false)
        this.BtnSure:GetComponent("Button").enabled = true
    else
        Util.SetGray(this.BtnSure,true)
        this.BtnSure:GetComponent("Button").enabled = false
    end
end
--界面关闭时调用（用于子类重写）
function CompoundSelectListPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function CompoundSelectListPopup:OnDestroy()
end

return CompoundSelectListPopup