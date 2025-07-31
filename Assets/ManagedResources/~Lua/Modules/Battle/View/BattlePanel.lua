require("Base/BasePanel")
require("Base/Stack")
require("Modules.Battle.Config.PokemonEffectConfig")
require("Modules/Fight/FightPointPassMainPanel")
local BattleView = require("Modules/Battle/View/BattleView")
BattlePanel = Inherit(BasePanel)

local chatPanel = require("Modules/Chat/BattleChatPanel")
local this = BattlePanel
local battleTimeScaleKey = "battleTimeScaleKey"

local timeCount
local endFunc
local isBack = false --是否为战斗回放
local fightType -- 1关卡 2副本 3限时怪, 5兽潮, 6新关卡, 7公会boss
local orginLayer
local fightId = nil         --< 通用战斗id
local fightTypeSub = nil    --< 战斗类型子类型 主用于back类型区别
local fightData = nil
local canOutRound = -1

local leaderScale = 1.5--72/55 --《主角技能图标放大大小

-- 显示跳过战斗使用
local hadCounted = 0

-- function BattlePanel:Showleader_Skill(roleIcon,skillName,index)
--     if index == 1 then
--         this.myRect_Skill:SetActive(true)
--         this.myRect_Skill_Icon.sprite = Util.LoadSprite(GetResourcePath(roleIcon))
--         this.myRect_Skill_SkillName.text = GetLanguageStrById(skillName)

--     elseif index == 2 then
--         this.enemyRect_Skill:SetActive(true)
--         this.enemyRect_Skill_Icon.sprite = Util.LoadSprite(GetResourcePath(roleIcon))
--         this.enemyRect_Skill_SkillName.text = GetLanguageStrById(skillName)
--     end
-- end

