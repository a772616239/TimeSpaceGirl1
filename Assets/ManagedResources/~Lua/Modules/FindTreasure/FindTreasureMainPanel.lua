require("Base/BasePanel")
local ItemPopIn = require("Modules/Common/ItemPopIn")
FindTreasureMainPanel = Inherit(BasePanel)
local this=FindTreasureMainPanel
local findTreasureGrid = {}
local findTreasureItemsGrid = {}
local timer = Timer.New()
local missionInfo = {}
local refreshIsMaterial = true
local isRefreshAddNum = false
local orginLayer = 0
--============================== 材料条（情报）溢出提示 ==============================
-- 材料满**不进入口红点**（那颗只表示「有奖可领」，见 FindTreasureManager.RefreshFindTreasureRedPoint
-- 上面的注释），改成面板内就地提示，两档口径分开：
--   ① 事实：bagNum >= MazeTreasureMax ⇒ Slider 填充转橙（与 numText 的 #FF9725 同色）
--   ② 提示：满 **且** 还有可立刻派遣的卡（idleCount > 0）⇒ 每次打开面板弹一下
-- 为什么不合并成一档：满但四张卡全在跑时，玩家在面板里没有任何能做的事，
-- 弹动只会重复「亮了但没东西点」的老问题（就是这次要修的那个观感）。
local kMaterialFullColor = Color.New(255/255, 151/255, 37/255, 1)   -- #FF9725，与 numText 一致
local materialFillColor = nil      -- 填充色原值，首次进面板快照；恢复时用
local materialHintPopped = false   -- 本次打开是否已经弹过（OnClose 复位）
local materialHintPop = nil        -- ItemPopIn 实例
local materialHintOwner = nil      -- 实例属于哪个面板对象：面板重建后要重新绑，闭包不能留旧的
local isFirstOpen
local conFigData
this.isjump = false
-- local isFirstOn = true--是否首次打开页面

local taskColor = {
    [1] = Color.New(245/255,245/255,245/255,255/255),
    [2] = Color.New(159/255,255/255,136/255,255/255),
    [3] = Color.New(136/255,228/255,255/255,255/255),
    [4] = Color.New(240/255,136/255,255/255,255/255),
    [5] = Color.New(255/255,186/255,136/255,255/255),
    [6] = Color.New(255/255,104/255,104/255,255/255)
}

local changeBgColor = {
    [1] = Color.New(77/255,77/255,77/255,150/255),
    [2] = Color.New(130/255,77/255,238/255,150/255)
}
-- local starImage={[1]="m5_img_tansuo-kongbaixingxing",[2]="ui_1yue"}--星星资源名

--============================== 任务卡入场（右滑入 + 底板淡入）==============================
-- docs/ui_item_slide_in_skill.md 配方落地。与 DailyCarbonPanel / MissionDailyPanel_Daily 同档参数。
-- 容器结构（prefab 实测）：rect 挂 Image，rect1 挂 ScrollRect + Mask（视口），grid 挂
-- VerticalLayoutGroup + ContentSizeFitter（content）⇒ 布局重建会重写 item 根的
-- anchoredPosition，位移必须写在卡的可视子节点上（配方 §4 第一行）。
-- 播放时机：只在玩家主动打开面板时播（OnOpen 闸门 + OnShow 末尾消费，见 MapPanel 落地 §10
-- —— 从派遣/领奖弹窗返回时只走 OnShow，不重播）。领奖 / 刷新按钮 / 派遣完成的事件回调
-- （GameEvent.FindTreasure.RefreshFindTreasure）都算数据刷新，不播：闪一下很显眼。
local kCardSlideFrom     = 260      -- 起点位移（px），卡宽 1043 的 ~25%
local kCardSlideDuration = 0.26     -- 单卡时长
local kCardSlideStep     = 0.055    -- 相邻卡错开（一屏 ~5 张，逐格涌入）
local kCardFadeFrom      = 0.3647   -- 参考 item/Bg 的 alpha 起点
-- 底板形态：BG 容器自己没有 Image，满幅底板是 BG/Image_BG1（1043×227，与 BG 同尺寸）
local kCardFadeNode      = "BG/Image_BG1"

-- 任务卡的可视子节点（一起右移 = 整卡滑入）。按钮区按任务状态互斥显隐
-- （getButton / jumpButton / quickGetButton / consumeObj / timeObject / getFinishText），
-- 未激活的会被 activeSelf 跳过。这 9 个名字在卡的整棵子树里都唯一（配方 §7 第 10 条）。
local kCardNodes = { "BG", "titleImage", "content", "getButton", "jumpButton",
                     "quickGetButton", "consumeObj", "timeObject", "getFinishText" }

