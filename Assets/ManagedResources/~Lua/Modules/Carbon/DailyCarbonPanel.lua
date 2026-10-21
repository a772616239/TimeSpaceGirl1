----- 日常副本 -----
require("Base/BasePanel")
DailyCarbonPanel = Inherit(BasePanel)
local this = DailyCarbonPanel
local dailyChallengeConfig = ConfigManager.GetConfig(ConfigName.DailyChallengeConfig)
local mainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local curData = {}
local showIndex = 0

local orginLayer = 0

local carbonIndex = 0--副本索引

local isGoBattle = fa
--顶部背景图
local titleBg = {
    --金币
    [1] = {bg = "cn2-X1_wuzi_banner01",icon = "cn2-X1_wuzi_jinbi",titleTip = specialConfig[41].Value, textbg = GetLanguageStrById(10328), color = Color.New(209/255,91/255,0/255,1)},
    --经验
    [2] = {bg = "cn2-X1_wuzi_banner02",icon = "cn2-X1_wuzi_jingyan",titleTip = specialConfig[42].Value, textbg = GetLanguageStrById(10329), color = Color.New(0/255,119/255,241/255,1)},
    --碎片
    [3] = {bg = "cn2-X1_wuzi_banner04",icon = "cn2-X1_wuzi_yingxiong",titleTip = specialConfig[43].Value, textbg = GetLanguageStrById(10330), color = Color.New(224/255,51/255,4/255,1)},
    --支援
    [4] = {bg = "cn2-X1_wuzi_banner03",icon = "cn2-X1_wuzi_shouhu",titleTip = specialConfig[44].Value, textbg = GetLanguageStrById(10331), color = Color.New(137/255,76/255,212/255,1)},
    --方案
    [5] = {bg = "cn2-X1_wuzi_banner05",icon = "cn2-X1_wuzi_jiezhi",titleTip = specialConfig[45].Value, textbg = GetLanguageStrById(10332), color = Color.New(254/255,0/255,85/255,1)},
}
--难度图片
local qualityBg = {
    [1] = {color = Color.New(72/255,121/255,234/255,255/255), font = GetLanguageStrById(10304)},
    [2] = {color = Color.New(182/255,77/255,242/255,255/255), font = GetLanguageStrById(10305)},
    [3] = {color = Color.New(224/255,160/255,11/255,255/255), font = GetLanguageStrById(10306)},
    [4] = {color = Color.New(224/255,160/255,11/255,255/255), font = GetLanguageStrById(10306)},
    [5] = {color = Color.New(224/255,160/255,11/255,255/255), font = GetLanguageStrById(10306)},
    [6] = {color = Color.New(255/255,20/255,212/255,255/255), font = GetLanguageStrById(10307)},
    [7] = {color = Color.New(255/255,20/255,212/255,255/255), font = GetLanguageStrById(10307)},
    [8] = {color = Color.New(255/255,20/255,212/255,255/255), font = GetLanguageStrById(10307)},
    [9] = {color = Color.New(255/255,20/255,212/255,255/255), font = GetLanguageStrById(10307)}
}

local itemList = {}--奖励容器

--该副本类型下 Id 最大的一关（难度最高）＝整条副本线的最后一关，作为「关键关卡」
--口径按 DailyChallengeConfig 现算，不写死 Id
local function IsLastDungeonOfType(data)
    if not data then
        return false
    end
    local list = ConfigManager.GetAllConfigsDataByKey(ConfigName.DailyChallengeConfig, "Type", data.Type)
    local maxId = 0
    for i = 1, #list do
        if list[i].Id > maxId then
            maxId = list[i].Id
        end
    end
    return data.Id == maxId
end

--每日副本服务器数据
local buyTime = 0--购买次数
local freeTime = 0--免费次数

