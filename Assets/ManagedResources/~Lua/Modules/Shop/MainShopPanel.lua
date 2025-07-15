require("Base/BasePanel")
local MainShopPanel = Inherit(BasePanel)
local this = MainShopPanel
-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

local _ShopTypeConfig = ConfigManager.GetConfig(ConfigName.StoreTypeConfig)
local _ShopPage = {
    [SHOP_PAGE.GENERAL] = {
        default = "", lock = "", select = "",
        rpType = RedPointType.Shop_Page_General,
    },
    [SHOP_PAGE.COIN] ={
        default = "", lock = "", select = "",
        rpType = RedPointType.Shop_Page_Coin,
    },
    [SHOP_PAGE.PLAY] = {
        default = "", lock = "", select = "",
        rpType = RedPointType.Shop_Page_Play,
    },
    [SHOP_PAGE.EXCHANGE] = {
        default = "", lock = "", select = "",
    },
    [SHOP_PAGE.ROAM] = {
        default = "", lock = "", select = "",
        rpType = RedPointType.Shop_Page_Roam,
    },
}

this._MainShopPageList = {}
this._MainShopTypeList = {}
local configData
--初始化组件（用于子类重写）
function MainShopPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    this.tabboxUp = Util.GetGameObject(self.gameObject, "up")
    this.tabUp = Util.GetGameObject(self.gameObject, "up/tab")
    this.tabboxMiddle = Util.GetGameObject(self.gameObject, "middle")
    this.tabboxBottom = Util.GetGameObject(self.gameObject, "bottom")
    this.tabMiddle = Util.GetGameObject(self.gameObject, "middle/tab")

    this.content = Util.GetGameObject(self.gameObject, "bg/topBg/backBg/content")

    -- -- 显示特权信息
    -- this.vipInfoPart = Util.GetGameObject(self.gameObject, "VipInfoPart")
    -- this.vipChargeRoot = Util.GetGameObject(this.vipInfoPart, "textGrid")
    -- this.chargeNum = Util.GetGameObject(this.vipInfoPart, "textGrid/num"):GetComponent("Text")
    -- this.moneyIcon = Util.GetGameObject(this.vipInfoPart, "textGrid/icon/Image"):GetComponent("Image")
    -- this.vipLevelTip = Util.GetGameObject(this.vipInfoPart, "textGrid/end"):GetComponent("Text")
    -- this.vipIconLevel = Util.GetGameObject(this.vipInfoPart, "vipIcon/num"):GetComponent("Text")
    -- this.vipHeroStar = Util.GetGameObject(this.vipInfoPart, "reward/Text"):GetComponent("Image")

    -- -- 进度
    -- this.vipProgress = Util.GetGameObject(this.vipInfoPart, "Slider/fill"):GetComponent("Image")
    -- this.vipDetailBtn = Util.GetGameObject(this.vipInfoPart, "btnDetail")
    -- this.progressText = Util.GetGameObject(this.vipInfoPart, "Slider/value"):GetComponent("Text")
    -- this.vipRedPoint = Util.GetGameObject(this.vipDetailBtn, "redPoint")

    -- BindRedPointObject(RedPointType.VIP_SHOP_DETAIL, this.vipRedPoint)

    --下部金币显示
    this.cny = Util.GetGameObject(self.gameObject, "bg/cny")
    this.frame = Util.GetGameObject(this.cny, "frame")
    this.upicon = Util.GetGameObject(this.cny, "icon"):GetComponent("Image")
    this.vaule = Util.GetGameObject(this.cny, "value"):GetComponent("Text")
    
    -- 上部货币显示
    this.HeadFrameView =SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowRight})
end
--绑定事件（用于子类重写）
function MainShopPanel:BindEvent()
    -- 初始化Tab管理器
    this.CategoryTabCtrl = TabBox.New()
    this.CategoryTabCtrl:SetTabAdapter(this.CategoryTabAdapter)
    -- this.CategoryTabCtrl:SetTabIsLockCheck(this.CategoryTabIsLockCheck)
    this.CategoryTabCtrl:SetChangeTabCallBack(this.OnCategoryTabChange)

    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    this.ShopTabCtrl = TabBox.New()
    this.ShopTabCtrl:SetTabAdapter(this.ShopTabAdapter)
    this.ShopTabCtrl:SetTabIsLockCheck(this.ShopTabIsLockCheck)
    this.ShopTabCtrl:SetChangeTabCallBack(this.OnShopTabChange)

    -- 关闭界面打开主城
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MainShopPanel:AddListener()
    -- Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.SetVipPartInfo)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.updateIconNumber)
end
--移除事件监听（用于子类重写）
function MainShopPanel:RemoveListener()
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.SetVipPartInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.updateIconNumber)
end