local cardSlideItems = {}       -- { rect, x, y, graphic, color, tween }，rect 与 graphic 二选一
local cardSlidePlaying = false  -- 这一轮还没播完（重播 / 快速重开靠它防叠）
local cardSlidePending = 0      -- 还有几条 tween 没完成；减到 0 才算播完
this.needCardSlide = false      -- OnOpen 闸门：true = 下一次 OnShowPanelData 播入场（挂 this 上，便于离线 harness 验证）

-- tolua 的枚举是运行期注册的：取不到就跳过，异常被 pcall 吃掉会整段静默不播
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能取字段
local function Alive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

local function WithAlpha(color, a)
    return Color.New(color.r, color.g, color.b, a)
end

-- 回收：Kill 掉所有 tween 并把位置/颜色复位。
-- 🔴 漏复位 = 任务卡永久停在半截位置或半透明；重播 / 关闭 / 销毁都必须走这里。
function this.StopCardSlideIn()
    -- Kill 不会回调 OnComplete ⇒ 播中标记必须在这里自己清，否则一次 Stop 之后
    -- 后面所有入场都会被「连点保护」当成播中而跳过
    cardSlidePlaying = false
    cardSlidePending = 0
    for i = #cardSlideItems, 1, -1 do
        local item = cardSlideItems[i]
        if Alive(item.tween) then
            item.tween:Kill(false)
        end
        if item.rect and item.x and Alive(item.rect) then
            item.rect.anchoredPosition = Vector2.New(item.x, item.y)
        end
        if item.graphic and item.color and Alive(item.graphic) then
            item.graphic.color = item.color
        end
        cardSlideItems[i] = nil
    end
end

