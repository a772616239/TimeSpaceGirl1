require("Base/BasePanel")
local GuildFightAttackTipPopup = Inherit(BasePanel)
local this = GuildFightAttackTipPopup
--初始化组件（用于子类重写）
function GuildFightAttackTipPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")

    this.time = Util.GetGameObject(self.transform, "content/time/Text"):GetComponent("Text")

    this.myGuild = Util.GetGameObject(self.transform, "content/result/my")
    this.enemyGuild = Util.GetGameObject(self.transform, "content/result/enemy")

    this.buffItem = Util.GetGameObject(self.transform, "content/result/bufflist")
    this.buffRoot = Util.GetGameObject(self.transform, "content/result/Scroll/Viewport/Content")

    this.rankNode = {}
    for i = 1, 3 do
        if not this.rankNode[i] then
            this.rankNode[i] = {}
        end
        this.rankNode[i].node = Util.GetGameObject(self.transform, "content/result/rank/rank"..i)
        this.rankNode[i][1] = Util.GetGameObject(this.rankNode[i].node, "left")
        this.rankNode[i][2] = Util.GetGameObject(this.rankNode[i].node, "right")
    end
end

--绑定事件（用于子类重写）
function GuildFightAttackTipPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildFightAttackTipPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.AttackStageDefendDataUpdate, this.OnOpen)
end

--移除事件监听（用于子类重写）
function GuildFightAttackTipPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.AttackStageDefendDataUpdate, this.OnOpen)
end

--界面打开时调用（用于子类重写）
function GuildFightAttackTipPopup:OnOpen(...)
    this.RefreshGuildShow()
    this.RefreshBuffShow()
    this.RefreshRankShow()

    this._TimeUpdate()
    if not this.timer then
        this.timer = Timer.New(this._TimeUpdate, 1, -1, true)
        this.timer:Start()
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFightAttackTipPopup:OnShow()
end

-- 刷新公会显示
function this.RefreshGuildShow()
    -- 敌方数据显示
    local enemyInfo = GuildFightManager.GetEnemyBaseData()
    this.GuildBaseInfoAdapter(this.enemyGuild, enemyInfo, GUILD_FIGHT_GUILD_TYPE.ENEMY)
    -- 我方数据显示
    local myGuildData = GuildFightManager.GetMyBaseData()
    this.GuildBaseInfoAdapter(this.myGuild, myGuildData, GUILD_FIGHT_GUILD_TYPE.MY)
end

-- 公会基础数据匹配
function this.GuildBaseInfoAdapter(node, data, gType)
    local nameText = Util.GetGameObject(node, "name"):GetComponent("Text")
    local levelText = Util.GetGameObject(node, "level"):GetComponent("Text")
    local levelbg = Util.GetGameObject(node, "lvbg")
    local logoSpr = Util.GetGameObject(node, "icon"):GetComponent("Image")
    local starText = Util.GetGameObject(node, "starNum"):GetComponent("Text")

    -- 星星数量显示
    starText.text = GuildFightManager.GetLeftStarNum(gType)
    levelText.gameObject:SetActive(data ~= nil)
    levelbg.gameObject:SetActive(data ~= nil)
    if data then
        nameText.text = data.name
        levelText.text = data.level
        local logoName = GuildManager.GetLogoResName(data.pictureId)
        logoSpr.sprite = Util.LoadSprite(logoName)
    else
        nameText.text = "..."
        logoSpr.sprite = Util.LoadSprite("r_gonghui_pipeiwenhao")
    end
    logoSpr:SetNativeSize()
end

