require("Base/BasePanel")
BagResolveAnCompoundPanel = Inherit(BasePanel)
local this = BagResolveAnCompoundPanel
--分解
local openLayoutType = 1--1 layout1  2 layout3  分解 还是 合成
local itemResolveType = 1--分解物品类型 1 道具  2 装备
local itemList = {}
local resolveStrList = { GetLanguageStrById(10191),GetLanguageStrById(10192),GetLanguageStrById(10193),GetLanguageStrById(10194),GetLanguageStrById(10195),GetLanguageStrById(10196),GetLanguageStrById(10197),GetLanguageStrById(10198)}
local resolveBtnList = {}--0 是全部
local resolveBooleList = {false,false,false,false,false,false,false,false}
local curSelectQuantityList = {}--当前选择后的稀有度 选项  {0 = true，1 = false  ...}  稀有度是依次减小的
local curResolveAllItemList = {}--最终向后段发送的分解list
local isShowTishi = false

--碎片合成
local itemData
local compoundNum = 0
local compoundMaxNum = 0

--装备单个分解
local equipData

local callBackFun

local count
--初始化组件（用于子类重写）
function BagResolveAnCompoundPanel:InitComponent()
	this.mask = Util.GetGameObject(self.gameObject, "mask")
	this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.nameText = Util.GetGameObject(self.gameObject, "bg/nameText"):GetComponent("Text")
    this.layout1 = Util.GetGameObject(self.gameObject, "bg/layout1")
    this.layout2 = Util.GetGameObject(self.gameObject, "bg/layout2")
    this.layout3 = Util.GetGameObject(self.gameObject, "bg/layout3")
    --分解道具
    this.btnesolve = Util.GetGameObject(self.gameObject, "bg/layout1/btnSure")
    this.btnSure = Util.GetGameObject(self.gameObject, "bg/layout2/btnSure")
    for i = 1, 8 do
        resolveBtnList[i] = Util.GetGameObject(self.gameObject, "bg/layout1/btns/btn ("..i..")")
        Util.GetGameObject(resolveBtnList[i], "Text"):GetComponent("Text").text = resolveStrList[i]
    end
    this.layout2Text = Util.GetGameObject(self.gameObject, "bg/layout2/Text"):GetComponent("Text")
    --碎片合成
    this.frame = Util.GetGameObject(self.gameObject, "bg/layout3/frame"):GetComponent("Image")
    this.icon = Util.GetGameObject(self.gameObject, "bg/layout3/icon"):GetComponent("Image")
    this.Slider = Util.GetGameObject(self.gameObject, "bg/layout3/Slider")--:GetComponent("Slider")
    this.numText = Util.GetGameObject(self.gameObject, "bg/layout3/numText"):GetComponent("Text")
    this.resolveName = Util.GetGameObject(self.gameObject, "bg/layout3/name"):GetComponent("Text")
    this.addBtn = Util.GetGameObject(self.gameObject, "bg/layout3/addBtn")
    this.jianBtn = Util.GetGameObject(self.gameObject, "bg/layout3/jianBtn")
    this.btnCompound = Util.GetGameObject(self.gameObject, "bg/layout3/btnCompound")
    this.btnCompoundText = Util.GetGameObject(self.gameObject,"bg/layout3/btnCompound/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function BagResolveAnCompoundPanel:BindEvent()
	Util.AddClick(this.mask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    for i = 0, 7 do
        Util.AddClick(resolveBtnList[i+1], function()
            this.OnShowLayout1Single(resolveBtnList[i+1],i)
        end)
    end
    Util.AddClick(this.btnesolve, function()
        this.SendBackResolveRe()
    end)
    Util.AddClick(this.btnSure, function()
        if openLayoutType == 1 then
            if #curResolveAllItemList > 0 then
                local type
                if itemResolveType == 1 then
                    type = 2
                else
                    type = 1
                end
                NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                    this.SendBackResolveReCallBack(drop)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10199)
            end
        elseif openLayoutType == 2 then
            UIManager.ClosePanel(UIName.RewardEquipSingleShowPopup)
            if equipData then
                curResolveAllItemList = {}
                local equip = {}
                equip.itemId = equipData.id
                if not count then
                    equip.itemNum = 1
                else
                    equip.itemNum = count
                end
                table.insert(curResolveAllItemList,equip)
                local type = 1
                NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                    this.SendBackResolveReCallBack(drop)
                end)
            end
        end
    end)

    Util.AddSlider(this.Slider, function(go, value)
        this.ShowCompoundNumData(value)
    end)
    Util.AddClick(this.addBtn, function()
        if compoundNum < compoundMaxNum then
            compoundNum = compoundNum + 1
            this.ShowCompoundNumData(compoundNum)
        end
    end)
    Util.AddClick(this.jianBtn, function()
        if compoundNum >= 2 then
            compoundNum = compoundNum - 1
            this.ShowCompoundNumData(compoundNum)
        end
    end)
    Util.AddClick(this.btnCompound, function()
        if itemData.itemConfig.ItemType == ItemType.HeroDebris then--碎片
            if compoundNum > 0 then
                local item = {}
                item.itemId = itemData.id
                item.itemNum = compoundNum * itemData.itemConfig.UsePerCount

                --催化剂
                if itemData.itemConfig.PropertyName == 7 then
                    NetManager.HeroComposeRequest(item,function (drop)
                        this.SendBackCompoundReCallBack(drop)
                    end)
                else
                    --英雄碎片
                    NetManager.BackpackLimitRequest(function(msg)
                        local heroNum = #HeroManager.GetAllHeroDatasAndZero()
                        local limit = msg.backpackLimitCount
                        if heroNum + compoundNum <= limit then
                            NetManager.HeroComposeRequest(item,function (drop)
                                this.SendBackCompoundReCallBack(drop)

                                local itemList = {}
                                local itemDataStarList = {}
                                local itemDataList = BagManager.GetItemListFromTempBag(drop)
                                for i, v in ipairs(itemDataList) do
                                    local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", v.sId)
                                    if heroData.Star > 3 then
                                        local state = true
                                        for index, value in ipairs(itemList) do
                                            if v.sId == value.Id then
                                                state = false
                                            end
                                        end
                                        if state then
                                            table.insert(itemList,heroData)
                                            table.insert(itemDataStarList,heroData.Star)
                                        end
                                    end
                                end
                                if #itemList > 0 then
                                    this.rewardItemPopup.gameObject:SetActive(false)
                                    UIManager.OpenPanel(UIName.PublicGetHeroPanel,itemList,itemDataStarList,function ()
                                        this.rewardItemPopup.gameObject:SetActive(true)
                                    end)
                                end
                            end)
                        else
                            PopupTipPanel.ShowTipByLanguageId(10671)
                        end
                    end)
                end
            else
                PopupTipPanel.ShowTipByLanguageId(10200)
            end
        elseif itemData.itemConfig.ItemType == ItemType.Box then--宝箱
            if compoundNum > 0 then
                local item = {}
                local itemList = {}
                item.itemId = itemData.id
                item.itemNum = compoundNum--*itemData.itemConfig.UsePerCount
                table.insert(itemList,item)
                
                NetManager.UseAndPriceItemRequest(0,itemList,function (drop)
                    this.SendBackCompoundReCallBack(drop)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10201)
            end
        else
            if compoundNum > 0 then
                UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
                curResolveAllItemList = {}
                local item = {}
                item.itemId = itemData.id
                item.itemNum = compoundNum
                table.insert(curResolveAllItemList,item)
                local type
                if itemData.itemConfig.ItemBaseType == ItemBaseType.Equip then
                    type = 2
                else
                    type = 1
                end
                NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                    this.SendBackResolveReCallBack(drop)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10202)
            end
        end
    end)
