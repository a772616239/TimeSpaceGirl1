require("Base/BasePanel")
RoleInfoPanel = Inherit(BasePanel)
local this = RoleInfoPanel

--升级升星
local curHeroData       --当前英雄信息
local leftHeroData      --左边预加载英雄信息
local rightHeroData     --右边预加载英雄信息
local heroDatas         --所有英雄list信息
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

--装备
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local PassiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local WarWaySkillConfig = ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)
local WarWaySkillUpgradeCost= ConfigManager.GetAllConfigsDataByKey(ConfigName.WarWaySkillConfig, "Level", 1)

local index                     --当前英雄在 英雄列表中的索引
local costItemList              --升级突破静态材料
local isUpLvMaterials = true    --升级 进阶 材料是否充足
local isUpStarMaterials = true  --升星 材料是否充足
local curSelectUpStarData       --当前选择升星坑位的数据
local curSelectUpStarGo         --当前选择升星坑位的预设
local upStarConsumeMaterial = {}--升星消耗的英雄组   {{1坑位英雄信息}{2坑位英雄信息}{}}
local upStarMaterialIsAll = {}  --升星消耗的英雄组是否满足   {{1满足}{2不满足}{}}
local allAddProVal = {}         --所有属性加成值
local lvUpShowProList = {}      --升级后展示的属性提升list
local skillShowProList = {}     --技能数据
local isHeroUpTuPo = false      --是否可进阶
local isHeroUpStar = false      --是否可升星
local upTuPoRankUpConfig = {}   --即将要突破的数据
local upStarRankUpConfig = {}   --即将要升星的数据
local curTuPoRankUpConfig = {}  --当前突破的数据
local curStarRankUpConfig = {}  --当前升星的数据
local upStarPreList = {}

--长按升级状态
local _isClicked = false            --是否点击
local _isReqLvUp = false
local _isLongPress = false          --是否长按
RoleInfoPanel.timePressStarted = 0  --监听长按事件
this.priThread = nil                --协同程序播放升级属性提升值动画用
local isGoToBattle = false          --当前英雄是否上阵
local isClickLeftOrRightBtn = true  --点击左右按钮切换英雄播放动画状态
local teamHero = {}                 --主线编队成员信息
local isTriggerLongClick = false    --长按是否升过级
this.AddLv = 1                      --升级级数
this.isCanAdvanced = true           --是否进阶
local oldLv = 0
-- local GoToBattleNum = 0             --上阵数量
local liveDeviation                 --立绘偏移
-- local breakLevelOne = {
--     [0] = 30,
--     [1] = 40,
--     [2] = 50,
--     [3] = 60,
--     [4] = 80,
--     [5] = 100,
-- }
-- local StarLevelOne={
--     [5] = 100,
--     [6] = 145,
--     [7] = 165,
--     [8] = 185,
--     [9] = 205,
--     [10] = 255,
--     [11] = 280,
--     [12] = 310,
--     [13] = 340,
-- }

-- this.isStaticLive = false           --是否是静态图
--装备
local effectList = {}
--当前英雄穿的装备
local curHeroEquipDatas = {}
local curEquipTreasureDatas = {}
local curPlanDatas = {}
local totemItem = {}
local orginLayer1
local curSelectEquipData
local curSelectTalentIdx = 1
local HeroMaxLevel = 340            --英雄最大等级
--装备类型
local equipType = {
    [1] = GetLanguageStrById(22623),
    [2] = GetLanguageStrById(22624),
    [3] = GetLanguageStrById(22625),
    [4] = GetLanguageStrById(22626)
}
--锁定按钮
local LockingBtnState = {
    [1] = {txt = string.format("<color=#FFFFFF>%s</color>", GetLanguageStrById(50164)),
        img = Util.LoadSprite("cn2-X1_pinglun_suoding")},
    [2] = {txt = string.format("<color=#A8A8A8>%s</color>", GetLanguageStrById(50165)),
        img =  Util.LoadSprite("cn2-X1_pinglun_yisuoding")}
}

--铸神等级图片
local SpriteName="cn2-X1_zhushen_dengji_0"

--英雄的两个能力是否可以领悟学习升级
local abilityCanShowRedPointState={
    ["ability1"]=false,
    ["ability2"]=false
}

--初始化组件（用于子类重写）
function RoleInfoPanel:InitComponent()
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight})


    this.curObj = Util.GetGameObject(self.transform, "curObj")
    this.leftObj = Util.GetGameObject(self.transform, "leftObj")
    this.rightObj = Util.GetGameObject(self.transform, "rightObj")
    -- self.live2dRoot = Util.GetGameObject(self.gameObject, "live2dRoot")
    this.BtnBack = Util.GetGameObject(self.transform, "rolePanel/btnBack")

    this.isFirstOpen = true --是否首次打开

    this.layout = Util.GetGameObject(self.transform, "rolePanel/layout")

    --页签按钮
    this.btnList = Util.GetGameObject(this.transform, "rolePanel/btnList")
    this.btnInfo = Util.GetGameObject(this.btnList, "btnInfo")              --属性
    this.btnInfoRedPoint = Util.GetGameObject(this.btnInfo, "redPoint")     --属性红点
    this.btnEquip = Util.GetGameObject(this.btnList, "btnEquip")            --装备
    this.btnEquipRedPoint = Util.GetGameObject(this.btnEquip, "redPoint")   --装备红点
    this.btnCulture = Util.GetGameObject(this.btnList, "btnCulture"     )   --培养
    this.btnCultureRedPoint = Util.GetGameObject(this.btnCulture, "redPoint") --培养红点

    this.btnCultureBtnList = Util.GetGameObject(this.layout, "LeftBtn")
    this.btnUpStar = Util.GetGameObject(this.btnCultureBtnList, "btnList/btnUpStar")        --升星
    this.btnUpStarRedpoint = Util.GetGameObject(this.btnUpStar, "redPoint")                 --升星红点
    this.btnAbility = Util.GetGameObject(this.btnCultureBtnList, "btnList/btnAbility")      --能力
    this.btnAbilityRedPoint = Util.GetGameObject(this.btnAbility, "redPoint")               --能力红点
    this.btnChip = Util.GetGameObject(this.btnCultureBtnList, "btnList/btnChip")            --芯片
    this.btnChipRedPoint = Util.GetGameObject(this.btnChip,"redPoint")                      --芯片红点
    -- this.btnOverclock = Util.GetGameObject(this.btnCultureBtnList, "btnList/btnOverclock")  --超频
    -- this.btnFlagArr = Util.GetGameObject(this.btnCultureBtnList, "btnList/btnFlagArr")      --旗阵
    this.btnSelect = Util.GetGameObject(this.btnCultureBtnList, "btnList/selectBtn")        --选择按钮

    --英雄详情结构对象
    this.roleInfoLayout = Util.GetGameObject(this.layout, "roleInfoLayout")
    this.roleEquipLayout = Util.GetGameObject(this.layout, "roleEquipLayout")
    this.roleUpStarLayout = Util.GetGameObject(this.layout, "roleUpStarLayout")
    this.roleAbilityLayout = Util.GetGameObject(this.layout, "roleAbilityLayout")
    this.roleChipLayout = Util.GetGameObject(this.layout, "roleChipLayout")

    --属性
    this.info = Util.GetGameObject(self.transform, "rolePanel/info")
    this.starGrid = Util.GetGameObject(this.info, "starGrid")
    -- this.name = Util.GetGameObject(this.info, "name")
    this.proImage = Util.GetGameObject(this.info, "name/proImage"):GetComponent("Image")
    this.heroName = Util.GetGameObject(this.info, "name/heroName"):GetComponent("Text")
    this.power = Util.GetGameObject(this.info, "powerBg/powerBtn/value"):GetComponent("Text")

    this.core = Util.GetGameObject(this.roleInfoLayout,"core")--核心

    this.posText = Util.GetGameObject(this.roleInfoLayout,"Info/Text"):GetComponent("Text") --定位
    this.pro = Util.GetGameObject(this.roleInfoLayout,"Info/pro")
    this.leftBtn = Util.GetGameObject(this.transform, "rolePanel/leftBtn")
    this.rightBtn = Util.GetGameObject(this.transform, "rolePanel/rightBtn")
    this.atkPro = Util.GetGameObject(this.pro,"atk")
    this.hpPro = Util.GetGameObject(this.pro,"hp")
    this.phyDef = Util.GetGameObject(this.pro,"phyDef")
    this.Speed = Util.GetGameObject(this.pro,"Speed")
    this.profession = Util.GetGameObject(this.pro,"lv/profession")
    this.lv = Util.GetGameObject(this.pro,"lv/proValue"):GetComponent("Text")
    this.maxLv = Util.GetGameObject(this.pro,"lv/proValueMax"):GetComponent("Text")

    this.proHelpBtn = Util.GetGameObject(this.roleInfoLayout,"Info/helpBtn")

    this.skillGrid = Util.GetGameObject(this.roleInfoLayout,"skill")
    for i = 1, 4 do
        skillShowProList[i] = Util.GetGameObject(this.skillGrid, "skillGroup/Skill" .. i)
    end

    --升级
    this.itemPre = Util.GetGameObject(this.roleInfoLayout,"upLv/itemPre")
    this.itemGrid = Util.GetGameObject(this.roleInfoLayout,"upLv/itemGrid")
    this.upLvBtn = Util.GetGameObject(this.roleInfoLayout,"upLvBtn")
    this.upLvTrigger = Util.GetEventTriggerListener(this.upLvBtn)
    this.upClassBtn = Util.GetGameObject(this.roleInfoLayout,"upClassBtn")
    this.maxLvTip = Util.GetGameObject(this.roleInfoLayout,"maxLv")

    this.upLv = Util.GetGameObject(this.roleInfoLayout ,"upLv")
    this.upLvGoldBtn = Util.GetGameObject(this.upLv ,"gold")
    this.upLvGoldText = Util.GetGameObject(this.upLv ,"gold/Text"):GetComponent("Text")

    --升星
    this.upStar = Util.GetGameObject(this.roleUpStarLayout,"upStar")
    this.upStarGrid = Util.GetGameObject(this.upStar,"upStarGrid")
    this.upStarBtn = Util.GetGameObject(this.upStar,"upStarBtn")
    -- this.upStarHelpBtn = Util.GetGameObject(this.roleUpStarLayout,"helpBtn")

    this.goldGrid = Util.GetGameObject(this.upStar,"goldGrid")
    this.goldBtn = Util.GetGameObject(this.goldGrid,"gold")
    this.goldText = Util.GetGameObject(this.goldGrid,"gold/Text"):GetComponent("Text")
    this.goldImage = Util.GetGameObject(this.goldGrid,"gold")
    this.gold2Btn = Util.GetGameObject(this.goldGrid,"gold2")
    this.gold2Text = Util.GetGameObject(this.goldGrid,"gold2/Text"):GetComponent("Text")
    this.gold2Image = Util.GetGameObject(this.goldGrid,"gold2")

    --升星属性
    this.nextStarGrid = Util.GetGameObject(this.upStar, "nextStarGrid")
    this.upInfoPro = Util.GetGameObject(this.upStar, "upInfoPro")

    this.skill = Util.GetGameObject(this.upStar, "skill")
    this.skillFream = Util.GetGameObject(this.skill, "fream"):GetComponent("Image")
    this.skillIcon = Util.GetGameObject(this.skill, "icon"):GetComponent("Image")
    this.skillImage = Util.GetGameObject(this.skill, "skillImage")
    this.skillLv = Util.GetGameObject(this.skill, "skillImage/skillLv"):GetComponent("Text")

    self.dragView = SubUIManager.Open(SubUIConfig.DragView, self.gameObject.transform)
    self.dragView.transform:SetSiblingIndex(4)
    this.trigger = Util.GetEventTriggerListener(self.dragView.gameObject)
    this.trigger.onBeginDrag = this.trigger.onBeginDrag + this.OnBeginDrag
    this.trigger.onDrag = this.trigger.onDrag + this.OnDrag
    this.trigger.onEndDrag = this.trigger.onEndDrag + this.OnEndDrag

    --装备
    this.castGodBtn = Util.GetGameObject(this.roleEquipLayout, "castGodBtn")--铸神
    this.EquipAll = Util.GetGameObject(this.roleEquipLayout, "EquipAll")--快速装备
    this.EquipAllRedPoint = Util.GetGameObject(this.EquipAll, "redPoint")

    this.equipInfo = Util.GetGameObject(this.roleEquipLayout, "equipInfo")
    for i = 1, 8 do
        effectList[i] = Util.GetGameObject(this.equipInfo, "equip" .. i .. "/effect")
    end

    for i = 1, 4 do
        Util.GetGameObject(this.equipInfo, "equip" .. i .. "/text"):GetComponent("Text").text = equipType[i]
    end
    this.equipRedPoint = {} --装备红点
    for i = 1, 8 do
        this.equipRedPoint[i] = Util.GetGameObject(this.equipInfo, "equip" .. i .. "/redPoint")
    end

    this.planGo1 = Util.GetGameObject(self.transform, "roleEquipLayout/equipInfo/equip5")
    this.planGo2 = Util.GetGameObject(self.transform, "roleEquipLayout/equipInfo/equip6")
    this.planGo3 = Util.GetGameObject(self.transform, "roleEquipLayout/equipInfo/equip7")
    this.planGo4 = Util.GetGameObject(self.transform, "roleEquipLayout/equipInfo/equip8")

    this.ResetBtn = Util.GetGameObject(this.roleInfoLayout, "ResetBtn")--重置
    this.LockingBtn = Util.GetGameObject(this.roleInfoLayout, "LockingBtn")--锁定
    this.lockTxt = Util.GetGameObject(this.LockingBtn, "Text"):GetComponent("Text")
    this.CommentBtn = Util.GetGameObject(this.roleInfoLayout, "CommentBtn")--评论

    --能力
    this.preViewBtn = Util.GetGameObject(this.roleAbilityLayout, "preViewBtn")
    this.shopAbilityBtn = Util.GetGameObject(this.roleAbilityLayout, "shopBtn")
    this.abilityHelpBtn = Util.GetGameObject(this.roleAbilityLayout, "helpBtn")
    this.abilityItemGrid = Util.GetGameObject(this.roleAbilityLayout, "ItemGrid")
    this.totemlock = Util.GetGameObject(self.transform, "EquipmentPart/equipInfo/equip7/lock")

    --芯片
    this.atlasChipBtn = Util.GetGameObject(this.roleChipLayout, "btnList/atlasBtn")
    this.manageChipBtn = Util.GetGameObject(this.roleChipLayout, "btnList/manageBtn")
    this.gainChipBtn = Util.GetGameObject(this.roleChipLayout, "btnList/gainBtn")
    this.shopChipBtn = Util.GetGameObject(this.roleChipLayout, "btnList/shopBtn")
    this.chipList = {}
    this.chipRedpointList = {} --芯片红点
    this.chipGroups = Util.GetGameObject(this.roleChipLayout, "chipGrid")
    for i = 1, 4 do
        local chipItem = Util.GetGameObject(this.chipGroups, "chip"..i)
        this.chipList[i] = chipItem
        this.chipRedpointList[i] = Util.GetGameObject(chipItem, "noChip/redpoint")
    end
    this.suit1 = Util.GetGameObject(this.roleChipLayout, "suit1")
    this.suit2 = Util.GetGameObject(this.roleChipLayout, "suit2")
    this.noSuit = Util.GetGameObject(this.roleChipLayout, "noSuit")
end

