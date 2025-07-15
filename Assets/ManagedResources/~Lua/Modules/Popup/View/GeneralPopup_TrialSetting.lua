----- 试练设置弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0

local btns={}
local btnClick={}

function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")

    this.root = Util.GetGameObject(gameObject, "Root")

    for i = 1, 3 do
        btns[i]=Util.GetGameObject(this.root,"Btn"..i)
    end
end

function this:BindEvent()
    for i = 1, 3 do
        Util.AddClick(btns[i],function()
            local o=btns[i]
            local go=Util.GetGameObject(o,"Go")
            local var=PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..i
            btnClick[i]=(btnClick[i] and btnClick[i]==1) and 0 or 1
            
            PlayerPrefs.SetInt(var,btnClick[i])
            go:SetActive(PlayerPrefs.GetInt(var)==1)
        end)
    end
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

    this.titleText.text=GetLanguageStrById(11649)
    for i = 1, 3 do
        local o=btns[i]
        local go=Util.GetGameObject(o,"Go")
        local var=PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..i
        if PlayerPrefs.HasKey(var) then
            go:SetActive(PlayerPrefs.GetInt(var)==1)
        else
            go:SetActive(false)
        end
    end
    btns[2]:SetActive(MapManager.curCarbonType == CarBonTypeId.TRIAL)
    btns[3]:SetActive(MapManager.curCarbonType == CarBonTypeId.TRIAL)
end

function this:OnClose()
end

function this:OnDestroy()
    btns={}
end

return this