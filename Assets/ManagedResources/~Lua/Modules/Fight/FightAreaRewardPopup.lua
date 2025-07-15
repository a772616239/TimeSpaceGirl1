require("Base/BasePanel")
local FightAreaRewardPopup = Inherit(BasePanel)
local this = FightAreaRewardPopup
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local _ProductList = {}
local _ItemList = {}
local _RewardList = {}
--初始化组件（用于子类重写）
function FightAreaRewardPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "mask")
    this.itemRoot = Util.GetGameObject(self.transform, "showMopUp/Bg/rewardContent")
    this.item = Util.GetGameObject(this.itemRoot, "item1")

    this.rewardBox = Util.GetGameObject(self.transform, "showMopUp/Bg/Scroll/Viewport/Content")

    --特权权益显示（暂时关闭，防止策划鬼畜）鬼畜不了了
    -- this.privilege = Util.GetGameObject(self.transform, "showMopUp/Bg/privilege")
    -- this.privilegeIcon = Util.GetGameObject(this.privilege, "Icon")
    -- this.privilegeEffect = Util.GetGameObject(this.privilege, "Icon/effect")
    -- this.privilegeContent = Util.GetGameObject(this.privilege, "Content"):GetComponent("Text")
    -- this.privilegeTimeBg = Util.GetGameObject(this.privilege, "bg")
    -- this.privilegeTime = Util.GetGameObject(this.privilege, "bg/Time"):GetComponent("Text")
    -- this.privilegeGo = Util.GetGameObject(this.privilege, "go")
end

--绑定事件（用于子类重写）
function FightAreaRewardPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)


    -- 激活特权 特权权益显示（暂时关闭）
    -- Util.AddClick(this.privilegeGo, function()
    --     local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(35)
    --     if not isActive then
    --         UIManager.OpenPanel(UIName.MainRechargePanel, 3)
    --     end
    -- end)
end

--添加事件监听（用于子类重写）
function FightAreaRewardPopup:AddListener()
end

--移除事件监听（用于子类重写）
function FightAreaRewardPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function FightAreaRewardPopup:OnOpen(...)

end

-- 
local orginLayer = -1
function this:OnSortingOrderChange()
    -- Util.AddParticleSortLayer(this.privilegeEffect, this.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightAreaRewardPopup:OnShow()
    local curFightId = FightPointPassManager.GetCurFightId()
    local config = ConfigManager.GetConfigData(ConfigName.MainLevelConfig, curFightId)
    if not config then return end

    -- 固定奖励
    for index, item in ipairs(config.RewardShowMin) do
        if not _ProductList[index] then
            _ProductList[index] = newObjToParent(this.item, this.itemRoot.transform)
        end
        this.ItemAdapter(_ProductList[index], item)
    end


    ---- 随机奖励
    local randReward = {}
    if config.RewardShow then
        for j = 1, #config.RewardShow do
            randReward[#randReward + 1] = config.RewardShow[j]
        end
    end
    
    local open, extral = FightPointPassManager.GetExtralReward()
    if open > 0 then
        for k = 1, #extral do
            randReward[#randReward + 1] = extral[k]
        end
    end

    if #randReward > 1 then
        table.sort(randReward, function (a, b)
            return ItemConfig[a[1]].Quantity > ItemConfig[b[1]].Quantity
        end)
    end

    for index, reward in ipairs(randReward) do
        if not _RewardList[index] then
            _RewardList[index] = SubUIManager.Open(SubUIConfig.ItemView, this.rewardBox.transform)
        end
        local rdata = {reward[1], 0}    -- 不显示数量
        _RewardList[index]:OnOpen(false, rdata, 1, true)
    end

    --特权权益显示（暂时关闭）
    -- local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(35)
    -- Util.SetGray(this.privilegeIcon, not isActive)
    -- this.privilegeTimeBg:SetActive(isActive)
    -- this.privilegeGo:SetActive(not isActive)
    -- this.privilegeEffect:SetActive(isActive)
    -- local colorStr = isActive and "#FFA278" or "#B7B7B7"
    -- this.privilegeContent.text = "<color="..colorStr..">挂机增益特权 (金币/成长护符<color=#FFA278>+50%</color>)</color>"
    -- if isActive then
    --     local leftTime = PrivilegeManager.GetPrivilegeLeftTimeById(35)
    --     this.privilegeTime.text = "剩余:"..GetLeftTimeStrByDeltaTime(leftTime)
    -- end
end

-- 物体数据匹配
function this.ItemAdapter(node, data)
    -- 创建一个物体
    local root = Util.GetGameObject(node, "root")
    if not _ItemList[node] then
        _ItemList[node] = SubUIManager.Open(SubUIConfig.ItemView, root.transform)
    end
    local rdata = {data[1], 0}    -- 不显示数量
    _ItemList[node]:OnOpen(false, rdata, 1.1)

    --
    local txt = Util.GetGameObject(node, "context"):GetComponent("Text")
    local addValue = FightPointPassManager.GetItemVipValue(data[1])
    if addValue - 1 <= 0 then
        txt.text = string.format(GetLanguageStrById(10568), data[2])
    else
        local valueShow = (addValue - 1) * 100
        --txt.text = string.format("+%d<color=#F5C66BFF>(+%d%%)</color>\n/分钟", data[2],math.floor(valueShow))
        txt.text ="+"..data[2].."<color=#F5C66BFF>(+"..valueShow..GetLanguageStrById(10569)
    end
end


--界面关闭时调用（用于子类重写）
function FightAreaRewardPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function FightAreaRewardPopup:OnDestroy()
    _ProductList = {}

    for _, node in ipairs(_ItemList) do
        SubUIManager.Close(node)
    end
    _ItemList = {}

    for _, node in ipairs(_RewardList) do
        SubUIManager.Close(node)
    end
    _RewardList = {}
end

return FightAreaRewardPopup