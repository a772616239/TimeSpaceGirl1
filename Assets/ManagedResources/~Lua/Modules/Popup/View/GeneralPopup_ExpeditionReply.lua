----- 大闹天宫  回复 和 复活节点弹窗 -----
local this = {}
--传入父脚本模块
local parent
local sortingOrder
local nodeType
local nodeState
local fun
function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.content=Util.GetGameObject(gameObject,"content"):GetComponent("Text")
    this.iconImage=Util.GetGameObject(gameObject,"iconImage"):GetComponent("Image")
    this.goBtn=Util.GetGameObject(gameObject,"GoBtn")
    this.goBtnText=Util.GetGameObject(gameObject,"GoBtn/Text"):GetComponent("Text")
end

function this:BindEvent()
    Util.AddOnceClick(this.goBtn,function()
        if fun then
            fun()
            fun = nil
        end
        parent:ClosePanel()
    end)
end

function this:AddListener()

end

function this:RemoveListener()

end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local _args = {...}
     nodeType = _args[1]
     nodeState = _args[2]
     fun = _args[3]
    this.RefreshPanel(nodeType,nodeState)
end

function this:OnClose()
end

function this:OnDestroy()
end


--刷新面板
function this.RefreshPanel()
    this.iconImage.sprite = Util.LoadSprite(ConfigManager.GetConfigData(ConfigName.ExpeditionNodeConfig,nodeType).Icon)
    if nodeType == ExpeditionNodeType.Reply then--回复节点
        this.titleText.text=GetLanguageStrById(11618)
    local num = ConfigManager.GetConfigData(ConfigName.ExpeditionSetting,1).RegeneratePercent/100
        if nodeState == ExpeditionNodeState.No then
            this.content.text = GetLanguageStrById(11619)..num..GetLanguageStrById(11620)
            this.goBtnText.text = GetLanguageStrById(10720)
        elseif nodeState == ExpeditionNodeState.NoPass then
            this.content.text = GetLanguageStrById(11619)..num..GetLanguageStrById(11621)
            this.goBtnText.text = GetLanguageStrById(10023)
        end
    elseif nodeType == ExpeditionNodeType.Resurgence then--复活节点
        this.titleText.text=GetLanguageStrById(11622)
        if nodeState == ExpeditionNodeState.No then
            this.content.text = GetLanguageStrById(11623)
            this.goBtnText.text = GetLanguageStrById(10720)
        elseif nodeState == ExpeditionNodeState.NoPass then
            this.content.text = GetLanguageStrById(11623)
            this.goBtnText.text = GetLanguageStrById(10023)
        end
    end
end
return this