--初始化所有技能的图标
function BattlePanel:InitIcons_Skill(skillArray,skillName,camp,unlockSlotNum)
    local skillRes = ConfigManager.GetConfig(ConfigName.SkillConfig)
    --获取最大槽位数字
    for i = 1, 4 do
        --设置上锁
        if camp == 0 then
            self:LockGrid_Skill(this.mineLeaderSkill,i,true)
        else
            self:LockGrid_Skill(this.enemyLeaderSkill,i,true)
        end
    end
    --LogError("unlockSlotNum:"..unlockSlotNum)
    local maxSlotNum = unlockSlotNum  
    for i = 1, maxSlotNum do
        --设置解锁
        if camp == 0 then
            self:LockGrid_Skill(this.mineLeaderSkill,i,false)
        else
            self:LockGrid_Skill(this.enemyLeaderSkill,i,false)
        end
    end

    --LogError("#skillArray"..#skillArray)
    if #skillArray > 0 then 
        for i = 1, #skillArray do
            -- if i > maxSlotNum then break end -- 主角固定不会大于四个 未装配技能不显示
            -- if skillArray[i][8].sort==i then 
                local skillid = tonumber(skillArray[i][1])
                --LogError("skillid:"..skillid)
                local iconid = skillRes[skillid].Icon
                --LogError("icon:"..iconid)
                local lv = skillArray[i][8].lv 
                local slot = tonumber(skillArray[i][8].sort)
                -- LogError("skillLv:"..lv)
                if camp == 0 then
                    self:FreshGrid_Skill(this.mineLeaderSkill,iconid,lv,slot)
                else
                    self:FreshGrid_Skill(this.enemyLeaderSkill,iconid,lv,slot)
                end
            -- else
            --     -- 设置为空状态
            --     self:FreshGrid_Skill(this.enemyLeaderSkill,nil,1,i)
            -- end            

        end
    end
end

--刷新技能图标状态 lock skilling hold
function BattlePanel:FreshIcon_Skill(skill,skillLv,camp,maxSlot,nextWaiteSkill)
    local root
    if camp == 0 then
        root = this.mineLeaderSkill
    else
        root = this.enemyLeaderSkill
    end

    local SetIconState
    SetIconState = function(index,state)
        local node = Util.GetGameObject(root, "iconback/node_"..index)
        local picnode = Util.GetGameObject(node, "small/Big")
        local pic =Util.GetGameObject(picnode, "image")--:GetComponent("Image")
        local scale = leaderScale 

        local function defalteTween(_node,part)
            Util.GetTransform(_node, part):DOScale(Vector3.one, 0.3)
            :SetEase(Ease.InOutExpo)
            :SetDelay(0.2)
        end
        local function scaleTween(_part)
            Util.GetTransform(node, _part):DOScale(Vector3.one*scale , skill.ReturnTime / 1000)
            :OnComplete(function () 
                SetIconState(index,1)
                SetIconState(index%4 + 1 ,5) --1 x 2  2 x 3 3 x 4 4 x 1 
            end)
            :SetEase(Ease.OutExpo)
            :SetDelay(0.1)
        end

        if state == 1 then --  使用过
            Util.SetGray(pic, true)
            Util.GetGameObject(picnode, "Fire").gameObject:SetActive(false)
            defalteTween(node,"small")
            defalteTween(node,"circle")

        elseif state == 2  then --select 选择状态
            Util.SetGray(pic, false)
            Util.GetGameObject(picnode, "Fire").gameObject:SetActive(true)
            scaleTween("small",nextWaiteSkill)
            scaleTween("circle",nextWaiteSkill)

            if skill.id == nil then 
                skillLv = 2
            else
                --服务器没有对应字段本地读取表单
                local data = ConfigManager.TryGetConfigDataByKey(ConfigName.MotherShipPlaneConfig, "Skill", skill.id)
                if data == nil then 
                    skillLv = 1
                else
                    skillLv = data.Lvl
                end
            end
            local spriteName = "cn2-X1_zhandou_zhanjian_xingji_0"..tonumber(skillLv)
            local pskillLv = Util.GetGameObject(root, "iconback/skill1"):GetComponent("Image")
            pskillLv.sprite = Util.LoadSprite(spriteName)

        elseif state == 3 then -- unlock 解锁empty
            Util.SetGray(pic, false)
            Util.GetGameObject(picnode, "Fire").gameObject:SetActive(false)
            defalteTween(node,"small")
            defalteTween(node,"circle")

        elseif state == 4 then -- lock 未解锁
        elseif state == 5 then -- 等待使用
            Util.GetGameObject(picnode, "Fire").gameObject:SetActive(true)
        end
    end

    -- for i = 1,maxSlot do  
    --     if  i < skill.sort then
    --         SetIconState(i,1)
    --     else           
    --         SetIconState(i,3)
    --     end
    -- end

    -- 更新选择的等级信息
    SetIconState(skill.sort,2)

    -- lock setgray
    -- skilling background set active
    -- hold skilling background set active false
end

-- 刷新图标信息
function BattlePanel:FreshGrid_Skill(root,roleIcon,lv,index)
   local node = Util.GetGameObject(root, "iconback/node_"..index)
   local picnode = Util.GetGameObject(node, "small/Big")
   local pic = Util.GetGameObject(picnode, "image"):GetComponent("Image")
   Util.GetTransform(node, "image"):DOScale(Vector3.one, 0.1)
   LogError("res:"..GetResourcePath(roleIcon))
   pic.sprite = Util.LoadSprite(GetResourcePath(roleIcon))
end

-- 主角技能图标信息上锁
function BattlePanel:LockGrid_Skill(root,index,unlock)
    local node = Util.GetGameObject(root, "iconback/node_"..index)
    local picnode = Util.GetGameObject(node, "small/Big")
    local pic =Util.GetGameObject(picnode, "image"):GetComponent("Image")
    Util.GetGameObject(picnode, "Fire").gameObject:SetActive(false)
    if not unlock then 
        pic.color = Color.New(1,1,1,1)
        --LogError("unlock")
    else
        pic.color = Color.New(1,1,1,1)
        pic.sprite = Util.LoadSprite("cn2-X1_xinpian_shuxingsuo")
    end
    Util.GetTransform(node, "image"):DOScale(Vector3.New(31/55*0.9, 40/55*0.9, 1), 0.1) --原始图片尺寸 grid/标准尺寸 * 缩放
 end

-- 主角技能图标信息上锁
function BattlePanel:UnGreyAndFrie_Skill(skill,camp,index,role)
    local root 
    if camp == 0 then
        root = this.mineLeaderSkill
    else
        root = this.enemyLeaderSkill
    end
    local node = Util.GetGameObject(root, "iconback/node_"..index)
    local picnode = Util.GetGameObject(node, "small/Big")
    local pic = Util.GetGameObject(picnode, "image"):GetComponent("Image")
    Util.GetGameObject(picnode, "Fire").gameObject:SetActive(false) 
    if skill.sort == #role.skillArray then
        for i=1, 4  do
            local node = Util.GetGameObject(root, "iconback/node_"..i)
            local picnode = Util.GetGameObject(node, "small/Big")
            local pic = Util.GetGameObject(picnode, "image")
            Util.SetGray(pic, false)
        end
    end
 end


function BattlePanel:ShowRect_Skill(roleIcon, skillName, index, isLead)
    if index == 1 then
        this.myRect_Skill:SetActive(true)
        if isLead then
            this.myRect_Skill_title.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_guaji_jinengmingzi_04"))
        else
            this.myRect_Skill_title.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_guaji_jinengmingzi_01"))
        end
        this.myRect_Skill_Icon.sprite = Util.LoadSprite(GetResourcePath(roleIcon))
        this.myRect_Skill_SkillName.text = GetLanguageStrById(skillName)
        this.myRect_Skill_title:SetNativeSize()
        Timer.New(function ()
            this.myRect_Skill:SetActive(false)
        end, 3):Start()
    elseif index == 2 then
        this.enemyRect_Skill:SetActive(true)
        if isLead then
            this.enemyRect_Skill_title.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_guaji_jinengmingzi_04"))
        else
            this.enemyRect_Skill_title.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_guaji_jinengmingzi_01"))
        end
        this.enemyRect_Skill_Icon.sprite = Util.LoadSprite(GetResourcePath(roleIcon))
        this.enemyRect_Skill_SkillName.text = GetLanguageStrById(skillName)
        this.enemyRect_Skill_title:SetNativeSize()
        Timer.New(function ()
            this.enemyRect_Skill:SetActive(false)
        end, 3):Start()
    end
end

--初始化组件（用于子类重写）
function this:InitComponent()
    --创建战场Prefab
    this.battleSceneLogicGameObject, this.battleSceneGameObject = BattleManager.CreateBattleScene(nil)

    BattleView:InitComponent(self, this.battleSceneLogicGameObject, this.battleSceneGameObject)
    chatPanel:InitComponent(Util.GetGameObject(self.gameObject, "ChatPanel"), this)

    orginLayer = 0

    this.BG = Util.GetGameObject(self.gameObject, "BG")
    this.UpRoot = Util.GetGameObject(self.gameObject, "UpRoot")

    this.Option = Util.GetGameObject(this.UpRoot, "option")
    this.DownRoot = Util.GetGameObject(self.gameObject, "DownRoot")

    --回合数
    this.roundText = Util.GetGameObject(this.DownRoot, "option/rounds/Text1"):GetComponent("Text")
    this.roundText2 = Util.GetGameObject(this.DownRoot, "option/rounds/Text2"):GetComponent("Text")

    this.orderText = Util.GetGameObject(this.Option, "order/text"):GetComponent("Text")
    
    this.btnTimeScale = Util.GetGameObject(this.DownRoot, "option/btnTimeScale")--倍数
    this.btnExit = Util.GetGameObject(this.DownRoot, "option/btnExit")
    this.ButtonLock = Util.GetGameObject(this.DownRoot, "option/Button/lock")
    this.btnJump = Util.GetGameObject(this.DownRoot, "option/btnJump")--跳过
    this.btnFightBack = Util.GetGameObject(this.DownRoot, "option/btnFightBack")--切出
    this.btnBuff = Util.GetGameObject(this.DownRoot, "option/btnBuff")--buff
    this.submit = Util.GetGameObject(this.DownRoot, "bg")

    this.DefResult = Util.GetGameObject(this.UpRoot, "result")
    this.AtkResult = Util.GetGameObject(this.DownRoot, "result")

    this.damagePanel = Util.GetGameObject(this.UpRoot, "damage")
    this.damageBoxBg = Util.GetGameObject(this.damagePanel, "bg")
    this.damageBoxIcon = Util.GetGameObject(this.damagePanel, "bg/iconRoot/icon"):GetComponent("Image")
    this.damageBoxLevel = Util.GetGameObject(this.damagePanel, "lv"):GetComponent("Text")
    this.damageProgress = Util.GetGameObject(this.damagePanel, "progress/Fill")
    this.damageText = Util.GetGameObject(this.damagePanel, "progress/Text"):GetComponent("Text")

    this.myRect_Skill = Util.GetGameObject(self.gameObject, "myRect_Skill")
    this.myRect_Skill_title = Util.GetGameObject(this.myRect_Skill, "title"):GetComponent("Image")
    this.myRect_Skill_Icon = Util.GetGameObject(this.myRect_Skill, "Icon"):GetComponent("Image")
    this.myRect_Skill_SkillName = Util.GetGameObject(this.myRect_Skill, "SkillName"):GetComponent("Text")
    
    this.enemyRect_Skill = Util.GetGameObject(self.gameObject, "enemyRect_Skill")
    this.enemyRect_Skill_title = Util.GetGameObject(this.enemyRect_Skill, "title"):GetComponent("Image")
    this.enemyRect_Skill_Icon = Util.GetGameObject(this.enemyRect_Skill, "Icon"):GetComponent("Image")
    this.enemyRect_Skill_SkillName = Util.GetGameObject(this.enemyRect_Skill, "SkillName"):GetComponent("Text")


    this.mineLeaderSkill = Util.GetGameObject(self.gameObject, "leftLeaderMan")
    this.enemyLeaderSkill = Util.GetGameObject(self.gameObject, "rightLeaderMan")


    this.btnBuffUp = Util.GetGameObject(self.gameObject, "DownRoot/option/btnBuffUp")
end

--绑定事件（用于子类重写）
function this:BindEvent()

    chatPanel:BindEvent()

    Util.AddLongPressClick(this.submit, function()
        BattleRecordManager.SubmitBattleRecord()
    end, 0.5)


    Util.AddClick(this.btnTimeScale, function ()
        if not BattleManager.IsCanOperate() then
            return
        end
        if not BattleManager.IsUnlockBattleSpeed() then
            PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.DoubleTimesFight))
            return
        end
        local scale = BattleManager.GetTimeScale()
        -- scale = math.floor(scale*10 + 0.5)/10
        scale = math.floor(scale)
        if scale == math.floor(BATTLE_TIME_SCALE_ONE) then
            BattleManager.SetTimeScale(BATTLE_TIME_SCALE_TWO)
        elseif scale == math.floor(BATTLE_TIME_SCALE_TWO) then
            if not BattleManager.IsUnlockBattleSpeedThree() then
                PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.ThreeTimesFight))
                BattleManager.SetTimeScale(BATTLE_TIME_SCALE_ONE)
                return
            end
            BattleManager.SetTimeScale(BATTLE_TIME_SCALE_Three)
        elseif scale == BATTLE_TIME_SCALE_Three then
            BattleManager.SetTimeScale(BATTLE_TIME_SCALE_ONE)
        end
    end)

    Util.AddClick(this.ButtonLock, function ()
        PopupTipPanel.ShowTipByLanguageId(12246)
    end)

    local pauseTime = 31
    Util.AddClick(this.btnExit, function ()
        if not BattleManager.IsUnlockBattlePass() then
            PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(isBack and  PRIVILEGE_TYPE.SkipFight or PRIVILEGE_TYPE.ExitFight ))
            return
        end
        if BattleLogic.IsEnd or not BattleManager.IsCanOperate() then
            return
        end
        -- 战斗暂停
        BattleManager.PauseBattle()

        local count = 0
        local timer = Timer.New(function ()
            if not UIManager.IsOpen(UIName.MsgPanel) then
                return
            end
            count = count + 1
            if isBack then
                MsgPanel.tipLabel.text = string.format(GetLanguageStrById(10255), pauseTime - count)
            else
                MsgPanel.tipLabel.text = string.format(GetLanguageStrById(10256), pauseTime - count)
            end
            if count == pauseTime then
                MsgPanel.OnRightBtnClick()
                return
            end
        end, 1, pauseTime, true)
        local cancelFunc = function ()
            this.CastingPass = MsgPanel._toggle.isOn
            BattleManager.ResumeBattle()
            timer:Stop()
        end
        local sureFunc = function()
            this.CastingPass = MsgPanel._toggle.isOn
            BattleLogic.IsEnd = true
            BattleView.Clear()
            timer:Stop()

            -- 事先初始化
            this.lastBattleResult = {
                result = 0,
                lastPos = 0,
            }
            if isBack then --战斗回放直接跳过
                if not this.fightResult then

                end
                BattleView.EndBattle(this.fightResult or 0)
                return
            end

            if fightType == BATTLE_TYPE.MAP_FIGHT then
                -- 必输的操作
                NetManager.MapFightResultRequest(1, "", "", fightType, this.lastBattleResult.result,function (msg)
                    this.lastBattleResult.result = msg.result
                    if msg.lastXY then
                        this.lastBattleResult.lastPos = msg.lastXY
                    else
                        this.lastBattleResult.lastPos = 0
                    end
                    this.ShowBattleResult(msg.result)
                end)
            elseif fightType == BATTLE_TYPE.GUILD_BOSS and  fightType == BATTLE_TYPE.GUILD_CAR_DELAY then
                this.lastBattleResult.result = -1
                this:ClosePanel()
            else
                this.ShowBattleResult(0)
            end
        end
        MsgPanel.ShowTwo(GetLanguageStrById(10258), sureFunc, cancelFunc, GetLanguageStrById(10259), GetLanguageStrById(10260),nil, false, GetLanguageStrById(10261))
        MsgPanel._toggle.isOn = this.CastingPass
        timer:Start()
    end)

    Util.AddClick(this.btnJump, function ()
        if BattleManager.IsCanOperate() 
        -- and not BattleLogic.IsEnd
        then
            if AppConst.isOpenGM then

            else
                if fightType == BATTLE_TYPE.Climb_Tower then --爬塔战斗 判断爬塔跳过战斗特权
                    if not PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ClimbTowerJump) then
                        PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.ClimbTowerJump))
                        return
                    end
                elseif fightType == BATTLE_TYPE.DefenseTraining then --深渊试炼战斗 判断深渊试炼跳过战斗特权
                    if not PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.DefenseTrainingJump) then
                        PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.DefenseTrainingJump))
                        return
                    end
                elseif fightType == BATTLE_TYPE.BLITZ_STRIKE then --遗忘之城战斗 判断遗忘之城跳过战斗特权
                    if not PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.BlitzStrikeJump) then
                        PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.BlitzStrikeJump))
                        return
                    end
                elseif fightType == BATTLE_TYPE.DAILY_CHALLENGE then --异端之战战斗 判断异端之战跳过战斗特权
                    if not PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.MapJump) then
                        PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.MapJump))
                        return
                    end
                elseif fightType == BATTLE_TYPE.REDCLIFF then --腐化之战战斗 判断腐化之战跳过战斗特权
                    if not PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.Carbon) then
                        PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.Carbon))
                        return
                    end
                elseif not BattleManager.IsUnlockBattlePass() then
                    PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.SkipFight))
                    return
                end
            end
            --BOSS关无法跳过
            if fightType == BATTLE_TYPE.STORY_FIGHT then
                if G_MainLevelConfig[FightPointPassManager.curOpenFight].BossShow == 1 then
                    PopupTipPanel.ShowTip(GetLanguageStrById(50201))
                    return
                end
            end

            BattleView.IsJumpGameEnd = true
            BattleView.EndBattle()
            BattleLogic.IsEnd = true
        end
    end)

    Util.AddClick(this.btnBuff, function ()
        -- if BattleManager.IsCanOperate() and not BattleLogic.IsEnd then
        --     BattleView.IsJumpGameEnd = true
        --     BattleView.EndBattle()
        --     BattleLogic.IsEnd = true
        -- end

        -- local roles = BattleView:GetRoles()
        UIManager.OpenPanel(UIName.BuffPreviewPopup)--, roles)
    end)

    Util.AddClick(this.btnBuffUp, function ()
        UIManager.OpenPanel(UIName.BuffPreviewPopup)
    end)

    Util.AddClick(this.btnFightBack, function ()
        if BattleLogic.GetCurRound() < canOutRound + 1 then
            PopupTipPanel.ShowTip(GetLanguageStrById(50276))
            return
        end

        if BattleManager.IsUnlockBattleInBack() then
            if not UIManager.IsOpen(UIName.MainPanel) then
                BattleManager.isFightBack = true
                BattleView:ResetAllRoleAnimation()
                SoundManager.SetBattleVolume(0)
                UIManager.OpenPanel(UIName.MainPanel)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(50016)
        end
    end)
