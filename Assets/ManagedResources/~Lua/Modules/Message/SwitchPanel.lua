require("Base/BasePanel")
SwitchPanel = Inherit(BasePanel)
local this = SwitchPanel
--初始化组件（用于子类重写）
function this:InitComponent()

    this.CircleMaskMat = self.gameObject:GetComponent("Image").material
    this.CircleMaskMat:SetFloat("_ScaleX", Screen.width / Screen.height)
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
function this:OnShow()
end
--界面打开时调用（用于子类重写）
function this:OnOpen(...)

end

function this.OpenPanel(id, func)
    -- local args = {...}
    UIManager.OpenPanel(UIName.SwitchPanel)
    DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 6 end),
            DG.Tweening.Core.DOSetter_float(function (progress)
                this.CircleMaskMat:SetFloat("_R", progress)
            end), 0, 1):SetEase(Ease.OutQuad):OnComplete(function ()
        -- UIManager.OpenPanel(id, unpack(args, table.maxn(args)))
        UIManager.OpenPanel(id)
        UIManager.OpenPanel(UIName.SwitchPanel)
        if func then func() end
        DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 0 end),
                DG.Tweening.Core.DOSetter_float(function (progress)
                    this.CircleMaskMat:SetFloat("_R", progress)
                end), 6, 1):SetEase(Ease.InQuad):OnComplete(function ()
            UIManager.ClosePanel(UIName.SwitchPanel)
        end)
    end)
end

-- 播放转场效果，不切换场景
function this.PlayTransEffect(func)
    UIManager.OpenPanel(UIName.SwitchPanel)
    DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 6 end),
            DG.Tweening.Core.DOSetter_float(function (progress)
                this.CircleMaskMat:SetFloat("_R", progress)
            end), 0, 1):SetEase(Ease.OutQuad):OnComplete(function ()
        if func then
            func()
        end
        DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 0 end),
                DG.Tweening.Core.DOSetter_float(function (progress)
                    this.CircleMaskMat:SetFloat("_R", progress)
                end), 6, 1):SetEase(Ease.InQuad):OnComplete(function ()
                UIManager.ClosePanel(UIName.SwitchPanel)
        end)
    end)
end

function this.ClosePanel(id, func)
    UIManager.OpenPanel(UIName.SwitchPanel)
    DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 6 end),
            DG.Tweening.Core.DOSetter_float(function (progress)
                this.CircleMaskMat:SetFloat("_R", progress)
            end), 0, 1):SetEase(Ease.OutQuad):OnComplete(function ()
        UIManager.ClosePanel(id)
        if func then func() end
        UIManager.OpenPanel(UIName.SwitchPanel)
        DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 0 end),
                DG.Tweening.Core.DOSetter_float(function (progress)
                    this.CircleMaskMat:SetFloat("_R", progress)
                end), 6, 1):SetEase(Ease.InQuad):OnComplete(function ()
            UIManager.ClosePanel(UIName.SwitchPanel)
        end)
    end)
end

--界面关闭时调用（用于子类重写）
function this:OnClose()

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()

end

return SwitchPanel