require("Base/BasePanel")
local GuildFightDefendInfoPopup = Inherit(BasePanel)
local this = GuildFightDefendInfoPopup
-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(168 / 255, 168 / 255, 167 / 255, 1),
                        select = Color.New(250 / 255, 227 / 255, 175 / 255, 1) }
local _TabSprite = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001"}
local _TabData = {
    [1] = { type = GUILD_BUILD_TYPE.HOUSE, name = GetLanguageStrById(10863), starSettingIndex = 1},
    [2] = { type = GUILD_BUILD_TYPE.STORE, name = GetLanguageStrById(10081), starSettingIndex = 3},
    [3] = { type = GUILD_BUILD_TYPE.LOGO, name = GetLanguageStrById(10864), starSettingIndex = 2},
}

-- 头像管理
local _PlayerHeadList = {}
-- 星星管理
local _StarList = {}

--初始化组件（用于子类重写）
function GuildFightDefendInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.tabbox = Util.GetGameObject(self.transform, "top")

    this.starBox = Util.GetGameObject(self.transform, "content/defend/allStar/box")
    this.star = Util.GetGameObject(self.transform, "content/defend/allStar/box/star")

    this.buffList = Util.GetGameObject(self.transform, "content/defend/bufflist")
    this.buffTip = Util.GetGameObject(self.transform, "content/defend/buffTip")

    this.btnDefend = Util.GetGameObject(self.transform, "content/defend/btnbg/btnDefend")
    this.btnDefendStr = Util.GetGameObject(this.btnDefend, "Text"):GetComponent("Text")

    this.scrollRoot = Util.GetGameObject(self.transform, "content/defend/scrollpos")
    this.scrollItem = Util.GetGameObject(this.scrollRoot, "mem")
    this.empty = Util.GetGameObject(this.scrollRoot, "empty")

    this.timePanel = Util.GetGameObject(self.transform, "content/defend/time")
    this.timeText = Util.GetGameObject(self.transform, "content/defend/time/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function GuildFightDefendInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    Util.AddClick(this.btnDefend, function()
        -- 判断编队是否是空的
        local formation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND)
        if #formation.teamHeroInfos == 0 then
            FormationManager.RefreshFormationData(function()
                UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.GUILD_DEFEND, "EDIT")
            end)
            return
        end
        --
        --if this._MyIndex then
            UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.GUILD_DEFEND, "EDIT")
        --else
        --    UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.GUILD_DEFEND, "DEFEND", this._CurBuildType)
        --end
    end)

    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
end

--添加事件监听（用于子类重写）
function GuildFightDefendInfoPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.DefendDataUpdate, this.RefreshDefendListShow)
end

--移除事件监听（用于子类重写）
function GuildFightDefendInfoPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.DefendDataUpdate, this.RefreshDefendListShow)
end

--界面打开时调用（用于子类重写）
function GuildFightDefendInfoPopup:OnOpen(isShowTime)

    this.isShowTime = isShowTime
    if isShowTime then
        this.timePanel:SetActive(true)
        this.scrollRoot.transform.sizeDelta = Vector2.New(910, 826)

        this._TimeUpdate()
        if not this.timer then
            this.timer = Timer.New(this._TimeUpdate, 1, -1, true)
            this.timer:Start()
        end
    else
        this.timePanel:SetActive(false)
        this.scrollRoot.transform.sizeDelta = Vector2.New(910, 878)
    end


    if this.TabCtrl then
        this.TabCtrl:Init(this.tabbox, _TabData)
        -- 切换到我防守的建筑
        local myBuildId = GuildFightManager.GetDefendStagePlayerBuildType(PlayerManager.uid)
        if myBuildId then
            for index, data in ipairs(_TabData) do
                if data.type == myBuildId then
                    this.TabCtrl:ChangeTab(index)
                end
            end
        end
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFightDefendInfoPopup:OnShow()
    this.RefreshDefendListShow()
end

-- 计时显示
function this._TimeUpdate()
    if not this.isShowTime then return end
    local guildFightData = GuildFightManager.GetGuildFightData()
    local curTime = GetTimeStamp()
    local roundEndTime = guildFightData.roundEndTime
    local leftTime = roundEndTime - curTime
    leftTime = leftTime < 0 and 0 or leftTime
    this.timeText.text = TimeToHMS(leftTime)
end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Img"):GetComponent("Image").sprite = Util.LoadSprite(_TabSprite[status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    -- 设置显示
    this._CurIndex = index
    this._CurBuildType = _TabData[index].type

    --this.RefreshBaseShow()

    this.RefreshDefendListShow()
