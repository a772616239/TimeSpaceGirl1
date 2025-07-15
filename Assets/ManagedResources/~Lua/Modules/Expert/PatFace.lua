local PatFace = quick_class("PatFace")
local this = PatFace

function PatFace:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function PatFace:InitComponent(gameObject)

    this.frame1goJumpBtn = Util.GetGameObject(gameObject, "goJumpBtn")
    this.frame1activityIcon = Util.GetGameObject(gameObject, "activityIcon"):GetComponent("Image")
end

--绑定事件（用于子类重写）
function PatFace:BindEvent()

end

--添加事件监听（用于子类重写）
function PatFace:AddListener()

end

--移除事件监听（用于子类重写）
function PatFace:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PatFace:OnOpen(...)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PatFace:OnShow()

    this:PatFaceShow()
end
function PatFace:PatFaceShow()
    local patFaceAllData = nil
    if RecruitManager.isTenRecruit == 0 then
        patFaceAllData = {ConfigManager.GetConfigData(ConfigName.LoginPosterConfig,1)}
    end
    if patFaceAllData then
       
        if #patFaceAllData > 0 then
            if patFaceAllData[1]  then
                --self.frame1activityIcon.sprite = Util.LoadSprite(GetResourcePath(patFaceSingleData.Background))
                Util.AddOnceClick(this.frame1goJumpBtn, function()
                    JumpManager.GoJump( patFaceAllData[1].Jump)
                end)
            end
        end
    end
end
--界面关闭时调用（用于子类重写）
function PatFace:OnClose()

end

--界面销毁时调用（用于子类重写）
function PatFace:OnDestroy()

end

return PatFace