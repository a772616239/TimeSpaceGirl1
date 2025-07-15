require("Base/BasePanel")
ClimbTowerElitePanel = Inherit(BasePanel)
local this = ClimbTowerElitePanel

local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local isInbattle

--初始化组件（用于子类重写）
function ClimbTowerElitePanel:InitComponent()
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    this.RawImage_Yun = Util.GetGameObject(self.gameObject, "frame/RawImage_Yun"):GetComponent("RawImage")
    this.RawImage_JianZhu = Util.GetGameObject(self.gameObject, "frame/RawImage_JianZhu"):GetComponent("RawImage")

    this.pro = Util.GetGameObject(self.gameObject, "ScrollPre")
    this.Scroll = Util.GetGameObject(self.gameObject, "Scroll")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.pro, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0), nil, this.ScrollOnUpdate)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    this.scrollView.elastic = false

    this.HeadBound = Util.GetGameObject(self.gameObject, "HeadBound")
    this.HeadBoundH = this.HeadBound.transform.rect.height
    this.Head = Util.GetGameObject(self.gameObject, "HeadBound/Head")
    this.scroll_headpos = Util.GetGameObject(self.gameObject, "HeadBound/Head/headpos")

    this.ChallengeBtn = Util.GetGameObject(self.gameObject, "ChallengeBtn")
    this.ChallengeBtnEffect = Util.GetGameObject(self.gameObject, "ChallengeBtn/effect")
    this.ChallengeTimes = Util.GetGameObject(self.gameObject, "ChallengeTimes")
    this.LastChallengeTimes = Util.GetGameObject(self.gameObject, "ChallengeTimes/LastChallengeTimes")
    this.LastBuyTimes = Util.GetGameObject(self.gameObject, "ChallengeTimes/LastBuyTimes")
    this.AddBtn = Util.GetGameObject(self.gameObject, "ChallengeTimes/AddBtn")

    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition

    this.RankMini = Util.GetGameObject(self.gameObject, "RankMini")
    this.RankMiniRankBtn = Util.GetGameObject(self.gameObject, "RankMini/Button")

    this.ShopBtn = Util.GetGameObject(self.gameObject, "ShopBtn")
    this.starScreenBtn = Util.GetGameObject(self.gameObject, "starScreen")

    this.modeBtn = Util.GetGameObject(self.gameObject, "btnList/ModeBtn")
    this.backBtn = Util.GetGameObject(self.gameObject, "btnList/backBtn")
    this.modeBtnRedPoint = Util.GetGameObject(self.gameObject, "btnList/ModeBtn/redpoint")

    this.playerScrollHead = {}
end

--绑定事件（用于子类重写）
function ClimbTowerElitePanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.ChallengeBtn, function()
        UIManager.OpenPanel(UIName.ClimbTowerEliteRewardPopup)
    end)

    Util.AddClick(this.RankMiniRankBtn, function()
        ClimbTowerManager.GetRankData(function()
            UIManager.OpenPanel(UIName.ClimbTowerEliteRankPopup)
        end, ClimbTowerManager.ClimbTowerType.Advance)
    end)
    Util.AddClick(this.scroll_headpos, function()
        local index = this:GetScrollIndexWithTier(this.curTier)
        this:UpdateScroll(index)
        this.ScrollOnUpdate(this.scrollView:GetOffset())
    end)

    Util.AddClick(this.AddBtn, function()
        if ClimbTowerManager.CheckCanBuy(self.climbTowerType) then
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.ClimbTowerBuy, function()
                NetManager.VirtualBattleBuyCount(self.climbTowerType, function()
                    -- 购买成功
                    -- 刷本地数据
                    ClimbTowerManager.SetCount(self.climbTowerType, ClimbTowerManager.GetCount(self.climbTowerType) + 1)
                    ClimbTowerManager.SetHasBuyCount(self.climbTowerType, ClimbTowerManager.GetHasBuyCount(self.climbTowerType) + 1)

                    ClimbTowerElitePanel.UpdateChallengeTimesUI()

                    this:UpdateScroll()
                end)
            end, ClimbTowerManager.GetHasBuyCount(self.climbTowerType) + 1)
        else
            PopupTipPanel.ShowTipByLanguageId(11543)
        end
    end)

    Util.AddClick(this.ShopBtn, function()
        UIManager.OpenPanel(UIName.ShopIndependentPanel, SHOP_INDEPENDENT_PAGE.CLIMB_ADVANCE)
    end)

    Util.AddClick(this.starScreenBtn, function()
        UIManager.OpenPanel(UIName.ClimbTowerEliteFilterStarPopup, 1)
    end)

    Util.AddOnceClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.ClimbTowerRewardPopup,this.helpPosition.x,this.helpPosition.y)
    end)

    Util.AddClick(this.modeBtn, function ()
        JumpManager.GoJump(8401)
    end)

    BindRedPointObject(RedPointType.ClimbTower, this.modeBtnRedPoint)
    BindRedPointObject(RedPointType.ClimbSeniorTowerReward, this.ChallengeBtnEffect)