--界面打开时调用（用于子类重写）
function MainShopPanel:OnOpen(chooseShopType)
    SoundManager.PlayMusic(SoundConfig.BGM_Shop)

    this._MainCaegoryPageList = ShopManager.GetMainShopCategoryList()

    this.CategoryTabCtrl:Init(this.tabboxBottom, this._MainCaegoryPageList)

    -- 检测默认打开
    chooseShopType = chooseShopType or SHOP_TYPE.SOUL_STONE_SHOP --默认打开魂晶商店
    if not ShopManager.IsActive(chooseShopType) then
        PopupTipPanel.ShowTipByLanguageId(11926)
        chooseShopType = SHOP_TYPE.SOUL_STONE_SHOP  --商店未激活，打开充值商店
    end

    -- 获取category页index
    local categoryId = ShopManager.GetShopCategoryByShopType(chooseShopType)
    for categoryIdx, category in ipairs(this._MainCaegoryPageList) do
        if category == categoryId then
            this._ChooseCategoryIndex = categoryIdx
            break
        end
    end
    -- 获取默认页index
    this._MainShopPageList = ShopManager.GetMainShopPageList(categoryId)
    local shopPage = ShopManager.GetShopPageByShopType(chooseShopType)
    for pageIndex, page in ipairs(this._MainShopPageList) do
        if page == shopPage then
            this._ChoosePageIndex = pageIndex
            break
        end
    end
    -- 获取默认商店index
    local shopTypeList = ShopManager.GetMainPageShopTypeList(shopPage)
    for shopIndex, shopType in ipairs(shopTypeList) do
        if shopType == chooseShopType then
            this._ChooseShopIndex = shopIndex
            break
        end
    end

    assert(this._ChooseCategoryIndex and this._ChoosePageIndex and this._ChooseShopIndex, GetLanguageStrById(11927))
end

-- 打开，重新打开时回调
function MainShopPanel:OnShow()
    -- 判断是否要打开选择的界面
    if this._ChooseCategoryIndex and this._ChoosePageIndex and this._ChooseShopIndex then
        -- 打开选择page
        if this.CategoryTabCtrl and this._ChooseCategoryIndex ~= this._CurCategoryIndex then
            this.CategoryTabCtrl:ChangeTab(this._ChooseCategoryIndex)
        end
        this._ChooseCategoryIndex = nil

        -- 打开选择page
        if this.PageTabCtrl and this._ChoosePageIndex ~= this._CurPageIndex then
            this.PageTabCtrl:ChangeTab(this._ChoosePageIndex)
        end
        this._ChoosePageIndex = nil

        -- 打开选择的shop
        if this.ShopTabCtrl and this._ChooseShopIndex ~= this._CurShopIndex then
            this.ShopTabCtrl:ChangeTab(this._ChooseShopIndex)
        end
        this._ChooseShopIndex = nil
    end
    this.HeadFrameView:OnShow()
end

-- 层级变化时，子界面层级刷新
function MainShopPanel:OnSortingOrderChange()
    if this.shopView then
        this.shopView:SetSortLayer(self.sortingOrder)
    end
end

----==========================底部页签相关===========================================
function this.CategoryTabAdapter(tab, index, status)
    local name = Util.GetGameObject(tab, "default/Text"):GetComponent("Text")
    local name2 = Util.GetGameObject(tab, "select/Text"):GetComponent("Text")
    local lock = Util.GetGameObject(tab, "lock")
    local title = Util.GetGameObject(tab, "select/title"):GetComponent("Image")

    local shopType = this._MainCaegoryPageList[index]
    if shopType == 1 then
        name.text =GetLanguageStrById(12660)
        name2.text = name.text
        title.sprite = Util.LoadSprite("cn2-x1_shangdian_jichuyeqian")
    elseif shopType == 2 then
        name.text = GetLanguageStrById(12661)
        name2.text = name.text
        title.sprite = Util.LoadSprite("cn2-x1_shangdian_zhanchangyeqian")
    end

    Util.GetGameObject(tab, "select"):SetActive(status == "select")
    Util.GetGameObject(tab, "default"):SetActive(status == "default")

    local islock = status == "lock"
    lock:SetActive(islock)

    -- 判断是否需要检测红点
    --redpot:SetActive(false)
    --if not islock then
        --this.ClearPageRedpot(page)
        --this.BindPageRedpot(page, redpot)
    --end
end

-- tab可用性检测
function this.CategoryTabIsLockCheck(index)
    local page = this._MainShopPageList[index]
    local isActive, errorTip = ShopManager.IsPageActive(page)
    if not isActive then
        if page == SHOP_PAGE.ROAM then
            errorTip = GetLanguageStrById(11928)
        elseif page == SHOP_PAGE.EXCHANGE then
            errorTip = GetLanguageStrById(11929)
        end
        errorTip = errorTip or GetLanguageStrById(10528)
        return true, errorTip
    end
    return false