end

--添加事件监听（用于子类重写）
function BagResolveAnCompoundPanel:AddListener()
end

--移除事件监听（用于子类重写）
function BagResolveAnCompoundPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BagResolveAnCompoundPanel:OnOpen(...)
    local data = {...}
    openLayoutType = data[1]
    if openLayoutType == 1 then--批量分解
        itemResolveType = data[2]
        itemList = data[3]
        this.OnShowLayout1Data()
        callBackFun = data[4]
        if itemResolveType == 4 then--特殊页签
            resolveBtnList[2]:SetActive(true)
            resolveBtnList[3]:SetActive(true)
        else
            resolveBtnList[2]:SetActive(false)
            resolveBtnList[3]:SetActive(false)
        end
    elseif openLayoutType == 2 then--
        itemResolveType = data[2]
        equipData = data[3]
        callBackFun = data[4]
        count = data[5]
        this.OnShowLayout2Data()
    elseif openLayoutType == 3 then--碎片合成
        itemData = data[2]
        callBackFun = data[3]
        this.OnShowLayout3Data()
    elseif openLayoutType == 4 then--宝箱使用
        itemData = data[2]
        callBackFun = data[3]
        this.OnShowLayout3Data()
    end
end
--初始化Layout1
function this.OnShowLayout1Data()
    this.nameText.text = GetLanguageStrById(10203)
    this.layout1:SetActive(true)
    this.layout2:SetActive(false)
    this.layout3:SetActive(false)
    curSelectQuantityList = {}
    resolveBooleList = {false,false,false,false,false,false,false,false}
    for i = 1, #resolveBooleList do
        Util.GetGameObject(resolveBtnList[i], "Image"):SetActive(resolveBooleList[i])
    end