--Tab
local TabBox = require("Modules/Common/TabBox")
local _TabData = { [1] = {default = "cn2-X1_wuzi_jinbi_weixuanzhong",select = "cn2-X1_wuzi_jinbi_xuanzhong" ,lock = "cn2-X1_wuzi_jinbi_weixuanzhong", name = GetLanguageStrById(10328),type = FUNCTION_OPEN_TYPE.DAILYCHALLENGE_COIN },
                 [2] = {default = "cn2-X1_wuzi_jingyan_weixuanzhong",select = "cn2-X1_wuzi_jingyan_xuanzhong" ,lock = "cn2-X1_wuzi_jingyan_weixuanzhong", name = GetLanguageStrById(10329),type = FUNCTION_OPEN_TYPE.DAILYCHALLENGE_EXP },
                 [3] = {default = "cn2-X1_wuzi_suipian_weixuanzhong",select = "cn2-X1_wuzi_suipian_xuanzhong" ,lock = "cn2-X1_wuzi_suipian_weixuanzhong", name = GetLanguageStrById(10330),type = FUNCTION_OPEN_TYPE.DAILYCHALLENGE_HERODEBRIS },
                 [4] = {default = "cn2-X1_wuzi_shouhu_weixuanzhong",select = "cn2-X1_wuzi_shouhu_xuanzhong" ,lock = "cn2-X1_wuzi_shouhu_weixuanzhong", name = GetLanguageStrById(10331),type = FUNCTION_OPEN_TYPE.DAILYCHALLENGE_TALISMAN },
                 [5] = {default = "cn2-X1_wuzi_jiezhi_weixuanzhong",select = "cn2-X1_wuzi_jiezhi_xuanzhong" ,lock = "cn2-X1_wuzi_jiezhi_weixuanzhong", name = GetLanguageStrById(10332),type = FUNCTION_OPEN_TYPE.DAILYCHALLENGE_SOULPRINT }
                }

--============================== 副本卡入场（右滑入 + 淡入）==============================
-- 参考 Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim（dump_clip.py 反解，m_EditorCurves 12 条全读）：
--   grid/item1..3     m_AnchoredPosition.x   -200 / -150 / -100 → 0   逐格错开
--   grid/item1..3/Bg  m_Color.a              0.3647 → 1             淡入比位移长
-- 本页按要求做**反向**：从右侧 +260 向左归位 0。
-- 前 4 条（Panel 的位移/现高、Panel/Bg 的回弹 + alpha）是弹窗本体进出场，本页是独立面板、
-- 自身已有打开表现 ⇒ 只复刻列表项那 6 条。
--
-- 作用对象是 Scroll 下 Pre 克隆出的**副本卡** item1..itemN（prefab 实测 Pre 882×275）。
--
-- 🔴 位移写卡的**直接子节点**，不写卡根节点：ScrollCycleView:SetData / SetItemIndex 每次都
--    直接赋值 item.tran.anchoredPosition（换页、滚动都会），写根节点必被抹回原位。
-- 🔴 一屏能放 ceil(视口高 / 275 + 1) 张卡 ⇒ 逐格错开生效；但滚动时 item 池复用，
--    所以只在 SetScroll 之后播一次，不放进每张卡的 SetData 里（滚动会逐张触发）。
local kCardSlideFrom     = 260      -- 起点位移（px）：卡宽 882 的 ~30%，与 BattlePass 任务卡同档
local kCardSlideDuration = 0.22     -- 单卡时长
local kCardSlideStep     = 0.05     -- 相邻卡错开
local kCardFadeFrom      = 0.3647   -- 参考 item/Bg 的 alpha 起点
local kCardFadeNode      = "Bg"     -- 只有它是一整张卡大小的 Image，参考也只淡底板

-- 副本卡的可视子节点（这 6 个一起右移 = 整卡滑入；Tip / Consume / GoBtn 会按状态显隐）
local kCardNodes = { "Bg", "Title", "Reward", "GoBtn", "Consume", "Tip" }

local cardSlideItems = {}   -- { rect, x, y, graphic, color, tween }，rect 与 graphic 二选一

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
-- 🔴 漏复位 = 副本卡永久停在半截位置或半透明；重播 / 关闭 / 销毁都必须走这里。
function this.StopCardSlideIn()
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

