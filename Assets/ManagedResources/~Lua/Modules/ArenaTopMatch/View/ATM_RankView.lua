require("Base/BasePanel")
local ATM_RankViewPanel = Inherit(BasePanel)
local this = ATM_RankViewPanel

--排名预设列表
local itemList = {}

local btnLikeList = {}

---巅峰战排名
--初始化组件（用于子类重写）
function ATM_RankViewPanel:InitComponent()
    this.itemPre = Util.GetGameObject(self.gameObject,"ItemPre")
    this.empty = Util.GetGameObject(self.gameObject,"Empty")
    this.emptyText = Util.GetGameObject(this.empty,"Text"):GetComponent("Text")
    this.panel = Util.GetGameObject(self.gameObject,"Panel")
    for i = 1,8 do
        itemList[i] = Util.GetGameObject(this.panel,"ItemPre"..i)
    end
    this.scorllRoot = Util.GetGameObject(self.gameObject,"ScorllRoot")
    this.buttonClose = Util.GetGameObject(self.gameObject,"Bg/Image/ButtonClose")
    if not this.scrollView then
        this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scorllRoot.transform,
                this.itemPre,nil, Vector2.New(this.scorllRoot.transform.rect.width, this.scorllRoot.transform.rect.height), 1,1,Vector2.New(0,5))
        this.scrollView.moveTween.MomentumAmount = 1
        this.scrollView.moveTween.Strength = 2
    end

    this.playerHead = {}--玩家头像列表
end

--绑定事件（用于子类重写）
function ATM_RankViewPanel:BindEvent()
    Util.AddClick(this.buttonClose, function()
        self:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    end)
end

--添加事件监听（用于子类重写）
function ATM_RankViewPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.ATM_RankView.OnRankChange,this.RefreshRankInfo)
end

--移除事件监听（用于子类重写）
function ATM_RankViewPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.ATM_RankView.OnRankChange, this.RefreshRankInfo)
end

--界面打开时调用（用于子类重写）
function ATM_RankViewPanel:OnOpen(...)
    this.RefreshRankInfo()
end

function ATM_RankViewPanel:OnSortingOrderChange(sortingOrder)
end

--界面关闭时调用（用于子类重写）
function ATM_RankViewPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function ATM_RankViewPanel:OnDestroy()
    this.scrollView = nil
    btnLikeList = {}
end

--刷新排名信息
function this.RefreshRankInfo()
    this.istop = true

    for i = 1, 3 do
        local root = Util.GetGameObject(this.gameObject,"data"..i)
        Util.GetGameObject(root,"domain/name/Text"):GetComponent("Text").text = GetLanguageStrById(12406)
        Util.GetGameObject(root,"domain/icon"):SetActive(false)
    end
    ArenaTopMatchManager.RequestRankData(1,function ()
        local rankData, myRankData = ArenaTopMatchManager.GetRankData()
        this.scorllRoot:SetActive(#rankData > 0)
        this.empty:SetActive(#rankData <= 0)

        for i, v in ipairs(rankData) do
            if rankData[i].rank <= 3 then
                this.SetTopThreeNodeShow(rankData[i])
            end
        end

        table.remove(rankData, 1)
        table.remove(rankData, 1)
        table.remove(rankData, 1)

        --滚动区数据
        if not this.scrollView then
            local rootHight = this.scorllRoot.transform.rect.height
            local rootWidth = this.scorllRoot.transform.rect.width
            this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scorllRoot.transform,
                    this.itemPre, Vector2.New(rootWidth, rootHight), 1, Vector2.New(0,5))
            this.scrollView.moveTween.MomentumAmount = 1
            this.scrollView.moveTween.Strength = 2
        end
        if this.istop then
            this.scrollView:SetData(rankData, function(index,root)
                this.SetNodeShow(root,rankData[index])
                --分页请求
                if index == #rankData then
                    ArenaTopMatchManager.GetNextRankData()
                    return
                end
            end, 1)
            this.istop = false
        else
            this.scrollView:SetData(rankData,function(index,root)
                this.SetNodeShow(root,rankData[index])
                --分页请求
                if index == #rankData then
                    ArenaTopMatchManager.GetNextRankData()
                    return
                end

            end)
        end
        this.CheckIsTop()

        this.LikeBtnState()
    end)

end

--刷新显示排行
function this.RefreshRankData(data,type)
    -- 虚位以待
    if type ~= ShowType.One then
        for i = 1,type - 1 do
            this.SetItemData(i)
        end
    end
    --输的玩家
    for i = type,8 do
        this.SetItemData(i,data[i])
    end
end

-- --设置排行Item数据
-- function this.SetItemData(...)
--     local args = {...}
--     local root = itemList[args[1]]
--     local head = Util.GetGameObject(root,"Head")
--     local info = Util.GetGameObject(root,"Info"):GetComponent("Image")
--     local name = Util.GetGameObject(root,"Name"):GetComponent("Text")
--     name.text = ""
--     if args[2] then
--         if not this.playerHead[root] then
--             this.playerHead[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,head)
--         end
--         this.playerHead[root]:Reset()
--         this.playerHead[root]:SetScale(Vector3.one * 0.6)
--         this.playerHead[root]:SetHead(args[2].head)
--         this.playerHead[root]:SetFrame(args[2].headFrame)
--         this.playerHead[root]:SetLevel(args[2].level)
--         info.enabled = false
--         if args[2].uid < 10000 then
--             name.text = GetLanguageStrById(tonumber(args[2].name))
--         else
--             name.text = args[2].name
--         end
--         -- name.text = args[2].name
--         Util.AddOnceClick(head,function()
--             UIManager.OpenPanel(UIName.PlayerInfoPopup, args[2].uid)
--         end)
--     else
--         if this.playerHead[root] then
--             this.playerHead[root] = nil
--         end
--         info.enabled = true
--     end
-- end

function this.SetTopThreeNodeShow(data)
    local root = Util.GetGameObject(this.gameObject,"data"..data.rank)
    local name = Util.GetGameObject(root,"domain/name/Text"):GetComponent("Text")
    local power = Util.GetGameObject(root,"power/Text"):GetComponent("Text")
    local frame = Util.GetGameObject(root,"domain/frame"):GetComponent("Image")
    local icon = Util.GetGameObject(root,"domain/icon"):GetComponent("Image")

    name.text = SetRobotName(data.uid, data.name)
    power.text = data.totalForce
    frame.sprite = GetPlayerHeadFrameSprite(data.headFrame)
    icon.gameObject:SetActive(true)
    icon.sprite = GetPlayerHeadSprite(data.head)

    Util.AddOnceClick(icon.gameObject,function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
    end)

    this.SetHeroBtnLike(root,data)
end

--设置每条节点显示
function this.SetNodeShow(root,data)
    root:SetActive(true)
    this.SetHeadInfo(root,data)
    this.SetRankingNum(root,data.rank)
    local name, power = this.InitRollingInfo(root)
    this.SetShowInfo(name,power,data)
    this.AddPlayerInfoClick(root,data.uid)
    this.SetHeroBtnLike(root,data)
end

--玩家信息弹窗
function this.AddPlayerInfoClick(root,uid)
    local bg = Util.GetGameObject(root,"clicked")
    Util.AddOnceClick(bg,function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, uid)
    end)