-- 收集当前可见的任务卡（findTreasureGrid[i] 与 missionInfo[i] 按下标一一对应；
-- 超出 missionInfo 数量的旧卡已在 OnShowPanelData 里 SetActive(false)）
local function CollectCards()
    local cards = {}
    for i = 1, #missionInfo do
        local go = findTreasureGrid[i]
        if go and Alive(go) and go.activeSelf then
            cards[#cards + 1] = go
        end
    end
    return cards
end

-- 起播：每张任务卡从右侧滑回原位，底板 alpha 0.3647 → 1。
function this.PlayCardSlideIn()
    -- 上一轮还没播完就只复位、不再重播 —— 重播等于列表刚重建完又堆一批 tween，
    -- 连点时最容易卡。复位到终值本身就是「立刻到位」，观感上不比重播差。
    local interrupted = cardSlidePlaying
    this.StopCardSlideIn()
    if interrupted then
        return 0
    end
    local cards = CollectCards()
    if #cards <= 0 then
        return 0
    end
    -- 每完成一条减一，减到 0 才算这一轮播完（Kill 不会回调 OnComplete，见 StopCardSlideIn）
    local function Done()
        cardSlidePending = cardSlidePending - 1
        if cardSlidePending <= 0 then
            cardSlidePending = 0
            cardSlidePlaying = false
        end
    end
    cardSlidePlaying = true
    local ok, err = pcall(function()
        for ci = 1, #cards do
            local card = cards[ci]
            local delay = (ci - 1) * kCardSlideStep
            -- 位移：卡的可视子节点一起走
            for i = 1, #kCardNodes do
                local go = Util.GetGameObject(card, kCardNodes[i])
                if Alive(go) and go.activeSelf then
                    local rect = go:GetComponent("RectTransform")
                    if Alive(rect) then
                        local pos = rect.anchoredPosition
                        -- 从右侧滑入：起点在右边，向左归位（反向 = 把这里的 + 改回 -）
                        rect.anchoredPosition = Vector2.New(pos.x + kCardSlideFrom, pos.y)
                        local tween = rect:DOAnchorPosX(pos.x, kCardSlideDuration)
                        tween:SetDelay(delay)
                        SetEaseSafe(tween, "OutQuad")
                        cardSlidePending = cardSlidePending + 1
                        tween:OnComplete(function()
                            if Alive(rect) then
                                rect.anchoredPosition = Vector2.New(pos.x, pos.y)
                            end
                            Done()
                        end)
                        cardSlideItems[#cardSlideItems + 1] = { rect = rect, x = pos.x, y = pos.y, tween = tween }
                    end
                end
            end
            -- 淡入：只淡底板（参考里就是 item/Bg，装饰图跟着底板走但不透明）
            local bg = Util.GetGameObject(card, kCardFadeNode)
            if Alive(bg) then
                local image = bg:GetComponent("Image")
                if Alive(image) then
                    local color = image.color
                    image.color = WithAlpha(color, kCardFadeFrom)
                    local tween = image:DOFade(color.a, kCardSlideDuration)
                    tween:SetDelay(delay)
                    SetEaseSafe(tween, "OutQuad")
                    cardSlidePending = cardSlidePending + 1
                    tween:OnComplete(function()
                        if Alive(image) then
                            image.color = color
                        end
                        Done()
                    end)
                    cardSlideItems[#cardSlideItems + 1] = { graphic = image, color = color, tween = tween }
                end
            end
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把任务卡留在半截位置/半透明
        LogError("FindTreasureMainPanel: 任务卡入场失败 " .. tostring(err))
        this.StopCardSlideIn()
        return 0
    end
    if cardSlidePending == 0 then
        cardSlidePlaying = false
    end
    return #cards
end
--初始化组件（用于子类重写）
function FindTreasureMainPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    --self.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    --self.helpPos = Util.GetGameObject(self.gameObject, "helpBtn"):GetComponent("RectTransform").localPosition
    self.findTreasureVipBtn = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn")
    self.findTreasureVipBtnRedPoint = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/redPoint")
    self.allGetBtn = Util.GetGameObject(self.gameObject, "allGetBtn")
    self.findTreasureGridGo = Util.GetGameObject(self.gameObject, "rect/rect1/grid")
    self.rewardPre = Util.GetGameObject(self.gameObject, "rewardPre")
    for i = 1, 2 do
        findTreasureGrid[i] = Util.GetGameObject(self.gameObject, "rect/rect1/grid/rewardPre"..i)
        local curexpertRewardItemsGri = {}
        for j = 1, 4 do
            curexpertRewardItemsGri[j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(findTreasureGrid[i], "content").transform)
        end
        findTreasureItemsGrid[i] = curexpertRewardItemsGri
    end
    self.FindTreasureVipIcon = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/icon")
    --self.FindTreasureVipTextIcon = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/icon/icon (1)"):GetComponent("Image")
    --self.FindTreasureVipTextIcon = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/icon/iconText"):GetComponent("Text")
    --self.FindTreasureVipImageIcon = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/icon/Image"):GetComponent("Image")

     --获取帮助按钮
    self.HelpBtn = Util.GetGameObject(self.gameObject,"HelpBtn")
    self.helpPosition = self.HelpBtn:GetComponent("RectTransform").localPosition

    self.FindTreasureVipText = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/Text"):GetComponent("Text")
    self.FindTreasureVipEffect = Util.GetGameObject(self.gameObject, "FindTreasureVipBtn/FindTreasureVipEffect")

    self.refreshBtn = Util.GetGameObject(self.gameObject, "refreshBtn")
    self.refreshBtnText = Util.GetGameObject(self.refreshBtn, "Text")
    self.refreshBtnFreeText = Util.GetGameObject(self.refreshBtn, "Text/Text"):GetComponent("Text")
    self.refreshImageGo = Util.GetGameObject(self.refreshBtn, "refreshImage")
    self.refreshBtnNumText = Util.GetGameObject(self.refreshBtn, "refreshImage/numText"):GetComponent("Text")
    self.refreshBtnImage = Util.GetGameObject(self.refreshBtn, "refreshImage"):GetComponent("Image")

    self.materialImageBg = Util.GetGameObject(self.gameObject, "materialImageBg")
    self.materialImage = Util.GetGameObject(self.materialImageBg , "materialImage"):GetComponent("Image")
    self.materialImageNumText = Util.GetGameObject(self.materialImageBg, "Slider/numText"):GetComponent("Text")
    self.materialImageSlider = Util.GetGameObject(self.materialImageBg, "Slider"):GetComponent("Slider")
    -- 填充条（Slider 默认层级 Slider/Fill Area/Fill）：材料满时转橙；取不到就只做数字变色。
    -- 用 pcall 兜一层：美术改层级时不能让整个面板打开就崩。
    local okFill, fillGo = pcall(function() return Util.GetGameObject(self.materialImageBg, "Slider/Fill Area/Fill") end)
    self.materialFillImage = (okFill and Alive(fillGo)) and fillGo:GetComponent("Image") or nil
    if materialHintPop == nil or materialHintOwner ~= self then
        -- 只弹材料条本身（不弹整行/不弹卡片）。pivot 实测 (0.5,1) 顶中，按模板原点放大即可
        -- ⇒ centerPivot=false，免得 ItemPopIn 再量内容中心把整条推歪。
        -- 🔴 闭包捕获的是 self：面板销毁重建后 materialImageBg 是旧对象（Alive 失败 ⇒ 静默不弹），
        -- 所以按 owner 判断重建，不能只判 nil。
        if materialHintPop ~= nil then
            materialHintPop:Stop()
        end
        materialHintOwner = self
        local panel = self
        materialHintPop = ItemPopIn.New(function() return { panel.materialImageBg } end,
            { mode = "surge", from = 0.96, peak = 1.04, riseDuration = 0.16, fallDuration = 0.18,
              step = 0, centerPivot = false })
    end

    self.refreshObj = Util.GetGameObject(self.gameObject, "refreshObj")
    self.refreshNumText = Util.GetGameObject(self.refreshObj, "numText"):GetComponent("Text")
    self.refreshImage = Util.GetGameObject(self.refreshObj, "refreshImage"):GetComponent("Image")
    orginLayer = 0

    self.skipBtn = Util.GetGameObject(self.gameObject, "skipBtn")
    this.skipImage = Util.GetGameObject(self.skipBtn, "skip")

end

--绑定事件（用于子类重写）
function FindTreasureMainPanel:BindEvent()
    Util.AddClick(self.btnBack, function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Task.Achievement)
        Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.TrainTask)
        self:ClosePanel()
    end)
    Util.AddClick(self.materialImageBg, function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, FindTreasureManager.materialItemId)
    end)
    Util.AddClick(self.refreshObj, function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, ConfigManager.GetConfigData(ConfigName.MazeTreasureSetting,1).RefreshItem[1])
    end)
    Util.AddClick(self.helpBtn, function()
       UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.FindTreasure,self.helpPosition.x,self.helpPosition.y)
   end)
    Util.AddClick(self.findTreasureVipBtn, function()
        UIManager.OpenPanel(UIName.FindTreasureVipPopup)
        FindTreasureManager.SetShowFindTreasureVipRedPoint(false)
        self.findTreasureVipBtnRedPoint:SetActive(FindTreasureManager.GetShowFindTreasureVipRedPoint())
    end)
    Util.AddClick(self.refreshBtn, function()
        if refreshIsMaterial then
            local isShowTwo = false
            for i = 1, #missionInfo do
                if missionInfo[i].state ~= 2 then
                    if ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(missionInfo[i].missionId%10000)).TaskType >= 4
                    and #missionInfo[i].heroId <= 0 then
                        isShowTwo = true
                    end
                end
            end
            if isShowTwo then
                MsgPanel.ShowTwo(GetLanguageStrById(10661), nil, function()
                    NetManager.FindTreasureRefreshRequest(function(msg)
                        TaskManager.RefreshFindTreasureData(msg)
                        if isRefreshAddNum then
                            PlayerManager.missingRefreshCount = PlayerManager.missingRefreshCount + 1
                        end
                        self:OnShowPanelData(true)
                    end)
                end, nil, nil, nil)
            else
                NetManager.FindTreasureRefreshRequest(function(msg)
                    TaskManager.RefreshFindTreasureData(msg)
                    if isRefreshAddNum then
                        PlayerManager.missingRefreshCount = PlayerManager.missingRefreshCount + 1
                    end
                    self:OnShowPanelData(true)
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(11139)
        end
        --刷新回到顶部
        self.findTreasureGridGo.transform.anchoredPosition3D = Vector3(0, 0, 0)

    end)
    Util.AddClick(self.allGetBtn, function()
        local allGetMissionData = {}
        for i = 1, #missionInfo do
            if missionInfo[i].state == 1 then
                table.insert(allGetMissionData,missionInfo[i])
            end
        end
        if #allGetMissionData > 0 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.FindTreasure,0, function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                end)
                --刷新界面
                for i = 1, #allGetMissionData do
                    TaskManager.RefreshFindTreasureStatrData(allGetMissionData[i].missionId,2)
                end
                self:OnShowPanelData(true)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10662)
        end
    end)

    Util.AddClick(self.skipBtn, function()
        if this.isjump then
            this.isjump = false
            this.skipImage:SetActive(false)
        else
            this.isjump = true
            this.skipImage:SetActive(true)
        end
    end)
