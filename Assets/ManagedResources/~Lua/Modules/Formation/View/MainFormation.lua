local MainFormation = {}
local this = MainFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = true

--- 逻辑初始化
function this.Init(root)
    this.root = root
    this.root.bg:SetActive(true)

    this.root.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationManager.curFormationIndex
end

--- 关闭界面事件
function this.OnCloseBtnClick()
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    --UIManager.OpenPanel(UIName.MainPanel)
    this.root:ClosePanel()
end



return this