



require("Base/BasePanel")
local MainShopPanel = Inherit(BasePanel)
local this = MainShopPanel
local oldAccumRecharge = 0
-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _PageInfo = {}
local _PageInfoCanRecharge = {
    [1] = {    -- 充值
        default = "cn2-X1_chongzhi_yeqian_01", lock = "", select = "cn2-X1_chongzhi_yeqian_01_xuanzhong",
        rpType = RedPointType.Shop_Page_Recharge,
        name = GetLanguageStrById(22615)
    },
    [2] = {    -- VIP
        default = "cn2-X1_chongzhi_yeqian_02", lock = "", select = "cn2-X1_chongzhi_yeqian_02_xuanzhong",
        rpType = RedPointType.VipPanel,
        params = {SHOP_TYPE.VIP_GIFT},-- 待改
        name = GetLanguageStrById(22616)
    },
    [3] = {    -- 每日礼包
        default = "cn2-X1_chongzhi_yeqian_03", lock = "", select = "cn2-X1_chongzhi_yeqian_03_xuanzhong",
        rpType = RedPointType.DailyGift,
        params = {DirectBuyType.DAILY_GIFT},
        name = GetLanguageStrById(22617)
    },
    [4] = {    -- 特权礼包
        default = "cn2-X1_chongzhi_yeqian_04", lock = "", select = "cn2-X1_chongzhi_yeqian_04_xuanzhong",
        -- rpType = RedPointType.Shop_Page_Recharge,
        params = {DirectBuyType.FINDTREASURE_GIFT},
        name = GetLanguageStrById(22618)
    },
    -- [5] = {    -- 成长礼包 （去掉）
    --     default = "m5_icon_chongzhi-chengzhanglibao-01", lock = "m5_icon_chongzhi-chengzhanglibao-01", select = "m5_icon_chongzhi-chengzhanglibao-02",
    --     rpType = RedPointType.GrowthPackage,
    --     params = {SHOP_TYPE.VIP_GIFT},-- 成长礼包
    -- },
}

local _PageInfoCantRecharge = {
    [1] = {-- 充值
        default = "", lock = "", select = "",
        params = {DirectBuyType.FINDTREASURE_GIFT},-- 特权礼包
    },
}
local GiftView = require("Modules/Recharge/View/GiftView")
local RechargeView = require("Modules/Recharge/View/RechargeView")
local VipPanel = require("Modules/Recharge/View/VipPanel")

this._MainShopPageList = {}
this._MainShopTypeList = {}
--初始化组件（用于子类重写）
function MainShopPanel:InitComponent()
    this.tabbox = Util.GetGameObject(self.gameObject, "tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.content = Util.GetGameObject(self.gameObject, "content")

    this.bg = {}
    this.bg[1] = Util.GetGameObject(self.gameObject, "bg1")
    this.bg[2] = Util.GetGameObject(self.gameObject, "bg2")
    this.bg[3] = Util.GetGameObject(self.gameObject, "bg3")

    this.buyAll = Util.GetGameObject(self.gameObject, "content/GiftShop/Bg/buyAll")
    this.goShopBtn = Util.GetGameObject(self.gameObject, "content/GiftShop/Bg/goShopBtn")
    local giftView = GiftView.new(self, Util.GetGameObject(self.transform, "content/GiftShop"))

    if not RECHARGEABLE then--（是否开启充值）
        _PageInfo = _PageInfoCantRecharge
        self.PageList = {
            [1] = giftView,
        }
    else
        _PageInfo = _PageInfoCanRecharge
        this.PageList = {
            [1] = RechargeView.new(self, Util.GetGameObject(self.transform, "content/ShopView")),
            [2] = VipPanel.new(self, Util.GetGameObject(self.transform, "content/VipPanel")),
            [3] = giftView,
            [4] = giftView,
        }
    end
    -- 上部货币显示
    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.PlayerHeadFrameView:OnShow(true)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowRight})
    -- this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
end
--绑定事件（用于子类重写）
function MainShopPanel:BindEvent()
    -- 初始化Tab管理器
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    -- 关闭界面打开主城
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
     Util.AddClick(this.goShopBtn, function()
        JumpManager.GoJump(20014)
    end)