end

--添加事件监听（用于子类重写）
function FindTreasureMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FindTreasure.RefreshFindTreasure, self.OnShowPanelData,self)
end

--移除事件监听（用于子类重写）
function FindTreasureMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FindTreasure.RefreshFindTreasure, self.OnShowPanelData,self)
end

--界面打开时调用（用于子类重写）
function FindTreasureMainPanel:OnOpen(...)
    -- 入场闸门：OnOpen 只在真正打开面板走；从派遣/领奖弹窗返回时只走 OnShow，
    -- 不会置这个标记 ⇒ 不会每次关弹窗都重看一遍入场（MapPanel 落地同款闸门）
    this.needCardSlide = true
end

function FindTreasureMainPanel:RefreshHelpBtn()
    Util.AddOnceClick(self.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.FindTreasure,self.helpPosition.x,self.helpPosition.y) 
    end)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FindTreasureMainPanel:OnShow()
    if this.isjump then
        this.isjump = true
        this.skipImage:SetActive(true)
    else
        this.isjump = false
        this.skipImage:SetActive(false)
    end
    self:OnShowPanelData(true)
    self:RefreshHelpBtn()
end

function FindTreasureMainPanel:OnSortingOrderChange()
    --特效穿透签到
    for i = 1, #findTreasureItemsGrid do
        for j = 1, #findTreasureItemsGrid[i] do
            findTreasureItemsGrid[i][j]:SetEffectLayer(self.sortingOrder)
        end
    end
    Util.AddParticleSortLayer(self.FindTreasureVipEffect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

function FindTreasureMainPanel:OnShowPanelData(isSort)
    -- 消费入场标记（在函数开头消费，temp==nil 提前 return 时标记也不会漏到下次刷新）
    local playSlideIn = this.needCardSlide
    this.needCardSlide = false
    refreshIsMaterial = true
    isRefreshAddNum = false
    TaskManager.SetFindTreasureDataState()

    local temp = TaskManager.GetTypeTaskList(TaskTypeDef.FindTreasure)
    if temp == nil then return end
    missionInfo = {}
    for i = 1, #temp do
        if temp[i].state ~= 2 then
            table.insert(missionInfo,temp[i])
        end
    end

    if isSort then
        self:MissionInfoSort(missionInfo)
    end
    for i = 1, math.max(#missionInfo, #findTreasureGrid) do
        local go = findTreasureGrid[i]
        if not go then
            go = newObject(self.rewardPre)
            --go:SetActive(true)
            go.transform:SetParent(self.findTreasureGridGo.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go.name = "rewardPre"..i
            findTreasureGrid[i] = go
            findTreasureItemsGrid[i] = {}
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #missionInfo do
        if missionInfo[i].state ~= 2 then
          self:ActivityRewardSingleShow(i,missionInfo[i])
        end
    end

    --DelayCreation(findTreasureGrid)

    if isFirstOpen then
        isFirstOpen = false
        self.findTreasureGridGo:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    end

    -- 任务卡入场：只有玩家主动打开面板（OnOpen 置的标记）才播。
    -- 领奖（getButton/allGetBtn/quickGetButton）、刷新按钮、派遣完成的事件回调走到这里
    -- 时 playSlideIn 都是 false —— 数据刷新重播会闪一下。
    -- 🔴 抑制时也要 Stop：列表刚被重建，上一轮的 tween 若还在跑会把刚刷新的卡拖回半截位置。
    if playSlideIn then
        this.PlayCardSlideIn()
    else
        this.StopCardSlideIn()
    end

    self:RemainTimeDown()

    --vip
    self.FindTreasureVipIcon:GetComponent("Image").sprite = Util.LoadSprite(FindTreasureVipTypeSprite[1])
    Util.SetGray(self.FindTreasureVipIcon,true)
    local curVipState = 1
    local curVipStateId = 1
    local FindTreasureGaoIdNum = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.GoFindTreasure)--高级寻宝
    local FindTreasureHaoIdNum = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.HaoFindTreasure)--豪华寻宝
    if FindTreasureGaoIdNum then
        curVipStateId = FindTreasureManager.FindTreasureGaoId
        curVipState = 2
        Util.SetGray(self.FindTreasureVipIcon,false)
    end
    if FindTreasureHaoIdNum then
        curVipStateId = FindTreasureManager.FindTreasureHaoId
        curVipState = 3
        Util.SetGray(self.FindTreasureVipIcon,false)
    end
    self.FindTreasureVipEffect:SetActive(curVipState > 1)
    --self.FindTreasureVipText.text = RefreshItemNum
    --self.FindTreasureVipTextIcon.sprite = Util.LoadSprite(FindTreasureVipTextTypeSprite[curVipState])
    -- self.FindTreasureVipImageIcon.sprite = Util.LoadSprite(FindTreasureVipImageTypeSprite[curVipState]) -- m5
    --刷新道具
    local mazeTreasureSetting = ConfigManager.GetConfigData(ConfigName.MazeTreasureSetting,1)--得判断是否 特权
    local itemNum = BagManager.GetItemCountById(FindTreasureManager.refreshTicketItemId)
    local RefreshItemNum = BagManager.GetItemCountById(mazeTreasureSetting.RefreshItem[1])
    
    self.refreshBtnFreeText.text = "(" .. itemNum .. "/".. 2 ..")"
    
    self.refreshBtnText:SetActive(itemNum > 0)
    self.refreshImageGo:SetActive(itemNum <= 0)

    if itemNum <= 0 then
        if RefreshItemNum > 0 then--劵有时花卷  没时候花妖晶
            self.refreshBtnNumText.text = mazeTreasureSetting.RefreshItem[2]
            
            self.refreshBtnImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,mazeTreasureSetting.RefreshItem[1]).ResourceID))
        else
            local refreshNum = PlayerManager.missingRefreshCount
            local cost = mazeTreasureSetting.Cost[2]
            local costNum = math.floor(((cost[1] * math.pow(refreshNum, 3) + cost[2] * math.pow(refreshNum, 2) + cost[3] * refreshNum + cost[4])))
            self.refreshBtnNumText.text = costNum
            
            self.refreshBtnImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,mazeTreasureSetting.Cost[1][1]).ResourceID))
            isRefreshAddNum = true
            if BagManager.GetItemCountById(mazeTreasureSetting.Cost[1][1]) < costNum then
                refreshIsMaterial = false
            end
        end
    end
    self:RefreshMaterialBar()

    self.refreshNumText.text = RefreshItemNum
    self.refreshImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,mazeTreasureSetting.RefreshItem[1]).ResourceID))
    
    local gaoState = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.GoFindTreasure)
    local haoState = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.HaoFindTreasure)
    if gaoState and haoState then
        FindTreasureManager.SetShowFindTreasureVipRedPoint(false)
    end
    self.findTreasureVipBtnRedPoint:SetActive(FindTreasureManager.GetShowFindTreasureVipRedPoint())
