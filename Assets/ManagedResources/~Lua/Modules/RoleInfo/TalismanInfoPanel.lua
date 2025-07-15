----- 法宝进阶面板 -----
require("Base/BasePanel")
TalismanInfoPanel = Inherit(BasePanel)
local this = TalismanInfoPanel
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local artResourcesConfig=ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local curTalismanConFig --EquipTalismana表数据
local nextTalismanConFig --EquipTalismana下一等级表数据

local curHeroData--当前英雄数据
local heroListData--全部英雄数据
local _heroListData={} --注意 这是筛选后的数据 本脚本当前英雄数据是从这里再被筛选出来的 匹配未满级的Hero
local data={}   --英雄表下法宝属性
local maxLv=0 --法宝最大进阶等级
local curLv=0 --当前法宝等级
local isMaxStar = false --默认不是最大进阶等级

--属性容器
local proList = {}

--进阶奖励容器
local upStarGrid={}
local itemGrid={}
local orginLayer
local index = 0

function TalismanInfoPanel:InitComponent()
    orginLayer =0
    self.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
    self.effect = Util.GetGameObject(self.gameObject,"Effect")
    self.backBtn = Util.GetGameObject(self.gameObject, "btnBack/btnBack")
    self.upStarBtn = Util.GetGameObject(self.gameObject, "upStarBtn")
    self.leftBtn = Util.GetGameObject(self.gameObject, "LeftBtn")
    self.rightBtn = Util.GetGameObject(self.gameObject, "RightBtn")
    self.helpBtn=Util.GetGameObject(self.gameObject,"HelpBtn")
    self.helpPosition=self.helpBtn:GetComponent("RectTransform").localPosition

    --法宝战力
    self.force = Util.GetGameObject(self.gameObject, "PowerBtn/PowerBtns/Value"):GetComponent("Text")  -- m5
    self.addForce=Util.GetGameObject(self.gameObject,"PowerBtn/PowerBtns/AddValue"):GetComponent("Text")  -- m5
    self.upLvEffect = Util.GetGameObject(self.gameObject,"PowerBtn/PowerBtns/Effect")
    --法宝icon
    -- self.talismanRoot = Util.GetGameObject(self.gameObject, "TalismanRoot"):GetComponent("Image")  m5
    self.talismanIcon = Util.GetGameObject(self.gameObject, "TalismanRoot/icon"):GetComponent("Image")
    --英雄名称
    self.talismanOldNameObj=Util.GetGameObject(self.gameObject, "TalismanRoot/Panel/OldName")
    self.talismanOldName = Util.GetGameObject(self.talismanOldNameObj, "Text"):GetComponent("Text")
    self.talismanNewNameObj=Util.GetGameObject(self.gameObject,"TalismanRoot/Panel/NewName")
    self.talismanNewName=Util.GetGameObject(self.talismanNewNameObj,"Text"):GetComponent("Text")
    self.image=Util.GetGameObject(self.gameObject,"TalismanRoot/Image"):GetComponent("Image")--三角图标

    --属性
    self.upStarMaterialInfo = Util.GetGameObject(self.transform,"downGo/upStarMaterialInfo")
    self.noUpStarText = Util.GetGameObject(self.transform,"downGo/noUpStarText")

    --属性预设
    self.proPre=Util.GetGameObject(self.gameObject,"downGo/proGrid/Root/ProPre")
    --属性列表父物体
    self.proRoot=Util.GetGameObject(self.gameObject,"downGo/proGrid/Root")

    --天赋激活信息
    self.skillInfoText = Util.GetGameObject(self.transform, "downGo/skillInfo/Mask/Text"):GetComponent("Text")
    --进阶材料根节点
    for i=1,3 do
        upStarGrid[i] = Util.GetGameObject(self.gameObject, "downGo/upStarMaterialInfo/upStarGrid/item"..i)
    end
    --金币 姚晶材料
    for n=1,2 do
        itemGrid[n]=Util.GetGameObject(self.gameObject,"downGo/upStarMaterialInfo/itemGrid/item"..n)
    end
end

