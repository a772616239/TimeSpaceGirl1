require("Base/BasePanel")
local ArenaMainPanel = Inherit(BasePanel)
local this = ArenaMainPanel

-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabImgData = {select = "cn2-X1_tongyong_fenlan_weixuanzhong_02", default = "cn2-X1_tongyong_fenlan_weixuanzhong_02",}
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1) }

local _TabData = {
    [1]= {txt = GetLanguageStrById(10334)},
    [2]= {txt = GetLanguageStrById(10131)},
    [3]= {txt = GetLanguageStrById(10080)},
}

local _TabIcon = {
    [1] = "cn2-X1_jingjichang_tiaozhanyeqian",
    [2] = "cn2-X1_jingjichang_paihangyeqian",
    [3] = "cn2-X1_yjingjichang_jiangliyeqian",
}

-- 内容数据
local _ViewData = {
    [1] = {script = "Modules/Arena/View/ArenaMainPanel_ArenaView"},
    [2] = {script = "Modules/Arena/View/ArenaMainPanel_RankingSingleList"},
    [3] = {script = "Modules/Arena/View/ArenaMainPanel_DailyReward"},
    -- [4] = {script = "Modules/Arena/View/ArenaMainPanel_RankReward"},
}

--初始化组件（用于子类重写）
function ArenaMainPanel:InitComponent()
    this.tabbox = Util.GetGameObject(self.gameObject, "tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.content = Util.GetGameObject(self.gameObject, "content")
    this.shopBtn = Util.GetGameObject(self.gameObject, "shopBtn")

    this.ViewList = {}
    this.ViewList[1] = Util.GetGameObject(self.gameObject, "content/ArenaMainPanel_ArenaView")
    this.ViewList[2] = Util.GetGameObject(self.gameObject, "content/ArenaMainPanel_RankingSingleList")

    this.ViewList[3] = Util.GetGameObject(self.gameObject, "content/ArenaMainPanel_DailyReward")
    this.ViewList[4] = Util.GetGameObject(self.gameObject, "content/ArenaMainPanel_RankReward")

    this.ViewLogicList = {}

    -- this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    -- 上部货币显示
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft})
end

--绑定事件（用于子类重写）
function ArenaMainPanel:BindEvent()
    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
        UIManager.OpenPanel(UIName.ArenaTypePanel)
    end)
    Util.AddClick(this.shopBtn, function()
        UIManager.OpenPanel(UIName.MainShopPanel,4)
    end)
end

--添加事件监听（用于子类重写）
function ArenaMainPanel:AddListener()
end

--移除事件监听（用于子类重写）
function ArenaMainPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ArenaMainPanel:OnOpen(...)
    -- 参数保存
    local args = {...}
    this._CurTabIndex = args[1] or 1
end

-- 打开，重新打开时回调
function ArenaMainPanel:OnShow()
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(this._CurTabIndex)
    end
    --if this._CurLogicIndex then
    --    this.OpenView(this._CurLogicIndex)
    --end
    SoundManager.PlayMusic(SoundConfig.BGM_Arena)
    -- this.BtView:OnOpen({sortOrder = self.sortingOrder,panelType = PanelTypeView.MainCity})

end

function ArenaMainPanel:OnSortingOrderChange()
    for index, logic in pairs(this.ViewLogicList) do
        if logic.OnSortingOrderChange then
            logic:OnSortingOrderChange(self.sortingOrder)
        end
    end
    -- this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
end

--界面关闭时调用（用于子类重写）
function ArenaMainPanel:OnClose()
    if this._CurLogicIndex then
        this.CloseView(this._CurLogicIndex)
    end

end

--界面销毁时调用（用于子类重写）
function ArenaMainPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    -- SubUIManager.Close(this.BtView)
    -- 清除红点
    -- ClearRedPointObject(RedPointType.Arena_Shop)
    -- 调用销毁方法
    for index, logic in pairs(this.ViewLogicList) do
        if logic.OnDestroy then
            logic:OnDestroy()
        end
    end

    if this.shopView then
        this.shopView.gameObject:SetActive(true)    -- 重置一下显示状态，避免其他界面打开时状态错误
        this.shopView = SubUIManager.Close(this.shopView)
        this.shopView = nil
    end
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local unselect = Util.GetGameObject(tab, "unselect")
    local select = Util.GetGameObject(tab, "select")

    unselect:SetActive(status == "default")
    select:SetActive(status == "select")

    Util.GetGameObject(unselect, "Text"):GetComponent("Text").text = _TabData[index].txt
    Util.GetGameObject(select, "Text"):GetComponent("Text").text = _TabData[index].txt
    Util.GetGameObject(select, "Image_Icon"):GetComponent("Image").sprite = Util.LoadSprite(_TabIcon[index])

    -- -- 判断是否需要检测红点
    -- local redpot = Util.GetGameObject(tab, "redpot")
    -- if index == 3 then
    --     BindRedPointObject(RedPointType.Arena_Shop, redpot)
    -- end

    if index == 2 then
        BindRedPointObject(RedPointType.ArenaTodayAlreadyLike, Util.GetGameObject(tab, "redpot"))
    end
end

-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    if lastIndex then
        this.CloseView(lastIndex)
    end
    this.OpenView(index)
end

--
function this.OpenView(index)
    this._CurLogicIndex = index
    this._CurTabIndex = index
    -- 商店界面特殊处理------------------------------------！！！！！！！！！！！！！！！！！！
    -- if index == 3 then
    --     if not this.shopView then
    --         this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform)
    --     end
    --     this.shopView.gameObject:SetActive(true)
    --     this.shopView:ShowShop(SHOP_TYPE.ARENA_SHOP, this.sortingOrder)
    --     this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.ArenaShop })
    --     return
    -- end

    local logic = this.ViewLogicList[index]
    if not logic then
        this.ViewLogicList[index] = reimport(_ViewData[index].script)
        logic = this.ViewLogicList[index]
        logic.gameObject = this.ViewList[index]
        logic.transform = this.ViewList[index].transform

        if logic.InitComponent then
            logic:InitComponent()
        end
        if logic.BindEvent then
            logic:BindEvent()
        end
    end

    if logic.AddListener then
        logic:AddListener()
    end

    if logic.OnOpen then
        logic:OnOpen(this)
    end

    logic.gameObject:SetActive(true)
    this.HeadFrameView:OnShow()
    -- 货币界面
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Arena })
end

function this.CloseView(index)
    if this._CurLogicIndex ~= index then return end

    -- -- 商店界面特殊处理-------------------------！！！！！！！！！！！！！！！！！！！！
    -- if index == 3 then
    --     if this.shopView then
    --         this.shopView.gameObject:SetActive(false)
    --     end
    --     return
    -- end
    local logic = this.ViewLogicList[index]
    if logic then
        if logic.RemoveListener then
            logic:RemoveListener()
        end
        if logic.OnClose then
            logic:OnClose()
        end
        logic.gameObject:SetActive(false)
    end
end

--跳转显示新手提示圈
function this.ShowGuideGo()
    JumpManager.ShowGuide(UIName.ArenaMainPanel,Util.GetGameObject(this.gameObject, "content/ArenaMainPanel_ArenaView/challengebox/enemy_1/challenge"))
end
return ArenaMainPanel