end

--材料条（情报）：数字 + Slider + 「满」与「该去派遣了」两档口径。
--所有刷新都走这里（OnShowPanelData 调一次），免得面板内改了、列表刷新又被还原。
function FindTreasureMainPanel:RefreshMaterialBar()
    local levelConfig = ConfigManager.GetConfigData(ConfigName.PlayerLevelConfig, PlayerManager.level)
    local mazeTreasureMax = levelConfig and levelConfig.MazeTreasureMax or 0
    local bagNum = BagManager.GetItemCountById(FindTreasureManager.materialItemId) or 0
    local isFull, idleCount = FindTreasureManager.GetMaterialHintState()

    local numColor = isFull and "#FF9725" or "#FFD12B"
    self.materialImageNumText.text = "<size=46><B><color=" .. numColor .. ">" ..
        PrintWanNum3(bagNum) .. "</color></B></size>/" .. mazeTreasureMax
    self.materialImageSlider.value = (mazeTreasureMax > 0) and (bagNum / mazeTreasureMax) or 0
    self.materialImage.sprite = Util.LoadSprite(GetResourcePath(
        ConfigManager.GetConfigData(ConfigName.ItemConfig, FindTreasureManager.materialItemId).ResourceID))

    --① 事实：满 ⇒ 填充条转橙（与数字同色）
    local fill = self.materialFillImage
    if fill ~= nil and Alive(fill) then
        if materialFillColor == nil then
            materialFillColor = fill.color
        end
        fill.color = isFull and kMaterialFullColor or materialFillColor
    end

    --② 提示：满 **且** 有可派遣的卡（卡上正显示「前往派遣」）⇒ 本次打开弹一下。
    --不循环、不常驻闪动：满但全在派遣中时什么都不做，提示必须指向一个当场能做的动作。
    if isFull and idleCount > 0 and not materialHintPopped then
        materialHintPopped = true
        if materialHintPop ~= nil then
            materialHintPop:Play()
        end
    end
