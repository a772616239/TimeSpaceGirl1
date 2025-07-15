----- 通用弹窗 -----
require("Base/BasePanel")
GeneralPopup = Inherit(BasePanel)
local this = GeneralPopup

--子模块脚本
local contentScripts = {
    --回溯
    [1] = {view = require("Modules/Popup/View/GeneralPopup_ResolveRecall"),panelName = "GeneralPopup_ResolveRecall",type = GENERAL_POPUP_TYPE.ResolveRecall},
    --献祭
    [2] = {view = require("Modules/Popup/View/GeneralPopup_ResolveDismantle"),panelName = "GeneralPopup_ResolveDismantle",type = GENERAL_POPUP_TYPE.ResolveDismantle},
    --装备合成
    [3] = {view = require("Modules/Popup/View/GeneralPopup_EquipCompound"),panelName = "GeneralPopup_EquipCompound",type = GENERAL_POPUP_TYPE.EquipCompound},
    --公会技能重置返还
    [4] = {view = require("Modules/Popup/View/GeneralPopup_GuildSkillReset"),panelName = "GeneralPopup_GuildSkillReset",type = GENERAL_POPUP_TYPE.GuildSkill},
    --宝物合成
    [5] = {view = require("Modules/Popup/View/GeneralPopup_TreasureCompound"),panelName = "GeneralPopup_TreasureCompound",type = GENERAL_POPUP_TYPE.TreasureCompound},
    --公会援助发送求助碎片
    [6] = {view = require("Modules/Popup/View/GeneralPopup_GuildAid"),panelName = "GeneralPopup_GuildAid",type = GENERAL_POPUP_TYPE.GuildAid},
    --公会援助查看宝箱奖励
    [7] = {view = require("Modules/Popup/View/GeneralPopup_GuildAidFindBoxReward"),panelName = "GeneralPopup_GuildAidFindBoxReward",type = GENERAL_POPUP_TYPE.GuildAidFindBoxReward},
    --点将台抽卡 奖励弹窗
    [8] = {view = require("Modules/Popup/View/GeneralPopup_RecruitBox"),panelName = "GeneralPopup_RecruitBox",type = GENERAL_POPUP_TYPE.RecruitBox},
    --挂机属性提升
    [9] = {view = require("Modules/Popup/View/GeneralPopup_Onhook"),panelName = "GeneralPopup_Onhook",type = GENERAL_POPUP_TYPE.Onhook},
    --试练设置弹窗
    [10] = {view = require("Modules/Popup/View/GeneralPopup_TrialSetting"),panelName = "GeneralPopup_TrialSetting",type = GENERAL_POPUP_TYPE.TrialSetting},
    --试练回春散
    [11] = {view = require("Modules/Popup/View/GeneralPopup_TrialXingYao"),panelName = "GeneralPopup_TrialXingYao",type = GENERAL_POPUP_TYPE.TrialXingYao},
    --试练增益
    [12] = {view = require("Modules/Popup/View/GeneralPopup_TrialGain"),panelName = "GeneralPopup_TrialGain",type = GENERAL_POPUP_TYPE.TrialGain},
    --大闹天宫  回复 和 复活节点
    [13] = {view = require("Modules/Popup/View/GeneralPopup_ExpeditionReply"),panelName = "GeneralPopup_ExpeditionReply",type = GENERAL_POPUP_TYPE.ExpeditionReply},
    --试炼副本进入下一层
    [14] = {view = require("Modules/Popup/View/GeneralPopup_TrialToNextFloor"),panelName = "GeneralPopup_TrialToNextFloor",type = GENERAL_POPUP_TYPE.TrialToNextFloor},
    --宝物分解
    [15] = {view = require("Modules/Popup/View/GeneralPopup_ResolveEquipTreasure"),panelName = "GeneralPopup_ResolveEquipTreasure",type = GENERAL_POPUP_TYPE.ResolveEquipTreasure},
    --装备批量出售
    [16] = {view = require("Modules/Popup/View/GeneralPopup_EquipBatchSell"),panelName = "GeneralPopup_EquipBatchSell",type = GENERAL_POPUP_TYPE.EquipBatchSell},
    --装备单种出售 拉条
    [17] = {view = require("Modules/Popup/View/GeneralPopup_EquipSingleSell"),panelName = "GeneralPopup_EquipSingleSell",type = GENERAL_POPUP_TYPE.EquipSingleSell},
    --森罗次元炸弹
    [18] = {view = require("Modules/Popup/View/GeneralPopup_TrialBomb"),panelName = "GeneralPopup_TrialBomb",type = GENERAL_POPUP_TYPE.TrialBomb},
    --神将召唤、限时召唤、乾坤宝盒 二次确认界面
    [19] = {view = require("Modules/Popup/View/GeneralPopup_RecruitConfirm"),panelName = "GeneralPopup_RecruitConfirm",type = GENERAL_POPUP_TYPE.RecruitConfirm},
    --碎片回收
    [20] = {view = require("Modules/Popup/View/GeneralPopup_ResolveDebris"),panelName = "GeneralPopup_ResolveDebris",type = GENERAL_POPUP_TYPE.ResolveDebris},
    --战法遗忘
    [21] = {view = require("Modules/Popup/View/GeneralPopup_WarWayForget"),panelName = "GeneralPopup_WarWayForget",type = GENERAL_POPUP_TYPE.WarWayForget},
    --模拟战购买挑战
    [22] = {view = require("Modules/Popup/View/GeneralPopup_ClimbTowerBuy"),panelName = "GeneralPopup_ClimbTowerBuy",type = GENERAL_POPUP_TYPE.ClimbTowerBuy},
    --联盟成员转让提示
    [23] = {view = require("Modules/Popup/View/GeneralPopup_GuildMemSet"),panelName = "GeneralPopup_GuildMemSet",type = GENERAL_POPUP_TYPE.GuildMemSet},
    --改装厂回溯英雄返还提示
    [24] = {view = require("Modules/Popup/View/GeneralPopup_HeroStarBack"),panelName = "GeneralPopup_HeroStarBack",type = GENERAL_POPUP_TYPE.GeneralPopup_HeroStarBack},
    --作战方案分解预览提示
    [25] = {view = require("Modules/Popup/View/GeneralPopup_DecomposePlan"),panelName = "GeneralPopup_DecomposePlan",type = GENERAL_POPUP_TYPE.DecomposePlan},
    --勋章售出预览
    [26] = {view = require("Modules/Popup/View/GeneralPopup_MedalSell"),panelName = "GeneralPopup_MedalSell",type = GENERAL_POPUP_TYPE.MedalSell},
    --
    [27] = {view = require("Modules/Popup/View/GeneralPopup_AlameinBuy"),panelName = "GeneralPopup_AlameinBuy",type = GENERAL_POPUP_TYPE.AlameinBuy},
    --YiJingBaoKuConfirm
    [28] = {view = require("Modules/Popup/View/GeneralPopup_YiJingBaoKuConfirm"),panelName = "GeneralPopup_YiJingBaoKuConfirm",type = GENERAL_POPUP_TYPE.YiJingBaoKuConfirm},
    --社稷大典检查是否加入工会
    [29] = {view = require("Modules/Popup/View/GeneralPopup_SheJiCheckGuild"),panelName = "GeneralPopup_SheJiCheckGuild",type = GENERAL_POPUP_TYPE.SheJiCheckGuild},
    --部件重置
    [30] = {view = require("Modules/Popup/View/GeneralPopup_PartsReset"),panelName = "GeneralPopup_PartsReset",type = GENERAL_POPUP_TYPE.PartsReset},
    --雷达重置
    [31] = {view = require("Modules/Popup/View/GeneralPopup_TotemReset"),panelName = "GeneralPopup_TotemReset",type = GENERAL_POPUP_TYPE.TotemReset},
    --坦克一键回收
    [32] = {view = require("Modules/Popup/View/GeneralPopup_OneKeyResolveDismantle"),panelName = "GeneralPopup_OneKeyResolveDismantle",type = GENERAL_POPUP_TYPE.OnrKeyResolveDismantle},
    --[33] = {view = require("Modules/Popup/View/GeneralPopup_XiaoYaoYouItemExchange"), panelName = "GeneralPopup_XiaoYaoYouItemExchange",type=GENERAL_POPUP_TYPE.XiaoYaoYouItemExchange},    
    --碎片一键合成
    [33] = {view = require("Modules/Popup/View/GeneralPopup_FragmentAllCompound"),panelName = "GeneralPopup_FragmentAllCompound",type = GENERAL_POPUP_TYPE.FragmentAllCompound},
    --拍脸
    [34] = {view = require("Modules/Popup/View/GeneralPopup_UpGradePackage"),panelName = "GeneralPopup_UpGradePackage",type = GENERAL_POPUP_TYPE.UpGradePackage},
    --抽卡
    [35] = {view = require("Modules/Popup/View/GeneralPopup_Recruit"),panelName = "GeneralPopup_Recruit",type = GENERAL_POPUP_TYPE.Recruit},
    --购买
    [36] = {view = require("Modules/Popup/View/GeneralPopup_Buy"),panelName = "GeneralPopup_Buy",type = GENERAL_POPUP_TYPE.Buy},
    --通用
    [37] = {view = require("Modules/Popup/View/GeneralPopup_Currency"),panelName = "GeneralPopup_Currency",type = GENERAL_POPUP_TYPE.Currency},
    --文本
    [38] = {view = require("Modules/Popup/View/GeneralPopup_txt"),panelName = "GeneralPopup_txt",type = GENERAL_POPUP_TYPE.Txt},
    --选择
    [39] = {view = require("Modules/Popup/View/GeneralPopup_Choose"),panelName = "GeneralPopup_Choose",type = GENERAL_POPUP_TYPE.Choose},
    --绑定账户
    [40] = {view = require("Modules/Popup/View/GeneralPopup_Binding"),panelName = "GeneralPopup_Binding", type = GENERAL_POPUP_TYPE.Binding},
    --重新确认
    [41] = {view = require("Modules/Popup/View/GeneralPopup_Reconfirm"),panelName = "GeneralPopup_Reconfirm", type = GENERAL_POPUP_TYPE.Reconfirm},
    --基因分解
    [42] = {view = require("Modules/Popup/View/GeneralPopup_GeneDecompose"),panelName = "GeneralPopup_GeneDecompose", type = GENERAL_POPUP_TYPE.GeneDecompose},
}
--子模块预设
local contentPrefabs = {}
--打开弹窗类型
local popupType
--打开弹窗索引
local index = 0