end

--设置名次
function this.SetRankingNum(root,rank)
    local rankText = Util.GetGameObject(root,"SortBg/Text"):GetComponent("Text")
    rankText.text = rank or ""
end

--设置头像
function this.SetHeadInfo(root,data)
    local headObj = Util.GetGameObject(root,"Head")
    if not this.playerHead[root] then
        this.playerHead[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,headObj)
    end
    this.playerHead[root]:Reset()
    this.playerHead[root]:SetScale(Vector3.one * 0.6)
    this.playerHead[root]:SetHead(data.head)
    this.playerHead[root]:SetFrame(data.headFrame)
    this.playerHead[root]:SetLevel(data.level)
end

--初始化滚动区信息
function this.InitRollingInfo(root)
    local name = Util.GetGameObject(root,"Name"):GetComponent("Text")
    local power = Util.GetGameObject(root,"power/Text"):GetComponent("Text")
    name.text = ""
    power.text = ""
    return name, power
end

--设置显示信息
function this.SetShowInfo(name, power, data)
    if data.uid < 10000 then
        name.text = GetLanguageStrById(data.name)
    else
        name.text = data.name
    end
    power.text = data.totalForce
end

--检查是否显示第一页 当切换页签时切换到第一页 当请求下一页时不跳转第一页
function this.CheckIsTop()
    if this.istop then
        this.scrollView:SetIndex(1)
        this.istop = false
    end
end

--排行榜人物点赞
function this.SetHeroBtnLike(root,data)
    local btnLike = Util.GetGameObject(root, "DianZanBtn")
    if data.uid < 10000 then
        btnLike:SetActive(false)
    else
        btnLike:SetActive(true)
    end
    local btnLikeText = Util.GetGameObject(root, "DianZanBtn/DianZanNum")
    btnLikeText:GetComponent("Text").text = data.likeNums
    btnLikeList[data.uid] = btnLike.gameObject

    Util.AddOnceClick(btnLike,function()
        if ArenaTopMatchManager.CheckTodayIsAlreadyLike(data.uid) then
            PopupTipPanel.ShowTipByLanguageId(50357)
            return
        end
        NetManager.ArenaTopMatchLikeRequest(data.uid,function()
            NetManager.ArenaTopMatchGetAllSendLikeResponse(function(msg) 
                local alreadyLike = msg.uid
                for i = 1, #alreadyLike do
                    if btnLikeList[alreadyLike[i]] then
                        -- Util.SetGray(btnLikeList[alreadyLike[i]], true)
                        btnLikeText:GetComponent("Text").text = data.likeNums + 1 --值对应改变
                        PopupTipPanel.ShowTipByLanguageId(12579)
                        btnLike:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[2])
                    else
                        -- Util.SetGray(btnLikeList[alreadyLike[i]], false)
                        btnLike:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[1])
                    end
                end
            end)
            CheckRedPointStatus(RedPointType.Championships_Rank)
        end)
    end)
end

function this.LikeBtnState()
    ArenaTopMatchManager.RequestTodayAlreadyLikeUids_TopMatch(function(msg)
        local alreadyLike = msg.uid
        for k, v in pairs(btnLikeList) do
            local isAlreadyLike = false
            for i = 1, #alreadyLike do
                if alreadyLike[i] == k then
                    isAlreadyLike = true
                end
            end
            -- Util.SetGray(v, isAlreadyLike)
            if isAlreadyLike then
                v:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[2])
            else
                v:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[1])
            end
        end
    end)
end

return ATM_RankViewPanel