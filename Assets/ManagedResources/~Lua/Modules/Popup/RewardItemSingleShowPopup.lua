require("Base/BasePanel")
RewardItemSingleShowPopup = Inherit(BasePanel)
local this = RewardItemSingleShowPopup
local JumpConfig = ConfigManager.GetConfig(ConfigName.JumpConfig)
local itemSid
local heroBackData
local itemConfigData
local itemNu = 0
local func
local armorType = 0
local lanTuData = {}
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

local isBagPanel = false
--初始化组件（用于子类重写）
function RewardItemSingleShowPopup:InitComponent()

    this.itemName = Util.GetGameObject(self.transform, "bg/Content/armorInfo/name"):GetComponent("Text")
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.BackMask = Util.GetGameObject(self.transform, "BackMask")
    this.icon = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/icon"):GetComponent("Image")
    this.frameMask = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/frameMask")
    this.frame = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/frame")
    this.fragmentBG = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/fragmentBG")
    -- this.pokemonFrame = Util.GetGameObject(self.transform, "bg/Content/armorInfo/pokemonFrame") --n1
    -- this.pokemonImage = Util.GetGameObject(self.transform, "bg/Content/armorInfo/pokemonFrame/pokemonImage"):GetComponent("Image") --n1
    this.armorType = Util.GetGameObject(self.transform, "bg/Content/armorInfo/armorType"):GetComponent("Text")
    -- this.armorLanTuNum = Util.GetGameObject(self.transform, "armorInfo/armorLanTuNum") --n1
    this.armorInfo = Util.GetGameObject(self.transform, "bg/Content/armorInfoText"):GetComponent("Text")
    this.btnJump = Util.GetGameObject(self.transform, "bg/Content/btnGrid/btnJump")
    this.btnSure = Util.GetGameObject(self.transform, "bg/Content/btnGrid/btnSure")
    this.btnSureText = Util.GetGameObject(this.btnSure.transform, "Text"):GetComponent("Text")
    -- this.equipQuaText = Util.GetGameObject(self.transform, "bg/Content/armorInfo/equipQuaText"):GetComponent("Text") --n1
    this.innateImage = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/innateImage")
    this.fragmentIcon = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/fragmentBG/fragmentIcon")
    this.innateText = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/innateImage/Text"):GetComponent("Text")

    this.equipProGrid = Util.GetGameObject(self.transform, "bg/Content/scroll")
    this.btnGrid = Util.GetGameObject(self.transform, "bg/Content/btnGrid")

    this.geneLv = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/geneLv"):GetComponent("Image")
end

--绑定事件（用于子类重写）
function RewardItemSingleShowPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BtnBack, function()
        --PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.btnSure, function()
        self:ClosePanel()
        if itemConfigData.ItemType == ItemType.HeroDebris then
            if BagManager.GetItemCountById(itemSid) >= BagManager.bagDatas[itemSid].itemConfig.UsePerCount then
                local _itemData = BagManager.bagDatas[itemSid]
                UIManager.OpenPanel(UIName.BagResolveAnCompoundPanel, 3, _itemData, function()
                    func()

                end)              
            else
                PopupTipPanel.ShowTipByLanguageId(11592)
            end
        elseif itemConfigData.ItemType == ItemType.Blueprint then
            if lanTuData and lanTuData[1] == true then
                local _itemData = BagManager.bagDatas[itemSid]
                UIManager.OpenPanel(UIName.BagResolveAnCompoundPanel, 3, _itemData, function()
                    func()
                end)
            elseif lanTuData and lanTuData[1] == false and lanTuData[2] > 0 then
                NetManager.GetWorkShopAvtiveLanTuRequest(lanTuData[2], 2, function()
                    --刷新工坊解锁蓝图数据
                    this.DeleteActiveLanTuData()
                end)
            end
        elseif itemConfigData.ItemType == ItemType.Box then
            local _itemData = BagManager.bagDatas[itemSid]
            if itemConfig[itemSid].UseType ~= 2 then
                UIManager.OpenPanel(UIName.BagResolveAnCompoundPanel, 4, _itemData, function()
                    func()
                end)
            end
        elseif itemConfigData.ItemType == ItemType.ChangeName then
            UIManager.OpenPanel(UIName.CreateNamePopup)
        else
            local _itemData = BagManager.bagDatas[itemSid]
            UIManager.OpenPanel(UIName.BagResolveAnCompoundPanel, 3, _itemData, function()
                func()
            end)
        end
    end)
    Util.AddClick(this.btnJump, function()
        self:ClosePanel()
        if itemConfigData then
            JumpManager.GoJump(itemConfigData.UseJump) 
        end
    end)
