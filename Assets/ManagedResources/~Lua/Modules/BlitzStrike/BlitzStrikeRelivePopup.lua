require("Base/BasePanel")
BlitzStrikeRelivePopup = Inherit(BasePanel)
local this = BlitzStrikeRelivePopup

local tabs = {}
local proId=0--0 全部  1 火 2风 3 水 4 地  5 光 6 暗

--初始化组件（用于子类重写）
function BlitzStrikeRelivePopup:InitComponent()
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.btnBack = Util.GetGameObject(self.gameObject, "Bg/btnBack")
    this.btnRelive = Util.GetGameObject(self.gameObject, "Bg/btnRelive/btn")
    this.btnReliveTxt = Util.GetGameObject(self.gameObject, "Bg/btnRelive/btnReliveTxt"):GetComponent("Text")
    this.reliveTimes = Util.GetGameObject(self.gameObject, "Bg/reliveTimes"):GetComponent("Text")
    this.btnReliveCostImg = Util.GetGameObject(self.gameObject, "Bg/btnRelive/Image")

    for i = 0, 5 do
        tabs[i] = Util.GetGameObject(self.gameObject, "Bg/Tabs/grid/Btn" .. i)
    end

    this.Scroll = Util.GetGameObject(self.gameObject, "Bg/Scroll")
    this.tankPre = Util.GetGameObject(self.gameObject, "Bg/item")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.tankPre, nil,
            Vector2.New(w, h), 1, 5, Vector2.New(0, 30))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.choosedTanks = {}
end

--绑定事件（用于子类重写）
function BlitzStrikeRelivePopup:BindEvent()
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnRelive, function()
        
        if LengthOfTable(this.choosedTanks) <= 0 then
            PopupTipPanel.ShowTipByLanguageId(12671)
            return
        end
        if BagManager.GetItemCountById(16) < this.ReliveCostDiamond then
            PopupTipPanel.ShowTipByLanguageId(10854)
            return
        end
        if BlitzStrikeManager.todayReviveCount >= this.ReliveTodayLimit then
            PopupTipPanel.ShowTipByLanguageId(10342)
            return
        end

        NetManager.BlitzReviveTank(this.choosedTanks, function()
            NetManager.GetBlitzAllTankInfo(function()
                NetManager.BlitzTypeInfo(function()
                    PopupTipPanel.ShowTipByLanguageId(10501)
                    this:SetTanks()
                    this.choosedTanks = {}
                    this:UpdateDownUI()
                end)
            end)
        end)
    end)

    for i = 0, 5 do
        Util.AddClick(tabs[i], function()
            proId=i
            this:SetSelectBtn()
            this:SetTanks()
        end)
    end
end

--添加事件监听（用于子类重写）
function BlitzStrikeRelivePopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function BlitzStrikeRelivePopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function BlitzStrikeRelivePopup:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BlitzStrikeRelivePopup:OnShow()
    this.specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "BlitzRevive")
    
    local dataArray = string.split(this.specialConfig.Value, "#")
    this.itemId = tonumber(dataArray[1])
    this.costBase = tonumber(dataArray[2])
    this.costAdd = tonumber(dataArray[3])
    local itemData = G_ItemConfig[this.itemId]
    this.btnReliveCostImg:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
    this:SetSelectBtn()
    this:SetTanks()
    this:UpdateDownUI()
end

function BlitzStrikeRelivePopup:UpdateDownUI()  
    
    this.ReliveOneCost = this.costBase + BlitzStrikeManager.todayReviveCount * this.costAdd
    
    this.ReliveCostDiamond = LengthOfTable(this.choosedTanks) * this.ReliveOneCost
    local upLimit = PrivilegeManager.GetPrivilegeNumber(PRIVILEGE_TYPE.BlitzRliveTimesLimit)
    this.ReliveTodayLimit = upLimit
    
    -- this.btnReliveTxt.text = this.ReliveCostDiamond .. GetLanguageStrById(10285)
    this.btnReliveTxt.text = this.ReliveCostDiamond 

    this:SetLastTimes()
end

function BlitzStrikeRelivePopup:SetLastTimes()
    this.reliveTimes.text = math.max(0, this.ReliveTodayLimit - BlitzStrikeManager.todayReviveCount) .. "/" .. this.ReliveTodayLimit
end

function BlitzStrikeRelivePopup:SetSelectBtn()
    for key, value in pairs(tabs) do
        value:GetComponent("Image").sprite = Util.LoadSprite(CampTabSelectPic[key][1])
        local select = Util.GetGameObject(value, "select")
        select:GetComponent("Image").sprite = Util.LoadSprite(CampTabSelectPic[key][2])

        if key == proId then
            select:SetActive(true)
            -- value:GetComponent("Image").sprite = Util.LoadSprite(CampTabSelectPic[key][2])
        else
            select:SetActive(false)
            -- value:GetComponent("Image").sprite = Util.LoadSprite(CampTabSelectPic[key][1])
        end
    end
end

function BlitzStrikeRelivePopup:SetTanks()
    local data = BlitzStrikeManager.GetAllDeadTanks(proId)
    this.scrollView:SetData(data, function(index, root)
        self:SetSingleTank(root, data[index])
    end)
end

function BlitzStrikeRelivePopup:SetSingleTank(go, data)
    local go = go
    local frame = Util.GetGameObject(go,"frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local lv = Util.GetGameObject(go, "lv/Text"):GetComponent("Text")
    local pro = Util.GetGameObject(go, "proIcon"):GetComponent("Image")
    local choosed = Util.GetGameObject(go, "choosed")
    local starGrid = Util.GetGameObject(go, "star")
    local Slider = Util.GetGameObject(go, "Slider")
    local Text = Util.GetGameObject(go, "Slider/Text")
    local name = Util.GetGameObject(go,"name"):GetComponent("Text")

    Text:SetActive(false)
    frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(data.heroConfig.Quality, data.star))
    icon.sprite = Util.LoadSprite(GetResourcePath(data.heroConfig.Icon))
    lv.text = data.lv
    name.text = GetLanguageStrById(data.heroConfig.ReadingName)
    pro.sprite = Util.LoadSprite(GetProStrImageByProNum(data.heroConfig.PropertyName))
    SetHeroStars(starGrid, data.star)
    Slider:GetComponent("Slider").value = 0

    choosed:SetActive(false)
    for k, v in pairs(this.choosedTanks) do
        if v == data.dynamicId then
            choosed:SetActive(true)
        end
    end

    Util.AddOnceClick(Util.GetGameObject(go, "icon"), function()
        if not this.choosedTanks[data.dynamicId] then
            if LengthOfTable(this.choosedTanks) >= 6 then
                return
            end
        end
        this.choosedTanks[data.dynamicId] = not this.choosedTanks[data.dynamicId] and data.dynamicId or nil
        this:SetTanks()

        this:UpdateDownUI()
    end)
end

--界面关闭时调用（用于子类重写）
function BlitzStrikeRelivePopup:OnClose()
    this.choosedTanks = {}
end

--界面销毁时调用（用于子类重写）
function BlitzStrikeRelivePopup:OnDestroy()

end

return BlitzStrikeRelivePopup