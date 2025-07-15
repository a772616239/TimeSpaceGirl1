require("Base/BasePanel")
ToTemListPopup = Inherit(BasePanel)
local this = ToTemListPopup

--初始化组件（用于子类重写）
function ToTemListPopup:InitComponent()

   
    this.item=Util.GetGameObject(self.gameObject,"item")
   
    --已获得
    this.upPart=Util.GetGameObject(self.gameObject,"upPart")
    this.upScroll=Util.GetGameObject(self.gameObject,"upPart/upScroll")
    local w = this.upScroll.transform.rect.width
    local h = this.upScroll.transform.rect.height
    this.scrollViewUp = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.upScroll.transform, this.item, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 10))
    this.scrollViewUp.moveTween.MomentumAmount = 1
    this.scrollViewUp.moveTween.Strength = 1


    --未获得        
    this.downPart=Util.GetGameObject(self.gameObject,"downPart")
    this.downScroll=Util.GetGameObject(self.gameObject,"downPart/downScroll")
   
    local w = this.downScroll.transform.rect.width
    local h = this.downScroll.transform.rect.height
    this.scrollViewDown = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.downScroll.transform, this.item, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 10))
    this.scrollViewDown.moveTween.MomentumAmount = 1
    this.scrollViewDown.moveTween.Strength = 1
    

 
    this.mask=Util.GetGameObject(self.gameObject,"mask")
    this.backBtn=Util.GetGameObject(self.gameObject,"bg/backBtn")
    this.getTotemBtn=Util.GetGameObject(self.gameObject,"getTotemBtn")
end

--绑定事件（用于子类重写）
function ToTemListPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        RoleInfoPanel.UpdatePanelData()

        self:ClosePanel()
    end)
    Util.AddClick(this.getTotemBtn,function()
        if ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.ENDLESS) then

            if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ENDLESS) then
                NetManager.MapInfoListRequest(function (msg)
                    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.ENDLESS)
                    PlayerPrefs.SetInt("WuJin1"..PlayerManager.uid,serData.endTime)
                    CheckRedPointStatus(RedPointType.EndlessPanel)
                    MapManager.curCarbonType = CarBonTypeId.ENDLESS
                    MapManager.SetViewSize(3)--设置视野范围（明雷形式）
                    MapManager.isTimeOut = false 
                    UIManager.OpenPanel(UIName.EndLessCarbonPanel,msg.info)
                end)
            else
                PopupTipPanel.ShowTip(GetLanguageStrById(10281))
            end
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.ENDLESS))
        end
    end)
    
end

--添加事件监听（用于子类重写）
function ToTemListPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function ToTemListPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function ToTemListPopup:OnOpen(...)
    local args={...}
    this.heroData=args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ToTemListPopup:OnShow()
    this.SetUpData()
    this.SetDownData()
end


function ToTemListPopup:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function ToTemListPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function ToTemListPopup:OnDestroy()

end


--已获得
function this.SetUpData()
    local haveDataList=TotemManager.GetAllTotemData()
    
    for i = 1, #haveDataList do
         
        
    end
    this.scrollViewUp:SetData(haveDataList, function (index, go)
        this.SetSingleUpData(go, haveDataList[index])
    end)
end

