----- 试练增益弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)

--增益弹窗类型
local gainType={
    Normal=0, --普通查看
    Specil=1 --重置时查看
}

--预设容器
local preList={}

function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.upTip=Util.GetGameObject(gameObject,"UpTip"):GetComponent("Text")
    this.bottomTip=Util.GetGameObject(gameObject,"BottomTip"):GetComponent("Text")
    this.root=Util.GetGameObject(gameObject,"Root")
    this.pre=Util.GetGameObject(this.root,"Pre")
    this.goBtn=Util.GetGameObject(gameObject,"GoBtn")
end

function this:BindEvent()
    --取消按钮
    Util.AddClick(this.cancelBtn,function()
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

    this.RefreshPanel(_args[1])
end

function this:OnClose()
end

function this:OnDestroy()
    preList={}
end


--刷新面板
function this.RefreshPanel(type)
    this.titleText.text=GetLanguageStrById(11647)

    this.upTip.gameObject:SetActive(type==gainType.Specil)
    this.bottomTip.gameObject:SetActive(type==gainType.Normal)
    this.goBtn.gameObject:SetActive(type==gainType.Specil)

    local props = FoodBuffManager.GetBuffPropList()
    if not props then return end

    for i, v in ipairs(props) do
        local o=preList[i]
        if not o then
            o=newObjToParent(this.pre,this.root)
            o.name="Pre"..i
            preList[i]=o
        end
        local icon=Util.GetGameObject(o,"Icon"):GetComponent("Image")
        local tip=Util.GetGameObject(o,"Tip"):GetComponent("Text")

        local val = v.value
        local express1 = val >= 0 and "+" or ""
        local express2 = ""
        if propertyConfig[v.id].Style == 2 then
            val = val / 100
            express2 = "%"
        end
        tip.text=string.format("%s：%s",GetLanguageStrById(propertyConfig[v.id].Info),(express1..val..express2))

        if propertyConfig[v.id].BuffShow then
            -- local lastStr = ""
            -- if propertyConfig[v.id].IfBuffShow == 1 then
            --     lastStr = v.value >= 0 and "_buff" or "_debuff" -- m5
            -- end
            -- icon.sprite = Util.LoadSprite(propertyConfig[v.id].BuffShow .. lastStr)
            icon.sprite = Util.LoadSprite(propertyConfig[v.id].BuffShow)
        else

        end
    end
end

return this