--绑定事件（用于子类重写）
function RoleInfoPanel:BindEvent()
    Util.AddClick(this.castGodBtn, function()
        UIManager.OpenPanel(UIName.PartsMainPopup, curHeroData, self)
    end)
    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.ResetBtn,function()
        if curHeroData.lv == 1 then
            PopupTipPanel.ShowTip(GetLanguageStrById(12505))
            return
        end

        if isGoToBattle then
            -- if GoToBattleNum < 2 then
                local teamId = HeroManager.GetFormationByHeroId(curHeroData.dynamicId)
                local team = FormationManager.GetFormationByID(teamId).teamHeroInfos
                if #team < 2 then
                    PopupTipPanel.ShowTip(GetLanguageStrById(23163))
                    return
                end
            -- end
            -- PopupTipPanel.ShowTipByLanguageId(11854)
            -- return
        end
        if curHeroData.lockState == 1 then
            PopupTipPanel.ShowTipByLanguageId(11855)
            return
        end

        this.selectHeroData = {}
        this.selectHeroData[curHeroData.dynamicId] = curHeroData
        this.costItemId = 16

        --回溯星级需要的材料ID   selectHeroData选中的当前数据
        if tonumber(LengthOfTable(curHeroData)) == 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(11792))
        else
            -- if BagManager.GetItemCountById(this.costItemId) == 0 then
            --     UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, this.costItemId)
            --     return
            -- end
            -- local teamId = HeroManager.GetFormationByHeroId(curHeroData.dynamicId)
            local dropList, cost = HeroManager.GetHeroReturnItems(this.selectHeroData,GENERAL_POPUP_TYPE.ResolveRecall)
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.ResolveRecall, dropList, this.selectHeroData, cost, function ()
                if isGoToBattle then
                    HeroManager.CompareWarPower(curHeroData.dynamicId)--对比战力并更新战力值 播放战力变更动画
                end
                this:UpdatePanelData()
            end)
        end
    end)

    Util.AddClick(this.LockingBtn,function()
        if curHeroData.lockState == 1 then
            curHeroData.lockState = 0
        elseif curHeroData.lockState == 0 then
            curHeroData.lockState = 1
        end
        NetManager.HeroLockEvent(curHeroData.dynamicId,curHeroData.lockState,function ()
            if curHeroData.lockState == 1 then
                PopupTipPanel.ShowTip(GetLanguageStrById(11853))
            elseif curHeroData.lockState == 0 then
                PopupTipPanel.ShowTip(GetLanguageStrById(11791))
            end
            HeroManager.UpdateSingleHeroLockState(curHeroData.dynamicId, curHeroData.lockState)
            
            this.lockTxt.text = LockingBtnState[curHeroData.lockState + 1].txt
            this.LockingBtn:GetComponent("Image").sprite = LockingBtnState[curHeroData.lockState + 1].img

            for i, v in pairs(heroDatas) do
                if curHeroData == v then
                    v.lockState = curHeroData.lockState
                end
            end
        end)
    end)
    Util.AddClick(this.CommentBtn,function()
        UIManager.OpenPanel(UIName.CommentPanel, curHeroData.heroConfig)
    end)

    --左切换按钮
    Util.AddClick(this.leftBtn, function()
        this:LeftBtnOnClick()
        -- this:UpdatePanelData()
    end)
    --右切换按钮
    Util.AddClick(this.rightBtn, function()
        this:RightBtnOnClick()
        
        -- this:UpdatePanelData()
    end)

    Util.AddClick(this.dragView.gameObject, function()
    end)

    Util.AddClick(this.proHelpBtn,function()
        UIManager.OpenPanel(UIName.RoleProInfoPopup,allAddProVal,curHeroData.heroConfig,true)
    end)

    --角色定位按钮
    Util.AddClick(this.posBtn,function()
        UIManager.OpenPanel(UIName.RolePosInfoPopup,curHeroData.heroConfig)
    end)

    --属性
    Util.AddClick(this.btnInfo, function()
        this:OnClickBtnInfo()
    end)
    --装备
    Util.AddClick(this.btnEquip, function()
        this:OnClickBtnEquip()
    end)
    --培养
    Util.AddClick(this.btnCulture, function()
        this:OnClickBtnCulture()
        this:UpdateHeroUpStarProUpShow()
        this:SelectBtn(this.btnUpStar)
    end)

    --升星
    Util.AddClick(this.btnUpStar, function()
        this:OnClickBtnUpStar()
    end)
    --能力
    Util.AddClick(this.btnAbility, function()
        this:OnClickBtnAbility()
    end)
   
    --芯片
    Util.AddClick(this.btnChip, function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MEDAL) then
            this:OnClickBtnChip()
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.MEDAL))
        end
    end)
    --超频
    Util.AddClick(this.btnOverclock, function()
        this:OnClickBtnOverclock()
    end)
    --旗阵
    Util.AddClick(this.btnFlagArr, function()
        this:OnClickBtnFlagArr()
    end)
    
    --升级
    Util.AddClick(this.upLvBtn, function()
        if UIManager.IsOpen(UIName.RoleRankUpConfirmPopup) then
            return
        end
        self:LvUpClick(true)
        this.isCanAdvanced = true
    end)

    --进阶
    Util.AddClick(this.upClassBtn, function()
        if UIManager.IsOpen(UIName.RoleRankUpConfirmPopup) then
            return
        end
        self:LvUpClick(true)
        this.isCanAdvanced = true
    end)

    -- Util.AddClick(this.up1LvBtn, function()
    -- --长按升级按下状态
    -- this._onPointerDown = function(Pointgo, data)
    --     isTriggerLongClick = false
    --     _isClicked = true
    --     RoleInfoPanel.timePressStarted = Time.realtimeSinceStartup
    --     oldLv = curHeroData.lv
    -- end
    -- -- 长按升级抬起状态
    -- this._onPointerUp = function(Pointgo, data)
    --     if _isLongPress and isTriggerLongClick then
    --         --连续升级抬起请求升级
    --         self:LongLvUpClick(oldLv)
    --     end
    --     _isClicked = false
    --     _isLongPress = false
    -- end
    -- this.upLvTrigger.onPointerDown = this.upLvTrigger.onPointerDown + this._onPointerDown
    -- this.upLvTrigger.onPointerUp = this.upLvTrigger.onPointerUp + this._onPointerUp

    --升星
    Util.AddClick(this.upStarBtn, function()
        -- this.FunctionClickEvent(FUNCTION_OPEN_TYPE.ASSEMBLE, function ()
            self:StarUpClick()
        -- end)
    end)
    --装备
    Util.AddClick(this.equipBtn, function()
        UIManager.OpenPanel(UIName.RoleEquipPanel,curHeroData,heroDatas,this,isGoToBattle)
    end)

    --装备
    this.equip = {}
    for i = 1, 8 do
        this.equip[i] = Util.GetGameObject(this.equipInfo, "equip" .. tostring(i))
        Util.AddClick(this.equip[i], function()
            if i <= 4 then
                UIManager.OpenPanel(UIName.EquipSelectPopup, curHeroData, i, self, nil)
            elseif i == 7 then
                local specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "ExpeditionUnlockLv")
                if curHeroData.star >= tonumber(specialConfig.Value) then
                    if curHeroData.totemId ~= 0 then
                        UIManager.OpenPanel(UIName.ToTemUpLvPopup, curHeroData.totemId,curHeroData)
                    else
                        UIManager.OpenPanel(UIName.ToTemListPopup, curHeroData)
                    end
                else
                    PopupTipPanel.ShowTip(specialConfig.Value .. GetLanguageStrById(10488)) 
                end
            else
                local isOpen, txt = this:checkUnlockCombatPlan(i - 4)
                if not isOpen then
                    PopupTipPanel.ShowTip(txt)
                    return
                end
                UIManager.OpenPanel(UIName.CombatPlanSelectPopup, curHeroData, i, self)
            end
        end)
    end

    --能力预览
    Util.AddClick(this.preViewBtn,function()
        UIManager.OpenPanel(UIName.WarWayPreviewPopup)
    end)
    --能力商城
    Util.AddClick(this.shopAbilityBtn,function()
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.WARWAY_SHOP)
    end)
    --能力帮助
    Util.AddOnceClick(this.abilityHelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.roleSkillLayout,
        this.abilityHelpBtn:GetComponent("RectTransform").localPosition.x - 100,
        this.abilityHelpBtn:GetComponent("RectTransform").localPosition.y)
    end)

    --芯片图谱
    Util.AddClick(this.atlasChipBtn,function()
        UIManager.OpenPanel(UIName.MedalAtlasPopup)
    end)
    --芯片管理
    Util.AddClick(this.manageChipBtn,function()
        UIManager.OpenPanel(UIName.MedalSuitPopup,curHeroData)
    end)
    --芯片获取
    Util.AddClick(this.gainChipBtn,function()
        UIManager.OpenPanel(UIName.ReconnaissancePanel)
    end)
    --芯片商城
    Util.AddClick(this.shopChipBtn,function()
        UIManager.OpenPanel(UIName.MainShopPanel,67)
    end)
end

--添加事件监听（用于子类重写）
function RoleInfoPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.UpdateHeroUpLvAndBreakMaterialShow)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.UpdateHeroUpStarMaterialShow)
    Game.GlobalEvent:AddEvent(GameEvent.HeroGrade.OnHeroGradeChange, this.UpdateHeroInfoData)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnPlayTitleChange, this.UpdateHeroInfoData)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnPlayRingChange, this.UpdateHeroInfoData)
end

--移除事件监听（用于子类重写）
function RoleInfoPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold,this.UpdateHeroUpLvAndBreakMaterialShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold,this.UpdateHeroUpStarMaterialShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.HeroGrade.OnHeroGradeChange, this.UpdateHeroInfoData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnPlayTitleChange, this.UpdateHeroInfoData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnPlayRingChange, this.UpdateHeroInfoData)
end

--界面打开时调用（用于子类重写）（初始数据，英雄数据，是否上阵，上阵数量）
function RoleInfoPanel:OnOpen(_curHeroData, _heroDatas, _isGoToBattle)--, _GoToBattleNum)
    curHeroData, heroDatas, isGoToBattle--[[, GoToBattleNum]] = _curHeroData, _heroDatas, _isGoToBattle--, _GoToBattleNum
    this.btnChip.gameObject:SetActive(ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MEDAL))
end

function RoleInfoPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.RoleInfo })
 
    isClickLeftOrRightBtn = true
    for i = 1, #heroDatas do
        if curHeroData == heroDatas[i] then
            index = i
        end
    end
    teamHero = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_NORMAL)

    --加载立绘
    this:UpdateLiveList()
    this:ShowHeroLive()

    FixedUpdateBeat:Add(this.OnUpdate, self)--长按方法注册

    --装备
    for i = 1, 6 do
        if effectList[i] ~= nil then
            this.SetActive(effectList[i],false)
        end
    end

    this:UpdatePanelData()--刷新页面
    this:OnClickBtnInfo()--默认显示属性
    this:SelectBtn(this.btnUpStar)--默认显示升星

    -- this.ShowHeroEquip()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if this.leftLiveObj and leftHeroData then
        UnLoadHerolive(leftHeroData.heroConfig,this.leftLiveObj)
        Util.ClearChild(this.leftObj.transform)
        this.leftLiveObj = nil
    end
    if this.rightLiveObj and rightHeroData then
        UnLoadHerolive(rightHeroData.heroConfig,this.rightLiveObj)
        Util.ClearChild(this.rightObj.transform)
        this.rightLiveObj = nil
    end
    if this.curLiveObj and curHeroData then
        UnLoadHerolive(curHeroData.heroConfig,this.curLiveObj)
        Util.ClearChild(this.curObj.transform)
        this.curLiveObj = nil
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.HeadFrameView)


    this.leftBtn:GetComponent("Button").enabled = true
    this.rightBtn:GetComponent("Button").enabled = true
    FixedUpdateBeat:Remove(this.OnUpdate, self)
    if this.priThread then
        coroutine.stop(this.priThread)
        this.priThread = nil
    end
end

--加载立绘
function this:ShowHeroLive()
    if this.leftLiveObj and leftHeroData then
        UnLoadHerolive(leftHeroData.heroConfig,this.leftLiveObj)
        Util.ClearChild(this.leftObj.transform)
        this.leftLiveObj = nil
    end
    if this.rightLiveObj and rightHeroData then
        UnLoadHerolive(rightHeroData.heroConfig,this.rightLiveObj)
        Util.ClearChild(this.rightObj.transform)
        this.rightLiveObj = nil
    end
    if this.curLiveObj and curHeroData then
        UnLoadHerolive(curHeroData.heroConfig,this.curLiveObj)
        Util.ClearChild(this.curObj.transform)
        this.curLiveObj = nil
    end

    this.leftLiveObj = LoadHerolive(leftHeroData.heroConfig, this.leftObj)
    this.rightLiveObj = LoadHerolive(rightHeroData.heroConfig, this.rightObj)
    this.curLiveObj = LoadHerolive(curHeroData.heroConfig, this.curObj)

    if this.curLiveObj then
        this.SetActive(this.dragView.gameObject,true)
        this.dragView:SetDragGO(this.curLiveObj)
    else
        this.SetActive(this.dragView.gameObject,false)
    end  
    self.dragView:SetDragGO(this.curLiveObj)
end

--刷新左右立绘
function this:UpdateLiveList()
    local leftIndex = (index - 1 > 0 and index - 1 or #heroDatas)
    leftHeroData = heroDatas[leftIndex]

    curHeroData = heroDatas[index]
    if curHeroData.heroConfig.HeroSound then
        SoundManager.PlaySound(curHeroData.heroConfig.HeroSound)
    end
    local rightIndex = (index + 1 <= #heroDatas and index + 1 or 1)
    rightHeroData = heroDatas[rightIndex]
end

--长按升级处理
function this.OnUpdate()
    if _isClicked then
        if Time.realtimeSinceStartup - RoleInfoPanel.timePressStarted > 0.5 then
            _isLongPress = true
            if not _isReqLvUp then
                _isReqLvUp = true
                this:LvUpClick(false)
            end
        end
    end
end

--更新界面显示
function this:UpdatePanelData()
    this.SetActive(this.core, curHeroData.heroConfig.HeroValue == 1)--核心卡

    if curHeroData.heroConfig.Material == 1 then
        this:UpdateMaterialHeroData()   --刷新材料英雄信息
        return
    end

    if curHeroData.heroConfig.GrowthSwitch then
        this.HideAllLayout()
        this.SetActive(this.roleInfoLayout,true)
        this:SetSelectBtn(this.btnInfo,this.roleInfoLayout)
    end
    this:GetCurHeroUpLvOrUpStarSData()  --获取当前英雄的下一进阶 和 升星 静态数据
    this:UpdateHeroUpStarData()         --更新英雄升星数据
    this:UpdateHeroUpLvAndBreakData()   --更新英雄升级和进阶数据
    this:UpdateHeroInfoData()           --更新英雄信息数据
    this:UpdateSkillData()              --技能信息
    this.UpdateHeroMedalData()          --芯片信息
    this:AbilityUpdateUI()              --能力界面更新
    this.RefreshPlanSlot()              --刷新戒指栏位
    this.ShowHeroEquip()                --装备信息
      if this.roleInfoLayout.activeSelf then
        this.SetActive(this.ResetBtn,curHeroData.lv ~= 1)
    else
        this.SetActive(this.ResetBtn,false)
    end
    
    this:IsMaxLevel()                   --最高级
    this:UpdateHeroEquipCastGod()       --铸造装备解锁
end

--技能信息
function this:UpdateSkillData()
    local oldSkillList = HeroManager.GetSkillIdsByHeroRulesRole(curHeroData.heroConfig.OpenSkillRules,curHeroData.star,curHeroData.breakId, curHeroData)
    local oldOpenPassiveSkillRules = HeroManager.GetPassiveSkillIdsByHeroRuleslock(curHeroData.heroConfig.OpenPassiveSkillRules,curHeroData.star,curHeroData.breakId, curHeroData)
    for key, value in pairs(oldOpenPassiveSkillRules) do
        table.insert(oldSkillList, value)
    end
    table.sort(oldSkillList,function(a,b) 
        return a.skillConfig.Id < b.skillConfig.Id
    end)

    for i = 1, 5 do
        if oldSkillList[i] and i ~= 1 then
            local triggerCallBack
            this.SetActive(skillShowProList[i-1],true)
            local sprite = Util.LoadSprite(GetResourcePath(oldSkillList[i].skillConfig.Icon))
            if sprite == nil then
                LogRed("空资源 资源ID:" .. oldSkillList[i].skillConfig.Icon .. "|资源名:" .. GetResourcePath(oldSkillList[i].skillConfig.Icon));
            end
            
            Util.GetGameObject(skillShowProList[i-1].transform,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(oldSkillList[i].skillConfig.Icon))
            Util.GetGameObject(skillShowProList[i-1].transform,"skillNameTx"):GetComponent("Text").text = GetLanguageStrById(oldSkillList[i].skillConfig.Name)
            local lv
            if SkillLogicConfig[oldSkillList[i].skillConfig.Id] ~= nil  then
                Util.GetGameObject(skillShowProList[i-1].transform,"Lv/LvTx"):GetComponent("Text").text = SkillLogicConfig[oldSkillList[i].skillConfig.Id].Level
                lv = SkillLogicConfig[oldSkillList[i].skillConfig.Id].Level
            else
                Util.GetGameObject(skillShowProList[i-1].transform,"Lv/LvTx"):GetComponent("Text").text = PassiveSkillLogicConfig[oldSkillList[i].skillConfig.Id].Level
                lv = PassiveSkillLogicConfig[oldSkillList[i].skillConfig.Id].Level
            end
            Util.SetGray(Util.GetGameObject(skillShowProList[i-1].transform,"icon"),oldSkillList[i].lock)
            Util.AddOnceClick(skillShowProList[i-1], function()
                if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
                    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                end
                local skillLogicConfig_
                local isPassive
                local skillPos
                if skillLogicConfig_ == nil then
                    skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.SkillLogicConfig,"Id",oldSkillList[i].skillConfig.Id)
                    isPassive = false
                end
                if skillLogicConfig_ == nil then
                    skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.PassiveSkillLogicConfig,"Id",oldSkillList[i].skillConfig.Id)
                    isPassive = true
                end
            
                if isPassive then
                    for j = 1, #curHeroData.heroConfig.OpenPassiveSkillRules do
                        if curHeroData.heroConfig.OpenPassiveSkillRules[j][2] == skillLogicConfig_.Group then
                            skillPos = curHeroData.heroConfig.OpenPassiveSkillRules[j][1]
                            break
                        end
                    end
                else
                    for j = 1, #curHeroData.heroConfig.OpenSkillRules do
                        if curHeroData.heroConfig.OpenSkillRules[j][2] == skillLogicConfig_.Group then
                            skillPos = curHeroData.heroConfig.OpenSkillRules[j][1]
                            break
                        end
                    end
                end
                    local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id,skillPos)             
                    local panel = UIManager.OpenPanel(UIName.SkillInfoPopup,oldSkillList[i],1,10,maxLv,i - 1,lv)
                    Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
                end)
        else
            if i ~= 1 then
                this.SetActive(skillShowProList[i - 1],false)
            end
        end
    end