-- 收集当前可见的副本卡（ScrollCycleView 的 item 池，顺序即列表顺序）
local function CollectCards()
    local cards = {}
    local sv = this.scrollView
    if type(sv) == "table" and type(sv.ForeachItemGO) == "function" then
        sv:ForeachItemGO(function(_, go)
            if Alive(go) and go.activeSelf then
                cards[#cards + 1] = go
            end
        end)
    end
    return cards
end

-- 起播：每张卡从右侧 260px 向左滑回原位，底板 alpha 0.3647 → 1。
function this.PlayCardSlideIn()
    this.StopCardSlideIn()
    local cards = CollectCards()
    if #cards <= 0 then
        return 0
    end
    local ok, err = pcall(function()
        for ci = 1, #cards do
            local card = cards[ci]
            local delay = (ci - 1) * kCardSlideStep
            -- 位移：卡的 6 个可视子节点一起走
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
                        tween:OnComplete(function()
                            if Alive(rect) then
                                rect.anchoredPosition = Vector2.New(pos.x, pos.y)
                            end
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
                    tween:OnComplete(function()
                        if Alive(image) then
                            image.color = color
                        end
                    end)
                    cardSlideItems[#cardSlideItems + 1] = { graphic = image, color = color, tween = tween }
                end
            end
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把副本卡留在半截位置/半透明
        LogError("DailyCarbonPanel: 副本卡入场失败 " .. tostring(err))
        this.StopCardSlideIn()
        return 0
    end
    return #cards
end

function DailyCarbonPanel:InitComponent()
    this.panel = Util.GetGameObject(this.gameObject,"Panel")

    this.bg = Util.GetGameObject(this.panel,"bg"):GetComponent("Image")
    this.titleIcon = Util.GetGameObject(this.panel,"bg/title/icon"):GetComponent("Image")
    this.titleText = Util.GetGameObject(this.panel,"bg/title/Text"):GetComponent("Text")
    this.titleFontBg = Util.GetGameObject(this.panel,"bg/title/fontBg"):GetComponent("Image")
    this.titleFont = Util.GetGameObject(this.panel,"bg/title/fontBg/Text"):GetComponent("Text")

    this.timeTip = Util.GetGameObject(this.panel,"TimeTip/Text"):GetComponent("Text")

    this.backBtn = Util.GetGameObject(this.panel,"backBtn")
    this.helpBtn = Util.GetGameObject(this.panel, "HelpBtn")
    this.sweepBtn = Util.GetGameObject(this.panel, "sweepBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition

    --滚动条
    this.pre = Util.GetGameObject(this.panel, "Scroll/Pre")
    this.scroll = Util.GetGameObject(this.panel, "Scroll")
    local w = this.scroll.transform.rect.width
    local h = this.scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scroll.transform,
            this.pre, nil, Vector2.New(this.scroll.transform.rect.width,this.scroll.transform.rect.height), 1, 1, Vector2.New(0, 0))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.tabBox = Util.GetGameObject(this.panel, "TabBox")
    this.TabCtrl = TabBox.New()

    this.HeadFrameView =SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowRight})
end

function DailyCarbonPanel:BindEvent()
    --返回按钮
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.DailyCarbon,this.helpPosition.x,this.helpPosition.y)
    end)

    --一键扫荡
    Util.AddClick(this.sweepBtn, function()
        if this.isOk then
            if buyTime <= 0 and freeTime <= 0 then
                PopupTipPanel.ShowTipByLanguageId(10342)
                return
            end

            local data = ConfigManager.GetConfigDataByKey("DailyChallengeConfig","Type",carbonIndex)
            local storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",7,"Limit",data.PrivilegeId[1])--商店表数据

            --钻石消耗提示
            if buyTime > 0 then
                local itemName = ConfigManager.GetConfigDataByKey("ItemConfig","Id",storeData.Cost[1][1])
                 if BagManager.GetItemCountById(storeData.Cost[1][1]) >= storeData.Cost[2][4]*buyTime then
                    -- if freeTime > 0 then 
                    --     NetManager.CopyOneKeySweepRequest(carbonIndex,false,function(msg) 
                    --         UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                    --             if freeTime > 0 then
                    --                 PrivilegeManager.RefreshPrivilegeUsedTimes(data.PrivilegeId[2],freeTime)
                    --             end
                    --             this.OnTabChange(carbonIndex)
                    --         end)
                    --     end)
                    -- else
                        local str_1 =string.format(GetLanguageStrById(50279), freeTime ,buyTime,storeData.Cost[2][4]*buyTime,GetLanguageStrById(itemName.Name))                        
                        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Choose,str_1, nil, function(_usebuy)
                            NetManager.CopyOneKeySweepRequest(carbonIndex,_usebuy,function(msg) 
                                local shopData = ShopManager.GetShopDataByType(SHOP_TYPE.FUNCTION_SHOP)
                                for _, v in ipairs(shopData.storeItem) do
                                    if v.id == storeData.Id then
                                        if _usebuy then
                                            v.buyNum = v.buyNum + buyTime
                                        else
                                            v.buyNum = v.buyNum
                                        end
                                        break
                                    end
                                end
                                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                                    -- if freeTime > 0 then
                                        PrivilegeManager.RefreshPrivilegeUsedTimes(data.PrivilegeId[2],freeTime)
                                    -- end
                                    this.OnTabChange(carbonIndex)
                                end)
                            end)
                        end)
                        -- MsgPanel.ShowTwo(, nil,)
                    -- end
                else
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343),GetLanguageStrById(itemName.Name)))
                end
                return
            end

            NetManager.CopyOneKeySweepRequest(carbonIndex, false, function(msg) 
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                    if freeTime > 0 then
                        PrivilegeManager.RefreshPrivilegeUsedTimes(data.PrivilegeId[2],freeTime)
                    end
                    this.OnTabChange(carbonIndex)
                end)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(23027)
        end
    end)