end

function this:SetOutRound()
    if fightData and (next(fightData.fightUnitDataAppend) ~= nil or next(fightData.tankDataAppend) ~= nil) then
        canOutRound = -1
        if fightData.fightUnitDataAppend and #fightData.fightUnitDataAppend > 0 then
            for i = 1, #fightData.fightUnitDataAppend do
                canOutRound = math.max(canOutRound, fightData.fightUnitDataAppend[i].round)
            end
        end
        if fightData.tankDataAppend and #fightData.tankDataAppend > 0 then
            for i = 1, #fightData.tankDataAppend do
                canOutRound = math.max(canOutRound, fightData.tankDataAppend[i].round)
            end
        end
    end
end

function this:LoseJump(id)
    if not MapManager.isInMap then
        if JumpManager.CheckJump(id) then
            this:ClosePanel()
            JumpManager.GoJumpWithoutTip(id)
        end
    else
        PopupTipPanel.ShowTipByLanguageId(10250)
    end
end

--添加事件监听（用于子类重写）
function this:AddListener()
    chatPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Battle.OnTimeScaleChanged, this.SwitchTimeScale)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    chatPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Battle.OnTimeScaleChanged, this.SwitchTimeScale)
end

function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.gameObject, this.sortingOrder - orginLayer)
    orginLayer = this.sortingOrder

    chatPanel:OnSortingOrderChange(self.sortingOrder)
    BattleView:OnSortingOrderChange(this.sortingOrder)
    -- this.BtView:OnSortingOrderChange(this.sortingOrder)
