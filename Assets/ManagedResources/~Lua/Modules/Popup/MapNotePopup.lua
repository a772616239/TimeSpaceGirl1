require("Base/BasePanel")
MapNotePopup = Inherit(BasePanel)
local this = MapNotePopup
this.notePos = 0
-- 1 --- > 标记面板
-- 2 --- > 删除面板
local panelType = 1


--初始化组件（用于子类重写）
function MapNotePopup:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "Frame/btnCancel")
    this.btnConfirm = Util.GetGameObject(self.gameObject, "Frame/btnConfirm")
    this.noteText = Util.GetGameObject(self.gameObject, "Frame/InputField/Name"):GetComponent("Text")

    --
    this.notePopup = Util.GetGameObject(self.gameObject, "Frame")
    this.deletePopup = Util.GetGameObject(self.gameObject, "Delete")

    this.btnCancelDelete = Util.GetGameObject(self.gameObject, "Delete/btnCancel")
    this.btnConfirmDelete = Util.GetGameObject(self.gameObject, "Delete/btnConfirm")
end

--绑定事件（用于子类重写）
function MapNotePopup:BindEvent()

    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnConfirm, function ()
        this.TakeNote()
    end)

    Util.AddClick(this.btnCancelDelete, function ()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnConfirmDelete, function ()
        EndLessMapManager.DeleteNotePoint(this.notePos, function ()
            self:ClosePanel()
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.OnRemoveNotePoint, this.notePos)
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)

        end)
    end)
end

--添加事件监听（用于子类重写）
function MapNotePopup:AddListener()

end

--移除事件监听（用于子类重写）
function MapNotePopup:RemoveListener()


end

--界面打开时调用（用于子类重写）
function MapNotePopup:OnOpen(notePos, type)
    if notePos then
        this.notePos = notePos
    end
    if type then
        panelType = type
    end

    -- 设置显示面板
    this.InitPanelShow(panelType)
end

function this.InitPanelShow(type)
    this.notePopup:SetActive(type == 1)
    this.deletePopup:SetActive(type == 2)
end

-- ================================= 标记面板 =================================================
-- 确认标记
function this.TakeNote()
    local u, v = Map_Pos2UV(this.notePos)
    local noteText = " "
    if this.noteText.text then
        noteText = tostring(this.noteText.text)
    end

    if noteText == "" or noteText == "" then
        PopupTipPanel.ShowTipByLanguageId(11567)
        return
    end






    NetManager.RequestNotePoint(MapManager.curMapId, this.notePos, noteText, 1, function (msg)
       
        if this.IsNotePass(msg.error) then
            -- 内容健康执行下一步
            MapNotePopup:ClosePanel()
            ---- 地图上新增一个标记点
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.OnAddNotePoint, this.notePos, noteText)
        else
            MsgPanel.ShowTwo(GetLanguageStrById(11570), nil, function()
                UIManager.ClosePanel(UIName.MsgPanel)
            end)
        end
    end)
end

-- 设置结果
function this.IsNotePass(str)
    local pass = false
    if str == GetLanguageStrById(11570) then
        pass = false
    else
        pass = true
    end
    return pass
end

-- ========================================================================================
-- ============================== 取消标记面板 ==============================================


-- ========================================================================================
--界面关闭时调用（用于子类重写）
function MapNotePopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function MapNotePopup:OnDestroy()

end

return MapNotePopup