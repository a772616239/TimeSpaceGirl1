require("Base/BasePanel")
ClimbTowerEliteGoFightPopup = Inherit(BasePanel)
local this = ClimbTowerEliteGoFightPopup

local VirtualBattle = ConfigManager.GetConfig(ConfigName.VirtualBattle)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local items = {}
--初始化组件（用于子类重写）
function ClimbTowerEliteGoFightPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")

    this.title = Util.GetGameObject(self.gameObject, "bg/bg/title"):GetComponent("Text")

    this.live = Util.GetGameObject(self.gameObject, "bg/live/pos")

    this.ChallengeBtn = Util.GetGameObject(self.gameObject, "bg/Btn/ChallengeBtn")
    this.SweepBtn = Util.GetGameObject(self.gameObject, "bg/Btn/SweepBtn")
    this.SweepBtnPic = Util.GetGameObject(self.gameObject, "bg/Btn/SweepBtn/GameObject/Pic")
    this.SweepBtnTxt = Util.GetGameObject(self.gameObject, "bg/Btn/SweepBtn/GameObject/Text")

    --
    this.power = Util.GetGameObject(self.gameObject, "bg/Report/GameObject/power"):GetComponent("Text")
    this.fastestName = Util.GetGameObject(self.gameObject, "bg/Report/GameObject/fastestName"):GetComponent("Text")
    this.minPower = Util.GetGameObject(self.gameObject, "bg/Report/GameObject/minPower"):GetComponent("Text")

    this.PassReportBtn = Util.GetGameObject(self.gameObject, "bg/Report/PassReportBtn")

    this.StarTask = Util.GetGameObject(self.gameObject, "bg/Task/StarTask")

    this.RewardGrid = Util.GetGameObject(self.gameObject, "bg/Reward/Grid/RewardGrid")

    this.btnClose = Util.GetGameObject(self.gameObject, "btnClose")

    this.repeatItemView = {}
end

--绑定事件（用于子类重写）
function ClimbTowerEliteGoFightPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.PassReportBtn, function()
        UIManager.OpenPanel(UIName.ClimbTowerEliteBattleReportPopup, this.towerTier, this.climbTowerType)
    end)

    Util.AddClick(this.ChallengeBtn, function()
        if this.towerTier < ClimbTowerManager.fightId_Advance then
            if ClimbTowerManager.GetCount(self.climbTowerType) > 0 then
                UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CLIMB_TOWER, this.towerTier, ClimbTowerManager.ClimbTowerType.Advance)
                self:ClosePanel()
            else        
                PopupTipPanel.ShowTipByLanguageId(11048)
            end
        else
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CLIMB_TOWER, this.towerTier, ClimbTowerManager.ClimbTowerType.Advance)
            self:ClosePanel()
        end
    end)

    Util.AddClick(this.SweepBtn, function()
        if this.towerTier < ClimbTowerManager.fightId_Advance then
            if ClimbTowerManager.GetCount(self.climbTowerType) > 0 then
                -- 直接免费扫荡
                self:Sweep()
            else
                if ClimbTowerManager.CheckCanBuy(self.climbTowerType) then
                    local cost, itemid = ClimbTowerManager.GetBuyCost(self.climbTowerType, ClimbTowerManager.GetHasBuyCount(self.climbTowerType) + 1) --< +1 获取的为已买次数 传入为第几次买
                    MsgPanel.ShowTwo(string.format(GetLanguageStrById(12532), cost .. GetLanguageStrById(ItemConfig[itemid].Name)), function()
                    end, function()
                        if BagManager.GetItemCountById(itemid) >= cost then
                            NetManager.VirtualBattleBuyCount(self.climbTowerType, function()
                                -- 购买成功
                                -- 刷本地数据
                                ClimbTowerManager.SetCount(self.climbTowerType, ClimbTowerManager.GetCount(self.climbTowerType) + 1)
                                ClimbTowerManager.SetHasBuyCount(self.climbTowerType, ClimbTowerManager.GetHasBuyCount(self.climbTowerType) + 1)
                                self:Sweep()
                            end)
                        else
                            PopupTipPanel.ShowTipByLanguageId(12529)
                        end
                    end)
                else
                    PopupTipPanel.ShowTipByLanguageId(11543)
                end
            end
        end
    end)
end

function ClimbTowerEliteGoFightPopup:Sweep()
    ClimbTowerManager.ExecuteSweep(self.climbTowerType, this.towerTier, function(msg)
        -- 刷本地数据
        ClimbTowerManager.SetCount(self.climbTowerType, ClimbTowerManager.GetCount(self.climbTowerType) - 1)

        if UIManager.IsOpen(UIName.ClimbTowerElitePanel) then -- 刷新父界面
            ClimbTowerElitePanel.UpdateChallengeTimesUI()
            local offset = ClimbTowerElitePanel.scrollView:GetOffset()
            ClimbTowerElitePanel:UpdateScroll(nil, offset)
        end

        this:Init() -- 刷新本界面
        
        if msg.drop then
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
        end
    end)
end

--添加事件监听（用于子类重写）
function ClimbTowerEliteGoFightPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ClimbTowerEliteGoFightPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ClimbTowerEliteGoFightPopup:OnOpen(...)
    local args = {...}
    this.towerTier = args[1]
    this.climbTowerType = args[2]

    ClimbTowerManager.curFightId_Advance = this.towerTier
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerEliteGoFightPopup:OnShow()
    self:Init()