end

--刷新材料英雄信息
function this:UpdateMaterialHeroData()
    if not this.isFirstOpen then
        this:OnClickBtnInfo()
    end

    self.dragView:SetDragGO(this.curLiveObj)
    SetHeroStars(self.starGrid, curHeroData.star)
    this.heroName.text = GetLanguageStrById(curHeroData.name)
    this.proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(curHeroData.heroConfig.PropertyName))

    this.power.text = 1
    this.posText.text = GetLanguageStrById(curHeroData.heroConfig.HeroLocation)
    this.lv.text = 1
    this.maxLv.text = ""
    this.SetActive(this.profession.gameObject,false)

    this:ProShow(this.atkPro,nil,HeroProType.Attack)
    this:ProShow(this.hpPro,nil,HeroProType.Hp)
    this:ProShow(this.phyDef,nil,HeroProType.PhysicalDefence)
    this:ProShow(this.Speed,nil,HeroProType.Speed)

    this.SetActive(this.upLvBtn,false)
    this.SetActive(this.upClassBtn,false)
    this.SetActive(this.upLv,false)
    this.SetActive(this.ResetBtn,false)
    this.SetActive(this.skillGrid,false)
    this.SetActive(Util.GetGameObject(this.roleInfoLayout,"Bg/hide"),false)
    this.SetActive(this.proHelpBtn,false)
    -- this.SetActive(this.btnInfo,false)
    this.SetActive(this.btnEquip,false)
    this.SetActive(this.btnCulture,false)
    Util.GetGameObject(this.roleInfoLayout,"Info"):GetComponent("Text").enabled = false
    this.SetActive(this.maxLvTip,false)
    this.SetActive(this.LockingBtn,false)
end

--更新英雄信息数据
function this:UpdateHeroInfoData()
    this.SetActive(this.profession.gameObject,true)
    this.SetActive(Util.GetGameObject(this.roleInfoLayout,"Bg/hide"),true)
    this.SetActive(this.proHelpBtn,true)
    this.SetActive(this.btnInfo,true)
    this.SetActive(this.btnEquip,true)
    this.SetActive(this.btnCulture,true)
    this.SetActive(this.skillGrid,true)
    Util.GetGameObject(this.roleInfoLayout,"Info"):GetComponent("Text").enabled = true
    if this.roleInfoLayout.activeSelf then
        this.SetActive(this.LockingBtn,true)
    else
        this.SetActive(this.LockingBtn,false)
    end
    

    this.lockTxt.text = LockingBtnState[curHeroData.lockState + 1].txt
    this.LockingBtn:GetComponent("Image").sprite = LockingBtnState[curHeroData.lockState  + 1].img

    if teamHero[curHeroData.dynamicId] then
        isGoToBattle = true
    else
        isGoToBattle = false
    end

    curTuPoRankUpConfig = heroRankupConfig[curHeroData.breakId]
    curStarRankUpConfig = heroRankupConfig[curHeroData.upStarId]
    if curHeroData.breakId == 0 then
        curTuPoRankUpConfig = heroRankupConfig[1]
    end

    --修改 此处不加阵容属性
    allAddProVal = HeroManager.CalculateHeroAllProValList(1, curHeroData.dynamicId, false)
    this.power.text = allAddProVal[HeroProType.WarPower]

    --属性
    self.dragView:SetDragGO(this.curLiveObj)
    SetHeroStars(self.starGrid, curHeroData.star)
    this.heroName.text = GetLanguageStrById(curHeroData.name)
    this.proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(curHeroData.heroConfig.PropertyName))

    this:ProShow(this.atkPro,allAddProVal,HeroProType.Attack)
    this:ProShow(this.hpPro,allAddProVal,HeroProType.Hp)
    this:ProShow(this.phyDef,allAddProVal,HeroProType.PhysicalDefence)
    this:ProShow(this.Speed,allAddProVal,HeroProType.Speed)

    this.profession:GetComponent("Image").sprite = Util.LoadSprite(ProfessionImage[curHeroData.heroConfig.Profession])
    this.lv.text = curHeroData.lv
    this.maxLv.text = "/" .. this:GetLvEnd()

    -- this.UpdateHeroUpStarProUpSkillShow(this.skillGrid,curHeroData.skillIdList)

    this.posText.text = GetLanguageStrById(curHeroData.heroConfig.HeroLocation)

    Game.GlobalEvent:DispatchEvent(GameEvent.HeroGrade.OnHeroGradeChange)
end

--获取当前最大等级
function this:GetLvEnd()
    local curLvEnd = 30
    if curHeroData.breakId > 0 then
        curLvEnd = heroRankupConfig[curHeroData.breakId].OpenLevel
    end
    if curHeroData.upStarId > 0 then
        if heroRankupConfig[curHeroData.upStarId].OpenLevel > curLvEnd then
            curLvEnd = heroRankupConfig[curHeroData.upStarId].OpenLevel
        end
    end
    return curLvEnd
end

--最高级
function this:IsMaxLevel()
    if not HeroManager.heroLvEnd[curHeroData.heroConfig.Id] or curHeroData.lv >= HeroManager.heroLvEnd[curHeroData.heroConfig.Id] then
        this.SetActive(this.upLv,false)
        this.SetActive(this.maxLvTip,true)
        this.SetActive(this.upLvBtn,false)
        this.SetActive(this.upClassBtn,false)
        return true
    else
        this.SetActive(this.upLv,true)
        this.SetActive(this.maxLvTip,false)
        this.SetActive(this.upLvBtn,true)
        Util.SetGray(this.proHelpBtn, false)
        return false
    end
end

--英雄属性
function this:ProShow(go,allAddProVal,HeroProType)
    local curProSConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,HeroProType)
    Util.GetGameObject(go,"proName"):GetComponent("Text").text = GetLanguageStrById(curProSConFig.Info)
    if allAddProVal == nil then
        Util.GetGameObject(go,"proValue"):GetComponent("Text").text = 1
    else
        Util.GetGameObject(go,"proValue"):GetComponent("Text").text = allAddProVal[HeroProType]
    end
    Util.GetGameObject(go,"Image"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(propertyConfig[HeroProType].PropertyIcon))
end

--更新英雄升级和进阶数据
function this:UpdateHeroUpLvAndBreakData()
    this:UpdateHeroUpLvAndBreakMaterialShow()

    this:RefreshRedPoint()

    -- 升级获取突破 和 升星相应heroRankUpConfig静态数据
  if isHeroUpTuPo and upTuPoRankUpConfig and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
        this.SetActive(this.upLv,false)
        this.SetActive(this.upClassBtn,true)
        this.upLvBtn:SetActive(true)
        -- this.up1LvBtn:SetActive(false)
        _isClicked = false
        _isReqLvUp = false
        return
    else
        this.SetActive(this.upLv,true)
        this.SetActive(this.upClassBtn,false)
    end
end

--刷新红点
function this:RefreshRedPoint()
    this.SetActive(this.btnInfoRedPoint,HeroManager.LvUpBtnRedPoint(curHeroData) and isUpLvMaterials)
    local WearmedalListWear = MedalManager.MedalDaraByHero(curHeroData.dynamicId)
    local isOn = false
    for i = 1, 4 do
        local shipList = MedalManager.MedalDaraBySite(i, curHeroData.dynamicId)
        if #shipList > 0 and not WearmedalListWear[i] then
            if isOn == false then
                isOn = true
            end
        end
    end

    local isCanUpStar = HeroManager.IsShowUpStarRedPoint(curHeroData)
 
    local abilityPointStateRes=HeroManager.GetCurHeroAbilityIsShowRedPoint(curHeroData)
    local isAbility= abilityPointStateRes["ability".. tostring(1)] or abilityPointStateRes["ability".. tostring(2)] 

    this.SetActive(this.btnCultureRedPoint, isGoToBattle and (isOn or isCanUpStar or isAbility)and HeroManager.IsCompetencySkills())
    this.SetActive(this.btnUpStarRedpoint, isGoToBattle and isCanUpStar)
    this.SetActive(this.btnChipRedPoint, isGoToBattle and isOn)
end

--更新英雄升级和进阶的材料显示
function this:UpdateHeroUpLvAndBreakMaterialShow()
    if this.isCanAdvanced == true then
        local costList = {{[1] = 0,[2] = 0},{[1] = 0,[2] = 0}}
        if isHeroUpTuPo and upTuPoRankUpConfig and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
            costItemList = upTuPoRankUpConfig.ConsumeMaterial
        else
            local costData = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv).Consume
            for  m = 4, 0, -1 do
                local isOk = true
                costList = {{[1] = 0,[2] = 0},{[1] = 0,[2] = 0}}
                local lv = m
                for i = 0,m do
                    if curHeroData.lv + i >= HeroMaxLevel - 1 then lv = i break end
                    local costItemList1 = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv+i).Consume
                    if costItemList1 == nil or #costItemList1 <= 1 then break end--确认
                    for j = 1,#costList do
                        costList[j][1] = costData[j][1]
                        costList[j][2] = costList[j][2] + costItemList1[j][2]
                    end
                end
                for n = 1, #costList do
                    if BagManager.GetItemCountById(costList[n][1]) < costList[n][2] then 
                        isOk = false
                    end
                end
                if m == 0 and isOk == false then
                    this.AddLv = lv + 1
                end
                if isOk == true then
                    this.AddLv = lv + 1
                    break
                end
            end
            costItemList = costList
        end
    end

    if not this:IsMaxLevel() then
        Util.ClearChild(this.itemGrid.transform)
        isUpLvMaterials = true
        for i = 1, #costItemList do
            if costItemList[i][1] == 0 then
            elseif costItemList[i][1] ~= 14 then--经验
                local go = newObject(this.itemPre)
                go.transform:SetParent(this.itemGrid.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero
                this.SetActive(go,true)
                Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[costItemList[i][1]].ResourceID))
                if BagManager.GetItemCountById(costItemList[i][1]) < costItemList[i][2] then
                    isUpLvMaterials = false
                    Util.GetGameObject(go.transform,"Text"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s</color>",PrintWanNum2(costItemList[i][2]))
                else
                    Util.GetGameObject(go.transform,"Text"):GetComponent("Text").text = string.format("%s",PrintWanNum2(costItemList[i][2]))
                end
                Util.AddOnceClick(Util.GetGameObject(go.transform,"icon"),function ()
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,costItemList[i][1])
                end)
            else
                --金钱
                if BagManager.GetItemCountById(costItemList[i][1]) < costItemList[i][2] then
                    isUpLvMaterials = false
                    this.upLvGoldText.text = string.format("<color=#FF0000FF>%s</color>",PrintWanNum2(costItemList[i][2]))
                else
                    this.upLvGoldText.text = string.format("%s",PrintWanNum2(costItemList[i][2]))
                end
                Util.AddOnceClick(this.upLvGoldBtn,function()
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,costItemList[i][1])
                end)
            end
        end
    end
end

--更新英雄升星数据
function this:UpdateHeroUpStarData()
    this:UpdateHeroUpStarMaterialShow()
    -- this:UpdateHeroUpLvAndBreakMaterialShow()

    --初始化技能显示
    this.skillIcon.sprite = Util.LoadSprite("cn2-X1_tongyong_mofazhen")
    this.skillIcon.color = Color.New(255/255,255/255,255/255,26/255)
    this.SetActive(this.skillImage,false)

    if curHeroData.star == curHeroData.heroConfig.MaxRank  then
    elseif curHeroData.star > 4 and curHeroData.star < 10 then
        this.skillImage:SetActive(true)
        local skillPos = ConfigManager.TryGetConfigDataByKey(ConfigName.UnlockSkill,"Star",curHeroData.star+1).SkillPos
        local skillLevel = ConfigManager.TryGetConfigDataByKey(ConfigName.UnlockSkill,"Star",curHeroData.star+1).UnlockLV
        local isPassive = false
        local skillGroupID
        for i = 1, #curHeroData.heroConfig.OpenSkillRules do
            if curHeroData.heroConfig.OpenSkillRules[i][1] == skillPos then
                skillGroupID = curHeroData.heroConfig.OpenSkillRules[i][2]
            end
        end
        for i = 1, #curHeroData.heroConfig.OpenPassiveSkillRules do
            if curHeroData.heroConfig.OpenPassiveSkillRules[i][1] == skillPos then
                isPassive = true
                skillGroupID = curHeroData.heroConfig.OpenPassiveSkillRules[i][2]
            end
        end
        local skilllogicconfig = ConfigManager.TryGetConfigDataByDoubleKey(isPassive and ConfigName.PassiveSkillLogicConfig or ConfigName.SkillLogicConfig, "Group", skillGroupID, "Level", skillLevel)
        local skillConfig = ConfigManager.TryGetConfigData(isPassive and ConfigName.PassiveSkillConfig or ConfigName.SkillConfig,skilllogicconfig.Id)
        this.skillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
        this.skillIcon.color = Color.New(255/255,255/255,255/255,255/255)
        this.skillLv.text = skillLevel 

        if curHeroData.star == 5 then
            this.skillIcon.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_yingxiongxiangqing_quanjineng"))
        end
    end

    --进阶祭品条件
    local curUpStarData = HeroManager.GetHeroCurUpStarInfo(curHeroData.dynamicId)
    if curUpStarData and #curUpStarData > 0 then
        this.upStar:SetActive(true)
        upStarConsumeMaterial = {}
        upStarMaterialIsAll = {}
        upStarPreList = {}
        local childCount = this.upStarGrid.transform.childCount
        for i = 1, childCount do
            local go = Util.GetGameObject(this.upStarGrid.transform,"upStarPre"..i)
            local icon = Util.GetGameObject(go.transform,"icon"):GetComponent("Image")
            local frame = Util.GetGameObject(go.transform,"frame"):GetComponent("Image")
            local addBtn = Util.GetGameObject(go.transform,"add")
            local starGrid = Util.GetGameObject(go.transform, "star/starGrid")
            local num = Util.GetGameObject(go.transform,"num"):GetComponent("Text")
            local name = Util.GetGameObject(go.transform,"name"):GetComponent("Text")

            if i <= #curUpStarData then -- 有数据
                num.gameObject:SetActive(true)
                upStarPreList[i] = go
                upStarConsumeMaterial[i] = {}
                upStarMaterialIsAll[i] = 2

                frame.color = Color.New(255/255,255/255,255/255,255/255)
                icon.color = Color.New(255/255,255/255,255/255,255/255)

                if curUpStarData[i].upStarMaterialsData.Issame == 1 or curUpStarData[i].upStarMaterialsData.IsId > 0 then
                    if curUpStarData[i].upStarMaterialsData.Issame == 1 then
                        icon.sprite = Util.LoadSprite(GetResourcePath(curHeroData.heroConfig.Icon))
                        frame.sprite = Util.LoadSprite(GetQuantityImageByquality(curHeroData.heroConfig.Quality, curUpStarData[i].upStarMaterialsData.StarLimit))
                        name.text = GetLanguageStrById(curHeroData.heroConfig.ReadingName)
                    elseif curUpStarData[i].upStarMaterialsData.IsId > 0 then
                        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, curUpStarData[i].upStarMaterialsData.IsId)
                        icon.sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
                        frame.sprite = Util.LoadSprite(GetQuantityImageByquality(heroConfig.Quality, curUpStarData[i].upStarMaterialsData.StarLimit))
                        name.text = GetLanguageStrById(heroConfig.ReadingName)
                    end
                else
                    icon.sprite = Util.LoadSprite(GetNoTargetHero(curUpStarData[i].upStarMaterialsData.StarLimit))
                    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(nil,curUpStarData[i].upStarMaterialsData.StarLimit))
                    name.text = ""
                end

                local upStarHeroListData = HeroManager.GetUpStarHeroListData(curUpStarData[i].upStarMaterialsData.Id,curHeroData)
                addBtn:SetActive(true)
                num.text = string.format("<color=#FF0000FF>%s/%s</color>",0,curUpStarData[i].upStarData[4])
                SetHeroStars(starGrid, curUpStarData[i].upStarMaterialsData.StarLimit)
                starGrid:SetActive(true)
                Util.AddOnceClick(addBtn, function()
                    curSelectUpStarData = curUpStarData[i]
                    curSelectUpStarGo = go
                    local curShowHeroListData = self:SetShowHeroListData(upStarConsumeMaterial,upStarHeroListData.heroList)
                    --参数1 显示的herolist     2 3 升当前星的规则     4 打开RoleUpStarListPanel的界面
                    UIManager.OpenPanel(UIName.RoleUpStarListPanel, curShowHeroListData, curUpStarData[i].upStarMaterialsData, curUpStarData[i].upStarData, this,upStarConsumeMaterial[i], curHeroData)
                end)
            else --无数据
                addBtn:SetActive(false)
                starGrid:SetActive(false)
                num.gameObject:SetActive(false)
                name.text = ""

                frame.sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
                frame.color = Color.New(255/255,255/255,255/255,128/255)
                icon.sprite = Util.LoadSprite("cn2-X1_tongyong_mofazhen")
                icon.color = Color.New(255/255,255/255,255/255,26/255)
            end
        end
    else
        this.SetActive(this.upStar,false)
    end
    --自动选择进阶英雄材料
    this:AutoSelectUpStarHeroList(curUpStarData)
