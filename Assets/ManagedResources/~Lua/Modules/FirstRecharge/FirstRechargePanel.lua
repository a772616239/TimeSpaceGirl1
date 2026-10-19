--[[
 * @ClassName FirstRechargePanel
 * @Description 首充
 * @Date 2019/6/3 11:45
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
local DayRewardItem = require("Modules/FirstRecharge/DayRewardItem")

---@class FirstRechargePanel
local FirstRechargePanel = Inherit(BasePanel)
local this = FirstRechargePanel

local kMaxTab, kMaxDay = 2, 3
local TextColorDef = {
    [1] = Color.New(255 / 255, 255 / 255, 255 / 255, 76/255),
    [2] = Color.New(255 / 255, 255 / 255, 255 / 255, 204/255)
}
local orginLayer
local activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local thread = nil --协程
--显示英雄ID
local showHeroIDs = {
    10003,
    10019,
    10042,
}
local showHeroId = 10042
--当前显示英雄的下标
local showHeroIndex = 0

-- UnityEngine.Object 在 Lua 侧是 userdata：被 Destroy 之后既不是 nil，也不能直接 .transform
-- （tolua 抛 "attempt to index xxx on a nil value"），必须先 tolua.isnull 判活。
local function Alive(obj)
    return obj ~= nil and not IsNull(obj)
end

function FirstRechargePanel:InitComponent()
    orginLayer = 0

    -- this 是类表，会被下一个实例复用：上一个实例销毁后残留的引用是 fake-null，
    -- 不清掉会让新实例的轮播误判 liveNode 仍然有效。
    this.liveNode = nil
    this.Onelive = nil
    this.heroData = nil
    this.oneHeroData = nil
    this.lihui = nil
    this.oneLihui = nil
    this.lihuiInfo = nil
    this.name = nil
    this.pro = nil

    -- hero 整块都做判空：美术改结构缺一个节点不该让面板开机就崩，
    -- 下游 OnShow/OnTabChanged/SetHeroData 已全部按 nil 处理（只是不显示立绘）。
    self.hero = Util.GetGameObject(self.transform, "hero")
    if Alive(self.hero) then
        this.lihui = Util.GetGameObject(self.hero.transform, "lihuis")
        this.oneLihui = Util.GetGameObject(self.hero.transform, "lihui")
        this.lihuiInfo = Util.GetGameObject(self.hero.transform, "lihuiInfo")
        if Alive(this.lihuiInfo) then
            local nameNode = Util.GetGameObject(this.lihuiInfo, "name")
            local proNode = Util.GetGameObject(this.lihuiInfo, "pro")
            if Alive(nameNode) then
                this.name = nameNode:GetComponent("Text")
            end
            if Alive(proNode) then
                this.pro = proNode:GetComponent("Image")
            end
        end
    else
        LogError("FirstRechargePanel: 缺少 hero 节点，立绘与英雄信息全部跳过")
    end
    if not Alive(this.lihui) then
        LogError("FirstRechargePanel: 缺少 hero/lihuis 节点，立绘轮播不会启动")
    end

    self.closeBtn = Util.GetGameObject(self.transform, "closeBtn")
	this.Btnback = Util.GetGameObject(this.transform, "Btnback")

    self.tabs = {}
    self.selectTabs = {}
    self.tabTitles = {}
    self.tabRedPoint = {}
    for i = 1, kMaxTab do
        self.tabs[i] = Util.GetGameObject(self.transform, "frame/tabsContent/tabs_" .. i)
        self.selectTabs[i] = Util.GetGameObject(self.tabs[i], "selected")
        self.tabTitles[i] = Util.GetGameObject(self.tabs[i], "title"):GetComponent("Text")
        self.tabRedPoint[i] = Util.GetGameObject(self.tabs[i], "redPoint")
    end
    self.selectTabIndex = -1

    self.dayRewardList = {}
    for i = 1, kMaxDay do
        self.dayRewardList[i] = DayRewardItem.new(self,self.transform:Find("frame/rewardBg/rewardDay" .. i))
    end

    --bottomPart
    self.reChargeBtn = Util.GetGameObject(self.transform, "frame/rechargeBtn")
    self.reChargeTips = Util.GetGameObject(self.transform, "frame/tips"):GetComponent("Text")

    self.effect = Util.GetGameObject(self.transform, "frame/effect")
    -- effectAdapte(Util.GetGameObject(self.effect, "Partical/ziti mask (1)"))

    self.oneLihuiInfo = Util.GetGameObject(self.transform,"hero/oneLihuiInfo")
end

function FirstRechargePanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)
	Util.AddClick(this.Btnback, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.reChargeBtn, function()
        self:OnRechargeBtnClicked()
    end)
    for i = 1, kMaxTab do
        Util.AddClick(self.tabs[i], function()
            self:OnTabClicked(i)
        end)
    end
end

function FirstRechargePanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
    --特效穿透特殊处理
    for i = 1, #self.dayRewardList do
        self.dayRewardList[i]:OnSortingOrderChange(self.sortingOrder)
    end
end
local fun = nil
function FirstRechargePanel:OnOpen(context,_fun)
    context = context and context or {}
    self.selectTabIndex = context.tabIndex and context.tabIndex or 1
    fun = _fun
end

function FirstRechargePanel:OnShow()
    self:OnTabChanged(self.selectTabIndex)
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FirstRecharge)
    local AccumRecharge = 0
    for _, missInfo in pairs(activityInfo.mission) do
        if missInfo and missInfo.progress then
            AccumRecharge = missInfo.progress
        end
    end
    self.reChargeTips.text = string.format(GetLanguageStrById(10663), AccumRecharge/100)
    if AccumRecharge/1000 >= 100 then
        self.reChargeBtn:SetActive(false)
    else
        self.reChargeBtn:SetActive(true)
    end
    for i = 1, kMaxTab do
        self:SetTabRedPointStatus(i)
    end

    this.oneHeroData = ConfigManager.GetConfigData(ConfigName.HeroConfig,showHeroId)
    -- 面板是缓存复用的（UIManager.openedList），重复 Open 不经过 OnClose：
    -- 上一次的一次性立绘要先回收，否则每次 OnShow 都多挂一张。
    if Alive(this.Onelive) then
        UnLoadHerolive(this.oneHeroData, this.Onelive)
        if Alive(this.oneLihui) then
            Util.ClearChild(this.oneLihui.transform)
        end
    end
    -- 静态立绘与英雄信息同样要判活：面板被 Destroy 后又 Open（openedList 里的残留实例）时，
    -- 这些节点已经是 fake-null，直接取 .transform 就是本条崩溃的同款死法。
    this.Onelive = nil
    if Alive(this.oneLihui) then
        this.Onelive = LoadHerolive(this.oneHeroData, this.oneLihui.transform)
    end

    if this.oneHeroData and Alive(this.oneLihuiInfo) then
        local nameNode = Util.GetGameObject(this.oneLihuiInfo, "name")
        local proNode = Util.GetGameObject(this.oneLihuiInfo, "pro")
        if Alive(nameNode) then
            nameNode:GetComponent("Text").text = GetLanguageStrById(this.oneHeroData.ReadingName)
        end
        if Alive(proNode) then
            proNode:GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(this.oneHeroData.PropertyName))
        end
    end

    -- 原写法 "for i = 1, 10, 0" 步长为 0：LuaJIT 2.1 不报错但会死循环（i 恒为 1），
    -- 每轮都 Load/UnLoad 一次立绘，是 UnLoadAsset 崩溃的高频触发源。这里显式写成轮播。
    self:StartHeroLoop()
