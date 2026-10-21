require("Base/BasePanel")
ValuePackPanel = Inherit(BasePanel)
local this = ValuePackPanel

local shopType = {
    801,--契约
    802,--守护
    803,--金钱
    804,--英雄培养
    805
}
local boxImage = {
    "cn2-X1_chaozhilibao_qiyuejingshen",
    "cn2-X1_chaozhilibao_shouhuqianghua",
    "cn2-X1_chaozhilibao_jinqianduoduo",
    "cn2-X1_chaozhilibao_yingxiongpeiyang",
    "cn2-X1_chaozhilibao_jiyinpeiyang",
}
this.ItemList = {}

--============================== 卡片入场：逐格放大缩小 ==============================
-- 参考 Coin Master 的礼包墙入场：每张卡先缩到 0.82，再弹到 1.02，最后落回 1，
-- 相邻卡错开 0.055s 依次起跳，整体跨度不超过 0.55s。
-- 卡片由 ScrollCycleView 克隆后挂在 grid 下，卡片根节点只有 Image（buyBtn 的 Animator
-- 在子节点上），所以动根节点 localScale 不会被 Animator 每帧盖回去。
-- 🔴 峰值只能压到 1.02：卡宽 1062 在 1080 画布里左右各让 9px，scroll/grid 都没有 Mask，
--    峰值再大卡片就会顶出屏幕边缘（1062*1.04 已经越界 12px/侧）。
local kPopFrom = 0.82          -- 起始缩放
local kPopPeak = 1.02          -- 弹起的最大缩放（受上面这条几何约束限制）
local kPopRiseDuration = 0.14  -- 放大段时长
local kPopFallDuration = 0.12  -- 缩小回落时长
local kPopStep = 0.055         -- 相邻卡的间隔
local kPopMaxSpan = 0.55       -- 卡片多时压缩间隔，整体不超过 0.55s

local popItems = {}   -- { tf = , base = }  参与过动画的节点（Stop 时复位）
local popTweens = {}  -- 存活的 tween（Stop 时 Kill）

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能直接取字段
-- （tolua fake-null），必须先 IsNull 判活。
local function PopAlive(obj)
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

function ValuePackPanel:InitComponent()
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    this.backBtn = Util.GetGameObject(this.gameObject, "Bg/down/backBtn")
    this.prefab = Util.GetGameObject(this.gameObject, "Bg/prefab")
    this.scroll = Util.GetGameObject(this.gameObject, "Bg/scroll")

    local rootWidth = this.scroll.transform.rect.width
    local rootHeight = this.scroll.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,this.prefab, nil, Vector2.New(rootWidth, rootHeight), 1, 1, Vector2.New(0,10))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    this.sellOut = Util.GetGameObject(this.gameObject, "Bg/sellOut")--售罄
    this.time = Util.GetGameObject(this.gameObject, "Bg/down/time"):GetComponent("Text")
end

function ValuePackPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)
end

function ValuePackPanel:OnOpen()

end

function ValuePackPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
    ValuePackPanel:SetDataList()
    --卡片逐格入场：必须排在 SetDataList 之后（先定下哪些卡显示、各自尺寸）
    --购买后走的也是 SetDataList 刷新，不经过这里 ⇒ 不会整墙重播
    this:PlayItemPopIn()
    this.time.text = GetLanguageStrById(10028) .. TimeToHMS(CalculateSecondsNowTo_N_OClock(24))
    ValuePackPanel:CountDown()
end

--设置数据
function ValuePackPanel:SetDataList()
    CheckRedPointStatus(RedPointType.ValuePack)
    local dataList = {}
    for _i, v in ipairs(shopType) do
        repeat
        local config = ConfigManager.GetConfigDataByKey(ConfigName.StoreTypeConfig, "Id", v)
        if config.OpenLevel and config.OpenLevel[1] == 3 then
            if not ActTimeCtrlManager.SingleFuncState(config.OpenLevel[2]) then
                break
            end
        end

        local storeData = ConfigManager.GetAllConfigsDataByKey(ConfigName.StoreConfig, "StoreId", v)
        table.sort(storeData, function(a,b)
            return a.Sort < b.Sort
        end)
        local data = ValuePackPanel:GetData(storeData)
        table.insert(dataList, data)
        until true
    end

    this.ScrollView:SetData(dataList, function (index, go)
        this.SetItemInfo(go, dataList[index], index)
    end)

    this.sellOut:SetActive(#dataList == 0)
end

--若没购买则显示 每一类型礼包显示一个
function ValuePackPanel:GetData(storeData)
    for index, value in ipairs(storeData) do
        local buyNum = ShopManager.GetShopItemData(value.StoreId, value.Id).buyNum
        if buyNum == 0 then
            return value
        end
    end
end

--设置每一条信息
function ValuePackPanel.SetItemInfo(go, data, index)
    local name = Util.GetGameObject(go, "title/name"):GetComponent("Text")
    local limit = Util.GetGameObject(go, "title/limit/Text"):GetComponent("Text")
    local box = Util.GetGameObject(go, "boxImage"):GetComponent("Image")
    local discount = Util.GetGameObject(go, "boxImage/discount"):GetComponent("Text")--折扣
    local ItemGrid = Util.GetGameObject(go, "ItemGrid")
    local curPrice = Util.GetGameObject(go, "curPrice/price"):GetComponent("Text")--初始价格
    local buyBtn = Util.GetGameObject(go, "buyBtn")
    local price = Util.GetGameObject(go, "buyBtn/price"):GetComponent("Text")
    local discountBg = Util.GetGameObject(go, "boxImage/discountBg")
    local redpoint = Util.GetGameObject(go, "buyBtn/redpoint")

    name.text = GetLanguageStrById(data.GoodsName)
    limit.text = GetLanguageStrById(data.Desc)
    box.sprite = Util.LoadSprite(boxImage[index])

    curPrice.text = data.Rebate
    price.text = data.Cost[2][4]
    -- 折扣为0时不显示
    if data.Cost[2][4] == 0 then
        discountBg:SetActive(false)
        discount.text = ""
        redpoint:SetActive(true)
    else
        discountBg:SetActive(true)
        discount.text = 100-string.format("%.0f",(data.Cost[2][4]/data.Rebate)*100).."%"
        redpoint:SetActive(false)
    end
    if this.ItemList[go] then
        for i = 1, #this.ItemList[go] do
            if this.ItemList[go][i] then
                this.ItemList[go][i].gameObject:SetActive(false)
            end
        end
        for i = 1, #data.Goods do
            if this.ItemList[go][i] then
                this.ItemList[go][i]:OnOpen(false, {data.Goods[i][1], data.Goods[i][2]}, 0.8)
                this.ItemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        this.ItemList[go] = {}
        for i = 1, #data.Goods do
            this.ItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, ItemGrid.transform)
            this.ItemList[go][i]:OnOpen(false, {data.Goods[i][1], data.Goods[i][2]}, 0.8)
        end
    end

    Util.AddOnceClick(buyBtn, function ()
        ShopManager.RequestBuyShopItem(data.StoreId, data.Id, 1, function ()
            ValuePackPanel:SetDataList()
        end)
    end)
