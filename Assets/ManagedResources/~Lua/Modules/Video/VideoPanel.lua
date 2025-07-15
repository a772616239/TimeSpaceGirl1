require("Base/BasePanel")
local VideoPanel = Inherit(BasePanel)
local this = VideoPanel


local videoName = nil

--初始化组件（用于子类重写）
function VideoPanel:InitComponent()
    this.Button_Skip = Util.GetGameObject(self.gameObject, "Button_Skip")
    this.VideoPlayer = Util.GetGameObject(self.gameObject, "RawImage"):GetComponent("VideoPlayer")
end

--绑定事件（用于子类重写）
function VideoPanel:BindEvent()
    Util.AddClick(this.Button_Skip, function()
        this.VideoStop()
    end)
end

--添加事件监听（用于子类重写）
function VideoPanel:AddListener()
end

--移除事件监听（用于子类重写）
function VideoPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function VideoPanel:OnOpen(...)
    local args = {...}
    videoName = args[1]
    stopFunc = args[2]
    if videoName then
        this.VideoStartPlay()
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function VideoPanel:OnShow(...)
end

--界面层级发生改变（用于子类重写）
function VideoPanel:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function VideoPanel:OnClose()
    videoName = nil
end

--界面销毁时调用（用于子类重写）
function VideoPanel:OnDestroy()
end


-- function this:Update()
--     如果loopPointReached不好用，用这个
--     if this.VideoPlayer.frame == this.VideoPlayer.frameCount then
--         Video has finshed playing!
--         this.VideoStop()
--         LogError("1111111111111111111111")
--     end
-- end

--开始播放
function this.VideoStartPlay()
    local VideoClip = resMgr:LoadAsset(videoName)
    if not VideoClip then
        LogError("没有找到VideoClip：" .. videoName)
        return;
    end
    this.VideoPlayer.loopPointReached = this.VideoPlayer.loopPointReached + this.VideoStop
    this.VideoPlayer.clip = VideoClip
    this.VideoPlayer:Play()
end

--播放完成后
function this.VideoStop()
    this.VideoPlayer.loopPointReached = this.VideoPlayer.loopPointReached - this.VideoStop
    this.VideoPlayer:Stop()
    this.VideoPlayer.targetTexture:Release()
    this.VideoPlayer.targetTexture:MarkRestoreExpected()
    if stopFunc then
        stopFunc()
    end
    this:ClosePanel()
end

return VideoPanel