end

--回收：ItemPopIn 不 Stop 会把材料条永久停在半截缩放
function FindTreasureMainPanel:StopMaterialHint()
    if materialHintPop ~= nil then
        materialHintPop:Stop()
    end
    materialHintPopped = false
end

--活动奖励2
function FindTreasureMainPanel:ActivityRewardSingleShow(index,rewardData)
    local activityRewardGo = findTreasureGrid[index]
    activityRewardGo:SetActive(true)
    local sConFigData = ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(rewardData.missionId%10000))
    local titleText = Util.GetGameObject(activityRewardGo, "titleImage/titleText"):GetComponent("Text")
    local titleText2 = Util.GetGameObject(activityRewardGo, "titleImage/titleText/titleText2"):GetComponent("Text")
    titleText.text = GetLanguageStrById(sConFigData.Desc)
    titleText2.text = FindTreasureMissionTitleTypeStr[sConFigData.TaskType]
    titleText.color =  taskColor[sConFigData.TaskType]
    titleText2.color =  taskColor[sConFigData.TaskType]
    local content = Util.GetGameObject(activityRewardGo, "content")

    for i = 1, math.max(#sConFigData.Reward, #findTreasureItemsGrid[index]) do
        local go = findTreasureItemsGrid[index][i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
            findTreasureItemsGrid[index][i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #sConFigData.Reward do
        findTreasureItemsGrid[index][i].gameObject:SetActive(true)
        findTreasureItemsGrid[index][i]:OnOpen(false,sConFigData.Reward[i],0.7,false,false,true,self.sortingOrder)
    end
    local getButton = Util.GetGameObject(activityRewardGo.gameObject, "getButton")
    local jumpButton = Util.GetGameObject(activityRewardGo.gameObject, "jumpButton")
    local quickGetButton = Util.GetGameObject(activityRewardGo.gameObject, "quickGetButton")
    local quickGetButtonImage = Util.GetGameObject(activityRewardGo.gameObject, "quickGetButton/item/Image")
    local quickGetButtonNumText = Util.GetGameObject(activityRewardGo.gameObject, "quickGetButton/item/numText")
    local getFinishText = Util.GetGameObject(activityRewardGo.gameObject, "getFinishText")
    local consumeObj = Util.GetGameObject(activityRewardGo.gameObject, "consumeObj")
    local consumeObjImage = Util.GetGameObject(activityRewardGo.gameObject, "consumeObj/Image"):GetComponent("Image")
    local consumeObjNumText = Util.GetGameObject(activityRewardGo.gameObject, "consumeObj/numText"):GetComponent("Text")
    local timeTextGo = Util.GetGameObject(activityRewardGo.gameObject, "timeObject")
    local changeBg = Util.GetGameObject(activityRewardGo.gameObject, "BG/change"):GetComponent("Image")
    
    timeTextGo:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId > 0)
    getButton:SetActive(rewardData.state == 1)
    jumpButton:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId <= 0)
    getFinishText:SetActive(rewardData.state == 2)

    if rewardData.state == 0 and rewardData.heroId and #rewardData.heroId <= 0 then
        changeBg.color = changeBgColor[1]
    else
        changeBg.color = changeBgColor[2]
    end
    
    consumeObj:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId <= 0)
    quickGetButton:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId > 0)
    consumeObjImage.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,sConFigData.TakeItem[1]).ResourceID))
    consumeObjNumText.text = sConFigData.TakeItem[2]
    quickGetButtonImage:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,sConFigData.SpeedUpTake[1]).ResourceID))
    quickGetButtonNumText:GetComponent("Text").text = sConFigData.SpeedUpTake[2]
    quickGetButtonImage:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId > 0)
    quickGetButtonNumText:SetActive(rewardData.state == 0 and rewardData.heroId and #rewardData.heroId > 0)
    Util.AddOnceClick(jumpButton, function()
        if this.isjump then
            FindTreasureMainPanel:Jump(rewardData)
        else
            UIManager.OpenPanel(UIName.FindTreasureDispatchPanel,rewardData)
        end
    end)
    Util.AddOnceClick(getButton, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.FindTreasure,rewardData.missionId, function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
            end)
            --刷新界面
            TaskManager.RefreshFindTreasureStatrData(rewardData.missionId,2)
            self:OnShowPanelData(true)
        end)
    end)
    Util.AddOnceClick(quickGetButton, function()
        NetManager.FindTreasureMissingRoomAccelerateRequest(rewardData.missionId, function()
            --刷新界面
            TaskManager.RefreshFindTreasureStatrData(rewardData.missionId,1)
            self:OnShowPanelData(true)
            end)
    end)
