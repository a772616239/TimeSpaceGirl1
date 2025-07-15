----- 点将台抽卡 宝箱弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local lotterySetting=ConfigManager.GetConfig(ConfigName.LotterySetting)
local specialConfig=ConfigManager.GetConfig(ConfigName.SpecialConfig)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local s --s1 消耗道具 s2消耗数量
local b --充值数

function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.text1=Util.GetGameObject(gameObject,"Body/Text1"):GetComponent("Text")
    this.text2=Util.GetGameObject(gameObject,"Body/Text2"):GetComponent("Text")
    this.text3=Util.GetGameObject(gameObject,"Body/Text3"):GetComponent("Text")
    this.curNum=Util.GetGameObject(gameObject,"Body/CurNum/Text"):GetComponent("Text")
    this.okBtn=Util.GetGameObject(gameObject,"OkBtn")
end

function this:BindEvent()
    Util.AddClick(this.okBtn,function()
        if BagManager.GetItemCountById(94)< tonumber(s) then
            PopupTipPanel.ShowTipByLanguageId(11636)
            return
        end
        RecruitManager.RecruitRequest(RecruitType.RecruitBox, function(msg)
            UIManager.OpenPanel(UIName.SingleRecruitPanel, msg.drop.Hero[1],RecruitType.RecruitBox,1)
            this.curNum.text=string.format(GetLanguageStrById(11637),BagManager.GetItemCountById(94))
        end)
    end)

end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder =_parent.sortingOrder
    local args = {...}
    s=lotterySetting[RecruitType.RecruitBox].CostItem[1][2]
    b=tonumber(specialConfig[49].Value)
    this.titleText.text=GetLanguageStrById(11638)
    this.text1.text=string.format(GetLanguageStrById(11639),s)
    this.text2.text=GetLanguageStrById(11640) --后续改成读表
    this.text3.text=string.format(GetLanguageStrById(11641),b)
    this.curNum.text=string.format(GetLanguageStrById(11637),BagManager.GetItemCountById(94))
    Util.SetGray(this.okBtn,VipManager.GetChargedNum()<b)
    this.okBtn:GetComponent("Button").interactable=VipManager.GetChargedNum()>=b
    this.text3.gameObject:SetActive(VipManager.GetChargedNum()>=0 and VipManager.GetChargedNum()<b)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this