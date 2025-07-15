require("Base/BasePanel")
ClimbTowerEliteFilterStarPopup = Inherit(BasePanel)
local this = ClimbTowerEliteFilterStarPopup

local _tabIdx = 1
local TabBox = require("Modules/Common/TabBox") -- 引用

local _TabData = {
    [1] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong",
        select = "cn2-x1_haoyou_biaoqian_xuanzhong",
        name = string.format(GetLanguageStrById(22604),
        1) },
    [2] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou",
        select = "cn2-x1_haoyou_biaoqian_xuanzhong",
        name = string.format(GetLanguageStrById(22604),
        2) },
}
local showType = 1
local args = {}

--初始化组件（用于子类重写）
function ClimbTowerEliteFilterStarPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnClose")

    this.tabBox = Util.GetGameObject(self.gameObject, "bg/TabBox")

    this.Scroll = Util.GetGameObject(self.gameObject, "bg/Scroll")
    this.Pre = Util.GetGameObject(self.gameObject, "bg/Pre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.Pre, nil,
            Vector2.New(w, h), 1, 2, Vector2.New(0, 0))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function ClimbTowerEliteFilterStarPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ClimbTowerEliteFilterStarPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ClimbTowerEliteFilterStarPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ClimbTowerEliteFilterStarPopup:OnOpen(type, data)
    showType = type or 1
    args = data or {}
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerEliteFilterStarPopup:OnShow()
    this.tabCtrl = TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter) 
    this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)
    this.tabCtrl:Init(this.tabBox, _TabData)

    _tabIdx = 1
    this.ChangeTab(_tabIdx)
    this.scrollView:SetIndex(1)
end

--界面关闭时调用（用于子类重写）
function ClimbTowerEliteFilterStarPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function ClimbTowerEliteFilterStarPopup:OnDestroy()
end

function this.OnTabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab, "default")
    local select = Util.GetGameObject(tab, "select")
    tab:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    default:GetComponent("Text").text = _TabData[index].name
    select:GetComponent("Text").text = _TabData[index].name
    default:SetActive(status == "default")
    select:SetActive(status == "select")
    _tabIdx = index
    this.ChangeTab(index)
end

function this.OnTabIsLockCheck(index)
end

function this.OnChangeTab(index, lastIndex)
end

function this.ChangeTab(index)
    this.data = {}
    if showType == 1 then
        this.data = ClimbTowerManager.GetStarUnfinishListByStar(index)
        table.sort(this.data, function(a, b)
            return a < b
        end)
    elseif showType == 2 then
        local chapterList = PVEActivityManager.GetChapterData(args[1])
        for i = 1, #chapterList do
            local checkpointList = PVEActivityManager.GetCheckpointList(chapterList[i].Id)
            for j = 1, #checkpointList do
                if checkpointList[j].state == 2 then
                    if checkpointList[j].config.StarShow then
                        local name = string.format(GetLanguageStrById(22416), i).."-"..GetLanguageStrById(checkpointList[j].config.Name)
                        local chapter = chapterList[i].Id
                        local checkpoint = checkpointList[j].config.Id
                        if #checkpointList[j].starList == index then
                            -- if index == 1 then
                                table.insert(this.data, {name, chapter, checkpoint})
                        --     end
                        -- elseif #checkpointList[j].starList == 2 then
                        --     if index == 2 then
                        --         table.insert(this.data, {name, chapter, checkpoint})
                        --     end
                        end
                    end
                end
            end
        end
    end
    this:RefreshScroll()
end

function this:RefreshScroll()
    this.scrollView:SetData(this.data, function(index, root)
        if showType == 1 then
            this:FillItemForType1(root, this.data[index])
        elseif showType == 2 then
            this:FillItemForType2(root, this.data[index])
        end
    end)
end

function this:FillItemForType1(go, data)
    Util.GetGameObject(go, "Stage"):GetComponent("Text").text = string.format(GetLanguageStrById(10484), data)
    Util.AddOnceClick(go, function()
        ClimbTowerManager.GetReportData(data, PlayerManager.uid, function(msg)
            UIManager.OpenPanel(UIName.ClimbTowerEliteGoFightPopup, data, ClimbTowerManager.ClimbTowerType.Advance)
        end, ClimbTowerManager.ClimbTowerType.Advance)
        -- FormationManager.curFormationIndex = FormationTypeDef.CLIMB_TOWER
        -- ClimbTowerManager.ExecuteFightAdvance(data, function()
        -- end, false)
    end)
end

function this:FillItemForType2(go, data)
    Util.GetGameObject(go, "Stage"):GetComponent("Text").text = data[1]
    Util.AddOnceClick(go, function()
        self:ClosePanel()
        Game.GlobalEvent:DispatchEvent(GameEvent.PVE.Jump, data[2], data[3])
    end)
end

return ClimbTowerEliteFilterStarPopup