end

--界面打开时调用（用于子类重写）
function this:OnOpen(_fightData, _fightType, _endFunc, _fightId, _fightTypeSub)
    chatPanel:OnShow()
    this:CloseOtherPanel()
    if this.battleSceneLogicGameObject ~= nil then
        this.battleSceneLogicGameObject:SetActive(true)
    end

    if this.battleSceneGameObject ~= nil then
        this.battleSceneGameObject:SetActive(true)
    end
    this:CloseOtherPanel()
    BattleView:OnOpen(_fightData)

    fightData = _fightData.fightData
    endFunc = _endFunc
    fightType = _fightType --判定战斗类型
    isBack = _fightType == BATTLE_TYPE.BACK --判定是否是战斗回放
    hadCounted = 0
    fightId = _fightId
    fightTypeSub = _fightTypeSub

    local loadMapName = _fightData.mapName
    if not loadMapName then
        loadMapName =  BattleManager.GetBattleBg(fightType)
    end

    if this.mapName ~= loadMapName then
        this.mapName = loadMapName
        if this.mapGameObject ~= nil then
            GameObject.Destroy(this.mapGameObject)
        end
        this.mapGameObject = BattleManager.CreateMap(this.battleSceneGameObject, loadMapName)
    end

    this.btnExit:SetActive(false)--FightPointPassManager.GetStopBtnState())

    SoundManager.PlayMusic(SoundConfig.BGM_Battle_1, true, function()
        -- SoundManager.PlayMusic(SoundConfig.BGM_Battle_2, false)
        SoundManager.PlayMusic(SoundConfig.BGM_Battle_1, false)
    end)

    this.fightResult = nil

    -- 清空名字数据
    BattleView:SetNameStr(nil)
    this.DefResult:SetActive(false)
    this.AtkResult:SetActive(false)

    local bossFinished = function ()
        -- 开始战斗
        BattleView:StartBattle()
        this.InitPanelData()
    end

    if fightType == BATTLE_TYPE.STORY_FIGHT then
        if G_MainLevelConfig[FightPointPassManager.curOpenFight].BossShow == 1 then
            --先驱守护隐藏
            Util.GetGameObject(this.gameObject.transform.parent, "BattlePanel/DownRoot/option/OuterUnit/mine"):SetActive(false)
            Util.GetGameObject(this.gameObject.transform.parent, "BattlePanel/DownRoot/option/OuterUnit/enemy"):SetActive(false)
            --延迟执行
            Timer.New(function()
                --显示boss来袭特效
                local fightBossName = "FightTipsUI_Boss"
                local fightTipsUI_Boss = poolManager:LoadAsset(fightBossName, PoolManager.AssetType.GameObject)
                fightTipsUI_Boss.transform:SetParent(self.gameObject.transform)
                fightTipsUI_Boss.transform.localScale = Vector3.one
                fightTipsUI_Boss.transform.localPosition = Vector3.zero
                --特效时间后销毁
                --更换多语言资源
                local font = Util.GetGameObject(fightTipsUI_Boss.gameObject, "font"):GetComponent("MeshRenderer").materials[0]
                local fontLight = Util.GetGameObject(fightTipsUI_Boss.gameObject, "fontLight"):GetComponent("MeshRenderer").materials[0]
                local name = font:GetTexture("_TextureSample0").name
                local newName = GetPictureFont(string.sub(name, 1, #(name)-3))
                local material = poolManager:LoadAsset(newName, PoolManager.AssetType.Other)
                if material == nil then
                    LogRed("无" .. newName)
                else
                    font:SetTexture("_TextureSample0", material)
                    fontLight:SetTexture("_MainTex", material)
                end
                
                --特效时间后销毁
                Timer.New(function()
                    bossFinished()
                    poolManager:UnLoadAsset(fightBossName, fightTipsUI_Boss, PoolManager.AssetType.GameObject)
                end,2):Start()
            end,0.3):Start()
        else
            bossFinished()
        end
    else
        bossFinished()
    end

     this:SetOutRound()
    -- this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.AlameinWarPanel })
