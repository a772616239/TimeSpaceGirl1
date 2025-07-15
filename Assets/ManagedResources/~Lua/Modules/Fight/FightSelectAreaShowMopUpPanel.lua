require("Base/BasePanel")
FightSelectAreaShowMopUpPanel = Inherit(BasePanel)
local fightId = 0
local fightData = {}
local mopUpDeleNum = 0
--初始化组件（用于子类重写）
function FightSelectAreaShowMopUpPanel:InitComponent()

    --扫荡选择
    self.mopUpGo=Util.GetGameObject(self.transform, "showMopUp")
    self.btnMpoUpBack = Util.GetGameObject(self.transform, "showMopUp/bg/btnBack")
    self.Slider= Util.GetGameObject(self.transform, "showMopUp/bg/Slider")
    self.numText= Util.GetGameObject(self.transform, "showMopUp/bg/Slider/numText"):GetComponent("Text")
    self.tiliNum= Util.GetGameObject(self.transform, "showMopUp/bg/tiliNum"):GetComponent("Text")
    self.btnMpoUpSure = Util.GetGameObject(self.transform, "showMopUp/bg/btnSure")
end

--绑定事件（用于子类重写）
function FightSelectAreaShowMopUpPanel:BindEvent()


    Util.AddClick(self.btnMpoUpBack, function()
        self:ClosePanel()
    end)
    Util.AddSlider(self.Slider, function(go, value)
        self:ShowMopUpInfoData(value)
    end)
    Util.AddClick(self.btnMpoUpSure, function()
        self:BtnMpoUpSureClick()
    end)
end

--添加事件监听（用于子类重写）
function FightSelectAreaShowMopUpPanel:AddListener()

end

--移除事件监听（用于子类重写）
function FightSelectAreaShowMopUpPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function FightSelectAreaShowMopUpPanel:OnOpen(_fightId)

    fightId = _fightId
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightSelectAreaShowMopUpPanel:OnShow()

    fightData = FightManager.GetSingleFightDataByFightId(fightId)
    self:ShowMopUpInfo(1)
    self.Slider:GetComponent("Slider").value=1
end

--扫荡设置
function FightSelectAreaShowMopUpPanel:ShowMopUpInfo(_curVal)
    local num = math.floor(BagManager.GetItemCountById(2)/(fightData.fightData.Cost[1][2]+fightData.fightData.PreLevelCost[1][2]))--体力
    if fightData.fightData.MaxCountPerDay~=0  then
        local curCishu=fightData.fightData.MaxCountPerDay-fightData.num
        num=curCishu >=num and num or curCishu
    end
    num=num>=10 and 10 or num
    self.Slider:GetComponent("Slider").maxValue=num
    self.Slider:GetComponent("Slider").minValue=0
    self:ShowMopUpInfoData(_curVal)
end
function FightSelectAreaShowMopUpPanel:ShowMopUpInfoData(value)
    self.numText.text= value
    mopUpDeleNum=value
    self.tiliNum.text=(fightData.fightData.Cost[1][2]+fightData.fightData.PreLevelCost[1][2])*value
end
--扫荡按钮点击处理
function FightSelectAreaShowMopUpPanel:BtnMpoUpSureClick()
    if mopUpDeleNum>0 then
        -- 已经没屁用了
        -- NetManager.GetMopUpFightDataRequest(1,fightData.fightId,mopUpDeleNum,function(dropList)
            -- UIManager.OpenPanel(UIName.FightMopUpEndPanel,dropList,fightData)
        --     self:ClosePanel()
        -- end)
    else
        PopupTipPanel.ShowTipByLanguageId(10608)
    end
end
--界面关闭时调用（用于子类重写）
function FightSelectAreaShowMopUpPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function FightSelectAreaShowMopUpPanel:OnDestroy()

end

return FightSelectAreaShowMopUpPanel