end
--刷新倒计时显示
function FindTreasureMainPanel:RemainTimeDown()
    if timer then
        timer:Stop()
        timer = nil
    end
    self:RemainTimeDown2()
    timer = Timer.New(function()
        self:RemainTimeDown2()
    end, 1, -1, true)
    timer:Start()
end
function FindTreasureMainPanel:RemainTimeDown2()
    for i = 1, #missionInfo do
        if missionInfo[i].state == 0 and #missionInfo[i].heroId > 0  then--未完成 已派遣
            local timeTextGo = Util.GetGameObject(findTreasureGrid[i], "timeObject/timeText")
            local timeDown  = missionInfo[i].progress - GetTimeStamp()
            if timeDown > 0 then
                timeTextGo:SetActive(true)
                local cursConFigData = ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(missionInfo[i].missionId%10000))
                local timeText = Util.GetGameObject(findTreasureGrid[i], "timeObject/timeText"):GetComponent("Text")
                local timeExp = Util.GetGameObject(findTreasureGrid[i], "timeObject/exp"):GetComponent("Slider")
                timeExp.value = (1- (timeDown / cursConFigData.WasteTime ))
                timeText.text = self:TimeStampToDateString(timeDown)
            else
                missionInfo[i].state = 1
                timeTextGo:SetActive(false)
                self:ActivityRewardSingleShow(i,missionInfo[i])
            end
        end
    end
end
function FindTreasureMainPanel:TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format("%02d:%02d:%02d", hour, minute, sec)
end
local sortTable = {
    [0] = 0,
    [1] = -1,
    [2] = 2,
}
function FindTreasureMainPanel:MissionInfoSort(missionInfo)
    table.sort(missionInfo, function(a, b)
        if a.state == b.state then
            if #a.heroId > 0 and #b.heroId > 0 or #a.heroId <= 0 and #b.heroId <= 0 then
                return ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(a.missionId%10000)).TaskType >
                        ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(b.missionId%10000)).TaskType
            else
                return #a.heroId < #b.heroId
            end
        else
            return sortTable[a.state] < sortTable[b.state]
        end
    end)
end

--界面关闭时调用（用于子类重写）
function FindTreasureMainPanel:OnClose()
    this.StopCardSlideIn()
    self:StopMaterialHint()
    if timer then
        timer:Stop()
        timer = nil
    end
    refreshIsMaterial = true
    isRefreshAddNum = false
    Game.GlobalEvent:DispatchEvent(GameEvent.CloseUI.OnClose)
end

--界面销毁时调用（用于子类重写）
function FindTreasureMainPanel:OnDestroy()
     findTreasureGrid = {}
    -- DestroyPanel 不走 OnClose，面板还会被 openedList 缓存复用 ⇒ 两处都要收
    this.StopCardSlideIn()
    self:StopMaterialHint()
    findTreasureItemsGrid = {}
    missionInfo = {}
    refreshIsMaterial = true
    isRefreshAddNum = false
    this.needCardSlide = false
