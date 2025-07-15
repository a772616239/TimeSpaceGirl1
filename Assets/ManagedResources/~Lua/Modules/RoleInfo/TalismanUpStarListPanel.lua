require("Base/BasePanel")
TalismanUpStarListPanel = Inherit(BasePanel)
local this = TalismanUpStarListPanel
local curSelectHeroList={}
local curSelectHeroList2={}
local curNeedRoleNum
local openThisPanel
local allTalismanList = {}
--初始化组件（用于子类重写）
function TalismanUpStarListPanel:InitComponent()

    screenAdapte(Util.GetGameObject(self.transform, "bg/bg"))
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.BtnSure = Util.GetGameObject(self.transform, "btnSure")
    this.btnQuickSure = Util.GetGameObject(self.transform, "btnQuickSure")
    this.cardPre = Util.GetGameObject(self.gameObject, "item")
    --this.grid = Util.GetGameObject(self.gameObject, "scroll/grid")
    this.desText = Util.GetGameObject(self.gameObject, "desText"):GetComponent("Text")
    this.numText = Util.GetGameObject(self.gameObject, "numText"):GetComponent("Text")

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
function TalismanUpStarListPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BtnSure, function()
        self:ClosePanel()
        
        openThisPanel:UpdateUpStarPosHeroData(curSelectHeroList)
    end)
    Util.AddClick(this.btnQuickSure, function()
        this.QuickSelectTalismans()
    end)
end

--添加事件监听（用于子类重写）
function TalismanUpStarListPanel:AddListener()

end

--移除事件监听（用于子类重写）
function TalismanUpStarListPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
--curTalismanData,upStarConFigData,upStarConsumeMaterial,this
function TalismanUpStarListPanel:OnOpen(curTalismanData,upStarConFigData,_curSelectTalismanList,_openThisPanel)

    
    openThisPanel= _openThisPanel
    curSelectHeroList={}
    for i = 1, #_curSelectTalismanList do
        
        curSelectHeroList[_curSelectTalismanList[i]]=_curSelectTalismanList[i]
    end
    --是否同名数据
    local EquipTalismanaRankupConFigData = ConfigManager.GetConfigData(ConfigName.EquipTalismanaRankup,upStarConFigData[2])
    allTalismanList = TalismanManager.GetAllTalismanByCondition(curTalismanData,EquipTalismanaRankupConFigData)
    this.HeroSortData(allTalismanList)
    this.ScrollView:SetData(allTalismanList, function (index, go)
        this.OnShowSingleCardData(go, allTalismanList[index])
    end)

    curNeedRoleNum = upStarConFigData[3]
    this.desText.text=string.format(GetLanguageStrById(11872),curNeedRoleNum,EquipTalismanaRankupConFigData.Name)
    this.numText.text=string.format("%s/%s",#curSelectHeroList,curNeedRoleNum)
end
function this.OnClickEnterHero(go,heroData,type)

    if type==1 then
        if #curSelectHeroList>=curNeedRoleNum then
            PopupTipPanel.ShowTipByLanguageId(10660)
            return
        else
            table.insert(curSelectHeroList,heroData)
        end
    elseif type==2 then
        for i = 1, #curSelectHeroList do
            if heroData.dynamicId==curSelectHeroList[i].dynamicId then
                table.remove(curSelectHeroList,i)
                break
            end
        end
    end
    this.OnShowSingleCardData(go,heroData,type)
    this.numText.text=string.format("%s/%s",#curSelectHeroList,curNeedRoleNum)
end

function this.OnShowSingleCardData(go,heroData)

    local choosed = Util.GetGameObject(go.transform, "choosed")
    choosed:SetActive(false)
    if curSelectHeroList[heroData.did] then
        curSelectHeroList[heroData.did]=heroData
        choosed:SetActive(true)
    end
    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.itemConfig.Quantity))
    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.itemConfig.ResourceID))
    Util.GetGameObject(go.transform, "name"):GetComponent("Text").text = heroData.itemConfig.Name
    local starGrid = Util.GetGameObject(go.transform, "star")
    SetHeroStars(starGrid, heroData.star)
    local cardBtn = Util.GetGameObject(go.transform, "icon")
    Util.AddOnceClick(cardBtn, function()
        if curSelectHeroList[heroData.did] then
            
            choosed:SetActive(false)
            curSelectHeroList[heroData.did]=nil
            this.numText.text=string.format("%s/%s",LengthOfTable(curSelectHeroList),curNeedRoleNum)
            return
        end
        if LengthOfTable(curSelectHeroList)>=curNeedRoleNum then
            PopupTipPanel.ShowTipByLanguageId(10660)
            return
        end
        
        curSelectHeroList[heroData.did]=heroData
        choosed:SetActive(true)
        this.numText.text=string.format("%s/%s",LengthOfTable(curSelectHeroList),curNeedRoleNum)
    end)
end
function this.HeroSortData(heroData)
    table.sort(heroData, function(a, b)
        if a.itemConfig.Quantity == b.itemConfig.Quantity then
            if a.star == b.star then
                return a.id < b.id
            else
                return a.star < b.star
            end
        else
           return a.itemConfig.Quantity < b.itemConfig.Quantity
        end
    end)
end
function this.QuickSelectTalismans()
    curSelectHeroList = {}
    for k, v in pairs(allTalismanList) do
        if LengthOfTable(curSelectHeroList) < curNeedRoleNum then
            
            curSelectHeroList[v.did]=v
        end
    end
    this.numText.text=string.format("%s/%s",LengthOfTable(curSelectHeroList),curNeedRoleNum)
    this.ScrollView:SetData(allTalismanList, function (index, go)
        this.OnShowSingleCardData(go, allTalismanList[index])
    end)
end
--界面关闭时调用（用于子类重写）
function TalismanUpStarListPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function TalismanUpStarListPanel:OnDestroy()

    this.ScrollView = nil
end

return TalismanUpStarListPanel