function GeneralPopup:InitComponent()
    this.contents = Util.GetGameObject(this.gameObject,"Contents")
    this.backBtn = Util.GetGameObject(this.contents,"BG/BackBtn")
    this.BG = Util.GetGameObject(this.contents,"BG")
    this.Mask = Util.GetGameObject(this.gameObject,"Mask")
    this.backMask = Util.GetGameObject(this.gameObject,"BackMask")

    --子模块脚本初始化
    for i = 1, #contentScripts do
        contentScripts[i].subNode = Util.GetGameObject(this.contents, contentScripts[i].panelName)
        if contentScripts[i].subNode ~= nil then
            contentScripts[i].createUI = true
            contentScripts[i].view:InitComponent(contentScripts[i].subNode)        
        end
    end
    --预设赋值
    for i = 1,#contentScripts do
        contentPrefabs[i] = Util.GetGameObject(this.contents,contentScripts[i].panelName)
    end
end

function GeneralPopup:BindEvent()
    for i = 1, #contentScripts do
        contentScripts[i].view:BindEvent()
    end
    --返回按钮
    for i = 1, #contentScripts do
        if contentScripts[i].createUI then
            Util.AddClick(Util.GetGameObject(contentScripts[i].subNode, "BG/BackBtn"), function()
                self:ClosePanel()
                Timer.New(function()
                    -- 刷新数据
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
                end, 0.1):Start()
            end)
        end
    end

    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    --     Timer.New(function()
    --         -- 刷新数据
    --         Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
    --     end, 0.1):Start()
    end)

    Util.AddClick(this.backMask,function()
        self:ClosePanel()
    end)
