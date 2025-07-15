local this = {}
local sortingOrder = 0
local HeroStarBackConfig = ConfigManager.GetConfig(ConfigName.HeroStarBackConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local HeroLevelConfig = ConfigManager.GetConfig(ConfigName.HeroLevelConfig)
local HeroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local selectData
local itemList = {}
local itemDefultList = {}
local gradeList = {}

function this:InitComponent(gameObject)
    this.Arena = Util.GetGameObject(gameObject, "ArenaTypePanel_Arena")
    --this.Arena_Name = Util.GetGameObject(this.Arena, "Name"):GetComponent("Text")
    
    --前三名数据显示
    this.first = Util.GetGameObject(this.Arena,"bg/flagRed/domain")
    this.firstIcon = Util.GetGameObject(this.first,"icon")
    this.firstName = Util.GetGameObject(this.first,"name/Text")
    this.firstBtn = Util.GetGameObject(this.first,"btnAdd")
    this.firstIBtnText = Util.GetGameObject(this.first,"btnAdd/Text")

    this.second = Util.GetGameObject(this.Arena,"bg/flagYellow/domain")
    this.secondIcon = Util.GetGameObject(this.second,"icon")
    this.secondName = Util.GetGameObject(this.second,"name/Text")
    this.secondBtn = Util.GetGameObject(this.second,"btnAdd")
    this.secondIBtnText = Util.GetGameObject(this.second,"btnAdd/Text")

    this.third = Util.GetGameObject(this.Arena,"bg/flagPurple/domain")
    this.thirdIcon = Util.GetGameObject(this.third,"icon")
    this.thirdName = Util.GetGameObject(this.third,"name/Text")
    this.thirdtBtn = Util.GetGameObject(this.third,"btnAdd")
    this.thirdIBtnText = Util.GetGameObject(this.third,"btnAdd/Text")
   
    table.insert(gradeList,this.first)
    table.insert(gradeList,this.second)
    table.insert(gradeList,this.third)

    this.Arena_Season = Util.GetGameObject(this.Arena, "bgDown/Season/Text"):GetComponent("Text")
    this.Arena_Score = Util.GetGameObject(this.Arena, "bgDown/Score/Text"):GetComponent("Text")
    this.Arena_Rank = Util.GetGameObject(this.Arena, "bgDown/Rank/Text"):GetComponent("Text")
    this.Arena_btnEnter = Util.GetGameObject(this.Arena, "btnEnter")
end

function this:BindEvent()
    Util.AddClick(this.Arena_btnEnter, function()
        JumpManager.GoJump(8001)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end
local sortingOrder = 0
function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end

function this:OnShow(...)
    sortingOrder = 0
    for key, value in pairs(gradeList) do
        value:SetActive(false)
        Util.GetGameObject(value.transform.parent.gameObject, "roleImage"):SetActive(false)
    end

    NetManager.RequestArenaRankData(1,function(page,msg)      --这块排行走了两套逻辑 RankingManager ArenaManager
        RankingManager.ReceiveArenaData(page,msg)

        this.RefreshArenaShow()

        local arenaRank = RankingManager.GetArenaInfo()
        this.dt = {}
        for i, v in ipairs(arenaRank) do
            if i == 1 or i == 2 or i == 3 then
                table.insert(this.dt,v)
            end
        end

        if #this.dt <= 0 then
            return
        end

        ArenaManager.RequestTodayAlreadyLikeUids_Arena(function()
            for i = 1, LengthOfTable(gradeList) do
                if gradeList[i] ~= nil then
                    this:SetHeadsInfo(gradeList[i],this.dt[i])
                end
            end
        end)
    end)
end

function this:OnClose()
  
end

function this:OnDestroy()
    gradeList = {}
end

-- 刷新竞技场显示
function this.RefreshArenaShow()
    --this.Arena_Name.text = ArenaManager.GetArenaName()
    local baseData = ArenaManager.GetArenaBaseData()
    this.Arena_Score.text = baseData.score
    local _, myRankInfo = ArenaManager.GetRankInfo()
    local myRank = myRankInfo.personInfo.rank
    if myRank < 0 then
        myRank = GetLanguageStrById(10041)
    end
    this.Arena_Rank.text = myRank

    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.ARENA)
    local startDate = os.date("%m.%d", serData.startTime)
    local endDate = os.date("%m.%d", serData.endTime)
    this.Arena_Season.text = string.format("%s - %s", startDate, endDate)
end

--设置前三名背景头像
function this:SetHeadsInfo(root,data)
    local frame = Util.GetGameObject(root,"frame"):GetComponent("Image")
    local icon = Util.GetGameObject(root,"icon"):GetComponent("Image")
    local name = Util.GetGameObject(root,"name/Text"):GetComponent("Text")
    local btn = Util.GetGameObject(root,"btnAdd")
    local btnText = Util.GetGameObject(root,"btnAdd/Text"):GetComponent("Text")
    local roleImage = Util.GetGameObject(root.transform.parent.gameObject, "roleImage")
    
    if data ~= nil then
        root:SetActive(true)
        roleImage:SetActive(false)
        frame.sprite = GetPlayerHeadFrameSprite(data.personInfo.headFrame)
        icon.sprite = GetPlayerHeadSprite(data.personInfo.head)
        name.text = data.personInfo.name
        btnText.text = data.personInfo.likeNums

        if ArenaManager.CheckTodayIsAlreadyLike(data.personInfo.uid) then
            btn:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[2])
            Util.SetGray(btn, true)
        else
            btn:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[1])
            Util.SetGray(btn, false)
        end
    else
        name.text = GetLanguageStrById(12406)
        roleImage:SetActive(true)
    end

    Util.AddOnceClick(icon.gameObject, function ()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, data.personInfo.uid)
    end)
    Util.AddOnceClick(btn,function()
        if ArenaManager.CheckTodayIsAlreadyLike(data.personInfo.uid) then
            PopupTipPanel.ShowTipByLanguageId(50357)
            return
        end

        NetManager.RedPackageLikeRequest(data.personInfo.uid, function()
            ArenaManager.RequestTodayAlreadyLikeUids_Arena(function()
                data.personInfo.likeNums = data.personInfo.likeNums + 1
                btnText.text = data.personInfo.likeNums
                PopupTipPanel.ShowTipByLanguageId(12579)
                btn:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[2])
                Util.SetGray(btn, true)
            end)
        end)
    end)
end

return this