--[[
 * 国家旗帜选择面板
 *
 * 层级结构见 Assets/ManagedResources/Prefabs/UI/CountryRank/CountryFlagSelectPopup.prefab
 *   board/grid/cellPre   旗帜格子模板（inactive，按需克隆）
 *   board/current/...    当前选择展示
 *
 * 打开方式：UIManager.OpenPanel(UIName.CountryFlagSelectPopup, onConfirm)
 *   onConfirm(code) 在玩家点选后回调；直接关窗不回调。
--]]
require("Modules/CountryRank/CountryConfig")
require("Modules/CountryRank/CountryRankManager")
require("Base/BasePanel")
CountryFlagSelectPopup = Inherit(BasePanel)
local this = CountryFlagSelectPopup

-- 网格参数（与 prefab 里 grid 的尺寸配套：860 x 810）
local CELL_W = 190
local CELL_H = 176
local COLUMN_COUNT = 4

-- 旗帜格子视图
local CellView = {}

function CellView:New(gameObject)
    local b = { gameObject = gameObject, transform = gameObject.transform }
    setmetatable(b, { __index = CellView })
    b:InitComponent()
    return b
end

function CellView:InitComponent()
    self.btn = self.gameObject
    self.flag = Util.GetGameObject(self.gameObject, "flag"):GetComponent("Image")
    self.nameText = Util.GetGameObject(self.gameObject, "nameText"):GetComponent("Text")
    self.selected = Util.GetGameObject(self.gameObject, "selected")
end

function CellView:SetData(code)
    self.code = code
    self.flag.sprite = Util.LoadSprite(CountryConfig.GetFlagSprite(code))
    self.nameText.text = CountryConfig.GetName(code)
    self.selected:SetActive(false)
end

function CellView:SetSelected(isOn)
    self.selected:SetActive(isOn)
end

----------------------------------------------------------------
function CountryFlagSelectPopup:InitComponent()
    this.board = Util.GetGameObject(self.gameObject, "board")
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.btnClose = Util.GetGameObject(this.board, "btnClose")
    this.titleText = Util.GetGameObject(this.board, "title"):GetComponent("Text")
    this.tipText = Util.GetGameObject(this.board, "tip"):GetComponent("Text")

    this.grid = Util.GetGameObject(this.board, "grid")
    this.cellPre = Util.GetGameObject(this.grid, "cellPre")

    this.curFlag = Util.GetGameObject(this.board, "current/flag"):GetComponent("Image")
    this.curName = Util.GetGameObject(this.board, "current/nameText"):GetComponent("Text")

    this.cells = {}
    this._selected = nil
end

function CountryFlagSelectPopup:BindEvent()
    Util.AddClick(this.btnClose, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        this:ClosePanel()
    end)
end

function CountryFlagSelectPopup:AddListener()
end

function CountryFlagSelectPopup:RemoveListener()
end

function CountryFlagSelectPopup:OnOpen(callback)
    this._callback = callback
    this.titleText.text = GetLanguageStrByStr("选择你的国家")
    this.tipText.text = GetLanguageStrByStr("默认按设备地区自动选择，可随时修改")
end

function CountryFlagSelectPopup:OnShow()
    this._selected = CountryRankManager.GetPlayerCountry()
    this:BuildCells()
    this:RefreshSelected()
end

function CountryFlagSelectPopup:OnClose()
    this.cells = {}
    this._callback = nil
end

--- 生成旗帜格子
function CountryFlagSelectPopup:BuildCells()
    if #this.cells > 0 then
        return
    end
    local list = CountryConfig.List
    local total = #list
    local rowCount = math.ceil(total / COLUMN_COUNT)
    local totalH = rowCount * CELL_H
    local startY = totalH / 2 - CELL_H / 2

    for i = 1, total do
        local code = list[i].code
        local col = (i - 1) % COLUMN_COUNT
        local row = math.floor((i - 1) / COLUMN_COUNT)
        local go = newObject(this.cellPre)
        go.name = "cell_" .. code
        go.transform:SetParent(this.grid.transform, false)
        go:SetActive(true)
        local rt = go:GetComponent("RectTransform")
        rt.anchorMin = Vector2.New(0.5, 0.5)
        rt.anchorMax = Vector2.New(0.5, 0.5)
        rt.pivot = Vector2.New(0.5, 0.5)
        rt.anchoredPosition = Vector2.New(
                (col - (COLUMN_COUNT - 1) / 2) * CELL_W,
                startY - row * CELL_H)
        rt.sizeDelta = Vector2.New(CELL_W, CELL_H)

        local view = CellView:New(go)
        view:SetData(code)
        this.cells[code] = view

        Util.AddClick(go, function()
            this:SelectCountry(code)
        end)
    end
end

function CountryFlagSelectPopup:SelectCountry(code)
    this._selected = CountryConfig.Normalize(code)
    CountryRankManager.SetPlayerCountry(this._selected)
    this:RefreshSelected()
    if Game.GlobalEvent then
        Game.GlobalEvent:DispatchEvent(GameEvent.CountryRank.OnCountryChanged, this._selected)
    end
    if this._callback then
        this._callback(this._selected)
    end
    this:ClosePanel()
end

function CountryFlagSelectPopup:RefreshSelected()
    for code, view in pairs(this.cells) do
        view:SetSelected(code == this._selected)
    end
    this.curFlag.sprite = Util.LoadSprite(CountryConfig.GetFlagSprite(this._selected))
    this.curName.text = CountryConfig.GetName(this._selected)
end
