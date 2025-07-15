require("Base/BasePanel")
local GuildBossLogPanel = Inherit(BasePanel)
local this = GuildBossLogPanel

local _PlayerHeadList = {}

function this:InitComponent()
    this.btnBack = Util.GetGameObject(this.transform, "btnBack")
    -- this.title = Util.GetGameObject(this.transform, "Title")
    this.empty = Util.GetGameObject(this.transform, "content/rank/empty")

    this.rankScrollRoot = Util.GetGameObject(this.transform, "content/rank/scrollpos")
    this.rankItem = Util.GetGameObject(this.transform, "content/rank/scrollpos/mem")
end

function this:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

end

-- 打开时调用
function this:OnOpen()
    GuildBossManager.RequestGuildBossAttackLog(this.RefreshShow)
end

function this.RefreshShow()
    local dataList = GuildBossManager.GetBossAttackLog()
    if not dataList then return end

    -- 创建滚动
    if not this.rankScroll then
        local height = this.rankScrollRoot.transform.rect.height
        local width = this.rankScrollRoot.transform.rect.width
        this.rankScroll = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rankScrollRoot.transform,
                this.rankItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
        this.rankScroll.moveTween.Strength = 2
    end

    this.rankScroll:SetData(dataList, function(index, go)
        this.RankItemAdapter(go, dataList[index], index)
    end)
    this.rankScroll:SetIndex(1)
    this.empty:SetActive(#dataList == 0)



end

-- 排名节点数据匹配
function this.RankItemAdapter(node, data, index)
    local rank = Util.GetGameObject(node, "rank"):GetComponent("Image")
    local btnRecord = Util.GetGameObject(node, "record")
    local rankNum = Util.GetGameObject(node, "rank/num"):GetComponent("Text")
    local head = Util.GetGameObject(node, "head")
    local name = Util.GetGameObject(node, "name"):GetComponent("Text")
    local damage = Util.GetGameObject(node, "num"):GetComponent("Text")


    --排名
    if index <= 3 then
        rank.sprite = Util.LoadSprite("r_playerrumble_paiming_0"..index)
        rank:SetNativeSize()
        rankNum.gameObject:SetActive(false)
    else
        rank.sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        rank.transform.sizeDelta = Vector2.New(120, 120)
        rankNum.gameObject:SetActive(true)
    end

    rankNum:GetComponent("Text").text = index
    name:GetComponent("Text").text = data.userName
    damage:GetComponent("Text").text = data.rankInfo.param1

    -- 头像
    if not _PlayerHeadList[node] then
        _PlayerHeadList[node] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    _PlayerHeadList[node]:Reset()
    _PlayerHeadList[node]:SetScale(Vector3.one * 0.6)
    _PlayerHeadList[node]:SetHead(data.head)
    _PlayerHeadList[node]:SetFrame(data.headFrame)
    _PlayerHeadList[node]:SetLevel(data.level)

    -- 查看记录
    Util.AddOnceClick(btnRecord, function()
        GuildBossManager.RequestRecordData(data.uid, function(fightData)
            local _fightData = BattleManager.GetBattleServerData({fightData = fightData})
            BattleRecordManager.SetBattleRecord(_fightData)
            UIManager.OpenPanel(UIName.DamageResultPanel, 1)
        end)
    end)
end

-- 销毁时调用
function this:OnDestroy()
    
    -- 滚动置空
    this.rankScroll = nil
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}
end

return this