end

function this:CloseOtherPanel()
    if UIManager.IsOpen(UIName.DamageResultPanel) then
        UIManager.ClosePanel(UIName.DamageResultPanel)
    end
    if UIManager.IsOpen(UIName.DefenseTrainingBuffPopup) then
        UIManager.ClosePanel(UIName.DefenseTrainingBuffPopup)
    end
    if UIManager.IsOpen(UIName.RewardItemSingleShowPopup) then
        UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
    end
    if UIManager.IsOpen(UIName.PublicGetHeroPanel) then
        UIManager.ClosePanel(UIName.PublicGetHeroPanel)
    end
end

function this:OnOpenCustom()
    --战斗从后台打开
    if this.battleSceneLogicGameObject ~= nil then
        this.battleSceneLogicGameObject:SetActive(true)
    end

    if this.battleSceneGameObject ~= nil then
        this.battleSceneGameObject:SetActive(true)
    end

    BattleView:OnOpenCustom()
end

-- 设置战斗结果
function this:SetResult(result)
    this.fightResult = result
end

-- 外部调用
function this:ShowNameShow(result, str)
    if true then return end
    this.fightResult = result
    if str then 
        local nameList = string.split(str, "|")
        BattleView:SetNameStr(str)
        this.DefResult:SetActive(true)
        this.AtkResult:SetActive(true)
    
        Util.GetGameObject(this.AtkResult, "win"):SetActive(result == 1)
        Util.GetGameObject(this.AtkResult, "lose"):SetActive(result == 0)
        Util.GetGameObject(this.DefResult, "win"):SetActive(result == 0)
        Util.GetGameObject(this.DefResult, "lose"):SetActive(result == 1)
    
        Util.GetGameObject(this.AtkResult, "win/Text"):GetComponent("Text").text = nameList[1]
        Util.GetGameObject(this.AtkResult, "lose/Text"):GetComponent("Text").text = nameList[1]
        Util.GetGameObject(this.DefResult, "win/Text"):GetComponent("Text").text = nameList[2]
        Util.GetGameObject(this.DefResult, "lose/Text"):GetComponent("Text").text = nameList[2]
    else
        this.DefResult:SetActive(false)
        this.AtkResult:SetActive(false)
    end
end

-- 初始化
function this.InitPanelData()
    if fightType == BATTLE_TYPE.GUILD_BOSS and  fightType == BATTLE_TYPE.GUILD_CAR_DELAY then
        this.myDamage = 0
        this.myDamageLevel = 0
        this.RefreshMyDamageShow()
        local list = RoleManager.Query(function (r) return r.camp == 1 end)
        if list[1] then
            list[1].Event:AddEvent(BattleEventName.RoleBeDamaged, function (atkRole, damage, bCrit, finalDmg, damageType, dotType)
                this.myDamage = this.myDamage + damage
                this.RefreshMyDamageShow()
            end)
        end
    end

    this.InitOption()