function TalismanInfoPanel:BindEvent()
    Util.AddClick(self.backBtn, function()
        UIManager.OpenPanel(UIName.RoleTalismanPanelV2,curHeroData,heroListData)
        self:ClosePanel()
    end)
    Util.AddClick(self.upStarBtn, function()
        if HeroManager.GetTalismanLv(curHeroData.dynamicId)>= maxLv then
            PopupTipPanel.ShowTipByLanguageId(11846)
            return
        end
        --需要判断材料够不够
        local tip={}
        for i=1,#curTalismanConFig.RankupBasicMaterial do
            local id=curTalismanConFig.RankupBasicMaterial[i][1]--物品ID
            local needNum=curTalismanConFig.RankupBasicMaterial[i][2]--需要物品数量
            local haveNum=BagManager.GetItemCountById(id)--已有物品数量
            if haveNum<needNum then
                table.insert(tip,itemConfig[id].Name)
            end
        end
        if #tip>0 then --有东西不足了
            if #tip==1 then --一个不足时
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343),tip[1]))
            else
                for j = 1, #tip do --多个不足 加逗号
                    if j~=1 then
                        tip[j]="，"..tip[j]
                    end
                end
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343),table.concat(tip)))
            end
            return
        end
        NetManager.TalismanUpStarRequest(tostring(curHeroData.dynamicId),function (msg)
            HeroManager.SetTalismanLv(curHeroData.dynamicId,curHeroData.talismanList+1)--本地标记等级
            UIManager.OpenPanel(UIName.TalismanUpStarSuccessPanel,curHeroData,function ()
                self:OnShowPanelData()
            end,function() self:ClosePanel() end)
        end)
    end)
    Util.AddClick(self.leftBtn, function()
        self:LeftBtnOnClick()
    end)
    Util.AddClick(self.rightBtn, function()
        self:RightBtnOnClick()
    end)
    --帮助按钮
    Util.AddClick(self.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.NewTalismanUp,self.helpPosition.x,self.helpPosition.y)
    end)
end

function TalismanInfoPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.BugCoin.OnBuyCoinUpdate, this.ShowUpStarGridData)
end

function TalismanInfoPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.BugCoin.OnBuyCoinUpdate, this.ShowUpStarGridData)
end

function TalismanInfoPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

function TalismanInfoPanel:OnOpen(_curHeroData,_heroListData)
    curHeroData = _curHeroData
    heroListData=_heroListData
end

function TalismanInfoPanel:OnShow()
    self.upView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType =  PanelType.Talisman })
    isMaxStar = false

    --拿到全部已激活数据 需要筛选出未满级的数据
    for i = 1, #heroListData do
        local d=ConfigManager.GetConfigData(ConfigName.HeroConfig,heroListData[i].id).EquipTalismana--当前法宝数据 data[1]星级 data[2]法宝ID
        local mLv=TalismanManager.AllTalismanEndStar[d[2]]
        local lv= HeroManager.GetTalismanLv(heroListData[i].dynamicId)
        if lv<mLv then
            table.insert( _heroListData,heroListData[i])
        end
    end
    for j=1,#_heroListData do
        if curHeroData == _heroListData[j] then
            index = j
        end
    end
    --已激活法宝的Hero为1时 隐藏左右按钮
    self.leftBtn:SetActive(#heroListData>1)
    self.rightBtn:SetActive(#heroListData>1)
    self:OnShowPanelData()
end

--显示
function TalismanInfoPanel:OnShowPanelData()
    data=ConfigManager.GetConfigData(ConfigName.HeroConfig,curHeroData.id).EquipTalismana--当前法宝数据 data[1]星级 data[2]法宝ID
    --获取最大等级
    TalismanManager.GetStartAndEndStar()
    maxLv=TalismanManager.AllTalismanEndStar[data[2]]
    --获取当前法宝等级
    curLv=HeroManager.GetTalismanLv(curHeroData.dynamicId)

    --获取当前等级与下一等级表数据
    local nextLv=0
    if (curLv+1) <= maxLv then
        nextLv=curLv+1
    end
    isMaxStar = curLv >= maxLv

    curTalismanConFig= ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana,"Level",curLv,"TalismanaId",data[2])
    nextTalismanConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId",  data[2], "Level", nextLv)

    --法宝战力
    local curPower = TalismanManager.CalculateWarForceBase(curTalismanConFig,0)
    local nextPower=TalismanManager.CalculateWarForceBase(nextTalismanConFig,0)
    self.force.text = curPower
    self.addForce.text="+"..(nextPower-curPower)
    --法宝Icon 边框品质
    -- self.talismanRoot.sprite = Util.LoadSprite(TalismanBubble[itemConfig[data[2]].Quantity])  m5
    self.talismanIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[data[2]].ResourceID))

    self.talismanNewNameObj:SetActive(not isMaxStar)
    self.image.enabled= not isMaxStar
    if isMaxStar==false then
        self.talismanOldName.text=string.format( "%s+%s",GetLanguageStrById(itemConfig[data[2]].Name),curLv)
        self.talismanNewName.text=string.format( "%s<color=#FE5022>+%s</color>",GetLanguageStrById(itemConfig[data[2]].Name),curLv+1)
    else
        self.talismanOldName.text = string.format( "%s+%s",GetLanguageStrById(itemConfig[data[2]].Name),maxLv)
    end

    self:ShowProAndSkillData()
    this.ShowUpStarGridData() --self真的很坑
end

