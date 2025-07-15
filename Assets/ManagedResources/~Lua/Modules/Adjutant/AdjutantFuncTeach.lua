local this = {}
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)

--初始化组件（用于子类重写）
function this:InitComponent(parentNode)
    this.parentNode = parentNode
    this.btn_ModifyBtn = Util.GetGameObject(this.parentNode, "Uping/ModifyBtn")
    this.btn_ModifyBtnRedpot = Util.GetGameObject(this.parentNode, "Uping/ModifyBtn/Redpot")

    this.curDesc = Util.GetGameObject(this.parentNode, "Uping/curDesc"):GetComponent("Text")
    this.nextDesc = Util.GetGameObject(this.parentNode, "Uping/nextDesc"):GetComponent("Text")

    this.curlv = Util.GetGameObject(this.parentNode, "Uping/curlv"):GetComponent("Text")
    this.nextlv = Util.GetGameObject(this.parentNode, "Uping/nextlv"):GetComponent("Text")

    this.Uping = Util.GetGameObject(this.parentNode, "Uping")
    this.MaxPic = Util.GetGameObject(this.parentNode, "MaxPic")
end

--绑定事件（用于子类重写）
function this:BindEvent()
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

--界面打开时调用（用于子类重写）
function this:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()
    self.adjutantId = AdjutantManager.GetCurSelectAdjutantId()
    self:UpdateUI()
    BindRedPointObject(RedPointType.Adjutant_Btn_Teach,this.btn_ModifyBtnRedpot)
end

function this:UpdateUI()
    CheckRedPointStatus(RedPointType.Adjutant_Btn_Teach)
    self.data = AdjutantManager.GetOneAdjutantDataById(self.adjutantId)
    
    local chatLv = self.data.chatLevel
    local curLv = self.data.teachLevel

    this.curlv.text = string.format(GetLanguageStrById(22310), curLv)
    local curLvData
    if curLv >= AdjutantManager.GetMaxLimit(self.adjutantId, 4) then
        this.Uping:SetActive(false)
        this.MaxPic:SetActive(true)
        Util.GetGameObject(this.MaxPic,"curlv"):GetComponent("Text").text = this.curlv.text
        this:UpdateMaxUI()
        return
    else
        curLvData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantTeachConfig, "AdjutantId", self.adjutantId, "TeachLvl", curLv)
        this.Uping:SetActive(true)
        this.MaxPic:SetActive(false)
    end

    local nextLv = self.data.teachLevel + 1
    local nextLvData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantTeachConfig, "AdjutantId", self.adjutantId, "TeachLvl", nextLv)
    local proid = nextLvData.AddType
    local id, curProValue = AdjutantManager.GetOnePro(proid, self.adjutantId, 3)
    this.curDesc.text = GetLanguageStrById(propertyConfig[proid].Info) .. "：+" .. this:GetProDataStr(id, curProValue)
    this.nextDesc.text = GetLanguageStrById(propertyConfig[proid].Info) .. "：+" .. this:GetProDataStr(id, curProValue + nextLvData.AddValue)

    this.nextlv.text = string.format(GetLanguageStrById(22310), nextLv)

    local enough = true
    for i = 1, 2 do
        local itemId = curLvData.Cost[i][1]
        local itemData = itemConfig[itemId]
        local bagNum = BagManager.GetItemCountById(itemId)
        Util.GetGameObject(this.parentNode, "Uping/Cost" .. i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))

        local str
        if bagNum >= curLvData.Cost[i][2] then
            str = PrintWanNum(bagNum)
        else
            str = string.format("<color=#FF6868>%s</color>",PrintWanNum(bagNum))
        end

        Util.GetGameObject(this.parentNode, "Uping/Cost" .. i .. "/num"):GetComponent("Text").text = str.."/"..curLvData.Cost[i][2]
        if bagNum < curLvData.Cost[i][2] then
            enough = false
        end

        ItemImageTips(itemId, Util.GetGameObject(this.parentNode, "Uping/Cost" .. i .. "/icon"))
    end

    Util.AddOnceClick(this.btn_ModifyBtn, function()
        if enough then
            if chatLv < curLvData.NeedLvl then
                PopupTipPanel.ShowTipByLanguageId(22316)
            else
                local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
                NetManager.GetAdjutantTeach(self.adjutantId, function()
                    NetManager.GetAllAdjutantInfo(function()    --< 需要重拉下数据 目前和后端这么定
                        self:UpdateUI()
                        CheckRedPointStatus(RedPointType.Adjutant_Btn_Teach)
                        RefreshPower(oldPower)
                    end)
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10073)
        end
    end)
end

function this:UpdateMaxUI()
end

function this:SetPro(go, data)
    local proData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", data.id)
    Util.GetGameObject(go, "proName"):GetComponent("Text").text = GetLanguageStrById(proData.Info)
    local txt = Util.GetGameObject(go, "proVale"):GetComponent("Text")
    if proData.Style == 1 then--绝对值
        txt.text = GetPropertyFormatStr(1, data.value)
    elseif proData.Style == 2 then--百分比
        txt.text = GetPropertyFormatStr(2, data.value)
    end

    Util.GetGameObject(go, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(proData.Icon))
end

function this:GetProDataStr(id, value)
    local style = propertyConfig[id].Style
    local str = ""
    if style == 1 then--绝对值
        str = GetPropertyFormatStr(1, value)
    elseif style == 2 then--百分比
        str = GetPropertyFormatStr(2, value)
    end
    return str
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    ClearRedPointObject(RedPointType.Adjutant_Btn_Teach,this.btn_ModifyBtnRedpot)
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

return this