end

--添加事件监听（用于子类重写）
function MainShopPanel:AddListener()
    for i = 1, #this.PageList do
        this.PageList[i]:AddListener()
    end
end
--移除事件监听（用于子类重写）
function MainShopPanel:RemoveListener()
    for i = 1, #this.PageList do
        this.PageList[i]:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function MainShopPanel:OnOpen(chooseIndex)
    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Shop)

    -- 初始化tab数据
    this.PageTabCtrl:Init(this.tabbox, _PageInfo)

    this._CurPageIndex = 4
    if chooseIndex and _PageInfo[chooseIndex] then
        this._CurPageIndex = chooseIndex
    end

end

-- 打开，重新打开时回调
function MainShopPanel:OnShow()
    CheckRedPointStatus(RedPointType.VipPanel)
    if this._CurPageIndex then
        this.PageTabCtrl:ChangeTab(this._CurPageIndex)
    end
end

-- 层级变化时，子界面层级刷新
function MainShopPanel:OnSortingOrderChange()
end

----==========================一级页签相关===========================================
-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    Util.GetGameObject(tab, "Select/img"):GetComponent("Image").sprite = Util.LoadSprite(_PageInfo[index].select)
    Util.GetGameObject(tab, "Select/Text"):GetComponent("Text").text = _PageInfo[index].name

    Util.GetGameObject(tab, "UnSelect/img"):GetComponent("Image").sprite = Util.LoadSprite(_PageInfo[index].default)
    Util.GetGameObject(tab, "UnSelect/Text"):GetComponent("Text").text = _PageInfo[index].name

    Util.GetGameObject(tab, "Select"):SetActive(status == "select")
    Util.GetGameObject(tab, "UnSelect"):SetActive(status == "default")
    local redpot = Util.GetGameObject(tab, "redpot")
    
    -- 判断是否需要检测红点
    redpot:SetActive(false)
    -- if not islock then
        this.ClearPageRedpot(index)
        this.BindPageRedpot(index, redpot)
    -- end
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    return false
end

-- tab改变事件
function this.OnPageTabChange(index, lastIndex)
    this._CurPageIndex = index
    for i = 1, #this.PageList do
        this.PageList[i]:OnHide()
        this.PageList[i].gameObject:SetActive(false)
    end
    --特权显示
    if _PageInfo[index].params ~= nil and _PageInfo[index].params[1] == DirectBuyType.FINDTREASURE_GIFT then
        this.buyAll:SetActive(false)
        this.goShopBtn:SetActive(false)
    else
        this.buyAll:SetActive(true)
        this.goShopBtn:SetActive(true)
    end
    this.PageList[index]:OnShow(this.sortingOrder, _PageInfo[index].params and unpack(_PageInfo[index].params) or nil)
    this.PageList[index].gameObject:SetActive(true)
end

-- 绑定数据
local _PageBindData = {}
local _TabBindData = {}
function this.BindPageRedpot(page, redpot)
    local rpType = _PageInfo[page].rpType
    if not rpType then return end
    BindRedPointObject(rpType, redpot)
    _PageBindData[rpType] = redpot
end
function this.ClearPageRedpot(page)
    -- 清除红点绑定
    if page then    -- 清除某个
        local rpType = _PageInfo[page].rpType
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

--界面关闭时调用（用于子类重写）
function MainShopPanel:OnClose()
    if this._CurPageIndex then 
        this.PageList[this._CurPageIndex]:OnHide()
        this.PageList[this._CurPageIndex].gameObject:SetActive(false)
    end
end
--界面销毁时调用（用于子类重写）
function MainShopPanel:OnDestroy()
    -- SubUIManager.Close(this.BtView)
    SubUIManager.Close(this.PlayerHeadFrameView)
    for _, page in ipairs(this.PageList) do
        page:OnDestroy()
    end

    SubUIManager.Close(this.UpView)
    -- 清除红点
    this.ClearPageRedpot()
end
return MainShopPanel