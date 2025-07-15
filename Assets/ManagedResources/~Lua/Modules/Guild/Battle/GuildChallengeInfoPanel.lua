require("Base/BasePanel")
local GuildChallengeInfoPanel = Inherit(BasePanel)
local this = GuildChallengeInfoPanel
local guildWarConfig = ConfigManager.GetConfig(ConfigName.GuildWarConfig)
local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local formationConfig = ConfigManager.GetConfig(ConfigName.FormationConfig)
local guildWarSetting = ConfigManager.GetConfig(ConfigName.GuildWarSetting)
local TabBox = require("Modules/Common/TabBox")
local tabs = {
    [1] = {
        default = "cn2-x1_haoyou_biaoqian_weixuanzhong",
        select = "cn2-x1_haoyou_biaoqian_xuanzhong",
        name = GetLanguageStrById(11033),--个人排行
        rpType = -1,
    },
    [2] = {
        default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou",
        select = "cn2-x1_haoyou_biaoqian_xuanzhong",
        name = GetLanguageStrById(11032),--公会排行
        rpType = -1,
    },
    [3] = {
        default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou",
        select = "cn2-x1_haoyou_biaoqian_xuanzhong",
        name = GetLanguageStrById(50252),--本会排行
        rpType = -1,
    },
}
local curIndex = 1
local curData = {}
local inBattle = false
function this:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.tabbox = Util.GetGameObject(this.gameObject, "rank")
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    this.name = Util.GetGameObject(this.gameObject, "Image/name"):GetComponent("Text")
    this.subjection = Util.GetGameObject(this.gameObject, "content/name"):GetComponent("Text")
    this.btnChallenge = Util.GetGameObject(this.gameObject, "rank/btnChallenge")
    this.scroll = Util.GetGameObject(this.gameObject, "rank/scroll")
    this.pre = Util.GetGameObject(this.gameObject, "rank/scroll/pre")
    local w = this.scroll.transform.rect.width
    local h = this.scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform, this.pre, nil,
        Vector2.New(w, h), 1, 1, Vector2.New(0, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    local formation = Util.GetGameObject(this.gameObject, "content/formation/grid")
    this.heroPreList = {}
    for i = 1, 9 do
        if not this.heroPreList[i] then
            local parent = Util.GetGameObject(formation, "pos"..i)
            this.heroPreList[i] = SubUIManager.Open(SubUIConfig.ItemView, parent.transform)
        end
    end
end

function this:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)

    Util.AddOnceClick(this.btnChallenge, function ()
        if GuildBattleManager.challengeCount >= guildWarSetting[1].Section+GuildBattleManager.buyCount then
            PopupTipPanel.ShowTip(GetLanguageStrById(11048))--挑战次数不足！
            return
        elseif GuildBattleManager.allowChallange == 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(50255))--活动期间加入/创建的公会，无法参与本次活动！
            return
        elseif GuildBattleManager.guildBattleState == 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(10029))--活动已结束！
            return
        end

        if BattleManager.IsInBackBattle() then
            return
        end
        if inBattle then
            return
        end
        inBattle = true
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_DEATHPOS, curData.pathId, 
        GetLanguageStrById(guildWarConfig[curData.pathId].Name), monsterGroup[guildWarConfig[curIndex].MonsterId].Formation)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

-- 打开时调用
function this:OnOpen(index, data)
    curIndex = index and index or 1
    curData = data
    this.PageTabCtrl:Init(this.tabbox, tabs, curIndex)
end

--界面打开时调用（用于子类重写）
function this:OnShow()
    this.PageTabCtrl:ChangeTab(curIndex)
    this.ShowGuard()
    this.SetRank()
    inBattle = false
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    inBattle = false
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

-- tab按钮自定义显示设置
function this.PageTabAdapter(tab, index, status)
    tab:GetComponent("Image").sprite = Util.LoadSprite(tabs[index][status])
    Util.GetGameObject(tab, "Text"):GetComponent("Text").text = tabs[index].name
    if status == "default" then
        Util.GetGameObject(tab, "Text"):GetComponent("Text").color = UIColor.GRAY
    else
        Util.GetGameObject(tab, "Text"):GetComponent("Text").color = UIColor.WHITE
    end
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    return false
end

-- tab改变事件
function this.OnPageTabChange(index)
    curIndex = index
    this.SetRank()
end

function this.ShowGuard()
    this.name.text = GetLanguageStrById(guildWarConfig[curData.pathId].Name)
    if curData.guildName == "" then
        this.subjection.text = GetLanguageStrById(50251)--"无归属"
    else
        this.subjection.text = curData.guildName
    end

    for i = 1, #this.heroPreList do
        this.heroPreList[i].gameObject:SetActive(false)
    end
    local monsterGroupId = guildWarConfig[curData.pathId].MonsterId
    local posArray = formationConfig[monsterGroup[monsterGroupId].Formation].pos
    for i, v in pairs(monsterGroup[monsterGroupId].Contents[1]) do
        local hero = this.heroPreList[posArray[i]]
        if v ~= 0 then
            hero:OnOpen(false, {monsterConfig[v].MonsterId, 1}, 0.9)
            hero:SetCorner(6, true, {lv = monsterConfig[v].Level, star = monsterConfig[v].Star})
            hero.gameObject:SetActive(true)
        end
    end
end

function this.SetRank()
    GuildBattleManager.GetCurrentDamageRankRequest(curData.pathId, curIndex, function (msg)
        this.scrollView:SetData(msg.rankInfo, function(i, go)
            this.SetScrollPre(go, msg.rankInfo[i])
        end)
    end)
end

local rankImg = {
    "cn2-X1_tongyong_diyi",
    "cn2-X1_tongyong_dier",
    "cn2-X1_tongyong_disan"
}
function this.SetScrollPre(go, data)
    go:SetActive(true)
    local rank1 = Util.GetGameObject(go, "rank/rank1"):GetComponent("Image")
    local rank2Obj = Util.GetGameObject(go, "rank/rank2")
    local rank2 = Util.GetGameObject(go, "rank/rank2/Text"):GetComponent("Text")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local hurt = Util.GetGameObject(go, "hurt"):GetComponent("Text")

    if GuildBattleManager.guildType == 1 and curIndex ~= 3 then
        name.text = string.format("[%s]%s", data.serverName, data.username)
    else
        name.text = data.username
    end
    hurt.text = PrintWanNum4(data.score)
    rank1.gameObject:SetActive(data.rank <= 3)
    rank2Obj.gameObject:SetActive(data.rank > 3)
    if data.rank <= 3 then
        rank1.sprite = Util.LoadSprite(rankImg[data.rank])
    else
        rank2.text = data.rank
    end

    if data.userId == PlayerManager.uid or data.userId == PlayerManager.familyId then
        name.fontStyle = UITextFontStyle.BOLD
        hurt.fontStyle = UITextFontStyle.BOLD
    else
        name.fontStyle = UITextFontStyle.NORMAL
        hurt.fontStyle = UITextFontStyle.NORMAL
    end
end

return this