end

function DailyCarbonPanel:OnSortingOrderChange()
    orginLayer = self.sortingOrder
    for i, v in pairs(itemList) do
        for j = 1, #itemList[i] do
            itemList[i][j]:SetEffectLayer(orginLayer)
        end
    end
end

function DailyCarbonPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh,this.FiveRefresh)
end

function DailyCarbonPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh,this.FiveRefresh)
end

function DailyCarbonPanel:OnOpen(_carbonIndex)
    carbonIndex = _carbonIndex and _carbonIndex or 1
end

function DailyCarbonPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })

    isGoBattle = false
    if carbonIndex == 0 then carbonIndex = 1 end
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetTabIsLockCheck(this.TabIsLockCheck)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init_SetTabAndBox(this.tabBox, _TabData, carbonIndex, Util.GetGameObject(this.tabBox, "tab"), Util.GetGameObject(this.tabBox, "box"))
    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)
end

function DailyCarbonPanel:RefreshRedPotShow()
    local tabs = Util.GetGameObject(this.tabBox,"box").transform
    for i = 1,tabs.childCount do
        Util.GetGameObject(tabs:GetChild(i-1),"Redpot").gameObject:SetActive(CarbonManager.GetDailyCarbons(i).state)
    end
    CheckRedPointStatus(RedPointType.HeroExplore)
end

function DailyCarbonPanel:OnClose()
    this.StopCardSlideIn()
end

function DailyCarbonPanel:OnDestroy()
    -- DestroyPanel 不走 OnClose，面板还会被 openedList 缓存复用 ⇒ 两处都要收
    this.StopCardSlideIn()
    itemList = {}
    this.scrollView = nil
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
end

function this.FiveRefresh()
    -- 5 点刷新是服务端数据回调，不是玩家换屏 ⇒ 重建列表不播入场
    this.suppressCardAnim = true
    local ok, err = pcall(this.OnTabChange, 1)
    this.suppressCardAnim = false
    if not ok then
        LogError("DailyCarbonPanel: 5 点刷新失败 " .. tostring(err))
    end
    DailyCarbonPanel:RefreshRedPotShow()
end