end

function this.InitOption()
    --显示倒计时
    local curRound, maxRound = BattleLogic.GetCurRound()
    this.roundText.text = curRound
    this.roundText2.text = "/" .. maxRound
    hadCounted = 0
    
    this.Option:SetActive(true)
    Util.GetGameObject(this.btnTimeScale, "lock"):SetActive(not BattleManager.IsUnlockBattleSpeed())

    --跳过锁定
    local IsUnLockBattlePass
    if fightType == BATTLE_TYPE.Climb_Tower then
        IsUnLockBattlePass = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ClimbTowerJump)
    elseif fightType == BATTLE_TYPE.DefenseTraining then
        IsUnLockBattlePass =  PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.DefenseTrainingJump)
    elseif fightType == BATTLE_TYPE.BLITZ_STRIKE then
        IsUnLockBattlePass =  PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.BlitzStrikeJump)
    elseif fightType == BATTLE_TYPE.DAILY_CHALLENGE then
        IsUnLockBattlePass =  PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.MapJump)
    elseif fightType == BATTLE_TYPE.REDCLIFF then
        IsUnLockBattlePass = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.Carbon)
    else
        IsUnLockBattlePass = BattleManager.IsUnlockBattlePass()
    end
    if AppConst.isOpenGM then
        Util.GetGameObject(this.btnJump, "lock"):SetActive(false)
    else
        Util.GetGameObject(this.btnJump, "lock"):SetActive(not IsUnLockBattlePass)
    end

    -- 跳过
    Util.GetGameObject(this.btnJump, "Prompt"):GetComponent("Text").text = GetLanguageStrById(50277)
    Util.GetGameObject(this.btnJump, "Prompt"):SetActive(IsUnLockBattlePass)

    -- 切出
    local isUnlockBattleInBack = BattleManager.IsUnlockBattleInBack()
    Util.GetGameObject(this.btnFightBack, "lock"):SetActive(not isUnlockBattleInBack)

    -- 初始化战斗时间，刷新前端显示
    BattleManager.InitTimeScale()
    this.SwitchTimeScale()
end

function this.SwitchTimeScale()
    local _scale = BattleManager.GetTimeScale()
    local child = this.btnTimeScale.transform.childCount 
    local s = "x".. math.floor(_scale)
    for i = 1, child do
        local g = this.btnTimeScale.transform:GetChild(i-1).gameObject
        g:SetActive(g.name == s)
    end
end

function this.BattleEnd(result)
    BattleManager.isFightBack = false
    BattleManager.ResetCVDatas() --< 重置航母显示数据
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
    
    -- 需要和服务器确认结果
    if fightType == BATTLE_TYPE.MAP_FIGHT
    or fightType == BATTLE_TYPE.MONSTER_CAMP
    or fightType == BATTLE_TYPE.STORY_FIGHT
    or fightType == BATTLE_TYPE.GUILD_BOSS
    or fightType == BATTLE_TYPE.Climb_Tower
    or fightType == BATTLE_TYPE.Climb_Tower_Advance
    or fightType == BATTLE_TYPE.CONTEND_HEGEMONY
    or fightType == BATTLE_TYPE.BLITZ_STRIKE
    or fightType == BATTLE_TYPE.DefenseTraining
    or fightType == BATTLE_TYPE.ALAMEIN_WAR
    or fightType == BATTLE_TYPE.PVEActivity
    then
        local levelId = nil
        if fightType == BATTLE_TYPE.Climb_Tower then
            levelId = ClimbTowerManager.curFightId
        elseif fightType == BATTLE_TYPE.Climb_Tower_Advance then
            levelId = ClimbTowerManager.curFightId_Advance
        elseif fightType == BATTLE_TYPE.DefenseTraining
            or fightType == BATTLE_TYPE.BLITZ_STRIKE
            or fightType == BATTLE_TYPE.ALAMEIN_WAR then
            levelId = fightId
        elseif fightType == BATTLE_TYPE.CONTEND_HEGEMONY then
            levelId = HegemonyManager.curFightId
        elseif fightType == BATTLE_TYPE.DAILY_CHALLENGE 
            or fightType == BATTLE_TYPE.REDCLIFF 
            or fightType == BATTLE_TYPE.CollectMaterials then
            levelId = 1
        elseif fightType == BATTLE_TYPE.PVEActivity then
            levelId = PVEActivityManager.selectId
        else
            levelId = FightPointPassManager.GetCurFightId()
        end
        
        NetManager.MapFightResultRequest(10000, "", levelId, fightType,result, function (msg)
            for i = 1, #msg.remainHpList do
                this.lastBattleResult.hpList[i] = msg.remainHpList[i]
            end
            
            this.lastBattleResult.drop = msg.enventDrop
            this.lastBattleResult.missionDrop = msg.missionDrop
            this.lastBattleResult.result = msg.result
            this.lastBattleResult.mission = msg.mission
            this.lastBattleResult.eventId = msg.eventId
            this.lastBattleResult.lastTowerTime = msg.lastTowerTime
            if msg.lastXY then
                this.lastBattleResult.lastPos = msg.lastXY
            else
                this.lastBattleResult.lastPos = 0
            end
            this.ShowBattleResult(msg.result, msg)
        end)
    elseif fightType == BATTLE_TYPE.EXECUTE_FIGHT then--远征处理
        if ExpeditionManager.ExpeditionState == 1 then
            local GetCurNodeInfo = ExpeditionManager.curAttackNodeInfo
            NetManager.EndExpeditionBattleRequest(GetCurNodeInfo.sortId, "", function (msg)
                this.lastBattleResult.result = msg.result
                this.lastBattleResult.drop = msg.drop
                --ExpeditionManager.UpdateHeroHpValue(msg.heroInfo)
                --ExpeditionManager.UpdateNodeValue(msg) --nodeInfo
                this.ShowBattleResult(msg.result, msg)
            end)
        else
            this:ClosePanel()
            ExpeditionManager.RefreshPanelShowByState()
        end
    else
        -- 直接显示结果
        this.ShowBattleResult(result)
    end