end
-- tab改变事件
function this.OnCategoryTabChange(index, lastIndex)
    this._CurCategoryIndex = index
    -- 清除tab绑定的红点
    this.ClearTabRedpot()
    -- 刷新tab数据
    local Category = this._MainCaegoryPageList[index]
    this._MainShopPageList = ShopManager.GetMainShopPageList(Category)
    this.PageTabCtrl:Init(this.tabboxUp, this._MainShopPageList)
end

----==========================顶部页签相关===========================================
-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    local name = Util.GetGameObject(tab, "Text"):GetComponent("Text")
    local lock = Util.GetGameObject(tab, "lock")
    local redpot = Util.GetGameObject(tab, "redpot")

    local page = this._MainShopPageList[index]
    local shopPage = this._MainShopPageList[index]
    local shopInfo = ShopManager.GetShopInfoByPages(shopPage)

    local default = Util.GetGameObject(tab, "default"):GetComponent("Image")
    if index == 1 then
        default.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong")
    else
        default.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
    end

    name.text = GetLanguageStrById(shopInfo.Title)
    Util.GetGameObject(tab, "select/Text"):GetComponent("Text").text = name.text

    Util.GetGameObject(tab, "select"):SetActive(status == "select")
    Util.GetGameObject(tab, "default"):SetActive(status == "default")


    local islock = status == "lock"
    lock:SetActive(islock)

    -- 判断是否需要检测红点
    redpot:SetActive(false)
    if not islock then
        --this.ClearPageRedpot(page)
        --this.BindPageRedpot(page, redpot)
    end

    if islock then
        tab:SetActive(false)
    end
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    local page = this._MainShopPageList[index]
    local isActive, errorTip = ShopManager.IsPageActive(page)
    if not isActive then
        if page == SHOP_PAGE.ROAM then
            errorTip = GetLanguageStrById(11928)
        elseif page == SHOP_PAGE.EXCHANGE then
            errorTip = GetLanguageStrById(11929)
        end
        errorTip = errorTip or GetLanguageStrById(10528)
        return true, errorTip
    end
    return false
end

-- tab改变事件
function this.OnPageTabChange(index, lastIndex)
    this._CurPageIndex = index
    -- 清除tab绑定的红点
    this.ClearTabRedpot()
    -- 刷新tab数据
    local page = this._MainShopPageList[index]
    this._MainShopTypeList = ShopManager.GetMainPageShopTypeList(page)
    this.ShopTabCtrl:Init(this.tabboxMiddle, this._MainShopTypeList)
    -- 默认打开第一个商店
    if this.ShopTabCtrl then
        this._CurShopIndex = nil
        this.ShopTabCtrl:ChangeTab(1)
    end
    -- 二级页签只有一个的时候不显示
    this.tabboxMiddle:SetActive(#this._MainShopTypeList > 1)
    this.shopView:SetScrollSize(not this.tabboxMiddle.activeSelf)

    if #this._MainShopTypeList <= 1 then
        -- this.content:GetComponent("RectTransform").offsetMin = Vector2.New(0,188)
        this.content:GetComponent("RectTransform").offsetMax = Vector2.New(0,0)
    else
        -- this.content:GetComponent("RectTransform").offsetMin = Vector2.New(0,188)
        this.content:GetComponent("RectTransform").offsetMax = Vector2.New(0,-155)
    end

    -- 初始化位置
    local contentWidth = LayoutUtility.GetPreferredWidth(this.tabboxMiddle.transform)
    local curPos = this.tabboxMiddle.transform.localPosition
    this.tabboxMiddle.transform.localPosition = Vector3.New(contentWidth, curPos.y, curPos.z)
end

----==========================中间页签相关===========================================
-- tab按钮自定义显示设置
function this.ShopTabAdapter(tab, index, status)
    local name = Util.GetGameObject(tab, "Text"):GetComponent("Text")
    local redpot = Util.GetGameObject(tab, "redpot")

    local shopType = this._MainShopTypeList[index]
    local shopInfo = ShopManager.GetShopInfoByType(shopType)

    name.text = GetLanguageStrById(shopInfo.Name)
    Util.GetGameObject(tab, "select/Text"):GetComponent("Text").text = name.text

    Util.GetGameObject(tab, "select"):SetActive(status == "select")

    local islock = status == "lock"

    -- 判断是否需要检测红点
    redpot:SetActive(false)
    if not islock then
        this.ClearTabRedpot(shopType)
        this.BindTabRedpot(shopType, redpot)
    end
end
-- tab可用性检测
function this.ShopTabIsLockCheck(index)
    local shopType = this._MainShopTypeList[index]
    local isActive, errorTip = ShopManager.IsActive(shopType)
    if not isActive then
        if shopType == SHOP_TYPE.ROAM_SHOP then
            errorTip = GetLanguageStrById(11930)
        end
        errorTip = errorTip or GetLanguageStrById(10528)
        return true, errorTip
    end
    return false
end
-- tab改变事件
function this.OnShopTabChange(index, lastIndex)
    if this._CurShopIndex == index then return end
    this._CurShopIndex = index
    local shopType = this._MainShopTypeList[index]
    if not this.shopView then
        this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform,this.content)
        -- 修改商品栏的位置
        --this.shopView:SetItemContentPosition(Vector3.New(0, 1100, 0))
    end
    -- local contentSize = this.content:GetComponent("RectTransform").rect
    this.shopView:ShowShop(shopType, this.sortingOrder)
    this.shopView:SetBasePanelPostion(Vector2.New(0, -90))

    -- 获取配置
    local shopId = ShopManager.GetShopDataByType(shopType).id
    local config = _ShopTypeConfig[shopId]
    configData = config
    -- 货币界面
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = config.ResourcesBar})

    --下方显示对应icon和数量
    this.updateIconNumber()
