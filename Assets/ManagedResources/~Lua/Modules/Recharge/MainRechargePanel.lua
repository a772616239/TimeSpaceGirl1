



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

--============================== 页签翻入 + 内容区落位 ==============================
-- 参考七日狂欢 cn2-X1_UI_SevenDayCarnivalPanelV2.anim（9 条曲线）：
--   7 条 m_LocalScale.x 0→1（0.167s/格，相邻错开 0.033s，整体 0.367s）
--   2 条 bg 的 m_FloatCurves（sizeDelta.y 110→0、anchoredPosition.y 55→0，0.3667s）
-- 本面板页签由 TabBox 在 OnOpen 里克隆（可充值时 4 个、关闭充值只有 1 个），
-- 页签常驻不重建 ⇒ 每次 OnShow 重播即可，数量变化时错开间隔自动压缩。
local kTabFlipDuration = 0.167
local kTabFlipStep = 0.033
local kTabFlipMaxSpan = 0.5   -- 可见页签多时压缩错开间隔，整体不超过 0.5s
local kDropDuration = 0.3667
local kDropOffsetY = 110

local tabFlipItems = {}       -- { tween = , tf = , anim = }
local tabSelectTween = nil    -- 高亮板翻入
local tabSelectTf = nil       -- 上面那条 tween 绑的节点（Kill 后要复位，否则永久停在半截）
local dropTween = nil
-- TabBox:Init 在 OnOpen 里就会回调一次 OnPageTabChange（默认页），那次是初始化不是切页；
-- 另外开启动画播放期间的点击也不该抢通道 ⇒ 只有 PlayDropIn 起过之后才翻高亮板。
local animReady = false

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能直接取字段
-- （tolua fake-null），必须先 IsNull 判活。
local function FlipAlive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

-- tolua 的枚举表是运行期注册的，取不到就不设：否则整段被 pcall 吃掉、什么都不动
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- DOAnchorPos 是 RectTransform 的扩展方法；直接拿 transform 得到的是 Transform 类型，
-- 那种 userdata 上没有这个方法。
-- 落位目标选 content：prefab 里它是 a(0,0)-(1,1) / p(0.5,0.5) / pos(0,0) 的透明容器，
-- 承所有子页（content/ShopView、content/VipPanel、content/GiftShop）。bg 虽然也是四边
-- 拉满，但它是无 sprite 的纯色全屏块，动它只会露边 —— 参考 clip 里动的正是这种看不见
-- 的遮罩，真正看得见的是遮罩底下的内容。
function this.GetContentRect()
    local go = this.content
    if not FlipAlive(go) then
        go = Util.GetGameObject(this.gameObject, "content")
    end
    if not FlipAlive(go) then
        return nil
    end
    return go:GetComponent("RectTransform")
end

-- 回收落位 tween 并把位置复位：中途关掉再打开会从半截位置起，漏复位则永久停在 +110
function this.StopDropIn()
    if FlipAlive(dropTween) then
        dropTween:Kill(false)
    end
    dropTween = nil
    local rect = this.GetContentRect()
    if FlipAlive(rect) then
        rect.anchoredPosition = Vector2.New(0, 0)
    end
end

-- 打开面板：内容区从上方落下 110px 落到原位（一次性，0.367s，两端缓入缓出）
function this.PlayDropIn()
    this.StopDropIn()
    local rect = this.GetContentRect()
    if not FlipAlive(rect) then
        return
    end
    local ok, err = pcall(function()
        rect.anchoredPosition = Vector2.New(0, kDropOffsetY)
        local tween = rect:DOAnchorPos(Vector2.New(0, 0), kDropDuration)
        SetEaseSafe(tween, "InOutQuad")
        tween:OnComplete(function()
            if FlipAlive(rect) then
                rect.anchoredPosition = Vector2.New(0, 0)
            end
        end)
        dropTween = tween
    end)
    if not ok then
        LogError("MainRechargePanel: 内容区落位失败 " .. tostring(err))
        if FlipAlive(rect) then
            rect.anchoredPosition = Vector2.New(0, 0)
        end
    end
    animReady = true
end

-- 回收所有翻入 tween，并把临时关掉的按钮 Animator 恢复。
-- 🔴 漏恢复 = 那颗页签从此没有按下反馈；重播 / 关闭 / 销毁都必须走这里。
function this.StopOpenAnims()
    animReady = false
    for i = #tabFlipItems, 1, -1 do
        local item = tabFlipItems[i]
        if FlipAlive(item.tween) then
            item.tween:Kill(false)
        end
        if FlipAlive(item.tf) then
            item.tf.localScale = Vector3.one
        end
        if FlipAlive(item.anim) then
            item.anim.enabled = true
        end
        tabFlipItems[i] = nil
    end
    if FlipAlive(tabSelectTween) then
        tabSelectTween:Kill(false)
    end
    tabSelectTween = nil
    -- 🔴 高亮板是「先置 0 再长回 1」，Kill 时必须自己复位，否则切页途中关面板会把
    -- 那块板永久留在半截缩放上（ExpertPanel 同一处也有这个坑，一并修）。
    if FlipAlive(tabSelectTf) then
        tabSelectTf.localScale = Vector3.one
    end
    tabSelectTf = nil
    -- 落位同属开启动画，一起回收
    this.StopDropIn()
