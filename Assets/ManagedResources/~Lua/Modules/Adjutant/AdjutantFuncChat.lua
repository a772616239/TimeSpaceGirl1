local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local adjutantChatConfig = ConfigManager.GetConfig(ConfigName.AdjutantChatConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local this = {}

--初始化组件（用于子类重写）
function this:InitComponent(parentNode)
    this.parentNode = parentNode
    this.Connect = Util.GetGameObject(this.parentNode, "connect")
    this.connectBtn = Util.GetGameObject(this.Connect, "connectBtn")
    this.btn_up1lvRedpot = Util.GetGameObject(this.parentNode, "ChatDown/up1lv/Redpot")
    this.connectAllBtn = Util.GetGameObject(this.Connect, "connectAllBtn")
    this.btn_autoUplvRedpot = Util.GetGameObject(this.parentNode, "ChatDown/autoUplv/Redpot")

    this.MaxPic = Util.GetGameObject(this.parentNode, "MaxPic")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.connectBtn, function()
        local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        NetManager.GetAdjutantChat(self.adjutantId, 1, 2, function()
            NetManager.GetAllAdjutantInfo(function()--需要重拉下数据 目前和后端这么定
                self:UpdateUI()
                -- FormationManager.FlutterPower(oldPower)
                RefreshPower(oldPower)
                CheckRedPointStatus(RedPointType.Adjutant_Btn_Chat)
            end)
        end)
    end)
    Util.AddClick(this.connectAllBtn, function()
        if not this.canChat then
            PopupTipPanel.ShowTip(GetLanguageStrById(10060))
        end
        local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        NetManager.GetAdjutantChat(self.adjutantId, 2, 2, function()
            NetManager.GetAllAdjutantInfo(function()--需要重拉下数据 目前和后端这么定
                self:UpdateUI()
                -- FormationManager.FlutterPower(oldPower)
                RefreshPower(oldPower)
                CheckRedPointStatus(RedPointType.Adjutant_Btn_Chat)
            end)
        end)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow(id)
    self.adjutantId = AdjutantManager.GetCurSelectAdjutantId()
    self:UpdateUI()
end

function this:UpdateUI()
    self.data = AdjutantManager.GetOneAdjutantDataById(self.adjutantId)
    
    local lv = self.data.chatLevel
    -- lv = lv == 0 and 1 or lv
    local curLvData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantChatConfig, "AdjutantId", self.adjutantId, "Lvl", lv)
    
    local id1, valueAtk = AdjutantManager.GetOnePro(HeroProType.Attack, self.adjutantId, 1)
    local id2, valueHp = AdjutantManager.GetOnePro(HeroProType.Hp, self.adjutantId, 1)

    Util.GetGameObject(this.parentNode, "ATK/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(propertyConfig[HeroProType.Attack].Icon))
    Util.GetGameObject(this.parentNode, "ATK/name"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[HeroProType.Attack].Info)
    Util.GetGameObject(this.parentNode, "ATK/value"):GetComponent("Text").text = "+" .. this:GetProDataStr(id1, valueAtk)

    Util.GetGameObject(this.parentNode, "HP/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(propertyConfig[HeroProType.Hp].Icon))
    Util.GetGameObject(this.parentNode, "HP/name"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[HeroProType.Hp].Info)
    Util.GetGameObject(this.parentNode, "HP/value"):GetComponent("Text").text = "+" .. this:GetProDataStr(id2, valueHp)
   
    Util.GetGameObject(this.parentNode, "lv"):GetComponent("Text").text = GetLanguageStrById(10470) .. tostring(lv)

    if lv >= AdjutantManager.GetMaxLimit(self.adjutantId, 1) then
        Util.GetGameObject(this.parentNode, "ExpBar"):GetComponent("Slider").value = 1
        this.Connect:SetActive(false)
        this.MaxPic:SetActive(true)
        return
    else
        this.Connect:SetActive(true)
        this.MaxPic:SetActive(false)
    end

    Util.GetGameObject(this.parentNode, "ExpBar"):GetComponent("Slider").value = self.data.exp / curLvData.ExpUpgrade

    this.canChat = true
    for i = 1, 2 do
        local itemId = curLvData.Cost[i][1]
        local itemData = itemConfig[itemId]
        local bagNum = BagManager.GetItemCountById(itemId)
        Util.GetGameObject(this.Connect, "Cost" .. i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
        local str
        if bagNum >= curLvData.Cost[i][2] then
            str = PrintWanNum(bagNum)
        else
            this.canChat = false
            str = string.format("<color=#FF6868>%s</color>",PrintWanNum(bagNum))
        end
        Util.GetGameObject(this.Connect, "Cost" .. i .. "/Num"):GetComponent("Text").text = str.."/"..curLvData.Cost[i][2]
 
        ItemImageTips(itemId, Util.GetGameObject(this.Connect, "Cost" .. i .. "/icon"))
    end
end

function this:GetProDataStr(id, value)
    local style = propertyConfig[id].Style
    local str = ""
    if style == 1 then-- 绝对值
        str = GetPropertyFormatStr(1, value)
    elseif style == 2 then-- 百分比
        str = GetPropertyFormatStr(2, value)
    end
    return str
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

return this