end
--扣除解锁蓝图材料 并数据
function this.DeleteActiveLanTuData()
    PopupTipPanel.ShowTip(GetLanguageStrById(11593) .. itemConfigData.Name)
    if lanTuData and lanTuData[1] == false and lanTuData[2] > 0 then
        WorkShopManager.UpdataWorkShopLanTuActiveState(2, lanTuData[2], itemConfigData.Id)--
    end
    if func then
        func()
    end
    this:ClosePanel()
end
--添加事件监听（用于子类重写）
function RewardItemSingleShowPopup:AddListener()

end

--移除事件监听（用于子类重写）
function RewardItemSingleShowPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RewardItemSingleShowPopup:OnOpen(...)

    isBagPanel = BagManager.isBagPanel
    itemNu = 0
    local data = { ... }
    itemSid = data[1]
    itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemSid)
    this.isRewardItemPop = data[3]
    LogGreen("道具ID："..itemSid)
    if data[2] then
        func = data[2]
    end
end
function RewardItemSingleShowPopup:OnShow()
    this.innateImage:SetActive(false)
    this.fragmentBG:SetActive(false)
    this.geneLv.gameObject:SetActive(false)

    --判断自选宝箱界面是否开启
    local isBoxOpen = UIManager.IsOpen(314)
    if isBagPanel and isBoxOpen then
        this.btnSure:SetActive(false)
    elseif isBagPanel and itemConfigData.IfResolve == 1 and  func then--是否可分解
        if itemConfigData.ItemType == 2 then
            this.btnSureText.text = GetLanguageStrById(10210)
        end
        this.btnSure:SetActive(true)
        if itemConfigData.ItemType == 24 then
            this.btnSure:SetActive(false) --< todo
        end
    elseif isBagPanel and itemConfigData.ItemType == 2 and func then--是否是碎片可合成
        this.btnSureText.text = GetLanguageStrById(10210)
        this.btnSure:SetActive(true)
    elseif isBagPanel and itemConfigData.ItemType == 10 and func then--是否宝箱可使用
        this.btnSure:SetActive(true)
        this.btnSureText.text = GetLanguageStrById(10212)
    elseif isBagPanel and itemConfigData.ItemType == 12 and func then-- 改名卡
        this.btnSure:SetActive(true)
        this.btnSureText.text = GetLanguageStrById(10212)
    else
        this.btnSure:SetActive(false)
        this.btnSureText.text = GetLanguageStrById(10214)
    end
    this.btnJump:SetActive(itemConfigData.UseJump and itemConfigData.UseJump > 0 and isBagPanel)
    -- this.equipQuaText.text = GetStringByEquipQua(itemConfigData.Quantity, GetQuaStringByEquipQua(itemConfigData.Quantity)) --n1
    this.itemName.text = GetStringByEquipQua(itemConfigData.Quantity, GetLanguageStrById(itemConfigData.Name))
    -- if itemConfigData.ItemType==4 then --妖魂 --n1
    --     this.pokemonFrame:SetActive(true)
    --     this.frame:SetActive(false)
    --     this.pokemonFrame:GetComponent("Image").sprite = Util.LoadSprite(YaoHunFrame[itemConfigData.Quantity])
    --     this.pokemonImage.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    -- else
    --     this.frame:SetActive(true)
    --     this.pokemonFrame:SetActive(false)
    --     this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfigData.Quantity))
    --     this.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    -- end --n1
    this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfigData.Quantity))
    this.fragmentBG:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(itemConfigData.Quantity))
    this.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    this.armorType.text = GetLanguageStrById(this.getType())--道具类型显示
    -- this.armorLanTuNum:SetActive(true) --n1
    -- this.armorLanTuNum:GetComponent("Text").text = GetLanguageStrById(11595) .. BagManager.GetItemCountById(itemSid) --n1
    this.armorInfo.text = string.gsub(GetLanguageStrById(itemConfigData.ItemDescribe), "\\n", "")
    this.frameMask:SetActive(false)
    if itemConfigData.ItemType == 2 then
        this.frameMask:SetActive(true)
        this.frameMask:GetComponent("Image").sprite = Util.LoadSprite(GetHeroChipQuantityImageByquality(itemConfigData.Quantity))
        local propertyName = itemConfig[itemConfigData.Id].PropertyName
        if propertyName ~= 0 then
            this.fragmentBG:SetActive(true)
            this.fragmentIcon:GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(propertyName))
        end
    elseif itemConfigData.ItemType == 9 then
        if itemConfigData.RingLevel > 0 then
            this.innateImage:SetActive(true)
            this.innateText.text = "+" .. itemConfigData.RingLevel
        else
            this.innateImage:SetActive(false)
            this.innateText.text = ""
        end
    elseif itemConfigData.ItemType == ItemType.Gene then
        this.geneLv.gameObject:SetActive(true)
        this.geneLv.sprite = Util.LoadSprite(AircraftCarrierManager.GetSkillLvImgForId(itemConfigData.Id).lvImg)
    end

    --装备获得途径
    Util.ClearChild(this.equipProGrid.transform)
    if itemConfigData and itemConfigData.Jump then
        if itemConfigData.Jump and #itemConfigData.Jump>0 then
            local jumpSortData = {}
            local isLevel = false
            for i = 1, #itemConfigData.Jump do--为关卡跳转做的排序数据
                local jumpData = {}
                jumpData.id = itemConfigData.Jump[i]
                jumpData.data = JumpConfig[itemConfigData.Jump[i]]
                --jumpData.state = 0
                
                if jumpData.data.Type == JumpType.Level then--关卡按钮特殊处理
                    isLevel = true
                end
                table.insert(jumpSortData,jumpData)
            end
            for i = 1, #jumpSortData do
                if jumpSortData[i].id > 0 then
                    if not RECHARGEABLE then--（是否开启充值）
                        if this.isRewardItemPop == true or itemConfigData.Id == 61 or itemConfigData.Id == 19 then
                            SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSortData[i].id,false)
                        else
                            SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSortData[i].id,true)
                        end
                    else
                        if this.isRewardItemPop == true then
                            SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSortData[i].id,false)
                        else
                            SubUIManager.Open(SubUIConfig.JumpView, this.equipProGrid.transform, jumpSortData[i].id,true)
                        end
                    end
                end
            end
        end
    end