end
--设置单个
function this.OnShowLayout1Single(_btnGo,_index)--_index  0-7
    if _index == 0 then--选择全部
          resolveBooleList[1] = not resolveBooleList[1]
        resolveBooleList = {resolveBooleList[1],false,false,false,false,false,false,false}
        for i = 1, 8 do--按钮八个
            Util.GetGameObject(resolveBtnList[i], "Image"):SetActive(resolveBooleList[i])
        end
        for i = 1, 7 do--稀有度就七个
            curSelectQuantityList[i] = resolveBooleList[i+1]
        end
    else--选择其他
        if resolveBooleList[1] == true then
            resolveBooleList[1] = false
            curSelectQuantityList[1] = false
            Util.GetGameObject(resolveBtnList[1], "Image"):SetActive(resolveBooleList[1])
        end
        resolveBooleList[_index+1] = not  resolveBooleList[_index + 1]
        curSelectQuantityList[9 - (_index + 1)] = resolveBooleList[_index + 1]
        Util.GetGameObject(_btnGo, "Image"):SetActive(resolveBooleList[_index + 1])
    end
    -- for k,v in pairs(curSelectQuantityList) do 
    -- end
end

--初始化Layout2
function this.OnShowLayout2Data()
    this.layout1:SetActive(false)
    this.layout2:SetActive(true)
    this.layout3:SetActive(false)
    if openLayoutType == 1 then--批量分解
        this.nameText.text = GetLanguageStrById(10204)
        this.layout2Text.text = GetLanguageStrById(10205)
    elseif openLayoutType == 2 then--单个装备分解
        this.nameText.text = GetLanguageStrById(10206)
        this.layout2Text.text = GetLanguageStrById(10207)..GetQuantityStrByquality(ConfigManager.GetConfigData(ConfigName.ItemConfig, equipData.id).Quantity)..GetLanguageStrById(10208)
    end
end
--初始化Layout3
function this.OnShowLayout3Data()
    this.layout1:SetActive(false)
    this.layout2:SetActive(false)
    this.layout3:SetActive(true)
    this.frame.sprite = Util.LoadSprite(itemData.frame)
    this.icon.sprite = Util.LoadSprite(itemData.icon)
    this.resolveName.text = GetStringByEquipQua(itemData.quality, GetLanguageStrById(itemData.itemConfig.Name))

    local gameSetting = ConfigManager.GetConfigData(ConfigName.GameSetting, 1)
    if itemData.itemConfig.ItemType == ItemType.HeroDebris then--碎片
        this.nameText.text = GetLanguageStrById(10209)
        this.btnCompoundText.text = GetLanguageStrById(10210)
        local maxCompoundValue = math.floor(itemData.num/itemData.itemConfig.UsePerCount)
        compoundMaxNum = maxCompoundValue > gameSetting.HeroCompoundLimit and gameSetting.HeroCompoundLimit or maxCompoundValue
        local endHeroNum = gameSetting.HeroNumlimit-LengthOfTable(HeroManager.heroDataLists)
        compoundMaxNum = compoundMaxNum > endHeroNum and endHeroNum or compoundMaxNum
    elseif itemData.itemConfig.ItemType == ItemType.Box then--宝箱
        this.nameText.text = GetLanguageStrById(10211)
        this.btnCompoundText.text = GetLanguageStrById(10212)
        local maxCompoundValue = itemData.num-- math.floor(itemData.num/itemData.itemConfig.UsePerCount)
        compoundMaxNum = maxCompoundValue > gameSetting.OpenBoxLimits and gameSetting.OpenBoxLimits or maxCompoundValue
    else
        itemResolveType = itemData.itemConfig.ItemBaseType
        this.nameText.text = GetLanguageStrById(10213)
        this.btnCompoundText.text = GetLanguageStrById(10214)
        compoundMaxNum = itemData.num
    end
        compoundNum = 1
        this.Slider:GetComponent("Slider").value = 1
        compoundNum = compoundNum >= compoundMaxNum and compoundMaxNum or compoundNum
       
        this.Slider:GetComponent("Slider").minValue = 0
        this.Slider:GetComponent("Slider").maxValue = compoundMaxNum
        --this.ShowCompoundNumData(compoundNum)
        this.ShowCompoundNumData(compoundMaxNum)
    end
