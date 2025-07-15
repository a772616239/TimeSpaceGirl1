require("Base/BasePanel")
GrowthManualLevelUpPanel = Inherit(BasePanel)
local this = GrowthManualLevelUpPanel
local config

local BgAndFontColor = { [1] = {bg = "cn2-X1_chengzhangshouce_putongdengji",color = Color.New(0/255,251/255,255/255,1)},
                        [2] = {bg = "cn2-X1_chengzhangshouce_jingyingdengji",color = Color.New(255/255,249/255,145/255,1)}} 

--初始化组件（用于子类重写）
function GrowthManualLevelUpPanel:InitComponent()    
    this.btnBack = Util.GetGameObject(this.gameObject, "bg/Button_Close")
    this.confimBtn = Util.GetGameObject(this.gameObject, "bg/Button")    
    this.level = Util.GetGameObject(this.gameObject, "bg/Image_LevelBg/Text_Level"):GetComponent("Text")
    this.box2 = Util.GetGameObject(this.gameObject, "bg/ScrollView/Viewport/Content")
    this.bg = Util.GetGameObject(this.gameObject, "bg/Image_LevelBg"):GetComponent("Image")
    
    this.taskList = {}
end

--绑定事件（用于子类重写）
function GrowthManualLevelUpPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.confimBtn, function()
        self:ClosePanel()
    end)
end

function GrowthManualLevelUpPanel:OnSortingOrderChange()
end
function GrowthManualLevelUpPanel:OnOpen(level)
    config = ConfigManager.GetConfigDataByKey(ConfigName.TreasureSunLongConfig,"Level",level)
end
-- 打开，重新打开时回调
function GrowthManualLevelUpPanel:OnShow()     
   this.level.text = config.Level
   this.SetItem()
end

function GrowthManualLevelUpPanel:SetItem()

    if GrowthManualManager.GetTreasureState() then
        this.bg.sprite = Util.LoadSprite(BgAndFontColor[2].bg)
        this.level.color = BgAndFontColor[2].color
    else
        this.bg.sprite = Util.LoadSprite(BgAndFontColor[1].bg)
        this.level.color = BgAndFontColor[1].color
    end

    for i = 1,#this.taskList do
        this.taskList[i].gameObject:SetActive(false)
    end
    local index = 1 
    for i = 1, #config.Reward do
        if not this.taskList[index] then
            local item = SubUIManager.Open(SubUIConfig.ItemView, this.box2.transform)
            this.taskList[index] = item
        end
        this.taskList[index]:OnOpen(false,config.Reward[i],0.8)
        index = index + 1
    end
    if GrowthManualManager.GetTreasureState() then
        for i = 1, #config.TreasureReward do
            if not this.taskList[index] then
                local item = SubUIManager.Open(SubUIConfig.ItemView, this.box2.transform)
                this.taskList[index] = item
            end
            this.taskList[index]:OnOpen(false,config.TreasureReward[i],0.8)
            index = index + 1
        end   
    end
    
end
function GrowthManualLevelUpPanel:AddListener()
   
end

function GrowthManualLevelUpPanel:RemoveListener()
    
end

--界面关闭时调用（用于子类重写）

function GrowthManualLevelUpPanel:OnClose()
    for i = 1,#this.taskList do
        SubUIManager.Close(this.taskList[i])
    end
    this.taskList = {}
end

--界面销毁时调用（用于子类重写）
function GrowthManualLevelUpPanel:OnDestroy()    
    this.taskList = {}
end

return this