require("Base/BasePanel")
MedalAssembleChoosePopup = Inherit(BasePanel)
local this = MedalAssembleChoosePopup


--勋章套装保存装配选择
--初始化组件（用于子类重写）
function MedalAssembleChoosePopup:InitComponent()
    this.backBtn = Util.GetGameObject(self.gameObject,"backBtn")
end

--绑定事件（用于子类重写）
function MedalAssembleChoosePopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MedalAssembleChoosePopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalAssembleChoosePopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MedalAssembleChoosePopup:OnOpen(...)
    local args={...}
   
    this.posData=args[1]
    this.medalData=args[2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalAssembleChoosePopup:OnShow()
 
    --TODO考虑有锁状态的套装 控制显示隐藏
    for i = 1, #this.posData do
        local plan=Util.GetGameObject(self.gameObject,"plan"..i .."/plan")
        if this.posData[i].name==nil or this.posData[i].name=="" then
            plan:GetComponent("Text").text=string.format(GetLanguageStrById(23053),this.posData[i].pos)
        else
            plan:GetComponent("Text").text=string.format("[%s]",this.posData[i].name)
        end
        --plan:GetComponent("Text").text=this.posData[i].name
        plan:SetActive(this.posData[i].activePos==1)
        Util.AddClick(Util.GetGameObject(self.gameObject,"plan"..i.."/plan/saveBtn"),function()
            NetManager.WearSavePosRequest(this.posData[i].pos,this.medalData,function(msg)
                
                
                MedalSuitPopup:OnShow()
                self:ClosePanel()
                return
             end)
        end)
    end
    
end
function MedalAssembleChoosePopup:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function MedalAssembleChoosePopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function MedalAssembleChoosePopup:OnDestroy()

end


return MedalAssembleChoosePopup