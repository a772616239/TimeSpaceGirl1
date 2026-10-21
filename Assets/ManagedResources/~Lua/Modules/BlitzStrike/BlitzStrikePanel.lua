require("Base/BasePanel")
local ItemPopIn = require("Modules/Common/ItemPopIn")--未开宝箱入场（从小到大弹一下）
BlitzStrikePanel = Inherit(BasePanel)
local this = BlitzStrikePanel

local buildingName = {"cn2-x1_yiwangzhicheng_TB_nandu_01", "cn2-x1_yiwangzhicheng_TB_nandu_02", "cn2-x1_yiwangzhicheng_TB_nandu_03"}

--==================== 未开宝箱入场（从小到大的弹性） ====================
-- 面板打开时，还显示「关闭态箱体」的宝箱按路径顺序逐个弹一下：0.45 → 1，OutElastic 自带过冲回弹。
-- 🔴 配方只写在这里（+ Modules/Common/ItemPopIn 的缺省值），别在面板里复写一套 tween；
--    配方/坑见 docs/ui_item_pop_in_skill.md。
-- mode = "duang" 只给一条 tween，过冲由缓动自己给（不要设 peak）：
--   箱体图 171×176，没到「大块头 250px」那条线，可以用弹性；再大就得改 phases 关键帧。
-- 缩放目标是 Bg/box（箱体图那层），不是 Box 根：Box 根 rect 是 261×115，箱体却画在 pivot 上方 61px，
-- 缩放根节点会「往下长」，看着没居中；Bg/box 的 rect 就是箱体本身，pivot 正好在画面中心
-- ⇒ centerPivot = false，别让模块再按子节点并集去挪 pivot。
local kBoxPopInCfg = {
    mode = "duang",
    from = 0.45,          -- 起点 45%：「从小到大」的落差主要靠这里
    duangDuration = 0.55, -- 单箱时长；拉到 0.8s 会变成软塌塌的果冻
    ease = "OutElastic",
    step = 0.08,          -- 相邻宝箱错开
    maxSpan = 0.45,       -- 5 个时 0.08*4 = 0.32，不触发压缩
    centerPivot = false,
}

local isCanClick = false

local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
--初始化组件（用于子类重写）
function BlitzStrikePanel:InitComponent()
    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    this.backBtn = Util.GetGameObject(self.gameObject, "Root/Bottom/backBtn")

    this.StageGo = {}
    for i = 1, BlitzStrikeManager.StageNum do
        this.StageGo[i] = Util.GetGameObject(self.gameObject, "Root/Center/StageRoot/Stage" .. tostring(i))
    end
    this.BoxGo = {}
    for i = 1, BlitzStrikeManager.BoxNum do
        this.BoxGo[i] = Util.GetGameObject(self.gameObject, "Root/Center/StageRoot/Box" .. tostring(i))
    end

    -- 未开宝箱的入场队列：内容由 UpdateMain 每次重建（空表时 Play 是 no-op）
    this.unopenedBoxGo = {}
    this.boxPopIn = ItemPopIn.New(function()
        return this.unopenedBoxGo
    end, kBoxPopInCfg)

    this.Model = {}
    for i = 1, 3 do
        this.Model[i] = Util.GetGameObject(self.gameObject, "Root/Top/TitleMode/Model" .. tostring(i))
        this.Model[i]:SetActive(false)
    end

    this.Btn_Shop = Util.GetGameObject(self.gameObject, "Root/Top/Btn_Shop")
    -- this.Btn_Friend = Util.GetGameObject(self.gameObject, "Root/Top/Btn_Friend")
    this.Btn_Relive = Util.GetGameObject(self.gameObject, "Root/Top/Btn_Relive")

    this.Scroll = Util.GetGameObject(self.gameObject, "Root/Top/TodayGetReward/Scroll")
    this.RewardPre = Util.GetGameObject(self.gameObject, "Root/Top/TodayGetReward/RewardPre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.RewardPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function BlitzStrikePanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.Btn_Shop, function()
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.BLITZ_STRIKE)
    end)

    -- Util.AddClick(this.Btn_Friend, function()
    --     UIManager.OpenPanel(UIName.BlitzStrikeSupportPopup)
    -- end)
    -- this.Btn_Friend:SetActive(false)

    Util.AddClick(this.Btn_Relive, function()
        if isCanClick then
            UIManager.OpenPanel(UIName.BlitzStrikeRelivePopup)
        end
    end)

    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.BlitzStrikeDifficultSelect,this.helpPosition.x,this.helpPosition.y+800) 
    end)
end

--添加事件监听（用于子类重写）
function BlitzStrikePanel:AddListener()
end

--移除事件监听（用于子类重写）
function BlitzStrikePanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BlitzStrikePanel:OnOpen()
    PlaySoundWithoutClick(SoundConfig.Sound_INTERFACE_Button_Entergame)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BlitzStrikePanel:OnShow()
    this.PlayerHeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.BlitzStrikePanel })

    if BlitzStrikeManager.difficultyLevel == 0 then
        UIManager.OpenPanel(UIName.BlitzStrikeDifficultSelectPopup)
        this.UpdateMainUnSelect()
        isCanClick = true
    else
        NetManager.GetBlitzAllTankInfo(function()
            isCanClick = true
            BlitzStrikeManager.RrefreshFormation()
        end)
        this.UpdateMain()
        -- 🔴 只在这里播（玩家主动打开/换屏）：领奖后刷新走的是 UpdateMain，不重播
        this.boxPopIn:Play()
    end

end

local boxSprite = {
    "cn2-X1_yiwang_jiangli_lan",
    "cn2-X1_yiwang_jiangli_lan_open",
    "cn2-X1_yiwang_jiangli_jin",
    "cn2-X1_yiwang_jiangli_jin_open"
}