end

--更新英雄升星属性
function this:UpdateHeroUpStarProUpShow()
    if upStarRankUpConfig and upStarRankUpConfig.Id then
        SetHeroStars(this.nextStarGrid, curHeroData.star + 1)

        local upInfoGrid = Util.GetGameObject(this.upStar,"upInfoGrid")
        local Info1 = Util.GetGameObject(upInfoGrid,"upInfoPro1/Info")
        local curLv = HeroManager.GetCurHeroStarLvEnd(1,curHeroData)
        if curLv == nil then
            curLv = 30
        end
        Util.GetGameObject(Info1,"cur"):GetComponent("Text").text = curLv
        Util.GetGameObject(Info1,"next"):GetComponent("Text").text = HeroManager.GetCurHeroStarLvEnd(2,curHeroData,curHeroData.breakId,upStarRankUpConfig.Id)

        local Info2 = Util.GetGameObject(upInfoGrid,"upInfoPro2/Info")
        local Info2Title = Util.GetGameObject(Info2,"title"):GetComponent("Text")
        local Info2Cur = Util.GetGameObject(Info2,"cur"):GetComponent("Text")
        local Info2Next = Util.GetGameObject(Info2,"next"):GetComponent("Text")

        local title2 = ConfigManager.TryGetConfigData(ConfigName.HeroStarConfig,curHeroData.star).Tip
        if title2 == nil then
            Info2Title.text = "--"
        else
            Info2Title.text = GetLanguageStrById(title2)
        end
        local cur2 = ConfigManager.TryGetConfigData(ConfigName.HeroStarConfig,curHeroData.star).Tip1
        if cur2 == nil then
            Info2Cur.text = "--"
        else
            Info2Cur.text = cur2 * 100 .."%"
            if title2 ~= nil and tonumber(title2) == 21010006 then
                Info2Cur.text = cur2
            end
        end
        local next2 = ConfigManager.TryGetConfigData(ConfigName.HeroStarConfig,curHeroData.star).Tip2
        if next2 == nil then
            Info2Next.text = "--"
        else
            Info2Next.text = next2 * 100 .."%"
            if title2 ~= nil and tonumber(title2) == 21010006 then
                Info2Next.text = next2
            end
        end
        
        local Info3 = Util.GetGameObject(upInfoGrid,"upInfoPro3/Info")
        local Info3Title = Util.GetGameObject(Info3,"title"):GetComponent("Text")
        local Info3Cur = Util.GetGameObject(Info3,"cur"):GetComponent("Text")
        local Info3Next = Util.GetGameObject(Info3,"next"):GetComponent("Text")

        local title3 = ConfigManager.TryGetConfigData(ConfigName.HeroStarConfig,curHeroData.star).Tip3
        if title3 == nil then
            Info3Title.text = "--"
        else
            Info3Title.text = GetLanguageStrById(title3)
        end
        local cur3 = ConfigManager.TryGetConfigData(ConfigName.HeroStarConfig,curHeroData.star).Tip4
        if cur3 == nil then
            Info3Cur.text = "--"
        else
            Info3Cur.text = cur3 * 100 .."%"
        end
        local next3 = ConfigManager.TryGetConfigData(ConfigName.HeroStarConfig,curHeroData.star).Tip5
        if  next3 == nil then
            Info3Next.text = "--"
        else
            Info3Next.text = next3 * 100 .."%"
        end

        --是否为最大等级
        if not HeroManager.heroLvEnd[curHeroData.heroConfig.Id] or curHeroData.lv >= HeroManager.heroLvEnd[curHeroData.heroConfig.Id] then
            -- PopupTipPanel.ShowTipByLanguageId(11846)
            _isClicked = false
            _isReqLvUp = false

            this.SetActive(this.maxLvTip,true)
            this.SetActive(this.upLvBtn,false)
            this.SetActive(this.upLv,false)
            this.SetActive(this.upClassBtn,false)
        else
            this.SetActive(this.maxLvTip,false)
            this.SetActive(this.upLvBtn,true)
            this.SetActive(this.upLv,true)
        end
    end
end

--单个技能显示
function this.UpdateHeroUpStarProUpSkillShow(skillGridGO,skillTabs)
    local triggerCallBack
    for i = 1, skillGridGO.transform.childCount do
        local go = skillGridGO.transform:GetChild(i-1).gameObject
        if #skillTabs >= i then
            local curSkillData = skillTabs[i]
            if  curSkillData and curSkillData.skillConfig and  curSkillData.skillConfig.Name then
                this.SetActive(go,true)
                local upGo = Util.GetGameObject(go.transform,"up")
                if upGo then
                    if curSkillData.isShowUpImage ~= nil and curSkillData.isShowUpImage == false then
                        this.SetActive(upGo,false)
                    else
                        this.SetActive(upGo,true)
                    end
                end
                Util.GetGameObject(go.transform,"skillImage/skillName"):GetComponent("Text").text = GetLanguageStrById(curSkillData.skillConfig.Name)
            else
                this.SetActive(go,false)
            end

            Util.AddOnceClick(Util.GetGameObject(go.transform,"icon"), function()
                if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
                    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                end
                local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id,i)
                local skillInfoPopup = UIManager.OpenPanel(UIName.SkillInfoPopup,curSkillData,1,10,maxLv,i)
                skillGridGO:GetComponent("Canvas").sortingOrder = skillInfoPopup.sortingOrder + 1
                triggerCallBack = function (panelType, p)
                    if panelType == UIName.SkillInfoPopup and skillInfoPopup == p then --监听到SkillInfoPopup关闭，把层级设回去
                        skillGridGO:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
                        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                    end
                end
                Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
            end)
        else
            this.SetActive(go,false)
        end
    end
end

------------------------------------------------------升星----------------------------------------------------------
--升星选择祭品后刷新界面
function this:AutoSelectUpStarHeroList(_curUpStarData)
    local curUpStarData = _curUpStarData
    if curUpStarData and #curUpStarData > 0 then
        for i = 1, #curUpStarData do
            curSelectUpStarData = curUpStarData[i]
            curSelectUpStarGo = upStarPreList[i]
            local upStarHeroListData = HeroManager.GetUpStarHeroListData(curUpStarData[i].upStarMaterialsData.Id,curHeroData)
            local curSelectHeroList = {}
            if curUpStarData[i].upStarMaterialsData.Issame == 1 
            or curUpStarData[i].upStarMaterialsData.IsId > 0 then
                if LengthOfTable(upStarHeroListData.heroList) >= curUpStarData[i].upStarData[4] then
                    for i = 1, curUpStarData[i].upStarData[4] do
                        if upStarHeroListData.heroList[i].lockState == 0 and upStarHeroListData.heroList[i].isFormation == "" then
                            table.insert(curSelectHeroList,upStarHeroListData.heroList[i])
                        end
                    end
                    self.UpdateUpStarPosHeroData(curSelectHeroList)
                end
            end
        end
    end
end

--更新英雄升星材料显示
function this:UpdateHeroUpStarMaterialShow()
    --进阶金币 进化药剂条件
    if upStarRankUpConfig then
        isUpStarMaterials = true
        local ConsumeMaterial = upStarRankUpConfig.ConsumeMaterial
        this.SetActive(this.goldGrid,false)
        this.SetActive(this.goldImage,false)
        this.SetActive(this.gold2Image,false)   
        if ConsumeMaterial and #ConsumeMaterial[1] > 1 then
            if ConsumeMaterial[1][2] > 0 then
                this.SetActive(this.goldGrid,true)
                this.SetActive(this.goldImage,true)       
                this.goldImage:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[ConsumeMaterial[1][1]].ResourceID))
                if BagManager.GetItemCountById(ConsumeMaterial[1][1]) < ConsumeMaterial[1][2] then
                    isUpStarMaterials = false
                    this.goldText.color = UIColorNew.RED
                else
                    this.goldText.color = UIColorNew.GREEN
                end
                this.goldText.text = BagManager.GetItemCountById(ConsumeMaterial[1][1]) .. "/" .. ConsumeMaterial[1][2]
                Util.AddOnceClick(this.goldBtn,function()
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,ConsumeMaterial[1][1])
                end)
            else
                this.SetActive(this.goldImage,false)
            end
        end
        if ConsumeMaterial and #ConsumeMaterial >= 2 then
            if ConsumeMaterial[1][2] > 0 then
                this.SetActive(this.goldGrid,true)
                this.SetActive(this.goldImage,true)                
                this.goldImage:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[ConsumeMaterial[1][1]].ResourceID))
                if BagManager.GetItemCountById(ConsumeMaterial[1][1]) < ConsumeMaterial[1][2] then
                    isUpStarMaterials = false
                    this.goldText.color = UIColorNew.RED
                else
                    this.goldText.color = UIColorNew.GREEN
                end
                this.goldText.text = BagManager.GetItemCountById(ConsumeMaterial[1][1]) .. "/" .. ConsumeMaterial[1][2]
                Util.AddOnceClick(this.goldBtn,function()
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,ConsumeMaterial[1][1])
                end)
            else
                this.SetActive(this.goldImage,false)
            end
            if ConsumeMaterial[2][2] > 0 then
                this.SetActive(this.goldGrid,true)
                this.SetActive(this.gold2Image,true)
                this.gold2Image:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[ConsumeMaterial[2][1]].ResourceID))
                if BagManager.GetItemCountById(ConsumeMaterial[2][1]) < ConsumeMaterial[2][2] then
                    isUpStarMaterials = false
                    this.gold2Text.color = UIColorNew.RED
                else
                    this.gold2Text.color = UIColorNew.GREEN
                end
                this.gold2Text.text =  BagManager.GetItemCountById(ConsumeMaterial[2][1]) .. "/" .. ConsumeMaterial[2][2]
                Util.AddOnceClick(this.gold2Btn,function()
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,ConsumeMaterial[2][1])
                end)
            else
                this.SetActive(this.gold2Image,false)
            end
        end
    end
end

--分析设置升星界面显示的英雄list数据    如果当前升星材料的坑位的英雄数据与 以其他坑位有重合并且选择上的英雄不显示  如果是当前坑位显示的英雄显示对勾
--1  消耗的总消耗组  2  当前坑位可选择的所有英雄
function this:SetShowHeroListData(upStarConsumeMaterial,curHeroList)
    local curEndShowHeroListData2 = {}
    for i = 1, #curHeroList do
        table.insert(curEndShowHeroListData2,curHeroList[i])
    end
    local curEndShowHeroListData = {}
    for i, v in pairs(curEndShowHeroListData2)  do
        local isFormations = {}
        for n, w in pairs(FormationManager.formationList) do
            for m = 1, #w.teamHeroInfos do
                if w.teamHeroInfos[m] and v.dynamicId == w.teamHeroInfos[m].heroId then
                    --队伍名称  队伍id
                    local isFormationStr = ""
                    local curFormationId = 0
                    local temp = HeroManager.GetHeroFormationStr2(n)
                    if temp and temp ~= "" then
                        if v.isFormation and v.isFormation == "" then
                            isFormationStr, curFormationId = HeroManager.GetHeroFormationStr2(n)
                            table.insert(isFormations, curFormationId)
                        else
                            isFormationStr, curFormationId = HeroManager.GetHeroFormationStr2(n)
                            isFormationStr = "、" ..isFormationStr
                            table.insert(isFormations, curFormationId)
                            v.isFormation = v.isFormation .. isFormationStr
                        end
                    end
                end
            end
        end
        --所有的所在队伍id，
        curEndShowHeroListData2[i].isFormations = isFormations

        v.isSelect = 2
        table.insert(curEndShowHeroListData,v)
    end
    for j = 1, #upStarConsumeMaterial do
        if upStarConsumeMaterial[j] and #upStarConsumeMaterial[j] > 0 then
            for k = 1, #upStarConsumeMaterial[j] do
                if j == curSelectUpStarData.upStarData[2] then--curSelectUpStarData  当前坑位选择的英雄信息
                    for _, v in pairs(curEndShowHeroListData) do
                        if v.dynamicId == upStarConsumeMaterial[j][k] then
                            v.isSelect = 1
                        end
                    end
                else
                    for i, v in pairs(curEndShowHeroListData) do
                        if v.dynamicId == upStarConsumeMaterial[j][k] then
                            curEndShowHeroListData[i] = nil
                        end
                    end
                end
            end
        end
    end
    local curList = {}
    for _, v in pairs(curEndShowHeroListData) do
        table.insert(curList,v)
    end
    return curList
end

--获取当前英雄的下一进阶 和 升星 静态数据
function this:GetCurHeroUpLvOrUpStarSData()
    isHeroUpTuPo = false
    isHeroUpStar = false
    this.isCanAdvanced = true
    upTuPoRankUpConfig = {}
    upStarRankUpConfig = {}
    this.residualUpLv = 0
    for i, v in ConfigPairs(heroRankupConfig) do
        --初始星级相等
        if v.Star == curHeroData.heroConfig.Star then
            --1进阶
            if v.Show == 1 then
                if v.Id ~= curHeroData.breakId and curHeroData.lv == v.LimitLevel  then  --and curHeroData.star == v.LimitStar
                    isHeroUpTuPo = true
                    upTuPoRankUpConfig = v
                end

                if v.Id ~= curHeroData.breakId and v.LimitLevel - curHeroData.lv <= 5 and curHeroData.lv < v.LimitLevel and v.LimitLevel ~= curHeroData.lv then
                    local costData = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv).Consume
                    for  m = 4, 0, -1 do
                        local isCanBreach = true --是否可突破
                        costItemList = {{[1] = 0,[2] = 0},{[1] = 0,[2] = 0}}
                        for i = 0, m do
                            local costItemListConfig = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv + i).Consume
                            if costItemListConfig == nil then break end
                            for j = 1,#costItemList do
                                costItemList[j][1] = costData[j][1]
                                costItemList[j][2] = costItemList[j][2] + costItemListConfig[j][2]
                            end
                        end
                        --如果材料不足
                        for n = 1, #costItemList do  
                            if BagManager.GetItemCountById(costItemList[n][1]) < costItemList[n][2] then 
                                isCanBreach = false
                            end
                        end
                        if isCanBreach == true then
                            this.AddLv = m + 1
                            break
                        end
                    end

                    local residualAdvanced = v.LimitLevel - curHeroData.lv--还有几级进阶
                    if this.AddLv > residualAdvanced then
                        costItemList = { {[1] = 0,[2] = 0},{[1] = 0,[2] = 0} }
                        for i = 0,residualAdvanced - 1 do
                            local costItemListConfig = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv + i).Consume
                            if costItemListConfig == nil then break end
                            for j = 1,#costItemList do
                                costItemList[j][1] = costData[j][1]
                                costItemList[j][2] = costItemList[j][2] + costItemListConfig[j][2]

                            end
                        end 
                        this.residualUpLv = residualAdvanced
                        this.isCanAdvanced = false
                    else
                        this.residualUpLv = this.AddLv
                    end
                    --return
                end
            end
            --2升星
            if v.Show == 2 then
                if v.Id ~= curHeroData.upStarId  and curHeroData.star == v.LimitStar and curHeroData.star ~= curHeroData.maxStar then
                    upStarRankUpConfig = v
                    isHeroUpStar = true
                    -- return
                end
                if v.Id ~= curHeroData.upStarId  and curHeroData.star == v.LimitStar and curHeroData.star ~= curHeroData.maxStar then--and v.OpenLevel-curHeroData.lv~=0 then
                    local costData = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv).Consume
                    for  m = 4, 0, -1 do
                        local isOk = true
                        costItemList = { {[1] = 0,[2] = 0},{[1] = 0,[2] = 0} }
                        for i = 0,m do
                            local costItemList1 = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv + i).Consume
                            if costItemList1 == nil then break end--确认
                            for j = 1,#costItemList do
                                costItemList[j][1] = costData[j][1]
                                costItemList[j][2] = costItemList[j][2] + costItemList1[j][2]
                            end
                        end
                        for n = 1, #costItemList do  
                            if BagManager.GetItemCountById(costItemList[n][1]) < costItemList[n][2] then 
                                isOk = false
                            end
                        end
                        if isOk == true then
                            this.AddLv = m + 1
                            break
                        end
                    end
                    -- this.num = 0
                    local index = 30
                    if curHeroData.breakId > 0 then
                        index = heroRankupConfig[curHeroData.breakId].OpenLevel
                    end
                    if curHeroData.upStarId > 0 then
                        if heroRankupConfig[curHeroData.upStarId].OpenLevel > index then
                            index = heroRankupConfig[curHeroData.upStarId].OpenLevel
                        end
                    end
                    local nowMaxLevel = index
                    --还有几级升星
                    this.upStarNum = nowMaxLevel - curHeroData.lv
                    if this.AddLv > this.upStarNum and this.upStarNum ~= 0 then
                        costItemList = {{[1] = 0,[2] = 0},{[1] = 0,[2] = 0}}
                        for i = 0,this.upStarNum - 1 do
                            local costItemList1 = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv + i).Consume
                            if costItemList1 == nil then break end--确认
                            for j = 1,#costItemList do
                                costItemList[j][1] = costData[j][1]
                                costItemList[j][2] = costItemList[j][2]+costItemList1[j][2]

                            end
                        end 
                        this.residualUpLv = this.upStarNum
                        this.isCanAdvanced = false
                    else
                        this.residualUpLv = this.AddLv
                    end
                end
            end
        end
    end
