require("Base/BasePanel")
MedalSuitPopup = Inherit(BasePanel)
local this = MedalSuitPopup
local SpecialConfig  = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local ItemConfig  = ConfigManager.GetConfig(ConfigName.ItemConfig)
local HeroDatar--当前英雄
local medalSuitPlanList={}
local changePosNameId=0

--初始化组件（用于子类重写）
function MedalSuitPopup:InitComponent()

    this.heroPre = Util.GetGameObject(this.gameObject,"heroPre")

    this.medalSiteList = {}
    this.medalGroups = Util.GetGameObject(this.gameObject,"medalGroup")
    for i = 1, 4 do
       local medalItem = Util.GetGameObject(this.medalGroups,"medal"..i)
       table.insert(this.medalSiteList,medalItem)
    end

    local item = Util.GetGameObject(self.gameObject, "item")
    local v = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "scroll").transform,
    item, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,15))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

    this.inputPanel = Util.GetGameObject(this.gameObject,"mask2")
    this.setNameBtn = Util.GetGameObject(this.inputPanel,"setNameBtn")
    this.setName = Util.GetGameObject(this.inputPanel,"bg/setName/Name")

    this.downBtn = Util.GetGameObject(self.gameObject,"downBtn")
    this.saveBtn = Util.GetGameObject(self.gameObject,"saveBtn")

    this.backBtn = Util.GetGameObject(self.gameObject,"backBtn")
	this.Mask = Util.GetGameObject(self.gameObject,"Mask")
 
end