function BlitzStrikePanel.UpdateMain()
    this.Model[BlitzStrikeManager.difficultyLevel]:SetActive(true)

    for i = 1, #this.StageGo do
        local Status1 = Util.GetGameObject(this.StageGo[i], "Status/Status1")
        local Status2 = Util.GetGameObject(this.StageGo[i], "Status/Status2")
        local Status3 = Util.GetGameObject(this.StageGo[i], "Status/Status3")
        local Click = Util.GetGameObject(this.StageGo[i], "Click")
        Status1:SetActive(false)
        Status2:SetActive(false)
        Status3:SetActive(false)

        local selectFightId = i + (BlitzStrikeManager.difficultyLevel - 1) * BlitzStrikeManager.StageNum
        if selectFightId < BlitzStrikeManager.curFightId then
            Status3:SetActive(true)
        elseif selectFightId == BlitzStrikeManager.curFightId then
            Status2:SetActive(true)
        else
            Status1:SetActive(true)
        end

        Util.AddOnceClick(Click, function()
            if isCanClick then
                if selectFightId == BlitzStrikeManager.curFightId then
                    NetManager.BlitzLevelInfo(function()
                        UIManager.OpenPanel(UIName.BlitzStrikePreFightPopup, BlitzStrikeManager.curFightId, i)
                    end)
                else
                end
            end
        end)
    end

    local StageConfigDatas = BlitzStrikeManager.GetConfigDataByDiff(BlitzStrikeManager.difficultyLevel)
    local BoxSignIdx = {}
    for i = 1, #StageConfigDatas do
        if StageConfigDatas[i].BoxAwards ~= 0 then
            table.insert(BoxSignIdx, StageConfigDatas[i])
        end
    end
    -- 「未开」= 还显示关闭态箱体：没达到的 + 达到但还没领的；已领的换成开箱图，不参与入场
    this.unopenedBoxGo = {}
    for i = 1, #this.BoxGo do
        local N = Util.GetGameObject(this.BoxGo[i], "Bg/box/N")
        local O = Util.GetGameObject(this.BoxGo[i], "Bg/box/O")
        local boxRoot = Util.GetGameObject(this.BoxGo[i], "Bg/box")
        local box = Util.GetGameObject(this.BoxGo[i], "Bg/box/box"):GetComponent("Image")
        local isOpened = false
        N:SetActive(false)
        O:SetActive(false)

        if i == 5 then
            box.sprite = Util.LoadSprite(boxSprite[3])
        else
            box.sprite = Util.LoadSprite(boxSprite[1])
        end

        Util.AddOnceClick(N, function()
        end)
        if BlitzStrikeManager.curFightId > BoxSignIdx[i].Id then
            -- finished
            if BlitzStrikeManager.boxAwardedProgress[BoxSignIdx[i].Id] == nil then
                -- can get
                N:SetActive(true)
                Util.AddOnceClick(N, function()
                    -- 关键关卡领奖 ⇒ 诱导评分（Google Play 内评价）
                    -- 宝箱每 3 关一个（含每档最后一关），后端只允许领一次，
                    -- 所以「领取成功」就等于打完了这一段的关键里程碑；具体弹不弹由 AppReview_TryShowOnKeyLevel 控频。
                    local boxConfigId = BoxSignIdx[i].Id
                    local reviewKey = "blitz_box_" .. tostring(boxConfigId)
                    NetManager.BlitzGetBoxAward(boxConfigId, function(msg)
                        NetManager.BlitzTypeInfo(function()
                            if msg.drop then
                                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                                    -- 等奖励面板关掉再弹，避免内评价盖在领奖动画上
                                    AppReview_TryShowOnKeyLevel(reviewKey)
                                end)
                            else
                                AppReview_TryShowOnKeyLevel(reviewKey)
                            end
                            this.UpdateMain()
                        end)
                    end)
                end)
            else
                isOpened = true
                O:SetActive(true)
                if i == 5 then
                    box.sprite = Util.LoadSprite(boxSprite[4])
                else
                    box.sprite = Util.LoadSprite(boxSprite[2])
                end
            end
        else
            N:SetActive(false)
        end

        if not isOpened then
            this.unopenedBoxGo[#this.unopenedBoxGo + 1] = boxRoot
        end
    end

    local data = BlitzStrikeManager.GetRewardTotal()
    this.scrollView:SetData(data, function(index, root)
        this:SetItem(root, data[index])
    end)
end

function BlitzStrikePanel.UpdateMainUnSelect()
    for i = 1, #this.StageGo do
        local Status1 = Util.GetGameObject(this.StageGo[i], "Status/Status1")
        local Status2 = Util.GetGameObject(this.StageGo[i], "Status/Status2")
        local Status3 = Util.GetGameObject(this.StageGo[i], "Status/Status3")
        Status1:SetActive(false)
        Status2:SetActive(false)
        Status3:SetActive(false)
        if i == 1 then
            Status2:SetActive(true)
        else
            Status1:SetActive(true)
        end
    end
end

function BlitzStrikePanel:SetItem(root, data)
    local itemData = ItemConfig[data[1]]
    Util.GetGameObject(root, "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
    Util.GetGameObject(root, "Num"):GetComponent("Text").text = data[2]
end

--界面关闭时调用（用于子类重写）
function BlitzStrikePanel:OnClose()
    -- 🔴 漏 Stop = 宝箱永久停在 0.45 半截缩放上，下次进来像卡图
    this.boxPopIn:Stop()
end

--界面销毁时调用（用于子类重写）
function BlitzStrikePanel:OnDestroy()
    this.boxPopIn:Stop()
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
end

return BlitzStrikePanel