end

function this.ShowBattleResult(result, msg)
    -- 检测不一致数据记录
    if BattleRecordManager.Lastresult ~= -1 then
        if result ~=  BattleRecordManager.Lastresult then            
            LogError("##fightDate is Error!!!!" .. "server is :"..result .." local is ：".. BattleRecordManager.Lastresult)
            if fightType == BATTLE_TYPE.MAP_FIGHT
            or fightType == BATTLE_TYPE.MONSTER_CAMP
            -- or fightType == BATTLE_TYPE.STORY_FIGHT 
            -- or fightType == BATTLE_TYPE.GUILD_BOSS
            -- or fightType == BATTLE_TYPE.Climb_Tower
            -- or fightType == BATTLE_TYPE.Climb_Tower_Advance
            -- or fightType == BATTLE_TYPE.CONTEND_HEGEMONY
            -- or fightType == BATTLE_TYPE.DefenseTraining
            or fightType == BATTLE_TYPE.ALAMEIN_WAR then 
                --  result = BattleRecordManager.Lastresult
            end
        end
    end

    SoundManager.StopMusic()
    -- -- 战斗结束时，如果元素光环面板还开着，则先关闭
    -- if UIManager.IsOpen(UIName.ElementPopup) then
    --     UIManager.ClosePanel(UIName.ElementPopup)
    -- end
    -- 回放直接关闭界面
    if fightType == BATTLE_TYPE.BACK then
        --> 判断回放类型 独立显示
        if fightTypeSub and fightTypeSub == BATTLE_TYPE_BACK.BACK_WITH_SB then
            if result == 0 then  -- 失败
                local haveRecord = BattleRecordManager.isHaveRecord()
                UIManager.OpenPanel(UIName.BattleFailPopup, this, haveRecord,nil, fightType)
            else  -- 胜利
                -- UIManager.OpenPanel(UIName.BattleWinPopup, this, isBack, fightType, this.lastBattleResult)
                local bestData, allDamage = BattleRecordManager.GetBattleBestData()
                if bestData then
                    -- 胜利显示本场比赛的表现最好的英雄
                    UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, nil, function(_BattleBestPopup)
                        if _BattleBestPopup then
                            _BattleBestPopup:ClosePanel()
                        end
                        this:ClosePanel()
                    end, true)
                end
            end
        else
            this:ClosePanel()
        end
        return 
    end
    if fightType == BATTLE_TYPE.Climb_Tower_Advance and ClimbTowerManager.fight_isPVP then
        if result == 0 then  -- 失败
            local haveRecord = BattleRecordManager.isHaveRecord()
            UIManager.OpenPanel(UIName.BattleFailPopup, this, haveRecord,nil, fightType)
        else  -- 胜利
            -- local bestData, allDamage= BattleRecordManager.GetBattleBestData()
            -- if bestData then
            --     -- 胜利显示本场比赛的表现最好的英雄
            --     UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, nil, function(_BattleBestPopup)
            --         if _BattleBestPopup then
            --             _BattleBestPopup:ClosePanel()
            --         end
            --         this:ClosePanel()
            --     end, true)
            -- end

            NetManager.VirtualElitBattleGetInfo(function()
                ClimbTowerManager.GetRankData(function()
                    PopupTipPanel.ShowTipByLanguageId(22523)
                    this:ClosePanel()
                end, ClimbTowerManager.ClimbTowerType.Advance)
            end)
        end
        return
    end
    -- 播放结算音效
    if result == 0 then
        this.resultSoundAudio = SoundManager.PlaySound(SoundConfig.Sound_BattleLose)
    else
        this.resultSoundAudio = SoundManager.PlaySound(SoundConfig.Sound_BattleWin)
    end

    if fightType == BATTLE_TYPE.GUILD_BOSS then
        UIManager.OpenPanel(UIName.GuildBossFightResultPopup, msg.enventDrop, msg.missionDrop, msg.essenceValue, function()
            this:ClosePanel()
        end)
    elseif fightType == BATTLE_TYPE.GUILD_CAR_DELAY and GuildCarDelayManager.progress == 1 then
        -- 延时执行避免事件冲突
        Timer.New(function()
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    UIManager.ClosePanel(UIName.BattleOfMinskBuyCountPopup)
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup,nil, 1,function()
                        --车迟挑战cd计时
                        GuildCarDelayManager.SetCdTime(GuildCarDelayProType.Challenge)
                        if _BattleBestPopup then
                            _BattleBestPopup:ClosePanel()
                        end
                        this:ClosePanel()
                    end, 3,true,true,nil,true,nil,BATTLE_TYPE.GUILD_CAR_DELAY)
                end)
            end
        end, 0.1):Start()
    elseif fightType == BATTLE_TYPE.DEATH_POS then
        -- 延时执行避免事件冲突
        Timer.New(function()
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup, GuildBattleManager.drop, 1,function()
                        if _BattleBestPopup then
                            _BattleBestPopup:ClosePanel()
                        end
                        this:ClosePanel()
                    end, 4,true,true,nil,true,nil,BATTLE_TYPE.DEATH_POS)
                end)
            end
        end, 0.1):Start()
    elseif fightType == BATTLE_TYPE.GuildTranscript then
        -- 延时执行避免事件冲突
        Timer.New(function()
            local bestData, allDamage = BattleRecordManager.GetBattleBestData()
            if bestData then
                -- 胜利显示本场比赛的表现最好的英雄
                UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
                    -- 打开关卡奖励界面
                    UIManager.OpenPanel(UIName.RewardItemPopup,GuildTranscriptManager.drop, 1,function()
                        if _BattleBestPopup then
                            _BattleBestPopup:ClosePanel()
                        end
                        this:ClosePanel()
                        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildTranscripQuickBtn)
                        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildTranscript)
                        GuildTranscriptManager.IsKillShowTip()
                    end, 6,true,true,nil,false)
                end)
            end
        end, 0.1):Start()
    -- elseif fightType == BATTLE_TYPE.CONTEND_HEGEMONY then
    --     Timer.New(function()
    --         local bestData, allDamage= BattleRecordManager.GetBattleBestData()
    --         if bestData then
    --             --胜利显示本场比赛的表现最好的英雄
    --             UIManager.OpenPanel(UIName.BattleBestPopup, bestData.roleId, bestData.damage, allDamage, function(_BattleBestPopup)
    --                 -- 打开关卡奖励界面
    --                 UIManager.OpenPanel(UIName.RewardItemPopup,false, 1,function()
    --                     if _BattleBestPopup then
    --                         _BattleBestPopup:ClosePanel()
    --                     end
    --                     UIManager.ClosePanel(UIName.HegemonyPopup)
    --                     this:ClosePanel()
                        
    --                 end,7,true,true,nil,false,HegemonyManager.curFightId)
    --             end)
    --         end
    --     end, 0.1):Start()    
    else
        if result == 0 then  -- 失败
            local haveRecord = BattleRecordManager.isHaveRecord()
            UIManager.OpenPanel(UIName.BattleFailPopup, this, haveRecord,nil,fightType)
        elseif result == -3 then --战斗异常/进度不匹配
           -- LogError(" xxx fightId"..fightId.." result:"..msg.result)
            local haveRecord = BattleRecordManager.isHaveRecord()
            PopupTipPanel.ShowTip(GetLanguageStrById(10926))
            UIManager.OpenPanel(UIName.BattleFailPopup, this, haveRecord,nil,fightType)           
        else  -- 胜利
            UIManager.OpenPanel(UIName.BattleWinPopup, this, isBack, fightType, this.lastBattleResult)
        end
    end
