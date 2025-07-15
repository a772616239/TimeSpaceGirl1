require("Base/BasePanel")
ClimbTowerPanel = Inherit(BasePanel)
local this = ClimbTowerPanel

local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

--初始化组件（用于子类重写）
function ClimbTowerPanel:InitComponent()
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)
    --获取帮助按钮
    this.backBtn = Util.GetGameObject(self.gameObject, "backBtn")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition

    this.RawImage_Yun = Util.GetGameObject(self.gameObject, "RawImage_Yun"):GetComponent("RawImage");
    this.RawImage_JianZhu = Util.GetGameObject(self.gameObject, "RawImage_JianZhu"):GetComponent("RawImage");

    this.pro = Util.GetGameObject(self.gameObject, "ScrollPre")
    this.Scroll = Util.GetGameObject(self.gameObject, "Scroll")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.pro, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0), nil, this.ScrollOnUpdate)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    this.scrollView.elastic = false

    -- this.tempPos = this.scrollView:GetOffset();
    -- print(tempPos.y)

    this.ChallengeBtn = Util.GetGameObject(self.gameObject, "ChallengeBtn")
    this.ChallengeBtnEffect = Util.GetGameObject(self.gameObject, "ChallengeBtn/effect")
    this.RankBtn = Util.GetGameObject(self.gameObject, "RankBtn")
    this.EliteModeBtn = Util.GetGameObject(self.gameObject, "EliteModeBtn")

    this.RankMini = Util.GetGameObject(self.gameObject, "RankMini")
    this.RankMiniRankBtn = Util.GetGameObject(self.gameObject, "RankMini/Button")

    this.HeadBound = Util.GetGameObject(self.gameObject, "HeadBound")
    this.HeadBoundH = this.HeadBound.transform.rect.height
    this.Head = Util.GetGameObject(self.gameObject, "HeadBound/Head")
    this.scroll_headpos = Util.GetGameObject(self.gameObject, "HeadBound/Head/headpos")

    this.ChallengeTimes = Util.GetGameObject(self.gameObject, "ChallengeTimes")
    this.LastChallengeTimes = Util.GetGameObject(self.gameObject, "ChallengeTimes/LastChallengeTimes")
    this.LastBuyTimes = Util.GetGameObject(self.gameObject, "ChallengeTimes/LastBuyTimes")
    this.AddBtn = Util.GetGameObject(self.gameObject, "ChallengeTimes/AddBtn")

    this.redPoint = Util.GetGameObject(self.gameObject, "ModeBtn/redpoint")
end

--绑定事件（用于子类重写）
function ClimbTowerPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.ChallengeBtn, function()
        UIManager.OpenPanel(UIName.ClimbTowerRewardPopup)
    end)
    Util.AddClick(this.RankBtn, function()
        ClimbTowerManager.GetRankData(function()
            UIManager.OpenPanel(UIName.ClimbTowerRankPopup)
        end)
    end)
    Util.AddClick(this.RankMiniRankBtn, function()
        ClimbTowerManager.GetRankData(function()
            UIManager.OpenPanel(UIName.ClimbTowerRankPopup)
        end)
    end)
    Util.AddClick(this.scroll_headpos, function()
        local index = this:GetScrollIndexWithTier(this.curTier)
        ClimbTowerPanel:UpdateScroll(index)
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

                    ClimbTowerPanel.UpdateChallengeTimesUI()

                    ClimbTowerPanel:UpdateScroll()
                end)
            end, ClimbTowerManager.GetHasBuyCount(self.climbTowerType) + 1)
        else
            PopupTipPanel.ShowTipByLanguageId(11543)
        end
    end)

    Util.AddClick(this.EliteModeBtn, function()
        local isVisible, isOpen = ClimbTowerManager.CheckEliteModeIsOpen()
        if not isOpen then
            PopupTipPanel.ShowTip(GetLanguageStrById(23042))
            return
        end
        NetManager.VirtualElitBattleGetInfo(function()
            ClimbTowerManager.GetRankData(function()
                UIManager.OpenPanel(UIName.ClimbTowerElitePanel)
            end, ClimbTowerManager.ClimbTowerType.Advance)
        end)
    end)
    BindRedPointObject(RedPointType.ClimbTowerReward, this.ChallengeBtnEffect)
    BindRedPointObject(RedPointType.ClimbTower, this.redPoint)

    Util.AddOnceClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.ClimbTower,this.helpPosition.x,this.helpPosition.y - 300)
    end)
