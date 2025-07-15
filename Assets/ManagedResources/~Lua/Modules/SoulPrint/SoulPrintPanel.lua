----- 魂印主面板 -----
require("Base/BasePanel")
SoulPrintPanel = Inherit(BasePanel)
local this = SoulPrintPanel
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local equipConfig=ConfigManager.GetConfig(ConfigName.EquipConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local equipSignSetting = ConfigManager.GetConfig(ConfigName.EquipSignSetting)

local orginLayer=0
--循环布局容器
local loopList={}
--最大槽位数量
local loopCount=0
--可装备槽位数量
local didLen=0
--动态最大等级
local didLv=0
--配置最大等级
local maxLv=0
--间隔角度
local angle=0
--半径
local radius=285

local curHeroData--当前英雄信息
local heroDatas--全部英雄数据
local index=0--当前索引

local isShow=true--默认显示装备中的魂印
local _specialData={}

local list={}

local orginLayer2 = 0
function SoulPrintPanel:InitComponent()
    this.upView = SubUIManager.Open(SubUIConfig.UpView, this.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
    this.helpBtn= Util.GetGameObject(this.gameObject, "HelpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.leftBtn = Util.GetGameObject(this.gameObject, "LeftBtn/GameObject")
    this.rightBtn = Util.GetGameObject(this.gameObject, "RightBtn/GameObject")
    this.handBookBtn=Util.GetGameObject(this.gameObject,"HandBookBtn")--图鉴按钮
    this.detailsBtn=Util.GetGameObject(this.gameObject,"DetailsBtn")--细节按钮
    this.showBtn=Util.GetGameObject(this.gameObject,"ShowBtn")--显示装备中的魂印按钮
    this.showBtnOn=Util.GetGameObject(this.showBtn,"Bg/On"):GetComponent("Image")
    this.backBtn = Util.GetGameObject(this.gameObject, "BackBtn/btnBack")
    this.empty=Util.GetGameObject(this.gameObject,"Empty")

    --循环布局根节点
    this.loopRoot=Util.GetGameObject(this.gameObject,"LoopRoot")
    this.loopPre=Util.GetGameObject(this.loopRoot,"Pre")

    --英雄头像
    -- this.heroFrame=Util.GetGameObject(this.gameObject,"Hero/Frame"):GetComponent("Image")
    -- this.heroIcon=Util.GetGameObject(this.gameObject,"Hero/Icon"):GetComponent("Image")

    this.heroCardGo = Util.GetGameObject(this.gameObject,"HeroCard")
    Util.GetGameObject(this.gameObject,"Hero"):SetActive(false)

    --战力
    this.power=Util.GetGameObject(this.gameObject,"Power/Value"):GetComponent("Text")

    this.scrollBar=Util.GetGameObject(this.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    --魂印列表
    this.scrollRoot=Util.GetGameObject(this.gameObject,"ScrollRoot")
    this.scrollPre=Util.GetGameObject(this.gameObject,"ScrollRoot/Pre")
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,this.scrollPre, this.scrollBar,--
        Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),1,5,Vector2.New(45,40))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.ptList = {}
    for i = 1, 10 do
        local ptgo = Util.GetGameObject(this.loopRoot,"pt" .. tostring(i))
        table.insert(this.ptList, ptgo.transform.anchoredPosition)
    end

    this.SetIsShow()
end

function SoulPrintPanel:BindEvent()
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.SoulPrint,this.helpPosition.x,this.helpPosition.y)
    end)
    --向左切换英雄数据
    Util.AddClick(this.leftBtn, function()
        this.OnLeftBtnClick()
    end)
    --向右切换英雄数据
    Util.AddClick(this.rightBtn, function()
        this.OnRightBtnClick()
    end)
    --点击图鉴按钮
    Util.AddClick(this.handBookBtn, function()
        UIManager.OpenPanel(UIName.SoulPrintHandBook)
    end)
    --点击细节按钮
    Util.AddClick(this.detailsBtn, function()
        UIManager.OpenPanel(UIName.SoulPrintPopUpV2,1,curHeroData)
    end)
    --点击显示装备中魂印按钮
    Util.AddClick(this.showBtn, function()
        isShow=(not isShow and true or false)
        this.showBtnOn.enabled= isShow
        this.SetScrollData()
    end)
    --关闭页面
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

function SoulPrintPanel:AddListener()
end

function SoulPrintPanel:RemoveListener()
end
local orginLayer = 0
function SoulPrintPanel:OnSortingOrderChange()
    --特效层级重设
    for i=1,#list do
        Util.AddParticleSortLayer(list[i], self.sortingOrder - orginLayer)
    end   
    orginLayer = self.sortingOrder
