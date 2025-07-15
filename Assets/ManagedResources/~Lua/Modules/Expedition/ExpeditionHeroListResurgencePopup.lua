require("Base/BasePanel")
ExpeditionHeroListResurgencePopup = Inherit(BasePanel)
local this = ExpeditionHeroListResurgencePopup
local cueSelectHeroDid = ""
local nodeData
local fun
local ResurgenceNum = 0
local btnstate = 0
local itemId = 0
--初始化组件（用于子类重写）
function ExpeditionHeroListResurgencePopup:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "bg/btnBack")
    this.BgMask = Util.GetGameObject(self.transform, "BgMask")    --m5
    this.BtnSure = Util.GetGameObject(self.transform, "bg/btnList/btnSure")
    this.BtnSureText = Util.GetGameObject(self.transform, "bg/btnList/btnSure/Text"):GetComponent("Text")
    this.btnCancel = Util.GetGameObject(self.transform, "bg/btnList/btnCancel")
    this.btnJump = Util.GetGameObject(self.transform, "bg/btnList/btnJump")
    this.cardPre = Util.GetGameObject(self.gameObject, "item")
    this.grid = Util.GetGameObject(self.gameObject, "bg/scroll/grid")
    this.noOneImage = Util.GetGameObject(self.gameObject, "bg/noOneImage")
    this.desc = Util.GetGameObject(self.gameObject, "bg/desc")
    this.ResurgenceNum = Util.GetGameObject(self.gameObject, "bg/ResurgenceImage/ResurgenceNum"):GetComponent("Text")
    this.ResurgenceImage = Util.GetGameObject(self.gameObject, "bg/ResurgenceImage")

    this.ScrollBar = Util.GetGameObject(self.gameObject, "bg/Scrollbar"):GetComponent("Scrollbar")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "scroll").transform,
            this.cardPre, this.ScrollBar, Vector2.New(927.5, 997.3), 1, 5, Vector2.New(19.32, 40))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.isHaveInTeam = false
end

--绑定事件（用于子类重写）
function ExpeditionHeroListResurgencePopup:BindEvent()

    Util.AddClick(this.BtnBack, function()
        btnstate = 4
        self:ClosePanel()
    end)
    Util.AddClick(this.BgMask, function()
        btnstate = 4
        self:ClosePanel()
    end) --m5
    Util.AddClick(this.BtnSure, function()
        btnstate = 1
        --if cueSelectHeroDid ~= "" and ResurgenceNum > 0 then
        --    if nodeData then
        --        NetManager.ReliveExpeditionHeroRequest(cueSelectHeroDid,nodeData.sortId,function()
        --            PopupTipPanel.ShowTip("已成功复活猎妖师！")
        --            self:ClosePanel()
        --        end)
        --    else
        --        NetManager.ReliveExpeditionHeroRequest(cueSelectHeroDid,-1,function()
        --            PopupTipPanel.ShowTip("已成功复活猎妖师！")
        --            self:ClosePanel()
        --            PrivilegeManager.RefreshPrivilegeUsedTimes(ConfigManager.GetConfigData(ConfigName.ExpeditionSetting,1).Revive[1], 1)
        --        end)
            --end
        --end
        if BagManager.GetItemCountById(itemId) < 1 then
            PopupTipPanel.ShowTip(GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId).Name)..GetLanguageStrById(10492))
            return
        end
        NetManager.ReliveExpeditionHeroRequest(nil,-1,function()
            PopupTipPanel.ShowTipByLanguageId(10493)
            self:ClosePanel()
        end)
    end)
    Util.AddClick(this.btnCancel, function()
        btnstate = 2
        self:ClosePanel()
    end)
    Util.AddClick(this.btnJump, function()
        NetManager.ReliveExpeditionHeroRequest("",nodeData.sortId,function()
            btnstate = 3
            self:ClosePanel()
        end)
    end)
end


--添加事件监听（用于子类重写）
function ExpeditionHeroListResurgencePopup:AddListener()
end

--移除事件监听（用于子类重写）
function ExpeditionHeroListResurgencePopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ExpeditionHeroListResurgencePopup:OnOpen(_nodeData,_fun)
    itemId = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,48).Value)
    nodeData = _nodeData
    fun = _fun
end

function ExpeditionHeroListResurgencePopup:OnShow()

    btnstate = 0
    cueSelectHeroDid = ""
    this.SetRoleList()
end