end

--添加事件监听（用于子类重写）
function ClimbTowerPanel:AddListener()
end

--移除事件监听（用于子类重写）
function ClimbTowerPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ClimbTowerPanel:OnOpen()
    self.climbTowerType = ClimbTowerManager.ClimbTowerType.Normal
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerPanel:OnShow()
    local isVisible, isOpen = ClimbTowerManager.CheckEliteModeIsOpen()
    this.EliteModeBtn:SetActive(isOpen)
    
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.ClimbTowerPanel })

    self.scrollData = ClimbTowerManager.GetTowerScrollData()

    self.curTier = ClimbTowerManager.fightId
    local index = self:GetScrollIndexWithTier(self.curTier)
    ClimbTowerPanel:UpdateScroll(index)

    if not this.scrollHead then
        this.scrollHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.scroll_headpos.transform)
    end
    this.scrollHead:SetHead(PlayerManager.head)
    this.scrollHead:SetFrame(PlayerManager.frame)
    this.scrollHead:SetScale(0.85)

    this.ScrollOnUpdate(this.scrollView:GetOffset())
    this.UpdateChallengeTimesUI()
    this.UpdateRankMini()

    this.UpdateAdvanceModeBtn()
end

-- 根据层数获取scrollData 索引
function ClimbTowerPanel:GetScrollIndexWithTier(curTier)
    return #self.scrollData  - curTier  --< +1为首尾位移 +3为趋于中间位置隔三个 setindex控件定位在最上
end

