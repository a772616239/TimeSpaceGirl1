---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by aaa.
--- DateTime: 2019/8/30 17:41
---

local FormFightFormation = {}
local this = FormFightFormation


--- 是否需要切换编队的功能
this.IsNeedChangeFormation = false

--- 逻辑初始化
function this.Init(root)
    this.root = root
    this.InitView()
end
--- 获取需要显示的编队id
function this.GetFormationIndex()
    return FormationTypeDef.BLOODY_BATTLE_ATTACK
end

--- btn1点击回调事件 -- lEFT
function this.On_BtnLeft_Click()

end
--- btn2点击回调事件  --RIGHT
function this.On_BtnRight_Click()

end

function this.InitView()
    this.root.bg:SetActive(true)
end

return this