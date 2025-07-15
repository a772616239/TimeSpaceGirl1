require("Base/BasePanel")
local GuildFightAttackInfoPopup = Inherit(BasePanel)
local this = GuildFightAttackInfoPopup

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
local _StarList = {}

--初始化组件（用于子类重写）
function GuildFightAttackInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.tabbox = Util.GetGameObject(self.transform, "top")

    this.starBox = Util.GetGameObject(self.transform, "content/defend/allStar/box")
    this.star = Util.GetGameObject(self.transform, "content/defend/allStar/box/star")
    this.starTitle = Util.GetGameObject(self.transform, "content/defend/allStar/title"):GetComponent("Text")
    this.starTip = Util.GetGameObject(self.transform, "content/defend/allStar/tip"):GetComponent("Text")

    this.buffTitle = Util.GetGameObject(self.transform, "content/defend/tip_1/Text"):GetComponent("Text")
    this.buffList = Util.GetGameObject(self.transform, "content/defend/bufflist")
    this.buffTip = Util.GetGameObject(self.transform, "content/defend/buffTip")
    this.buffNodeList = {}
    for i = 1, 4 do
        this.buffNodeList[i] = Util.GetGameObject(this.buffList, "buff_"..i)
    end

    Util.GetGameObject(self.transform, "content/defend/btnDefend"):SetActive(false)

    this.scrollRoot = Util.GetGameObject(self.transform, "content/defend/scrollpos")
    this.scrollItem = Util.GetGameObject(this.scrollRoot, "mem")
    this.empty = Util.GetGameObject(this.scrollRoot, "empty")

end

--绑定事件（用于子类重写）
function GuildFightAttackInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
end

--添加事件监听（用于子类重写）
function GuildFightAttackInfoPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildFightAttackInfoPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildFightAttackInfoPopup:OnOpen(guildType)
    this._GuildType = guildType
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFightAttackInfoPopup:OnShow()
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(this._CurIndex or 1)
    end
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

    this.RefreshBaseShow()

    this.RefreshAttackListShow()
end

-- 刷新基础显示
function this.RefreshBaseShow()
    -- 文本
    local buildStr = _TabData[this._CurIndex].name
    this.starTitle.text = string.format(GetLanguageStrById(10865), buildStr)
    this.starTip.text = string.format(GetLanguageStrById(10866), buildStr)
    this.buffTitle.text = string.format(GetLanguageStrById(10867), buildStr)
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
    --TODO:buff详情展示
    if not this._GuildType then return end
    local propList = GuildFightManager.GetAttackStageBuildBuffData(this._GuildType, this._CurBuildType)
    if not propList then

        return
    end
    this.buffTip:SetActive(false)
    this.buffList:SetActive(true)
    for i, node in ipairs(this.buffNodeList) do
        local prop = propList[i]
        if prop then
            local propInfo = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.id)
            if propInfo then
                node:SetActive(true)
                -- 显示内容
                local val = prop.value
                local express1 = val >= 0 and "+" or ""
                local express2 = ""
                if propInfo.Style == 2 then
                    val = val / 100
                    express2 = "%"
                end
                Util.GetGameObject(node, "Text"):GetComponent("Text").text = propInfo.Info .. express1..val..express2
                local lastStr = ""
                if propInfo.IfBuffShow == 1 then
                    lastStr = prop.value >= 0 and "_Up" or "_Down"
                end
                node:GetComponent("Image").sprite = Util.LoadSprite(propInfo.BuffShow .. lastStr)
            else

                node:SetActive(false)
            end
        else
            node:SetActive(false)
        end
    end
end


-- 刷新列表显示
function this.RefreshAttackListShow()
    -- 创建滚动
    if not this.scrollView then
        local height = this.scrollRoot.transform.rect.height
        local width = this.scrollRoot.transform.rect.width
        this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
                this.scrollItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
        this.scrollView.moveTween.Strength = 2
    end

    local datalist = GuildFightManager.GetAttackStageBuildDefendData(this._GuildType, this._CurBuildType)
    if #datalist ~= 0 then
        this.scrollView:SetData(datalist, function(index, go)
            this.AttackItemAdapter(go, datalist[index])
        end)
        this.empty:SetActive(false)
        this.scrollView.gameObject:SetActive(true)
    else
        this.empty:SetActive(true)
        this.scrollView.gameObject:SetActive(false)
    end

end

-- 防守数据节点数据匹配
function this.AttackItemAdapter(item, data)
    local bg = Util.GetGameObject(item, "bg")
    local headpos = Util.GetGameObject(item, "head")
    local nameText = Util.GetGameObject(item, "name"):GetComponent("Text")
    local powerText = Util.GetGameObject(item, "power"):GetComponent("Text")
    local professText = Util.GetGameObject(item, "pos"):GetComponent("Text")
    local numText = Util.GetGameObject(item, "num"):GetComponent("Text")

    local memData = data.userInfo
    nameText.text = memData.userName
    professText.text = GUILD_GRANT_STR[memData.position]
    powerText.text = memData.soulForce
    numText.text = data.starCount

    -- 头像
    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetScale(Vector3.one * 0.6)
    _PlayerHeadList[item]:SetHead(memData.head)
    _PlayerHeadList[item]:SetFrame(memData.frame)
    _PlayerHeadList[item]:SetGray(data.starCount <= 0)

    -- 添加点击事件
    Util.AddOnceClick(bg, function()
        if data.starCount <= 0 then
            PopupTipPanel.ShowTipByLanguageId(10870)
            return
        end
        local memType = nil
        if this._GuildType == GUILD_FIGHT_GUILD_TYPE.MY then
            memType = GUILD_MEM_POPUP_TYPE.ATTACK_MY_DEFEND
        elseif this._GuildType == GUILD_FIGHT_GUILD_TYPE.ENEMY then
            memType = GUILD_MEM_POPUP_TYPE.ATTACK_ENEMY_DEFEND
        end
        if not memType then return end

        UIManager.OpenPanel(UIName.GuildMemberInfoPopup, memType, memData.roleUid, data.starCount)
    end)
end

--界面关闭时调用（用于子类重写）
function GuildFightAttackInfoPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildFightAttackInfoPopup:OnDestroy()
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    this.scrollView = nil
    -- 星星
    _StarList = {}

end

return GuildFightAttackInfoPopup