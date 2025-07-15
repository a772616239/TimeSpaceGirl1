require("Base/BasePanel")
HelpPopup = Inherit(BasePanel)
local this = HelpPopup

this.Rect ={}
this.value = nil
this.value0 = nil
this.value1 = nil
this.contentrootRect = nil
this.configData = {}
this.helpBtnPosX = 0--传入帮助按钮位置,暂时用上X
this.helpBtnPosY = 0

--初始化组件（用于子类重写）
function HelpPopup:InitComponent()
    this.RContentroot = Util.GetGameObject(self.gameObject,"RContentroot")
    this.RContentrootRect = Util.GetGameObject(self.transform,"RContentroot"):GetComponent("RectTransform")--位置
    this.RContent = Util.GetGameObject(self.transform,"RContentroot/bg/RContent"):GetComponent("Text")--内容

    this.LContentroot = Util.GetGameObject(self.gameObject,"LContentroot")
    this.LContentrootRect = Util.GetGameObject(self.transform,"LContentroot"):GetComponent("RectTransform")
    this.LContent = Util.GetGameObject(self.transform,"LContentroot/bg/LContent"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function HelpPopup:BindEvent()
end

--添加事件监听（用于子类重写）
function HelpPopup:AddListener()
end

--移除事件监听（用于子类重写）
function HelpPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function HelpPopup:OnOpen(QAConfigID,posX,poxY, str)
    this.Rect = Util.GetGameObject(self.transform,"HelpPopup"):GetComponent("RectTransform")
    if QAConfigID then
        this.configData = ConfigManager.GetConfigData(ConfigName.QAConfig,QAConfigID)
    else
        this.str = str
    end
    this.helpBtnPosX = posX
    this.helpBtnPosY = poxY

    if posX > 0 then
        this.contentrootRect = this.RContentrootRect
        this.value = 1
    else
        this.contentrootRect = this.LContentrootRect
        this.value = -1
    end
    --ogErrorTrace(this.value)

    local update
    update = function()
        if Input.GetMouseButtonDown(0) then
            local v2 = Input.mousePosition
            this.value0,this.value1 = RectTransformUtility.ScreenPointToLocalPointInRectangle(this.Rect,v2,UIManager.camera,nil)
            if CheckLOrR(this.value) == 0 then
                return
            end
            this:ClosePanel()
            UpdateBeat:Remove(update, this)
        end
    end
    UpdateBeat:Add(update, this)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HelpPopup:OnShow()
    this.RContentroot:SetActive(false)
    this.LContentroot:SetActive(false)
    local str = nil
    if not this.str then
        str = this.configData.content
        str = string.gsub(str,"{","<color=#D48A07>")
        str = string.gsub(str,"}","</color>")
        str = string.gsub(str,"|","\n")--换行
    else
        str = this.str
    end
    if this.helpBtnPosX > 0 then
        --this.contentrootRect:DOPivotX(1,0)
        this.RContentroot:SetActive(true)
        this.RContentrootRect.anchoredPosition=Vector3.New(this.helpBtnPosX-30,this.helpBtnPosY)
        this.RContent.text=GetLanguageStrById(str)
    else
        --this.contentrootRect:DOPivotX(0,0)
        this.LContentroot:SetActive(true)
        this.LContentrootRect.anchoredPosition=Vector3.New(this.helpBtnPosX+30,this.helpBtnPosY)
        this.LContent.text=GetLanguageStrById(str)
    end
end

--界面关闭时调用（用于子类重写）
function HelpPopup:OnClose()
    this.str = nil
end

--界面销毁时调用（用于子类重写）
function HelpPopup:OnDestroy()
end

function CheckLOrR(index)
    --右
    if index == 1 then
        if this.value1.x > this.RContentrootRect.localPosition.x-this.contentrootRect.sizeDelta.x and
                this.value1.x < this.RContentrootRect.localPosition.x and
                    this.value1.y < this.contentrootRect.localPosition.y and
                        this.value1.y > this.contentrootRect.localPosition.y-this.contentrootRect.sizeDelta.y then
            return 0
        end
    end
    --左
    if index == -1 then
        if this.value1.x > this.LContentrootRect.localPosition.x and
                this.value1.x < this.LContentrootRect.localPosition.x+this.contentrootRect.sizeDelta.x and
                this.value1.y < this.contentrootRect.localPosition.y and
                this.value1.y > this.contentrootRect.localPosition.y-this.contentrootRect.sizeDelta.y then
            return 0
        end
    end
    return 1
end

return HelpPopup