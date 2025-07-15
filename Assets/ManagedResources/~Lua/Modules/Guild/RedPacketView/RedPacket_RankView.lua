----- 公会红包-抢红包排行榜 -----
local this = {}
this.firstHead=nil --第一名玩家头像
this.playerScrollHead={}--玩家头像组
this.firstHead={}--第一名头像组
local uidList={}--临时存储uid列表
local guildSetting=ConfigManager.GetConfigData(ConfigName.GuildSetting,1)
local sortingOrder=0

local rankPreBg = {
    { bg = "cn2-X1_tongyong_liebiao_02" , color = Color.New(255/255,198/255,40/255,255/255)},
    { bg = "cn2-X1_tongyong_liebiao_03" , color = Color.New(255/255,169/255,92/255,255/255)},
    { bg = "cn2-X1_tongyong_liebiao_04" , color = Color.New(255/255,156/255,148/255,255/255)},
    { bg = "cn2-X1_tongyong_liebiao_05" , color = Color.New(199/255,141/255,254/255,255/255)},
}

function this:InitComponent(gameObject)
    this.firstPre = Util.GetGameObject(gameObject,"FirstPre")
    this.firstPlayerHead = Util.GetGameObject(this.firstPre,"PlayerHead")--第一名玩家头像
    this.firstPlayerName = Util.GetGameObject(this.firstPre,"PlayerName"):GetComponent("Text")--第一名玩家名
    this.detailBtn = Util.GetGameObject(this.firstPre,"DetailBtn")--查看详情按钮

    this.scrollRoot = Util.GetGameObject(gameObject,"ScrollRoot")--滚动条根节点
    this.rankPre = Util.GetGameObject(gameObject,"RankPre")--排名预设
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,this.rankPre, nil,
    Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),1,1,Vector2.New(0,10))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.noRank=Util.GetGameObject(gameObject,"NoRank")--无排名信息提示
end

function this:BindEvent()

end

function this:AddListener()

end

function this:RemoveListener()

end

function this:OnShow(_sortingOrder)
    -- logWarnTrance("打开发红包排行榜")
    sortingOrder = _sortingOrder
    this:InitRankView()
end

function this:OnClose()
    -- logWarnTrance("关闭发红包排行榜")
end

function this:OnDestroy()
    this.scrollView = nil
end

--初始化排名面板
function this:InitRankView()
    --先请求已点赞信息 好赋值进排行信息
    NetManager.GetAllSendLikeResponse(function(msg)
        -- for k,v in ipairs(msg.uid) do
        
        -- end
        uidList={}
        for k,v in ipairs(msg.uid) do
            table.insert(uidList, v)
        end
    end)

    --请求排行信息
    NetManager.RequestRankInfo(RANK_TYPE.GUILD_REDPACKET, function (msg)
        this.firstPlayerHead:SetActive(#msg.ranks > 0)
        this.detailBtn:SetActive(#msg.ranks > 0)
        this.noRank:SetActive(#msg.ranks == 0)
        if #msg.ranks == 0 then this.firstPlayerName.text = GetLanguageStrById(11073) end

        this.scrollView:SetData(msg.ranks,function(index, root)
            this:SetShow(root, msg.ranks[index],msg.myRankInfo.rank)
            -- if index > 1 then return end
            -- this:SetFirstShow(msg.ranks[index])
        end)
    end)
end

-- --设置第一数据
-- function this:SetFirstShow(data)
--     if not this.firstHead[this.firstPre] then this.firstHead[this.firstPre] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD, this.firstPlayerHead) end
--     this.firstHead[this.firstPre]:Reset()
--     this.firstHead[this.firstPre]:SetHead(data.head)
--     this.firstHead[this.firstPre]:SetFrame(data.headFrame)
--     this.firstHead[this.firstPre]:SetLevel(data.level)
--     this.firstHead[this.firstPre]:SetScale(Vector3.one *0.9)

--     this.firstPlayerName.text = data.userName
--      --查看详情按钮
--      Util.AddClick(this.detailBtn,function()
--          UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
--      end)
-- end

--设置每条数据
function this:SetShow(root,data,mydata)
    root:SetActive(true)
    --local selfBg = Util.GetGameObject(root,"SelfBG"):GetComponent("Image")
    local rankImage = Util.GetGameObject(root,"RankImage"):GetComponent("Image")
    local rankText = Util.GetGameObject(root, "RankText"):GetComponent("Text")
    local playerHead = Util.GetGameObject(root,"PlayerHead")
    local playerName = Util.GetGameObject(root,"PlayerName"):GetComponent("Text")
    local btn = Util.GetGameObject(root,"Like")

    --selfBg.enabled = data.rankInfo.rank==mydata

    local bg = Util.GetGameObject(root,"Bg"):GetComponent("Image")
    bg.sprite = Util.LoadSprite(rankPreBg[data.rankInfo.rank].bg)
    local color = Util.GetGameObject(root,"Bg/color"):GetComponent("Image")
    color.color = rankPreBg[data.rankInfo.rank].color

    rankImage.sprite = SetRankNumFrame(data.rankInfo.rank)
    rankText.text = data.rankInfo.rank > 3 and data.rankInfo.rank or ""
    if not this.playerScrollHead[root] then
        this.playerScrollHead[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD, playerHead)
    end
    this.playerScrollHead[root]:Reset()
    this.playerScrollHead[root]:SetHead(data.head)
    this.playerScrollHead[root]:SetFrame(data.headFrame)
    this.playerScrollHead[root]:SetLevel(data.level)
    this.playerScrollHead[root]:SetScale(Vector3.one * 0.55)
    playerName.text = data.userName

    btn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jingjichang_dianzan"))
    for k, v in pairs(uidList) do
        btn:GetComponent("Button").interactable = data.uid ~= v
        if data.uid == v then
            -- Util.SetGray(btn,true)
            btn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jingjichang_yizan"))
            break
        end
    end
    --点赞
    Util.GetGameObject(btn,"Num"):GetComponent("Text").text = data.likeNum
    Util.AddOnceClick(btn,function()
        NetManager.GetRedPackageLikeRequest(data.uid,function(msg)
            btn:GetComponent("Button").interactable = false
            btn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jingjichang_yizan"))
            Util.GetGameObject(btn,"Num"):GetComponent("Text").text = data.likeNum+1
            PopupTipPanel.ShowTip(string.format( GetLanguageStrById(11074),guildSetting.GiveLikeReward[2]))
            -- Util.SetGray(btn,true)
        end)
    end)
end

return this