end
function this.updateIconNumber()
    if configData.BottomResource ~= nil then
        this.cny:SetActive(true)
        local itemData = ItemConfig[configData.BottomResource]
        this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemData.Quantity))
        this.upicon.sprite = SetIcon(configData.BottomResource)
        this.vaule.text = PrintWanNum(BagManager.GetTotalItemNum(configData.BottomResource))
        Util.AddOnceClick(this.frame, function ()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, configData.BottomResource)
        end)
        return
    end
    this.cny:SetActive(false)
end

-- 绑定数据
local _PageBindData = {}
local _TabBindData = {}
function this.BindPageRedpot(page, redpot)
    local rpType = _ShopPage[page].rpType
    if not rpType then return end
    BindRedPointObject(rpType, redpot)
    _PageBindData[rpType] = redpot
end
function this.ClearPageRedpot(page)
    -- 清除红点绑定
    if page then    -- 清除某个
        local rpType = _ShopPage[page].rpType
        if not rpType then return end
        ClearRedPointObject(rpType, _PageBindData[rpType])
        _PageBindData[rpType] = nil
    else    -- 全部清除
        for rpt, redpot in pairs(_PageBindData) do
            ClearRedPointObject(rpt, redpot)
        end
        _PageBindData = {}
    end
end

-- 获取商店小页签的红点类型
function this.GetTabRPType(shopType)
    local rpType = nil
    if shopType == SHOP_TYPE.GENERAL_SHOP then
        rpType = RedPointType.Shop_Tab_General
    elseif shopType == SHOP_TYPE.SECRET_BOX_SHOP then
        rpType = RedPointType.Shop_Tab_Secret
    elseif shopType == SHOP_TYPE.ARENA_SHOP then
        rpType = RedPointType.Shop_Tab_Arena
    elseif shopType == SHOP_TYPE.ROAM_SHOP then
        rpType = RedPointType.Shop_Tab_Roam
    elseif shopType == SHOP_TYPE.GUILD_SHOP then
        rpType = RedPointType.Shop_Tab_Guild
    end
    return rpType
end
-- 绑定红点
function this.BindTabRedpot(shopType, redpot)
    local rpType = this.GetTabRPType(shopType)
    if not rpType then return end
    BindRedPointObject(rpType, redpot)
    _TabBindData[rpType] = redpot
end
-- 清除红点
function this.ClearTabRedpot(shopType)
    -- 清除红点绑定
    if shopType then    -- 清除某个
        local rpType = this.GetTabRPType(shopType)
        if not rpType then return end
        ClearRedPointObject(rpType, _TabBindData[rpType])
        _TabBindData[rpType] = nil
    else    -- 全部清除
        for rpt, redpot in pairs(_TabBindData) do
            ClearRedPointObject(rpt, redpot)
        end
        _TabBindData = {}
    end
end

--界面关闭时调用（用于子类重写）
function MainShopPanel:OnClose()
end
--界面销毁时调用（用于子类重写）
function MainShopPanel:OnDestroy()
    -- 销毁shopview
    if this.shopView then
        SubUIManager.Close(this.shopView)
        this.shopView = nil
    end
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.HeadFrameView)
    -- 清除红点
    this.ClearPageRedpot()
    this.ClearTabRedpot()
    -- ClearRedPointObject(RedPointType.VIP_SHOP_DETAIL, this.vipRedPoint)
end

return MainShopPanel