end

--刷新当前升星坑位英雄的信息
function this.UpdateUpStarPosHeroData(curSelectHeroList)
    if LengthOfTable(curSelectHeroList) < curSelectUpStarData.upStarData[4] then
        upStarMaterialIsAll[curSelectUpStarData.upStarData[2]] = 2
        this.SetActive(Util.GetGameObject(curSelectUpStarGo.transform,"add"),true)  
        local upStarHeroListData = HeroManager.GetUpStarHeroListData(curSelectUpStarData.upStarMaterialsData.Id,curHeroData)
        if upStarHeroListData.state <= 0 then
            this.SetActive(Util.GetGameObject(curSelectUpStarGo.transform,"add"),false)
        end
        Util.GetGameObject(curSelectUpStarGo.transform,"num"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s/%s</color>", LengthOfTable(curSelectHeroList),curSelectUpStarData.upStarData[4])
    else
        upStarMaterialIsAll[curSelectUpStarData.upStarData[2]] = 1
        -- this.SetActive(Util.GetGameObject(curSelectUpStarGo.transform,"add"),false)
        Util.GetGameObject(curSelectUpStarGo.transform,"num"):GetComponent("Text").text = string.format("<color=#FFFFFFFF>%s/%s</color>", LengthOfTable(curSelectHeroList),curSelectUpStarData.upStarData[4])
    end
    local curUpStarConsumeMaterial = {}
    for i, v in pairs(curSelectHeroList) do
        table.insert(curUpStarConsumeMaterial,v.dynamicId)
    end
    upStarConsumeMaterial[curSelectUpStarData.upStarData[2]] = curUpStarConsumeMaterial
end

--跳转直接到进阶界面
function this.JumpOnClickBtnUpStar()
    this:OnClickBtnUpStar()
end

------------------------------------------------------升级----------------------------------------------------------
--升级按钮点击事件处理 --isSingleLvUp 是否单次升级
function this:LvUpClick(isSingleLvUp)
    if this:IsMaxLevel() then
        curHeroData.lv = HeroMaxLevel
        PopupTipPanel.ShowTip(GetLanguageStrById(11846))
        _isClicked = false
        _isReqLvUp = false
        return
    end

    --判断是否达到阶级上限
    --当前突破全部完成
    if isHeroUpStar and upStarRankUpConfig and curTuPoRankUpConfig and curTuPoRankUpConfig.JudgeClass == 1 and curHeroData.lv >= curTuPoRankUpConfig.OpenLevel then
        --升星过处理
        if curStarRankUpConfig then
            if curHeroData.lv >= curStarRankUpConfig.OpenLevel then --OpenLevel开放等级
                _isClicked = false
                _isReqLvUp = false
                MsgPanel.ShowTwo(GetLanguageStrById(11847), nil, function()
                    this:OnClickBtnCulture()
                    this:UpdateHeroUpStarProUpShow()
                    this:OnClickBtnUpStar()
                end,GetLanguageStrById(10719),GetLanguageStrById(11848))
            else
                --材料足够
                if isUpLvMaterials then
                    --单次升级
                    if isSingleLvUp then
                        local curUpLv = curHeroData.lv
                        if this.isCanAdvanced then
                            curUpLv = curHeroData.lv + this.AddLv
                        else
                            curUpLv = curHeroData.lv + this.residualUpLv
                        end
                        NetManager.HeroLvUpEvent(curHeroData.dynamicId,curUpLv,curHeroData.lv,function (msg)
                            self:DeleteLvUpMaterials(isSingleLvUp,msg)
                        end)
                    else
                        isTriggerLongClick = true
                        self:DeleteLvUpMaterials(isSingleLvUp)
                    end
                else
                    _isClicked = false
                    _isReqLvUp = false
                    if isHeroUpTuPo and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
                        PopupTipPanel.ShowTipByLanguageId(11849)
                    else
                        PopupTipPanel.ShowTipByLanguageId(11850)
                    end
                end
            end
        else
            --第一次升星处理
            _isClicked = false
            _isReqLvUp = false
            MsgPanel.ShowTwo(GetLanguageStrById(11847), nil, function()
                this:OnClickBtnCulture()
                this:UpdateHeroUpStarProUpShow()
                this:OnClickBtnUpStar()
            end,GetLanguageStrById(10719),GetLanguageStrById(11848))
        end
    else
        if isUpLvMaterials then
            --单次升级
            if isSingleLvUp then
                local curUpLv = curHeroData.lv --初始等级
                if isHeroUpTuPo and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
                    UIManager.OpenPanel(UIName.RoleRankUpConfirmPopup,
                        curHeroData,
                        upTuPoRankUpConfig,
                        upTuPoRankUpConfig.OpenLevel,
                        upTuPoRankUpConfig.ConsumeMaterial,
                        function ()
                        curUpLv = curHeroData.lv
                        if curUpLv > HeroMaxLevel then
                            curUpLv = HeroMaxLevel
                        end
                        NetManager.HeroLvUpEvent(curHeroData.dynamicId,curUpLv,curHeroData.lv,function (msg)
                            self:DeleteLvUpMaterials(isSingleLvUp, msg)
                        end)
                    end)
                    curUpLv = curHeroData.lv
                else
                    if HeroManager.heroLvEnd[curHeroData.heroConfig.Id] - curHeroData.lv <= 5 then
                        this.AddLv = HeroManager.heroLvEnd[curHeroData.heroConfig.Id] - curHeroData.lv
                    end

                    if this.isCanAdvanced then
                        curUpLv = curHeroData.lv + this.AddLv
                    else
                        for i, v in ConfigPairs(heroRankupConfig) do
                            if v.Star == curHeroData.heroConfig.Star then
                                if v.Show == 1 then
                                    if v.Id ~= curHeroData.breakId and v.LimitLevel - curHeroData.lv <= 5 and curHeroData.lv < v.LimitLevel and v.LimitLevel ~= curHeroData.lv then
                                        this.residualUpLv = v.LimitLevel - curHeroData.lv
                                    end
                                end
                            end
                        end
                        curUpLv = curHeroData.lv + this.residualUpLv
                    end
                    if curUpLv > HeroMaxLevel then
                        curUpLv = HeroMaxLevel
                    end
                    NetManager.HeroLvUpEvent(curHeroData.dynamicId,curUpLv,curHeroData.lv,function (msg)
                        self:DeleteLvUpMaterials(isSingleLvUp,msg)
                    end)
                end
            else
                if curHeroData.lv <= this:GetLvEnd() then
                    isTriggerLongClick = true
                    self:DeleteLvUpMaterials(isSingleLvUp)
                end
            end
        else
            _isClicked = false
            _isReqLvUp = false
            if isHeroUpTuPo and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
                PopupTipPanel.ShowTipByLanguageId(11849)
            else
                PopupTipPanel.ShowTipByLanguageId(11850)
            end
        end
    end
end
function RoleInfoPanel:LvUpClickOne(isSingleLvUp)
     --是否为最大等级
     if curHeroData.lv >= HeroManager.heroLvEnd[curHeroData.heroConfig.Id] then
        PopupTipPanel.ShowTip(GetLanguageStrById(11846))
        _isClicked = false
        _isReqLvUp = false
        return
    end
    
    -- 突破新增加条件
    local heroRankUpConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
    --突破等级
    local breaklevel
    -- local iscompletely = false
    if heroRankUpConfig[curHeroData.breakId] then
        breaklevel= heroRankUpConfig[curHeroData.breakId].Phase[2]
    else
        breaklevel=0
    end
    -- if (curHeroData.star == 5 and breaklevel == 5) or breaklevel == 6 or curHeroData.star <= 4 then
    --   iscompletely = true
    -- end
    --判断是否达到阶级上限
    if isUpLvMaterials then
        if isSingleLvUp then--是否是单次升级
            local curUpLv = curHeroData.lv
            if isHeroUpTuPo and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
                UIManager.OpenPanel(UIName.RoleRankUpConfirmPopup,curHeroData,upTuPoRankUpConfig,upTuPoRankUpConfig.OpenLevel,upTuPoRankUpConfig.ConsumeMaterial,function ()
                    curUpLv = curHeroData.lv
                    NetManager.HeroLvUpEvent(curHeroData.dynamicId,curUpLv,curHeroData.lv,function (msg)
                        self:DeleteLvUpMaterials(isSingleLvUp,msg)
                    end)
                end)
                curUpLv = curHeroData.lv
            else
                curUpLv = curHeroData.lv + 1
                NetManager.HeroLvUpEvent(curHeroData.dynamicId,curUpLv,curHeroData.lv,function (msg)
                    self:DeleteLvUpMaterials(isSingleLvUp,msg)
                end)
            end
        else
            isTriggerLongClick = true
            self:DeleteLvUpMaterials(isSingleLvUp)
        end
    else
        _isClicked = false
        _isReqLvUp = false
        if isHeroUpTuPo and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
            PopupTipPanel.ShowTip(GetLanguageStrById(11849))
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(11850))
        end
    end
end
--长按升级结束后请求协议
function this:LongLvUpClick(oldLv)
    NetManager.HeroLvUpEvent(curHeroData.dynamicId,curHeroData.lv,oldLv,function (msg)
        self:DeleteLvUpMaterials2(msg)
    end)
end

--升星按钮点击事件处理
function this:StarUpClick()
    if curHeroData.lv >= HeroManager.heroLvEnd[curHeroData.heroConfig.Id] then
        return
    end
    if curHeroData.lv < upStarRankUpConfig.LimitLevel then
        PopupTipPanel.ShowTip(GetLanguageStrById(11851) .. upStarRankUpConfig.LimitLevel)
        return
    end

    local isUpStarMaterialsHero = true --升星英雄材料是否足够
    for i = 1, #upStarMaterialIsAll do
        if upStarMaterialIsAll[i] == 2 then
            isUpStarMaterialsHero = false
        end
    end
    if isUpStarMaterials and isUpStarMaterialsHero then
        NetManager.HeroUpStarEvent(curHeroData.dynamicId, upStarConsumeMaterial, function (msg)
            UIManager.OpenPanel(UIName.RoleUpStarSuccessPanel,curHeroData,upStarRankUpConfig.Id,upStarRankUpConfig.OpenLevel,function ()
                local dropItemTabs = BagManager.GetTableByBackDropData(msg)
                if #dropItemTabs > 0 then
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg, 1, function ()
                        self:DeleteUpStarMaterials()
                        self:UpdateHeroUpStarProUpShow()
                    end)
                else
                    self:DeleteUpStarMaterials()
                    self:UpdateHeroUpStarProUpShow()
                end
            end)
        end)
        -- 进阶音效
        PlaySoundWithoutClick(SoundConfig.Sound_Recruit3)

        CombatPlanManager.RequestAllPlanData(function()end)
    else
        PopupTipPanel.ShowTipByLanguageId(11852)
    end
end

--扣除升级 突破 消耗的材料  更新英雄数据
function this:DeleteLvUpMaterials(isSingleLvUp,msg)
    --连续升级的时候需要自己先扣除
    if isSingleLvUp == false then
        for i = 1, #costItemList do
            BagManager.HeroLvUpUpdateItemsNum(costItemList[i][1],costItemList[i][2])
        end
    end
    for i, v in pairs(heroDatas) do
        if curHeroData == v then
            if isHeroUpTuPo and upTuPoRankUpConfig and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
                UIManager.OpenPanel(UIName.RoleUpLvBreakSuccessPanel,curHeroData,upTuPoRankUpConfig.Id,upTuPoRankUpConfig.OpenLevel)
                curHeroData.breakId = upTuPoRankUpConfig.Id
                v.breakId = curHeroData.breakId
                --突破有可能会升星
                if curHeroData.star < upTuPoRankUpConfig.OpenStar then
                    curHeroData.star = upTuPoRankUpConfig.OpenStar
                    v.star = curHeroData.star
                end
                _isClicked = false
                _isReqLvUp = false
            else
                if msg then
                    curHeroData.lv = msg.targetLevel
                else
                    curHeroData.lv = curHeroData.lv + 1
                end
                v.lv = curHeroData.lv
            end
        end
    end
    --刷新英雄库里单个英雄数据
    if isHeroUpTuPo and upTuPoRankUpConfig and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
        -- 突破音效
        PlaySoundWithoutClick(SoundConfig.Sound_Breach)
    else
        -- 升级音效
        PlaySoundWithoutClick(SoundConfig.Sound_Upgrade)
    end
    HeroManager.UpdateSingleHeroDatas(curHeroData.dynamicId,curHeroData.lv,curHeroData.star,curHeroData.breakId,curHeroData.upStarId,isSingleLvUp)
    local allAddProValOld = allAddProVal
    this.ShowProAddVal(allAddProValOld)
    this:UpdatePanelData()--刷新界面

    _isReqLvUp = false
end

--连续升级更新后端英雄数据
function this:DeleteLvUpMaterials2(msg)
    for i, v in pairs(heroDatas) do
        if curHeroData == v then
            if msg  then
                curHeroData.lv = msg.targetLevel
            end
            v.lv = curHeroData.lv
        end
    end
    HeroManager.UpdateSingleHeroDatas(curHeroData.dynamicId,curHeroData.lv,curHeroData.star,curHeroData.breakId,curHeroData.upStarId,true)
    this:UpdatePanelData()--刷新界面
end

--扣除升星 消耗的材料  更新英雄数据
function this:DeleteUpStarMaterials()
    HeroManager.UpdateSingleHeroDatas(curHeroData.dynamicId,curHeroData.lv,curHeroData.star+1,curHeroData.breakId,upStarRankUpConfig.Id,true)
    HeroManager.UpdateSingleHeroSkillData(curHeroData.dynamicId)
    for i, v in pairs(heroDatas) do
        if curHeroData == v then
            curHeroData = HeroManager.GetSingleHeroData(curHeroData.dynamicId)
            v = curHeroData
        end
    end
    --本地数据删除材料英雄
    for i = 1, #upStarConsumeMaterial do
        HeroManager.DeleteHeroDatas(upStarConsumeMaterial[i])
    end
    if HeroManager.heroListPanelProID ~= ProIdConst.All then
        heroDatas = HeroManager.GetHeroDataByProperty(HeroManager.heroListPanelProID)
    else
        heroDatas = HeroManager.GetAllHeroDatas()
    end
    if UIManager.IsOpen(UIName.RoleInfoPanel) then--当界面存在时需要刷新当前界面
        this:SortHeroDatas(heroDatas)

        if this.leftLiveObj and leftHeroData then
            UnLoadHerolive(leftHeroData.heroConfig,this.leftLiveObj)
            this.leftLiveObj = nil
        end
        if this.rightLiveObj and rightHeroData then
            UnLoadHerolive(rightHeroData.heroConfig,this.rightLiveObj)
            this.rightLiveObj = nil
        end
        if this.curLiveObj and curHeroData then
            UnLoadHerolive(curHeroData.heroConfig,this.curLiveObj)
            this.curLiveObj = nil
        end
        Util.ClearChild(this.curObj.transform)
        Util.ClearChild(this.leftObj.transform)
        Util.ClearChild(this.rightObj.transform)

        for i = 1, #heroDatas do
            if curHeroData == heroDatas[i] then
                index = i
            end
        end
        this:UpdateLiveList()

        this.leftLiveObj = LoadHerolive(leftHeroData.heroConfig,this.leftObj)
        this.rightLiveObj = LoadHerolive(rightHeroData.heroConfig,this.rightObj)
        this.curLiveObj = LoadHerolive(curHeroData.heroConfig,this.curObj)

        self.dragView:SetDragGO(this.curLiveObj)
        this:UpdatePanelData()
    end
end

--排序
function this:SortHeroDatas(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if (teamHero[a.dynamicId] and teamHero[b.dynamicId]) or
                (not teamHero[a.dynamicId] and not teamHero[b.dynamicId])
        then
                if a.heroConfig.Natural == b.heroConfig.Natural then
                    if a.star == b.star then
                        if a.lv == b.lv then
                            return a.heroConfig.Id < b.heroConfig.Id
                        else
                            return a.lv > b.lv
                        end
                    else
                        return a.star > b.star
                    end
                else
                    return a.heroConfig.Natural > b.heroConfig.Natural
                end
        else
            return teamHero[a.dynamicId] and not teamHero[b.dynamicId]
        end
    end)
end

