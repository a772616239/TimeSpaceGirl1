--- 显示进度条界面
local BHShowProgress = {}
local this = BHShowProgress

function this.Excute(arg, func)
    local content = arg.content
    local time = arg.time
    UIManager.OpenPanel(UIName.ProgressPanel, content, func, time)
end

return this