end

function SoulPrintPanel:OnOpen(_curHeroData,_heroDatas)
    curHeroData=_curHeroData
    heroDatas = {}
    if _heroDatas then
        for i = 1, #_heroDatas do
            if SoulPrintManager.GetSoulPrintIsOpen(_heroDatas[i]) then
                table.insert(heroDatas,_heroDatas[i])
            end
        end
    else
       local curheroListData=HeroManager.GetAllHeroDatas()
        for i = 1, #curheroListData do
            if SoulPrintManager.GetSoulPrintIsOpen(curheroListData[i]) then
                table.insert(heroDatas,curheroListData[i])
            end
        end
    end

    for i = 1, #heroDatas do
        if curHeroData.dynamicId == heroDatas[i].dynamicId then
            index = i
            break
        end
    end

end

function SoulPrintPanel:OnShow()
    this.upView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    --已激活魂印的Hero为1时 隐藏左右按钮
    this.leftBtn.gameObject:SetActive(#heroDatas>1)
    this.rightBtn.gameObject:SetActive(#heroDatas>1)
    this.RefreshShow()

    this.FloatIcon()
end

function SoulPrintPanel:OnClose()
    angle=0
    loopCount=0
    local var=isShow and 1 or 0
    PlayerPrefs.SetInt(PlayerManager.uid .. "_SoulPrint_IsShow",var)

    
    for k, v in ipairs(this.tweenList) do
        if v then
            v:Kill()
        end
    end
    this.tweenList = {}
    for k, v in ipairs(loopList) do
        v.transform.anchoredPosition = this.ptList[k]
    end
    
end

function SoulPrintPanel:OnDestroy()
    SubUIManager.Close(this.upView)
    this.scrollView=nil
    loopList={}
    list={}
    orginLayer2=0
    orginLayer=0
end

--点击左
function this.OnLeftBtnClick()
    index = (index - 1 > 0 and index - 1 or #heroDatas)
    curHeroData = heroDatas[index]
    this.RefreshShow()
end
--点击右
function this.OnRightBtnClick()
    index = (index + 1 <= #heroDatas and index + 1 or 1)
    curHeroData = heroDatas[index]
    this.RefreshShow()
end


--刷新显示
function this.RefreshShow()

    this.SetLoopUI()
    this.SetHero()
    this.SetScrollData()
    --对比战力并更新战力值 播放战力变更动画
    HeroManager.CompareWarPower(curHeroData.dynamicId)
    local allPro = HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false)
    this.power.text = allPro[HeroProType.WarPower]
end

--设置环形布局
function this.SetLoopUI()
    -- local specialData = string.split(ConfigManager.GetConfigData(ConfigName.SpecialConfig,37).Value, "#")
    -- --获取格子数量的动态上限
    -- _specialData={}
    -- for n = 1, #specialData do
    --     local v=specialData[n]
    --     if PlayerManager.level>=tonumber(v) then
    --         table.insert(_specialData,v)
    --     end
    -- end

    --动态当前最大等级
    local didLv=0
    -- --你猜啥意思
    -- if #_specialData<#specialData then--未达到最大等级 +1显示锁定
    --     loopCount= #_specialData+1
    --     didLv=tonumber(specialData[#_specialData+1])--最大英雄等级（需要从表获取）
    -- else
    --     loopCount=#_specialData
    --     didLv=tonumber(specialData[loopCount])
    -- end
    --最终最大等级
    local maxLv = 0 


    loopCount,didLen,didLv,maxLv= HeroManager.GetSoulPrintLoopUIMaxData()
    

    --初始化
    for i=1,loopCount do
        if not loopList[i] then
            loopList[i]=newObjToParent(this.loopPre,this.loopRoot)
        end
        loopList[i].name="Pre"..i
    end
    --设置不包含最后一位 为默认
    for j=1,loopCount do
        loopList[j]:GetComponent("RectTransform").anchoredPosition = this.ptList[j]
        local i=j-1
        if i==0 then
            i=1
            this.SetLoopPre(loopList[i],1,nil,nil,j)
        else
            this.SetLoopPre(loopList[j],1,nil,nil,j)
        end
    end
    --最后一位锁定
    if PlayerManager.level<maxLv then
        this.SetLoopPre(loopList[loopCount],2,nil,didLv)
    else
        this.SetLoopPre(loopList[loopCount],1)
    end
    --数据赋值
    for k=1,#curHeroData.soulPrintList do
        local index=curHeroData.soulPrintList[k].position
        this.SetLoopPre(loopList[index],3,index,curHeroData.soulPrintList[k])
    end
end
--获取当前子布局坐标
-- function this.GetCurPosByIndex(index)
--     local hudu=(angle/180)*Mathf.PI
--     angle=angle+(360/loopCount)
--     return Vector2.New(radius*Mathf.Cos(hudu),radius*Mathf.Sin(hudu))
-- end
--设置环形布局预设 root:预设根节点  type:开启类型 index 位置 data:数据
function this.SetLoopPre(root,type,index,data,curIndex)
    local normal= Util.GetGameObject(root,"Normal")
    local lock= Util.GetGameObject(root,"Lock")
    local unlock= Util.GetGameObject(root,"UnLock")
    local bg=Util.GetGameObject(root,"Bg")
    Util.GetGameObject(bg,"Frame"):GetComponent("Image").enabled=false

    this.setAngle(root)

    normal:SetActive(type==1) --解锁 未装备
    lock:SetActive(type==2) --锁定
    unlock:SetActive(type==3) --解锁装备魂印
    root:GetComponent("Button").interactable=type==3--只有被赋值的按钮才能点击
    if type==1 then
        Util.GetGameObject(bg,"bg"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[0].circleBg1)
    elseif type==2 then
        Util.GetGameObject(bg,"bg"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[0].circleBg1)
        Util.GetGameObject(lock,"Text"):GetComponent("Text").text=string.format( GetLanguageStrById(11947),data)
    elseif type==3 then
        --Util.GetGameObject(bg,"Frame"):GetComponent("Image").enabled=true
        Util.GetGameObject(bg,"bg"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[equipConfig[data.equipId].Quality].circleBg1)
        --Util.GetGameObject(bg,"Frame"):GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByqualityPoint(equipConfig[data.equipId].Quality))
        Util.GetGameObject(unlock,"circleFrame"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[equipConfig[data.equipId].Quality].circleBg2)
        Util.GetGameObject(unlock,"Icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(itemConfig[data.equipId].ResourceID))
        Util.GetGameObject(unlock,"circle"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[equipConfig[data.equipId].Quality].circle)
        Util.GetGameObject(unlock,"Name"):GetComponent("Text").text=GetLanguageStrById(itemConfig[data.equipId].Name)
        Util.AddOnceClick(root,function()
            local pos=index

            UIManager.OpenPanel(UIName.SoulPrintPopUp,2,curHeroData.dynamicId,data.equipId,pos,function()
                PopupTipPanel.ShowTipByLanguageId(11949)
                this.RefreshShow()
            end)
        end)
    end
end

function this.setAngle(root)
    local unlock= Util.GetGameObject(root,"UnLock")
    local bg=Util.GetGameObject(root,"Bg")

    local ptFloat = root.transform.anchoredPosition
    local angle = math.acos(math.abs(ptFloat.x) / math.sqrt(ptFloat.x * ptFloat.x + ptFloat.y * ptFloat.y)) * 57.29578

    if ptFloat.x >= 0 and ptFloat.y >= 0 then
        angle = angle + 135
    elseif ptFloat.x < 0 and ptFloat.y > 0 then
        angle = (90 - angle) + 225
    elseif ptFloat.x < 0 and ptFloat.y < 0 then
        angle = angle - 45
    elseif ptFloat.x > 0 and ptFloat.y < 0 then
        angle = 45 + (90 - angle)
    end
    Util.GetGameObject(bg,"Image").transform:DORotate(Vector3.New(0,0,angle),0)
    Util.GetGameObject(unlock,"line").transform:DORotate(Vector3.New(0,0,angle),0)
end

function this.FloatIcon()
    if this.tweenList then
        for k, v in ipairs(this.tweenList) do
            if v then
                v:Kill()
            end
        end
        this.tweenList = {}
    end
    for k, v in ipairs(loopList) do
        v.transform.anchoredPosition = this.ptList[k]
    end

    local _ptround = 23
    local _speed = 7
    local function floatPt(go, startv2, k)
        local tempPos = Vector2.New(startv2.x + Random.Range(-_ptround, _ptround), startv2.y + Random.Range(-_ptround, _ptround))
        local dis = Vector2.Distance(tempPos, go.transform.anchoredPosition)
        local t = dis / _speed

        this.tweenList[k] = DoTween.To(DG.Tweening.Core.DOGetter_UnityEngine_Vector2( function () return go.transform.anchoredPosition end),
                DG.Tweening.Core.DOSetter_UnityEngine_Vector2(function (v2)
                    go.transform.anchoredPosition = v2
                    this.setAngle(go)
                end), tempPos, t):SetEase(Ease.InOutQuad):OnComplete(function ()
                    floatPt(go, startv2, k)
                end )
    end
    
    this.tweenList = {}
    for k, v in ipairs(loopList) do
        local startv2 = v.transform.anchoredPosition
        floatPt(v, startv2, k)
    end

end

--设置英雄
function this.SetHero()
    --this.heroIcon.sprite=Util.LoadSprite(GetResourcePath(curHeroData.heroConfig.Icon))
    local allPro = HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false)
    this.power.text = allPro[HeroProType.WarPower]

    --改成卡牌
    local cardGo = Util.GetGameObject(this.heroCardGo.transform, "cardroot")
    cardGo.transform.localPosition = Vector3.zero
    cardGo.transform.localScale = Vector3.one

    this.SetHeroUI(cardGo, curHeroData)
end

function this.SetHeroUI(_go, _heroData)
    local heroData = _heroData
    SetHeroBg(Util.GetGameObject(_go.transform, "card/bg"),Util.GetGameObject(_go.transform, "card/frame"),heroData.heroConfig.Quality,_heroData.star)
    Util.GetGameObject(_go.transform, "card/lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(_go.transform, "card/name"):GetComponent("Text").text = GetLanguageStrById(heroData.heroConfig.ReadingName)
    Util.GetGameObject(_go.transform, "card/icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.painting)
    Util.GetGameObject(_go.transform, "card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    local redPoint = Util.GetGameObject(_go.transform, "card/sign/redPoint")
    Util.GetGameObject(_go.transform, "card/sign/lock"):SetActive(heroData.lockState == 1)
    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, heroData.star)
    SoulPrintManager.UnLockSoulPrintPos(heroData)
    local  soulPrintIsOpen = table.nums(SoulPrintManager.hasUnlockPos)>=1

    redPoint:SetActive(false)
    Util.GetGameObject(_go.transform, "card/sign/choosed"):SetActive(false)
end


--设置装备中的魂印
function this.SetIsShow()
    if PlayerPrefs.GetInt(PlayerManager.uid .. "_SoulPrint_IsShow") then
        isShow=PlayerPrefs.GetInt(PlayerManager.uid .. "_SoulPrint_IsShow")==1
    else
        isShow=true
    end
    this.showBtnOn.enabled=isShow
end

--设置魂印列表滚动条
function this.SetScrollData()  
    local data =SoulPrintManager.GetAllSoulPrint(isShow,curHeroData.id,curHeroData.dynamicId)
    this.empty:SetActive(#data==0)
    this.ShowRedPotDataAndSort(data)

    list={}
    this.scrollView:SetData(data,function(index,root)
        this.SetScrollPre(root,data[index])
        table.insert(list,root)
    end)
    --特效层级重设
    for i=1,#list do
        Util.AddParticleSortLayer(list[i], this.sortingOrder- orginLayer2)
    end
    orginLayer2 = this.sortingOrder
    orginLayer = this.sortingOrder
    this.scrollView:SetIndex(1)
end
--设置魂印列表预设
function this.SetScrollPre(root,data)
    local effect = Util.GetGameObject(root,"UI_Effect_Kuang_JinSe")

    local frame=Util.GetGameObject(root,"Frame"):GetComponent("Image")
    local icon=Util.GetGameObject(root,"Icon"):GetComponent("Image")
    local name=Util.GetGameObject(root,"Name"):GetComponent("Text")
    local hero=Util.GetGameObject(root,"Hero")
    local heroIcon=Util.GetGameObject(hero,"Icon"):GetComponent("Image")
    local circle=Util.GetGameObject(root,"circle"):GetComponent("Image")
    local equipped=Util.GetGameObject(root,"Equipped") --是否已装备

    Util.GetGameObject(root,"limit"):SetActive(equipConfig[data.id].limit == 1 and not SoulPrintManager.GetCurSoulPrintIsCanUp(data.id) and data.upHero=="")
    frame.sprite=Util.LoadSprite(GetQuantityImageByquality(equipConfig[data.id].Quality))
    circle.sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[equipConfig[data.id].Quality].circle)
    icon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[data.id].ResourceID))
    name.text=equipConfig[data.id].Name
    hero.gameObject:SetActive(data.upHero~="")
    Util.GetGameObject(root,"redPoint"):SetActive(data.isShowRedPot == 1)
    equipped.gameObject:SetActive(this.GetCurHeroSoulPrintState(data.id))
    if data.upHero~="" then
        local heroId= HeroManager.GetSingleHeroData(data.upHero).id
        
        heroIcon.sprite=Util.LoadSprite(GetResourcePath(heroConfig[heroId].Icon))
    end


    --点击事件（穿戴或替换魂印）
    Util.AddOnceClick(root,function()
        if not SoulPrintManager.GetCurSoulPrintIsCanUp(data.id) and data.upHero=="" then
            PopupTipPanel.ShowTipByLanguageId(11950)
            return
        end
        if this.GetCurHeroSoulPrintState(data.id) then 
            PopupTipPanel.ShowTipByLanguageId(11950)
            return
        end          
        local pos=this.GetPos()--位置
        UIManager.OpenPanel(UIName.SoulPrintPopUp,1,curHeroData.dynamicId,data.id,pos,function()
            PopupTipPanel.ShowTipByLanguageId(11604)
            this.RefreshShow()
        end,data)
        -- end
    end)
end

--自动获取魂印的位置 如果有位置返回位置 如果没位置返回0
function this.GetPos()
    local _data={}
    for k=1,loopCount do
        if Util.GetGameObject(loopList[k].gameObject,"UnLock").activeSelf then
            table.insert(_data,k,k)
        end
    end
    for i = 1, loopCount do
        if _data[i]==nil then
            return i
        end
        if didLen == LengthOfTable(_data) then
            return 0
        end
    end
end
function this.ShowRedPotDataAndSort(allData)
    local didMaxLen,didLen,didLv,maxLv = HeroManager.GetSoulPrintLoopUIMaxData()
    if curHeroData.soulPrintList and #curHeroData.soulPrintList >= didLen then 
        table.sort(allData, function(a,b)   
            if equipConfig[a.id].Quality == equipConfig[b.id].Quality  then
                return a.id > b.id
            else
                return equipConfig[a.id].Quality >  equipConfig[b.id].Quality 
            end
        end)
        return 
    end

    local allUpSoulPrint = {}--所有已上魂印
    if curHeroData.soulPrintList then
        for i = 1, #curHeroData.soulPrintList do
            allUpSoulPrint[curHeroData.soulPrintList[i].equipId] = curHeroData.soulPrintList[i]
        end
    end
    
    local haveRedPointSid = {}--所有已标记红点魂印

    local temp=SoulPrintManager.GetAllSoulPrint(true,curHeroData.id,curHeroData.dynamicId)
    local limitSoulPrint = {}   
    for i = 1, #temp do
        if not limitSoulPrint[temp[i].id] and equipConfig[temp[i].id].limit == 1 and temp[i].upHero ~= "" then
            limitSoulPrint[temp[i].id] = temp[i].id
        end
    end
    for i = 1, #allData do
        --这个英雄没有装备这个魂印，并且可以装备,并且不在haveRedPointSid列表里
        if not allUpSoulPrint[allData[i].id] and  equipConfig[allData[i].id].Range and  equipConfig[allData[i].id].Range[1] == 0 and allData[i].upHero == "" and not haveRedPointSid[allData[i].id] then
            allData[i].isShowRedPot = 1--有空位可以穿戴
            haveRedPointSid[allData[i].id] = allData[i].id
        else
            allData[i].isShowRedPot = 0
        end

        local isHaveCurHeroid = false
        if equipConfig[allData[i].id].Range then
            for j = 1, #equipConfig[allData[i].id].Range do
                local heroId = equipConfig[allData[i].id].Range[j]
                if curHeroData.id == heroId then
                    isHaveCurHeroid = true
                end
            end
        end
        if not allUpSoulPrint[allData[i].id] and isHaveCurHeroid and allData[i].upHero == "" and not  haveRedPointSid[allData[i].id] then
            allData[i].isShowRedPot = 1--有空位可以穿戴
            haveRedPointSid[allData[i].id] = allData[i].id
        end

        if limitSoulPrint[allData[i].id] then
            allData[i].isShowRedPot = 0
        end      
    end
    table.sort(allData, function(a,b)   
        if a.isShowRedPot > b.isShowRedPot then
           return true
        elseif a.isShowRedPot == b.isShowRedPot then          
            if equipConfig[a.id].Quality == equipConfig[b.id].Quality then
                return a.id > b.id
             else
                 return equipConfig[a.id].Quality > equipConfig[b.id].Quality
             end
        else
            return false
        end
    end)
end

--获取当前英雄是否已装备该魂印
function this.GetCurHeroSoulPrintState(id)
    for k=1,#curHeroData.soulPrintList do       
        local _id=curHeroData.soulPrintList[k].equipId
        if _id==id then
            return true
        end
    end
    return false
end

return SoulPrintPanel