--刷新面板
function this.OnTabChange(i)
    carbonIndex = i
    curData = {}

    curData = ConfigManager.GetAllConfigsDataByKey(ConfigName.DailyChallengeConfig,"Type",i)

    this.bg.sprite = Util.LoadSprite(titleBg[i].bg)
    this.titleIcon.sprite = Util.LoadSprite(titleBg[i].icon)
    this.titleText.text = titleBg[i].textbg
    this.titleFontBg.color = titleBg[i].color
    this.titleFont.text = GetLanguageStrById(titleBg[i].titleTip)

    this.SetTimeTip()
    this.SetScroll(i)
    DailyCarbonPanel:RefreshRedPotShow()
end

--设置滚动条
function this.SetScroll(_index)
    this.isOk = false

    for i = 1, #curData do
        local ldata = nil
        if curData[i-1] ~= nil then
            ldata = curData[i-1]
        end
        local data = curData[i]

        local _lv = 0--等级
        local _point = 0--关卡
        local _power = 0--data.ForceShow--表战力
        for i = 1, #data.OpenRules do
            if data.OpenRules[i][1] == 1 then
                _lv = data.OpenRules[i][2]
            elseif data.OpenRules[i][1] == 2 then
                _point = data.OpenRules[i][2]
            elseif data.OpenRules[i][1] == 3 then
                _power = data.OpenRules[i][2]
            end
        end
        if data.OpenRules[2] ~= nil and data.OpenRules[1][1] == 1 then
            _lv = data.OpenRules[1][2]
        end
        if data.OpenRules[1] ~= nil and data.OpenRules[1][1] == 2 then
            _point = data.OpenRules[1][2]
        end
        if data.OpenRules[2][1] == 3 then
            _power = data.OpenRules[2][2]
        end

        local isOpen = (not ldata or CarbonManager.IsDailyCarbonPass(ldata.Id)) -- 上一个副本解锁
        and PlayerManager.level >= _lv          -- 等级
        and (_point == 0 or FightPointPassManager.IsFightPointPass(_point))
        and PlayerManager.maxForce >= _power    -- 战斗力

        -- if isOpen and not CarbonManager.IsDailyCarbonPass(data.Id) then
        --     showIndex = _index
        -- end
    end

    -- local itemList = {}
    this.scrollView:SetData(curData,function(index,root)
        this.SetData(root,curData[index], curData[index - 1])
        -- itemList[index] = root
    end)
    Util.SetGray(this.sweepBtn, not this.isOk)

    -- 副本卡入场：玩家主动进面板 / 换页签才播（数据刷新走 RefreshScrollSilently）
    if this.suppressCardAnim then
        this.StopCardSlideIn()
    else
        this.PlayCardSlideIn()
    end

    -- this.scrollView:SetIndex(1)
    -- DelayCreation(itemList)
end

-- 数据刷新（战斗结算 / 一键扫荡 / 5 点刷新）重建列表时不播入场：卡片闪一下很显眼。
-- pcall 只是为了保证标记一定被复位 —— 否则一次异常会让后面所有入场动画永久失效。
local function RefreshScrollSilently()
    this.suppressCardAnim = true
    local ok, err = pcall(this.SetScroll)
    this.suppressCardAnim = false
    if not ok then
        LogError("DailyCarbonPanel: 刷新副本列表失败 " .. tostring(err))
    end
end

