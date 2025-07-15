require("Base/BasePanel")
WorkShopLvUpPanel = Inherit(BasePanel)
local upLvInfo={}
local materialList={}
local isMaterialMeet=true
local openPanel
--初始化组件（用于子类重写）
function WorkShopLvUpPanel:InitComponent()

    self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    self.btnSure = Util.GetGameObject(self.transform, "btnSure")
    for i = 1, 4 do
        upLvInfo[i] = Util.GetGameObject(self.transform, "lvUpInfo/info"..i)
    end
    self.equipProGrid = Util.GetGameObject(self.transform, "scroll/grid")
end

--绑定事件（用于子类重写）
function WorkShopLvUpPanel:BindEvent()

    Util.AddClick(self.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(self.btnSure, function()
        if isMaterialMeet then
            NetManager.WorkShopLvUpRequest(function()
                self.DelMaterialList()
                self:OnShow()
                if openPanel then
                    openPanel:OnClickMianTabBtn(4, 2)
                end
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10455)
        end
    end)
end

--添加事件监听（用于子类重写）
function WorkShopLvUpPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopLvUpPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopLvUpPanel:OnOpen(_openPanel)

    openPanel = _openPanel
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function WorkShopLvUpPanel:OnShow()

    --取数据
    isMaterialMeet = true
    local curLvConfigData = ConfigManager.GetConfigData(ConfigName.WorkShopSetting, WorkShopManager.WorkShopData.lv)
    local nextLvConfigData = {}
    if WorkShopManager.WorkShopData.lv >=100 then
        self.btnSure:SetActive(false)
        nextLvConfigData = ConfigManager.GetConfigData(ConfigName.WorkShopSetting, WorkShopManager.WorkShopData.lv)
    else
        nextLvConfigData  = ConfigManager.GetConfigData(ConfigName.WorkShopSetting, WorkShopManager.WorkShopData.lv+1)
        self.btnSure:SetActive(true)
    end
    --local openFunList = ConfigManager.GetConfigData(ConfigName.GameSetting, 1).FunctionRules
    --赋值数据
    Util.GetGameObject(upLvInfo[1].transform, "curNum"):GetComponent("Text").text = curLvConfigData.Id
    Util.GetGameObject(upLvInfo[1].transform, "nextNum"):GetComponent("Text").text = nextLvConfigData.Id
    Util.GetGameObject(upLvInfo[3].transform, "curNum"):GetComponent("Text").text = curLvConfigData.TechnologyLevel
    Util.GetGameObject(upLvInfo[3].transform, "nextNum"):GetComponent("Text").text = nextLvConfigData.TechnologyLevel
    upLvInfo[2]:SetActive(false)
    local openCengJiStrs = ""
    local WorkShopTechnologySetting = ConfigManager.GetConfigData(ConfigName.WorkShopTechnologySetting,1).Limitate
    --for i, v in ConfigPairs(globalSystemConfig) do
    --
    --end
    for i = 1, #WorkShopTechnologySetting do
        if WorkShopManager.WorkShopData.lv+1 == WorkShopTechnologySetting[i] then
            upLvInfo[2]:SetActive(true)
            if openCengJiStrs == "" then
                openCengJiStrs=i..GetLanguageStrById(12036)
            else
                openCengJiStrs=openCengJiStrs.."、"..i..GetLanguageStrById(12036)
            end
        end
    end
    Util.GetGameObject(upLvInfo[2].transform, "curNum"):GetComponent("Text").text = openCengJiStrs
    upLvInfo[4]:SetActive(false)
    local openFunStrs = ""
    local globalSystemConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
    for i, v in ConfigPairs(globalSystemConfig) do
        if v.OpenRules and v.OpenRules[1] == 3 then
            if  WorkShopManager.WorkShopData.lv+1 == v.OpenRules[2] then
                upLvInfo[4]:SetActive(true)
                if openFunStrs == "" then
                    openFunStrs=v.Name
                else
                    openFunStrs=openFunStrs.."、"..v.Name
                end
            end
        end
    end
    Util.GetGameObject(upLvInfo[4].transform, "curNum"):GetComponent("Text").text = openFunStrs
    Util.ClearChild(self.equipProGrid.transform)
    materialList = nextLvConfigData.Exp
    if nextLvConfigData and materialList and #materialList>0 then
        for i = 1, #materialList do
            SubUIManager.Open(SubUIConfig.ItemView, self.equipProGrid.transform, false, materialList[i], 0.86,true,true)
            local bagAllNum=BagManager.GetItemCountById(materialList[i][1])
            if bagAllNum <  materialList[i][2] then
                isMaterialMeet=false
            end
        end
    end
end
function WorkShopLvUpPanel.DelMaterialList()
    --扣除升级材料
    --if materialList and #materialList>0 then
    --    for i = 1, #materialList do
    --        BagManager.UpdateItemsNum(materialList[i][1],materialList[i][2])
    --    end
    --end
end
--界面关闭时调用（用于子类重写）
function WorkShopLvUpPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function WorkShopLvUpPanel:OnDestroy()

end

return WorkShopLvUpPanel