end

function FindTreasureMainPanel:Jump(rewardData)
    local isMaterial = true

    conFigData = ConfigManager.GetConfigData(ConfigName.MazeTreasure,math.floor(rewardData.missionId%10000))
    if BagManager.GetItemCountById(FindTreasureManager.materialItemId) < conFigData.TakeItem[2]  then isMaterial = false end

    if not isMaterial then
        PopupTipPanel.ShowTip(GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,FindTreasureManager.materialItemId).Name)..GetLanguageStrById(10655))
        return
    end
    -- for i = 1, #needState do
    --     if needState[i] < 1 then
    --         PopupTipPanel.ShowTipByLanguageId(10656)
    --         return
    --     end
    -- end

    local conditionHeros = {}
    for i = 1, #conFigData.Condition do
        local curConditionHeros = {}
        local curSortHeroList = HeroManager.GetFingTreasureAllHeroDatas()
        for k, v in pairs(curSortHeroList) do
            if conFigData.Condition[i][1] == FindTreasureNeedType.Star then
                if v.star >= conFigData.Condition[i][2] then
                    table.insert(curConditionHeros,v)
                end
            elseif conFigData.Condition[i][1] == FindTreasureNeedType.Pro then
                if v.heroConfig.PropertyName == conFigData.Condition[i][2] then
                    table.insert(curConditionHeros,v)
                end
            end
        end
        conditionHeros[i] = curConditionHeros
    end


    local curSelectHeroList = {}
    local conditionTabs = {}
    for i = 1, #conFigData.Condition do
        conditionTabs[i] = 0
    end
    for i = 1, #conditionHeros do
        if #conditionHeros[i] > 0 then
            local jixu = self:AutoSelectState(conditionTabs)
            --if jixu <= 0  then needState = conditionTabs return end
            if i > jixu then jixu = i end
            if #conditionHeros[jixu] <= 0  then  return end
          
            local curSelectSingleHero = self:AutoSelectHeroId(conditionHeros[jixu])
            -- curSelectSingleHero.sortId = curPanelHerosSortNum--排序
            -- curPanelHerosSortNum = curPanelHerosSortNum + 1--排序
            curSelectHeroList[curSelectSingleHero.dynamicId] = curSelectSingleHero
            -- for k = 1, #conFigData.Condition do
            --     if conFigData.Condition[k][1] == FindTreasureNeedType.Star then
            --         for j, v in pairs(curSelectHeroList) do
            --             if v.star >= conFigData.Condition[k][2] then
            --                 conditionTabs[i] = 1
            --             end
            --         end
            --     elseif conFigData.Condition[k][1] == FindTreasureNeedType.Pro then
            --         for j, v in pairs(curSelectHeroList) do
            --             if v.heroConfig.PropertyName == conFigData.Condition[k][2] then
            --                 conditionTabs[i] = 1
            --             end
            --         end
            --     end
            -- end
            --监测方法
            -- self:ShowNeedConditionData()
            -- self:ShowSelectHeroData()
        end
    end

    local curSelectHeroIdsTab = {}
    for k, v in pairs(curSelectHeroList) do
        table.insert(curSelectHeroIdsTab,k)
    end

    NetManager.FindTreasureMissingRoomSendHeroRequest(rewardData.missionId,curSelectHeroIdsTab,function()
        TaskManager.RefreshFindTreasureHerosData(rewardData.missionId,curSelectHeroIdsTab,conFigData.WasteTime)
        Game.GlobalEvent:DispatchEvent(GameEvent.FindTreasure.RefreshFindTreasure,true)
    end)
end

function FindTreasureMainPanel:AutoSelectState(conditionTabs)
    for i = 1, #conditionTabs do
        if conditionTabs[i] < 1 then
           return i
        end
    end
    return 0
end

function FindTreasureMainPanel:AutoSelectHeroId(conditionSingleHeros)
    local heroData = conditionSingleHeros[1]
    local endfeheNeedNum = 0
    for i = 1, #conditionSingleHeros do
        local feheNeedNum = 0
        for j = 1, #conFigData.Condition do
            if conFigData.Condition[j][1] == FindTreasureNeedType.Star then
                if conditionSingleHeros[i].star >= conFigData.Condition[j][2] then
                    feheNeedNum = feheNeedNum + 1
                end
            elseif conFigData.Condition[j][1] == FindTreasureNeedType.Pro then
                if conditionSingleHeros[i].heroConfig.PropertyName == conFigData.Condition[j][2] then
                    feheNeedNum = feheNeedNum + 1
                end
            end
        end
        if endfeheNeedNum < feheNeedNum then
            endfeheNeedNum = feheNeedNum
            heroData = conditionSingleHeros[i]
        end
    end
    return heroData
end

return FindTreasureMainPanel