--设置滚动条数据 root根节点 data本地表数据 ldata 上一条数据
function this.SetData(root, data, ldata)
    -- root:SetActive(true)
    local type = 0 --0为未开启 1为挑战 2为扫荡
    local title = Util.GetGameObject(root,"Title"):GetComponent("Text")
    local reward = Util.GetGameObject(root,"Reward")
    local tip = Util.GetGameObject(root,"Tip"):GetComponent("Text")

    local goBtn = Util.GetGameObject(root,"GoBtn")
    local sweep = Util.GetGameObject(goBtn,"sweep")
    local challenge = Util.GetGameObject(goBtn,"challenge")

    local Consume = Util.GetGameObject(root,"Consume")
    -- local goIcon = Util.GetGameObject(root,"Consume/Icon")
    local goIconNum = Util.GetGameObject(root,"Consume/Num"):GetComponent("Text")

    local storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",7,"Limit",data.PrivilegeId[1])--商店表数据
    title.text = qualityBg[data.Quality].font
    title.color = qualityBg[data.Quality].color

    ResetItemView(root,reward.transform,itemList,3,1,orginLayer,false,data.RewardView)

    --解锁状态
    local _lv = 0 --等级
    local _point = 0 --关卡
    local _power = 0 --data.ForceShow--表战力

    for i = 1, #data.OpenRules do
        if data.OpenRules[i][1] == 1 then
            _lv = data.OpenRules[i][2]
        elseif data.OpenRules[i][1] == 2 then
            _point = data.OpenRules[i][2]
        elseif data.OpenRules[i][1] == 3 then
            _power = data.OpenRules[i][2]
        end
    end
    if data.OpenRules[2] ~= nil and data.OpenRules[1][1] == 1 then
        _lv = data.OpenRules[1][2]
    end
    if data.OpenRules[1] ~= nil and data.OpenRules[1][1] == 2 then
        _point = data.OpenRules[1][2]
    end
    if data.OpenRules[2][1] == 3 then
        _power = data.OpenRules[2][2]
    end

    local maxPower = FormationManager.GetMaxPowerForTeamID()
    -- 判断每日副本是否解锁
    local isOpen = (not ldata or CarbonManager.IsDailyCarbonPass(ldata.Id)) -- 上一个副本解锁
        and PlayerManager.level >= _lv          -- 等级
        and (_point == 0 or FightPointPassManager.IsFightPointPass(_point))
        and maxPower >= _power    -- 战斗力
    --显示挑战或扫荡道具消耗
    Consume:SetActive(isOpen and freeTime <= 0)

    if freeTime <= 0 then
        goIconNum.text = storeData.Cost[2][4]
    end

    Util.GetGameObject(challenge,"Text"):GetComponent("Text").text = GetLanguageStrById(10334)
    Util.GetGameObject(sweep,"Text"):GetComponent("Text").text = GetLanguageStrById(10336)
    --表现显示
    Util.SetGray(goBtn, not isOpen)
    if isOpen then
        type = 1
        goBtn:SetActive(true)
        tip.gameObject:SetActive(false)
        sweep:SetActive(false)
        if CarbonManager.IsDailyCarbonPass(data.Id) then--扫荡
            this.isOk = true
            type = 2
            sweep:SetActive(true)
        end
    else
        type = 0
        goBtn:SetActive(false)
        tip.gameObject:SetActive(true)
        tip.text = string.format(GetLanguageStrById(10338),_power)
    end

    --点击事件
    Util.AddOnceClick(goBtn, function()
        local func = function()
            if PlayerManager.level < _lv then
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10340),_lv))
                return
            elseif maxPower < _power then
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12219), _power))
                return 
            elseif _point ~= 0 and not FightPointPassManager.IsFightPointPass(_point) then
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12220), mainLevelConfig[_point].Name))
                return 
            -- elseif PlayerManager.curMapId ~= 0 and FightPointPassManager.IsFightPointPass(PlayerManager.curMapId)==false then
            --     PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10341),mainLevelConfig[_point].Name))
            --     return
            end
    
            if not isOpen then
                PopupTipPanel.ShowTip(GetLanguageStrById(12191))
                return
            end
    
            --检测剩余次数
            if buyTime <= 0 and freeTime <= 0 then
                PopupTipPanel.ShowTip(GetLanguageStrById(10342))
                return
            end
    
            --检测妖晶数量
            local itemId = storeData.Cost[1][1] --消耗道具
            if BagManager.GetItemCountById(itemId) < storeData.Cost[2][4] and freeTime <= 0 then
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343),GetLanguageStrById(itemConfig[itemId].Name)))
                return
            end

            --当免费次数不足 不管是挑战还是扫荡 购买次数
            if freeTime <= 0 then
                ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,storeData.Id,1,function() end)
            end

            isGoBattle = true
            NetManager.DailyChallengeRequest(data.Id, type, function(msg)
                local fightData = BattleManager.GetBattleServerData(msg)
                fightData.mapName = this.GetMapName(data.Type)
                if type == 1 then --挑战
                    BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.CollectMaterials, G_DailyChallengeConfig[data.Id].MonsterId)
                    UIManager.OpenPanel(UIName.BattleStartPopup, function()
                    UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.CollectMaterials , function(result)
                        if result.result == 0 then
                            this.SetTimeTip()
                            this:RefreshRedPotShow()
                            RefreshScrollSilently()
                            isGoBattle = false
                        elseif result.result == 1 then
                            -- 关键关卡领奖 ⇒ 诱导评分（Google Play 内评价）
                            -- 关键关卡＝该副本线（Type）最后一关的**首次通关**；
                            -- 必须在 AddDailyChallengeInfo 之前判首通，否则本地首通标记已经被写掉了
                            local reviewKey = nil
                            if not CarbonManager.IsDailyCarbonPass(data.Id) and IsLastDungeonOfType(data) then
                                reviewKey = "daily_carbon_" .. tostring(data.Type)
                            end
                            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                                PrivilegeManager.RefreshPrivilegeUsedTimes(data.PrivilegeId[2],1)
                                CarbonManager.AddDailyChallengeInfo(data.Id)
                                -- this.RefreshShow(carbonIndex)
                                this.SetTimeTip()
                                this:RefreshRedPotShow()
                                RefreshScrollSilently()
                                isGoBattle = false
                                -- 等奖励面板关掉再弹，避免内评价盖在领奖动画上
                                AppReview_TryShowOnKeyLevel(reviewKey)
                            end)
                        end
                    end)
                end)
                elseif type == 2 then --扫荡
                    UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                        PrivilegeManager.RefreshPrivilegeUsedTimes(data.PrivilegeId[2],1)
                        -- this.RefreshShow(carbonIndex)
                        this.SetTimeTip()
                        this:RefreshRedPotShow()
                        RefreshScrollSilently()
                        isGoBattle = false
                    end)
                end
            end)
        end

        if isGoBattle then
            return
        end

        if type == 1 then
            BattleManager.GotoFight(function()
                func()
            end)
        else
            func()
        end
    end)