end

--回收入场动画：Kill 掉所有 tween，并把缩放复位到 ScrollCycleView 给的基准值。
--🔴 漏复位 = 那张卡永久停在 0.82 / 1.02 上（重播、关闭、销毁都必须走这里）
function ValuePackPanel:StopItemPopIn()
    for i = #popTweens, 1, -1 do
        if PopAlive(popTweens[i]) then
            popTweens[i]:Kill(false)
        end
        popTweens[i] = nil
    end
    for i = #popItems, 1, -1 do
        local item = popItems[i]
        if PopAlive(item.tf) then
            item.tf.localScale = item.base
        end
        popItems[i] = nil
    end
end

--打开面板：可视卡片按版面顺序逐格「放大再缩小」入场。
--ForeachItemGO 按数据下标给出 1..dataCount 的节点，下标顺序即版面顺序；
--滚出可视区的 card 是 SetActive(false) 的，跳过（否则会白等一轮错开时间）。
function ValuePackPanel:PlayItemPopIn()
    this:StopItemPopIn()
    local scrollView = this.ScrollView
    if not PopAlive(scrollView) or not scrollView.ForeachItemGO then
        return
    end

    local targets = {}
    local okScan, errScan = pcall(function()
        scrollView:ForeachItemGO(function(_, go)
            if PopAlive(go) and go.activeSelf then
                targets[#targets + 1] = go.transform
            end
        end)
    end)
    if not okScan then
        LogError("ValuePackPanel: 遍历礼物卡失败 " .. tostring(errScan))
        return
    end

    local count = #targets
    if count <= 0 then
        return
    end
    local step = kPopStep
    if count > 1 and step * (count - 1) > kPopMaxSpan then
        step = kPopMaxSpan / (count - 1)
    end

    local order = 0
    local ok, err = pcall(function()
        for i = 1, count do
            local tf = targets[i]
            local base = tf.localScale
            popItems[#popItems + 1] = { tf = tf, base = base }
            tf.localScale = base * kPopFrom

            local rise = tf:DOScale(base * kPopPeak, kPopRiseDuration)
            rise:SetDelay(order * step)
            SetEaseSafe(rise, "OutQuad")
            popTweens[#popTweens + 1] = rise
            rise:OnComplete(function()
                -- 中途被 Kill 时 OnComplete 不会回调，回落段也就不会再建
                if not PopAlive(tf) then
                    return
                end
                local fall = tf:DOScale(base, kPopFallDuration)
                SetEaseSafe(fall, "InOutQuad")
                popTweens[#popTweens + 1] = fall
                fall:OnComplete(function()
                    if PopAlive(tf) then
                        tf.localScale = base
                    end
                end)
            end)
            order = order + 1
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把卡片留在半截缩放上
        LogError("ValuePackPanel: 卡片入场动画失败 " .. tostring(err))
        this:StopItemPopIn()
    end
end

--重置时间倒计时
function ValuePackPanel:CountDown()
    if this.localTimer then
        this.localTimer:Stop()
        this.localTimer = nil
    end
    if not this.localTimer then
        this.localTimer = Timer.New(function ()
            local t = CalculateSecondsNowTo_N_OClock(24)
            this.time.text = GetLanguageStrById(10028) .. TimeToHMS(t)
        end, 1, -1, true)
        this.localTimer:Start()
    end
end

function ValuePackPanel:OnClose()
    this:StopItemPopIn()
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

function ValuePackPanel:OnDestroy()
    if this.localTimer then
        this.localTimer:Stop()
        this.localTimer = nil
    end
    this:StopItemPopIn()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
end

return ValuePackPanel