end

-- 刷新基础显示
function this.RefreshBaseShow()
    -- 星星
    local guildSetting = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1)
    local starSettingIndex = _TabData[this._CurIndex].starSettingIndex
    local buildStarNum = guildSetting.BuildingStar[starSettingIndex]
    local maxNum = math.max(buildStarNum, #_StarList)
    for i = 1, maxNum do
        if not _StarList[i] then
            _StarList[i] = newObjToParent(this.star, this.starBox)
        end
        _StarList[i]:SetActive(i <= buildStarNum)
    end

    -- buff
    this.buffTip:SetActive(true)
    this.buffList:SetActive(false)

end


-- 刷新列表显示
function this.RefreshDefendListShow()
    -- 创建滚动
    local height = this.isShowTime and 826 or 878
    if not this.scrollView then
        this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
                this.scrollItem, nil, Vector2.New(910, height), 1, 1, Vector2.New(0,0))
        this.scrollView.moveTween.Strength = 2
    end
    this.scrollView.rectTransform.sizeDelta = Vector2.New(910, height)

    local datalist = GuildFightManager.GetDefendStageBuildDefendData(this._CurBuildType)
    if #datalist ~= 0 then
        this.scrollView:SetData(datalist, function(index, go)
            this.DefendItemAdapter(go, datalist[index], index)
        end)
        this.empty:SetActive(false)
        this.scrollView.gameObject:SetActive(true)
    else
        this.empty:SetActive(true)
        this.scrollView.gameObject:SetActive(false)
    end

    -- 判断我是否在当前建筑中
    --this._MyIndex = nil
    --for index, data in ipairs(datalist) do
    --    if data.uid == PlayerManager.uid then
    --        this._MyIndex = index
    --        break
    --    end
    --end

    -- 如果我在当前建筑
    --if this._MyIndex then
    --    this.btnDefendStr.text = "编辑队伍"
    --    if this._MyIndex > 4 then
    --        this.scrollView:SetIndex(this._MyIndex)
    --    end
    --else
    --    this.btnDefendStr.text = "上阵队伍"
    --end

end

-- 防守数据节点数据匹配
function this.DefendItemAdapter(item, data, index)
    local bg = Util.GetGameObject(item, "bg")
    local selfbg = Util.GetGameObject(item, "selfbg")
    local headpos = Util.GetGameObject(item, "head")
    local nameText = Util.GetGameObject(item, "name"):GetComponent("Text")
    local powerText = Util.GetGameObject(item, "power"):GetComponent("Text")
    local professText = Util.GetGameObject(item, "pos"):GetComponent("Text")
    local numText = Util.GetGameObject(item, "num"):GetComponent("Text")
    local rankBg = Util.GetGameObject(item, "rankbg")
    local rankLab = Util.GetGameObject(rankBg, "rank")

    -- 排名
    if index > 0 and index <= 3 then
        rankBg:GetComponent("Image").sprite = Util.LoadSprite("r_playerrumble_paiming_0"..index)
        rankBg:GetComponent("Image"):SetNativeSize()
        rankLab:SetActive(false)
    else
        rankBg:GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        rankBg:GetComponent("RectTransform").sizeDelta = Vector2.New(120, 120)
        rankLab:GetComponent("Text").text = index
        rankLab:SetActive(true)
    end

    local memData = MyGuildManager.GetMemInfo(data.uid)
    nameText.text = memData.userName
    professText.text = GUILD_GRANT_STR[memData.position]
    powerText.text = data.curForce
    
    numText.text = data.starCount
    -- 自己要特殊显示
    selfbg:SetActive(data.uid == PlayerManager.uid)

    -- 头像
    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetScale(Vector3.one * 0.6)
    _PlayerHeadList[item]:SetHead(memData.head)
    _PlayerHeadList[item]:SetFrame(memData.frame)

    -- 添加点击事件
    Util.AddOnceClick(bg, function()
        UIManager.OpenPanel(UIName.GuildMemberInfoPopup, GUILD_MEM_POPUP_TYPE.DEFEND, data.uid, data.starCount)
    end)
end

--界面关闭时调用（用于子类重写）
function GuildFightDefendInfoPopup:OnClose()
    --if this.scrollView then
    --    GameObject.Destroy(this.scrollView.gameObject)
    --    this.scrollView = nil
    --end
end

--界面销毁时调用（用于子类重写）
function GuildFightDefendInfoPopup:OnDestroy()
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    this.scrollView = nil
    -- 星星
    _StarList = {}

    -- 计时器销毁
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

return GuildFightDefendInfoPopup