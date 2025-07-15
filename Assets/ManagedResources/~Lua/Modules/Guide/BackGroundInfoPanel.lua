require("Base/BasePanel")
BackGroundInfoPanel = Inherit(BasePanel)
local this = BackGroundInfoPanel
local content
local func

--初始化组件（用于子类重写）
function BackGroundInfoPanel:InitComponent()
    this.Image_Bg = Util.GetGameObject(self.gameObject, "Image_Bg")   
    this.Text_BgInfo = Util.GetGameObject(self.gameObject, "Image_Bg/Text_BgInfo")   
    this.Button_Jump = Util.GetGameObject(self.gameObject, "Button_Jump")   
    this.Image_Mask = Util.GetGameObject(self.gameObject, "Image_Mask")   
end

--绑定事件（用于子类重写）
function BackGroundInfoPanel:BindEvent()
    Util.AddClick(this.Button_Jump, function()
        if func then
            func()
        end        
        self:ClosePanel()
    end)
    Util.AddClick(this.Image_Bg, function()
        if func then
            func()
        end        
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function BackGroundInfoPanel:AddListener()   
end

--移除事件监听（用于子类重写）
function BackGroundInfoPanel:RemoveListener()    
end

--界面打开时调用（用于子类重写）
function BackGroundInfoPanel:OnOpen(...)  
    local data = {...}  
    --要显示的文字
    if data[1] then
        content=data[1]        
    end
    --跳过按钮
    if data[2] then
        func=data[2]        
    end
   
    ShowText(this.Text_BgInfo, content, 20,this.funMask)
end

function this.funMask()
    this.Image_Mask:SetActive(false)   
end
--界面关闭时调用（用于子类重写）
function BackGroundInfoPanel:OnClose()
  
end

--界面销毁时调用（用于子类重写）
function BackGroundInfoPanel:OnDestroy()
end

return BackGroundInfoPanel