end

--添加事件监听（用于子类重写）
function ClimbTowerElitePanel:AddListener()
end

--移除事件监听（用于子类重写）
function ClimbTowerElitePanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ClimbTowerElitePanel:OnOpen()
    self.climbTowerType = ClimbTowerManager.ClimbTowerType.Advance
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerElitePanel:OnShow()
    CheckRedPointStatus(RedPointType.ClimbTowerReward)
    CheckRedPointStatus(RedPointType.ClimbTowerFreeTime)
    CheckRedPointStatus(RedPointType.ClimbSeniorTowerReward)
    isInbattle = false
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.ClimbTowerElitePanel })

    self.scrollData = ClimbTowerManager.GetTowerScrollData(ClimbTowerManager.ClimbTowerType.Advance)

    self.curTier = ClimbTowerManager.fightId_Advance
    local index = self:GetScrollIndexWithTier(self.curTier)
    self:UpdateScroll(index)

    if not this.scrollHead then
        this.scrollHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.scroll_headpos.transform)
    end
    this.scrollHead:SetHead(PlayerManager.head)
    this.scrollHead:SetFrame(PlayerManager.frame)
    this.scrollHead:SetScale(0.85)

    this.ScrollOnUpdate(this.scrollView:GetOffset())
    this.UpdateChallengeTimesUI()
    this.UpdateRankMini()
end

-- 根据层数获取scrollData 索引
function ClimbTowerElitePanel:GetScrollIndexWithTier(curTier)
    -- return #self.scrollData  - (curTier + 1 + 3)  -- +1为首尾位移 +3为趋于中间位置隔三个 setindex控件定位在最上
    return #self.scrollData  - curTier
end

