require("Base/BasePanel")
local GuildBattleRankPanel = Inherit(BasePanel)
local this = GuildBattleRankPanel

local TabBox = require("Modules/Common/TabBox")
local tabs = {
    [1] = {
        default = "cn2-x1_haoyou_biaoqian_weixuanzhong",
        select = "cn2-x1_haoyou_biaoqian_xuanzhong",
        name = GetLanguageStrById(11033),
        rpType = -1,
    },
    [2] = {
        default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou",
        select = "cn2-x1_haoyou_biaoqian_xuanzhong",
        name = GetLanguageStrById(11032),
        rpType = -1,
    },
}
local rankImg = {
    {"cn2-X1_tongyong_liebiao_02", "cn2-X1_tongyong_diyi",},
    {"cn2-X1_tongyong_liebiao_03", "cn2-X1_tongyong_dier",},
    {"cn2-X1_tongyong_liebiao_04", "cn2-X1_tongyong_disan"},
}
local curIndex = 1 --1 个人 2 公会
local calculaUnit=10000 --总伤害再处理单位
function this:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.tabbox = Util.GetGameObject(this.gameObject, "Panel/btnList")
    this.PageTabCtrl = TabBox.New()
    this.PageTabCtrl:SetTabAdapter(this.PageTabAdapter)
    this.PageTabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.PageTabCtrl:SetChangeTabCallBack(this.OnPageTabChange)

    this.scroll = Util.GetGameObject(this.gameObject, "Panel/scroll")
    --个人
    this.personalPrefab = Util.GetGameObject(this.gameObject, "Panel/scroll/personal")
    this.personalScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.personalPrefab, nil, Vector2.New(this.scroll.transform.rect.width, this.scroll.transform.rect.height), 1, 1, Vector2.New(0, 5))
    this.personalScrollView.moveTween.MomentumAmount = 1
    this.personalScrollView.moveTween.Strength = 2
    --公会
    this.guildPrefab = Util.GetGameObject(this.gameObject, "Panel/scroll/guild")
    this.guildScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.guildPrefab, nil, Vector2.New(this.scroll.transform.rect.width, this.scroll.transform.rect.height), 1, 1, Vector2.New(0, 5))
    this.guildScrollView.moveTween.MomentumAmount = 1
    this.guildScrollView.moveTween.Strength = 2

    this.myRank = Util.GetGameObject(this.gameObject, "Panel/myRank")
end

