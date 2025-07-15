require("Base/BasePanel")
ExpeditionHeroListInfoPopup = Inherit(BasePanel)
local this = ExpeditionHeroListInfoPopup
local sortType = 1 -- 1：品阶  2：等级
local proId=0--0 全部  1 火 2风 3 水 4 地  5 光 6 暗
local tabs = {}

--初始化组件（用于子类重写）
function ExpeditionHeroListInfoPopup:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "bg/btnBack")
    this.BgMask = Util.GetGameObject(self.transform, "BgMask") --m5
    this.BtnSure = Util.GetGameObject(self.transform, "bg/btnSure")
    this.cardPre = Util.GetGameObject(self.gameObject, "item")
    this.noOneImage = Util.GetGameObject(self.gameObject, "bg/noOneImage")
    this.noOneImageText = Util.GetGameObject(self.gameObject, "bg/noOneImage/talkImage/Text"):GetComponent("Text")
    this.grid = Util.GetGameObject(self.gameObject, "bg/scroll/grid")
    for i = 1, 4 do
        tabs[i] = Util.GetGameObject(self.transform, "bg/Tabs/grid/Btn" .. i)
    end
    this.ShaiXuanBtn = Util.GetGameObject(self.gameObject, "bg/ShaiXuanBtn")
    this.ShaiXuanBtnLv = Util.GetGameObject(self.gameObject, "bg/ShaiXuanBtn/Lv")
    this.ShaiXuanBtnQu = Util.GetGameObject(self.gameObject, "bg/ShaiXuanBtn/Qu")
    this.desc = Util.GetGameObject(self.gameObject, "bg/desc"):GetComponent("Text")
    this.selectBtn = Util.GetGameObject(self.gameObject, "bg/Tabs/selectBtn")
    this.ScrollBar = Util.GetGameObject(self.gameObject, "bg/Scrollbar"):GetComponent("Scrollbar")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "scroll").transform,
            this.cardPre, this.ScrollBar, Vector2.New(860, 930), 1, 5, Vector2.New(19.32, 40)) --m5
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.isHaveInTeam = false
end