--播放升级 属性提升动画
function this.ShowProAddVal(allAddProValOld)
    this.ThreadShowProAddVal()
end
function this.ThreadShowProAddVal()
    if this.priThread then
        coroutine.stop(this.priThread)
        this.priThread = nil
    end
    table.walk(lvUpShowProList, function(privilegeItem)
        this.SetActive(privilegeItem,false)
    end)
    this.priThread = coroutine.start(function()
        for i = 1, 4 do
            -- lvUpShowProList[i]:SetActive(false)
            -- PlayUIAnims(lvUpShowProList[i])
            -- coroutine.wait(0.04)
            -- lvUpShowProList[i]:SetActive(true)
            -- coroutine.wait(0.08)
        end
        -- this.lvUpGo:SetActive(false)
    end)
end

--跳转显示新手提示圈
function this.ShowGuideGo(type)--1 升级突破  2 进阶
    if type == 1 then
        JumpManager.ShowGuide(UIName.RoleInfoPanel,this.upLvBtn)
    elseif type == 2 then
        --local btn = Util.GetGameObject(this.upStarGrid.transform, "upStarPre3")
        JumpManager.ShowGuide(UIName.RoleInfoPanel,this.upClassBtn)

    -- 我要变强跳转过来显示小手
    elseif type == -1 then
        JumpManager.ShowGuide(UIName.RoleInfoPanel,this.upLvBtn)
    elseif type == -2 then
        JumpManager.ShowGuide(UIName.RoleInfoPanel,this.equipBtn)
    elseif type == -3 then
        JumpManager.ShowGuide(UIName.RoleInfoPanel,this.soulPrintBtn)
    elseif type == -4 then
        JumpManager.ShowGuide(UIName.RoleInfoPanel,this.talismanClick)
    end
end

------------------------------------------------------装备----------------------------------------------------------
--展示英雄装备
function this.ShowHeroEquip()
    this.RefreshPlanSlot()
    -- this.RefreshTotemState()
    --装备的数据
    curHeroEquipDatas = {}
    for i = 1, #curHeroData.equipIdList do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(curHeroData.equipIdList[i], curHeroData.dynamicId)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        end
    end

    --戒指
    curPlanDatas = {}
    for i = 1, #curHeroData.planList do
        local sData = curHeroData.planList[i]
        local bData = CombatPlanManager.GetPlanData(sData.planId)

        curPlanDatas[sData.position + 4] = {sData = sData, bData = bData}
    end

    for i = 1, this.equipInfo.transform.childCount do
        local go = this.equipInfo.transform:GetChild(i - 1).gameObject
        local effect = Util.GetGameObject(go, "effect")
        -- local frame = Util.GetGameObject(go, "frame"):GetComponent("Image")
        local mask = Util.GetGameObject(go, "mask")
        local item = Util.GetGameObject(go, "item"):GetComponent("Image")
        local icon = Util.GetGameObject(go, "item/icon"):GetComponent("Image")
        local pro = Util.GetGameObject(go, "item/pro")
        local addLv = Util.GetGameObject(go, "AddLv"):GetComponent("Image")

        --装备铸神
        local nowAddLevel = this.ShowAddLevel(i)
        if nowAddLevel > 0 then
            addLv.gameObject:SetActive(true)
            addLv.sprite = Util.LoadSprite(SpriteName..nowAddLevel)
        else
            addLv.gameObject:SetActive(false)
        end

        effectList[i] = effect
        if curHeroEquipDatas[i] then
            this.SetActive(item.gameObject, true)
            this.SetActive(pro,false)
            icon.sprite = Util.LoadSprite(curHeroEquipDatas[i].icon)
            item.sprite = Util.LoadSprite(curHeroEquipDatas[i].frame)

            EquipManager.SetEquipStarShow(
                Util.GetGameObject(go.transform, "item/star"),
                curHeroEquipDatas[i].itemConfig.Id
            )
            this.equip[i]:GetComponent("Button").enabled = false
        elseif curPlanDatas[i] then
            this.SetActive(item.gameObject, true)
            this.SetActive(mask, false)
            this.SetActive(pro,false)
            local config = G_CombatPlanConfig[curPlanDatas[i].bData.combatPlanId]
            if config.Quality ~= 6 then
                item.sprite = Util.LoadSprite(GetQuantityImageByquality(config.Quality + 1))
            else
                item.sprite = Util.LoadSprite(GetQuantityImageByquality(config.Quality))
            end
            icon.sprite = Util.LoadSprite(config.Icon)
        elseif totemItem[i] then 
            -- frame.gameObject:SetActive(true)
            this.SetActive(mask, false)
            local itemData = TotemManager.GetOneTotemData(TotemManager.GetTotemIdById(totemItem[i]))
            icon.sprite = Util.LoadSprite(itemData.icon)
            item.sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(itemData.Totemconfig.Color))
        else
            this.SetActive(item.gameObject, false)
            -- this.SetActive(frame.gameObject, false)
            this.SetActive(mask, true)

            if Util.GetGameObject(go, "num") then
                this.SetActive(Util.GetGameObject(go, "num").gameObject, false)
            end

            this.equip[i]:GetComponent("Button").enabled = true
        end
        Util.AddOnceClick(
            icon.gameObject,
            function()
                if curHeroEquipDatas[i] then
                    curSelectEquipData = curHeroEquipDatas[i]
                    UIManager.OpenPanel(UIName.RoleEquipChangePopup, this, 1, curHeroData, curHeroEquipDatas[i], i)
                elseif curPlanDatas[i] then
                    UIManager.OpenPanel(UIName.CombatPlanTipsPopup, 1, this, curPlanDatas[i], curHeroData)
                elseif totemItem[i] then
                    UIManager.OpenPanel(UIName.ToTemUpLvPopup, curHeroData.totemId,curHeroData)
                end
            end
        )
    end
    --红点
    local isHaveBatter,isHave,isNull = this:CheckEquipHaveWear()
    local hasBetterRings,betterRingsState=HeroManager.GetRingsIsShowRedPoin(curHeroData)
    if betterRingsState ~= nil then
        if isHaveBatter or isHaveBatter or isHave then
            this.SetActive(this.EquipAllRedPoint,true)
            this.SetActive(this.btnEquipRedPoint,true)
        elseif betterRingsState["Rings1"] or betterRingsState["Rings2"] then
            this.SetActive(this.btnEquipRedPoint,true)
            if isHaveBatter==false then
                this.SetActive(this.EquipAllRedPoint,false)
            end

        elseif not betterRingsState["Rings1"] and not betterRingsState["Rings2"] then
            this.SetActive(this.btnEquipRedPoint,false)
            this.SetActive(this.EquipAllRedPoint,false)

        else
            this.SetActive(this.EquipAllRedPoint,false)
            this.SetActive(this.btnEquipRedPoint,false)
        end
    elseif isHaveBatter then
        this.SetActive(this.btnEquipRedPoint,true)
    else
        this.SetActive(this.btnEquipRedPoint,false)
    end
    if isHaveBatter then
            this.EquipAll:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_yingxiongxiangqing_kuaisuzhuangbei"))
            this.EquipAll:GetComponent("RectTransform").sizeDelta = Vector2.New(660,253)
            Util.AddOnceClick(this.EquipAll, function()  this:AllEquipUp() end)
    else
        if isHave then
            this.EquipAll:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_yingxiongxiangqing_kuaisuzhuangbei"))
            this.EquipAll:GetComponent("RectTransform").sizeDelta = Vector2.New(660,253)
            Util.AddOnceClick(this.EquipAll, function() this:AllEquipDown() end)   
        else
            if isNull then
                this.EquipAll:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_yingxiongxiangqing_yijianxiexia"))
                this.EquipAll:GetComponent("RectTransform").sizeDelta = Vector2.New(332,124)
                Util.AddOnceClick(this.EquipAll, function() this:AllEquipDown() end)
            else
                this.EquipAll:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_yingxiongxiangqing_kuaisuzhuangbei"))
                this.EquipAll:GetComponent("RectTransform").sizeDelta = Vector2.New(660,253)
                Util.AddOnceClick(this.EquipAll, function() PopupTipPanel.ShowTipByLanguageId(23122) end)
            end
        end
    end

    this:RefreshEquipRedPoint()
end

-- 刷新戒指栏位
function this.RefreshPlanSlot()
    local lock1 = Util.GetGameObject(this.planGo1, "lock")
    local text1 = Util.GetGameObject(this.planGo1, "text"):GetComponent("Text")
    local lock2 = Util.GetGameObject(this.planGo2, "lock")
    local text2 = Util.GetGameObject(this.planGo2, "text"):GetComponent("Text")

    local isOpen1, txt1 = this:checkUnlockCombatPlan(1)
    local isOpen2, txt2 = this:checkUnlockCombatPlan(2)

    if not isOpen1 then
        text1.text = txt1
        this.SetActive(lock1,true)
        this.SetActive(Util.GetGameObject(this.planGo1, "mask"),false)
        this.SetActive(Util.GetGameObject(this.planGo1, "add"),false)
    else
        text1.text = ""
        this.SetActive(lock1,false)
    end
    if not isOpen2 then
        text2.text = txt2
        this.SetActive(lock2,true)
        this.SetActive(Util.GetGameObject(this.planGo2, "mask"),false)
        this.SetActive(Util.GetGameObject(this.planGo2, "add"),false)
    else
        text2.text = ""
        this.SetActive(lock2,false)
    end
end

--[[
function this.RefreshTotemState()
    local mask = Util.GetGameObject(this.planGo3, "mask")
    local lock = Util.GetGameObject(this.planGo3, "lock")
    local add = Util.GetGameObject(this.planGo3, "add")
    local text = Util.GetGameObject(this.planGo3, "text"):GetComponent("Text")

    local specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "ExpeditionUnlockLv")
    if curHeroData.star >= tonumber(specialConfig.Value) then
        text.text = ""
        add:SetActive(true)
        lock:SetActive(false)
        mask:SetActive(true)
    else
        text.text = specialConfig.Value .. GetLanguageStrById(10488)
        add:SetActive(false)
        lock:SetActive(true)
        mask:SetActive(false)
    end
end
]]

function this:UpdateHeroEquipCastGod()
    local isLock = this:checkUnlockEquipCastGod()
    this.castGodBtn:SetActive(isLock)
end

--刷新当前英雄装备坑位的信息 _equipOrTreasure 1装备 2宝物 3作战方案 默认更新装备铸神
function this.UpdateEquipPosHeroData(_equipOrTreasure, _type, _selectEquipDataList, _oldSelectEquip, position)
    --type 1.穿单件装备  2.卸单件装备 3.替换单件装备 4.一键穿装备  5.一键脱装备
    if _type == 1 then
        this.SetActive(effectList[position],false)
        this.SetActive(effectList[position],true)
        if _equipOrTreasure == 1 then
            curSelectEquipData = _selectEquipDataList[1]
            --装备绑英雄
            EquipManager.SetEquipUpHeroDid(curSelectEquipData.id, curHeroData.dynamicId)
            --英雄加装备
            table.insert(curHeroData.equipIdList, curSelectEquipData.id)
            HeroManager.SetHeroEquipIdList(curHeroData.dynamicId, curHeroData.equipIdList)
        elseif _equipOrTreasure == 2 then
            curEquipTreasureDatas = _selectEquipDataList[1]
            --装备绑英雄
            EquipTreasureManager.SetEquipTreasureUpHeroDid(curEquipTreasureDatas.idDyn, curHeroData.dynamicId)
            --英雄加装备
            table.insert(curHeroData.jewels, curEquipTreasureDatas.idDyn)
        elseif _equipOrTreasure == 3 then
            --英雄绑plan
            --_selectEquipDataList 传入值 为直接Did 目前逻辑满足不了一键
            local planDid = _selectEquipDataList
            local oldPlanList = {}
            for i = 1, #curHeroData.planList do
                table.insert(oldPlanList, curHeroData.planList[i])
            end
            table.insert(oldPlanList, {planId = planDid, position = position - 4})--< 后端的第三个参数confPlanId不用
            curHeroData.planList = oldPlanList
            -- plan+英雄id
            CombatPlanManager.UpPlanData(curHeroData.dynamicId, planDid)
        end
    elseif _type == 2 then
        if _equipOrTreasure == 1 then
            --装备解绑英雄
            curSelectEquipData = _selectEquipDataList[1]
            EquipManager.DeleteSingleEquip(curSelectEquipData.id, curHeroData.dynamicId)
            for i = 1, #curHeroData.equipIdList do
                if tonumber(curHeroData.equipIdList[i]) == tonumber(curSelectEquipData.id) then
                    --英雄删除装备
                    table.remove(curHeroData.equipIdList, i)
                    break
                end
            end
            HeroManager.SetHeroEquipIdList(curHeroData.dynamicId, curHeroData.equipIdList)
        elseif _equipOrTreasure == 2 then
            curEquipTreasureDatas = _selectEquipDataList[1]
            EquipTreasureManager.SetEquipTreasureUpHeroDid(curEquipTreasureDatas.idDyn, "")
            for i = 1, #curHeroData.jewels do
                if curHeroData.jewels[i] == curEquipTreasureDatas.idDyn then
                    --英雄删除装备
                    table.remove(curHeroData.jewels, i)
                    break
                end
            end
        elseif _equipOrTreasure == 3 then
            local planDid = _selectEquipDataList
            for i = 1, #curHeroData.planList do
                if curHeroData.planList[i].planId == planDid then
                    table.remove(curHeroData.planList, i)
                    break
                end
            end
            CombatPlanManager.DownPlanData(curHeroData.dynamicId, planDid)
        end
    elseif _type == 3 then
        this.SetActive(effectList[position],false)
        this.SetActive(effectList[position],true)
        if _equipOrTreasure == 1 then
            curSelectEquipData = _selectEquipDataList[1]
            EquipManager.SetEquipUpHeroDid(curSelectEquipData.id, curHeroData.dynamicId)
            --穿
            if _oldSelectEquip and tonumber(_oldSelectEquip.id) ~= tonumber(curSelectEquipData.id) then
                EquipManager.DeleteSingleEquip(_oldSelectEquip.id, curHeroData.dynamicId)
            end
            --英雄替换新选择装备
            if curHeroEquipDatas[position] then
                for i = 1, #curHeroData.equipIdList do
                    if
                        tonumber(curHeroData.equipIdList[i]) ==
                            tonumber(curHeroEquipDatas[position].id)
                     then
                        curHeroData.equipIdList[i] = curSelectEquipData.id
                        break
                    end
                end
            end
            HeroManager.SetHeroEquipIdList(curHeroData.dynamicId, curHeroData.equipIdList)
        elseif _equipOrTreasure == 2 then
            curEquipTreasureDatas = _selectEquipDataList[1]
            --新装备绑英雄
            EquipTreasureManager.SetEquipTreasureUpHeroDid(curEquipTreasureDatas.idDyn, curHeroData.dynamicId)
            if _oldSelectEquip then
                --被替换装备解绑英雄
                EquipTreasureManager.SetEquipTreasureUpHeroDid(_oldSelectEquip.idDyn, "")
            end
            --英雄替换新选择装备
            for i = 1, #curHeroData.jewels do
                if curHeroData.jewels[i] == _oldSelectEquip.idDyn then
                    curHeroData.jewels[i] = curEquipTreasureDatas.idDyn
                end
            end
        elseif _equipOrTreasure == 3 then
            local newPlanDid = _selectEquipDataList
            local oldPlanDid = _oldSelectEquip
            CombatPlanManager.UpPlanData(curHeroData.dynamicId, newPlanDid)
            CombatPlanManager.DownPlanData(curHeroData.dynamicId, oldPlanDid)

            for i = 1, #curHeroData.planList do
                if curHeroData.planList[i].planId == oldPlanDid then
                    curHeroData.planList[i].planId = newPlanDid
                    break
                end
            end
        end
    elseif _type == 4 then
        --一键穿  把身上装备解绑英雄id
        if _equipOrTreasure == 1 then
            --宝物
            for n, m in ipairs(_selectEquipDataList) do
                local isadd = true
                for i = 1, #curHeroData.equipIdList do
                    if equipConfig[tonumber(curHeroData.equipIdList[i])].Position == equipConfig[tonumber(m)].Position then
                        EquipManager.DeleteSingleEquip(curHeroData.equipIdList[i], curHeroData.dynamicId)
                        curHeroData.equipIdList[i] = m
                        HeroManager.GetHeroEquipIdList1(curHeroData.dynamicId, m)
                        isadd = false
                        break
                    end
                end
                if isadd then
                    table.insert(curHeroData.equipIdList, m)
                end
            end
            EquipManager.UpdateEquipData(_selectEquipDataList, curHeroData.dynamicId)
        elseif _equipOrTreasure == 4 then
            for k, v in ipairs(curHeroData.jewels) do
                EquipTreasureManager.SetTreasureUpOrDown(v, "0")
            end
            curHeroData.jewels = {}
            for i = 1, #_selectEquipDataList do
                --把选择的装备绑上英雄
                EquipTreasureManager.SetTreasureUpOrDown(_selectEquipDataList[i], curHeroData.dynamicId)
                --穿
                --再把英雄装备list 清空并添加上新选择的装备
                table.insert(curHeroData.jewels, _selectEquipDataList[i])
            end
        end
    elseif _type == 5 then
        --一键脱  把身上装备英雄id置为“0”   再把英雄装备list清空
        if _equipOrTreasure == 1 then
            if _selectEquipDataList then
                for i = 1, #_selectEquipDataList do
                    EquipManager.DeleteSingleEquip(_selectEquipDataList[i], curHeroData.dynamicId)
                end
            end
            curHeroData.equipIdList = {}
            HeroManager.SetHeroEquipIdList(curHeroData.dynamicId, {})
            curHeroData.equipIdList = {}
        elseif _equipOrTreasure == 5 then
            if _selectEquipDataList then
                for i = 1, #_selectEquipDataList do
                    EquipTreasureManager.SetTreasureUpOrDown(_selectEquipDataList[i], "")
                end
                curHeroData.jewels = {}
            end
        end
    end
    --刷新部件数据
    HeroManager.UpdateHeroPartsData(curHeroData)
    -- 刷新界面
    -- this.ShowHeroEquip()
    --更新界面
    this:UpdatePanelData()
    --对比战力并更新战力值 播放战力变更动画
    HeroManager.CompareWarPower(curHeroData.dynamicId)

    Game.GlobalEvent:DispatchEvent(GameEvent.Parts.FreshEquip)