end

--获取道具种类
function this.getType()
    local type = GetLanguageStrById(itemConfig[itemSid].ItemTypeDes)
    -- if type == 1 then
    --     return GetLanguageStrById(11093)..GetLanguageStrById(12266)
    -- elseif type == 2 then
    --     return GetLanguageStrById(11093)..GetLanguageStrById(10219)
    -- elseif type == 4 then
    --     return GetLanguageStrById(11093)..GetLanguageStrById(12267)
    -- elseif type == 5 then
    --     return GetLanguageStrById(11093)..GetLanguageStrById(12268)
    -- elseif type == 6 then
    --     return GetLanguageStrById(11093)..GetLanguageStrById(12269)
    -- elseif type == 7 then
    --     return GetLanguageStrById(11093)..GetLanguageStrById(12270)
    -- end
    return type
end
--为关卡跳转做的排序
function this.JumpSort(jumps)
    table.sort(jumps, function(a, b)
        if a.state == b.state then
            if a.state == 2 and  b.state == 2 then
                return a.data.SortId > b.data.SortId
            end
        else
            return a.state > b.state
        end
    end)
end
--道具 和 装备分解 发送请求后 回调
function this.SendBackResolveReCallBack(drop, curResolveAllItemList)
    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
    if func then
        func()
    end
    this:ClosePanel()
end
--界面关闭时调用（用于子类重写）
function RewardItemSingleShowPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function RewardItemSingleShowPopup:OnDestroy()

end

return RewardItemSingleShowPopup