end

-- 打开面板：可见页签逐格 scaleX 0→1。
-- 页签由 TabBox 按 box 的子节点顺序克隆（HorizontalLayoutGroup 排版），
-- GetTabList() 的下标就是版面顺序，不需要再按 sibling 取。
function this.PlayTabFlipIn()
    this.StopOpenAnims()
    local list = this.PageTabCtrl and this.PageTabCtrl:GetTabList()
    if not list then
        return
    end
    local visible = 0
    for i = 1, #list do
        local go = list[i]
        if FlipAlive(go) and go.activeSelf then
            visible = visible + 1
        end
    end
    if visible <= 0 then
        return
    end
    local step = kTabFlipStep
    if visible > 1 and step * (visible - 1) > kTabFlipMaxSpan then
        step = kTabFlipMaxSpan / (visible - 1)
    end

    local order = 0
    local started = {}   -- 出错回滚用：{ tf, anim }
    local ok, err = pcall(function()
        for i = 1, #list do
            local go = list[i]
            -- 未激活的页签不参与动画（TabBox 会把模板 tab 藏起来，克隆体都是激活的）
            if FlipAlive(go) and go.activeSelf then
                local tf = go.transform
                local anim = go:GetComponent("Animator")
                -- 🔴 每格都挂 CommonButton 的 Animator，Normal 状态是 1.1→1 的缩放 pop，
                -- 而且 Animator 在 Update 之后求值 ⇒ 不关掉它，下面的 DOTween 缩放会被
                -- 每帧盖回去（现象：脚本跑完了但页签没动）。
                if FlipAlive(anim) then
                    anim.enabled = false
                end
                started[#started + 1] = { tf = tf, anim = anim }
                tf.localScale = Vector3.New(0, 1, 1)
                local tween = tf:DOScale(Vector3.one, kTabFlipDuration)
                tween:SetDelay(order * step)
                SetEaseSafe(tween, "OutQuad")
                tween:OnComplete(function()
                    if FlipAlive(tf) then
                        tf.localScale = Vector3.one
                    end
                    if FlipAlive(anim) then
                        anim.enabled = true
                    end
                end)
                tabFlipItems[#tabFlipItems + 1] = { tween = tween, tf = tf, anim = anim }
                order = order + 1
            end
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把页签留在 scale 0 / Animator 禁用态
        LogError("MainRechargePanel: 页签翻入失败 " .. tostring(err))
        for i = 1, #started do
            local item = started[i]
            if FlipAlive(item.tf) then
                item.tf.localScale = Vector3.one
            end
            if FlipAlive(item.anim) then
                item.anim.enabled = true
            end
        end
        tabFlipItems = {}
    end
end

-- 切换页签：高亮板翻一次。Select 节点没有 Animator，不会和 CommonButton 抢缩放通道。
-- 定义用冒号：调用方是 this:PlayTabSelectFlip(index)，点式定义会让 index 吃到 self。
function this:PlayTabSelectFlip(index)
    if not animReady then
        return
    end
    local list = this.PageTabCtrl and this.PageTabCtrl:GetTabList()
    local tabGo = list and list[index]
    if not FlipAlive(tabGo) then
        return
    end
    local go = Util.GetGameObject(tabGo, "Select")
    if not FlipAlive(go) then
        return
    end
    if FlipAlive(tabSelectTween) then
        tabSelectTween:Kill(false)
    end
    local tf = go.transform
    tf.localScale = Vector3.New(0, 1, 1)
    tabSelectTf = tf
    tabSelectTween = tf:DOScale(Vector3.one, kTabFlipDuration)
    SetEaseSafe(tabSelectTween, "OutQuad")
end

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
    -- 开启动画：先页签翻入，再内容区落位。
    -- 🔴 顺序不能反：PlayTabFlipIn 第一行是 StopOpenAnims，会把先起的落位一起杀掉
    --   （现象：页签翻了、内容区一动不动）。
    this:PlayTabFlipIn()
    this:PlayDropIn()
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
    -- 切页签：新选中的高亮板翻一次（内部按 animReady 过滤掉初始化那次回调）
    this:PlayTabSelectFlip(index)
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
    -- 回收开启动画，避免下次打开从半截状态起
    this:StopOpenAnims()
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
    -- 面板销毁：tween 必须停，否则回调会打到已销毁节点（tolua fake-null 判不出）
    this:StopOpenAnims()
    -- 清除红点
    this.ClearPageRedpot()
end
return MainShopPanel