end

--检测装备是否有提升
function this:CheckEquipHaveWear()
    -- local allEquipIds = {}

    --计算英雄身上的所有装备位的装备
    local curHeroEquipDatas = {}
    for k, v in ipairs(curHeroData.equipIdList) do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(v, curHeroData.dynamicId)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        else

        end
    end
    -- local isHaveSlot = false
    local isCanWear = false
    local isNull = false
    if this:IsEquipUp() then
        return true
    end
    for i = 1, 6 do
        if curHeroEquipDatas[i] == nil then--槽位为空或者有更好装备时
            local curPosEquip = BagManager.GetEquipDataByEquipPosition(curHeroData.heroConfig.Profession, i)
            if curPosEquip and #curPosEquip > 0 then
                isCanWear = true
                return true
            end
        else
            isNull = true
        end
    end
----------------------------------------------戒指红点start------------------
    --红点显示的条件
    --  1.解锁了但是没有装备
    --  2.有更好的戒指
    --首先看玩家有没有解锁戒指，然后判断当前装备的戒指有没有更好的替代品
    --如果没解锁红点显示，有更好的替代品也显示红点

    --查看两个戒指的解锁状态
    -- local rings1IsUnlock=false
    -- local rings2IsUnlock=false
    -- for i=1,2 do
    --     local s_type = 0
    --     local s_value = 0
    --     local specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "CombatPlanUnlock")
    --     local valueArray = string.split(specialConfig.Value, "|")
    --     local a = string.split(valueArray[i], "#")
    --     s_type = a[2]
    --     s_value = a[3]
    --     if tonumber(s_type) == 1 then
    --         rings1IsUnlock= curHeroData.lv >= tonumber(s_value)
    --     elseif tonumber(s_type) == 2 then
    --         rings2IsUnlock=curHeroData.star >= tonumber(s_value)
    --     end
    -- end

    
    
    -- --初始化获得背包所有的戒指,索引从5开始，因为装备是1234，方便区别
    -- curRingsData = {}
    -- for i = 1, #curHeroData.planList do
    --     local sData = curHeroData.planList[i]
    --     local bData = CombatPlanManager.GetPlanData(sData.planId)
    --     curRingsData[sData.position+4] = {sData = sData, bData = bData}
    -- end

    -- --获取所有的没装备的戒指并且比较有没有更好的
    -- local hasBetterRings=fasle
    -- local allRingsData = CombatPlanManager.GetPlanByType(2)
    -- for i = 1, #allRingsData do
    --     local oneRingsData = CombatPlanManager.CalPlanPowerByProperty(allRingsData[i].property)
    --     if curRingsData[5] == nil or curRingsData[6] == nil then
    --         hasBetterRings = true
    --     else
    --         if
    --             oneRingsData > CombatPlanManager.CalPlanPowerByProperty(curRingsData[5].bData.property) or
    --                 oneRingsData > CombatPlanManager.CalPlanPowerByProperty(curRingsData[6].bData.property)
    --         then
    --             hasBetterRings = true
    --         end
    --     end

    --     --背包全部装备的评价
    --     Log('全部未装备戒指的评价：' .. CombatPlanManager.CalPlanPowerByProperty(allRingsData[i].property))
    -- end

    
    -- --获取当前穿戴戒指的评分
    -- if curRingsData[5] ~= nil then
    --    Log("1号戒指的评价是：".. CombatPlanManager.CalPlanPowerByProperty(curRingsData[5].bData.property))
    -- end
    -- if curRingsData[6] ~= nil then
    --    Log("2号戒指的评价是：".. CombatPlanManager.CalPlanPowerByProperty(curRingsData[6].bData.property))
    -- end

    -- if not rings1IsUnlock and not rings1IsUnlock then
    --     Log("戒指没解锁")
    -- else
    --     if rings1IsUnlock and rings2IsUnlock and (curRingsData[5]==nil or curRingsData[6]==nil) and #curHeroData.planList>0 then
    --         Log("戒指都解锁了，背包有戒指，但是没装备任何戒指")
    --     elseif hasBetterRings then
    --         Log("有更好的戒指")
    --     end
    -- end
    -- HeroManager.GetRingsIsShowRedPoin(curHeroData)

    -------------------------------------------------戒指红点end---
    
    return false,isCanWear,isNull
end

--装备是否有提升
function this:IsEquipUp()
    --计算英雄身上的所有装备位的装备
    local curHeroEquipDatas = {}
    for k, v in ipairs(curHeroData.equipIdList) do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(v, curHeroData.dynamicId)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        else

        end
    end

    for i = 1, 4 do
        local curPosEquip = {}
        local index = i
        curPosEquip = BagManager.GetEquipDataByEquipPosition(curHeroData.heroConfig.Profession, index)

        --计算每个位置可装备的装备战力 取战力最大的装备
        if curPosEquip and #curPosEquip > 0 then
            local equiData = {}
            local indexMaxPower = 0
            if curHeroEquipDatas[index] then
                equiData = curHeroEquipDatas[index]
                indexMaxPower = EquipManager.CalculateWarForce(curHeroEquipDatas[index].id)
            end
            for i = 1, #curPosEquip do
                local addPower = 0
                local curEquip = curPosEquip[i]
                if curEquip then
                    addPower = EquipManager.CalculateWarForce(curEquip.id)
                end
                if addPower > indexMaxPower then
                   return true
                end
            end
        end
    end
    return false
end

--刷新装备红点
function this:RefreshEquipRedPoint()
    local curHeroEquipDatas = {}
    for k, v in ipairs(curHeroData.equipIdList) do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(v, curHeroData.dynamicId)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        end
    end
    for i = 1, 4 do
        this.SetActive(this.equipRedPoint[i],false)
        local curPosEquip = BagManager.GetEquipDataByEquipPosition(curHeroData.heroConfig.Profession, i)
        if curHeroEquipDatas[i] == nil then
            if curPosEquip and #curPosEquip > 0 then
                this.SetActive(this.equipRedPoint[i],true)
            end
        else
            if curPosEquip and #curPosEquip > 0 then
                local addPower = 0
                local curPower = 0
                if curHeroEquipDatas[i] then
                    curPower = EquipManager.CalculateWarForce(curHeroEquipDatas[i].id)
                end
                for j = 1, #curPosEquip do
                    local curEquip = curPosEquip[j]
                    if curEquip then
                        addPower = EquipManager.CalculateWarForce(curEquip.id)
                    end
                    if addPower > curPower then
                        this.SetActive(this.equipRedPoint[i],true)
                    end
                end
            end
        end
    end

    --戒指
    -- local isOpen1, txt1 = this:checkUnlockCombatPlan(1)
    -- local isOpen2, txt2 = this:checkUnlockCombatPlan(2)
    -- local data = CombatPlanManager.GetPlanByType(2)
    -- this.SetActive(Util.GetGameObject(this.planGo1, "redPoint"),false)
    -- this.SetActive(Util.GetGameObject(this.planGo2, "redPoint"),false)
    -- if #data > 0 then
    --     if isOpen1 then
    --         if Util.GetGameObject(this.planGo1, "mask").activeSelf then
    --             this.SetActive(Util.GetGameObject(this.planGo1, "redPoint"),true)
    --             --装备按钮的红点
    --            -- this.SetActive(this.btnEquipRedPoint,HeroManager.GetFormationHeroRedPoint)
    --         end
    --     end
    --     if isOpen2 then
    --         if Util.GetGameObject(this.planGo2, "mask").activeSelf then
    --             this.SetActive(Util.GetGameObject(this.planGo2, "redPoint"),true)
    --             -- 装备按钮的红点
    --             --this.SetActive(this.btnEquipRedPoint,true)
    --             --this.SetActive(this.btnEquipRedPoint,HeroManager.GetFormationHeroRedPoint)
    --         end
    --     end
    -- end

    local hasBetterRings,betterRingsState=HeroManager.GetRingsIsShowRedPoin(curHeroData)
    if betterRingsState ~=nil and betterRingsState~=nil then
        this.SetActive(Util.GetGameObject(this.planGo1, "redPoint"),betterRingsState["Rings1"])
        this.SetActive(Util.GetGameObject(this.planGo2, "redPoint"),betterRingsState["Rings2"])
    else
        this.SetActive(Util.GetGameObject(this.planGo1, "redPoint"),false)
        this.SetActive(Util.GetGameObject(this.planGo2, "redPoint"),false)
    end

end

--一键装备
function this:AllEquipUp()
    local allEquipIds = {}

    --计算英雄身上的所有装备位的装备
    local curHeroEquipDatas = {}
    for k, v in ipairs(curHeroData.equipIdList) do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(v, curHeroData.dynamicId)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        else

        end
    end

    local equipEffectPos = {}
    for i = 1, 4 do
        local curPosEquip = {}
        local index = i

        curPosEquip = BagManager.GetEquipDataByEquipPosition(curHeroData.heroConfig.Profession, index)

        --计算每个位置可装备的装备战力 取战力最大的装备
        if curPosEquip and #curPosEquip > 0 then
            local equiData = {}
            local indexMaxPower = 0
            if curHeroEquipDatas[index] then
                equiData = curHeroEquipDatas[index]
                indexMaxPower = EquipManager.CalculateWarForce(curHeroEquipDatas[index].id)
            end
            for i = 1, #curPosEquip do
                local addPower = 0
                local curEquip = curPosEquip[i]
                if curEquip then
                    addPower = EquipManager.CalculateWarForce(curEquip.id)
                end
                if addPower >= indexMaxPower then
                    indexMaxPower = addPower
                    equiData = curEquip
                end
            end

            if not curHeroEquipDatas[index] or tonumber(equiData.id) ~= tonumber(curHeroEquipDatas[index].id) then
                table.insert(allEquipIds, tostring(equiData.id))
            end
            --特效
            if curHeroEquipDatas[equiData.position] then
                if equiData.id ~= curHeroEquipDatas[equiData.position].id then
                    table.insert(equipEffectPos, i)
                end
            else
                --table.insert(showEffectPos,i)
            end
        end
    end

    if allEquipIds and #allEquipIds > 0 then
        --穿装备协议
        NetManager.EquipWearRequest(
            curHeroData.dynamicId,
            allEquipIds,
            1,
            function()
                this.UpdateEquipPosHeroData(1, 4, allEquipIds)
                --特效播放
                if equipEffectPos then
                    for i = 1, #equipEffectPos do
                        this.SetActive(effectList[equipEffectPos[i]],false)
                        this.SetActive(effectList[equipEffectPos[i]],true)
                    end
                end
            end
        )

    else
        if not allEquipIds or #allEquipIds < 1  then
            PopupTipPanel.ShowTipByLanguageId(11826)
        else
            PopupTipPanel.ShowTipByLanguageId(11827)
        end
    end
    PlaySoundWithoutClick(SoundConfig.Sound_Wear)
    this.ShowHeroEquip()
end

--一键卸载
function this:AllEquipDown()
    if curHeroData.equipIdList and #curHeroData.equipIdList > 0 then
        if curHeroData.equipIdList and #curHeroData.equipIdList > 0 then
            NetManager.EquipUnLoadOptRequest(
                curHeroData.dynamicId,
                curHeroData.equipIdList,
                1,
                function()
                    this.UpdateEquipPosHeroData(1, 5, curHeroData.equipIdList)
                end
            )
        end
    else
        PopupTipPanel.ShowTipByLanguageId(11828)
    end
    PlaySoundWithoutClick(SoundConfig.Sound_TakeOff)
    this.ShowHeroEquip()
end

--芯片信息
function this.UpdateHeroMedalData()
    local WearmedalListWear = MedalManager.MedalDaraByHero(curHeroData.dynamicId)

    local suitRes = {}
    suitRes = MedalManager.SuitHeroSuitActive(WearmedalListWear)
    HeroManager.SetHeroSuitAtive(curHeroData.dynamicId,suitRes)
    local suitActiveList = HeroManager.GetHeroSuitActive(curHeroData.dynamicId)

    --套装激活文字显示
    this.SetActive(this.noSuit,false)
    this.SetActive(this.suit1,true)
    this.SetActive(this.suit2,true)
    if LengthOfTable(suitActiveList) > 0 then
        for i = 1,LengthOfTable(suitActiveList)do
            local data = suitActiveList[i]
            local suit = Util.GetGameObject(this.roleChipLayout,"suit"..i)
            Util.SetGray(suit,false)
            RoleInfoPanel.ShowSuitActive(suit,data,true)
        end

        if LengthOfTable(suitActiveList) == 1 then
            Util.SetGray(this.suit2,true)
            RoleInfoPanel.ShowSuitActive(this.suit2,{num = 4,suitId = suitActiveList[1].suitId},false)
        end
    else
        --身上有无芯片
        if LengthOfTable(WearmedalListWear) >= 1 then
            local data = {}
            for k,v in pairs(WearmedalListWear) do
                while true do
                    if v ~= nil then
                        data = v
                        break
                    end
                    break
                end
            end
            --显示最小芯片
            for i = 1,2 do
                local suit = Util.GetGameObject(this.roleChipLayout,"suit"..i)
                local num = {2,4}
                Util.SetGray(suit,true)
                RoleInfoPanel.ShowSuitActive(suit,{num = num[i],suitId = data.suitId},false)
            end
        else
            this.SetActive(this.noSuit,true)
            this.SetActive(this.suit1,false)
            this.SetActive(this.suit2,false)
        end
    end
    --芯片展示
    for i = 1, 4 do
        local chipItem = this.chipList[i]
        local chipBtn = Util.GetGameObject(chipItem,"chipBtn")
        local noChip = Util.GetGameObject(chipItem,"noChip")
        local frame = Util.GetGameObject(chipItem,"haveChip")
        local icon = Util.GetGameObject(chipItem,"haveChip/chip")
        -- local text = Util.GetGameObject(chipItem,"name")
        local star = Util.GetGameObject(chipItem,"star")

        if WearmedalListWear[i] then
            this.SetActive(noChip,false)
            this.SetActive(frame,true)
            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(WearmedalListWear[i].medalConfig.Quality))
            icon:GetComponent("Image").sprite = Util.LoadSprite(WearmedalListWear[i].icon)
            SetHeroStars(star,WearmedalListWear[i].medalConfig.Star)
        else
            this.SetActive(noChip,true)
            this.SetActive(frame,false)
        end
        Util.AddOnceClick(chipBtn, function()
            if WearmedalListWear[i] then
                UIManager.OpenPanel(UIName.MedalParticularsPopup,WearmedalListWear[i],i,true,curHeroData.dynamicId,true,true)--data勋章 槽位ID  是否穿戴在英雄身上 英雄id
            else
                UIManager.OpenPanel(UIName.MedalChangelPopup,i,curHeroData.dynamicId)--槽位id  英雄ID
            end
        end)
    end

    this:RefreshChipRedPoint()
end

--刷新芯片红点
function this:RefreshChipRedPoint()
    for i = 1, 4 do
        this.SetActive(this.chipRedpointList[i],false)
        local shipList = MedalManager.MedalDaraBySite(i,curHeroData.dynamicId)
        if #shipList > 0 then
            if Util.GetGameObject(this.chipList[i],"noChip").activeSelf then
                this.SetActive(this.chipRedpointList[i],true)
            end
        end
    end
end