--绑定事件（用于子类重写）
function ExpeditionHeroListInfoPopup:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BgMask, function()
        self:ClosePanel()
    end) --m5
    Util.AddClick(this.BtnSure, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    for i = 1, 4 do
        Util.AddClick(tabs[i], function()
            if i == proId then
                proId=ProIdConst.All
            else
                proId=i
            end
            this:OnClickTabBtn(proId)
        end)
    end

    Util.AddClick(this.ShaiXuanBtn, function()
        if sortType == SortTypeConst.Lv then
            sortType = SortTypeConst.Natural
        else
            sortType = SortTypeConst.Lv
        end
        this.ShaiXuanBtnLv:SetActive(sortType ~= SortTypeConst.Lv)
        this.ShaiXuanBtnQu:SetActive(sortType ~= SortTypeConst.Natural)
        this:OnClickTabBtn(proId)
    end)
end

--添加事件监听（用于子类重写）
function ExpeditionHeroListInfoPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ExpeditionHeroListInfoPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ExpeditionHeroListInfoPopup:OnOpen()
    sortType = SortTypeConst.Lv
    proId = ProIdConst.All
    this:OnClickTabBtn(proId)
    this.ShaiXuanBtnLv:SetActive(sortType ~= SortTypeConst.Lv)
    this.ShaiXuanBtnQu:SetActive(sortType ~= SortTypeConst.Natural)
    this.desc.text = GetLanguageStrById(10491)
    this.noOneImageText.text = GetLanguageStrById(12196)
end

--设置英雄列表数据
function this.SetRoleList(_roleDatas)
    this:SortHeroDatas(_roleDatas)
    this.ScrollView:SetData(_roleDatas, function(index, go)
        this.SingleHeroDataShow(go, _roleDatas[index])
    end)
end

function this.SingleHeroDataShow(_go, _heroData)
    local heroData = _heroData
    local go = _go
    Util.GetGameObject(go, "choosed"):SetActive(false)
    local orderImage= Util.GetGameObject(go, "orderImage")
    orderImage:SetActive(false)
    Util.GetGameObject(go, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality, heroData.star))
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.icon)
    Util.GetGameObject(go, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    --Util.GetGameObject(go, "posIcon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
    Util.GetGameObject(go, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    --Util.GetGameObject(go, "heroStage"):GetComponent("Image").sprite = Util.LoadSprite(HeroStageSprite[heroData.heroConfig.HeroStage])
    Util.GetGameObject(go, "heroStage"):SetActive(false)
    Util.GetGameObject(go, "yuanImage"):SetActive(heroData.createtype == 1)
    --剩余血量 无尽副本才显示
    local hpExp = Util.GetGameObject(go, "hpExp")
    local heroHp = ExpeditionManager.heroInfo[heroData.dynamicId].remainHp
    local starGrid = Util.GetGameObject(go, "star")
    SetHeroStars(starGrid, heroData.star)
    this.SetHeroBlood(hpExp, heroHp, go)
    Util.AddOnceClick(go, function()
        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData)
    end)
end

-- 设置妖灵师血量
function this.SetHeroBlood(hpExp, heroHp, go)
    if heroHp then
        hpExp:SetActive(true)
        hpExp:GetComponent("Slider").value = heroHp
        Util.SetGray(go, heroHp <= 0)
    else
        hpExp:SetActive(false)
    end
end


function this.SetSelectBtn()
    this.selectBtn:SetActive(proId ~= ProIdConst.All)
    if proId ~= ProIdConst.All then
        this.selectBtn.transform.localPosition = tabs[proId].transform.localPosition
    end
end
--点击页签__根据sortType和职业属性/类型进行排序
function this:OnClickTabBtn(_proId)
    local heros
    this.SetSelectBtn()
    local limitLevel = 20
    if _proId == ProIdConst.All then
        heros = HeroManager.GetAllHeroDatas(limitLevel)
        heros = ExpeditionManager.GetAllHeroDatas(heros,limitLevel)
    else
        heros = HeroManager.GetHeroDataByProperty(_proId, limitLevel)
        heros = ExpeditionManager.GetHeroDataByProperty(heros,_proId, limitLevel)
    end
    
    this.noOneImage:SetActive(#heros<=0)
    this.SetRoleList(heros)
end

function this:SortHeroDatas(_heroDatas)
    local dieHeros = {}
    for i = 1, #_heroDatas do
        local heroHp = 0
        if ExpeditionManager.heroInfo[_heroDatas[i].dynamicId] then
            heroHp = ExpeditionManager.heroInfo[_heroDatas[i].dynamicId].remainHp
            if heroHp <= 0 then
                dieHeros[_heroDatas[i].dynamicId] = _heroDatas[i].dynamicId
            end
        end
    end
    table.sort(_heroDatas, function(a, b)
            if (dieHeros[a.dynamicId] and dieHeros[b.dynamicId]) or
                    (not dieHeros[a.dynamicId] and not dieHeros[b.dynamicId])
            then
                if sortType == SortTypeConst.Natural then
                    if a.heroConfig.Natural == b.heroConfig.Natural then
                        if a.heroConfig.Quality == b.heroConfig.Quality then
                            if a.star == b.star then
                                if a.lv == b.lv then
                                    if a.warPower == b.warPower then
                                        if a.id == b.id then
                                            return a.sortId > b.sortId
                                        else
                                            return a.id > b.id
                                        end
                                    else
                                        return a.warPower > b.warPower 
                                    end
                                else
                                    return a.lv > b.lv
                                end
                            else
                                return a.star > b.star
                            end
                        else
                            return a.heroConfig.Quality > b.heroConfig.Quality
                        end
                    else
                        return a.heroConfig.Natural > b.heroConfig.Natural
                    end
                else
                    if a.lv == b.lv then
                        if a.heroConfig.Quality == b.heroConfig.Quality then
                            if a.star == b.star then
                                if a.heroConfig.Natural == b.heroConfig.Natural then
                                    if a.warPower == b.warPower then
                                        if a.id == b.id then
                                            return a.sortId > b.sortId
                                        else
                                            return a.id > b.id
                                        end
                                    else
                                        return a.warPower > b.warPower 
                                    end
                                else
                                    return a.heroConfig.Natural > b.heroConfig.Natural
                                end
                            else
                                return a.star > b.star
                            end
                        else
                            return a.heroConfig.Quality > b.heroConfig.Quality
                        end
                    else
                        return a.lv > b.lv
                    end
                end
            else
                return not dieHeros[a.dynamicId] and  dieHeros[b.dynamicId]
            end
    end)
end

--界面关闭时调用（用于子类重写）
function ExpeditionHeroListInfoPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function ExpeditionHeroListInfoPopup:OnDestroy()


    this.ScrollView = nil
end

return ExpeditionHeroListInfoPopup