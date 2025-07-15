require("Base/BasePanel")
ChaosMainPanel = Inherit(BasePanel)
local this = ChaosMainPanel

local Views = {
    --挑战
    [1] = {view = require("Modules/ChaosZZ/HLChallengeView"), panelName = "ChallengePanel"},
    --战报
    [2] = {view = require("Modules/ChaosZZ/ChaosBattleFileView"), panelName = "BattleFieldPanel"},
    --奖励
    [3] = {view = require("Modules/ChaosZZ/ChaosRewardPanel"), panelName = "RewardPanel"},
    --排行
    [4] = {view = require("Modules/ChaosZZ/ChaosRankView"), panelName = "RankPanel"},
}
local chanllengeView = Views[1].view
local battleFileView = Views[2].view
local rewardView = Views[3].view
local rankView = Views[4].view

--初始化组件（用于子类重写）
function ChaosMainPanel:InitComponent()
    this.panels = Util.GetGameObject(this.gameObject, "Root/Panel")
    this.backBtn = Util.GetGameObject(this.gameObject, "Root/Bottom/BackButton")
    this.rewardBtn = Util.GetGameObject(this.gameObject, "Root/Bottom/RewardBtn/tab")
    this.rewardBtnSelect = Util.GetGameObject(this.gameObject, "Root/Bottom/RewardBtn/tab/select")
   -- this.rewardBtnUnSelect = Util.GetGameObject(this.gameObject, "Root/Bottom/RewardBtn/tab/unselect")
    this.zhanBaoBtn = Util.GetGameObject(this.gameObject, "Root/Bottom/ZhanBaoBtn/tab")
    this.zhanBaoBtnSelect = Util.GetGameObject(this.gameObject, "Root/Bottom/ZhanBaoBtn/tab/select")
   -- this.zhanBaoBtnUnSelect = Util.GetGameObject(this.gameObject, "Root/Bottom/ZhanBaoBtn/tab/unselect")
   this.rankBtn = Util.GetGameObject(this.gameObject, "Root/Bottom/RankBtn/tab")
   this.rankBtnSelect = Util.GetGameObject(this.gameObject, "Root/Bottom/RankBtn/tab/select")
    this.challegeBtn = Util.GetGameObject(this.gameObject, "Root/Bottom/ChallegeBtn/tab")
    this.challegeBtnSelect = Util.GetGameObject(this.gameObject, "Root/Bottom/ChallegeBtn/tab/select")
    this.challegeBtnRedState = Util.GetGameObject(this.gameObject, "Root/Bottom/ChallegeBtn/Redpoint")
    this.zhanBaoBtnRedState = Util.GetGameObject(this.gameObject, "Root/Bottom/ZhanBaoBtn/Redpoint")
    --this.challegeBtnUnSelect = Util.GetGameObject(this.gameObject, "Root/Bottom/ChallegeBtn/tab/unselect")
    for i = 1, #Views do
        Views[i].view:InitComponent(Util.GetGameObject(this.panels, Views[i].panelName))
    end 
    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)
end
--挑战红点
function ChaosMainPanel:ChallengeRedPointStateRefresh()

end
--战报红点
function ChaosMainPanel:ZhanBaoRedPointStateRefresh(data)

 end
--按钮状态切换
function ChaosMainPanel:SwitchBtns(index)
  
    if index == 1 then
        this.rewardBtnSelect:SetActive(false)
        this.zhanBaoBtnSelect:SetActive(false)
        this.challegeBtnSelect:SetActive(true)
        this.rankBtnSelect:SetActive(false)
        ChaosManager:SetSelectBtnState(1)
    elseif index==2 then
        this.rewardBtnSelect:SetActive(false)
        this.zhanBaoBtnSelect:SetActive(true)
        this.challegeBtnSelect:SetActive(false)
        this.rankBtnSelect:SetActive(false)
        ChaosManager:SetSelectBtnState(2)
    elseif index==3 then
        this.rewardBtnSelect:SetActive(true)
        this.zhanBaoBtnSelect:SetActive(false)
        this.challegeBtnSelect:SetActive(false)
        this.rankBtnSelect:SetActive(false)
        ChaosManager:SetSelectBtnState(3)
    elseif index==4 then
        this.rewardBtnSelect:SetActive(false)
        this.zhanBaoBtnSelect:SetActive(false)
        this.challegeBtnSelect:SetActive(false)
        this.rankBtnSelect:SetActive(true)
        ChaosManager:SetSelectBtnState(4)
    end
end
--按钮状态切换
function ChaosMainPanel:SwitchView(index)
    Views[2].view.gameObject:SetActive(false)
    Views[3].view.gameObject:SetActive(false)
    Views[4].view.gameObject:SetActive(false)
    for i = 1, 4 do
        if i == index then
            Views[i].view.gameObject:SetActive(true)
            if index ==2 then
                battleFileView:RefreshView()
            end
            if index == 4 then
                rankView:RefreshView()
            end
            if index == 3 then
                rewardView:RefreshView()
            end
        end
    end
end

--绑定事件（用于子类重写）
function ChaosMainPanel:BindEvent()   
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        ChaosManager:SetSelectBtnState(1)
            this:ClosePanel()
    end)
    Util.AddClick(this.rewardBtn, function() 
        if ChaosManager:GetIsOpen() then
            this:SwitchBtns(3)
            this:SwitchView(3)
        end
    end)
    Util.AddClick(this.zhanBaoBtn, function()
        if ChaosManager:GetIsOpen() then
            this:SwitchBtns(2)
            this:SwitchView(2)
        end
    end)
    Util.AddClick(this.challegeBtn, function()
        if ChaosManager:GetIsOpen() then
            this:SwitchBtns(1)
            this:SwitchView(1)
        end
    end)
    Util.AddClick(this.rankBtn, function()
        if ChaosManager:GetIsOpen() then
            this:SwitchBtns(4)
            this:SwitchView(4)
        end
    end)
     for i = 1, #Views do
        Views[i].view:BindEvent()
    end
    BindRedPointObject(RedPointType.Chaos_Tab_Chanllege, this.challegeBtnRedState)
end

--添加事件监听（用于子类重写）
function ChaosMainPanel:AddListener()
end

--移除事件监听（用于子类重写）
function ChaosMainPanel:RemoveListener()
    
end


function ChaosMainPanel:RefreshView()
    this:ChallengeRedPointStateRefresh()
end

-- --界面打开时调用（用于子类重写）
function ChaosMainPanel:OnOpen(msg)
    ChaosManager:SetChallegeData(msg)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ChaosMainPanel:OnShow()
    if ChaosManager:GetIsOpen() then
        this.PlayerHeadFrameView:OnShow()
        this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
        local btnState =  ChaosManager:GetSelectBtnState()
        this:SwitchBtns(btnState)
        this:SwitchView(btnState)
        chanllengeView:RefreshView()
       -- rewardView:RefreshView()
        this:RefreshView()
        --battleFileView:RefreshView()
        CheckRedPointStatus(RedPointType.Chaos_Tab_Chanllege)
    end
end

--界面关闭时调用（用于子类重写）
function ChaosMainPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function ChaosMainPanel:OnDestroy()
    ClearRedPointObject(RedPointType.Chaos_Tab_Chanllege)
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
    for i = 1, #Views do
        Views[i].view:OnDestroy()
    end
    ChaosManager:SetSelectBtnState(1)
    --  chanllengeView:OnDestroy()
    --  battleFileView:OnDestroy()
end

return ChaosMainPanel