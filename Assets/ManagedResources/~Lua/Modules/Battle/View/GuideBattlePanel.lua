require("Base/BasePanel")
require("Base/Stack")
require("Modules.Battle.Config.PokemonEffectConfig")
local BattleView = require("Modules/Battle/View/BattleView")
local GuideBattleLogic = require("Modules/Battle/View/GuideBattleLogic")
GuideBattlePanel = Inherit(BasePanel)

local this = GuideBattlePanel

local timeCount
local endFunc
local isBack = false --是否为战斗回放
local fightType -- 1关卡 2副本 3限时怪, 5兽潮, 6新关卡, 7公会boss
local orginLayer


function this:ShowRect_Skill(roleIcon,skillName,index,isLead)
    if index == 1 then
        this.myRect_Skill:SetActive(true)
        this.myRect_Skill_Icon.sprite = Util.LoadSprite(GetResourcePath(roleIcon))
        this.myRect_Skill_SkillName.text = GetLanguageStrById(skillName)
        if isLead then
            this.myRect_Skill_title.sprite = Util.LoadSprite("cn2-X1_guaji_jinengmingzi_04_zh")
        else
            this.myRect_Skill_title.sprite = Util.LoadSprite("cn2-X1_guaji_jinengmingzi_01_zh")
        end
        Timer.New(function ()
            this.myRect_Skill:SetActive(false)
        end, 3):Start()
    elseif index == 2 then
        this.enemyRect_Skill:SetActive(true)
        this.enemyRect_Skill_Icon.sprite = Util.LoadSprite(GetResourcePath(roleIcon))
        this.enemyRect_Skill_SkillName.text = GetLanguageStrById(skillName)
        if isLead then
            this.enemyRect_Skill_title.sprite = Util.LoadSprite("cn2-X1_guaji_jinengmingzi_04_zh")
        else
            this.enemyRect_Skill_title.sprite = Util.LoadSprite("cn2-X1_guaji_jinengmingzi_01_zh")
        end
        Timer.New(function ()
            this.enemyRect_Skill:SetActive(false)
        end, 3):Start()
    end
end


--初始化组件（用于子类重写）
function this:InitComponent()
    --this.spLoader = SpriteLoader.New()
    this.battleSceneLogicGameObject, this.battleSceneGameObject = BattleManager.CreateBattleScene(nil)
    BattleView:InitComponent(self, this.battleSceneLogicGameObject,this.battleSceneGameObject)
    orginLayer = 0

    this.BG = Util.GetGameObject(self.gameObject, "BG")
    this.UpRoot = Util.GetGameObject(self.gameObject, "UpRoot")

    this.Option = Util.GetGameObject(this.UpRoot, "option")
    this.DownRoot = Util.GetGameObject(self.gameObject, "DownRoot")

    this.roundText = Util.GetGameObject(this.DownRoot, "option/rounds/Text1"):GetComponent("Text")

    this.orderText = Util.GetGameObject(this.Option, "order/text"):GetComponent("Text")
    
    this.btnTimeScale = Util.GetGameObject(this.DownRoot, "option/btnTimeScale")
    this.ButtonLock = Util.GetGameObject(this.DownRoot, "option/btnJump/lock")
    this.btnJump = Util.GetGameObject(this.DownRoot, "option/btnJump")
    this.btnFightBack = Util.GetGameObject(this.DownRoot, "option/btnFightBack")
    --this.submit = Util.GetGameObject(this.DownRoot, "bg")
    this.btnBuff = Util.GetGameObject(this.DownRoot, "option/btnBuff")

    this.DefResult = Util.GetGameObject(this.UpRoot, "result")
    this.AtkResult = Util.GetGameObject(this.DownRoot, "result")

    this.damagePanel = Util.GetGameObject(this.UpRoot, "damage")
    this.damageBoxBg = Util.GetGameObject(this.damagePanel, "bg")
    this.damageBoxIcon = Util.GetGameObject(this.damagePanel, "bg/iconRoot/icon"):GetComponent("Image")
    this.damageBoxLevel = Util.GetGameObject(this.damagePanel, "lv"):GetComponent("Text")
    this.damageProgress = Util.GetGameObject(this.damagePanel, "progress/Fill")
    this.damageText = Util.GetGameObject(this.damagePanel, "progress/Text"):GetComponent("Text")

    this.myRect_Skill = Util.GetGameObject(self.gameObject,"myRect_Skill")
    this.myRect_Skill_Icon = Util.GetGameObject(this.myRect_Skill,"Icon"):GetComponent("Image")
    this.myRect_Skill_SkillName = Util.GetGameObject(this.myRect_Skill,"SkillName"):GetComponent("Text")
    this.myRect_Skill_title = Util.GetGameObject(this.myRect_Skill,"title"):GetComponent("Image")

    this.enemyRect_Skill = Util.GetGameObject(self.gameObject,"enemyRect_Skill")
    this.enemyRect_Skill_Icon = Util.GetGameObject(this.enemyRect_Skill,"Icon"):GetComponent("Image")
    this.enemyRect_Skill_SkillName = Util.GetGameObject(this.enemyRect_Skill,"SkillName"):GetComponent("Text")
    this.enemyRect_Skill_title = Util.GetGameObject(this.enemyRect_Skill,"title"):GetComponent("Image")