--显示属性提升、天赋激活信息
function TalismanInfoPanel:ShowProAndSkillData()
    self.upStarMaterialInfo:SetActive(not isMaxStar)
    self.noUpStarText:SetActive(isMaxStar)

    --设置属性提升
    for i=1,#curTalismanConFig.Property do
        local item= proList[i]
        if not item then
            item= newObjToParent(self.proPre,self.proRoot)
            item.name="ProPre"..i
            proList[i]=item
        end
        local icon=Util.GetGameObject(proList[i],"Icon"):GetComponent("Image")
        local proName=Util.GetGameObject(proList[i],"ProName"):GetComponent("Text")
        local proValue=Util.GetGameObject(proList[i],"ProValue"):GetComponent("Text")
        local nextProValue=Util.GetGameObject(proList[i],"NextProValue"):GetComponent("Text")

        local skillId=curTalismanConFig.Property[i][1]
        local curValue=curTalismanConFig.Property[i][2]
        local nextValue=nextTalismanConFig.Property[i][2]

        icon.sprite=Util.LoadSprite(artResourcesConfig[propertyConfig[skillId].PropertyIcon].Name)
        icon:SetNativeSize()
        proName.text= propertyConfig[skillId].Info
        proValue.text=curValue
        nextProValue.text=nextValue
    end

    --显示法宝天赋
    --筛选出符合要求的数据
    local dowerAllData= ConfigManager.GetAllConfigsDataByKey(ConfigName.EquipTalismana,"TalismanaId",data[2])
    local dowerData={}--当前法宝全部技能开放数据
    for i=1,#dowerAllData do
        if dowerAllData[i].OpenSkillRules then
            table.insert( dowerData, dowerAllData[i])
        end
    end
    table.sort(dowerData, function(a,b) return a.OpenSkillRules[1]<b.OpenSkillRules[1] end)

    local skillId=ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana,"Level",self:GetTargetLv(dowerData),"TalismanaId",data[2]).OpenSkillRules[1]
    self.skillInfoText.text=string.format( GetLanguageStrById(11611),passiveSkillConfig[skillId].Desc,self:GetTargetLv(dowerData))
end

--根据当前法宝等级获取法宝最近的下一等级
function TalismanInfoPanel:GetTargetLv(dowerData)
    for j=1,#dowerData do
        if dowerData[j].Level> curLv then
            return dowerData[j].Level
        end
    end
end

--显示进阶信息
function this.ShowUpStarGridData()
    if isMaxStar then return end
    --关闭激活
    for n=1,#upStarGrid do
        upStarGrid[n].gameObject:SetActive(false)
    end
    for m=1,#itemGrid do
        itemGrid[m].gameObject:SetActive(false)
    end

    --数据拆分
    local upStarData={}--不包含金币姚晶的数据
    local itemData={}--金币姚晶的数据
    --根据消耗材料显示
    for i=1,#curTalismanConFig.RankupBasicMaterial do
        local _data=curTalismanConFig.RankupBasicMaterial[i]
        local itemId=_data[1]
        if itemId==14 or itemId==16 then
            table.insert(itemData, _data)
        else
            table.insert(upStarData, _data)
        end
    end

    --赋值
    for x=1,#upStarData do
        upStarGrid[x].gameObject:SetActive(true)
        local id=upStarData[x][1]--物品ID
        local needNum=upStarData[x][2]--需要物品数量
        local haveNum=BagManager.GetItemCountById(id)--已有物品数量

        local info=""
        if haveNum>=needNum then
            info=haveNum.."/"..needNum
        else
            info="<color=red>"..haveNum.."/"..needNum.."</color>"
        end

        local frame=Util.GetGameObject(upStarGrid[x],"frame"):GetComponent("Image")
        local icon=Util.GetGameObject(upStarGrid[x],"icon"):GetComponent("Image")
        local num=Util.GetGameObject(upStarGrid[x],"num"):GetComponent("Text")
        frame.sprite=Util.LoadSprite(GetHeroQuantityImageByquality(itemConfig[id].Quantity))
        icon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[id].ResourceID))
        num.text=info
        Util.AddOnceClick(frame.gameObject,function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,id)
        end)
    end
    for y=1,#itemData do
        itemGrid[y].gameObject:SetActive(true)
        local id=itemData[y][1]--物品ID
        local haveNum=BagManager.GetItemCountById(id)--已有物品数量
        local needNum=itemData[y][2]--需要物品数量
        local icon=Util.GetGameObject(itemGrid[y],"icon"):GetComponent("Image")
        local num=Util.GetGameObject(itemGrid[y],"num"):GetComponent("Text")
        icon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[id].ResourceID))
        if haveNum>=needNum then
            num.text=PrintWanNum2(needNum)
        else
            num.text="<color=red>"..PrintWanNum2(needNum).."</color>"
        end
    end
end

--右切换按钮点击
function TalismanInfoPanel:RightBtnOnClick()
    index = (index + 1 <= #_heroListData and index + 1 or 1)
    curHeroData = _heroListData[index]
    self:OnShowPanelData()
end
--左切换按钮点击
function TalismanInfoPanel:LeftBtnOnClick()
    index = (index - 1 > 0 and index - 1 or #_heroListData)
    curHeroData = _heroListData[index]
    self:OnShowPanelData()
end

function TalismanInfoPanel:OnClose()
end

function TalismanInfoPanel:OnDestroy()
    SubUIManager.Close(self.upView)
    proList={}
end

return TalismanInfoPanel