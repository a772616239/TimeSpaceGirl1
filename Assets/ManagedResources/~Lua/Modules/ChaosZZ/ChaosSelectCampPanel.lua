require("Base/BasePanel")
ChaosSelectCampPanel = Inherit(BasePanel)
local this = ChaosSelectCampPanel
local minBattleNumIndex=1
local CampData={}
local CampItems =
{
    [1] = {
        campType=1,
        btn = nil,
        recommendImage  = nil,
        battleNum = nil,
        personNum = nil,
    },
    [2] = {
        campType=2,
        btn = nil,
        recommendImage  = nil,
        battleNum = nil,
        personNum = nil,
    },
    [3] = {
        campType=3,
        btn = nil,
        recommendImage  = nil,
        battleNum = nil,
        personNum = nil,
    }, 
}
--初始化组件（用于子类重写）
function ChaosSelectCampPanel:InitComponent()
    for k,v in ipairs(CampItems) do
        local btn = "Root/Camps/Camp_"..k.."/bgBtn"
        local recommendImage = "Root/Camps/Camp_"..k.."/RecommendImage"
        local battleNum = "Root/Camps/Camp_"..k.."/info/BattleNum_text" 
        local personNum = "Root/Camps/Camp_"..k.."/info/PersonNum_text" 
        CampItems[k].btn = Util.GetGameObject(self.gameObject, btn)
        CampItems[k].recommendImage = Util.GetGameObject(self.gameObject, recommendImage)
        CampItems[k].battleNum = Util.GetGameObject(self.gameObject, battleNum):GetComponent("Text")
        CampItems[k].personNum = Util.GetGameObject(self.gameObject, personNum):GetComponent("Text")
    end
    this.backBtn = Util.GetGameObject(this.gameObject, "Root/CloseButton")
end
--申请加入阵营
function ChaosSelectCampPanel:ItemBtnOnClick(campItem)
        local name = ""
        if campItem.campType == 1 then
            name = "秩序阵营"
        elseif campItem.campType == 2 then
            name = "混沌阵营"
        elseif campItem.campType == 3 then
            name = "腐化阵营"
        end
        MsgPanel.ShowTwo("是否确认加入"..name.."？注意：加入阵营后直至本期混乱之治结束将无法更换阵营，请慎重选择", nil,function()
                -- -- 确定加入阵营
                    NetManager.CampSetReq(campItem.campType,function (msg)
                        NetManager.CampWarInfoGetReq(function (msg)
                            UIManager.OpenPanel(UIName.ChaosMainPanel,msg)
                        end)
                    end)
                this:ClosePanel()
        end)
end
--绑定事件（用于子类重写）
function ChaosSelectCampPanel:BindEvent()
    for k,v in ipairs(CampItems) do
        Util.AddClick(v.btn,function ()
            this:ItemBtnOnClick(v)
        end)
    end
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
            this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ChaosSelectCampPanel:AddListener()
     
end

--移除事件监听（用于子类重写）
function ChaosSelectCampPanel:RemoveListener()
   
end

-- --界面打开时调用（用于子类重写）
function ChaosSelectCampPanel:OnOpen(msg)
    
    CampData = msg.CampSimpleInfos

   -- Log("             CampData  "..#CampData)
end

--推荐加入阵营
function ChaosSelectCampPanel:SetRecommendCamp(index)
    for k,v in ipairs(CampItems) do
        if v.campType ~= index then
            v.recommendImage.gameObject:SetActive(false)
        else
            v.recommendImage.gameObject:SetActive(true)
        end
    end
end

function ChaosSelectCampPanel:RefreshView()
    
    
    if CampData and CampData[1] ~= nil then
        local battlenum = CampData[1].totalFight  --默认第一个
        minBattleNumIndex = CampData[1].camp
        for k,v in ipairs(CampData) do
            for index, value in ipairs(CampItems) do
                if v.camp == value.campType then
                    value.personNum.text = v.totalNum
                    value.battleNum.text = v.totalFight
                end
            end   
            if v.totalFight <= battlenum then  --   选择最低战力
                battlenum = v.totalFight
               minBattleNumIndex = v.camp
            end
        end
    else
        LogRed("ChaosSelectCampPanel:RefreshView() CampData is nil")
        return
    end
    
    
    this:SetRecommendCamp(minBattleNumIndex)

end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ChaosSelectCampPanel:OnShow()
    this:RefreshView()
end

--界面关闭时调用（用于子类重写）
function ChaosSelectCampPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function ChaosSelectCampPanel:OnDestroy()
end

return ChaosSelectCampPanel