require("Base/BasePanel")
ClimbTowerGoFightPopup = Inherit(BasePanel)
local this = ClimbTowerGoFightPopup

local VirtualBattle = ConfigManager.GetConfig(ConfigName.VirtualBattle)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local items = {}
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
--初始化组件（用于子类重写）
function ClimbTowerGoFightPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "btnClose")
    this.ChallengeBtn = Util.GetGameObject(self.gameObject, "bg/Btn/ChallengeBtn")
    this.SweepBtn = Util.GetGameObject(self.gameObject, "bg/Btn/SweepBtn")
    this.SweepBtnPic = Util.GetGameObject(self.gameObject, "bg/Btn/SweepBtn/GameObject/Pic")
    this.SweepBtnTxt = Util.GetGameObject(self.gameObject, "bg/Btn/SweepBtn/GameObject/Text")

    this.title = Util.GetGameObject(self.gameObject, "bg/title"):GetComponent("Text")
    this.TankImg = Util.GetGameObject(self.gameObject, "bg/TankImg/pos")
    this.Power = Util.GetGameObject(self.gameObject, "bg/Report/GameObject/Power"):GetComponent("Text")
    this.FastPowerUserName = Util.GetGameObject(self.gameObject, "bg/Report/GameObject/FastPowerUserName"):GetComponent("Text")
    this.LowestPowerUserName = Util.GetGameObject(self.gameObject, "bg/Report/GameObject/LowestPowerUserName"):GetComponent("Text")
    this.PassReportBtn = Util.GetGameObject(self.gameObject, "bg/Report/PassReportBtn")

    this.RewardGrid = Util.GetGameObject(self.gameObject, "bg/Reward/Grid/RewardGrid")

    this.repeatItemView = {}
end

--绑定事件（用于子类重写）
function ClimbTowerGoFightPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.PassReportBtn, function()
        UIManager.OpenPanel(UIName.ClimbTowerBattleReportPopup, this.towerTier, this.climbTowerType)
    end)

    Util.AddClick(this.ChallengeBtn, function()
        if this.towerTier < ClimbTowerManager.fightId then
            if ClimbTowerManager.GetCount(self.climbTowerType) > 0 then
                UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CLIMB_TOWER, this.towerTier)
                self:ClosePanel()
            else
                PopupTipPanel.ShowTipByLanguageId(11048)
            end
        else
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CLIMB_TOWER, this.towerTier)
            self:ClosePanel()
        end
    end)

    Util.AddClick(this.SweepBtn, function()
        if this.towerTier < ClimbTowerManager.fightId then
            if ClimbTowerManager.GetCount(self.climbTowerType) > 0 then
                --> 直接免费扫荡
                self:Sweep()
            else
                if ClimbTowerManager.CheckCanBuy(self.climbTowerType) then
                    local cost, itemid = ClimbTowerManager.GetBuyCost(self.climbTowerType, ClimbTowerManager.GetHasBuyCount(self.climbTowerType) + 1) --< +1 获取的为已买次数 传入为第几次买
                    MsgPanel.ShowTwo(string.format(GetLanguageStrById(12532), cost .. GetLanguageStrById(ItemConfig[itemid].Name)), function()
                        
                    end, function()
                        if BagManager.GetItemCountById(itemid) >= cost then
                            NetManager.VirtualBattleBuyCount(self.climbTowerType, function()
                                --< 购买成功
                                --> 刷本地数据
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

function ClimbTowerGoFightPopup:Sweep()
    ClimbTowerManager.ExecuteSweep(self.climbTowerType, this.towerTier, function(msg)
        --> 刷本地数据
        ClimbTowerManager.SetCount(self.climbTowerType, ClimbTowerManager.GetCount(self.climbTowerType) - 1)

        if ClimbTowerPanel then --< 刷新父界面
            ClimbTowerPanel.UpdateChallengeTimesUI()
            local offset = ClimbTowerPanel.scrollView:GetOffset()
            ClimbTowerPanel:UpdateScroll(nil, offset)
        end

        this:Init() --< 刷新本界面
        
        if msg.drop then
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
        end
    end)
end

--添加事件监听（用于子类重写）
function ClimbTowerGoFightPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function ClimbTowerGoFightPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function ClimbTowerGoFightPopup:OnOpen(...)
    local args = {...}
    this.towerTier = args[1]
    this.climbTowerType = args[2]

    ClimbTowerManager.curFightId = this.towerTier
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerGoFightPopup:OnShow()
    self:Init()
end

function ClimbTowerGoFightPopup:Init()
    if this.towerTier == ClimbTowerManager.fightId then
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

    towerData = VirtualBattle[this.towerTier]

    this.title.text = towerData.Name
    
    --local spinePrefabName = GetResourcePath(HeroConfig[towerData.VisibleTank].RoleImage)
    -- poolManager:LoadLive(spinePrefabName,this.TankImg.transform,Vector3.New(1, 1,1), 

    if this.liveObj then
        UnLoadHerolive(HeroConfig[towerData.VisibleTank],this.liveObj)
        Util.ClearChild(this.TankImg.transform)
        this.liveObj = nil
    end
    this.liveObj = LoadHerolive(HeroConfig[towerData.VisibleTank],this.TankImg.transform)

    --Vector3.New(HeroConfig[towerData.VisibleTank].Position[1], HeroConfig[towerData.VisibleTank].Position[2]))
    --this.TankImg:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(HeroConfig[towerData.VisibleTank].RoleImage))
    this.Power.text = string.format(GetLanguageStrById(12519), towerData.Power)
    
    local reportData = ClimbTowerManager.GetReportDataByDataId(ClimbTowerManager.ReportId.FastTime)
    if reportData then
        this.FastPowerUserName.text = string.format(GetLanguageStrById(12520), reportData.playName)
    else
        this.FastPowerUserName.text = string.format(GetLanguageStrById(12520), GetLanguageStrById(10094))
    end
    reportData = ClimbTowerManager.GetReportDataByDataId(ClimbTowerManager.ReportId.LowestPower)
    if reportData then
        this.LowestPowerUserName.text = string.format(GetLanguageStrById(12521), reportData.playName)
    else
        this.LowestPowerUserName.text = string.format(GetLanguageStrById(12521), GetLanguageStrById(10094))
    end

    local itemDatas = {}
    if self.isFirst and #towerData.FirstAwards == 2 then
        table.insert(itemDatas, {itemid = towerData.FirstAwards[1], num = towerData.FirstAwards[2], cornerType = ItemCornerType.FirstPass})
    end
    for i = 1, #towerData.Awards do 
        table.insert(itemDatas, {itemid = towerData.Awards[i][1], num = towerData.Awards[i][2]})
    end

    if #this.repeatItemView == 0 then
        for i = 1, 4 do --< 支持四个
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
end

--界面关闭时调用（用于子类重写）
function ClimbTowerGoFightPopup:OnClose()
    if this.liveObj then
        UnLoadHerolive(HeroConfig[towerData.VisibleTank],this.liveObj)
        Util.ClearChild(this.TankImg.transform)
        this.liveObj = nil
    end
end

--界面销毁时调用（用于子类重写）
function ClimbTowerGoFightPopup:OnDestroy()
    this.repeatItemView = {}
end

return ClimbTowerGoFightPopup