function this.SetSingleUpData(go,data)
    local frame=Util.GetGameObject(go,"frame")
    local icon=Util.GetGameObject(go,"frame/icon")
    local name=Util.GetGameObject(go,"name")
    local type=Util.GetGameObject(go,"type")
    local condition=Util.GetGameObject(go,"condition")
    local hero=Util.GetGameObject(go,"wear/hero")
    local wearBtn=Util.GetGameObject(go,"wear/wearBtn/wearBtn")
    frame:GetComponent("Image").sprite=Util.LoadSprite(data.frame)
    icon:GetComponent("Image").sprite=Util.LoadSprite(data.icon)
    name:GetComponent("Text").text=GetLanguageStrById(data.name) 
    type:GetComponent("Text").text=GetLanguageStrById(data.itemConfig.ItemTypeDes)
    condition:SetActive(false)

 
    if data.upHeroDid~=nil then
        hero:SetActive(true)
        local heroFrame=Util.GetGameObject(hero,"frame")
        local heroIcon=Util.GetGameObject(hero,"icon")
        local heroProIcon=Util.GetGameObject(hero,"proIcon")
        local heroLv=Util.GetGameObject(hero,"lv/Text")
        local heroStar=Util.GetGameObject(hero,"star")
        local wearState=Util.GetGameObject(hero,"wearState")

        local heroInfo=HeroManager.GetSingleHeroData(data.upHeroDid)
        heroFrame:GetComponent("Image").sprite=Util.LoadSprite(GetHeroQuantityImageByquality(heroInfo.heroConfig.Quality, heroInfo.star))
        heroIcon:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(heroInfo.heroConfig.Icon))
        heroProIcon:GetComponent("Image").sprite=Util.LoadSprite(GetProStrImageByProNum(heroInfo.heroConfig.PropertyName))
        heroLv:GetComponent("Text").text=heroInfo.lv
        SetHeroStars(heroStar,heroInfo.star)
        wearState:SetActive(data.upHeroDid==this.heroData.dynamicId)
    else
        hero:SetActive(false)
    end

    if data.upHeroDid==this.heroData.dynamicId then
        wearBtn:SetActive(false)
    else
        wearBtn:SetActive(true)
    end
   
    Util.AddOnceClick(wearBtn,function()
        --图腾身上有没有挂载在其他英雄身上
        if data.upHeroDid~=nil then
            --提示是否替换
            MsgPanel.ShowTwo(GetLanguageStrById(50337), nil, function()

                local totemdata=TotemManager.GetTotemDataByHeroId(this.heroData.dynamicId)

                if totemdata~=nil  then
                    TotemManager.DownTutemDataByHeroId(totemdata.upHeroDid)
                end


                local data= TotemManager.GetOneTotemData(data.idDyn)
               NetManager.TotemWearRequest(data.id,this.heroData.dynamicId,function()
                  PopupTipPanel.ShowTipByLanguageId(11953)
                  TotemManager.DownTutemDataByHeroId(data.upHeroDid)
                  TotemManager.wearTotemData(data.id,this.heroData.dynamicId)
                  this.SetUpData()
                  this.SetDownData()
                  RoleInfoPanel.ShowHeroEquip()
               end)
          end)
          
        else
            local totemdata=TotemManager.GetTotemDataByHeroId(this.heroData.dynamicId)

            if totemdata~=nil and totemdata.idDyn~=data.idDyn then
                    NetManager.TotemWearRequest(data.id,this.heroData.dynamicId,function()
                        PopupTipPanel.ShowTipByLanguageId(23127)
                        TotemManager.DownTutemDataByHeroId(totemdata.upHeroDid)
                        TotemManager.wearTotemData(data.id,this.heroData.dynamicId)
                        this.SetUpData()
                        this.SetDownData()
                        RoleInfoPanel.ShowHeroEquip()
                    end)
            else

            end
            NetManager.TotemWearRequest(data.id,this.heroData.dynamicId,function()
                PopupTipPanel.ShowTipByLanguageId(23127)
                TotemManager.wearTotemData(data.id,this.heroData.dynamicId)
                this.SetUpData()
                this.SetDownData()
                RoleInfoPanel.ShowHeroEquip()
            end)
        end
       
    end)
end



--未获得
function this.SetDownData()
    local dataList=TotemManager.GetAllNoHaveTotemData()
    local noHaveDataList={}
    for k,v in pairs(dataList)do
        table.insert(noHaveDataList,v)
    end
    table.sort(noHaveDataList,function (a,b)
        return a.ItemId<b.ItemId
    end)
    this.scrollViewDown:SetData(noHaveDataList, function (index, go)
        this.SetSingleDownData(go, noHaveDataList[index])
    end)
end

function this.SetSingleDownData(go,data)
    local frame=Util.GetGameObject(go,"frame")
    local icon=Util.GetGameObject(go,"frame/icon")
    local name=Util.GetGameObject(go,"name")
    local type=Util.GetGameObject(go,"type")
    local condition=Util.GetGameObject(go,"condition")
    local hero=Util.GetGameObject(go,"hero")
    local wearBtn=Util.GetGameObject(go,"wearBtn")

    local tutemData=ConfigManager.GetConfigDataByDoubleKey("ExpeditionTotemConfig","ItemId",data.ItemId,"Level",1)
    local itemConfigData=ConfigManager.GetConfigData("ItemConfig",tutemData.ItemId)
    frame:GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByquality(tutemData.Color))
    icon:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    name:GetComponent("Text").text=GetLanguageStrById(itemConfigData.Name) 
    type:GetComponent("Text").text=GetLanguageStrById(itemConfigData.ItemTypeDes)
    if itemConfigData.ItemDescribe==nil or itemConfigData.ItemDescribe=="0" then
       condition:SetActive(false)
    else
       condition:SetActive(true)
       condition:GetComponent("Text").text=GetLanguageStrById(itemConfigData.ItemDescribe)
    end
    hero:SetActive(false)
    wearBtn:SetActive(false)
end


return ToTemListPopup