--道具 和 装备分解 发送请求
function this.SendBackResolveRe()
    isShowTishi = false
    curResolveAllItemList = {}
   
    if itemResolveType == ItemBaseType.Equip then--装备
        for i = 1, #itemList do
            if resolveBooleList[1] == true and itemList[i].itemConfig.IfResolve == 1 then
                if itemList[i].equipConfig.Quality >= 4 then
                    isShowTishi = true
                end
                table.insert(curResolveAllItemList,itemList[i].did)
            else
                if curSelectQuantityList[itemList[i].equipConfig.Quality] == true and itemList[i].itemConfig.IfResolve==1 then
                    if itemList[i].equipConfig.Quality >= 4 then
                        isShowTishi = true
                    end
                    table.insert(curResolveAllItemList,itemList[i].did)
                end
            end
        end
    else--道具
        for i = 1, #itemList do
            if resolveBooleList[1] == true and itemList[i].itemConfig.IfResolve == 1 then
                if itemList[i].itemConfig.Quantity >= 4 then
                    isShowTishi = true
                end
                local item = {}
                item.itemId = itemList[i].id
                item.itemNum = itemList[i].num
                item.endingTime = itemList[i].endingTime
                table.insert(curResolveAllItemList,item)
            else
                if curSelectQuantityList[itemList[i].itemConfig.Quantity] == true and  itemList[i].itemConfig.IfResolve == 1 then
                    if itemList[i].itemConfig.Quantity >= 4 then
                        isShowTishi = true
                    end
                    local item = {}
                    item.itemId = itemList[i].id
                    item.itemNum = itemList[i].num
                    item.endingTime = itemList[i].endingTime
                    table.insert(curResolveAllItemList,item)
                end
            end
        end
    end
   
    --for i = 1, #curResolveAllItemList do
    
    --end
    if isShowTishi then
        this.OnShowLayout2Data()
    else
        if #curResolveAllItemList > 0 then
            local type
            if itemResolveType == ItemBaseType.Equip then
                type = 2
            else
                type = 1
            end
            NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                this.SendBackResolveReCallBack(drop)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10199)
        end
    end
end
--道具 和 装备分解 发送请求后 回调
function this.SendBackResolveReCallBack(drop)
    this:ClosePanel()
    local isShowReward = false
    if drop.itemlist ~= nil and #drop.itemlist > 0 then
        for i = 1, #drop.itemlist do
            if drop.itemlist[i].itemNum > 0 then
                isShowReward = true
                break
            end
        end
    end
    if isShowReward then
        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function ()
            BagManager.OnShowTipDropNumZero(drop)
            if callBackFun then
                callBackFun()
            end
        end)
    else
        BagManager.OnShowTipDropNumZero(drop)        
    end
    if callBackFun then
        callBackFun()
    end
end
function this.SendBackCompoundReCallBack(drop)
    this:ClosePanel()
    this.rewardItemPopup = UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function ()
        --UIManager.OpenPanel(UIName.BagPanel)
        if callBackFun then
            callBackFun()
        end
    end,nil,nil,nil,true)
    --改为后端刷新了
    --BagManager.UpdateItemsNum(itemData.id,compoundNum*itemData.itemConfig.UsePerCount)
end

function  this.ShowCompoundNumData(value)

    compoundNum = value
    this.Slider:GetComponent("Slider").value = value
    if itemData.itemConfig.ItemType == ItemType.HeroDebris then--碎片
        this.numText.text = GetLanguageStrById(10216)..value*itemData.itemConfig.UsePerCount..GetLanguageStrById(10217)..value..GetLanguageStrById(10218).. string.gsub(GetLanguageStrById(itemData.itemConfig.Name),GetLanguageStrById(10219),"")
    elseif itemData.itemConfig.ItemType == ItemType.Box then--宝箱
        this.numText.text = GetLanguageStrById(10220)..value..GetLanguageStrById(10218)..GetLanguageStrById(itemData.itemConfig.Name)..""
    else
        this.numText.text = GetLanguageStrById(10213)..value..GetLanguageStrById(10218)..GetLanguageStrById(itemData.itemConfig.Name)..""
    end
end
--界面关闭时调用（用于子类重写）
function BagResolveAnCompoundPanel:OnClose()
    if callBackFun then
        callBackFun()
    end
    this.rewardItemPopup = nil
end

--界面销毁时调用（用于子类重写）
function BagResolveAnCompoundPanel:OnDestroy()

end

return BagResolveAnCompoundPanel