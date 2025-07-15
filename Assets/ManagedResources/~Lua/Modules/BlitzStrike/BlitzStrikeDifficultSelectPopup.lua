require("Base/BasePanel")
BlitzStrikeDifficultSelectPopup = Inherit(BasePanel)
local this = BlitzStrikeDifficultSelectPopup

local BlitzType = ConfigManager.GetConfig(ConfigName.BlitzType)

--初始化组件（用于子类重写）
function BlitzStrikeDifficultSelectPopup:InitComponent()
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.btnBack = Util.GetGameObject(self.gameObject, "Bg/btnBack")
      --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition=this.HelpBtn:GetComponent("RectTransform").localPosition

    this.difficultGo = {}
    for i = 1, BlitzStrikeManager.TotalModelNum do
        this.difficultGo[i] = Util.GetGameObject(self.gameObject, "Bg/Difficult" .. tostring(i))
    end
    this.itemList = {}
end

--绑定事件（用于子类重写）
function BlitzStrikeDifficultSelectPopup:BindEvent()
    Util.AddClick(this.mask, function()
        self:ClosePanel()
        if BlitzStrikePanel then
            BlitzStrikePanel:ClosePanel()
        end
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
        if BlitzStrikePanel then
            BlitzStrikePanel:ClosePanel()
        end
    end)
end

function BlitzStrikeDifficultSelectPopup.RefreshHelpBtn()
    
        this.HelpBtn:SetActive(true)
        Util.AddOnceClick(this.HelpBtn, function()
         UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.BlitzStrikeDifficultSelect,this.helpPosition.x,this.helpPosition.y+1150) 
   
        -- this.HelpBtn:SetActive(false)
    end)
end
--添加事件监听（用于子类重写）
function BlitzStrikeDifficultSelectPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function BlitzStrikeDifficultSelectPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function BlitzStrikeDifficultSelectPopup:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BlitzStrikeDifficultSelectPopup:OnShow()
    local mainFormationPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
    this.RefreshHelpBtn()
    for i = 1, BlitzStrikeManager.TotalModelNum do
        local Btn = Util.GetGameObject(this.difficultGo[i], "Btn")
        local Power = Util.GetGameObject(this.difficultGo[i], "Power")
        local PowerFont = Util.GetGameObject(this.difficultGo[i], "Power/PowerFont"):GetComponent("Text")
        local BlitzTypeConfig = BlitzType[i]
        PowerFont.text = GetLanguageStrById(11727) .. " " .. PrintPowerNum(BlitzTypeConfig.NeedPower)
        Power:SetActive(false)
        Btn:SetActive(false)
        local function setBtn(j)
            Btn:SetActive(true)
            Util.AddOnceClick(Btn, function()
                NetManager.BlitzChooseDifficulty(j, function(msg)
                    if msg.drop ~= nil then
                        UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function() end)
                    end
                    NetManager.BlitzInfo(function()
                        NetManager.BlitzTypeInfo(function()
                            NetManager.GetBlitzAllTankInfo(function()
                                CheckRedPointStatus(RedPointType.ForgottenCity)
                                self:ClosePanel()
                                if BlitzStrikePanel then
                                    BlitzStrikePanel.UpdateMain()
                                end
                            end)
                        end)
                    end)
                end)
            end)
        end
        if i > 1 then
            if BlitzStrikeManager.historyAllPassStatus[i-1] == 1 and mainFormationPower > BlitzTypeConfig.NeedPower then
            --if BlitzStrikeManager.historyAllPassStatus[i-1] == 1 then --< 战力走后端
                --> 可选择
                setBtn(i)
            else
                Power:SetActive(true)
            end
        else
            --> 可选择
            setBtn(i)
        end


        local RewardGrid = Util.GetGameObject(this.difficultGo[i], "RewardTotal/Grid/RewardGrid")
        if not this.itemList[i] then
            this.itemList[i] = {}
        end
        for j = 1, #BlitzTypeConfig.ShowAwards do
            if not this.itemList[i][j] then
                this.itemList[i][j] = SubUIManager.Open(SubUIConfig.ItemView, RewardGrid.transform)
            end   
            this.itemList[i][j]:OnOpen(false, {BlitzTypeConfig.ShowAwards[j][1], BlitzTypeConfig.ShowAwards[j][2]}, 0.6, nil, nil, nil, nil, nil)
        end
        
    end
end

--界面关闭时调用（用于子类重写）
function BlitzStrikeDifficultSelectPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function BlitzStrikeDifficultSelectPopup:OnDestroy()
    this.itemList = {}
end

return BlitzStrikeDifficultSelectPopup