--绑定事件（用于子类重写）
function MedalSuitPopup:BindEvent()
    Util.AddClick(self.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(self.Mask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)

    --一键卸下
    Util.AddClick(self.downBtn, function()
        local count = MedalManager.MedalDaraByHero(HeroDatar.dynamicId)
        if count and #count > 0 then
            NetManager.MedalUnload2Request(HeroDatar.dynamicId,function(msg)
                MedalManager.DownMedalDaraByHero(HeroDatar.dynamicId)
                this.HeroMedalDataShow()
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(23070)
        end
    end)

    --保存为方案
    Util.AddClick(self.saveBtn, function()
        if #this.WearmedalList <= 0 then
            PopupTipPanel.ShowTipByLanguageId(23071)
        end
        local isTip = false
        for i = 1, #this.medalSavePos do
            if this.medalSavePos[i].activePos==1 and #this.medalSavePos[i].medalId<=0 then--解锁、没方案
                isTip=false

                NetManager.WearSavePosRequest(this.medalSavePos[i].pos,this.WearmedalList,function(msg)
                    --TODO考虑已存方案存在相同勋章问题
                    Log(GetLanguageStrById(23072))
                    Log(this.medalSavePos[i].pos)
                    MedalSuitPopup:OnShow()
                end)
                return
            end
            isTip = true
        end

        --三个栏位都有勋章套装的时候
        --弹出选择代替方案id
        if isTip then
            UIManager.OpenPanel(UIName.MedalAssembleChoosePopup,this.medalSavePos,this.WearmedalList)
        end
    end)

    Util.AddOnceClick(this.setNameBtn,function()--勋章改名字
        local nameData= this.setName:GetComponent("Text").text
         NetManager.SetNameRequest(changePosNameId,nameData,function()
             this.inputPanel:SetActive(true)
              MedalSuitPopup:OnShow()
          end)   
     
     end)
   
end

--添加事件监听（用于子类重写）
function MedalSuitPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalSuitPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MedalSuitPopup:OnOpen(...)
    local args = {...}
    HeroDatar = args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalSuitPopup:OnShow()
    this.inputPanel:SetActive(false)
    this.HeroDataShow()
    this.HeroMedalDataShow()

    NetManager.GetSavePosRequest(function(msg)
        this.medalSavePos=msg.medalSavePos
        this.ScrollView:SetData(this.medalSavePos, function (index, go)
            this.MedalPlanShow(go, this.medalSavePos[index],this.medalSavePos[index-1])
        end)
    end)

    
    
end
function MedalSuitPopup:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function MedalSuitPopup:OnClose()

    RoleInfoPanel.UpdatePanelData()
    --TODO刷新详情面板
end

--界面销毁时调用（用于子类重写）
function MedalSuitPopup:OnDestroy()

end

--英雄展示
function this.HeroDataShow()
    local heroData = HeroDatar
    Util.GetGameObject(this.heroPre, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(heroData.heroConfig.Quality,heroData.heroConfig.star))
    Util.GetGameObject(this.heroPre, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality,heroData.heroConfig.star))
    Util.GetGameObject(this.heroPre, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(this.heroPre, "name"):GetComponent("Text").text = GetLanguageStrById(heroData.heroConfig.ReadingName)
    Util.GetGameObject(this.heroPre, "icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.icon)
    Util.GetGameObject(this.heroPre, "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality,heroData.heroConfig.star))
    Util.GetGameObject(this.heroPre, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    local starGrid = Util.GetGameObject(this.heroPre, "star")
    SetHeroStars(starGrid, heroData.star)
end

--英雄芯片信息
function this.HeroMedalDataShow()

    local WearmedalListWear = MedalManager.MedalDaraByHero(HeroDatar.dynamicId)
    this.WearmedalList = {}

    for k,v in pairs(WearmedalListWear) do
       table.insert(this.WearmedalList,v.idDyn)
    end

    local suitRes = {}
    suitRes = MedalManager.SuitHeroSuitActive(WearmedalListWear)
    HeroManager.SetHeroSuitAtive(HeroDatar.dynamicId,suitRes)
    local suitActiveList = HeroManager.GetHeroSuitActive(HeroDatar.dynamicId)

    local suit1 = Util.GetGameObject(this.gameObject, "suit1")
    local suit2 = Util.GetGameObject(this.gameObject, "suit2")
    suit2:SetActive(false)
    --套装激活
    if HeroDatar.suitActive and #HeroDatar.suitActive > 0 then
        for i = 1, #HeroDatar.suitActive do
            local suit = Util.GetGameObject(this.gameObject, "suit"..i)
            suit:SetActive(true)
            local medalSuitData = MedalManager.GetMedalSuitInfoById(HeroDatar.suitActive[i].suitId)
            local suitTypedata = MedalManager.GetMedalSuitInfoByType(medalSuitData.Type)
            suit:GetComponent("Text").text = string.format(GetLanguageStrById(23073),medalSuitData.Star,GetLanguageStrById(suitTypedata.Name),HeroDatar.suitActive[i].num)
        end
    else
        suit1:SetActive(true)
        suit1:GetComponent("Text").text = GetLanguageStrById(23074)
    end

    --芯片展示
    for i = 1, 4 do
        local medalItem = this.medalSiteList[i]
        local no = Util.GetGameObject(medalItem,"no")
        local frame = Util.GetGameObject(medalItem,"frame")
        local icon = Util.GetGameObject(medalItem,"icon")
        local starGrid = Util.GetGameObject(medalItem,"icon/grid")
        local text = Util.GetGameObject(medalItem,"text")
        local hintLightImage = Util.GetGameObject(medalItem,"hintLight/hintLightImage")

        if WearmedalListWear[i] then
            no:SetActive(false)
            frame:SetActive(true)
            icon:SetActive(true)
            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(WearmedalListWear[i].medalConfig.Quality))
            icon:GetComponent("Image").sprite = Util.LoadSprite(WearmedalListWear[i].icon)
            SetHeroStars(starGrid,WearmedalListWear[i].medalConfig.Star)
        else
            no:SetActive(true)
            frame:SetActive(false)
            icon:SetActive(false)
            -- frame:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
            -- icon:GetComponent("Image").sprite = Util.LoadSprite("")
        end
        Util.AddOnceClick(no, function()
            -- if WearmedalListWear[i] then
            --     UIManager.OpenPanel(UIName.MedalParticularsPopup,WearmedalListWear[i],i,true,HeroDatar.dynamicId,true,true)--data勋章 槽位ID  是否穿戴在英雄身上 英雄id
            -- else
            --     UIManager.OpenPanel(UIName.MedalChangelPopup,i,HeroDatar.dynamicId)--槽位id  英雄ID
            -- end
            if WearmedalListWear[i] then
                UIManager.OpenPanel(UIName.MedalParticularsPopup,WearmedalListWear[i].id,nil,false,nil,false,false)--data勋章ID 槽位ID  随机属性ID 已添加的勋章列表
            end
        end)
    end
end

--套装方案展示
function this.MedalPlanShow(go,data,iData)
    go:SetActive(true)
    local user = Util.GetGameObject(go,"user")
    local name = Util.GetGameObject(go,"name")
    local renameBtn = Util.GetGameObject(go,"name/renameBtn")

    local Image2 = Util.GetGameObject(go,"Image2")
    local activeFalse = Util.GetGameObject(go,"activeFalse")
    local buyBtn = Util.GetGameObject(activeFalse,"buyBtn")
    local costIcon = Util.GetGameObject(activeFalse,"buyBtn/costIcon")
    local costText = Util.GetGameObject(activeFalse,"buyBtn/costText")

    local activeTrue = Util.GetGameObject(go,"activeTrue")
    -- local medalGroup = Util.GetGameObject(activeTrue,"medalGroup")
    -- local suit1 = Util.GetGameObject(activeTrue,"suit1")
    -- local suit2 = Util.GetGameObject(activeTrue,"suit2")
    local wearBtn = Util.GetGameObject(activeTrue,"wearBtn")

    Image2:SetActive(data.activePos == 1)
    renameBtn:SetActive(data.activePos == 1)
    activeFalse:SetActive(data.activePos == 0)
    activeTrue:SetActive(data.activePos == 1)

    --未开启
    if data.activePos == 0 then
        name:GetComponent("Text").text = string.format(GetLanguageStrById(23053),data.pos)
        local SpecialConfigData = SpecialConfig[132].Value
        local dataList = {}
        for k,v in ipairs(string.split(SpecialConfigData,"|")) do
            local splitData = string.split(v,"#")
            dataList[k] = {splitData[1],splitData[2]}
        end
        local dataOne = dataList[data.pos-1]
        costIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[tonumber(dataOne[1])].ResourceID))
        costText:GetComponent("Text").text = dataOne[2]
        Util.AddOnceClick(buyBtn,function()--购买套装位置
                --todo开启顺序
            if iData ~= nil and iData.activePos == 1 then
                MsgPanel.ShowTwo(GetLanguageStrById(23075), nil, function()
                    NetManager.BuySavePosRequest(data.pos,function(msg)
                        Log(GetLanguageStrById(23076))
                        this.medalSavePos = msg.medalSavePos
                        this.ScrollView:SetData(this.medalSavePos, function (index, go)
                             this.MedalPlanShow(go, this.medalSavePos[index])
                        end)
                    end)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(23077)
            end
        end)
    else--开启
        if data.name == nil or data.name == "" then
            name:GetComponent("Text").text = string.format(GetLanguageStrById(23053),data.pos)
        else
            name:GetComponent("Text").text = string.format("[%s]",data.name)
        end
        local medalList = data.medalId
        local medalSiteList = {}
        local medalGroup = Util.GetGameObject(activeTrue,"medalGroup")
        for i = 1, 4 do
            local medalItem = Util.GetGameObject(medalGroup,"medal"..i)
            table.insert(medalSiteList,medalItem)
        end
        this.MedalDataShow(data.medalId,medalSiteList,activeTrue)
            
        Util.AddOnceClick(wearBtn,function()--穿戴勋章
            if data.medalId and #data.medalId <= 0 then
                PopupTipPanel.ShowTipByLanguageId(23078)
                return
            end
            local heroList = {}
            local sameMedalList = {}
            for k,v in ipairs(data.medalId)do
                local heroId = MedalManager.GetOneheroIdData(v,HeroDatar.dynamicId)
                if  heroId ~= 0 then
                 table.insert(heroList,heroId)
                 table.insert(sameMedalList,v)
                end
            end
            if #heroList > 0 then
                UIManager.OpenPanel(UIName.MedalSameTipPopup,heroList,sameMedalList,function()
                    NetManager.UseSavePosRequest(HeroDatar.dynamicId,data.pos,function()
                        for k,v in ipairs(heroList)do
                            MedalManager.UpMedalData(v,nil)
                        end
                        MedalManager.DownMedalDaraByHero(HeroDatar.dynamicId)
                        MedalManager.WearMedalsByHero(HeroDatar.dynamicId,medalList)
                       
                        this.HeroMedalDataShow()
                    end)
                end)
            else
                NetManager.UseSavePosRequest(HeroDatar.dynamicId,data.pos,function()
                    MedalManager.DownMedalDaraByHero(HeroDatar.dynamicId)
                    MedalManager.WearMedalsByHero(HeroDatar.dynamicId,medalList)
                   
                    this.HeroMedalDataShow()
                end)
            end
        end)
        
        Util.AddOnceClick(renameBtn,function()--勋章改名字
            this.inputPanel:SetActive(true)
            if data.activePos==1 then
                changePosNameId=data.pos
            end 
        
        end)
    end
end

function this.MedalDataShow(medalData,medals,go)
    local WearmedalListWear = {}

    for i = 1, #medalData do
        local data = MedalManager.GetOneMedalData(medalData[i])
        WearmedalListWear[data.position] = data
    end

    local suitRes = {}
    suitRes = MedalManager.SuitHeroSuitActive(WearmedalListWear) 

    local suit1 = Util.GetGameObject(go, "suit1")
    local suit2 = Util.GetGameObject(go, "suit2")
    suit2:SetActive(false)
    --套装激活
    if suitRes and #suitRes > 0 then
        for i = 1, #suitRes do
            local suit = Util.GetGameObject(go, "suit"..i)
            suit:SetActive(true)
            local medalSuitData = MedalManager.GetMedalSuitInfoById(suitRes[i].suitId)
            local suitTypedata = MedalManager.GetMedalSuitInfoByType(medalSuitData.Type)
            suit:GetComponent("Text").text = string.format(GetLanguageStrById(23073),medalSuitData.Star,GetLanguageStrById(suitTypedata.Name),suitRes[i].num)
        end
    else
        suit1:SetActive(true)
        suit1:GetComponent("Text").text = GetLanguageStrById(23074)
    end

    --勋章展示
    for i = 1, 4 do
        local medalItem = medals[i]
        local no = Util.GetGameObject(medalItem,"no")
        local frame = Util.GetGameObject(medalItem,"frame")
        local icon = Util.GetGameObject(medalItem,"icon")
        local starGrid = Util.GetGameObject(medalItem,"icon/grid")
        -- local text = Util.GetGameObject(medalItem,"text")
        -- local hintLightImage = Util.GetGameObject(medalItem,"hintLight/hintLightImage")
        local btn = Util.GetGameObject(medalItem,"btn")

        if WearmedalListWear[i] then
            no:SetActive(false)
            frame:SetActive(true)
            icon:SetActive(true)
            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(WearmedalListWear[i].medalConfig.Quality))
            icon:GetComponent("Image").sprite = Util.LoadSprite(WearmedalListWear[i].icon)
            SetHeroStars(starGrid,WearmedalListWear[i].medalConfig.Star)
        else
            no:SetActive(true)
            frame:SetActive(false)
            icon:SetActive(false)
        --    frame:GetComponent("Image").sprite = Util.LoadSprite("N1_iconbg_tongyong_baise")
        --    icon:GetComponent("Image").sprite = Util.LoadSprite("N1_icon_tankexunzhang_xunzhang0"..i)
        end
        Util.AddOnceClick(btn, function()
            if WearmedalListWear[i] then
                UIManager.OpenPanel(UIName.MedalParticularsPopup,WearmedalListWear[i].id,nil,false,nil,false,false)--data勋章ID 槽位ID  随机属性ID 已添加的勋章列表
            end
        end)
    end
end

return MedalSuitPopup