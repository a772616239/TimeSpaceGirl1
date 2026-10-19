--[[
 * 国家旗帜选择面板
 *
 * 层级结构见 Assets/ManagedResources/Prefabs/UI/CountryRank/CountryFlagSelectPopup.prefab
 *   board/scroll/viewport/grid/cellPre   旗帜格子模板（inactive，按需克隆）；
 *                                        scroll 是 ScrollRect（仅纵向），内容高度
 *                                        由本文件按行数动态设置
 *   board/current/...    当前选择展示
 *
 * 打开方式：UIManager.OpenPanel(UIName.CountryFlagSelectPopup, onConfirm)
 *   onConfirm(code) 在玩家点选后回调；直接关窗不回调。
--]]
require("Modules/CountryRank/CountryConfig")
require("Modules/CountryRank/CountryRankManager")
require("Modules/CountryRank/CountryFlagUtil")
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

    -- ScrollRect 组件在 tolua 未绑定类成员，Lua 侧不直接访问其属性；
    -- 滚动归位通过把 content（grid）的 anchoredPosition 归零实现（Clamped
    -- 模式下 ScrollRect 在下次交互时按 content位置重新夹紧）。
    this.scrollGo = Util.GetGameObject(this.board, "scroll")
    this.grid = Util.GetGameObject(this.board, "scroll/viewport/grid")
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
    this:SnapToTop()
end

--- 滚动区回到顶部（每次打开都从头展示）
function CountryFlagSelectPopup:SnapToTop()
    if this.grid == nil then
        return
    end
    local rt = this.grid:GetComponent("RectTransform")
    rt.anchoredPosition = Vector2.New(0, 0)
end

function CountryFlagSelectPopup:OnClose()
    this.cells = {}
    this._callback = nil
end

--- 清掉 grid 下已经生成过的格子（保留 cellPre 模板）
---
--- 🔴 为什么必须清：本面板 noDestory=false ⇒ UIManager.ClosePanel 里
--- `isDestroy = isDestroy or noDestory == 0` 为 false，关闭时只把 GameObject
--- SetActive(false)，lua 面板对象还被 openedList[id] 缓存复用。所以 grid 下克隆出来的
--- 73 个格子在关闭后依然存在；下次 OnShow 再 BuildCells 就又叠一整套在同一坐标，
--- 而旧格子里上一个被点选国家的 `selected` 高亮没人重置 ⇒ 看上去「多选了多个国家」。
--- 更早版本用来防重入的 `#this.cells > 0` 也拦不住：cells 以国家码（字符串）为键，
--- `#` 长度恒为 0。这里改成按节点名清理，天然幂等（也顺手修掉已叠加的多套旧格子）。
function CountryFlagSelectPopup:ClearCells()
    this.cells = {}
    if this.grid == nil or IsNull(this.grid) then
        return
    end
    local t = this.grid.transform
    -- Destroy 是延迟到帧末执行，childCount 不会当场变，倒序遍历即可安全
    for i = t.childCount, 1, -1 do
        local child = t:GetChild(i - 1)
        if child ~= nil and not IsNull(child) then
            local go = child.gameObject
            if go ~= nil and not IsNull(go) then
                -- 克隆出来的格子都叫 cell_<code>；模板 cellPre 不会命中该前缀
                local name = go.name
                if name ~= nil and string.sub(name, 1, 5) == "cell_" then
                    GameObject.Destroy(go)
                end
            end
        end
    end
end

--- 生成旗帜格子
function CountryFlagSelectPopup:BuildCells()
    this:ClearCells()
    local list = CountryConfig.List
    local total = #list
    local rowCount = math.ceil(total / COLUMN_COUNT)

    -- 内容高度按行数撑开，ScrollRect 据此算出可滚动范围
    local gridRt = this.grid:GetComponent("RectTransform")
    gridRt.sizeDelta = Vector2.New(0, rowCount * CELL_H)

    -- 🔴 格子锚点钉在 grid 顶部（aMin/aMax.y = 1），位置只按行号往下累加：
    -- 旧写法用中心锚点 + startY = rowCount*CELL_H - CELL_H/2，实际位置等于「内容顶 + 内容高/2」，
    -- 比真实内容顶高出 半个内容高度，导致前半部分整体溢出到内容区上方被 viewport 裁掉
    -- （73 国时前 9 行＝36 国永久看不到，滚到底又是空白）。顶部锚定后与 grid 高度/pivot 解耦。
    -- 注意 pivot 仍保持 (0.5,0.5)：pivot 一改，格子里的旗/名字会跟着整体偏移。
    for i = 1, total do
        local code = list[i].code
        local col = (i - 1) % COLUMN_COUNT
        local row = math.floor((i - 1) / COLUMN_COUNT)
        local go = newObject(this.cellPre)
        go.name = "cell_" .. code
        go.transform:SetParent(this.grid.transform, false)
        go:SetActive(true)
        local rt = go:GetComponent("RectTransform")
        rt.anchorMin = Vector2.New(0.5, 1)
        rt.anchorMax = Vector2.New(0.5, 1)
        rt.pivot = Vector2.New(0.5, 0.5)
        rt.anchoredPosition = Vector2.New(
                (col - (COLUMN_COUNT - 1) / 2) * CELL_W,
                -(row * CELL_H + CELL_H / 2))
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
    -- 落本地 + 上报服务端；「派发 OnCountryChanged / 重画已渲染的自己的旗」
    -- 统一在 CountryRankManager.SetPlayerCountry 里做（唯一收口），这里不再重复。
    CountryRankManager.SetPlayerCountry(this._selected)
    this:RefreshSelected()
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

return CountryFlagSelectPopup