end

-- 立绘轮播：一个面板只允许一个协程在跑。
-- 旧实现是 while true + 模块级 thread（每次 OnShow 都覆盖），而面板是缓存复用的：
--   ① 重复 Open（不经过 OnClose）会残留旧协程，thread 只记得最后一个；
--   ② 销毁路径 UIManager.DestroyPanel 只调 DestroyUI(OnDestroy)、不调 OnClose；
-- 两种情况下残留协程会一直跑下去，拿着已 Destroy 的 this.lihui 去取 .transform，
-- 就是 "FirstRechargePanel:142 attempt to index transform on a nil value" 的来源。
function FirstRechargePanel:StopHeroLoop()
    -- 代次自增：正在 coroutine.wait 里的旧循环醒来后会发现代次变了，自己退出
    this.heroLoopToken = (this.heroLoopToken or 0) + 1
    if thread then
        coroutine.stop(thread)
        thread = nil
    end
end

function FirstRechargePanel:StartHeroLoop()
    self:StopHeroLoop()
    if not Alive(this.lihui) then
        return
    end
    local token = this.heroLoopToken
    thread = coroutine.start(function ()
        while this.heroLoopToken == token and Alive(this.lihui) do
            -- SetHeroData 内部有 wait（一轮约 3.6s）；它若提前返回（配置/资源缺失），
            -- 这里补一次等待，避免 while 变成立即重试的空转死循环。
            if SetHeroData(GetHeroId()) == false then
                coroutine.wait(1)
            end
        end
    end)
end

-- 回收立绘节点（OnClose / OnDestroy 共用）
function FirstRechargePanel:ReleaseHeroLives()
    if Alive(this.liveNode) then
        UnLoadHerolive(this.heroData, this.liveNode)
        if Alive(this.lihui) then
            Util.ClearChild(this.lihui.transform)
        end
    end
    this.liveNode = nil

    if Alive(this.Onelive) then
        UnLoadHerolive(this.oneHeroData, this.Onelive)
        if Alive(this.oneLihui) then
            Util.ClearChild(this.oneLihui.transform)
        end
    end
    this.Onelive = nil
end