end

function ClimbTowerEliteGoFightPopup:Init()
    if this.towerTier == ClimbTowerManager.fightId_Advance then
        self.isFirst = true
        this.SweepBtn:SetActive(false)
    else
        self.isFirst = false
        this.SweepBtn:SetActive(true)

        local GameObject = Util.GetGameObject(this.SweepBtn, "GameObject")
        local GameObjectFree = Util.GetGameObject(this.SweepBtn, "GameObjectFree")
        GameObject:SetActive(false)
        GameObjectFree:SetActive(false)
        if ClimbTowerManager.GetCount(self.climbTowerType) > 0 then
            GameObjectFree:SetActive(true)
        else
            GameObject:SetActive(true)

            local cost, itemid = ClimbTowerManager.GetBuyCost(self.climbTowerType, ClimbTowerManager.GetHasBuyCount(self.climbTowerType) + 1) --< +1 获取的为已买次数 传入为第几次买
            local itemData = ItemConfig[itemid]
            Util.GetGameObject(this.SweepBtn, "GameObject/Pic"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
            Util.GetGameObject(this.SweepBtn, "GameObject/Text"):GetComponent("Text").text = string.format(GetLanguageStrById(12530), tostring(cost))
        end
    end

    towerData = G_VirtualEliteBattle[this.towerTier]
    this.title.text = GetLanguageStrById(towerData.Name)

    if this.liveObj then
        UnLoadHerolive(HeroConfig[towerData.VisibleTank],this.liveObj)
        Util.ClearChild(this.live.transform)
    end
    this.liveObj = LoadHerolive(HeroConfig[towerData.VisibleTank],this.live.transform)

    this.power.text = string.format(GetLanguageStrById(12519), towerData.Power)

    local reportData = ClimbTowerManager.GetReportDataByDataId(ClimbTowerManager.ReportId.FastTime, ClimbTowerManager.ClimbTowerType.Advance)
    if reportData then
        this.fastestName.text = string.format(GetLanguageStrById(12520), reportData.playName)
    else
        this.fastestName.text = string.format(GetLanguageStrById(12520), GetLanguageStrById(10094))
    end
    reportData = ClimbTowerManager.GetReportDataByDataId(ClimbTowerManager.ReportId.LowestPower, ClimbTowerManager.ClimbTowerType.Advance)
    if reportData then
        this.minPower.text = string.format(GetLanguageStrById(12521), reportData.playName)
    else
        this.minPower.text = string.format(GetLanguageStrById(12521), GetLanguageStrById(10094))
    end

    local itemDatas = {}
    if self.isFirst then
        for i = 1, #towerData.FirstAwards do
            table.insert(itemDatas, {itemid = towerData.FirstAwards[i][1], num = towerData.FirstAwards[i][2], cornerType = ItemCornerType.FirstPass})
        end
    end
    for i = 1, #towerData.Awards do
        table.insert(itemDatas, {itemid = towerData.Awards[i][1], num = towerData.Awards[i][2]})
    end

    if #this.repeatItemView == 0 then
        for i = 1, 4 do -- 支持四个
            this.repeatItemView[i] = SubUIManager.Open(SubUIConfig.ItemView, this.RewardGrid.transform)
        end
    end

    for i = 1, #this.repeatItemView do
        if i <= #itemDatas then
            this.repeatItemView[i]:OnOpen(false, {itemDatas[i].itemid, itemDatas[i].num}, 0.7, nil, nil, nil, nil, itemDatas[i].cornerType)
            this.repeatItemView[i].gameObject:SetActive(true)
        else
            this.repeatItemView[i].gameObject:SetActive(false)
        end
    end

    -- startask
    for i = 1, #towerData.StarCondition do
        local taskGo = Util.GetGameObject(this.StarTask, "task" .. i)
        local desc = Util.GetGameObject(taskGo, "desc"):GetComponent("Text")
        local star = Util.GetGameObject(taskGo, "star")
        local no = Util.GetGameObject(taskGo, "no")
        local taskid = towerData.StarCondition[i][1]
        local StarCondServer = towerData.StarCondition[i]
        if taskid == 4 then
            local data = {
                taskid,
                towerData.StarCondition[i][2]/100 .. "%"
            }
            StarCondServer = data
        end
        local desstr = GVM.GetTaskById(taskid, unpack(StarCondServer, 2, #StarCondServer))
        desc.text = desstr

        local ids = ClimbTowerManager.GetStageStarIds(towerData.Id)
        star:SetActive(not not ids[taskid])
        no:SetActive(not star.activeSelf)
    end
end

--界面关闭时调用（用于子类重写）
function ClimbTowerEliteGoFightPopup:OnClose()
    if this.liveObj then
        UnLoadHerolive(HeroConfig[towerData.VisibleTank],this.liveObj)
        Util.ClearChild(this.live.transform)
    end
end

--界面销毁时调用（用于子类重写）
function ClimbTowerEliteGoFightPopup:OnDestroy()
    this.repeatItemView = {}
end

return ClimbTowerEliteGoFightPopup