function this:BindEvent()
    Util.AddClick(this.btnBack, function()
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
function this:OnOpen(index)
    curIndex = index and index or 1
    this.PageTabCtrl:Init(this.tabbox, tabs, curIndex)
end

--界面打开时调用（用于子类重写）
function this:OnShow()
    this.PageTabCtrl:ChangeTab(curIndex)
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
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
        Util.GetGameObject(tab, "Text"):GetComponent("UnityEngine.UI.Outline").enabled = false
    else
        Util.GetGameObject(tab, "Text"):GetComponent("Text").color = UIColor.WHITE
        Util.GetGameObject(tab, "Text"):GetComponent("UnityEngine.UI.Outline").enabled = true
    end
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    return false
end

-- tab改变事件
function this.OnPageTabChange(index)
    curIndex = index
    this.personalScrollView.gameObject:SetActive(curIndex == 1)
    this.guildScrollView.gameObject:SetActive(curIndex == 2)
    if curIndex == 1 then
        GuildBattleManager.GetTotalDamageRankRequest(function ()
            local allData = GuildBattleManager.allHurtRank
            local myData
            for i = 1, #allData do
                if allData[i].userId == PlayerManager.uid then
                    myData = allData[i]
                end
            end
            if myData then
                this.mySeverId = myData.serverId
            end
            this.SetMyRank(myData)
            this.personalScrollView:SetData(allData, function (index, go)
                this.SetPersonalRank(go, allData[index])
            end)
        end)
    elseif curIndex == 2 then
        NetManager.DeathPathCurGuildCountRankRequest(function (msg)
            local allData = msg.rankInfo
            local myData
            for i = 1, #allData do
                local guildData = MyGuildManager.GetMyGuildInfo()
                if allData[i].guildId == guildData.id then
                    myData = allData[i]
                end
            end
            if myData then
                this.mySeverId = myData.serverId
            end
            this.SetMyRank(myData)
            this.guildScrollView:SetData(allData, function (index, go)
                this.SetGuildRank(go, allData[index])
            end)
        end)
    end
end

function this.SetPersonalRank(go, data)
    go:SetActive(true)
    local head = Util.GetGameObject(go, "head")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local score = Util.GetGameObject(go, "score"):GetComponent("Text")
    local rank1 = Util.GetGameObject(go, "rank/rank1"):GetComponent("Image")
    local rank2 = Util.GetGameObject(go, "rank/rank2"):GetComponent("Text")

    rank1.gameObject:SetActive(data.rank <= 3)
    rank2.text = ""
    if data.rank <= 3 then
        go:GetComponent("Image").sprite = Util.LoadSprite(rankImg[data.rank][1])
        rank1.sprite = Util.LoadSprite(rankImg[data.rank][2])
    else
        go:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_liebiao_05")
        rank2.text = data.rank
    end

    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[go] then
        this.playerHead[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    this.playerHead[go]:Reset()
    this.playerHead[go]:SetScale(0.7)
    this.playerHead[go]:SetHead(data.head)
    this.playerHead[go]:SetFrame(data.headFrame)
    this.playerHead[go]:SetUID(data.userId)
    this.playerHead[go]:SetSeverID(data.serverId)
    if GuildBattleManager.guildType == 1 then
        this.playerHead[go]:SetClickedTypeId(PlayerInfoType.CSGuildBattle)
    end

    if GuildBattleManager.guildType == 1 then
        name.text = string.format("[%s]%s", data.serverName, data.username)
    else
        name.text = data.username
    end
    score.text = string.format("%.2f", (data.score/calculaUnit)) .. GetLanguageStrById(10042)
end

function this.SetGuildRank(go, data)
    go:SetActive(true)
    -- local head = Util.GetGameObject(go, "head")
    local guildName = Util.GetGameObject(go, "guildName"):GetComponent("Text")
    local playerName = Util.GetGameObject(go, "playerName/Text"):GetComponent("Text")
    local hurt = Util.GetGameObject(go, "hurt/Text"):GetComponent("Text")
    local score = Util.GetGameObject(go, "score"):GetComponent("Text")
    local rank1 = Util.GetGameObject(go, "rank/rank1"):GetComponent("Image")
    local rank2 = Util.GetGameObject(go, "rank/rank2"):GetComponent("Text")

    rank1.gameObject:SetActive(data.rank <= 3)
    rank2.text = ""
    if data.rank <= 3 then
        go:GetComponent("Image").sprite = Util.LoadSprite(rankImg[data.rank][1])
        rank1.sprite = Util.LoadSprite(rankImg[data.rank][2])
    else
        go:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_liebiao_05")
        rank2.text = data.rank
    end

    if GuildBattleManager.guildType == 1 then
        guildName.text = string.format("[%s]%s", data.serverName, data.guildName)
    else
        guildName.text = data.guildName
    end
    playerName.text = data.chairmanName
    hurt.text = string.format("%.2f", (data.score/calculaUnit)) .. GetLanguageStrById(10042)
    score.text = data.count
end

function this.SetMyRank(data)
    Util.GetGameObject(this.myRank, "personal"):SetActive(curIndex == 1)
    Util.GetGameObject(this.myRank, "guild"):SetActive(curIndex == 2)
    if curIndex == 1 then
        local head = Util.GetGameObject(this.myRank, "personal/head")
        local name = Util.GetGameObject(this.myRank, "personal/name"):GetComponent("Text")
        local score = Util.GetGameObject(this.myRank, "personal/score"):GetComponent("Text")
        local rank1 = Util.GetGameObject(this.myRank, "personal/rank/rank1"):GetComponent("Image")
        local rank2 = Util.GetGameObject(this.myRank, "personal/rank/rank2"):GetComponent("Text")

        if data then
            rank1.gameObject:SetActive(data.rank <= 3)
            rank2.text = ""
            if data.rank <= 3 then
                rank1.sprite = Util.LoadSprite(rankImg[data.rank][2])
            else
                rank2.text = data.rank
            end
            score.text =  string.format("%.2f", (data.score/calculaUnit)) .. GetLanguageStrById(10042)
        else
            rank1.gameObject:SetActive(false)
            rank2.text = GetLanguageStrById(91000072)
            score.text = "0.00" .. GetLanguageStrById(10042)
        end
        name.text = PlayerManager.nickName

        if not this.playerHead then
            this.playerHead = {}
        end
        if not this.playerHead[head] then
            this.playerHead[head] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
        end
        this.playerHead[head]:Reset()
        this.playerHead[head]:SetScale(0.7)
        this.playerHead[head]:SetHead(PlayerManager.head)
        this.playerHead[head]:SetFrame(PlayerManager.headFrame)
        this.playerHead[head]:SetUID(PlayerManager.uid)
    elseif curIndex == 2 then
        local head = Util.GetGameObject(this.myRank, "guild/head")
        local guildName = Util.GetGameObject(this.myRank, "guild/guildName"):GetComponent("Text")
        local playerName = Util.GetGameObject(this.myRank, "guild/playerName/Text"):GetComponent("Text")
        local hurt = Util.GetGameObject(this.myRank, "guild/hurt/Text"):GetComponent("Text")
        local score = Util.GetGameObject(this.myRank, "guild/score"):GetComponent("Text")
        local rank1 = Util.GetGameObject(this.myRank, "guild/rank/rank1"):GetComponent("Image")
        local rank2 = Util.GetGameObject(this.myRank, "guild/rank/rank2"):GetComponent("Text")

        if data then
            rank1.gameObject:SetActive(data.rank <= 3)
            rank2.text = ""
            if data.rank <= 3 then
                rank1.sprite = Util.LoadSprite(rankImg[data.rank][2])
            else
                rank2.text = data.rank
            end
            guildName.text = data.guildName
            playerName.text = data.chairmanName
            hurt.text = string.format("%.2f", (data.score/calculaUnit)) .. GetLanguageStrById(10042)
            score.text = data.count
        else
            rank1.gameObject:SetActive(false)
            rank2.text = GetLanguageStrById(91000072)
            local guildData = MyGuildManager.GetMyGuildInfo()
            local masterInfo = MyGuildManager.GetMyGuildMasterInfo()
            guildName.text = guildData.name
            playerName.text = GetLanguageStrById(masterInfo.userName)
            hurt.text = "0.00"..GetLanguageStrById(10042)
            score.text = 0
        end

        if not this.playerHead then
            this.playerHead = {}
        end
        if not this.playerHead[head] then
            this.playerHead[head] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
        end
        this.playerHead[head]:Reset()
        this.playerHead[head]:SetScale(0.7)
        this.playerHead[head]:SetHead(PlayerManager.head)
        this.playerHead[head]:SetFrame(PlayerManager.headFrame)
        this.playerHead[head]:SetUID(PlayerManager.uid)
    end
end

return this