-- 刷新buff显示
local _BuffNodeList = {}
function this.RefreshBuffShow()
    local myBuffList = GuildFightManager.GetGuildBuffList(GUILD_FIGHT_GUILD_TYPE.MY)
    local enemyBuffList = GuildFightManager.GetGuildBuffList(GUILD_FIGHT_GUILD_TYPE.ENEMY)
    local maxNum = math.max(#myBuffList, #enemyBuffList)
    for i = 1, maxNum do
        local node = _BuffNodeList[i]
        if not node then
            node = newObjToParent(this.buffItem, this.buffRoot.transform)
            _BuffNodeList[i] = node
        end
        this.BuffItemAdapter(node, myBuffList[i], enemyBuffList[i])
    end
end
function this.BuffItemAdapter(node, myProp, enemyProp)
    local buff_1 = Util.GetGameObject(node, "buff_1")
    local buff_2 = Util.GetGameObject(node, "buff_2")

    local function _SingleBuffAdapter(buffNode, prop)
        if not prop then
            buffNode:SetActive(false)
            return
        end
        local propInfo = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.id)
        if not propInfo then
            buffNode:SetActive(false)
            return
        end
        buffNode:SetActive(true)
        -- 显示内容
        local val = prop.value
        local express1 = val >= 0 and "+" or ""
        local express2 = ""
        if propInfo.Style == 2 then
            val = val / 100
            express2 = "%"
        end
        Util.GetGameObject(buffNode, "Text"):GetComponent("Text").text = propInfo.Info .. express1..val..express2
        local lastStr = ""
        if propInfo.IfBuffShow == 1 then
            lastStr = prop.value >= 0 and "_Up" or "_Down"
        end
        buffNode:GetComponent("Image").sprite = Util.LoadSprite(propInfo.BuffShow .. lastStr)
    end

    buff_1:SetActive(myProp ~= nil)
    buff_2:SetActive(enemyProp ~= nil)
    _SingleBuffAdapter(buff_1, myProp)
    _SingleBuffAdapter(buff_2, enemyProp)
end

-- 刷新排名显示
local _PlayerHeadList = {}
function this.RefreshRankShow()
    local myDefendList = GuildFightManager.GetAttackStageFirstThreeMem(GUILD_FIGHT_GUILD_TYPE.MY)
    local enemyDefendList = GuildFightManager.GetAttackStageFirstThreeMem(GUILD_FIGHT_GUILD_TYPE.ENEMY)
    for i = 1, #this.rankNode do
        this.rankNode[i].node:SetActive(myDefendList[i] ~= nil or enemyDefendList[i] ~= nil)
        this.RankNodeAdapter(this.rankNode[i][1], myDefendList[i], i * 2 - 1)
        this.RankNodeAdapter(this.rankNode[i][2], enemyDefendList[i], i * 2)
    end
end
function this.RankNodeAdapter(node, data, index)
    if not data then
        node:SetActive(false)
        return
    end
    node:SetActive(true)
    local headRoot = Util.GetGameObject(node, "head")
    local nameText = Util.GetGameObject(node, "name"):GetComponent("Text")
    local powerText = Util.GetGameObject(node, "power"):GetComponent("Text")

    local memData = data.userInfo
    nameText.text = memData.userName
    powerText.text = memData.soulForce

    if not _PlayerHeadList[index] then
        _PlayerHeadList[index] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headRoot.transform)
    end
    _PlayerHeadList[index]:Reset()
    _PlayerHeadList[index]:SetScale(Vector3.one * 0.6)
    _PlayerHeadList[index]:SetHead(memData.head)
    _PlayerHeadList[index]:SetFrame(memData.frame)
    --_PlayerHeadList[index]:SetLevel(memData.level)

end


-- 计时显示
function this._TimeUpdate()
    local guildFightData = GuildFightManager.GetGuildFightData()
    local curTime = GetTimeStamp()
    local roundEndTime = guildFightData.roundEndTime
    local leftTime = roundEndTime - curTime
    leftTime = leftTime < 0 and 0 or leftTime
    this.time.text = TimeToHMS(leftTime)
end
--界面关闭时调用（用于子类重写）
function GuildFightAttackTipPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildFightAttackTipPopup:OnDestroy()
    -- 计时器销毁
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    _BuffNodeList = {}
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}
end

return GuildFightAttackTipPopup