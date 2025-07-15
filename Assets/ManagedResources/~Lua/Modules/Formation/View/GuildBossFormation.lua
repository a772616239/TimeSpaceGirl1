local GuildBossFormation = {}
local this = GuildBossFormation

--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false

function this.Init(root)
    this.root = root
    this.InitView()
end

--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.FORMATION_NORMAL
end
--- 界面关闭时回调
function this.OnCloseBtnClick()
    this.root:ClosePanel()
end
--- 提交按钮点击事件
function this.On_BtnLeft_Click()
    GuildBossManager.RequestAttackBoss(function()
        -- body
        this.root:ClosePanel()
    end)
end

-- 界面显示刷新
function this.InitView()
    this.root.btnLeft:SetActive(true)
    this.root.btnLeftTxt.text = GetLanguageStrById(10729)
end

return this