function SetHeroData(heroId)
    -- 协程跑得比面板活得久：节点可能已被 Destroy，这里必须判活后再取 transform
    if not Alive(this.lihui) then
        return false
    end
    local lihuiTrans = this.lihui.transform

    if Alive(this.liveNode) then
        UnLoadHerolive(this.heroData, this.liveNode)
        Util.ClearChild(lihuiTrans)
    end
    this.liveNode = nil

    this.heroData = ConfigManager.GetConfigData(ConfigName.HeroConfig,heroId)
    if this.heroData == nil then
        return false
    end

    if Alive(this.name) then
        this.name.text = GetLanguageStrById(this.heroData.ReadingName)
    end
    if Alive(this.pro) then
        this.pro.sprite = Util.LoadSprite(GetProStrImageByProNum(this.heroData.PropertyName))
    end

    this.liveNode = LoadHerolive(this.heroData, lihuiTrans)
    -- 立绘可能加载失败（配置缺失/资源缺失），后面的 DoTween 与等待都不该再往下走
    if not Alive(this.liveNode) then
        return false
    end

    local stopV3 = Vector3.New(this.heroData.Position[1], this.heroData.Position[2],0)
    local startV3 = Vector3.New(this.heroData.Position[1], this.heroData.Position[2],0)
    local endV3 = Vector3.New(this.heroData.Position[1], this.heroData.Position[2],0)

    startV3.x = 1000
    endV3.x = -1000

    -- tween 回调比面板活得久（关界面 0.3 秒内就会打到），读写前同样要判活
    local function GetLivePos()
        if not Alive(this.liveNode) then
            return stopV3
        end
        return this.liveNode.transform.localPosition
    end

    local function SetLivePos(pos)
        if not Alive(this.liveNode) then
            return
        end
        this.liveNode.transform.localPosition = pos
    end

    DoTween.To(
        DG.Tweening.Core.DOGetter_UnityEngine_Vector3(GetLivePos),
        DG.Tweening.Core.DOSetter_UnityEngine_Vector3(SetLivePos),
        stopV3,
        0.3
    ):SetEase(Ease.InQuad)
    coroutine.wait(3)
    DoTween.To(
        DG.Tweening.Core.DOGetter_UnityEngine_Vector3(GetLivePos),
        DG.Tweening.Core.DOSetter_UnityEngine_Vector3(SetLivePos),
        endV3,
        0.3
    ):SetEase(Ease.InQuad)
    coroutine.wait(0.3)
    return true
end

function GetHeroId()
    showHeroIndex = showHeroIndex + 1
    if showHeroIndex > #showHeroIDs then
        showHeroIndex = 1
    end

    return showHeroIDs[showHeroIndex]
end

function FirstRechargePanel:OnTabClicked(index)
    if self.selectTabIndex == index then
        return
    end
    self:OnTabChanged(index)
end

function FirstRechargePanel:OnTabChanged(index)
    for i, select in ipairs(self.selectTabs) do
        select:SetActive(i == index)
    end
    for i, title in ipairs(self.tabTitles) do
        title.color = i == index and TextColorDef[2] or TextColorDef[1]
    end
    self:ShowContent(index)
    self.selectTabIndex = index
    -- tab 切换会被 OnShow 直接调用，节点可能已随面板销毁 ⇒ 逐个判活，不再裸 :SetActive
    if Alive(this.oneLihui) then
        this.oneLihui:SetActive(index == 1)
    end
    --this.lihui:SetActive(index == 2)
    if Alive(this.oneLihuiInfo) then
        this.oneLihuiInfo:SetActive(index == 1)
    end
    if Alive(this.lihuiInfo) then
        this.lihuiInfo:SetActive(index == 1)
    end
    Log("OnTabClicked index:"..index)
end

function FirstRechargePanel:ShowContent(index)
    local tempData = {}
    for _, rewardInfo in ConfigPairs(activityRewardConfig) do
        if rewardInfo.ActivityId == ActivityTypeDef.FirstRecharge and
                rewardInfo.Values[1][1] == IndexValueDef[index] then
            table.insert(tempData, rewardInfo)
        end
    end

    for i, dayRewardItem in ipairs(self.dayRewardList) do
        dayRewardItem:SetValue(tempData[i],self.sortingOrder)
    end
end

function FirstRechargePanel:OnRechargeBtnClicked()
    self:ClosePanel()
    if not ShopManager.SetMainRechargeJump() then
        JumpManager.GoJump(36008)
    else
        -- UIManager.OpenPanel(UIName.MainRechargePanel, 1)
        JumpManager.GoJump(36006)
    end
end

function FirstRechargePanel:SetTabRedPointStatus(tabIndex)
    local redPointStatus = false
    if tabIndex == 1 then
        redPointStatus = redPointStatus or FirstRechargeManager.GetSixMoneyTabRedPointStatus()
    else
        redPointStatus = redPointStatus or FirstRechargeManager.GetHundredTabRedPointStatus()
    end
    self.tabRedPoint[tabIndex]:SetActive(redPointStatus)
end
--界面关闭时调用（用于子类重写）
function FirstRechargePanel:OnClose()
    self:StopHeroLoop()
    if fun then
        fun()
        fun = nil
    end
    self:ReleaseHeroLives()
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用：UIManager.DestroyPanel 只走 DestroyUI→OnDestroy，不会走 OnClose，
--轮播协程必须在这里兜底停掉，否则会拿着已 Destroy 的节点继续跑（本次崩溃就是这么来的）。
function FirstRechargePanel:OnDestroy()
    self:StopHeroLoop()
    self:ReleaseHeroLives()
end

return FirstRechargePanel