function this.ShowSuitActive(suit,data,isActive)
    local activation = Util.GetGameObject(suit,"activation/Image")
    local name = Util.GetGameObject(suit,"suitName")
    local num = Util.GetGameObject(suit,"suitName/suitNum")
    local star = Util.GetGameObject(suit,"suitLv/lv")
    local icon = Util.GetGameObject(suit,"pro/icon")
    local proName = Util.GetGameObject(suit,"pro/pro")
    local value = Util.GetGameObject(suit,"pro/num")

    local medalSuitData = MedalManager.GetMedalSuitInfoById(data.suitId)
    local suitTypedata = MedalManager.GetMedalSuitInfoByType(medalSuitData.Type)
    this.SetActive(activation,isActive)
    Util.SetGray(activation,not isActive)
    name:GetComponent("Text").text = GetLanguageStrById(suitTypedata.Name)
    num:GetComponent("Text").text = string.format("(%s/4)",data.num)
    star:GetComponent("Text").text = string.format(GetLanguageStrById(23121), medalSuitData.Star)
    for k,v in pairs(medalSuitData.SuitAttr)do
        if v[1] == data.num then
            if v[2] == 8888 then
                local PassiveSkillConfigData = ConfigManager.GetConfigDataByKey(ConfigName.PassiveSkillConfig, "Id", v[3])
                icon.transform.localScale = Vector3.one * 0.7
                -- icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(PassiveSkillConfigData.Icon))
                proName:GetComponent("Text").text = string.format(GetLanguageStrById(23148), GetLanguageStrById(PassiveSkillConfigData.Name))
                value:GetComponent("Text").text = ""
            else
                icon.transform.localScale = Vector3.one
                local PropertyConfigData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", v[2])

                -- icon:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfigData.Icon)
                proName:GetComponent("Text").text = GetLanguageStrById(PropertyConfigData.Info)
                value:GetComponent("Text").text = "+" .. GetPropertyFormatStr(PropertyConfigData.Style,v[3])

            end
        end
    end
end

--检测英雄重铸是否开启
function this:checkUnlockEquipCastGod()
    local specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "AdjustUnlockStar")
    if curHeroData.star >= tonumber(specialConfig.Value) then 
       return true
    end
    return false
end


--检测戒指是否开启
function this:checkUnlockCombatPlan(slot)
    local s_type = 0
    local s_value = 0
    local specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "CombatPlanUnlock")
    local valueArray = string.split(specialConfig.Value, "|")
    local a = string.split(valueArray[slot], "#")
    s_type = a[2]
    s_value = a[3]
    if tonumber(s_type) == 1 then
        return curHeroData.lv >= tonumber(s_value), s_value .. GetLanguageStrById(10062)
    elseif tonumber(s_type) == 2 then
        return curHeroData.star >= tonumber(s_value), s_value .. GetLanguageStrById(10488)
    end
    return false, ""
end

------------------------------------------------------页签----------------------------------------------------------
--隐藏layout下所有节点
function this.HideAllLayout()
    local layoutCount = this.layout.transform.childCount
    for i = 0, layoutCount - 1 do
        this.SetActive(this.layout.transform:GetChild(i).gameObject,false)
    end
end

--页签选中效果设置
function this:SetSelectBtn(_btn,btnHorizontal)
    local btnListCount = self.btnList.transform.childCount
    for i = 0, btnListCount - 1 do
        Util.GetGameObject(this.btnList.transform:GetChild(i),"bg"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_fenlan_weixuanzhong_02")    
        this.SetActive(Util.GetGameObject(this.btnList.transform:GetChild(i),"title"),false)
        this.SetActive(Util.GetGameObject(this.btnList.transform:GetChild(i),"name"),false)
        this.SetActive(Util.GetGameObject(this.btnList.transform:GetChild(i),"name2"),true)
    end
    Util.GetGameObject(_btn,"bg"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_fenlan_yixuanzhong_02")
    this.SetActive(Util.GetGameObject(_btn,"title"),true)
    this.SetActive(Util.GetGameObject(_btn,"name"),true)
    this.SetActive(Util.GetGameObject(_btn,"name2"),false)

    if this.isFirstOpen then
        this.isFirstOpen = false
    else
        this.leftBtn.transform.position = Util.GetGameObject(btnHorizontal,"leftBtnPos").transform.position
        this.rightBtn.transform.position = Util.GetGameObject(btnHorizontal,"rightBtnPos").transform.position
    end
end

function this:SelectBtn(_btn)
    local selectBtnPos = Vector3.New(6,6.3,0)
    this.btnSelect.transform:SetParent(Util.GetGameObject(_btn,"target").transform)
    this.btnSelect.transform.localPosition = selectBtnPos
    Util.GetGameObject(this.btnSelect,"Text"):GetComponent("Text").text = 
    Util.GetGameObject(_btn,"Text"):GetComponent("Text").text
end

--属性
function this:OnClickBtnInfo()
    this.HideAllLayout()
    this.SetActive(this.roleInfoLayout,true)
    this.SetActive(this.CommentBtn,true)
    this.SetActive(this.LockingBtn,true)
    this.SetActive(this.ResetBtn,false)
    this:SetSelectBtn(this.btnInfo,this.roleInfoLayout)
    this.MoveLive(-150)
    liveDeviation = -1
end
--装备
function this:OnClickBtnEquip()
    this.HideAllLayout()
    this.SetActive(this.roleEquipLayout,true)
    this.SetActive(this.CommentBtn,false)
    this.SetActive(this.LockingBtn,false)
    this.SetActive(this.ResetBtn,false)
    this:SetSelectBtn(this.btnEquip,this.roleInfoLayout)
    this.MoveLive(0)
    liveDeviation = 0
end
--培养
function this:OnClickBtnCulture()
    this.HideAllLayout()
    this.SetActive(this.roleUpStarLayout,true)
    this.SetActive(this.btnCultureBtnList,true)
    this:SetSelectBtn(this.btnCulture,this.btnCulture)
    this.SetActive(this.CommentBtn,false)
    this.SetActive(this.LockingBtn,false)
    this.SetActive(this.ResetBtn,false)
    this.MoveLive(150)
    liveDeviation = 1
end
--升星
function this:OnClickBtnUpStar()
    this.HideAllLayout()
    this.SetActive(this.btnCultureBtnList,true)
    this.SetActive(this.roleUpStarLayout,true)
    this:SelectBtn(this.btnUpStar)
    this.SetActive(this.CommentBtn,false)
    this.SetActive(this.LockingBtn,false)
    this.SetActive(this.ResetBtn,false)
    this.MoveLive(150)
    liveDeviation = 1
end
--能力
function this:OnClickBtnAbility()
    this.HideAllLayout()
    this.SetActive(this.btnCultureBtnList,true)
    this.SetActive(this.roleAbilityLayout,true)
        this.SetActive(this.CommentBtn,false)
    this.SetActive(this.LockingBtn,false)
    this.SetActive(this.ResetBtn,false)
    this:SelectBtn(this.btnAbility)
    self:AbilityUpdateUI()
    this.MoveLive(150)
    liveDeviation = 1
end
--芯片SetSelectBtn
function this:OnClickBtnChip()
    this.HideAllLayout()
    this.SetActive(this.btnCultureBtnList,true)
    this.SetActive(this.roleChipLayout,true)
    this.SetActive(this.CommentBtn,false)
    this.SetActive(this.LockingBtn,false)
    this.SetActive(this.ResetBtn,false)
    this:SelectBtn(this.btnChip)
    this.MoveLive(150)
    liveDeviation = 1
end
--超频
function this:OnClickBtnOverclock()
    this.HideAllLayout()
    this.SetActive(this.btnCultureBtnList,true)
    this:SelectBtn(this.btnOverclock)
    this.SetActive(this.CommentBtn,false)
    this.SetActive(this.LockingBtn,false)
    this.SetActive(this.ResetBtn,false)
    this.MoveLive(150)
    liveDeviation = 1
end
--旗阵
function this:OnClickBtnFlagArr()
    this.HideAllLayout()
    this.SetActive(this.btnCultureBtnList,true)
    this.SetActive(this.CommentBtn,false)
    this.SetActive(this.LockingBtn,false)
    this.SetActive(this.ResetBtn,false)
    this:SelectBtn(this.btnFlagArr)
    this.MoveLive(150)
    liveDeviation = 1
end




--能力界面更新
function this:AbilityUpdateUI()
    local limit = {
        ["limitStarLv1"] = 6,
        ["limitStarLv2"] = 11
    }

    local abilityPointStateRes={
        ["ability1"]=false,
        ["ability2"]=false
    }

    abilityPointStateRes=HeroManager.GetCurHeroAbilityIsShowRedPoint(curHeroData)
    for i = 1, 2 do
        local item = Util.GetGameObject(this.abilityItemGrid, string.format("Item%d", i))
        local frame = Util.GetGameObject(item, "frame")
        local btn = frame:GetComponent("Button")
        local icon = Util.GetGameObject(item, "icon")
        local add = Util.GetGameObject(item, "add")
        local lock = Util.GetGameObject(item, "lock")
        local name = Util.GetGameObject(item, "name"):GetComponent("Text")
        local redPoint = Util.GetGameObject(item, "redPoint")

        if curHeroData.star >= limit["limitStarLv" .. tostring(i)] then -- isOpen
            local isOn = false
            local warWaySlotId = curHeroData[string.format("warWaySlot%dId", i)]
            
            if warWaySlotId and warWaySlotId ~= 0 then
                isOn = true
            end
            if isOn then
                --如果检测到已经学习了能力那么就关闭红点
                this.SetActive(add,false)
                --this.SetActive(redPoint,false)
                this.SetActive(redPoint,abilityPointStateRes["ability".. tostring(i)])
                name.text = ""
                this.SetActive(icon,true)
                Util.AddOnceClick(frame, function()
                    UIManager.OpenPanel(UIName.WarWayLevelUpPopup, curHeroData, i, warWaySlotId)
                end)
                local warWayConfig = WarWaySkillConfig[warWaySlotId]
                icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(warWayConfig.Image))
                frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(warWayConfig.Level))
                local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
                name.text = GetLanguageStrById(PassiveSkillConfig[warWayConfig.SkillId].Name)
            else
                name.text = ""
                --解锁了能力但是没有学习能力，加号和红点都显示
                --this.SetActive(redPoint,HeroManager.GetCurHeroAbilityIsShowRedPoint(curHeroData))
                abilityPointStateRes["ability".. tostring(i)]=HeroManager.IsCompetencySkills()
                
                this.SetActive(add,true)
                this.SetActive(icon,false)
                Util.AddOnceClick(frame, function()
                    UIManager.OpenPanel(UIName.WarWayComprehendPopup, curHeroData, i)
                end)
                frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(0))
            end
            this.SetActive(lock,false)
            btn.enabled = true
        else
            --角色星级不够，开启锁图标，关闭红点和加号还有锁图标
            this.SetActive(lock,true)
            this.SetActive(add,false)
            this.SetActive(icon,false)
            -- btn.enabled = false
            
            if  i == 1 then
                Util.AddOnceClick(frame, function()
                    PopupTipPanel.ShowTipByLanguageId(22613)
                end)
                name.text = GetLanguageStrById(22613)
            else
                Util.AddOnceClick(frame, function()
                    PopupTipPanel.ShowTipByLanguageId(22614)
                end)
                name.text = GetLanguageStrById(22614)
            end
            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(0))
        end
        this.SetActive(redPoint,abilityPointStateRes["ability".. tostring(i)])
    end

    local isRedpoint=abilityPointStateRes["ability".. tostring(1)] or abilityPointStateRes["ability".. tostring(2)]
    this.SetActive(this.btnAbilityRedPoint,isRedpoint)
end

--拖拽立绘
local beginV3
local endV3
local distance
function this:OnBeginDrag(Pointgo, data)
    beginV3 = this.curLiveObj.transform.anchoredPosition
end
function this:OnDrag(Pointgo, data)
    distance = Vector2.Distance(beginV3,this.curLiveObj.transform.anchoredPosition)
end
function this:OnEndDrag(Pointgo, data)
    endV3 = this.curLiveObj.transform.anchoredPosition
    if distance > 250 and endV3.x < 0 then
        this:RightBtnOnClick()
        this.ShowHeroEquip()
    elseif distance > 250 and endV3.x > 0 then
        this:LeftBtnOnClick()
        this.ShowHeroEquip()
    else
        local tweenEndVer = Vector2.New(curHeroData.position[1],curHeroData.position[2])
        this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.5, false):SetEase(Ease.Linear)
    end
    distance = 0
end

function this.MoveLive(pos)
    local tweenEndVer = Vector2.New(curHeroData.heroConfig.Position[1] + pos,curHeroData.heroConfig.Position[2])
    this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.3, false):SetEase(Ease.Linear)
end

--右切换按钮点击
function this:RightBtnOnClick()
    if isClickLeftOrRightBtn == false then
        return
    end
    isClickLeftOrRightBtn = false
    this.rightBtn:GetComponent("Button").enabled = false
    local oldIndexConfigData = heroDatas[index]
    index = (index + 1 <= #heroDatas and index + 1 or 1)
    curHeroData = heroDatas[index]

    if this.leftLiveObj then
        UnLoadHerolive(leftHeroData.heroConfig,this.leftLiveObj)
        Util.ClearChild(this.leftObj.transform)
        this.leftLiveObj = nil
    end
    this.curLiveObj.transform:SetParent(self.leftObj.transform)

    local tweenEndVer = Vector2.New(oldIndexConfigData.position[1],oldIndexConfigData.position[2])
    this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.5, false):SetEase(Ease.Linear)
    this.rightLiveObj.transform:SetParent(this.curObj.transform)

    --立绘偏移动画
    local tweenEndRightVer
    if liveDeviation == 1 then
        tweenEndRightVer = Vector2.New(rightHeroData.position[1] + 150,rightHeroData.position[2])
    elseif liveDeviation == -1 then
        tweenEndRightVer = Vector2.New(rightHeroData.position[1] - 150,rightHeroData.position[2])
    else
        tweenEndRightVer = Vector2.New(rightHeroData.position[1],rightHeroData.position[2])
    end
    this.rightLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndRightVer, 0.4, false):OnComplete(function ()
        this:UpdateLiveList()
        this.leftLiveObj = this.curLiveObj
        this.curLiveObj = this.rightLiveObj
        this.rightLiveObj = LoadHerolive(rightHeroData.heroConfig,self.rightObj)
        this:UpdatePanelData()
        this:UpdateHeroUpStarProUpShow()
        this.rightBtn:GetComponent("Button").enabled = true
        isClickLeftOrRightBtn = true
    end):SetEase(Ease.Linear)
    PlaySoundWithoutClick(SoundConfig.Sound_Switch)
end

--左切换按钮点击
function this:LeftBtnOnClick()
    if isClickLeftOrRightBtn == false then
        return
    end
    isClickLeftOrRightBtn = false
    this.leftBtn:GetComponent("Button").enabled = false
    local oldIndexConfigData = heroDatas[index]
    index = (index - 1 > 0 and index - 1 or #heroDatas)
    curHeroData = heroDatas[index]
    if this.rightLiveObj then
        UnLoadHerolive(rightHeroData.heroConfig,this.rightLiveObj)
        Util.ClearChild(this.rightObj.transform)
        this.rightLiveObj = nil
    end
    this.curLiveObj.transform:SetParent(this.rightObj.transform)
    local tweenEndVer = Vector2.New(oldIndexConfigData.position[1],oldIndexConfigData.position[2]) 
    this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndVer, 0.5, false):SetEase(Ease.Linear)
    this.leftLiveObj.transform:SetParent(this.curObj.transform)
    
    --立绘偏移动画
    local tweenEndLeftVer
    if liveDeviation == 1 then
        tweenEndLeftVer = Vector2.New(leftHeroData.position[1] + 150,leftHeroData.position[2])
    elseif liveDeviation == -1 then
        tweenEndLeftVer = Vector2.New(leftHeroData.position[1] - 150,leftHeroData.position[2])
    else
        tweenEndLeftVer = Vector2.New(leftHeroData.position[1],leftHeroData.position[2])
    end
    this.leftLiveObj:GetComponent("RectTransform"):DOAnchorPos(tweenEndLeftVer, 0.4, false):OnComplete(function ()
        this:UpdateLiveList()
        this.rightLiveObj = this.curLiveObj
        this.curLiveObj = this.leftLiveObj
        this.leftLiveObj = LoadHerolive(leftHeroData.heroConfig,self.leftObj)
        this:UpdatePanelData()
        this:UpdateHeroUpStarProUpShow()
        this.leftBtn:GetComponent("Button").enabled = true
        isClickLeftOrRightBtn = true
    end):SetEase(Ease.Linear)
     PlaySoundWithoutClick(SoundConfig.Sound_Switch)
end

--设置显隐
function this.SetActive(go, value)
    if value and not go.activeSelf then
        go:SetActive(value)
    elseif not value and go.activeSelf then
        go:SetActive(value)
    end
end

-- --点击时检测功能
-- function this.FunctionClickEvent(funcId, callback)
--     if not funcId or funcId == 0 or not callback then return end

--     local isOpen = ActTimeCtrlManager.SingleFuncState(funcId)
--     if isOpen then
--         if callback then callback() end
--     else
--         PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(funcId))
--     end
-- end

--铸神等级
function this.ShowAddLevel(curPos)
    local AddLevel = 0
    local curData = curHeroData.partsData[curPos]
    if not curData then
        return 0
    end
    if curData.isUnLock > curData.actualLv then
        AddLevel = curData.actualLv
    else
        AddLevel = curData.isUnLock
    end
    if AddLevel < 0 then AddLevel = 0 end
    return AddLevel
end


return RoleInfoPanel