end

--绑定事件（用于子类重写）
function this:BindEvent()

    -- Util.AddLongPressClick(this.submit, function()
    --     BattleRecordManager.SubmitBattleRecord()
    -- end, 0.5)

    Util.AddClick(this.btnJump, function ()
        if BattleManager.IsCanOperate() and not BattleLogic.IsEnd then
            BattleView.EndBattle()
            BattleLogic.IsEnd = true
        end
    end)

end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.gameObject, this.sortingOrder - orginLayer)
    orginLayer = this.sortingOrder

    BattleView:OnSortingOrderChange(this.sortingOrder)
end

--界面打开时调用（用于子类重写）
function this:OnOpen(_fightData, _endFunc, guideType)
    GuideBattleLogic:Init(guideType)
    BattleView:OnOpen(_fightData)
    this.guideType = guideType
    endFunc = _endFunc

    fightType = BATTLE_TYPE.Test --判定战斗类型
    
    local loadMapName = BattleManager.GetBattleBg(fightType)
    if this.mapName ~= loadMapName then
        this.mapName = loadMapName
        if this.mapGameObject ~= nil then
            GameObject.Destroy(this.mapGameObject)
        end
        this.mapGameObject = BattleManager.CreateMap(this.battleSceneGameObject, loadMapName)
    end

    this.mapGameObject = BattleManager.CreateMap(this.battleSceneGameObject, fightType)
    this.btnJump:SetActive(AppConst.isOpenGM)
    this.ButtonLock:SetActive(false)
    this.btnTimeScale:SetActive(false)
    this.damagePanel:SetActive(false)
    this.btnBuff:SetActive(false)
    this.btnFightBack:SetActive(false)

    SoundManager.PlayMusic(SoundConfig.BGM_Battle_1, true, function()
        SoundManager.PlayMusic(SoundConfig.BGM_Battle_1, false)
    end)

    this.fightResult = nil

    -- 清空名字数据
    this.DefResult:SetActive(false)
    this.AtkResult:SetActive(false)

    -- 开始战斗
    BattleView:StartBattle()


    this.InitPanelData()
end

-- 初始化
function this.InitPanelData()
    this.InitOption()
end

function this.InitOption()
    --显示倒计时
    local curRound, maxRound = BattleLogic.GetCurRound()
    this.roundText.text = string.format(GetLanguageStrById(10252), curRound, maxRound)
    
    -- 初始化战斗时间，刷新前端显示
    Time.timeScale = BATTLE_TIME_SCALE_ONE


    --> prompt
    -- local prompt = Util.GetGameObject(this.BtnGM, "Prompt")
    -- prompt:SetActive(false)
end

function this.SwitchTimeScale()
    local _scale = BattleManager.GetTimeScale()
    local child = this.BtnTimeScale.transform.childCount - 3 -- 3倍速时-2
    local s = "x".. math.floor(_scale)
    for i=1, child do
        local g = this.BtnTimeScale.transform:GetChild(i-1).gameObject
        g:SetActive(g.name == s)
    end
end

function this.BattleEnd(result)
    BattleManager.PauseBattle()
    -- 强制停止倍速
    Time.timeScale = 1
    -- 设置音效播放的速度
    SoundManager.SetAudioSpeed(1)
    --用一个变量接收最近的战斗结果
    this.lastBattleResult = {
        result = result,
        hpList = {},
        drop = {},
    }
    
    -- 战斗结束时，如果元素光环面板还开着，则先关闭
    if UIManager.IsOpen(UIName.ElementPopup) then
        UIManager.ClosePanel(UIName.ElementPopup)
    end
    
    -- 检测需要在战斗结束时显示的引导
    GuideBattleLogic:OnBattleEnd(function()
        -- 直接显示结果
        this:ClosePanel()
    end)
end


function this.OnOrderChanged(order)
    --显示波次
    this.orderText.text = string.format("%d/%d", order, BattleLogic.TotalOrder)
end

-- 战斗回合变化回调
this.curRound = 1
function this.OnRoundChanged(round)
    -- 轮数变化
    this.curRound = round
    --显示波次
    local curRound, maxRound = BattleLogic.GetCurRound()
    this.roundText.text = string.format(GetLanguageStrById(10252), curRound, maxRound)

end

-- 角色轮转回调
function this.RoleTurnChange(role)
    GuideBattleLogic:RoleTurnChange(this.curRound, role)
end

-- 由BattleView驱动
function this.OnUpdate()
    
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if this.battleSceneLogicGameObject ~= nil then
        this.battleSceneLogicGameObject:SetActive(false)
    end

    if this.battleSceneGameObject ~= nil then
        this.battleSceneGameObject:SetActive(false)
    end

    BattleView:OnClose()
    if endFunc then
        endFunc(this.lastBattleResult)
    end

    BattleView:OnDestroy()
end

function this:BattleEndClear()

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    --地图销毁
    GameObject.Destroy(this.mapGameObject)
    this.mapGameObject = nil
end

return GuideBattlePanel