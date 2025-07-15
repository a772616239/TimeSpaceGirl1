---
--- 公告面板
---

require("Base/BasePanel")

GongGaoPanel = Inherit(BasePanel)
local this = GongGaoPanel

--初始化组件（用于子类重写）
function this:InitComponent()

    this.bgRoot = Util.GetGameObject(self.transform,"bg");
    this.CloseBtnRoot = Util.GetGameObject(self.transform,"CloseBtn");
    this.Txt_Content = Util.GetGameObject(self.transform, "TipLabel"):GetComponent("Text");
end

--绑定事件（用于子类重写）
function this:BindEvent()

    Util.AddClick(this.CloseBtnRoot, this.OnCloseClick);
end

--界面打开时调用（用于子类重写）
function this:OnOpen(str,action)

    this.action = action;
    this.Txt_Content.text = string.gsub(str,"&nbsp","");

end

--界面关闭时调用（用于子类重写）
function this:OnClose()

    if(this.action ~= nil) then
        this.action();
        this.action = nil;
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()

end

function this.OnCloseClick()
    this:DestroyPanel();
    ShareSoundConfig.PlayClickButtonSound();
end

return GongGaoPanel