function ClimbTowerElitePanel:UpdateScroll(index)
    CheckRedPointStatus(RedPointType.ClimbSeniorTowerReward)
    this.scrollView:SetData(self.scrollData , function(index, root)
        local configData = self.scrollData[index].data
        local isShow = not not configData
        root:SetActive(isShow)
        if isShow then
            Util.GetGameObject(root, "Tier"):GetComponent("Text").text = GetLanguageStrById(configData.Name)

            local Open = Util.GetGameObject(root, "Open")
            local Lock = Util.GetGameObject(root, "Lock")
            Lock:SetActive(false)
            Open:SetActive(false)
            Util.SetGray(Lock,true)

            local function SetStar(num)
                for i = 1, 3 do
                    local star = Util.GetGameObject(root, "Star/star" .. i)
                    star:SetActive(i <= num)
                    local no = Util.GetGameObject(root, "Star/no" .. i)
                    no:SetActive(i > num)
                end
            end

            if configData.Id <= self.curTier then
                Open:SetActive(true)
                local status = Util.GetGameObject(Open, "Status")
                local Current = Util.GetGameObject(status, "Current")
                local Finish = Util.GetGameObject(status, "Finish")

                local Cleared = Util.GetGameObject(Finish, "Cleared")--已通关
                local mopUp = Util.GetGameObject(Finish, "mopUp")--扫荡

                -- 默认点击事件
                Util.AddOnceClick(Util.GetGameObject(root, "Click"), function()
                    ClimbTowerManager.GetReportData(configData.Id, PlayerManager.uid, function(msg)
                        UIManager.OpenPanel(UIName.ClimbTowerEliteGoFightPopup, configData.Id, self.climbTowerType)
                    end, ClimbTowerManager.ClimbTowerType.Advance)
                end)

                if configData.Id == self.curTier then
                    -- 当前
                    Current:SetActive(true)
                    Finish:SetActive(false)
                else
                    -- 已完成
                    Current:SetActive(false)
                    Finish:SetActive(true)
                    if configData.Id == self.curTier - 1 then
                        mopUp:SetActive(true)
                        Cleared:SetActive(false)

                        local SweepBuy = Util.GetGameObject(mopUp, "SweepBuy")
                        local SweepFree = Util.GetGameObject(mopUp, "SweepFree")
                        SweepBuy:SetActive(false)
                        SweepFree:SetActive(false)
                        if ClimbTowerManager.GetCount(self.climbTowerType) > 0 then
                            SweepFree:SetActive(true)
                        else
                            if ClimbTowerManager.CheckCanBuy(self.climbTowerType) then
                                SweepBuy:SetActive(true)

                                local cost, itemid = ClimbTowerManager.GetBuyCost(self.climbTowerType, ClimbTowerManager.GetHasBuyCount(self.climbTowerType) + 1) --< +1 获取的为已买次数 传入为第几次买
                                local itemData = ItemConfig[itemid]
                                Util.GetGameObject(SweepBuy, "GameObject/Pic"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
                                Util.GetGameObject(SweepBuy, "GameObject/Text"):GetComponent("Text").text = string.format(GetLanguageStrById(12530), tostring(cost))
                            else
                                mopUp:SetActive(false)
                                Cleared:SetActive(true)
                            end
                        end
                    else
                        mopUp:SetActive(false)
                        Cleared:SetActive(true)
                    end
                end

                SetStar(ClimbTowerManager.GetStageStar(configData.Id))
            else
                Util.AddOnceClick(Util.GetGameObject(root, "Click"), function()
                    -- 覆盖点击事件
                end)

                if configData.Id > self.curTier + ClimbTowerManager.FirstShowNum then
                    Lock:SetActive(true)
                end

                SetStar(0)
            end

            --首通奖励显示
            local FirstShow = Util.GetGameObject(root, "FirstShow")
            local isFirstShow = configData.Id == self.curTier or (configData.Id > self.curTier and configData.Id <= self.curTier + ClimbTowerManager.FirstShowNum)
            if isFirstShow then
                FirstShow:SetActive(true)
                local Item = Util.GetGameObject(FirstShow, "Item").transform
                if Item.childCount > 0 then
                    for i = 1,Item.childCount do
                        GameObject.Destroy(Item:GetChild(i-1).gameObject)
                    end
                end 

                local view = SubUIManager.Open(SubUIConfig.ItemView, Item)
                view:OnOpen(false, {configData.FirstAwards[1][1], configData.FirstAwards[1][2]}, 0.55)
            else
                FirstShow:SetActive(false)
            end

            local winner = Util.GetGameObject(root, "winner")
            if configData.Challenge == 1 then
                -- 有擂主的
                winner:SetActive(true)
                local TowerMaster = Util.GetGameObject(winner, "TowerMaster/Text"):GetComponent("Text")
                local frame = Util.GetGameObject(winner, "info/frame"):GetComponent("Image")
                local icon = Util.GetGameObject(winner, "info/icon"):GetComponent("Image")
                local name = Util.GetGameObject(winner, "info/name"):GetComponent("Text")
                local battle = Util.GetGameObject(winner, "btn")
                local getWinner = Util.GetGameObject(winner, "frame")

                local WinnerInfo = ClimbTowerManager.virtualEliteBossArray[configData.Id]

                battle:SetActive(self.curTier > configData.Id)

                -- 有擂主
                if WinnerInfo then
                    battle:GetComponent("Button").enabled = WinnerInfo.teamInfo.uid ~= PlayerManager.uid
                    TowerMaster.text = "( "..(configData.Name-4).." - "..configData.Name.." )"
                    frame.sprite = GetPlayerHeadFrameSprite(WinnerInfo.teamInfo.headFrame)
                    icon.sprite = GetPlayerHeadSprite(WinnerInfo.teamInfo.head)
                    name.text = WinnerInfo.username

                    Util.AddOnceClick(getWinner, function()
                        UIManager.OpenPanel(UIName.PlayerInfoPopup, WinnerInfo.teamInfo.uid)
                    end)

                    Util.AddOnceClick(battle, function()
                        if self.curTier > configData.Id then
                            if BattleManager.IsInBackBattle() then
                                return
                            end
                            if isInbattle then
                                return
                            end
                            isInbattle = true
                            if WinnerInfo then
                                FormationManager.curFormationIndex = FormationTypeDef.FORMATION_NORMAL
                                --> fightInfo
                                local structA = nil
                                local structB = {
                                    head = WinnerInfo.teamInfo.head,
                                    headFrame = WinnerInfo.teamInfo.headFrame,
                                    name = WinnerInfo.teamInfo.name,
                                    formationId = WinnerInfo.teamInfo.teamFormation or 1,
                                    investigateLevel = WinnerInfo.teamInfo.investigateLevel
                                }
                                BattleManager.SetAgainstInfoData(BATTLE_TYPE.Climb_Tower_Advance, structA, structB)
                                ClimbTowerManager.ExecuteFightAdvance(configData.Id, function()
                                end, true)
                            end
                        else
                            -- 未到
                        end
                    end)
                else
                    winner:SetActive(false)
                end
            else
                winner:SetActive(false)
            end
        end

        Util.GetGameObject(root, "Idx").transform:GetChild(0).name = self.scrollData[index].idx
        local arr = {}
        this.scrollView:ForeachItemGO(function(i, go)
            local n = Util.GetGameObject(go, "Idx").transform:GetChild(0).name
            if n ~= "Idx" then
                table.insert(arr, {go, n})
            end
        end)
        table.sort(arr, function(a, b)
            return tonumber(a[2]) < tonumber(b[2])
        end)
        for k, v in ipairs(arr) do
            v[1].transform:SetSiblingIndex(k - 1)
        end
 
        local RawImage = Util.GetGameObject(root, "RawImage"):GetComponent("RawImage")
        tempUVRect = RawImage.uvRect
        if self.scrollData [index].idx % 3 == 1 then
            tempUVRect.y = 0
        elseif self.scrollData [index].idx % 3 == 2 then
            tempUVRect.y = -1
        else
            tempUVRect.y = 1
        end
        RawImage.uvRect = tempUVRect

        --塔主位置
        local RawImage_TaZhu = Util.GetGameObject(root, "RawImage_TaZhu"):GetComponent("RawImage")
        local UVRect = RawImage.uvRect
        UVRect.y = configData.Name - 1
        RawImage_TaZhu.uvRect = UVRect
    end)

    if index then
        this.scrollView:SetIndex(index)
    end
end

local offset_temp = 0
function ClimbTowerElitePanel.ScrollOnUpdate(gridLocalPos)
    -- if gridLocalPos ~= nil then
    --     print(gridLocalPos.y)
    -- end

    if offset_temp ~= 0 and offset_temp ~= gridLocalPos.y then
        offsetVal = offset_temp - gridLocalPos.y
        if offsetVal ~= 0 then
            tempUVRect = this.RawImage_JianZhu.uvRect
            tempUVRect.y = tempUVRect.y + offsetVal * 0.00003
            this.RawImage_JianZhu.uvRect = tempUVRect

            -- print("RawImage_JianZhu:   "..tempUVRect.y)

            tempUVRect = this.RawImage_Yun.uvRect
            tempUVRect.y = tempUVRect.y + offsetVal * 0.00001
            this.RawImage_Yun.uvRect = tempUVRect

            -- print("RawImage_Yun:   "..tempUVRect.y)
        end
    end
    offset_temp = gridLocalPos.y

    this.scrollView:ForeachItemGO(function(i, go)
        local n = Util.GetGameObject(go, "Idx").transform:GetChild(0).name
        if n ~= "Idx" then
            if this.scrollData[tonumber(n)] and this.scrollData[tonumber(n)].data then
                if this.scrollData[tonumber(n)].data.Id == this.curTier then
                    local targetPos = UIManager.GetLocalPositionToTarget(go, this.HeadBound)
                    local y = -targetPos.y + 50 -- 对位置偏移180 对准层数位置
                    if y < -this.HeadBoundH / 2 then
                        y = -this.HeadBoundH / 2
                    end
                    if y > this.HeadBoundH / 2 then
                        y = this.HeadBoundH / 2
                    end
                    this.Head.transform.localPosition = Vector3.New(this.Head.transform.localPosition.x, y, 0)
                end
            end
        end
    end)
end

function ClimbTowerElitePanel.UpdateChallengeTimesUI()
    this.LastChallengeTimes:GetComponent("Text").text = GetLanguageStrById(11050) .. ClimbTowerManager.GetCount(this.climbTowerType) .. "/" .. ClimbTowerManager.GetFreeTimesUp(this.climbTowerType)
    this.LastBuyTimes:GetComponent("Text").text = string.format(GetLanguageStrById(10345), tostring(ClimbTowerManager.GetBuyTimesUp(this.climbTowerType) - ClimbTowerManager.GetHasBuyCount(this.climbTowerType)))
end

function ClimbTowerElitePanel.UpdateRankMini()
    local rankDatas = ClimbTowerManager.GetSortRanks(ClimbTowerManager.ClimbTowerType.Advance)
    for i = 1, 3 do
        local rankGo = Util.GetGameObject(this.RankMini, "User/RankUser" .. tostring(i))
        if rankDatas[i] then
            rankGo:SetActive(true)

            Util.GetGameObject(rankGo, "Front"):GetComponent("Text").text = rankDatas[i].userName
            Util.GetGameObject(rankGo, "Back"):GetComponent("Text").text = string.format(GetLanguageStrById(12534), tostring(rankDatas[i].rankInfo.rank))
        else
            rankGo:SetActive(false)
        end
    end
end

--界面关闭时调用（用于子类重写）
function ClimbTowerElitePanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function ClimbTowerElitePanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)

    if this.scrollHead then
        this.scrollHead:Recycle()
        this.scrollHead = nil
    end
    this.playerScrollHead = {}

    ClearRedPointObject(RedPointType.ClimbTower, this.modeBtnRedPoint)
    ClearRedPointObject(RedPointType.ClimbSeniorTowerReward, this.ChallengeBtnEffect)
end

return ClimbTowerElitePanel