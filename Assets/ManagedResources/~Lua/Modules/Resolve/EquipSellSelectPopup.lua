require("Base/BasePanel")
EquipSellSelectPopup = Inherit(BasePanel)
local this = EquipSellSelectPopup
local isAllSelectState = false
local quaGrid = {}
local starGrid = {}
local quaStateTable = {}
--false 未选择 true 选择
local starStateTable = {}
--false 未选择 true 选择
local quaTextStringSeting = {
    [1] = {name = GetLanguageStrById(10197), defaultState = true},
    [2] = {name = GetLanguageStrById(10196), defaultState = true},
    [3] = {name = GetLanguageStrById(10195), defaultState = false},
    [4] = {name = GetLanguageStrById(10192), defaultState = false},
    [5] = {name = GetLanguageStrById(10193), defaultState = false}
}
local sartTextStringSeting = {
    [1] = {name = GetLanguageStrById(12237), defaultState = true},
    [2] = {name = GetLanguageStrById(12179), defaultState = true},
    [3] = {name = GetLanguageStrById(12177), defaultState = false},
    [4] = {name = GetLanguageStrById(12175), defaultState = false},
    [5] = {name = GetLanguageStrById(12173), defaultState = false},
}
--初始化组件（用于子类重写）
function EquipSellSelectPopup:InitComponent()
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.BackMask = Util.GetGameObject(self.transform, "BackMask") --m5
    this.allSelectBtn = Util.GetGameObject(self.transform, "allSelectBtn/click")
    this.allSelectBtnImage = Util.GetGameObject(self.transform, "allSelectBtn/allSelectBtnImage")
    this.cancelBtn = Util.GetGameObject(self.transform, "cancelBtn")
    this.sellBtn = Util.GetGameObject(self.transform, "sellBtn")
    quaGrid = {}
    for i = 1, 5 do
        quaGrid[i] = Util.GetGameObject(self.transform, "quaGrid/quaSelectBtn (" .. i .. ")")
        starGrid[i] = Util.GetGameObject(self.transform, "starGrid/starSelectBtn (" .. i .. ")")
    end
end

--绑定事件（用于子类重写）
function EquipSellSelectPopup:BindEvent()
    Util.AddClick(
        this.BtnBack,
        function()
            self:ClosePanel()
        end
    )
    Util.AddClick(
        this.BackMask,
        function()
            self:ClosePanel()
        end
    ) --m5
    Util.AddClick(
        this.allSelectBtn,
        function()
            isAllSelectState = not isAllSelectState
            this.allSelectBtnImage:SetActive(isAllSelectState)
            if isAllSelectState then
                this.AllSelectShow()
            else
                this.DefaultShow()
            end
        end
    )
    Util.AddClick(
        this.cancelBtn,
        function()
            self:ClosePanel()
        end
    )
    Util.AddClick(
        this.sellBtn,
        function()
            local qualityList = {}
            local starList = {}
            for i=1,#quaStateTable do
                if quaStateTable[i] then
                    qualityList[i + 1] = i + 1
                end
            end
            for i=1,#starStateTable do
                if starStateTable[i] then
                    starList[i] = i 
                end
            end  
            if LengthOfTable(qualityList) == 0 or LengthOfTable(starList) == 0 then
                PopupTipPanel.ShowTipByLanguageId(12277)
                return
            end
            local data = BagManager.GetEquipDataByEquipQualityAndStar(qualityList,starList)
            if #data < 1 then
                PopupTipPanel.ShowTipByLanguageId(12277)
                return
            end
            self:ClosePanel()
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.EquipBatchSell,
            BagManager.GetEquipDataByEquipQualityAndStar(qualityList,starList))           
        end
    )
    for i = 1, #quaGrid do
        Util.AddClick(
            Util.GetGameObject(quaGrid[i], "click"),
            function()
                quaStateTable[i] = not quaStateTable[i]
                Util.GetGameObject(quaGrid[i], "allSelectBtnImage"):SetActive(quaStateTable[i])
                this.IsShowAllSelectImage()
            end
        )
    end
    for i = 1, #starGrid do
        Util.AddClick(
            Util.GetGameObject(starGrid[i], "click"),
            function()
                starStateTable[i] = not starStateTable[i]
                Util.GetGameObject(starGrid[i], "allSelectBtnImage"):SetActive(starStateTable[i])
                this.IsShowAllSelectImage()
            end
        )
    end
end

--添加事件监听（用于子类重写）
function EquipSellSelectPopup:AddListener()
end

--移除事件监听（用于子类重写）
function EquipSellSelectPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function EquipSellSelectPopup:OnOpen()
end
function EquipSellSelectPopup:OnShow()
    this.DefaultShow()
end
function this.DefaultShow()
    --初始选择
    isAllSelectState = false
    this.allSelectBtnImage:SetActive(isAllSelectState)
    quaStateTable = {}
    starStateTable = {}
    for i = 1, #quaTextStringSeting do
        table.insert(quaStateTable, quaTextStringSeting[i].defaultState)
        if quaGrid[i] then
            Util.GetGameObject(quaGrid[i], "Text"):GetComponent("Text").text = quaTextStringSeting[i].name
            Util.GetGameObject(quaGrid[i], "allSelectBtnImage"):SetActive(quaTextStringSeting[i].defaultState)
        end
    end
    for i = 1, #sartTextStringSeting do
        table.insert(starStateTable, sartTextStringSeting[i].defaultState)
        if starGrid[i] then
            Util.GetGameObject(starGrid[i], "Text"):GetComponent("Text").text = sartTextStringSeting[i].name
            Util.GetGameObject(starGrid[i], "allSelectBtnImage"):SetActive(sartTextStringSeting[i].defaultState)
        end
    end
end
function this.AllSelectShow()
    --初始选择
    quaStateTable = {}
    starStateTable = {}
    for i = 1, #quaTextStringSeting do
        table.insert(quaStateTable, true)
        if quaGrid[i] then
            Util.GetGameObject(quaGrid[i], "allSelectBtnImage"):SetActive(true)
        end
    end
    for i = 1, #sartTextStringSeting do
        table.insert(starStateTable, true)
        if starGrid[i] then
            Util.GetGameObject(starGrid[i], "allSelectBtnImage"):SetActive(true)
        end
    end
end
--显示全部按钮
function this.IsShowAllSelectImage()
    local quaIsAllTrue = true
    for i = 1, #quaStateTable do
        if not quaStateTable[i] then
            quaIsAllTrue = false
        end
    end
    local starIsAllTrue = true
    for i = 1, #starStateTable do
        if not starStateTable[i] then
            starIsAllTrue = false
        end
    end
    if quaIsAllTrue and starIsAllTrue then
        isAllSelectState = true
    else
        isAllSelectState = false
    end
    this.allSelectBtnImage:SetActive(isAllSelectState)
end
--出售点击事件
function this.SellBtnClick()
    local quaIsAllTrue = false
    for i = 1, #quaStateTable do
        if quaStateTable[i] then
            quaIsAllTrue = true
        end
    end
    local starIsAllTrue = false
    for i = 1, #starStateTable do
        if starStateTable[i] then
            starIsAllTrue = true
        end
    end
    if quaIsAllTrue and starIsAllTrue then
        --出售
    else
        -- GetLanguageStrById(12108)
    end
end
--界面关闭时调用（用于子类重写）
function EquipSellSelectPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function EquipSellSelectPopup:OnDestroy()
end

return EquipSellSelectPopup