function ClimbTowerPanel:UpdateScroll(index)
    CheckRedPointStatus(RedPointType.ClimbTowerReward)
    CheckRedPointStatus(RedPointType.ClimbTowerFreeTime)
    this.scrollView:SetData(self.scrollData , function(index, root)
        local configData = self.scrollData [index].data
        local isShow = not not configData
        root:SetActive(isShow)
        if isShow then
            Util.GetGameObject(root, "Tier"):GetComponent("Text").text = configData.Name
            local Open = Util.GetGameObject(root, "Open")
            local Lock = Util.GetGameObject(root, "Lock")
            Open:SetActive(false)
            Lock:SetActive(false)
            Util.SetGray(Lock,true)

            if configData.Id <= self.curTier then
                Open:SetActive(true)
                local status = Util.GetGameObject(Open, "Status")
                local Current = Util.GetGameObject(status, "Current")
                local Finish = Util.GetGameObject(status, "Finish")
                -- local Document = Util.GetGameObject(Open, "Document")

                -- 默认点击事件
                Util.AddOnceClick(Util.GetGameObject(root, "Click"), function()
                    ClimbTowerManager.GetReportData(configData.Id, PlayerManager.uid, function(msg)
                        UIManager.OpenPanel(UIName.ClimbTowerGoFightPopup, configData.Id, self.climbTowerType)
                    end)
                end)

                if configData.Id == self.curTier then   -- 当前
                    Current:SetActive(true)
                    Finish:SetActive(false)
                    -- Document:GetComponent("Image").sprite = Util.LoadSprite("N1_img_monizhan_dangandai3")
                else    -- 已完成
                    Current:SetActive(false)
                    Finish:SetActive(true)
                    if configData.Id == self.curTier - 1 then
                        Util.GetGameObject(Finish, "SignSweep"):SetActive(true)
                        -- Util.GetGameObject(Finish, "SignAlready"):SetActive(false)

                        local SweepBuy = Util.GetGameObject(Finish, "SignSweep/SweepBuy")
                        local SweepFree = Util.GetGameObject(Finish, "SignSweep/SweepFree")
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
                                Util.GetGameObject(Finish, "SignSweep"):SetActive(false)
                                -- Util.GetGameObject(Finish, "SignAlready"):SetActive(true)
                            end
                        end
                    else
                        Util.GetGameObject(Finish, "SignSweep"):SetActive(false)
                        -- Util.GetGameObject(Finish, "SignAlready"):SetActive(true)
                    end
                    -- Document:GetComponent("Image").sprite = Util.LoadSprite("N1_img_monizhan_dangandai2")
                end
            else
                Util.AddOnceClick(Util.GetGameObject(root, "Click"), function()
                    -- 覆盖点击事件
                end)

                if configData.Id > self.curTier + ClimbTowerManager.FirstShowNum then
                    Lock:SetActive(true)
                end
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

                local  view = SubUIManager.Open(SubUIConfig.ItemView,Item)
                view:OnOpen(false, {configData.FirstAwards[1], configData.FirstAwards[2]}, 0.6)
            else
                FirstShow:SetActive(false)
            end
        end

        --> 层级
        Util.GetGameObject(root, "Idx").transform:GetChild(0).name = self.scrollData [index].idx
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
 
        local RawImage_Bg = Util.GetGameObject(root, "RawImage_Bg"):GetComponent("RawImage")
        tempUVRect = RawImage_Bg.uvRect
        if self.scrollData [index].idx % 3 == 1 then
            tempUVRect.y = 0
        elseif self.scrollData [index].idx % 3 == 2 then
            tempUVRect.y = -1
        else
            tempUVRect.y = 1
        end
        RawImage_Bg.uvRect = tempUVRect

    end)

    if index then
        this.scrollView:SetIndex(index)
    end
end


local offset_temp = 0
function ClimbTowerPanel.ScrollOnUpdate(gridLocalPos)
    --if gridLocalPos ~= nil then 
        --print(gridLocalPos.y)
    --end

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
                    local y = -targetPos.y + 50 --< 对位置偏移180 对准层数位置
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

function ClimbTowerPanel.UpdateChallengeTimesUI()
    this.LastChallengeTimes:GetComponent("Text").text = GetLanguageStrById(11050) .. ClimbTowerManager.GetCount(this.climbTowerType) .. "/" .. ClimbTowerManager.GetFreeTimesUp(this.climbTowerType)
    this.LastBuyTimes:GetComponent("Text").text = string.format(GetLanguageStrById(10345), tostring(ClimbTowerManager.GetBuyTimesUp(this.climbTowerType) - ClimbTowerManager.GetHasBuyCount(this.climbTowerType)))
end

function ClimbTowerPanel.UpdateRankMini()
    ClimbTowerManager.GetRankData(function ()
        local rankDatas = ClimbTowerManager.GetSortRanks()
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
    end)
end

function ClimbTowerPanel.UpdateAdvanceModeBtn()
    local isVisible, isOpen = ClimbTowerManager.CheckEliteModeIsOpen()
    --this.EliteModeBtn:SetActive(isVisible)

    --this.EliteModeBtn:SetActive(false) -- 屏蔽 开启删除
end

--界面关闭时调用（用于子类重写）
function ClimbTowerPanel:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function ClimbTowerPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    -- SubUIManager.Close(this.BtView)
    if this.playerHead then
        this.playerHead:Recycle()
        this.playerHead = nil
    end
    if this.scrollHead  then
        this.scrollHead:Recycle()
        this.scrollHead = nil
    end

    ClearRedPointObject(RedPointType.ClimbTowerReward, this.ChallengeBtnEffect)
    ClearRedPointObject(RedPointType.ClimbTower, this.redPoint)
end

return ClimbTowerPanel