--设置英雄列表数据
function this.SetRoleList()
    local roleDatas = {}
    local limitLevel = 20
    roleDatas = HeroManager.GetAllHeroDatas(limitLevel)
    roleDatas = ExpeditionManager.GetAllHeroDatas(roleDatas,limitLevel)
    this.BtnSureText.text = GetLanguageStrById(10212)
    ResurgenceNum = BagManager.GetItemCountById(itemId)--PrivilegeManager.GetPrivilegeRemainValue(ConfigManager.GetConfigData(ConfigName.ExpeditionSetting,1).Revive[1])
    this.btnCancel:SetActive(false)
    this.btnJump:SetActive(false)
    this.desc:GetComponent("Text").text = GetLanguageStrById(10220)..GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId).Name)..GetLanguageStrById(10494)
    if nodeData then--节点里
        ResurgenceNum = 1
        this.ResurgenceImage:SetActive(false)
        this.btnCancel:SetActive(#roleDatas <= 0)
        this.btnJump:SetActive(#roleDatas <= 0)
        --this.btnJump:SetActive(true)
        this.BtnSure:SetActive(#roleDatas > 0)
    else--外边复活进入
        this.ResurgenceImage:SetActive(#roleDatas > 0)
        this.BtnSure:SetActive(true)
    end
    if #roleDatas <= 0 or ResurgenceNum <= 0 then
        --this.BtnSure:GetComponent("Button").enabled = true
        Util.SetGray(this.BtnSure,true)
    else
        --this.BtnSure:GetComponent("Button").enabled = false
        Util.SetGray(this.BtnSure,false)
    end
    this.noOneImage:SetActive(#roleDatas <= 0)
    Util.GetGameObject(this.noOneImage, "talkImage/Text"):GetComponent("Text").text = GetLanguageStrById(10495)
    this.ResurgenceNum.text = ResurgenceNum
    this.ResurgenceImage:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId).ResourceID))
    this:SortHeroDatas(roleDatas)
    this.ScrollView:SetData(roleDatas, function(index, go)
        this.SingleHeroDataShow(go, roleDatas[index])
    end)
end

function this.SingleHeroDataShow(_go, _heroData)
    local heroData = _heroData
    local go = _go
    local choosed = Util.GetGameObject(go, "choosed")
    choosed:SetActive(false)
    --if cueSelectHeroDid ==  heroData.dynamicId then
    --    choosed:SetActive(true)
    --end
    Util.GetGameObject(go, "info/frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality))
    Util.GetGameObject(go, "info/icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.icon)
    Util.GetGameObject(go, "info/lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go, "info/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    --Util.GetGameObject(go, "info/posIcon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
    Util.GetGameObject(go, "info/proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    --Util.GetGameObject(go, "info/heroStage"):GetComponent("Image").sprite = Util.LoadSprite(HeroStageSprite[heroData.heroConfig.HeroStage])
    Util.GetGameObject(go, "yuanImage"):SetActive(heroData.createtype == 1)
    --剩余血量 无尽副本才显示
    local hpExp = Util.GetGameObject(go, "info/hpExp")
        local heroHp = ExpeditionManager.heroInfo[heroData.dynamicId].remainHp
    local starGrid = Util.GetGameObject(go, "info/star")
    SetHeroStars(starGrid, heroData.star)
    this.SetHeroBlood(hpExp, heroHp, go)
    --Util.AddOnceClick(go, function()
    --    if cueSelectHeroDid ==  heroData.dynamicId then
    --        cueSelectHeroDid = ""
    --    else
    --        cueSelectHeroDid = heroData.dynamicId
    --    end
    --    this.SetRoleList(HeroManager.GetAllHeroDatas(1))
    --end)
end

-- 设置妖灵师血量
function this.SetHeroBlood(hpExp, heroHp, go)
    if heroHp then
        hpExp:SetActive(true)
        hpExp:GetComponent("Slider").value = heroHp
        Util.SetGray(Util.GetGameObject(go, "info"), heroHp <= 0)
    else
        hpExp:SetActive(false)
    end
end

function this:SortHeroDatas(_heroDatas)
    table.sort(_heroDatas, function(a, b)
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
    end)
end


--界面关闭时调用（用于子类重写）
function ExpeditionHeroListResurgencePopup:OnClose()

    if fun then
        fun(btnstate)
        fun = nil
    end
end

--界面销毁时调用（用于子类重写）
function ExpeditionHeroListResurgencePopup:OnDestroy()

    this.ScrollView = nil
end

return ExpeditionHeroListResurgencePopup