end

function GeneralPopup:AddListener()
    for i = 1, #contentScripts do
        contentScripts[i].view:AddListener()
    end
end

function GeneralPopup:RemoveListener()
    for i = 1, #contentScripts do
        contentScripts[i].view:RemoveListener()
    end
end

function GeneralPopup:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end
local onOpenArgs--临时接的参数 需要onshow刷新的调用
function GeneralPopup:OnOpen(popupType,...)
    onOpenArgs = ...
    --根据传入类型打开对应面板

    for i,v in pairs(contentScripts) do
        if popupType == v.type then
            index = i
            break
        end
    end
    for i = 1,#contentPrefabs do
        if contentScripts[i].createUI then
            contentPrefabs[i].gameObject:SetActive(false)            
        end
    end
    this.Mask:SetActive(index ~= GENERAL_POPUP_TYPE.Onhook)
    if index == GENERAL_POPUP_TYPE.SheJiCheckGuild then
        this.backMask:GetComponent("Button").enabled = false
    else
        this.backMask:GetComponent("Button").enabled = true
    end
    if Util.GetGameObject(contentScripts[index].subNode, "BG") then
        Util.GetGameObject(contentScripts[index].subNode, "BG"):SetActive(index ~= GENERAL_POPUP_TYPE.Onhook)
    end

    contentPrefabs[index].gameObject:SetActive(true)
    contentScripts[index].view:OnShow(this,...)--1、传入自己 2、传入不定参
end

function GeneralPopup:OnShow()
    if index == 8 then--临时接的参数 需要onshow刷新的调用
        contentScripts[index].view:OnShow(this,onOpenArgs)
    end
    if index == 9 then
        this.backMask:GetComponent("Image").color = Color.New(0/255,0/255,0/255,120/255)
        this.BG:SetActive(false)
    else
        this.backMask:GetComponent("Image").color = Color.New(0/255,0/255,0/255,200/255)
        this.BG:SetActive(true)
    end
end

function GeneralPopup:OnClose()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnClose()
    end
end

function GeneralPopup:OnDestroy()
    for i = 1, #contentScripts do
        contentScripts[i].view:OnDestroy()
    end
end

return GeneralPopup