end

--设置剩余次数
function this.SetTimeTip()
    local storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",7,"Limit",curData[1].PrivilegeId[1])--商店表数据
    local buyTimeId = curData[1].PrivilegeId[1]
    local freeTimeId = curData[1].PrivilegeId[2]
    buyTime = ShopManager.GetShopItemRemainBuyTimes(SHOP_TYPE.FUNCTION_SHOP,storeData.Id) --购买次数
    freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimeId) --免费次数
    local str = ""
    if freeTime > 0 then
        str = string.format(GetLanguageStrById(10344),"<color=#FFD12B><B>"..tostring(freeTime).."</B></color>")
    else
        str = string.format(GetLanguageStrById(10345),"<color=#FFD12B><B>"..tostring(buyTime).."</B></color>")
    end
    this.timeTip.text = str
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local select = Util.GetGameObject(tab,"select")
    local lock = Util.GetGameObject(tab, "LockImage")
    lock:SetActive(status == "lock")
    select:SetActive(status == "select")
    local bg = Util.GetGameObject(tab,"bg"):GetComponent("Image")
    bg.sprite = Util.LoadSprite(GetPictureFont(_TabData[index][status]))
end

function this.TabIsLockCheck(index)
    if not ActTimeCtrlManager.SingleFuncState(_TabData[index].type) then
        return true,ActTimeCtrlManager.SystemOpenTip(_TabData[index].type)
    end
    return false
end

local typeToMap = {
    [1] = "Map3",
    [2] = "Map7",
    [3] = "Map8",
    [4] = "Map5",
    [5] = "Map1",
}

function this.GetMapName(type)
    return typeToMap[type]
end

return DailyCarbonPanel