end

-- 战斗波次变化回调
function this.OnOrderChanged(order)
    -- body
    --显示波次
    this.orderText.text = string.format("%d/%d", order, BattleLogic.TotalOrder)
end

-- 战斗回合变化回调
function this.OnRoundChanged(round)
    -- body
    --显示波次
    local curRound, maxRound = BattleLogic.GetCurRound()
    --限制当前回合数大于最大回合数
    if curRound > maxRound then
        curRound = maxRound
    end
    this.roundText.text = curRound
end

-- 由BattleView驱动
function this.OnUpdate() 
end

-- 刷新我的伤害显示
function this.RefreshMyDamageShow()
    if fightType == 7 or fightType == 10 then
        local myDamage = this.myDamage-- *10
        local bossRewardConfig = ConfigManager.GetConfig(ConfigName.GuildBossRewardConfig)
        local curLevel, curLevelData, nextLevelData 
        for level, data in ConfigPairs(bossRewardConfig) do
            if data.Damage > myDamage then
                nextLevelData = data
                break
            end
            curLevel = level
            curLevelData = data
        end
        if not nextLevelData then
            nextLevelData = curLevelData
        end
        -- 有等级变化
        if curLevel ~= this.myDamageLevel then
            this.myDamageLevel = curLevel
            -- 播放升级特效
            this.damageBoxBg:SetActive(false)
            this.damageBoxBg:SetActive(true)
        end

        this.damageBoxLevel.text = curLevel or 0
        this.damageBoxIcon.sprite = GuildBossManager.GetBoxSpriteByLevel(curLevel or 0)
        -- this.damageText.text = myDamage.."/"..nextLevelData.Damage   -- 显示总伤害
    
        local curLevelDamage = not curLevelData and 0 or curLevelData.Damage
        local deltaDamage = nextLevelData.Damage - curLevelDamage
        local myDeltaDamage = myDamage - curLevelDamage
        local rate = deltaDamage == 0 and 1 or myDeltaDamage/deltaDamage
        this.damageText.text = myDeltaDamage.."/"..deltaDamage   -- 显示当前等级伤害


        this.damageProgress.transform.localScale = Vector3.New(rate, 1, 1)
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    
    chatPanel:OnClose()

    if this.battleSceneLogicGameObject ~= nil then
        this.battleSceneLogicGameObject:SetActive(false)
    end

    if this.battleSceneGameObject ~= nil then
        this.battleSceneGameObject:SetActive(false)
    end


--[[
    BattleView:OnClose()
    -- 停止音效
    --if this.resultSoundAudio then
    --    SoundManager.StopSound(this.resultSoundAudio)
    --end
    -- 
    -- BattleManager.SetTimeScale(1)
    -- 真正生效的敌方 
    Time.timeScale = 1
    -- 设置音效播放的速度
    SoundManager.SetAudioSpeed(1)
    if endFunc then
        endFunc(this.lastBattleResult)
    end
    --检测是否需要弹每日任务飘窗
    TaskManager.RefreshShowDailyMissionTipPanel()

]]


    BattleView:OnClose()
end

function this:BattleEndClear()
    -- 真正生效的敌方 
    Time.timeScale = 1
    -- 设置音效播放的速度
    SoundManager.SetAudioSpeed(1)
    if endFunc then
        endFunc(this.lastBattleResult)
    end
    --检测是否需要弹每日任务飘窗
    TaskManager.RefreshShowDailyMissionTipPanel()

    fightData = nil
    canOutRound = -1
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()

    --地图销毁
    GameObject.Destroy(this.mapGameObject)
    this.mapGameObject = nil

    --销毁战场
    if this.battleSceneLogicGameObject ~= nil then
        GameObject.Destroy(this.battleSceneLogicGameObject)
        this.battleSceneLogicGameObject = nil
    end

    if this.battleSceneGameObject ~= nil then
        GameObject.Destroy(this.battleSceneGameObject)
        this.battleSceneGameObject = nil
    end

    BattleView:OnDestroy()

    -- SubUIManager.Close(this.BtView)
end

return BattlePanel